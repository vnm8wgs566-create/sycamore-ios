//
//  SupabaseRepository+Enrolment.swift
//  Sycamore
//
//  Getting a person and a camp attached to each other: the invite code, the membership row, the
//  staff row that follows from it, and the two inserts that have to survive a name already taken.
//
//  Two globally unique columns make this less mechanical than it looks. `camps.invite_code` is
//  derived from the camp's name by an FNV fold, so two camps called "Summer Tennis" produce the
//  same code. `sites.name` is unique across the whole project, and screen 4 names its venues
//  "Venue 1" and "Venue 2". Both inserts therefore have to be able to try again.
//
//  Then, below the fold, the same question asked of kids rather than coaches: the three writes a
//  roster file makes — bring the week in, bring it in again next week, and take off whoever did
//  not come back. They are three different bargains with atomicity, and each one says which it
//  struck and why at the method that strikes it.
//

import Foundation

extension SupabaseRepository {

    // MARK: Membership

    /// The picker's row for one camp, with the venue and kid counts already on it.
    ///
    /// Goes back through `memberships(forAccount:)` rather than building the projection here:
    /// `joinCamp` and `createCamp` both promise the same shape the picker draws, and two places
    /// computing "3 venues · 74 kids" is two places for it to go stale.
    func membership(forAccount accountID: Account.ID, camp campID: Camp.ID) async throws -> Membership {
        let all = try await memberships(forAccount: accountID)
        guard let membership = all.first(where: { $0.campID == campID }) else {
            throw SycamoreError.unknownCamp
        }
        return membership
    }

    /// Every person at a camp needs a `coaches` row, because that is what the app calls a
    /// `StaffMember` — it is what carries their court, their phone and their name onto Setup's
    /// staff card. `memberships` says they belong; this says where they stand.
    ///
    /// Reactivates rather than duplicating: "Remove from camp" only deactivates, so someone
    /// rejoining with the same code must get their row back, not a second one.
    func adoptStaffRow(accountID: Account.ID, campID: Camp.ID, role: Role) async throws {
        let existing: [CoachRecord] = try await db.select(
            Relation.coaches, .select("*").eq("account_id", accountID).eq("camp_id", campID)
        )
        if let found = existing.first {
            guard !found.active else { return }
            try await db.update(
                Relation.coaches,
                set: ["active": .bool(true), "camp_id": .uuid(campID)],
                where: PostgRESTQuery().eq("id", found.id)
            )
            return
        }

        let account = try await account(id: accountID)
        try await db.insert(Relation.coaches, [RowValues([
            "name": .text(account.displayName),
            "camp_id": .uuid(campID),
            "account_id": .uuid(accountID),
            // `profiles.id` *is* `auth.users.id`, so this is the same value — carried onto the
            // row the eventual per-camp RLS policy will check against.
            "auth_uid": .uuid(accountID),
            "role": .text(PostgresEnum.text(role)),
            "role_label": .text(PostgresEnum.label(role)),
            "phone": .text(account.emergencyPhone),
            "is_roaming": .bool(role.roamsByDefault),
            "is_admin": .bool(role.isAdmin),
            "active": .bool(true),
        ])])
    }

    // MARK: Inserts that can collide

    func insertCamp(_ camp: Camp) async throws {
        var code = Self.acceptableInviteCode(camp.inviteCode)
        for _ in 0..<Self.collisionRetries {
            do {
                try await db.insert(Relation.camps, [RowValues([
                    "id": .uuid(camp.id),
                    "name": .text(camp.name),
                    "sport": .text(PostgresEnum.text(camp.sport)),
                    "invite_code": .text(code),
                    "icon": .text(camp.icon),
                    "tint": .text(camp.tint.rawValue),
                    // Written rather than left to the column's DEFAULT of 31, which would be the
                    // right week for four camps in five and silently the wrong one for the fifth.
                    // `Camp.make(from:)` has already substituted the default for a draft that
                    // somehow carried no days, so this is never the 0 the CHECK refuses.
                    "camp_days": .int(camp.days.rawValue),
                ])])
                return
            } catch let error as SupabaseError where error.isUniqueViolation {
                // The letters carry the camp's name and are what makes a code recognisable; only
                // the digits are arbitrary, so only the digits are rerolled.
                code = "\(code.prefix(3))-\(String(format: "%04d", Int.random(in: 0...9999)))"
            }
        }
        throw SupabaseError.rejected(
            status: 409, message: "Couldn't find a free invite code for that camp."
        )
    }

    /// A venue whose name is taken keeps its number and gains four characters, which is ugly and
    /// visible — deliberately. The alternative is failing the whole camp creation over a name the
    /// app chose for the person, and the venue sheet renames it in two taps.
    func insertSite(_ venue: Venue, campID: Camp.ID) async throws {
        var name = venue.name
        for _ in 0..<Self.collisionRetries {
            var row = Self.siteRow(venue, campID: campID)
            row["id"] = .uuid(venue.id)
            row["name"] = .text(name)
            do {
                try await db.insert(Relation.sites, [row])
                return
            } catch let error as SupabaseError where error.isUniqueViolation {
                name = "\(venue.name) \(UUID().uuidString.prefix(4))"
            }
        }
        throw SupabaseError.rejected(
            status: 409, message: "Couldn't find a free name for that venue."
        )
    }

    private static var collisionRetries: Int { 6 }

    /// The columns `8t`'s "Camp name & sport" row writes, and only those.
    ///
    /// Not the whole camp. `id` is set once at insert, `icon` and `tint` are nobody's to change
    /// from this row, and `invite_code` has its own write — a rename that carried the code would
    /// be able to undo a roll that happened between the read and the PATCH. See `RowValues`:
    /// sending exactly what changed is also what keeps two admins editing different fields of
    /// the same camp from silently overwriting each other.
    static func campRow(name: String, sport: Sport) -> RowValues {
        [
            "name": .text(name),
            // `camps.sport` has no `sport_label` column beside it, so `Sport.other(label:)` goes
            // down as plain `other` and comes back with its label gone. `PostgresEnum` says so.
            "sport": .text(PostgresEnum.text(sport)),
        ]
    }

    /// The one column `8t`'s "Days the camp runs" row writes.
    ///
    /// Its own payload rather than a third field on `campRow`, which is the same rule that file
    /// states: send exactly what moved. A days row that also PATCHed `name` and `sport` would be
    /// able to undo a rename made from another device between this screen's last read and this
    /// write — the precise failure the doc above says the narrow payload exists to prevent.
    ///
    /// Sent as the mask, unclamped. An empty set is 0 and `camps_camp_days_check` refuses it —
    /// deliberately: every caller has come through an editor that will not let the last day go
    /// out, so a 0 arriving here is a bug in that editor, and a 400 naming the constraint is a
    /// better way to hear about it than a week the reader did not choose being written in silence.
    static func campDaysRow(_ days: CampDays) -> RowValues {
        ["camp_days": .int(days.rawValue)]
    }

    // MARK: Invite codes

    /// `8t`'s "Roll a new code".
    ///
    /// The retry `insertCamp` runs, pointed at `update` instead of `insert`. It has to be a
    /// retry rather than a lookup: `camps.invite_code` is UNIQUE across the whole project, and
    /// while a signed-in user *may* select every camp row, pulling all of them to avoid a
    /// one-in-ten-thousand clash would be a far worse trade than being told about it.
    func rollInviteCode(campID: Camp.ID) async throws -> Camp {
        try await serialised(campID) {
            let current = try await camp(id: campID).inviteCode
            var code = Self.rerolledInviteCode(current)
            for _ in 0..<Self.collisionRetries {
                do {
                    try await db.update(
                        Relation.camps,
                        set: ["invite_code": .text(code)],
                        where: PostgRESTQuery().eq("id", campID)
                    )
                    return try await camp(id: campID)
                } catch let error as SupabaseError where error.isUniqueViolation {
                    code = Self.rerolledInviteCode(code)
                }
            }
            throw SupabaseError.rejected(
                status: 409, message: "Couldn't find a free invite code for that camp."
            )
        }
    }

    /// A code with the same three letters and four different digits.
    ///
    /// Only the digits move, for the same reason `insertCamp` only rerolls the digits: the
    /// letters carry the camp's name and are what makes a code recognisable read down a phone.
    private static func rerolledInviteCode(_ code: String) -> String {
        let accepted = acceptableInviteCode(code)
        var digits = Int.random(in: 0...9999)
        // One roll in ten thousand comes back with the digits it started from, and a "Roll a new
        // code" that changed nothing would read as broken rather than as lucky. Nudging past it
        // beats rolling again until it differs, which is a loop with no bound on it.
        if digits == Int(accepted.suffix(4)) { digits = (digits + 1) % 10_000 }
        return "\(accepted.prefix(3))-\(String(format: "%04d", digits))"
    }

    /// `SYC-4821`, `syc4821` and `SYC 4821` are the same code — the same rule
    /// `InMemoryRepository` applies — put back into the shape the column's CHECK demands.
    ///
    /// Exactly seven characters, not "at least seven": `InMemoryRepository` compares whole
    /// normalised strings, so `SYC48210` matches nothing there and must not quietly join
    /// `SYC-4821` here.
    static func formattedInviteCode(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard cleaned.count == 7 else { return nil }
        let letters = cleaned.prefix(3)
        let digits = cleaned.dropFirst(3)
        guard letters.allSatisfy(\.isLetter), digits.allSatisfy(\.isNumber) else { return nil }
        return "\(letters)-\(digits)"
    }

    /// A code Postgres will accept.
    ///
    /// `Camp.inviteCode(for:)` takes the first three letters of the camp's name, and
    /// `Character.isLetter` is true of `É` and of `ェ` — but `camps.invite_code` is checked
    /// against `^[A-Z]{3}-[0-9]{4}$`, so a camp called "Été Tennis" is refused outright and
    /// retrying the insert cannot help. The digits carry the name's fold and are kept; only a
    /// prefix the column will not take is replaced, with the same `CMP` the model itself falls
    /// back to for a name with no letters at all.
    private static func acceptableInviteCode(_ raw: String) -> String {
        if let accepted = formattedInviteCode(raw) { return accepted }
        let digits = raw.filter(\.isNumber).suffix(4)
        return digits.count == 4
            ? "CMP-\(digits)"
            : "CMP-\(String(format: "%04d", Int.random(in: 0...9999)))"
    }
}

// MARK: - Enrolment

extension SupabaseRepository {

    /// How many PATCHes `updatePlayers` keeps in the air at once.
    ///
    /// Six because that is roughly what a phone's URL session will run against one host before it
    /// queues them itself: past that the requests are not concurrent, they are merely all
    /// started, and the only thing the extra width buys is sockets. Deliberately not tuned
    /// against a measurement — there is no batch to measure yet, and a number chosen to be
    /// unremarkable is easier to raise later than one chosen to look precise.
    static let concurrentWrites = 6

    func addPlayer(
        _ player: Player, toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> Camp {
        try await importPlayers([player], toVenue: venueID, campID: campID)
    }

    /// One insert for the whole roster.
    ///
    /// Not a loop over `addPlayer`: a week's intake is forty-odd kids, and forty sequential
    /// round-trips is the difference between an import that feels instant and one somebody
    /// watches happen. It also makes the import atomic — PostgREST rejects the whole array if any
    /// row fails a CHECK, and half a roster is worse than none because nobody can tell which half
    /// arrived.
    ///
    /// No `ratings` rows are written here. The `seed_rating` trigger on `players` creates one per
    /// kid at the default 1500, which is exactly right for somebody nobody has assessed yet — and
    /// `overallRank` is read from `ratings.rating`, so a new arrival sorts among the unplaced
    /// rather than landing at a rank the camp never gave them.
    func importPlayers(
        _ players: [Player], toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> Camp {
        guard !players.isEmpty else { return try await camp(id: campID) }

        return try await serialised(campID) {
            let before = try await camp(id: campID)
            guard before.venues.contains(where: { $0.id == venueID }) else {
                throw SycamoreError.unknownVenue
            }

            try await db.insert(
                Relation.players,
                players.map { Self.playerRow($0, venueID: venueID) }
            )
            return try await camp(id: campID)
        }
    }

    /// One filtered PATCH per kid the file actually changes, sent together.
    ///
    /// The shape `writePlacements` already uses for exactly this problem
    /// (`SupabaseRepository+Graph.swift:142-165`): skip the rows that did not move, then run what
    /// is left concurrently, so the wall clock is roughly one round trip rather than forty. Both
    /// halves matter here and the first one matters most, because the whole point of this method
    /// is a file being re-read a week later — most of its lines say what the row already says, and
    /// a re-import that changed nothing should cost nothing. It is also why the `before` camp is a
    /// full `camp(id:)` read rather than the two narrow selects `writeAttendance` gets away with
    /// (`SupabaseRepository+Graph.swift:281-298`): the graph is not loaded to validate the ids, it
    /// is loaded because the current values are what the file is being compared against.
    ///
    /// The fan-out is **capped**, which is where this parts company with `writePlacements`
    /// (`SupabaseRepository+Graph.swift:142-165`) rather than copying it. That one groups by
    /// destination slot, so a hundred kids is a dozen requests and the width takes care of
    /// itself. Nothing here can be grouped — every payload is a different kid's different fields
    /// — so the width *is* the batch, and the batch is a whole camp on the one re-import that
    /// changes everyone at once: a season rolling over and every age going up by a year. A
    /// hundred simultaneous sockets is not a thing to do to somebody's phone on a court, and the
    /// cost of the cap is wall clock nobody is watching — `ceil(N / concurrentWrites)` waves
    /// instead of one.
    ///
    /// **Deliberately not `db.upsert(Relation.players, rows, onConflict: "id")`**, which is the
    /// tempting single-request answer and has to be argued away rather than merely not chosen.
    /// `players.site_id` is nullable, so a kid another admin deleted between the read above and
    /// this write does *not* fail a NOT NULL — their row is simply absent, the upsert falls
    /// through to an **insert**, and it inserts with `site_id = null`. That row then fails
    /// `players_member`, because `null in (…)` is null rather than true, and PostgREST rejects the
    /// **entire array**: twenty good writes lost to one vanished kid, under "new row violates
    /// row-level security policy", an error naming nothing a person can act on. A filtered PATCH
    /// for a kid who is gone matches zero rows and answers 204, which is the honest result —
    /// there is nothing left there to update.
    ///
    /// And this is the opposite answer from `importPlayers` above, on purpose. That insert must
    /// not half-succeed: half an insert means duplicate kids the moment somebody retries, and
    /// nobody can tell which half arrived. Half an update is a different thing entirely — some
    /// kids have their new age and some do not, the camp comes back from this same call so
    /// re-running the reconciliation shows exactly what is still outstanding, and running it again
    /// is idempotent. Different risk, different answer, both written down where they are made.
    func updatePlayers(_ players: [Player], campID: Camp.ID) async throws -> Camp {
        guard !players.isEmpty else { return try await camp(id: campID) }

        return try await serialised(campID) {
            let before = try await camp(id: campID)
            // Keyed both ways, so the checks below are one pass over the roster rather than one
            // per line. A kid named twice in a file takes the last line — which is also what two
            // PATCHes would leave behind, arrived at without the second request.
            let patches = Dictionary(players.map { ($0.id, $0) }) { _, last in last }
            let current = Dictionary(before.players.map { ($0.id, $0) }) { first, _ in first }

            // `camp(id:)` scopes players through `sites.camp_id`, so a kid at somebody else's camp
            // is `unknownPlayer` here exactly as they are offline — and every id is checked before
            // the first PATCH, so nothing in the batch is written when one fails.
            var changed: [Player] = []
            for (playerID, patch) in patches {
                guard let existing = current[playerID] else { throw SycamoreError.unknownPlayer }
                // `Player.keepingPlacement(of:)` is the same method `InMemoryRepository` writes
                // with, so "this line changes something" and "this is what gets written" cannot
                // drift apart. It carries the argument for stating the rule as four exclusions.
                if patch.keepingPlacement(of: existing) != existing {
                    changed.append(patch)
                }
            }
            // `before` rather than a fresh read: nothing was written, so it is already the answer.
            guard !changed.isEmpty else { return before }

            // Bound out of the actor because the tasks below run concurrently, which is legal
            // because `PostgRESTClient` is a `Sendable` struct. `writePlacements` does the same.
            let db = self.db
            try await withThrowingTaskGroup(of: Void.self) { tasks in
                func patch(_ player: Player) {
                    tasks.addTask {
                        try await db.update(
                            Relation.players,
                            set: Self.playerFields(player),
                            where: PostgRESTQuery().eq("id", player.id)
                        )
                    }
                }
                // Prime the window, then add one for each that finishes, so at most
                // `concurrentWrites` requests are ever in flight. `next()` rethrows, so the first
                // failure still leaves the group — and its remaining tasks are cancelled on the
                // way out exactly as `waitForAll` would have left them.
                var pending = changed.makeIterator()
                for _ in 0..<Self.concurrentWrites {
                    guard let player = pending.next() else { break }
                    patch(player)
                }
                while try await tasks.next() != nil {
                    guard let player = pending.next() else { continue }
                    patch(player)
                }
            }
            return try await camp(id: campID)
        }
    }

    /// One filtered DELETE.
    ///
    /// Filtered, so `PostgRESTClient`'s `unfilteredWrite` guard (`PostgRESTClient.swift:133`) is
    /// satisfied — and atomic for the same reason the import is: it is one statement, and Postgres
    /// applies all of it or none of it.
    ///
    /// A hard delete, deliberately not the deactivation `removeStaff` performs; the protocol says
    /// why that precedent's two reasons do not transfer. The soft alternative was costed and is
    /// the worse trade: `players` would need a new column *and* a filter at every Swift site that
    /// reads the table — `SupabaseRepository.swift:228`, `:337`,
    /// `SupabaseRepository+SectionEight.swift:52`, and the ladder assembled in
    /// `SupabaseRepository+Graph.swift:43` — *and* the three SQL views that join `players`:
    /// `today_courts`, `roster_today` and `player_scores` (`20260805141707:160-199`). Miss any one
    /// of those seven and a removed kid is still visible on one screen while being gone from the
    /// others, which is a worse fault than the one being avoided.
    ///
    /// **Nothing here writes ranks, and that is the point.** There is no `players.overall_rank`
    /// column — the ladder is derived at read time by sorting on `ratings.rating` descending with
    /// the player's id breaking ties (`SupabaseRepository+Graph.swift:39-58`). So the departing
    /// kid's `ratings` row cascades away with them, everybody else keeps the rating they had, and
    /// the derived 1…N closes up by itself. No `writeLadder` call, and none wanted. It is the
    /// asymmetry with `importPlayers`: an insert has to choose where in the ladder a new arrival
    /// goes, and a removal has no such choice to make.
    ///
    /// The delete reaches `feedback` only once `20260808230500_feedback_player_cascade.sql` is
    /// applied. Until then `feedback.player_id` is `on delete set null`, and a removed kid leaves
    /// notes behind that no policy can read and no request can reach.
    func removePlayers(_ playerIDs: [Player.ID], campID: Camp.ID) async throws -> Camp {
        // PostgREST rejects `in.()`, so an empty tick list is no request at all rather than one
        // that cannot succeed — the rule `PostgRESTQuery.within` states and leaves to its callers.
        guard !playerIDs.isEmpty else { return try await camp(id: campID) }

        return try await serialised(campID) {
            // One narrow select rather than the whole graph, and this is the difference between
            // this method and `updatePlayers` above. That one loads the camp because the current
            // values are what the file is compared against; this one has nothing to compare and
            // needs a single fact — do these ids belong to this camp. `camp(id:)` is eight
            // selects in two waves, including a week of attendance and the whole inbox, and every
            // row of it would be decoded and thrown away.
            //
            // Scoped through `sites!inner(camp_id)`, which is how `writeAttendance` asks the same
            // question of one kid (`SupabaseRepository+Graph.swift:284-286`) — `players` carries
            // no `camp_id` of its own, so the site is the only route to one. Counting the rows
            // back is enough: the filter cannot return an id that was not asked for, so fewer
            // rows than ids means at least one kid is somebody else's, which is `unknownPlayer`
            // exactly as it is offline. Before the DELETE, so a tick list naming another camp's
            // kid takes none of this camp's with it.
            // `*` rather than `id`, as `writeAttendance` also asks for: `PlayerRecord.firstName`
            // and `.isReturning` are non-optional, so an id-only projection decodes to nothing.
            // The row is still one relation's worth instead of the graph's.
            let mine: [PlayerRecord] = try await db.select(
                Relation.players,
                .select("*,sites!inner(camp_id)")
                    .within("id", playerIDs)
                    .eq("sites.camp_id", campID)
            )
            guard Set(mine.map(\.id)) == Set(playerIDs) else {
                throw SycamoreError.unknownPlayer
            }
            try await db.delete(Relation.players, where: PostgRESTQuery().within("id", playerIDs))
            return try await camp(id: campID)
        }
    }

    /// The columns a roster file is allowed to speak to, and only those.
    ///
    /// Named separately from `playerRow` because `updatePlayers` wants exactly this set and must
    /// name neither `id` nor `site_id`: the first is the row's identity, and the second is the
    /// venue — camp state that a file has no opinion about, so a PATCH carrying it would let a
    /// re-import reseat a kid `movePlayer` had deliberately placed. One definition, so the wire
    /// names and the `gender` conversion cannot drift between the insert and the update.
    ///
    /// `gender` goes through `PostgresEnum.text`, **not** `Gender.rawValue`. The enum's raw values
    /// are lowercase and `players_gender_check` demands `'M','F','X'` — the raw value fails every
    /// write.
    ///
    /// `last_name` and `age` are the two columns a roster is allowed to leave null, and both go as
    /// whatever the file said. Null rather than `""` for a kid with no surname:
    /// `players_last_name_len` admits null or 1…60 characters, and an empty string fails it.
    static func playerFields(_ player: Player) -> RowValues {
        [
            "first_name": .text(player.firstName),
            "last_initial": .text(player.lastInitial),
            "last_name": .text(player.lastName),
            "age": .int(player.age),
            "gender": .text(PostgresEnum.text(player.gender)),
            "is_returning": .bool(player.isReturning),
        ]
    }

    /// One kid, as an insert: what a file can say, plus who they are and where they are going.
    ///
    /// This row is the only thing that survives the insert — the camp is re-read from Postgres
    /// afterwards — so a surname the roster carried is written here or lost.
    ///
    /// `group_id` is deliberately absent. A new kid has no court until somebody puts them on one,
    /// which is what Groups' unassigned band is for; defaulting them onto court 1 would quietly
    /// outrank kids already standing there.
    static func playerRow(_ player: Player, venueID: Venue.ID) -> RowValues {
        var row = playerFields(player)
        row["id"] = .uuid(player.id)
        row["site_id"] = .uuid(venueID)
        return row
    }
}
