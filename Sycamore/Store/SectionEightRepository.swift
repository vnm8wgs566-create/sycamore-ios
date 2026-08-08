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
    // about a venue. The per-venue three below cannot express that, and the app has been papering
    // over it: `AppStore.readVenueID` picks the camp's first venue and the Inbox shows that one
    // venue's rows. Against the seeded camp today that hides exactly the row the design uses as
    // its example, because the only LATC row is the only row not at Sycamore.
    //
    // The per-venue three are kept rather than replaced because `AppStore+SectionEight` and
    // `InboxView` still call them. They should move to `forCamp:` and then these should go.

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

    func scheduleBlocks(
        forVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        sectionEightBlocks
            .filter { $0.venueID == venueID && $0.day == day }
            .sorted { $0.startsAt.id < $1.startsAt.id }
    }

    func addScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock] {
        sectionEightBlocks.append(block)
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func updateScheduleBlock(_ block: ScheduleBlock, campID: Camp.ID) async throws -> [ScheduleBlock] {
        guard let index = sectionEightBlocks.firstIndex(where: { $0.id == block.id }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightBlocks[index] = block
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func deleteScheduleBlock(
        _ blockID: ScheduleBlock.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        guard let block = sectionEightBlocks.first(where: { $0.id == blockID }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightBlocks.removeAll { $0.id == blockID }
        return try await scheduleBlocks(forVenue: block.venueID, day: block.day, campID: campID)
    }

    func applyDayShape(
        _ shape: DayShape, toVenue venueID: Venue.ID, day: Weekday, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        // Replaces the day rather than appending to it. "Start from a shape" is only offered on
        // an empty day, but a double tap must not produce two overlapping timetables.
        sectionEightBlocks.removeAll { $0.venueID == venueID && $0.day == day }
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

    func copySchedule(
        fromDay: Weekday, toDay: Weekday, venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        let source = sectionEightBlocks.filter { $0.venueID == venueID && $0.day == fromDay }
        sectionEightBlocks.removeAll { $0.venueID == venueID && $0.day == toDay }
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

    func addBlockNote(
        _ text: String, to block: ScheduleBlock, authorID: StaffMember.ID?, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        guard let index = sectionEightBlocks.firstIndex(where: { $0.id == block.id }) else {
            throw SycamoreError.unknownGroup
        }
        let author = (try? await camp(id: campID))?.staff.first { $0.id == authorID }
        sectionEightBlocks[index].notes.append(
            BlockNote(id: UUID(), text: text, authorName: author?.name, at: .now)
        )
        return try await scheduleBlocks(
            forVenue: block.venueID, day: block.day, campID: campID
        )
    }

    func deleteBlockNote(
        _ noteID: InboxItem.ID, from block: ScheduleBlock, campID: Camp.ID
    ) async throws -> [ScheduleBlock] {
        guard let index = sectionEightBlocks.firstIndex(where: { $0.id == block.id }) else {
            throw SycamoreError.unknownGroup
        }
        sectionEightBlocks[index].notes.removeAll { $0.id == noteID }
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
