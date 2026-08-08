//
//  SectionEightRepository.swift
//  Sycamore
//
//  The reads and writes section 8's three new screens need, and the in-memory implementation.
//
//  A separate protocol rather than eleven more methods on `SycamoreRepository`, for one reason:
//  every screen being built from section 8 needs this contract at the same time, and a single
//  file that all of them edit is the merge conflict for all of them. `SycamoreRepository`
//  inherits it, so nothing at a call site has to know there are two.
//
//  Same shape as the rest of the protocol — `async throws`, `Sendable` — so a Postgres-backed
//  implementation drops in behind it without a single view changing.
//

import Foundation

// MARK: - Protocol

protocol SectionEightData: Sendable {

    // MARK: Overview — `8i` / `8j`

    /// Every court at a venue today, in rank order. Backed by the `today_courts` view.
    func courts(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [CourtCard]

    /// Takes a court out of play, or puts it back. The design draws a closed court with the
    /// reason still on it ("Net down"), so the reason travels with the change.
    func setCourtStatus(
        _ status: CourtStatus, forGroup groupID: Group.ID, campID: Camp.ID
    ) async throws -> [CourtCard]

    // MARK: Schedule — `8k` / `8l` / `8f`

    func scheduleBlocks(
        forVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock]

    func addScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock]
    func updateScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock]
    func deleteScheduleBlock(_ blockID: ScheduleBlock.ID, campID: Camp.ID) async throws -> [ScheduleBlock]

    /// `8f`'s "Or start from a shape" — writes a whole day in one go. Returns the blocks it
    /// made so the caller does not have to re-read.
    func applyDayShape(
        _ shape: DayShape, toVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock]

    /// `8f`'s "Copy Monday instead".
    func copySchedule(
        fromDay: Weekday, toDay: Weekday, venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock]

    /// Pins a line to a block. Returns the day, because the count on every other card is drawn
    /// from the same read and a note added to one block renumbers nothing else — but the caller
    /// should not have to know that.
    ///
    /// Admin-only, and the gate that counts is the RLS policy on `inbox_items`: a refusal
    /// arrives as a 403 and is raised as `SycamoreError.notPermitted`.
    func addBlockNote(
        _ text: String, to block: ScheduleBlock, authorID: StaffMember.ID?, campID: Camp.ID
    ) async throws -> [ScheduleBlock]

    /// By id rather than by index. The list was re-read from the server and can have changed
    /// between the tap and the write; an index would delete whatever had moved into that slot.
    func deleteBlockNote(
        _ noteID: InboxItem.ID, from block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock]

    // MARK: Inbox — `8r` / `8h`
    //
    // Two families, and the argument label is the whole difference: `forCamp:` spans the camp,
    // `campID:` is one venue inside it.
    //
    // `8r` draws a row reading "LATC is 2 coaches short" while the reader is standing on
    // Sycamore, so the Inbox is a camp-wide list — it is the one screen in section 8 that is not
    // about a venue. The per-venue three below cannot express that, and the app papered over it
    // for a while: `AppStore.readVenueID` picks the camp's first venue and the Inbox showed that
    // one venue's rows. Against the seeded camp that hid exactly the row the design uses as its
    // example, because the only LATC row is the only row not at Sycamore.
    //
    // **`AppStore` now calls the `forCamp:` three**, which pinned messages forced: an admin pins
    // at `readVenueID`, so under the narrow read a camp-wide announcement reached only the venue
    // its author happened to be standing on. The per-venue three survive because the tests
    // exercise them directly and because a caller that genuinely wants one venue has nothing else
    // to ask — but nothing in the app is that caller today, and if none appears they should go.

    /// Every Inbox row in the camp, across its venues, newest first.
    func inboxItems(forCamp campID: Camp.ID) async throws -> [InboxItem]

    /// The "Review" / "Assign" buttons. Resolving is what moves a row out of "Needs you" and
    /// into the day's history, so it returns the whole list rather than one row.
    func resolveInboxItem(_ itemID: InboxItem.ID, forCamp campID: Camp.ID) async throws -> [InboxItem]

    func addInboxItem(_ item: InboxItem, forCamp campID: Camp.ID) async throws -> [InboxItem]

    /// Puts a row at the top of the Inbox, or takes it back down. Admin-only on the server.
    ///
    /// Separate from `resolveInboxItem` because the two say different things: resolving moves a
    /// row into the day's history, and unpinning leaves it exactly where it was in the feed.
    func setPinned(
        _ pinned: Bool, forItem itemID: InboxItem.ID, forCamp campID: Camp.ID
    ) async throws -> [InboxItem]

    /// One venue's rows. Superseded by `inboxItems(forCamp:)` — see above.
    func inboxItems(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [InboxItem]

    /// Answers with the resolved row's *venue*, not its camp. Superseded by
    /// `resolveInboxItem(_:forCamp:)`.
    func resolveInboxItem(_ itemID: InboxItem.ID, campID: Camp.ID) async throws -> [InboxItem]

    /// Answers with the new row's *venue*, not its camp. Superseded by
    /// `addInboxItem(_:forCamp:)`.
    func addInboxItem(_ item: InboxItem, campID: Camp.ID) async throws -> [InboxItem]
}

// MARK: - Day shapes

/// The three starting points `8f` offers instead of a blank day.
///
/// The block lists live here rather than in the view because `applyDayShape` has to write them,
/// and a shape whose definition sat in SwiftUI would mean the repository could not build one.
enum DayShape: String, CaseIterable, Identifiable, Sendable {
    case halfDay, fullDay, tournament

    var id: String { rawValue }

    var title: String {
        switch self {
        case .halfDay: "Half day"
        case .fullDay: "Full day"
        case .tournament: "Tournament"
        }
    }

    var detail: String {
        switch self {
        case .halfDay: "5 blocks · 8:30 to 12:45"
        case .fullDay: "8 blocks · lunch and two breaks"
        case .tournament: "4 blocks · ranked pairs all morning"
        }
    }

    /// `(hour, minute, title, detail)`. Transcribed from the design's own summaries — "5 blocks
    /// · 8:30 to 12:45" is a promise about what this returns, so the counts have to match.
    var blocks: [(hour: Int, minute: Int, title: String, detail: String?)] {
        switch self {
        case .halfDay:
            [(8, 30, "Drop-off", nil),
             (9, 0, "Skills rotation", "All courts"),
             (10, 30, "Water & regroup", "15 min"),
             (10, 45, "Match play", nil),
             (12, 45, "Pick-up", nil)]
        case .fullDay:
            [(8, 30, "Drop-off", nil),
             (9, 0, "Skills rotation", "All courts"),
             (10, 30, "Water & regroup", "15 min"),
             (10, 45, "Match play", nil),
             (12, 0, "Lunch", "Shade lawn"),
             (13, 0, "Drills", nil),
             (14, 30, "Water & regroup", "15 min"),
             (15, 0, "Free play", nil)]
        case .tournament:
            [(8, 30, "Drop-off", nil),
             (9, 0, "Ranked pairs", "Courts 1–3"),
             (10, 45, "Ranked pairs", "Round two"),
             (12, 30, "Finals", "Court 1")]
        }
    }
}

// MARK: - In-memory implementation

/// Keeps the offline build working while the Postgres one is written, and is what every
/// `#Preview` resolves against.
///
/// Stored on the actor rather than derived from `Camp`, because none of the three has a home in
/// the camp graph — `Camp` predates section 8.
extension InMemoryRepository: SectionEightData {

    /// Derived from the camp graph rather than stored.
    ///
    /// It used to read a `sectionEightCourts` array that nothing ever wrote, so it always
    /// answered `[]` — and `OverviewView` quietly made up the difference by rebuilding the cards
    /// itself, in the feature layer, only while the array was empty. That meant two
    /// implementations of "what is on each court today" with no way to check them against each
    /// other, and the moment Postgres returned a single court the offline one silently stopped,
    /// so a partly-populated venue drew a partial screen.
    ///
    /// Every column `today_courts` selects is already in the graph, so there is nothing to store.
    func courts(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [CourtCard] {
        let camp = try await camp(id: campID)
        let activity = ScheduleBlock.running(
            in: try await scheduleBlocks(forVenue: venueID, day: .today, campID: campID),
            at: .now()
        )?.title

        return camp.groups(in: venueID)
            .sorted { $0.rankOrder < $1.rankOrder }
            .map { group in
                let coach = camp.coach(forGroup: group.id)
                return CourtCard(
                    id: group.id,
                    venueID: group.venueID,
                    groupName: group.label,
                    courtLabel: group.label,
                    rankOrder: group.rankOrder,
                    coachID: coach?.id,
                    coachName: coach?.name,
                    playersHere: camp.players(inGroup: group.id)
                        .count { !camp.isAway($0.id, on: .today) },
                    activity: activity,
                    // A closed court keeps its card — the design draws the reason on it — so the
                    // closure is an overlay on the derivation, not a row that replaces it.
                    status: closedCourts[group.id].map { .closed(reason: $0) } ?? .open
                )
            }
    }

    func setCourtStatus(
        _ status: CourtStatus, forGroup groupID: Group.ID, campID: Camp.ID
    ) async throws -> [CourtCard] {
        let camp = try await camp(id: campID)
        guard let group = camp.groups.first(where: { $0.id == groupID }) else {
            throw SycamoreError.unknownGroup
        }
        switch status {
        case .open: closedCourts[groupID] = nil
        case .closed(let reason): closedCourts[groupID] = reason
        }
        return try await courts(forVenue: group.venueID, campID: campID)
    }

    /// A day's blocks, with each one's notes *derived* rather than stored.
    ///
    /// A note is a row of `sectionEightInbox` of kind `.note` carrying this block's id, which is
    /// what a note is in Postgres — an `inbox_items` row with a `schedule_block_id`. It would
    /// have been fewer lines to keep the array on the block, and it would have meant the two
    /// builds disagreed about *where a note lives*: adding one offline would put it on `8k` and
    /// nowhere near `8r`, while the same tap online would put it in both. That is the exact class
    /// of bug this file already caught twice — `courts` had "two implementations of one question
    /// with no way to check them against each other" a few lines above, and the head-count had
    /// the same in `SupabaseRepository+SectionEight`'s header.
    ///
    /// It also means a seeded note shows up on the Inbox tab in previews, which is not a side
    /// effect to apologise for. Those rows *are* inbox rows.
    ///
    /// The Postgres read orders notes by `created_at` ascending; the filter below keeps them in
    /// `sectionEightInbox` order, which is insertion order and therefore the same order — with
    /// the array settling the ties that a timestamp on its own leaves open.
    func scheduleBlocks(
        forVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let staff = (try? await camp(id: campID))?.staff ?? []
        let authorNames = Dictionary(
            staff.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }
        )
        // Grouped once rather than filtered per block, which is what the Postgres sibling does
        // and the only reason to write it out here too: two implementations of one question that
        // differ in shape are how they start differing in answer.
        let notesByBlock = Dictionary(
            grouping: sectionEightInbox.filter { $0.kind == .note },
            by: { $0.scheduleBlockID }
        )
        return sectionEightBlocks
            .filter { $0.venueID == venueID && $0.day == day }
            .sorted { $0.startsAt.id < $1.startsAt.id }
            .map { block in
                var block = block
                block.notes = (notesByBlock[block.id] ?? [])
                    .map { item in
                        BlockNote(
                            id: item.id,
                            // `detail ?? title`, the same way round as the Postgres read: a note
                            // written against a block puts its sentence in `detail`, and `title`
                            // stands in only for a row that was given nothing else.
                            text: item.detail ?? item.title,
                            authorName: item.actorID.flatMap { authorNames[$0] },
                            at: item.createdAt
                        )
                    }
                return block
            }
    }

    /// Stores the block, and splits any notes it arrived with into inbox rows.
    ///
    /// A fixture states its notes inline — `ScheduleSampleDay` does, which is how every Schedule
    /// preview is populated — so a block can turn up here carrying some. They are unpacked rather
    /// than kept, because the read above derives them and a stored copy would be a second answer
    /// to the same question that nothing ever looks at.
    ///
    /// `note.id` becomes the row's id and `note.at` its `createdAt`, so the note keeps its
    /// identity and its place in the order across the round trip. The author is matched by name,
    /// which is the inverse of the read resolving `actorID` to one: a fixture has no ids to give,
    /// and an unrecognised name lands as nil rather than inventing a staff row for it.
    ///
    /// The one place this build is knowingly more generous than Postgres, and the bounds matter.
    /// `SupabaseRepository.addScheduleBlock` writes the block and its coaches and drops any notes
    /// it came with, because `scheduleRow` has no column for them and reversing a *name* into an
    /// `inbox_items.actor_id` would mean guessing which of two people called Alex wrote it —
    /// against a real database, a wrong author is worse than none. No screen can reach the
    /// difference: the Add-block sheet composes a block with no notes on it, and the only caller
    /// that supplies any is `ScheduleSampleDay`, which exists to populate a preview.
    func addScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock] {
        var stored = block
        stored.notes = []
        sectionEightBlocks.append(stored)

        let staff = (try? await camp(id: campID))?.staff ?? []
        sectionEightInbox.append(contentsOf: block.notes.map { note in
            InboxItem(
                id: note.id,
                venueID: block.venueID,
                kind: .note,
                title: block.title,
                detail: note.text,
                actorID: note.authorName.flatMap { name in staff.first { $0.name == name }?.id },
                scheduleBlockID: block.id,
                createdAt: note.at
            )
        })
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func updateScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock] {
        guard let index = sectionEightBlocks.firstIndex(where: { $0.id == block.id }) else {
            throw SycamoreError.unknownGroup
        }
        // The incoming notes are dropped rather than stored, and deliberately not unpacked the
        // way `addScheduleBlock` unpacks them: the block being edited was read from here a moment
        // ago, so its notes are already rows and re-adding them would double every one of them.
        // Postgres does the same by omission — `scheduleRow` has no column for them.
        var stored = block
        stored.notes = []
        sectionEightBlocks[index] = stored
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func deleteScheduleBlock(
        _ blockID: ScheduleBlock.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        guard let block = sectionEightBlocks.first(where: { $0.id == blockID }) else {
            throw SycamoreError.unknownGroup
        }
        removeBlocks { $0.id == blockID }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    /// Drops blocks *and* the inbox rows hanging off them, which is what
    /// `inbox_items_schedule_block_id_fkey`'s `on delete cascade` does on the other side.
    ///
    /// Without it this build would keep notes pointing at blocks that are gone — and because the
    /// Inbox reads the same array, they would still be drawn on `8r`, attached to nothing.
    private func removeBlocks(_ isRemoved: (ScheduleBlock) -> Bool) {
        let removed = Set(sectionEightBlocks.filter(isRemoved).map(\.id))
        guard !removed.isEmpty else { return }
        sectionEightBlocks.removeAll { removed.contains($0.id) }
        sectionEightInbox.removeAll { $0.scheduleBlockID.map(removed.contains) ?? false }
    }

    func applyDayShape(
        _ shape: DayShape, toVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        // Replaces the day rather than appending to it. "Start from a shape" is only offered on
        // an empty day, but a double tap must not produce two overlapping timetables.
        //
        // A shape names no coaches — `DayShape.blocks` is `(hour, minute, title, detail)` — so
        // the blocks below arrive with `coachIDs` empty, exactly as they do from Postgres.
        removeBlocks { $0.venueID == venueID && $0.day == day }
        for spec in shape.blocks {
            sectionEightBlocks.append(
                ScheduleBlock(
                    venueID: venueID,
                    day: day,
                    startsAt: TimeOfDay(spec.hour, spec.minute),
                    title: spec.title,
                    detail: spec.detail
                )
            )
        }
        return try await scheduleBlocks(forVenue: venueID, day: day, campID: campID)
    }

    /// Copies a day. The coaches follow the blocks; the notes do not.
    ///
    /// The source is read from `sectionEightBlocks` directly rather than through
    /// `scheduleBlocks(forVenue:day:campID:)`, so a copy is made from a block whose `notes` have
    /// not been derived onto it — which is the same answer Postgres gives for a different reason
    /// (there, a copy is minted a fresh id and no `inbox_items` row points at it). `copy.status`
    /// argues the case below: "net still down, play on 1–3" is true of the morning it was written
    /// and is nobody's instruction for tomorrow. Who is rostered on a block is not that kind of
    /// fact, so `coachIDs` rides along on the copy.
    func copySchedule(
        fromDay: Weekday, toDay: Weekday, venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let source = sectionEightBlocks.filter { $0.venueID == venueID && $0.day == fromDay }
        removeBlocks { $0.venueID == venueID && $0.day == toDay }
        for block in source {
            var copy = block
            copy.id = UUID()
            copy.day = toDay
            // A copied day starts fresh: yesterday's "done" is not today's.
            copy.status = block.status == .done ? .planned : block.status
            sectionEightBlocks.append(copy)
        }
        return try await scheduleBlocks(forVenue: venueID, day: toDay, campID: campID)
    }

    /// Writes the note as an inbox row, in the same words the Postgres one uses: the block's
    /// title in `title`, the note in `detail`. Nothing is appended to the block — see
    /// `scheduleBlocks(forVenue:day:campID:)` for where a note actually lives.
    func addBlockNote(
        _ text: String, to block: ScheduleBlock, authorID: StaffMember.ID?, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        guard sectionEightBlocks.contains(where: { $0.id == block.id }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightInbox.append(
            InboxItem(
                venueID: block.venueID,
                kind: .note,
                title: block.title,
                detail: text,
                actorID: authorID,
                scheduleBlockID: block.id
            )
        )
        return try await scheduleBlocks(
            forVenue: block.venueID, day: block.day, campID: campID
        )
    }

    /// By id alone, which is what the Postgres delete filters on. Narrowing it to the block as
    /// well would make this build stricter than the real one — a difference only the offline
    /// build could ever show you.
    func deleteBlockNote(
        _ noteID: InboxItem.ID, from block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        guard sectionEightInbox.contains(where: { $0.id == noteID }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightInbox.removeAll { $0.id == noteID }
        return try await scheduleBlocks(
            forVenue: block.venueID, day: block.day, campID: campID
        )
    }

    /// The camp's venues are the filter, because an Inbox row reaches its camp through its venue
    /// — `inbox_items.site_id` → `sites.camp_id` is what the Postgres side joins on, and this has
    /// to answer the same question the same way.
    ///
    /// A camp this repository does not hold has no venues and so no Inbox, rather than raising:
    /// the Postgres read is a filter on `sites.camp_id`, and a camp that is not there matches no
    /// site. An offline build that threw where the real one returns nothing would be a difference
    /// only the offline build could show you.
    func inboxItems(forCamp campID: Camp.ID) async throws -> [InboxItem] {
        let venues = (try? await camp(id: campID))?.venues ?? []
        let venueIDs = Set(venues.map(\.id))
        return sectionEightInbox
            .filter { venueIDs.contains($0.venueID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func resolveInboxItem(_ itemID: InboxItem.ID, forCamp campID: Camp.ID) async throws -> [InboxItem] {
        guard let index = sectionEightInbox.firstIndex(where: { $0.id == itemID }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightInbox[index].resolved = true
        return try await inboxItems(forCamp: campID)
    }

    func addInboxItem(_ item: InboxItem, forCamp campID: Camp.ID) async throws -> [InboxItem] {
        sectionEightInbox.append(item)
        return try await inboxItems(forCamp: campID)
    }

    func setPinned(
        _ pinned: Bool, forItem itemID: InboxItem.ID, forCamp campID: Camp.ID
    ) async throws -> [InboxItem] {
        guard let index = sectionEightInbox.firstIndex(where: { $0.id == itemID }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightInbox[index].pinned = pinned
        return try await inboxItems(forCamp: campID)
    }

    func inboxItems(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [InboxItem] {
        sectionEightInbox
            .filter { $0.venueID == venueID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func resolveInboxItem(_ itemID: InboxItem.ID, campID: Camp.ID) async throws -> [InboxItem] {
        guard let index = sectionEightInbox.firstIndex(where: { $0.id == itemID }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightInbox[index].resolved = true
        let venueID = sectionEightInbox[index].venueID
        return try await inboxItems(forVenue: venueID, campID: campID)
    }

    func addInboxItem(_ item: InboxItem, campID: Camp.ID) async throws -> [InboxItem] {
        sectionEightInbox.append(item)
        return try await inboxItems(forVenue: item.venueID, campID: campID)
    }
}
