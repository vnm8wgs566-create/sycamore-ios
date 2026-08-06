//
//  SupabaseRepository.swift
//  Sycamore
//
//  `SycamoreRepository`, backed by Postgres. Drop-in for `InMemoryRepository`: same protocol,
//  same semantics, same guarantee that every mutation hands the whole camp back.
//
//  That last convention is what shapes this file. `Repository.swift` says a backend "will
//  re-select the graph after a write anyway", and it is right — so a write here is: load the
//  graph, let `Camp`'s own mutating methods decide what the answer is, send the difference, load
//  it again. The partition algorithm, the even-out, the rule that a kid dropped across a venue
//  rule changes venue: all of it stays in `Models.swift`, where it is already written and
//  already the thing `InMemoryRepository` obeys. Reimplementing any of it in SQL would be two
//  copies of the rules and one of them would be wrong.
//
//  Three places where the schema cannot say what the model says, all of them called out at the
//  code below:
//
//  1. There is no `players.overall_rank`. `ratings.rating` is the only column holding an order
//     over players, so it is what a drag writes — as a permutation of the values already there,
//     which moves the kids without inventing a rating.
//  2. There is no `groups.closed_reason`, so a court taken out of play is held on this actor for
//     the life of the process. See `SupabaseRepository+SectionEight.swift`.
//  3. `sites.name` is globally unique and `camps.invite_code` is too, which the app's own
//     "Venue 1" naming walks straight into. Both inserts retry with a disambiguated value.
//
//  And one thing that is not a schema gap but will look like a broken client until it is fixed:
//  the two section 8 migrations created `camps`, `memberships`, `profiles`, `schedule_blocks` and
//  `inbox_items`, and recreated `today_courts`, `roster_today` and `player_scores`, without
//  granting a single privilege to `anon` or `authenticated`. `delete` is missing from the older
//  tables too. Every one of those relations answers `42501 permission denied` over REST, so
//  signing in, picking a camp, Schedule and the Inbox all fail until:
//
//      grant select, insert, update, delete on all tables in schema public
//        to anon, authenticated;
//      grant select on public.today_courts, public.roster_today, public.player_scores
//        to anon, authenticated;
//
//  Row level security is already the gate — every table has RLS on, and `20260805074039`
//  documents its open `mvp_all` policy as a deliberate placeholder — so this restores the
//  intent the migrations wrote down rather than loosening anything.
//

import Foundation

actor SupabaseRepository: SycamoreRepository {

    // Not private: `SupabaseRepository+SectionEight.swift` implements against both from an
    // extension, and an extension cannot reach a private stored property.
    let auth: SupabaseAuth
    let db: PostgRESTClient

    /// Courts taken out of play, and why. See the file header — nothing in the schema holds this.
    var closedCourts: [Group.ID: String] = [:]

    /// Camps with a write in flight, and whoever is queued behind them.
    private var busyCamps: Set<Camp.ID> = []
    private var campQueues: [Camp.ID: [CheckedContinuation<Void, Never>]] = [:]

    init(urlSession: URLSession = .shared) {
        let auth = SupabaseAuth(urlSession: urlSession)
        self.auth = auth
        self.db = PostgRESTClient(auth: auth, urlSession: urlSession)
    }

    /// Runs `body` with no other write to this camp in progress.
    ///
    /// An actor is not enough on its own. Every mutation here is load, decide, send, reload — and
    /// an actor gives up isolation at each of those four awaits, so two intents that overlap both
    /// read the same graph, both compute a whole answer from it, and the second one overwrites
    /// the first entirely rather than composing with it. Toggling a kid away while a partition is
    /// in flight loses one of the two. `InMemoryRepository` cannot do this: its mutations never
    /// suspend, so they are already atomic, and this is what buys back the same guarantee.
    ///
    /// Per camp rather than one lock: two people running two different camps have nothing to say
    /// to each other, and a single gate would serialise them for no reason.
    func serialised<T>(_ campID: Camp.ID, _ body: () async throws -> T) async throws -> T {
        while busyCamps.contains(campID) {
            await withCheckedContinuation { campQueues[campID, default: []].append($0) }
        }
        busyCamps.insert(campID)
        defer { release(campID) }
        return try await body()
    }

    private func release(_ campID: Camp.ID) {
        busyCamps.remove(campID)
        guard var queue = campQueues[campID], !queue.isEmpty else { return }
        let next = queue.removeFirst()
        campQueues[campID] = queue.isEmpty ? nil : queue
        next.resume()
    }

    // MARK: - Identity

    func requestSignInCode(email: String) async throws -> SignInChallenge {
        let address = EmailAddress.normalised(email)
        guard EmailAddress.isValid(address) else { throw SycamoreError.invalidEmail }
        try await auth.requestCode(email: address)
        return SignInChallenge(email: address)
    }

    func verifySignInCode(_ code: String, email: String) async throws -> Account {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else { throw SycamoreError.invalidCode }
        let address = EmailAddress.normalised(email)
        // Only the exchange itself is read as a bad code. `adoptProfile` talks to PostgREST, and
        // a policy refusing the profile write is not the coach mistyping a digit.
        let session: SupabaseAuth.Session
        do {
            session = try await auth.verify(code: digits, email: address)
        } catch let error as SupabaseError {
            throw Self.asInvalidCode(error)
        }
        return try await adoptProfile(for: session)
    }

    /// No mapping onto `invalidCode`: there is no code on this screen, and "That code didn't work"
    /// is not something a coach who tapped Continue with Apple can act on. A rejected identity
    /// token surfaces as what it is.
    /// Refuses before the network when there is no token to send.
    ///
    /// `AppleSignIn` produces a real token now, and `continueWithApple` no longer defaults it to
    /// `""` — the compiler enforces one. The guard stays as a backstop for the empty-string case
    /// the type system cannot rule out, because what GoTrue answers to an empty token is
    /// `id_token required`: an internal detail of an endpoint the reader never asked about.
    ///
    /// It is also the honest error while the provider is off. Apple sign-in needs two switches
    /// the app cannot throw for itself — the provider enabled in the Supabase dashboard with the
    /// bundle id as its Client ID, and "Sign In with Apple" ticked on the App ID in the Apple
    /// developer portal. Until both are on, this is what a person sees.
    func signInWithApple(identityToken: String) async throws -> Account {
        guard !identityToken.isEmpty else { throw SycamoreError.appleSignInUnavailable }
        let session = try await auth.signInWithApple(identityToken: identityToken)
        return try await adoptProfile(for: session)
    }

    func signOut() async throws {
        await auth.signOut()
    }

    func account(id: Account.ID) async throws -> Account {
        let rows: [ProfileRecord] = try await db.select(
            Relation.profiles, .select("*").eq("id", id)
        )
        guard let row = rows.first else { throw SycamoreError.unknownAccount }
        return Account(row)
    }

    /// `avatarImageData` is carried through untouched rather than saved: `profiles.avatar_url`
    /// holds a URL into Storage, not bytes, and uploading one is a feature with a bucket and a
    /// policy behind it. Dropping the photo the profile screen just took would look like a bug,
    /// so the value the caller passed comes straight back.
    func updateAccount(_ account: Account) async throws -> Account {
        let values: RowValues = [
            "display_name": .text(account.displayName),
            "emergency_phone": .text(account.emergencyPhone),
            "notifications_enabled": .bool(account.notificationsEnabled),
        ]
        try await db.update(
            Relation.profiles, set: values, where: PostgRESTQuery().eq("id", account.id)
        )
        var saved = try await self.account(id: account.id)
        saved.avatarImageData = account.avatarImageData
        return saved
    }

    /// Deletes the profile, which cascades to every membership and detaches every staff row.
    ///
    /// The `auth.users` row survives, because removing it needs the service role key and that
    /// key must never ship inside an app — anyone who extracted it could read every camp in the
    /// project. What the person loses is everything about them the app can see; what remains is
    /// an empty login, and signing in with it again lands on a fresh account with no camps.
    func deleteAccount(id: Account.ID) async throws {
        // The rows back, not a bare 204: a DELETE that matched nothing answers exactly the same
        // as one that matched — and under `profiles_own_row` somebody else's id matches nothing.
        // Without this the app would sign the real person out and call it a success.
        let deleted: [ProfileRecord] = try await db.delete(
            Relation.profiles, where: PostgRESTQuery().eq("id", id), returning: ProfileRecord.self
        )
        guard !deleted.isEmpty else { throw SycamoreError.unknownAccount }
        await auth.signOut()
    }

    /// Every sign-in path ends here: `auth.users` owns the login, `profiles` owns the name and
    /// the phone number, and the second one does not exist until somebody makes it.
    private func adoptProfile(for session: SupabaseAuth.Session) async throws -> Account {
        let row: RowValues = ["id": .uuid(session.userID), "email": .text(session.email)]
        try await db.upsert(Relation.profiles, [row], onConflict: "id")
        return try await account(id: session.userID)
    }

    /// GoTrue answers a wrong or expired code with a 4xx and a developer-facing sentence. The
    /// screen has a better one already.
    private static func asInvalidCode(_ error: SupabaseError) -> any Error {
        if case .rejected(let status, _) = error, (400...403).contains(status) {
            return SycamoreError.invalidCode
        }
        return error
    }

    // MARK: - Camps

    func memberships(forAccount accountID: Account.ID) async throws -> [Membership] {
        let records: [MembershipRecord] = try await db.select(
            Relation.memberships, .select("*").eq("account_id", accountID).order("created_at")
        )
        guard !records.isEmpty else { return [] }

        let campIDs = records.map(\.campId)
        async let campsTask: [CampRecord] = db.select(
            Relation.camps, .select("*").within("id", campIDs)
        )
        async let sitesTask: [SiteRecord] = db.select(
            Relation.sites, .select("*").within("camp_id", campIDs).order("sort_index")
        )
        async let coachesTask: [CoachRecord] = db.select(
            Relation.coaches, .select("*").eq("account_id", accountID).isTrue("active")
        )
        let (campRecords, siteRecords, coachRecords) = try await (campsTask, sitesTask, coachesTask)

        let camps = Dictionary(uniqueKeysWithValues: campRecords.map { ($0.id, $0) })
        let siteIDs = siteRecords.map(\.id)

        var groupRecords: [GroupRecord] = []
        var playerRecords: [PlayerRecord] = []
        // Only today's away rows change a head-count: `Camp` reads a missing attendance row as
        // "here", and the picker's `8 kids · 7 here` has to agree with what Groups will show.
        var away: Set<Player.ID> = []
        if !siteIDs.isEmpty {
            async let groupsTask: [GroupRecord] = db.select(
                Relation.groups, .select("*").within("site_id", siteIDs).order("rank_order")
            )
            async let playersTask: [PlayerRecord] = db.select(
                Relation.players, .select("*").within("site_id", siteIDs)
            )
            async let awayTask: Set<Player.ID> = awayPlayerIDs(inSites: siteIDs, on: .today)
            (groupRecords, playerRecords, away) = try await (groupsTask, playersTask, awayTask)
        }

        let sitesByCamp = Dictionary(grouping: siteRecords, by: { $0.campId })
        let groupsBySite = Dictionary(grouping: groupRecords, by: \.siteId)
        let playersBySite = Dictionary(grouping: playerRecords, by: { $0.siteId })

        return records.compactMap { record -> Membership? in
            guard let campRecord = camps[record.campId] else { return nil }
            let sites = sitesByCamp[campRecord.id] ?? []
            let players = sites.flatMap { playersBySite[$0.id] ?? [] }
            let camp = Camp(
                id: campRecord.id,
                name: campRecord.name,
                sport: PostgresEnum.sport(campRecord.sport),
                inviteCode: campRecord.inviteCode,
                icon: campRecord.icon,
                tint: PostgresEnum.tint(campRecord.tint),
                venues: sites.map(Venue.init),
                players: players.map { Player($0, overallRank: 0, courtRank: 0) }
            )

            let coach = coachRecords.first { $0.campId == campRecord.id }
            let assignment = todayAssignment(
                for: coach, in: camp, groups: groupsBySite, away: away
            )
            return Membership(
                // The row's own id, not a fresh one. `Membership` is `Identifiable` and the
                // picker draws a list of them — an id that changed on every load would make
                // every refresh look like a different set of camps.
                id: record.id,
                accountID: accountID,
                campID: campRecord.id,
                role: PostgresEnum.role(record.role, label: record.roleLabel),
                todayAssignment: assignment,
                campName: campRecord.name,
                campIcon: campRecord.icon,
                campTint: PostgresEnum.tint(campRecord.tint),
                campSummary: assignment == nil ? camp.summaryLine : nil
            )
        }
    }

    /// The camp picker's second line, when there is a court to name. Mirrors what
    /// `InMemoryRepository.refreshMembershipProjections` computes: with no court, the row falls
    /// back to `campSummary` instead.
    private func todayAssignment(
        for coach: CoachRecord?,
        in camp: Camp,
        groups: [UUID: [GroupRecord]],
        away: Set<Player.ID>
    ) -> TodayAssignment? {
        guard let coach, let groupID = coach.groupId, let siteID = coach.siteId,
              let venue = camp.venue(siteID),
              let court = (groups[siteID] ?? []).first(where: { $0.id == groupID })
        else { return nil }

        let here = camp.players.filter { $0.groupID == groupID }
        return TodayAssignment(
            venueID: venue.id,
            venueName: venue.name,
            venueIcon: venue.icon,
            venueTint: venue.tint,
            groupID: groupID,
            groupLabel: court.courtLabel ?? court.name,
            kidCount: here.count,
            presentCount: here.count { !away.contains($0.id) },
            // No column records when a coach last committed an order.
            rankedAt: nil
        )
    }

    /// The whole graph, in two waves: what hangs off the camp, then what hangs off its venues.
    /// Five requests in the second wave and three in the first, all of them concurrent — the
    /// screens want a camp, and eight sequential round trips is a second of staring at a
    /// spinner on camp wifi.
    func camp(id: Camp.ID) async throws -> Camp {
        async let campTask: [CampRecord] = db.select(
            Relation.camps, .select("*").eq("id", id)
        )
        async let sitesTask: [SiteRecord] = db.select(
            Relation.sites, .select("*").eq("camp_id", id).order("sort_index")
        )
        async let coachesTask: [CoachRecord] = db.select(
            Relation.coaches, .select("*").eq("camp_id", id).isTrue("active")
        )
        let (campRecords, siteRecords, coachRecords) = try await (campTask, sitesTask, coachesTask)
        guard let campRecord = campRecords.first else { throw SycamoreError.unknownCamp }

        var camp = Camp(
            id: campRecord.id,
            name: campRecord.name,
            sport: PostgresEnum.sport(campRecord.sport),
            inviteCode: campRecord.inviteCode,
            icon: campRecord.icon,
            tint: PostgresEnum.tint(campRecord.tint),
            venues: siteRecords.map(Venue.init)
        )
        let siteIDs = siteRecords.map(\.id)
        guard !siteIDs.isEmpty else { return camp }

        let week = CampWeek.weekBounds()
        async let groupsTask: [GroupRecord] = db.select(
            Relation.groups, .select("*").within("site_id", siteIDs).order("rank_order")
        )
        async let playersTask: [PlayerRecord] = db.select(
            Relation.players, .select("*").within("site_id", siteIDs)
        )
        // `ratings` and `attendance` carry no `site_id`, so both reach the camp through an inner
        // join on `players`. That keeps the filter one short list of venue ids rather than a URL
        // with every player's uuid in it, which a camp of any size would overflow.
        async let ratingsTask: [RatingRecord] = db.select(
            Relation.ratings,
            .select("player_id,rating,players!inner(site_id)").within("players.site_id", siteIDs)
        )
        async let attendanceTask: [AttendanceRecord] = db.select(
            Relation.attendance,
            .select("*,players!inner(site_id)")
                .within("players.site_id", siteIDs)
                .eq("session", Self.session)
                .gte("day", week.monday)
                .lte("day", week.friday)
        )
        async let inboxTask: [InboxItemRecord] = db.select(
            Relation.inboxItems,
            .select("*").within("site_id", siteIDs).isNull("player_id", false)
                .order("created_at", ascending: false)
        )
        let (groupRecords, playerRecords, ratingRecords, attendanceRecords, inboxRecords) =
            try await (groupsTask, playersTask, ratingsTask, attendanceTask, inboxTask)

        camp.groups = Self.courts(from: groupRecords, venues: camp.venues)
        camp.players = Self.players(from: playerRecords, ratings: ratingRecords)
        camp.staff = Self.staff(from: coachRecords, camp: camp)
        camp.attendance = Self.attendance(from: attendanceRecords)
        camp.history = inboxRecords.compactMap(HistoryEvent.init)
        camp.reindex()
        return camp
    }

    func joinCamp(inviteCode: String, accountID: Account.ID) async throws -> Membership {
        guard let code = Self.formattedInviteCode(inviteCode) else {
            throw SycamoreError.unknownInviteCode
        }
        let camps: [CampRecord] = try await db.select(
            Relation.camps, .select("*").eq("invite_code", code)
        )
        guard let campRecord = camps.first else { throw SycamoreError.unknownInviteCode }

        // Idempotent by reading first rather than by upserting: a merge would reset an admin who
        // pasted their own code back down to `worker`, and `joinCamp` is documented to hand the
        // existing membership back untouched.
        let existing: [MembershipRecord] = try await db.select(
            Relation.memberships,
            .select("*").eq("account_id", accountID).eq("camp_id", campRecord.id)
        )
        if existing.isEmpty {
            // A code hands out the lowest useful permission; an admin promotes from Setup.
            try await db.insert(Relation.memberships, [RowValues([
                "account_id": .uuid(accountID),
                "camp_id": .uuid(campRecord.id),
                "role": .text(PostgresEnum.text(Role.worker)),
            ])])
        }
        try await adoptStaffRow(
            accountID: accountID,
            campID: campRecord.id,
            role: existing.first.map { PostgresEnum.role($0.role, label: $0.roleLabel) } ?? .worker
        )
        return try await membership(forAccount: accountID, camp: campRecord.id)
    }

    func createCamp(_ draft: CampDraft, accountID: Account.ID) async throws -> Membership {
        guard draft.isValid else { throw SycamoreError.campNameRequired }

        // `Camp.make` is screen 4's output — N venues, M courts each, ids and all. Building it
        // first means the rows written below are the same graph the offline build would produce.
        let camp = Camp.make(from: draft, inviteCode: Camp.inviteCode(for: draft.name))
        try await insertCamp(camp)

        for venue in camp.orderedVenues {
            try await insertSite(venue, campID: camp.id)
        }
        try await db.insert(Relation.groups, camp.groups.map(Self.groupRow))

        try await db.insert(Relation.memberships, [RowValues([
            "account_id": .uuid(accountID),
            "camp_id": .uuid(camp.id),
            "role": .text(PostgresEnum.text(Role.admin)),
        ])])
        try await adoptStaffRow(accountID: accountID, campID: camp.id, role: .admin)

        return try await membership(forAccount: accountID, camp: camp.id)
    }

    // MARK: - The day

    func setAttendance(
        playerID: Player.ID, day: Weekday, present: Bool, campID: Camp.ID
    ) async throws -> Camp {
        try await writeAttendance(playerID: playerID, day: day, campID: campID) { record in
            record.present = present
            if !present { record.leavesAt = nil }
        }
    }

    func setEarlyPickup(
        playerID: Player.ID, day: Weekday, leavesAt: TimeOfDay?, campID: Camp.ID
    ) async throws -> Camp {
        try await writeAttendance(playerID: playerID, day: day, campID: campID) { record in
            record.leavesAt = leavesAt
        }
    }

    // MARK: - Order

    func reorderGroup(
        _ groupID: Group.ID, playerIDs: [Player.ID], campID: Camp.ID
    ) async throws -> Camp {
        try await mutateLadder(campID) { camp in
            guard camp.group(groupID) != nil else { throw SycamoreError.unknownGroup }
            camp.reorder(group: groupID, playerIDs: playerIDs)
        }
    }

    func reorderCamp(_ assignments: [RankAssignment], campID: Camp.ID) async throws -> Camp {
        try await mutateLadder(campID) { camp in
            for assignment in assignments where camp.venue(assignment.venueID) == nil {
                throw SycamoreError.unknownVenue
            }
            camp.applyRankOrder(assignments)
        }
    }

    func movePlayer(
        _ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp {
        try await mutateLadder(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            guard camp.venue(venueID) != nil else { throw SycamoreError.unknownVenue }
            camp.movePlayer(playerID, toVenue: venueID, group: groupID)
        }
    }

    func partitionCamp(_ campID: Camp.ID) async throws -> Camp {
        try await mutateLadder(campID) { $0.partition() }
    }

    func evenOut(_ campID: Camp.ID) async throws -> Camp {
        try await mutateLadder(campID) { $0.evenOut() }
    }

    // MARK: - Shape

    func updateVenue(_ venue: Venue, campID: Camp.ID) async throws -> Camp {
        try await serialised(campID) {
            let before = try await camp(id: campID)
            guard before.venue(venue.id) != nil else { throw SycamoreError.unknownVenue }

            var after = before
            // Patches the venue, adds or trims courts, rehomes anyone displaced.
            after.upsert(venue)

            do {
                try await db.update(
                    Relation.sites,
                    set: Self.siteRow(venue, campID: campID),
                    where: PostgRESTQuery().eq("id", venue.id)
                )
            } catch let error as SupabaseError where error.isUniqueViolation {
                // `sites.name` is unique across every camp in the project, not just this one.
                throw SupabaseError.rejected(
                    status: 409, message: "Another venue already uses that name."
                )
            }

            // Order matters, and the foreign keys set it: a court cannot be deleted while a kid
            // still points at it, and a kid cannot be moved onto a court that is not there yet.
            try await addCourts(before: before, after: after, venueID: venue.id)
            try await writePlacements(before: before, after: after)
            try await dropCourts(before: before, after: after, venueID: venue.id)
            try await writeLadder(before: before, after: after)
            return try await camp(id: campID)
        }
    }

    func addVenue(campID: Camp.ID) async throws -> Camp {
        try await serialised(campID) {
            let before = try await camp(id: campID)
            var after = before
            // The same defaults `InMemoryRepository.addVenue` uses: a new venue copies the shape
            // of the last one rather than arriving with numbers nobody chose.
            let index = before.venues.count
            let icon = Venue.iconOptions[index % Venue.iconOptions.count]
            let template = before.orderedVenues.last
            let venue = Venue(
                name: "Venue \(index + 1)",
                subtitle: nil,
                icon: icon,
                tint: .suggested(for: icon),
                groupCount: template?.groupCount ?? 6,
                coachMin: template?.coachMin ?? 4,
                coachMax: template?.coachMax ?? 7,
                playerMin: template?.playerMin ?? 0,
                playerMax: template?.playerMax ?? 60,
                sortIndex: index
            )
            after.upsert(venue)

            try await insertSite(venue, campID: campID)
            try await db.insert(Relation.groups, after.groups(in: venue.id).map(Self.groupRow))
            return try await camp(id: campID)
        }
    }

    func updateStaffRole(
        _ staffID: StaffMember.ID, role: Role, campID: Camp.ID
    ) async throws -> Camp {
        try await serialised(campID) {
            let before = try await camp(id: campID)
            guard before.staff(staffID) != nil else { throw SycamoreError.unknownStaff }

            var after = before
            after.setRole(role, forStaff: staffID)
            let updated = after.staff(staffID)

            try await db.update(
                Relation.coaches,
                set: [
                    "role": .text(PostgresEnum.text(role)),
                    "role_label": .text(PostgresEnum.label(role)),
                    "is_roaming": .bool(updated?.isRoaming ?? false),
                    "is_admin": .bool(role.isAdmin),
                ],
                where: PostgRESTQuery().eq("id", staffID)
            )

            // And the membership, which is where the *permission* lives. `Role` sits on the staff
            // row for display and on the membership for authority — `AppStore.isAdmin` reads the
            // second — so a promotion without this changes the chip in Setup and nothing else.
            if let accountID = updated?.accountID {
                try await db.update(
                    Relation.memberships,
                    set: [
                        "role": .text(PostgresEnum.text(role)),
                        "role_label": .text(PostgresEnum.label(role)),
                    ],
                    where: PostgRESTQuery().eq("account_id", accountID).eq("camp_id", campID)
                )
            }
            return try await camp(id: campID)
        }
    }

    func assignStaff(
        _ staffID: StaffMember.ID, toGroup groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp {
        try await serialised(campID) {
            let before = try await camp(id: campID)
            guard let member = before.staff(staffID) else { throw SycamoreError.unknownStaff }
            if let groupID, before.group(groupID) == nil { throw SycamoreError.unknownGroup }

            if let groupID, let court = before.group(groupID) {
                // One coach per court: whoever was there is bumped to no court.
                try await db.update(
                    Relation.coaches,
                    set: ["group_id": .null, "site_id": .null],
                    where: PostgRESTQuery().eq("group_id", groupID).neq("id", staffID)
                )
                try await db.update(
                    Relation.coaches,
                    set: [
                        "group_id": .uuid(groupID),
                        "site_id": .uuid(court.venueID),
                        "is_roaming": .bool(false),
                    ],
                    where: PostgRESTQuery().eq("id", staffID)
                )
            } else {
                try await db.update(
                    Relation.coaches,
                    set: [
                        "group_id": .null,
                        "site_id": .null,
                        "is_roaming": .bool(member.role.roamsByDefault),
                    ],
                    where: PostgRESTQuery().eq("id", staffID)
                )
            }
            return try await camp(id: campID)
        }
    }

    /// Deactivated, not deleted. `attendance.noted_by` and `ratings.last_by` point at coaches
    /// with no `on delete` clause, so removing the row would fail for anyone who has ever marked
    /// a kid away — and succeeding would erase who noted it. `camp(id:)` reads only active staff,
    /// so from every screen's point of view they are gone.
    func removeStaff(_ staffID: StaffMember.ID, campID: Camp.ID) async throws -> Camp {
        try await serialised(campID) {
            let before = try await camp(id: campID)
            guard before.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            // `camp_id` stays. It is what `adoptStaffRow` looks the person up by when they
            // rejoin; clearing it would leave the old row unfindable and orphan their history
            // behind a duplicate.
            try await db.update(
                Relation.coaches,
                set: ["active": .bool(false), "site_id": .null, "group_id": .null],
                where: PostgRESTQuery().eq("id", staffID)
            )
            return try await camp(id: campID)
        }
    }
}
