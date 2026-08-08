//
//  SupabaseRepository+SectionEight.swift
//  Sycamore
//
//  `SectionEightData` against Postgres: Overview's courts, Schedule's blocks, the Inbox.
//
//  Schedule is a table read almost literally. The other two have a seam in them, and both are
//  worth saying out loud.
//
//  The Inbox is camp-wide, not per-venue — `8r` puts an LATC row in front of a reader standing on
//  Sycamore — but `inbox_items` only knows its `site_id`. So it reaches its camp through `sites`,
//  in one embedded join rather than a loop over venues. See `inboxItems(forCamp:)`.
//
//  Overview:
//
//  `today_courts` exists and is exactly this query — but `drop view … create view` in the
//  section 8 migration reset the view's grants, so `anon` and `authenticated` currently have no
//  `select` on it and the app is answered `42501 permission denied`. Assembling the same card
//  from `groups`, `coaches`, `players` and `attendance` is four small requests instead of one,
//  and it has the side benefit of counting who is here by the app's own rule rather than the
//  view's: `Camp` treats a missing attendance row as "here", the view counts only explicit
//  `present = true` rows, and a court that reads "8 here" on Groups must not read "0 here" on
//  Overview. Restoring the grant is a one-line `grant select on public.today_courts to anon,
//  authenticated;` whenever the schema's owner wants the single-query version back.
//

import Foundation

extension SupabaseRepository: SectionEightData {

    // MARK: - Overview

    func courts(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [CourtCard] {
        async let courtsTask: [GroupRecord] = db.select(
            Relation.groups, .select("*").eq("site_id", venueID).order("rank_order")
        )
        async let coachesTask: [CoachRecord] = db.select(
            Relation.coaches, .select("*").eq("site_id", venueID).isTrue("active")
        )
        async let playersTask: [PlayerRecord] = db.select(
            Relation.players, .select("*").eq("site_id", venueID)
        )
        async let scheduleTask: [ScheduleBlockRecord] = db.select(
            Relation.scheduleBlocks,
            .select("*")
                .eq("site_id", venueID)
                .eq("day", CampWeek.dateString(for: .today))
                .order("starts_at")
        )
        async let awayTask: Set<Player.ID> = awayPlayerIDs(inSites: [venueID], on: .today)
        let (courtRecords, coachRecords, playerRecords, blockRecords, away) =
            try await (courtsTask, coachesTask, playersTask, scheduleTask, awayTask)

        let activity = Self.runningBlock(in: blockRecords)?.title
        let coachesByGroup = Dictionary(
            coachRecords.compactMap { record in record.groupId.map { ($0, record) } },
            uniquingKeysWith: { first, _ in first }
        )
        let playersByGroup = Dictionary(
            grouping: playerRecords.filter { !away.contains($0.id) }, by: { $0.groupId }
        )

        return courtRecords.map { record in
            let coach = coachesByGroup[record.id]
            return CourtCard(
                id: record.id,
                venueID: record.siteId,
                groupName: record.name,
                courtLabel: record.courtLabel,
                rankOrder: record.rankOrder,
                coachID: coach?.id,
                coachName: coach?.name,
                playersHere: playersByGroup[record.id]?.count ?? 0,
                activity: activity,
                status: closedCourts[record.id].map { .closed(reason: $0) } ?? .open
            )
        }
    }

    /// Held on the actor, not written down: nothing in the schema says a court is out of play.
    /// The design draws a closed court with its reason still on it, so a `groups.closed_reason`
    /// column is all it would take — until then a reason survives the screen but not the app.
    func setCourtStatus(
        _ status: CourtStatus, forGroup groupID: Group.ID, campID: Camp.ID
    ) async throws -> [CourtCard] {
        let records: [GroupRecord] = try await db.select(
            Relation.groups, .select("*").eq("id", groupID)
        )
        guard let court = records.first else { throw SycamoreError.unknownGroup }

        switch status {
        case .open: closedCourts[groupID] = nil
        case .closed(let reason): closedCourts[groupID] = reason
        }
        return try await courts(forVenue: court.siteId, campID: campID)
    }

    /// What is on right now: the latest block that has started and has not ended. Blocks arrive
    /// in time order, so the last match is the current one. A block with no stated end runs until
    /// the next one starts — which is what "Drop-off" with no end time means on the design's own
    /// card.
    private static func runningBlock(in records: [ScheduleBlockRecord]) -> ScheduleBlockRecord? {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let clock = TimeOfDay(parts.hour ?? 0, parts.minute ?? 0)

        // The latest block to have started, and then whether it is over. Asking both questions of
        // every block instead would let an earlier open-ended one match again once the current
        // block ends — and 8:30 "Drop-off" would be the activity on every court all afternoon.
        guard let started = records.last(where: { record in
            TimeOfDay(postgresTime: record.startsAt).map { $0 <= clock } ?? false
        }) else { return nil }

        guard let endsAt = started.endsAt, let ends = TimeOfDay(postgresTime: endsAt) else {
            return started
        }
        return ends <= clock ? nil : started
    }

    // MARK: - Schedule

    func scheduleBlocks(
        forVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let records: [ScheduleBlockRecord] = try await db.select(
            Relation.scheduleBlocks,
            .select("*")
                .eq("site_id", venueID)
                .eq("day", CampWeek.dateString(for: day))
                .order("starts_at")
        )
        return records.compactMap(ScheduleBlock.init)
    }

    func addScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock] {
        try await db.insert(Relation.scheduleBlocks, [Self.scheduleRow(block)])
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func updateScheduleBlock(
        _ block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let updated: [ScheduleBlockRecord] = try await db.update(
            Relation.scheduleBlocks,
            set: Self.scheduleRow(block),
            where: PostgRESTQuery().eq("id", block.id),
            returning: ScheduleBlockRecord.self
        )
        guard !updated.isEmpty else { throw SycamoreError.unknownGroup }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func deleteScheduleBlock(
        _ blockID: ScheduleBlock.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let deleted: [ScheduleBlockRecord] = try await db.delete(
            Relation.scheduleBlocks,
            where: PostgRESTQuery().eq("id", blockID),
            returning: ScheduleBlockRecord.self
        )
        guard let record = deleted.first, let day = CampWeek.weekday(from: record.day) else {
            throw SycamoreError.unknownGroup
        }
        return try await scheduleBlocks(forVenue: record.siteId, day: day, campID: campID)
    }

    /// A note is an `inbox_items` row of kind `note` carrying `schedule_block_id`. There is no
    /// notes table and deliberately so — the seed migration states this design, `8r` already
    /// draws these rows in the day's feed, and a `text[]` on the block could carry neither the
    /// author nor the time that feed shows.
    ///
    /// The text goes in `detail` rather than `title`: that is where the seeded notes put the
    /// sentence, `title` is where "Nass pinned a note" lives, and `detail` is the column with
    /// 200 characters rather than 120 — which suits describing an activity.
    func addBlockNote(
        _ text: String, to block: ScheduleBlock, authorID: StaffMember.ID?, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let item = InboxItem(
            venueID: block.venueID,
            kind: .note,
            title: block.title,
            detail: text,
            actorID: authorID,
            scheduleBlockID: block.id
        )
        try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func deleteBlockNote(
        _ noteID: InboxItem.ID, from block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let deleted: [InboxItemRecord] = try await db.delete(
            Relation.inboxItems,
            where: PostgRESTQuery().eq("id", noteID),
            returning: InboxItemRecord.self
        )
        guard !deleted.isEmpty else { throw SycamoreError.unknownGroup }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func applyDayShape(
        _ shape: DayShape, toVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let dayText = CampWeek.dateString(for: day)
        // Replaces the day rather than appending to it: "start from a shape" is only offered on
        // an empty day, but a double tap must not produce two overlapping timetables.
        try await db.delete(
            Relation.scheduleBlocks,
            where: PostgRESTQuery().eq("site_id", venueID).eq("day", dayText)
        )
        try await db.insert(Relation.scheduleBlocks, shape.blocks.map { spec in
            RowValues([
                "site_id": .uuid(venueID),
                "day": .text(dayText),
                "starts_at": .text(TimeOfDay(spec.hour, spec.minute).postgresTime),
                "title": .text(spec.title),
                "detail": .text(spec.detail),
                "status": .text(ScheduleBlockStatus.planned.rawValue),
            ])
        })
        return try await scheduleBlocks(forVenue: venueID, day: day, campID: campID)
    }

    func copySchedule(
        fromDay: Weekday, toDay: Weekday, venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let source = try await scheduleBlocks(forVenue: venueID, day: fromDay, campID: campID)
        let target = CampWeek.dateString(for: toDay)
        try await db.delete(
            Relation.scheduleBlocks,
            where: PostgRESTQuery().eq("site_id", venueID).eq("day", target)
        )
        try await db.insert(Relation.scheduleBlocks, source.map { block in
            var copy = block
            copy.id = UUID()
            copy.day = toDay
            // A copied day starts fresh: yesterday's "done" is not today's.
            copy.status = block.status == .done ? .planned : block.status
            return Self.scheduleRow(copy)
        })
        return try await scheduleBlocks(forVenue: venueID, day: toDay, campID: campID)
    }

    /// `notes` has no column and is dropped. See `ScheduleBlock.init(_:)` — inventing a
    /// `schedule_block_notes` table is a schema decision, and this client does not get to make it.
    private static func scheduleRow(_ block: ScheduleBlock) -> RowValues {
        [
            "id": .uuid(block.id),
            "site_id": .uuid(block.venueID),
            "day": .text(CampWeek.dateString(for: block.day)),
            "starts_at": .text(block.startsAt.postgresTime),
            "ends_at": .text(block.endsAt?.postgresTime),
            "title": .text(block.title),
            "detail": .text(block.detail),
            "status": .text(block.status.rawValue),
        ]
    }

    // MARK: - Inbox

    /// The camp's Inbox, across its venues.
    ///
    /// `inbox_items` carries a `site_id` and nothing else about where it belongs, so the camp is
    /// one join away — `sites!inner(camp_id)` with the filter on the embedded column, which is the
    /// same shape `ratings`, `attendance` and the ownership check in `+Graph` already use. One
    /// request, whatever the camp's venue count; looping this read over `camp.venues` in Swift
    /// would be N round trips to draw one screen, and would still have to merge and re-sort them.
    ///
    /// No view for it. `today_courts` is the warning already in this schema — a `drop view …
    /// create view` reset its grants and the app has been answered `42501` on it ever since — and
    /// a view over `inbox_items` would need `security_invoker` or it would read as its owner and
    /// hand every camp's Inbox to everyone.
    ///
    /// This is not a wider read than the per-venue one. `inbox_items_member` already scopes rows
    /// to the venues of camps you hold a membership in, so a non-member gets nothing here exactly
    /// as they do there.
    func inboxItems(forCamp campID: Camp.ID) async throws -> [InboxItem] {
        let records: [InboxItemRecord] = try await db.select(
            Relation.inboxItems,
            .select("*,sites!inner(camp_id)")
                .eq("sites.camp_id", campID)
                .order("created_at", ascending: false)
        )
        return records.map(InboxItem.init)
    }

    func resolveInboxItem(_ itemID: InboxItem.ID, forCamp campID: Camp.ID) async throws -> [InboxItem] {
        let resolved: [InboxItemRecord] = try await db.update(
            Relation.inboxItems,
            set: ["resolved": .bool(true)],
            where: PostgRESTQuery().eq("id", itemID),
            returning: InboxItemRecord.self
        )
        guard !resolved.isEmpty else { throw SycamoreError.unknownGroup }
        return try await inboxItems(forCamp: campID)
    }

    func addInboxItem(_ item: InboxItem, forCamp campID: Camp.ID) async throws -> [InboxItem] {
        try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        return try await inboxItems(forCamp: campID)
    }

    func setPinned(
        _ pinned: Bool, forItem itemID: InboxItem.ID, forCamp campID: Camp.ID
    ) async throws -> [InboxItem] {
        let updated: [InboxItemRecord] = try await db.update(
            Relation.inboxItems,
            set: ["pinned": .bool(pinned)],
            where: PostgRESTQuery().eq("id", itemID),
            returning: InboxItemRecord.self
        )
        guard !updated.isEmpty else { throw SycamoreError.unknownGroup }
        return try await inboxItems(forCamp: campID)
    }

    func inboxItems(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [InboxItem] {
        let records: [InboxItemRecord] = try await db.select(
            Relation.inboxItems,
            .select("*").eq("site_id", venueID).order("created_at", ascending: false)
        )
        return records.map(InboxItem.init)
    }

    func resolveInboxItem(_ itemID: InboxItem.ID, campID: Camp.ID) async throws -> [InboxItem] {
        let resolved: [InboxItemRecord] = try await db.update(
            Relation.inboxItems,
            set: ["resolved": .bool(true)],
            where: PostgRESTQuery().eq("id", itemID),
            returning: InboxItemRecord.self
        )
        guard let record = resolved.first else { throw SycamoreError.unknownGroup }
        return try await inboxItems(forVenue: record.siteId, campID: campID)
    }

    func addInboxItem(_ item: InboxItem, campID: Camp.ID) async throws -> [InboxItem] {
        try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        return try await inboxItems(forVenue: item.venueID, campID: campID)
    }

    private static func inboxRow(_ item: InboxItem) -> RowValues {
        [
            "id": .uuid(item.id),
            "site_id": .uuid(item.venueID),
            "kind": .text(item.kind.rawValue),
            "title": .text(item.title),
            "detail": .text(item.detail),
            // Only actionable rows carry a button, which the table's own CHECK enforces — so a
            // label on a note is dropped here rather than rejected by Postgres.
            "action_label": .text(item.kind == .needsAction ? item.actionLabel : nil),
            "actor_id": .uuid(item.actorID),
            "player_id": .uuid(item.playerID),
            "group_id": .uuid(item.groupID),
            // The column has existed since `section8_model_gaps` and was never written, so the
            // app read a field it could not set and every note lost the block it was about.
            "schedule_block_id": .uuid(item.scheduleBlockID),
            "pinned": .bool(item.pinned),
            "resolved": .bool(item.resolved),
        ]
    }
}
