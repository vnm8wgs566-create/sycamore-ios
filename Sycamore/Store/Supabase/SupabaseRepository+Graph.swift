//
//  SupabaseRepository+Graph.swift
//  Sycamore
//
//  Assembling a `Camp` out of six result sets, and writing one back down.
//
//  Split off `SupabaseRepository.swift` so that file reads as the protocol it implements — one
//  method per screen affordance, in the order `Repository.swift` declares them — instead of
//  being interleaved with the joins underneath.
//

import Foundation

// MARK: - Reading the graph

extension SupabaseRepository {

    /// Courts, numbered.
    ///
    /// `number` is the 1-based position inside the venue rather than `rank_order` itself: a chip
    /// reads `C3` meaning "the third court here", and a reorder is free to leave `rank_order`
    /// sparse. Groups belonging to a site outside this camp fall out, which is what makes this
    /// safe to hand every group the venue filter returned.
    static func courts(from records: [GroupRecord], venues: [Venue]) -> [Group] {
        let byVenue = Dictionary(grouping: records, by: \.siteId)
        return venues.flatMap { venue -> [Group] in
            // The same arithmetic `Camp.syncGroups` uses, so a court's ceiling does not change
            // depending on whether it was created here or offline.
            let capacity = max(1, venue.playerMax / max(1, venue.groupCount))
            return (byVenue[venue.id] ?? [])
                .sorted { $0.rankOrder == $1.rankOrder ? $0.name < $1.name : $0.rankOrder < $1.rankOrder }
                .enumerated()
                .map { Group($1, number: $0 + 1, capacity: capacity) }
        }
    }

    /// The ladder.
    ///
    /// There is no `players.overall_rank` column. `ratings.rating` is the only order over players
    /// the schema holds, and `roster_today` already sorts by it, so it is the ladder — descending,
    /// with the player's id breaking ties so two kids on the same rating do not trade places
    /// between one load and the next. `courtRank` falls out of the same sequence.
    static func players(from records: [PlayerRecord], ratings: [RatingRecord]) -> [Player] {
        let rating = Dictionary(ratings.map { ($0.playerId, $0.rating) }, uniquingKeysWith: { first, _ in first })
        let ladder = records.sorted { lhs, rhs in
            let left = rating[lhs.id] ?? -.greatestFiniteMagnitude
            let right = rating[rhs.id] ?? -.greatestFiniteMagnitude
            return left == right ? lhs.id.uuidString < rhs.id.uuidString : left > right
        }

        var seats: [Group.ID: Int] = [:]
        return ladder.enumerated().map { index, record in
            var courtRank = 0
            if let groupID = record.groupId {
                courtRank = (seats[groupID] ?? 0) + 1
                seats[groupID] = courtRank
            }
            return Player(record, overallRank: index + 1, courtRank: courtRank)
        }
    }

    /// Needs `camp.venues` and `camp.groups` already filled: a `CourtAssignment` carries the
    /// venue's name and emoji so a chip draws without walking back to the graph.
    static func staff(from records: [CoachRecord], camp: Camp) -> [StaffMember] {
        records.map { record in
            guard let groupID = record.groupId,
                  let court = camp.group(groupID),
                  let venue = camp.venue(court.venueID)
            else { return StaffMember(record, assignment: nil) }

            return StaffMember(record, assignment: CourtAssignment(
                venueID: venue.id,
                venueName: venue.name,
                venueIcon: venue.icon,
                groupID: court.id,
                groupNumber: court.number,
                groupLabel: court.label
            ))
        }
    }

    /// One row per kid per day, from rows already narrowed to the morning session.
    ///
    /// `attendance` is keyed on `(player_id, day, session)` and the app has no notion of a morning
    /// and an afternoon — a kid is either here today or not. Every read here filters to `morning`
    /// and `writeAttendance` only ever writes `morning`, which is the important part: a read that
    /// also honoured afternoon rows would see facts no write could ever clear, and cancelling an
    /// early pick-up would appear not to work.
    static func attendance(from records: [AttendanceRecord]) -> [Attendance] {
        var seen: Set<Attendance.ID> = []
        return records.compactMap { record in
            guard let entry = Attendance(record), seen.insert(entry.id).inserted else { return nil }
            return entry
        }
    }

    /// Today's away list. `Camp` reads a missing attendance row as "here", so only the explicit
    /// `present = false` rows change a head-count and only those are worth fetching.
    nonisolated func awayPlayerIDs(
        inSites siteIDs: [UUID], on day: Weekday
    ) async throws -> Set<Player.ID> {
        guard !siteIDs.isEmpty else { return [] }
        let records: [AttendanceRecord] = try await db.select(
            Relation.attendance,
            .select("*,players!inner(site_id)")
                .within("players.site_id", siteIDs)
                .eq("day", CampWeek.dateString(for: day))
                .eq("session", Self.session)
                .isTrue("present", false)
        )
        return Set(records.map(\.playerId))
    }

    /// The only session this app reads or writes. See `attendance(from:)`.
    static var session: String { "morning" }
}

// MARK: - Writing the graph

extension SupabaseRepository {

    /// The shape every ordering write takes: load, let `Camp` decide, send the difference, load
    /// again. The rules — partition, even out, what happens when a kid crosses a venue rule —
    /// stay in `Models.swift`, which is the only copy of them there should be.
    func mutateLadder(
        _ campID: Camp.ID, _ edit: (inout Camp) throws -> Void
    ) async throws -> Camp {
        try await serialised(campID) {
            let before = try await camp(id: campID)
            var after = before
            try edit(&after)
            after.reindex()
            try await writePlacements(before: before, after: after)
            try await writeLadder(before: before, after: after)
            return try await camp(id: campID)
        }
    }

    /// Which venue and which court, for everyone who moved. Grouped by destination so a
    /// partition that reseats a hundred kids is a dozen requests rather than a hundred, and run
    /// concurrently because no two touch the same rows.
    func writePlacements(before: Camp, after: Camp) async throws {
        var moves: [CourtSlot: [Player.ID]] = [:]
        for player in after.players {
            guard let was = before.player(player.id) else { continue }
            guard was.venueID != player.venueID || was.groupID != player.groupID else { continue }
            moves[CourtSlot(venueID: player.venueID, groupID: player.groupID), default: []]
                .append(player.id)
        }
        guard !moves.isEmpty else { return }

        let db = self.db
        try await withThrowingTaskGroup(of: Void.self) { tasks in
            for (slot, playerIDs) in moves {
                tasks.addTask {
                    try await db.update(
                        Relation.players,
                        set: ["site_id": .uuid(slot.venueID), "group_id": .uuid(slot.groupID)],
                        where: PostgRESTQuery().within("id", playerIDs)
                    )
                }
            }
            try await tasks.waitForAll()
        }
    }

    /// The smallest gap `ratings.rating` can hold. The column is `numeric(7, 2)`, so anything
    /// finer is rounded away on the way in — separating two tied kids by a thousandth writes two
    /// identical numbers, and the reorder that asked for it silently does nothing.
    static var ladderStep: Double { 0.01 }

    /// Commits an order by redealing the ratings that are already there.
    ///
    /// A permutation rather than a fresh scale: the values in `ratings.rating` came from real
    /// assessments and the spread between them means something, so a drag moves who holds which
    /// value instead of overwriting the lot. The one adjustment is to ties — `rating` defaults to
    /// 1500 and a camp that has never been assessed is entirely ties, where redealing equal
    /// numbers would leave the drag with nothing to say.
    func writeLadder(before: Camp, after: Camp) async throws {
        let target = Self.storageLadder(after)
        guard target != Self.storageLadder(before), !target.isEmpty else { return }

        let siteIDs = after.venues.map(\.id)
        guard !siteIDs.isEmpty else { return }
        let existing: [RatingRecord] = try await db.select(
            Relation.ratings,
            .select("player_id,rating,players!inner(site_id)").within("players.site_id", siteIDs)
        )
        let current = Dictionary(
            existing.map { ($0.playerId, $0.rating) }, uniquingKeysWith: { first, _ in first }
        )

        var values = existing.map(\.rating).sorted(by: >)
        // A kid with no ratings row yet — the trigger seeds one on insert, but a row can be
        // missing — sits below everyone who has one.
        while values.count < target.count { values.append((values.last ?? 1500) - 1) }
        for index in values.indices.dropFirst() where values[index] >= values[index - 1] {
            // Rounded to the column's own scale, so repeated subtraction in binary floating point
            // cannot drift into a value Postgres stores as equal to its neighbour.
            values[index] = ((values[index - 1] - Self.ladderStep) * 100).rounded() / 100
        }

        let rows = zip(target, values).compactMap { playerID, rating -> RowValues? in
            current[playerID] == rating
                ? nil
                : RowValues(["player_id": .uuid(playerID), "rating": .number(rating)])
        }
        try await db.upsert(Relation.ratings, rows, onConflict: "player_id")
    }

    /// The order this camp will read back in.
    ///
    /// The loader has one sequence to work from and derives both ladders from it: `overallRank`
    /// is a position in the whole camp, `courtRank` a position among the kids sharing a court. So
    /// for a coach's drag inside one court to survive a reload, that court's members have to
    /// appear in the coach's order at the positions the court already occupies in the camp
    /// ladder. Without this step a court reorder writes nothing at all, because it leaves
    /// `overallRank` untouched.
    static func storageLadder(_ camp: Camp) -> [Player.ID] {
        var sequence = camp.orderedPlayers.map(\.id)
        var slots: [Group.ID: [Int]] = [:]
        for (index, player) in camp.orderedPlayers.enumerated() {
            guard let groupID = player.groupID else { continue }
            slots[groupID, default: []].append(index)
        }
        for (groupID, positions) in slots {
            for (position, player) in zip(positions, camp.players(inGroup: groupID)) {
                sequence[position] = player.id
            }
        }
        return sequence
    }

    // MARK: Courts

    func addCourts(before: Camp, after: Camp, venueID: Venue.ID) async throws {
        let had = Set(before.groups(in: venueID).map(\.id))
        let added = after.groups(in: venueID).filter { !had.contains($0.id) }
        try await db.insert(Relation.groups, added.map(Self.groupRow))
    }

    /// Trimming a venue's court count. Three of the four tables pointing at `groups` were created
    /// without an `on delete` clause, so the delete has to clear them itself or Postgres refuses
    /// it outright.
    func dropCourts(before: Camp, after: Camp, venueID: Venue.ID) async throws {
        let has = Set(after.groups(in: venueID).map(\.id))
        let removed = before.groups(in: venueID).map(\.id).filter { !has.contains($0) }
        guard !removed.isEmpty else { return }

        try await db.update(
            Relation.coaches,
            set: ["group_id": .null, "site_id": .null],
            where: PostgRESTQuery().within("group_id", removed)
        )
        try await db.update(
            Relation.assessments,
            set: ["group_id": .null],
            where: PostgRESTQuery().within("group_id", removed)
        )
        try await db.delete(
            Relation.courtAssignments, where: PostgRESTQuery().within("group_id", removed)
        )
        try await db.delete(Relation.groups, where: PostgRESTQuery().within("id", removed))
    }

    // MARK: Attendance

    /// Reads the day's row, edits it the way `Camp.upsertAttendance` would, and writes the
    /// result — or deletes it. The table is sparse for the same reason the model is: a row
    /// saying "here all day, staying to the end" is the default written down, and keeping it
    /// would leave rows the app's own logic considers deleted.
    func writeAttendance(
        playerID: Player.ID, day: Weekday, campID: Camp.ID, _ edit: (inout Attendance) -> Void
    ) async throws -> Camp {
        try await serialised(campID) {
            let dayText = CampWeek.dateString(for: day)
            // Both checks before the write, in the order `InMemoryRepository.mutate` makes them.
            // The player is scoped through `sites` rather than looked up on their own, so a kid
            // at another camp is `unknownPlayer` here exactly as they are offline — and neither
            // failure leaves a row behind.
            // `RowIDRecord`, not `CampRecord`. The projection is `id` alone — this only asks
            // whether the camp exists — but `CampRecord` declares five more non-optional columns,
            // so decoding a one-key row into it threw `keyNotFound` on `name` before the write
            // was ever attempted. Against the real backend that meant **every** attendance write
            // failed: the offline build has no decode step, so the whole of `8m` worked in the
            // simulator and nowhere else. `RowIDRecord` exists at `SupabaseDTOs.swift:164` for
            // exactly this shape.
            async let campTask: [RowIDRecord] = db.select(
                Relation.camps, .select("id").eq("id", campID)
            )
            async let playerTask: [PlayerRecord] = db.select(
                Relation.players,
                .select("*,sites!inner(camp_id)").eq("id", playerID).eq("sites.camp_id", campID)
            )
            async let currentTask: [AttendanceRecord] = db.select(
                Relation.attendance,
                .select("*")
                    .eq("player_id", playerID)
                    .eq("day", dayText)
                    .eq("session", Self.session)
            )
            let (campRows, playerRows, currentRows) =
                try await (campTask, playerTask, currentTask)
            guard !campRows.isEmpty else { throw SycamoreError.unknownCamp }
            guard !playerRows.isEmpty else { throw SycamoreError.unknownPlayer }

            var record = Attendance(
                playerID: playerID,
                day: day,
                present: currentRows.first?.present ?? true,
                leavesAt: currentRows.first?.leavesAt.flatMap { TimeOfDay(postgresTime: $0) }
            )
            edit(&record)

            let row = PostgRESTQuery()
                .eq("player_id", playerID).eq("day", dayText).eq("session", Self.session)
            if record.present, record.leavesAt == nil {
                try await db.delete(Relation.attendance, where: row)
            } else {
                try await db.upsert(Relation.attendance, [RowValues([
                    "player_id": .uuid(playerID),
                    "day": .text(dayText),
                    "session": .text(Self.session),
                    "present": .bool(record.present),
                    "leaves_at": .text(record.leavesAt?.postgresTime),
                ])], onConflict: "player_id,day,session")
            }
            return try await camp(id: campID)
        }
    }
}

// MARK: - Rows

extension SupabaseRepository {

    static func siteRow(_ venue: Venue, campID: Camp.ID) -> RowValues {
        [
            "name": .text(venue.name),
            "camp_id": .uuid(campID),
            "subtitle": .text(venue.subtitle),
            "icon": .text(venue.icon),
            "tint": .text(venue.tint.rawValue),
            // These two used to be one line — `"court_count": .int(venue.groupCount)` — because
            // the model had one number for both. `20260810040000_a_venue_knows_its_own_shape`
            // split them, and this is the write side of that split: `court_count` is now the
            // courts the venue has, and `group_count` is how many groups it runs on them. The
            // migration backfilled the second from the first, so every venue that existed before
            // the split keeps writing back exactly what it read.
            "court_count": .int(venue.courtCount),
            "group_count": .int(venue.groupCount),
            "target_per_group": .int(venue.targetPerGroup),
            "age_band": .text(venue.ageBand.rawValue),
            "coach_min": .int(venue.coachMin),
            "coach_max": .int(venue.coachMax),
            "player_min": .int(venue.playerMin),
            "player_max": .int(venue.playerMax),
            "sort_index": .int(venue.sortIndex),
        ]
    }

    /// `name` and `court_label` both take the model's single `label`. The table separates them —
    /// "Group 1" beside "Court 1" — and the app has never had two names for a court.
    static func groupRow(_ court: Group) -> RowValues {
        [
            "id": .uuid(court.id),
            "site_id": .uuid(court.venueID),
            "name": .text(court.label),
            "court_label": .text(court.label),
            "rank_order": .int(court.rankOrder),
        ]
    }
}

/// Where a batch of players is being sent. A local type would do, but `writePlacements` hands it
/// across a task group boundary, which wants something plainly `Sendable`.
struct CourtSlot: Hashable, Sendable {
    var venueID: Venue.ID?
    var groupID: Group.ID?
}
