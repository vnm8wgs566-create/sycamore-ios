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

    /// `gender` takes `Gender.symbol`, not `rawValue`. The enum's raw values are lowercase and
    /// the column's CHECK demands `'M','F','X'` — sending the raw value fails every insert.
    ///
    /// `last_name` and `age` are the two columns an import is allowed to leave null, and both go
    /// as whatever the file said. This row is the only thing that survives the insert — the camp
    /// is re-read from Postgres afterwards — so a surname the roster carried is lost here or not
    /// at all. Null rather than `""` for a kid with no surname: the column admits null or 1…60
    /// characters, and an empty string fails it.
    ///
    /// `group_id` is deliberately absent. A new kid has no court until somebody puts them on one,
    /// which is what Groups' unassigned band is for; defaulting them onto court 1 would quietly
    /// outrank kids already standing there.
    static func playerRow(_ player: Player, venueID: Venue.ID) -> RowValues {
        [
            "id": .uuid(player.id),
            "first_name": .text(player.firstName),
            "last_initial": .text(player.lastInitial),
            "last_name": .text(player.lastName),
            "age": .int(player.age),
            "gender": .text(PostgresEnum.text(player.gender)),
            "is_returning": .bool(player.isReturning),
            "site_id": .uuid(venueID),
        ]
    }
}
