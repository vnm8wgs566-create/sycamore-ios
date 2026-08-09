//
//  Repository.swift
//  Sycamore
//
//  The seam. `SycamoreRepository` is every read and write the twelve screens need,
//  expressed as `async throws` so a Supabase-backed implementation can drop in behind
//  it without a single view changing. `InMemoryRepository` is the offline stand-in,
//  seeded from `SampleData`.
//
//  Two conventions worth knowing before you add a method:
//
//  1. Every mutation that touches a camp returns the whole camp back. A backend will
//     re-select the graph after a write anyway, and it means callers never have to
//     patch local state by hand.
//  2. Nothing here knows about SwiftUI, navigation, or the current selection. That all
//     lives in `AppStore`.
//

import Foundation

// MARK: - Sign-in

/// What the server tells us after it posts a code. `resendAfter` is the 0:42 countdown.
struct SignInChallenge: Hashable, Sendable {
    var email: String
    var codeLength: Int = 6
    var resendAfter: Int = 42
    var sentAt: Date = .now
}

enum SycamoreError: LocalizedError, Equatable {
    case invalidEmail
    case invalidCode
    case unknownAccount
    case unknownCamp
    case unknownVenue
    case unknownGroup
    case unknownPlayer
    case unknownStaff
    case unknownInviteCode
    case campNameRequired
    case notPermitted
    case appleSignInUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "That doesn't look like an email address."
        case .invalidCode: "That code didn't work. Try again."
        case .unknownAccount: "We couldn't find that account."
        case .unknownCamp: "We couldn't find that camp."
        case .unknownVenue: "We couldn't find that venue."
        case .unknownGroup: "We couldn't find that court."
        case .unknownPlayer: "We couldn't find that kid."
        case .unknownStaff: "We couldn't find that person."
        case .unknownInviteCode: "No camp uses that code."
        case .campNameRequired: "Give the camp a name first."
        case .notPermitted: "Only an admin can do that."
        case .appleSignInUnavailable: "Apple sign-in isn't set up yet. Use your email instead."
        }
    }
}

// MARK: - Protocol

/// Inherits `SectionEightData` (in `SectionEightRepository.swift`) so a call site only ever
/// sees one repository. The split is about who edits which file, not about two capabilities.
protocol SycamoreRepository: SectionEightData {

    // MARK: Identity

    /// Screen 1. Posts a one-time code and returns the resend window.
    func requestSignInCode(email: String) async throws -> SignInChallenge
    /// Screen 2. Trades the six digits for an account.
    func verifySignInCode(_ code: String, email: String) async throws -> Account
    /// Screen 1's "Continue with Apple". The token is whatever `ASAuthorization` hands
    /// back; the in-memory build ignores it.
    func signInWithApple(identityToken: String) async throws -> Account
    func signOut() async throws

    func account(id: Account.ID) async throws -> Account
    func updateAccount(_ account: Account) async throws -> Account
    func deleteAccount(id: Account.ID) async throws

    // MARK: Camps

    /// Screen 3's "Your camps".
    func memberships(forAccount accountID: Account.ID) async throws -> [Membership]
    /// The whole camp graph in one shot.
    func camp(id: Camp.ID) async throws -> Camp
    /// Screen 3's code field. Idempotent — joining twice returns the same membership.
    func joinCamp(inviteCode: String, accountID: Account.ID) async throws -> Membership
    /// Screen 4. The creator becomes the camp's first admin.
    func createCamp(_ draft: CampDraft, accountID: Account.ID) async throws -> Membership

    // MARK: The day

    /// Screen 5's swipe action and the player sheet's "Mark away today".
    func setAttendance(
        playerID: Player.ID, day: Weekday, present: Bool, campID: Camp.ID
    ) async throws -> Camp
    /// Screen 10. Pass `nil` to cancel a pick-up that was already set.
    func setEarlyPickup(
        playerID: Player.ID, day: Weekday, leavesAt: TimeOfDay?, campID: Camp.ID
    ) async throws -> Camp

    // MARK: Order

    /// A drag inside one coach's card on screen 5.
    func reorderGroup(
        _ groupID: Group.ID, playerIDs: [Player.ID], campID: Camp.ID
    ) async throws -> Camp
    /// A drag on screen 6. Sections arrive top to bottom, so a kid dropped across a
    /// venue rule simply appears in the next section and changes venue.
    func reorderCamp(_ assignments: [RankAssignment], campID: Camp.ID) async throws -> Camp
    /// The player sheet's "Move up a court", and any explicit venue change.
    func movePlayer(
        _ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp
    /// Setup's "Partition the camp" — fills each venue by rank, inside its limits.
    func partitionCamp(_ campID: Camp.ID) async throws -> Camp
    /// Screen 6's "Even out" — levels the courts inside every venue.
    func evenOut(_ campID: Camp.ID) async throws -> Camp

    // MARK: Shape

    /// Screen 11. Name, subtitle, icon and all four limits in one write.
    func updateVenue(_ venue: Venue, campID: Camp.ID) async throws -> Camp
    /// Setup's "Add" beside the VENUES header.
    func addVenue(campID: Camp.ID) async throws -> Camp

    /// `8t`'s "Camp name & sport".
    ///
    /// The two fields that row edits, rather than a whole `Camp`. A `Camp` argument would read
    /// as though the venues, the roster and the staff hanging off it were being written too —
    /// and it would let a caller holding a stale copy of any of them post it back.
    ///
    /// The invite code deliberately does not follow the name. It is derived from the name only
    /// once, when the camp is created; after that it is a thing people have written down, and
    /// silently retiring it because somebody fixed a typo would lock out a camp that had done
    /// nothing wrong. `rollInviteCode` is how a code changes.
    func renameCamp(name: String, sport: Sport, campID: Camp.ID) async throws -> Camp

    /// `8t`'s "Days the camp runs" — the row under it.
    ///
    /// Its own intent rather than a third argument to `renameCamp`, for the reason that method
    /// takes two fields rather than a `Camp`: a write says what moved. A days row that also sent
    /// the name and the sport could undo a rename made from another device between this screen's
    /// last read and this write, and would make every days edit re-read the camp picker's
    /// projection — which stores the name and cannot hold the days at all.
    func setCampDays(_ days: CampDays, campID: Camp.ID) async throws -> Camp

    /// `8t`'s "Roll a new code".
    ///
    /// Keeps the three letters and moves the four digits: the letters are the camp's initials
    /// and are what makes a code recognisable read down a phone. The old code stops working,
    /// which is the point of the row — it is how a camp closes a code that got out.
    func rollInviteCode(campID: Camp.ID) async throws -> Camp

    // MARK: Enrolment

    /// `8e` — Add a player, one at a time.
    ///
    /// The kid joins the back of the venue's ladder. Section 8 has no screen that asks where a
    /// new kid ranks, and it would be the wrong question to ask on the way in: rank is what the
    /// camp works out about them over a morning, not something typed at a gate.
    func addPlayer(
        _ player: Player, toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> Camp

    /// `8c` / `8d` — Bring in the week, then check the import.
    ///
    /// A batch rather than a loop over `addPlayer`: a roster is forty-odd kids, and forty
    /// sequential round-trips is the difference between an import that feels instant and one
    /// somebody watches. It is also the only way the whole import can fail as one thing —
    /// half a roster is worse than none, because nobody can tell which half.
    func importPlayers(
        _ players: [Player], toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> Camp

    /// `8d` again, a week later — the same file re-read against the camp it already built.
    ///
    /// Plural for the reason `importPlayers` is plural. Reconciling a roster is forty-odd kids at
    /// once, and a singular `updatePlayer` would force every caller into a loop each iteration of
    /// which returns a whole `Camp` that is thrown away except the last — precisely the cost the
    /// batch above exists to avoid. A one-kid call site is `updatePlayers([kid], campID:)`, which
    /// is how `addPlayer` already relates to `importPlayers`.
    ///
    /// Whole `Player` values rather than a patch of the fields that moved. The caller is already
    /// holding the patched copy — it read the kid, applied the file's line to them, and is sending
    /// the result back — and a half-shape going down against a whole shape coming up would be two
    /// vocabularies for one write.
    ///
    /// **Deliberately does not touch venue, court or rank.** Those three are camp state. A file
    /// says who is enrolled and how old they are; it has no opinion about where a child stands in
    /// a ladder the camp spent a morning working out, and a re-import that silently reseated
    /// everybody would undo a week of somebody's judgement. `movePlayer` and `reorderCamp` are
    /// where a change of mind about any of the three goes.
    ///
    /// An unknown camp and an unknown kid both throw, and nothing in the batch is written when
    /// they do — the same promise `importPlayers` keeps by checking the venue before its insert.
    func updatePlayers(_ players: [Player], campID: Camp.ID) async throws -> Camp

    /// `8d`'s "not on the new list" — ticked by an admin, then gone.
    ///
    /// Plural for the same reason, and because the tick list *is* the shape of the affordance: an
    /// admin confirms a set of kids who did not come back, and the set leaves together.
    ///
    /// A hard delete, and deliberately not the deactivation `removeStaff` performs. That method's
    /// two stated reasons (`SupabaseRepository.swift:652-655`) are that `attendance.noted_by` and
    /// `ratings.last_by` reference `coaches` with no `on delete` clause, so the delete would fail
    /// outright, and that succeeding would erase *who noted* a fact. Neither reason transfers.
    /// Every foreign key into `players` names an action, so the delete succeeds; and a player is
    /// the **subject** of their attendance and their ratings, not the author of them, so there is
    /// no third party whose record is being rubbed out. The soft alternative was costed and is
    /// worse — see `SupabaseRepository.removePlayers`.
    ///
    /// The ladder is left alone. Everyone else keeps the rating, the court and the order they
    /// already had, and the 1…N numbering closes up behind whoever left. That is the asymmetry
    /// with `importPlayers`: an insert *must* do arithmetic because it has to choose where in the
    /// ladder a new kid goes, and a removal has no such choice to make.
    ///
    /// An unknown camp and an unknown kid both throw, and nothing in the batch goes when they do.
    func removePlayers(_ playerIDs: [Player.ID], campID: Camp.ID) async throws -> Camp

    /// Screen 12's role chips.
    func updateStaffRole(_ staffID: StaffMember.ID, role: Role, campID: Camp.ID) async throws -> Camp
    /// Screen 12's court chips. `nil` means "No court".
    func assignStaff(
        _ staffID: StaffMember.ID, toGroup groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp
    /// Screen 12's "Remove from camp".
    func removeStaff(_ staffID: StaffMember.ID, campID: Camp.ID) async throws -> Camp
}

// MARK: - In-memory implementation

/// An actor so the whole thing is `Sendable` without ceremony, and so the shape of the
/// call sites already matches a network client.
actor InMemoryRepository: SycamoreRepository {

    private var accounts: [Account.ID: Account]
    private var membershipRecords: [Membership]
    private var camps: [Camp.ID: Camp]
    /// The last code we "sent", per email. The offline build accepts any six digits.
    private var pendingChallenges: [String: SignInChallenge] = [:]

    // Section 8's three new shapes. They sit beside the camp graph rather than inside it
    // because `Camp` predates them, and folding courts, blocks and inbox rows into it would
    // mean every existing screen re-decoding three things it does not use. Not `private` —
    // `SectionEightRepository.swift` implements against them from an extension, and an
    // extension cannot reach a private stored property.
    /// Courts are *derived* from the camp graph, not stored — see
    /// `SectionEightRepository.courts(forVenue:campID:)`. Only the closure reason is state,
    /// because nothing in the graph knows a net is down.
    var closedCourts: [Group.ID: String] = [:]
    var sectionEightBlocks: [ScheduleBlock] = []
    var sectionEightInbox: [InboxItem] = []

    /// Empty by default: a fresh install has no account, no memberships and no camps until
    /// someone signs in and creates or joins one.
    ///
    /// These used to default to `SampleData`, which meant the shipped app opened already
    /// populated with a fictional camp. The fixtures are still there and still used — every
    /// `#Preview` and the `AppStore.preview` family pass them in explicitly — but they are no
    /// longer what a real person sees on first launch.
    init(
        accounts: [Account] = [],
        memberships: [Membership] = [],
        camps: [Camp] = []
    ) {
        self.accounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        self.membershipRecords = memberships
        self.camps = Dictionary(uniqueKeysWithValues: camps.map { ($0.id, $0) })
    }

    // MARK: Identity

    func requestSignInCode(email: String) async throws -> SignInChallenge {
        let address = EmailAddress.normalised(email)
        guard EmailAddress.isValid(address) else { throw SycamoreError.invalidEmail }
        let challenge = SignInChallenge(email: address)
        pendingChallenges[address] = challenge
        return challenge
    }

    func verifySignInCode(_ code: String, email: String) async throws -> Account {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else { throw SycamoreError.invalidCode }
        return try signIn(email: email)
    }

    func signInWithApple(identityToken: String) async throws -> Account {
        // A real client would exchange the token for the address behind it. Offline there is
        // nothing to exchange, so we stand in a relay address of the shape Apple actually
        // hands out; `signIn` creates the person if this is their first time.
        try signIn(email: "apple.user@privaterelay.appleid.com")
    }

    func signOut() async throws {
        pendingChallenges.removeAll()
    }

    func account(id: Account.ID) async throws -> Account {
        guard let account = accounts[id] else { throw SycamoreError.unknownAccount }
        return account
    }

    func updateAccount(_ account: Account) async throws -> Account {
        guard accounts[account.id] != nil else { throw SycamoreError.unknownAccount }
        accounts[account.id] = account
        return account
    }

    func deleteAccount(id: Account.ID) async throws {
        guard accounts.removeValue(forKey: id) != nil else { throw SycamoreError.unknownAccount }
        membershipRecords.removeAll { $0.accountID == id }
    }

    /// Offline, an unknown address simply becomes a new person rather than an error, so
    /// the sign-in screens can be driven with anything.
    private func signIn(email: String) throws -> Account {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let existing = accounts.values.first(where: { $0.email.lowercased() == address }) {
            return existing
        }
        let account = Account(
            email: address,
            displayName: address.split(separator: "@").first.map(String.init)?.capitalized ?? "You",
            emergencyPhone: nil
        )
        accounts[account.id] = account
        return account
    }

    // MARK: Camps

    func memberships(forAccount accountID: Account.ID) async throws -> [Membership] {
        membershipRecords.filter { $0.accountID == accountID }
    }

    func camp(id: Camp.ID) async throws -> Camp {
        guard let camp = camps[id] else { throw SycamoreError.unknownCamp }
        return camp
    }

    func joinCamp(inviteCode: String, accountID: Account.ID) async throws -> Membership {
        let needle = Self.normalise(inviteCode)
        guard let camp = camps.values.first(where: { Self.normalise($0.inviteCode) == needle }) else {
            throw SycamoreError.unknownInviteCode
        }
        if let existing = membershipRecords.first(where: { $0.accountID == accountID && $0.campID == camp.id }) {
            return existing
        }
        // A code hands out the lowest useful permission; an admin promotes from Setup.
        let membership = Membership(
            accountID: accountID,
            campID: camp.id,
            role: .worker,
            todayAssignment: nil,
            campName: camp.name,
            campIcon: camp.icon,
            campTint: camp.tint,
            campSummary: camp.summaryLine
        )
        membershipRecords.append(membership)

        var updated = camp
        let account = accounts[accountID]
        updated.staff.append(
            StaffMember(
                accountID: accountID,
                name: account?.displayName ?? "New coach",
                role: .worker,
                phone: account?.emergencyPhone,
                isRoaming: false,
                assignment: nil
            )
        )
        updated.reindex()
        camps[camp.id] = updated
        return membership
    }

    func createCamp(_ draft: CampDraft, accountID: Account.ID) async throws -> Membership {
        guard draft.isValid else { throw SycamoreError.campNameRequired }
        var camp = Camp.make(from: draft, inviteCode: Camp.inviteCode(for: draft.name))
        let account = accounts[accountID]
        camp.staff.append(
            StaffMember(
                accountID: accountID,
                name: account?.displayName ?? "You",
                role: .admin,
                phone: account?.emergencyPhone,
                isRoaming: false,
                assignment: nil
            )
        )
        camp.reindex()
        camps[camp.id] = camp

        let membership = Membership(
            accountID: accountID,
            campID: camp.id,
            role: .admin,
            todayAssignment: nil,
            campName: camp.name,
            campIcon: camp.icon,
            campTint: camp.tint,
            campSummary: camp.summaryLine
        )
        membershipRecords.append(membership)
        return membership
    }

    // MARK: The day

    func setAttendance(
        playerID: Player.ID, day: Weekday, present: Bool, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            camp.setAttendance(playerID: playerID, day: day, present: present)
        }
    }

    func setEarlyPickup(
        playerID: Player.ID, day: Weekday, leavesAt: TimeOfDay?, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            camp.setEarlyPickup(playerID: playerID, day: day, leavesAt: leavesAt)
        }
    }

    // MARK: Order

    func reorderGroup(
        _ groupID: Group.ID, playerIDs: [Player.ID], campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.group(groupID) != nil else { throw SycamoreError.unknownGroup }
            camp.reorder(group: groupID, playerIDs: playerIDs)
        }
    }

    func reorderCamp(_ assignments: [RankAssignment], campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            for assignment in assignments where camp.venue(assignment.venueID) == nil {
                throw SycamoreError.unknownVenue
            }
            camp.applyRankOrder(assignments)
        }
    }

    func movePlayer(
        _ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            guard camp.venue(venueID) != nil else { throw SycamoreError.unknownVenue }
            camp.movePlayer(playerID, toVenue: venueID, group: groupID)
        }
    }

    func partitionCamp(_ campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { $0.partition() }
    }

    func evenOut(_ campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { $0.evenOut() }
    }

    // MARK: Shape

    func updateVenue(_ venue: Venue, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.venue(venue.id) != nil else { throw SycamoreError.unknownVenue }
            camp.upsert(venue)
        }
    }

    func addVenue(campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            let index = camp.venues.count
            let icon = Venue.iconOptions[index % Venue.iconOptions.count]
            let template = camp.orderedVenues.last
            camp.upsert(
                Venue(
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
            )
        }
    }

    /// Goes through `mutate` for the same reason `updateVenue` does: it refreshes the camp
    /// picker's denormalised `Membership.campName`, which is the copy of this field anybody not
    /// currently inside the camp is looking at.
    func renameCamp(name: String, sport: Sport, campID: Camp.ID) async throws -> Camp {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw SycamoreError.campNameRequired }
        return try mutate(campID) { camp in
            camp.name = trimmed
            camp.sport = sport
        }
    }

    /// Written as given, the way `campDaysRow` sends it. This repository stands in for Postgres,
    /// and quietly correcting an empty week here would hide from previews and tests exactly the
    /// bug `camps_camp_days_check` exists to catch.
    ///
    /// Through `mutate` like every other camp write, though not for the reason `renameCamp` is:
    /// `Membership` has no field the days can reach, so the projection refresh at the end of it
    /// is a no-op here. It costs a dictionary walk offline; `AppStore` is where the equivalent
    /// refresh is a network round trip, and that one is skipped.
    func setCampDays(_ days: CampDays, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            camp.days = days
        }
    }

    func rollInviteCode(campID: Camp.ID) async throws -> Camp {
        // Every other camp's code. Postgres has a UNIQUE index on `camps.invite_code` and
        // `SupabaseRepository` finds a collision by being rejected; here the whole set is in
        // hand, so the collision is avoided instead of discovered.
        let taken = Set(
            camps.values.lazy.filter { $0.id != campID }.map { Self.normalise($0.inviteCode) }
        )
        return try mutate(campID) { camp in
            camp.inviteCode = Self.freeInviteCode(unlike: camp.inviteCode, avoiding: taken)
        }
    }

    func updateStaffRole(_ staffID: StaffMember.ID, role: Role, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            camp.setRole(role, forStaff: staffID)
        }
    }

    func assignStaff(
        _ staffID: StaffMember.ID, toGroup groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            if let groupID, camp.group(groupID) == nil { throw SycamoreError.unknownGroup }
            camp.assignStaff(staffID, toGroup: groupID)
        }
    }

    func removeStaff(_ staffID: StaffMember.ID, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            camp.removeStaff(staffID)
        }
    }

    // MARK: Enrolment

    func addPlayer(
        _ player: Player, toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> Camp {
        try await importPlayers([player], toVenue: venueID, campID: campID)
    }

    func importPlayers(
        _ players: [Player], toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.venues.contains(where: { $0.id == venueID }) else {
                throw SycamoreError.unknownVenue
            }

            // The back of the venue's ladder, in the order they were given. `reindex()` in
            // `mutate` assigns the real ranks afterwards — setting them here would be guessing
            // at numbers it is about to overwrite.
            //
            // Counted off where the venue's block *ends* in the camp ladder, not off how many
            // kids are standing in it. `overallRank` is camp-wide, so a venue holding ranks
            // 51…100 has a head-count of 50: counting off the head-count handed a new arrival
            // rank 50 and made them the venue's top kid instead of its last.
            let tail = (camp.players.filter { $0.venueID == venueID }.map(\.overallRank).max() ?? 0) + 1

            // Everyone from `tail` down slides back by the size of the intake to make room. That
            // leaves every existing kid in the order they were already in, and it keeps the
            // arrivals from tying with whoever holds `tail` now — `reindex()` sorts on
            // `overallRank` alone, so a tie is settled by whatever `sort` happens to do, which is
            // not something to leave a child's place in the ladder to.
            for index in camp.players.indices where camp.players[index].overallRank >= tail {
                camp.players[index].overallRank += players.count
            }

            for (offset, player) in players.enumerated() {
                var joined = player
                joined.venueID = venueID
                // Deliberately no group. A kid with no court shows up in Groups' unassigned
                // band, which is where somebody decides where they belong — as opposed to being
                // dropped into court 1 by an import and quietly outranking kids already there.
                joined.groupID = nil
                joined.overallRank = tail + offset
                joined.courtRank = 0
                camp.players.append(joined)
            }
        }
    }

    func updatePlayers(_ players: [Player], campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            // Keyed once and used for both jobs below. A kid named twice in one batch takes the
            // last line, which is what a PATCH per row would also do.
            let patches = Dictionary(players.map { ($0.id, $0) }) { _, last in last }

            // Every id checked before the first field is written, and checked against a set rather
            // than searched for in the roster one at a time — a forty-row file is one pass over a
            // hundred children, not forty. `mutate` edits a copy and only stores it once `edit`
            // has returned, so throwing here leaves the camp exactly as it was: the all-or-nothing
            // `importPlayers` gets from PostgREST rejecting a whole array, arrived at from the
            // other side.
            let enrolled = Set(camp.players.map(\.id))
            guard patches.keys.allSatisfy(enrolled.contains) else {
                throw SycamoreError.unknownPlayer
            }

            for index in camp.players.indices {
                guard let patch = patches[camp.players[index].id] else { continue }
                // `Player.keepingPlacement(of:)` rather than an assignment per file-owned field,
                // and `SupabaseRepository.updatePlayers` reads the same method. This was six
                // assignments here and four exclusions there — one rule in two polarities, and
                // the inclusive one silently drops any field added to `Player` later.
                camp.players[index] = patch.keepingPlacement(of: camp.players[index])
            }
        }
    }

    /// Removing from `camp.players` is the whole implementation, and that is worth saying out
    /// loud. `mutate` ends in `reindex()`, which renumbers `overallRank` 1…N
    /// (`Models.swift:890-894`), closes the court-rank gaps left behind (`:904-912`) and
    /// recomputes every court's `playerCount` and `presentCount` (`:914-919`). So nothing here
    /// touches the ladder: everyone keeps the place they were already in and the numbering closes
    /// up behind whoever left. `SupabaseRepository.removePlayers` reaches the same answer by
    /// deriving the ladder at read time — no `writeLadder` call there either.
    func removePlayers(_ playerIDs: [Player.ID], campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            // One pass over the roster rather than one per tick, and the same all-or-nothing as
            // `updatePlayers`: `mutate` stores nothing when `edit` throws.
            let leaving = Set(playerIDs)
            guard leaving.isSubset(of: Set(camp.players.map(\.id))) else {
                throw SycamoreError.unknownPlayer
            }

            camp.players.removeAll { leaving.contains($0.id) }
            // What hung off them goes too, which is what Postgres does of its own accord — every
            // foreign key into `players` cascades. Left behind, an attendance row would be a fact
            // about nobody and a history entry would belong to a sheet that can no longer be
            // opened.
            camp.attendance.removeAll { leaving.contains($0.playerID) }
            camp.history.removeAll { leaving.contains($0.playerID) }
        }
    }

    // MARK: Plumbing

    /// Internal rather than private, the way `sectionEightBlocks` above it is and for the same
    /// reason: `SectionEightRepository.swift` holds half of this actor's conformance, and every
    /// camp-graph write in it needs the one path that reindexes and refreshes the projections.
    /// `camps` itself stays private — this is the only door.
    func mutate(_ campID: Camp.ID, _ edit: (inout Camp) throws -> Void) throws -> Camp {
        guard var camp = camps[campID] else { throw SycamoreError.unknownCamp }
        try edit(&camp)
        camp.reindex()
        camps[campID] = camp
        refreshMembershipProjections(for: camp)
        return camp
    }

    /// Keeps the camp picker's denormalised copies honest after a write.
    private func refreshMembershipProjections(for camp: Camp) {
        for index in membershipRecords.indices where membershipRecords[index].campID == camp.id {
            membershipRecords[index].campName = camp.name
            membershipRecords[index].campIcon = camp.icon
            membershipRecords[index].campTint = camp.tint

            let accountID = membershipRecords[index].accountID
            guard let record = camp.staff.first(where: { $0.accountID == accountID }),
                  let assignment = record.assignment,
                  let court = camp.group(assignment.groupID)
            else {
                membershipRecords[index].todayAssignment = nil
                membershipRecords[index].campSummary = camp.summaryLine
                continue
            }
            membershipRecords[index].role = record.role
            membershipRecords[index].campSummary = nil
            // Emoji and tint are drawn on top of each other in Profile's "On today" tile, so
            // they come from one read of one venue. Taking the emoji off the assignment's
            // snapshot and the tint off the venue is what let the tile render the old emoji on
            // the new colour. The assignment is the fallback for a venue that has gone missing.
            let venue = camp.venue(assignment.venueID)
            membershipRecords[index].todayAssignment = TodayAssignment(
                venueID: assignment.venueID,
                venueName: venue?.name ?? assignment.venueName,
                venueIcon: venue?.icon ?? assignment.venueIcon,
                venueTint: venue?.tint ?? camp.tint,
                groupID: court.id,
                groupLabel: court.label,
                kidCount: court.playerCount,
                presentCount: court.presentCount,
                rankedAt: membershipRecords[index].todayAssignment?.rankedAt
            )
        }
    }

    /// `SYC-4821`, `syc4821` and `SYC 4821` are the same code.
    private static func normalise(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// A code with the same three letters, four different digits, and nobody else already on it.
    ///
    /// Only the digits move. The letters are the camp's initials — they are what makes a code
    /// recognisable when somebody reads it down a phone, and they are already in the CHECK the
    /// column carries. `SupabaseRepository.rollInviteCode` rerolls exactly the same way.
    ///
    /// Rolls once, then walks. The roll is what stops a new code from being the obvious next
    /// one; the walk is what makes this total, and it cannot spin because four digits are ten
    /// thousand slots and it visits each of them at most once.
    private static func freeInviteCode(unlike current: String, avoiding taken: Set<String>) -> String {
        let mine = normalise(current)
        let letters = mine.prefix(3)
        // The same `CMP` the model itself falls back to for a name with no usable letters, for
        // the same reason `SupabaseRepository.acceptableInviteCode` does: `^[A-Z]{3}-[0-9]{4}$`
        // is what the column will take, and a camp called "Été Tennis" does not reach it.
        let prefix = letters.count == 3 && letters.allSatisfy(\.isLetter) ? String(letters) : "CMP"
        let start = Int.random(in: 0...9999)
        for step in 0..<10_000 {
            // `String(format:)` and not a `FormatStyle`: a code is data checked against a regex,
            // not a number shown to somebody, and a locale-aware formatter would pad it with
            // whatever digits the reader's locale uses. `٠٠٤٢` is not `[0-9]{4}`.
            let code = "\(prefix)-\(String(format: "%04d", (start + step) % 10_000))"
            let key = normalise(code)
            if key != mine, !taken.contains(key) { return code }
        }
        // Ten thousand camps sharing three initials, which the offline build cannot reach.
        // Handing the code back unchanged beats failing a settings tap over it.
        return current
    }
}
