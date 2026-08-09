//
//  SupabaseRepository+SectionEight.swift
//  Sycamore
//
//  `SectionEightData` against Postgres: Overview's courts, Schedule's blocks, the Inbox.
//
//  All three have a seam in them, and each is worth saying out loud.
//
//  Schedule used to be a table read almost literally, and is not one any more. A block on `8k`
//  draws three things that are not columns of `schedule_blocks`: its notes, which are
//  `inbox_items` rows carrying `schedule_block_id`, and its coaches, which are
//  `schedule_block_coaches` rows. Both are read in the same wave as the blocks and reach the day
//  through an embedded inner join rather than through the ids of the blocks just read, so the
//  three are independent and cost one round trip rather than two. See
//  `scheduleBlocks(forVenue:day:campID:)`.
//
//  The Inbox is camp-wide, not per-venue — `8r` puts an LATC row in front of a reader standing on
//  Sycamore — but `inbox_items` only knows its `site_id`. So it reaches its camp through `sites`,
//  in one embedded join rather than a loop over venues. See `inboxItems(forCamp:)`.
//
//  Admin-gated writes rename one failure on the way out. A `with check` refusal is a 403, which
//  `SupabaseError` would otherwise report as "You don't have access to that." — a sentence about
//  a session, for something that is a rule. See `adminWrite` and `missingOrRefused`.
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

    /// A day's blocks, with the notes and the coaches on each of them.
    ///
    /// Four reads in one `async let` wave, the shape `courts(forVenue:campID:)` already uses. The
    /// two child reads reach the day through an embedded inner join — `schedule_blocks!inner`
    /// with the filter on the embedded column, the same shape `inboxItems(forCamp:)` uses to
    /// reach a camp through `sites` — rather than through the ids of the blocks just read. That
    /// is the whole reason there is one wave and not two: an `in.(…)` over ids cannot be built
    /// until the blocks have arrived, which would make the day cost two round trips instead of
    /// one, and would need an empty-list guard besides, because PostgREST rejects `in.()`.
    ///
    /// Confirmed against the project before it was written, since a filter on a column PostgREST
    /// does not recognise is the kind of thing that fails quietly: a deliberately misspelled
    /// embed answers `PGRST200`, a filter on a column that does not exist answers `42703
    /// column schedule_blocks_1.no_such_column does not exist` — which names the join's own alias
    /// and so proves the filter is planned into the query rather than dropped — and the query
    /// below answers 200.
    ///
    /// `InboxItemRecord` is reused unchanged for the notes. The embedded `schedule_blocks` key it
    /// does not declare is simply ignored by `Decodable`.
    ///
    /// The fourth read is the camp's coaches, and it is here for the notes rather than for the
    /// blocks: `BlockNote.authorName` is a name, and names live on `coaches`. It filters
    /// `active` like every other read of that table, which is exactly why `authorName` is
    /// optional — a note outlives the person who wrote it.
    func scheduleBlocks(
        forVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let dayText = CampWeek.dateString(for: day)

        async let blocksTask: [ScheduleBlockRecord] = db.select(
            Relation.scheduleBlocks,
            .select("*").eq("site_id", venueID).eq("day", dayText).order("starts_at")
        )
        // Ascending, and deliberately the opposite of the Inbox's own `created_at desc`. `8k`
        // pins `notes.first` under the block card and `8l` pins it again on the court card, so
        // newest-first would swap the pinned line out from under a coach mid-session — every new
        // note would displace the one they were reading.
        async let notesTask: [InboxItemRecord] = db.select(
            Relation.inboxItems,
            .select("*,schedule_blocks!inner(site_id,day)")
                .eq("kind", InboxKind.note.rawValue)
                .eq("schedule_blocks.site_id", venueID)
                .eq("schedule_blocks.day", dayText)
                .order("created_at")
        )
        async let coachesTask: [ScheduleBlockCoachRecord] = db.select(
            Relation.scheduleBlockCoaches,
            .select("block_id,coach_id,schedule_blocks!inner(site_id,day)")
                .eq("schedule_blocks.site_id", venueID)
                .eq("schedule_blocks.day", dayText)
                .order("created_at")
        )
        async let staffTask: [CoachRecord] = db.select(
            Relation.coaches, .select("*").eq("camp_id", campID).isTrue("active")
        )
        let (blockRecords, noteRecords, coachRecords, staffRecords) =
            try await (blocksTask, notesTask, coachesTask, staffTask)

        let authorNames = Dictionary(
            staffRecords.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }
        )

        var notesByBlock: [ScheduleBlock.ID: [BlockNote]] = [:]
        for record in noteRecords {
            // `!inner` already dropped the rows with no block, so this only ever skips a row the
            // embed and the column disagreed about — which is to say never.
            guard let blockID = record.scheduleBlockId else { continue }
            notesByBlock[blockID, default: []].append(
                BlockNote(
                    id: record.id,
                    // `detail`, not `title`. That is where the seeded notes put the sentence —
                    // "Skills rotation · net on 4 is loose", "Match play 10:45 · net still down,
                    // play on 1–3" — while `title` holds "Nass pinned a note", which would draw
                    // three identical lines on the Skills rotation card. `detail` also allows 200
                    // characters against `title`'s 120, which suits describing an activity.
                    // `title` is the fallback rather than the choice, and only because the
                    // columns are shaped that way round: `detail` is nullable and `title` is
                    // `not null`, so a row always has one of the two and a note whose author put
                    // everything in the heading draws its own words instead of an empty line.
                    text: record.detail ?? record.title,
                    authorName: record.actorId.flatMap { authorNames[$0] },
                    at: record.createdAt
                )
            )
        }

        var coachIDsByBlock: [ScheduleBlock.ID: [StaffMember.ID]] = [:]
        for record in coachRecords {
            coachIDsByBlock[record.blockId, default: []].append(record.coachId)
        }

        return blockRecords.compactMap { record in
            ScheduleBlock(
                record,
                notes: notesByBlock[record.id] ?? [],
                coachIDs: coachIDsByBlock[record.id] ?? []
            )
        }
    }

    func addScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock] {
        try await adminWrite {
            try await db.insert(Relation.scheduleBlocks, [Self.scheduleRow(block)])
            // The block row first, because `schedule_block_coaches.block_id` is a foreign key
            // into it. `scheduleRow` writes an explicit `id`, so the client already knows what
            // the join rows point at and does not have to read the insert back to find out.
            //
            // No delete before the insert, unlike `updateScheduleBlock`: the id was minted on
            // this device a moment ago, so there is nothing under it to clear and a delete could
            // only ever be a round trip that matched nothing.
            try await db.insert(
                Relation.scheduleBlockCoaches, Self.blockCoachRows(block.coachIDs, for: block.id)
            )
        }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func updateScheduleBlock(
        _ block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        try await adminWrite {
            let updated: [ScheduleBlockRecord] = try await db.update(
                Relation.scheduleBlocks,
                set: Self.scheduleRow(block),
                where: PostgRESTQuery().eq("id", block.id),
                returning: ScheduleBlockRecord.self
            )
            guard !updated.isEmpty else {
                throw await missingOrRefused(Relation.scheduleBlocks, id: block.id)
            }
            try await setBlockCoaches(block.coachIDs, forBlock: block.id)
        }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func deleteScheduleBlock(
        _ blockID: ScheduleBlock.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        // Nothing to unpick by hand. Both children hang off `schedule_blocks.id` with
        // `on delete cascade` — `inbox_items_schedule_block_id_fkey` since `section8_model_gaps`,
        // and `schedule_block_coaches.block_id` since the table was created — so the block's
        // notes and its coaches go with it in the same statement.
        let deleted: [ScheduleBlockRecord] = try await adminWrite {
            try await db.delete(
                Relation.scheduleBlocks,
                where: PostgRESTQuery().eq("id", blockID),
                returning: ScheduleBlockRecord.self
            )
        }
        guard let record = deleted.first, let day = CampWeek.weekday(from: record.day) else {
            throw await missingOrRefused(Relation.scheduleBlocks, id: blockID)
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
        try await adminWrite {
            try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func deleteBlockNote(
        _ noteID: InboxItem.ID, from block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let deleted: [InboxItemRecord] = try await adminWrite {
            try await db.delete(
                Relation.inboxItems,
                where: PostgRESTQuery().eq("id", noteID),
                returning: InboxItemRecord.self
            )
        }
        guard !deleted.isEmpty else {
            throw await missingOrRefused(Relation.inboxItems, id: noteID)
        }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    /// Nothing here writes `schedule_block_coaches`, and that is not an omission.
    ///
    /// A shape is a timetable, not a roster: `DayShape.blocks` is `(hour, minute, title, detail)`
    /// and names nobody, so a shape has no coaches to carry. The old day's coaches need no
    /// clearing either — the delete below takes its blocks, and `block_id`'s cascade takes the
    /// join rows with them.
    func applyDayShape(
        _ shape: DayShape, toVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let dayText = CampWeek.dateString(for: day)
        try await adminWrite {
            // Replaces the day rather than appending to it: "start from a shape" is only offered
            // on an empty day, but a double tap must not produce two overlapping timetables.
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
        }
        return try await scheduleBlocks(forVenue: venueID, day: day, campID: campID)
    }

    /// Copies a day, and copies its coaches with it — explicitly, because nothing else would.
    ///
    /// Each copy is minted a fresh `UUID()` below, so a `schedule_block_coaches` row keyed on the
    /// source block's id follows nothing. The join rows are built here against the new ids, in
    /// one insert for the whole day rather than one per block.
    ///
    /// Notes deliberately do not follow, and the two decisions are the same decision read from
    /// opposite ends. `copy.status` already argues it a few lines down — "a copied day starts
    /// fresh: yesterday's done is not today's" — and "net still down, play on 1–3" is exactly that
    /// kind of fact: true of the morning somebody wrote it and nobody's instruction for tomorrow.
    /// Who is *rostered* on a block is not a fact about a morning, which is why the coaches copy.
    func copySchedule(
        fromDay: Weekday, toDay: Weekday, venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let source = try await scheduleBlocks(forVenue: venueID, day: fromDay, campID: campID)
        let target = CampWeek.dateString(for: toDay)
        let copies = source.map { block -> ScheduleBlock in
            var copy = block
            copy.id = UUID()
            copy.day = toDay
            // A copied day starts fresh: yesterday's "done" is not today's.
            copy.status = block.status == .done ? .planned : block.status
            return copy
        }
        try await adminWrite {
            try await db.delete(
                Relation.scheduleBlocks,
                where: PostgRESTQuery().eq("site_id", venueID).eq("day", target)
            )
            try await db.insert(Relation.scheduleBlocks, copies.map(Self.scheduleRow))
            try await db.insert(
                Relation.scheduleBlockCoaches,
                copies.flatMap { Self.blockCoachRows($0.coachIDs, for: $0.id) }
            )
        }
        return try await scheduleBlocks(forVenue: venueID, day: toDay, campID: campID)
    }

    /// The block's coaches, written as a cover rather than as a diff: clear what is there, insert
    /// what is there now.
    ///
    /// Deliberately not a diff. A diff has to read the stored rows before it can say what changed,
    /// and the set is a handful of rows — so the diff would spend a round trip to save writing
    /// two or three, and would then have to get "removed" and "added" right against a list that
    /// may have moved underneath it.
    ///
    /// The delete carries `block_id` because `PostgRESTClient` will not send it otherwise: an
    /// unfiltered DELETE would take every block's coaches off every block in the table, and that
    /// guard exists precisely so a filter lost in an edit never leaves the device.
    private func setBlockCoaches(
        _ coachIDs: [StaffMember.ID], forBlock blockID: ScheduleBlock.ID
    ) async throws {
        try await db.delete(
            Relation.scheduleBlockCoaches, where: PostgRESTQuery().eq("block_id", blockID)
        )
        try await db.insert(Relation.scheduleBlockCoaches, Self.blockCoachRows(coachIDs, for: blockID))
    }

    /// `(block_id, coach_id)` is the table's primary key, so the same coach named twice is a
    /// `23505` rather than a harmless no-op. Deduplicated here, keeping the first mention, because
    /// the order the rows are written in is the order `created_at` gives them back and therefore
    /// the order `ScheduleBlock.coachLine(in:)` reads out as "Nass & Alina".
    private static func blockCoachRows(
        _ coachIDs: [StaffMember.ID], for blockID: ScheduleBlock.ID
    ) -> [RowValues] {
        var seen: Set<StaffMember.ID> = []
        return coachIDs
            .filter { seen.insert($0).inserted }
            .map { ["block_id": .uuid(blockID), "coach_id": .uuid($0)] }
    }

    /// `notes` and `coachIDs` have no columns here and are dropped. Both are relations of their
    /// own — `inbox_items` and `schedule_block_coaches` — written beside this row rather than
    /// inside it. See `setBlockCoaches` and `addBlockNote`.
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
        let resolved: [InboxItemRecord] = try await adminWrite {
            try await db.update(
                Relation.inboxItems,
                set: ["resolved": .bool(true)],
                where: PostgRESTQuery().eq("id", itemID),
                returning: InboxItemRecord.self
            )
        }
        guard !resolved.isEmpty else {
            throw await missingOrRefused(Relation.inboxItems, id: itemID)
        }
        return try await inboxItems(forCamp: campID)
    }

    func addInboxItem(_ item: InboxItem, forCamp campID: Camp.ID) async throws -> [InboxItem] {
        // Admin-gated for one field out of thirteen. `pinned` is the admin-only one, and the
        // member `with check` can only refuse a venue that is not yours at all — which is a bug
        // rather than something a coach can do — so a 403 here is the pin being refused.
        try await adminWrite {
            try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        }
        return try await inboxItems(forCamp: campID)
    }

    /// One insert, then the camp's rows back — and `created_at` left to Postgres, which is the
    /// whole point of the method. See the protocol for the divergence it closes.
    ///
    /// Deliberately **not** wrapped in `adminWrite`, which every other write in this file is.
    /// That wrapper renames a 403 to "Only an admin can do that.", and it is only honest where
    /// the policy answering is an admin gate. `addInboxItem` above earns it because the row it
    /// writes may be `pinned`, which is the admin-only column. An activity row never is, so the
    /// only `with check` left to refuse it is the member one — a venue outside your camps, which
    /// is a bug on this side of the wire rather than something a coach can do. Renaming that
    /// would tell a coach marking a kid away that they lack a permission they in fact hold, and
    /// send them looking for an admin over a defect in the app.
    ///
    /// So a refusal arrives as `SupabaseError.rejected` and reads "You don't have access to
    /// that." — which for a venue that genuinely is not yours is the true sentence.
    func logActivity(_ item: InboxItem, forCamp campID: Camp.ID) async throws -> [InboxItem] {
        try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        return try await inboxItems(forCamp: campID)
    }

    func setPinned(
        _ pinned: Bool, forItem itemID: InboxItem.ID, forCamp campID: Camp.ID
    ) async throws -> [InboxItem] {
        let updated: [InboxItemRecord] = try await adminWrite {
            try await db.update(
                Relation.inboxItems,
                set: ["pinned": .bool(pinned)],
                where: PostgRESTQuery().eq("id", itemID),
                returning: InboxItemRecord.self
            )
        }
        guard !updated.isEmpty else {
            throw await missingOrRefused(Relation.inboxItems, id: itemID)
        }
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
        let resolved: [InboxItemRecord] = try await adminWrite {
            try await db.update(
                Relation.inboxItems,
                set: ["resolved": .bool(true)],
                where: PostgRESTQuery().eq("id", itemID),
                returning: InboxItemRecord.self
            )
        }
        guard let record = resolved.first else {
            throw await missingOrRefused(Relation.inboxItems, id: itemID)
        }
        return try await inboxItems(forVenue: record.siteId, campID: campID)
    }

    func addInboxItem(_ item: InboxItem, campID: Camp.ID) async throws -> [InboxItem] {
        try await adminWrite {
            try await db.insert(Relation.inboxItems, [Self.inboxRow(item)])
        }
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
            // `created_at` is deliberately absent, and this is the one omission worth stating.
            // The column defaults to `now()`, so a row is stamped by the server rather than by
            // whichever phone composed it — and `item.createdAt` is discarded on the way past.
            // `8r` cuts its headings on that value at noon and five (`InboxBucket.swift:31-37`),
            // so a device an hour out would otherwise file its own morning under everybody
            // else's afternoon, and two coaches reading one feed would see two different days.
            // `logActivity` is built on this. The one caller anywhere that means its own
            // timestamp is `InboxView`'s preview harness seeding a morning through
            // `addInboxItem(_:campID:)`, and this absent line is where that value goes — which
            // is why the offline build is allowed to keep it and this one is not.
        ]
    }

    // MARK: - Refusals

    /// Runs a write and renames the one failure the domain already has a sentence for.
    ///
    /// `SycamoreError.notPermitted` — "Only an admin can do that." — has been declared since the
    /// first repository and thrown by nothing, because nothing on this side of the wire could
    /// recognise a refusal when it saw one. A 403 is the `with check` clause answering, which is
    /// precisely that sentence; left alone it arrives as `SupabaseError.rejected` and reads
    /// "You don't have access to that.", which sounds like a broken session and sends somebody
    /// to sign in again over a rule that would refuse them just as firmly afterwards.
    ///
    /// Applied per call site rather than inside `PostgRESTClient`, because the mapping is only
    /// true where the policy is an admin gate. A 403 writing `attendance` would mean the row is
    /// not in a camp of yours, and "Only an admin can do that" would be a confident lie.
    private func adminWrite<T>(_ write: () async throws -> T) async throws -> T {
        do {
            return try await write()
        } catch let refusal as SupabaseError where refusal.isPolicyRefusal {
            throw SycamoreError.notPermitted
        }
    }

    /// Which of the two things a write that changed nothing meant.
    ///
    /// Row level security refuses in two different ways and only one of them is loud. A `with
    /// check` violation is a 403, which `adminWrite` catches. A `using` clause is not a refusal at
    /// all — PostgREST applies it as a filter, so the PATCH matches nothing and answers exactly as
    /// it would for an id that was never there. Every guard in this file used to read that as
    /// `unknownGroup`, so a coach tapping "unpin" on a row visible on screen in front of them was
    /// told "We couldn't find that court."
    ///
    /// One request settles it, and only on the path that has already failed: reading is
    /// member-scoped while writing is admin-scoped, so a row you can select but could not write
    /// to is the gate, and a row you cannot select either is genuinely not yours or not there.
    ///
    /// Falls back to `unknownGroup` if that read itself fails, because a network error on the way
    /// to explaining a failure should not replace the failure with a different one.
    private func missingOrRefused(_ relation: String, id: UUID) async -> SycamoreError {
        let rows: [RowIDRecord]? = try? await db.select(
            relation, .select("id").eq("id", id).limit(1)
        )
        return rows?.isEmpty == false ? .notPermitted : .unknownGroup
    }
}
