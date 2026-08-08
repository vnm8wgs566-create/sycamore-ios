//
//  InboxPreviewItems.swift
//  Sycamore
//
//  The rows the design draws on `8r`, built against whatever day the preview runs on, plus the
//  two pinned messages the section above them needs to have anything to draw.
//
//  Not in `SampleData`: `inbox_items` ships empty, so these are preview scenery rather than the
//  app's seed data, and putting them in the shipped fixture set would put a fictional morning in
//  front of the first real person who opens the tab.
//

#if DEBUG
import Foundation

enum InboxPreviewItems {

    /// - Parameter venueID: the venue the rows belong to, so a preview can seed the same one
    ///   the screen will go on to ask for.
    static func morning(
        venueID: Venue.ID,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [InboxItem] {
        let midnight = calendar.startOfDay(for: now)
        func at(_ hour: Int, _ minute: Int, daysAgo: Int = 0) -> Date {
            calendar.date(
                byAdding: DateComponents(day: -daysAgo, hour: hour, minute: minute),
                to: midnight
            ) ?? midnight
        }

        // Stand-ins for the people and courts the rows reference. Which of these are filled in
        // matters — `InboxIconTile` reads them to pick the glyph and its tint.
        let nass = UUID(), dana = UUID()
        let austin = UUID(), serene = UUID(), jonah = UUID()
        let court2 = UUID()

        return pinned(venueID: venueID, now: now) + [
            InboxItem(
                venueID: venueID, kind: .needsAction,
                title: "Austin Zheng → Court 2",
                detail: "Nass asked",
                actionLabel: "Review",
                actorID: nass, playerID: austin,
                // Relative rather than a clock time: this row's second line is an age, and the
                // design draws it at eight minutes old.
                createdAt: now.addingTimeInterval(-8 * 60)
            ),
            InboxItem(
                venueID: venueID, kind: .needsAction,
                title: "LATC is 2 coaches short",
                detail: "10:45 match play · unassigned",
                actionLabel: "Assign",
                createdAt: now.addingTimeInterval(-40 * 60)
            ),
            InboxItem(
                venueID: venueID, kind: .activity,
                title: "Serene Chu leaves at 2:30",
                detail: "Mum collects at the gate · today",
                playerID: serene,
                createdAt: at(9, 44)
            ),
            InboxItem(
                venueID: venueID, kind: .note,
                title: "Hubert · Court 2",
                detail: "Two in sandals, benched until shoes turn up",
                groupID: court2,
                createdAt: at(9, 31)
            ),
            InboxItem(
                venueID: venueID, kind: .activity,
                title: "Jonah Reyes marked away",
                detail: "Dana · 9:12",
                actorID: dana, playerID: jonah,
                createdAt: at(9, 12)
            ),
            InboxItem(
                venueID: venueID, kind: .activity,
                title: "Rank order published",
                detail: "Sycamore · 6 groups · by Nass",
                actorID: nass,
                createdAt: at(16, 20, daysAgo: 1)
            ),
        ]
    }

    /// The two pinned messages, on their own, for the previews that draw only that section.
    ///
    /// Both shaped the way the composer writes one: the reader's sentence in `title`, no detail
    /// line, `actorID` filled in and `pinned` set — which is exactly what
    /// `AppStore.addPinnedMessage` stores. The second carries a detail line as well, because
    /// `setPinned` can pin a row that already had one and the section has to draw that too.
    ///
    /// Older than the morning above them on purpose. A pin is the state of the camp rather than
    /// an event in its day, so it predates the day and stays put while the feed moves under it —
    /// which is also the case that proves the section is not sorted into the feed by time.
    static func pinned(venueID: Venue.ID, now: Date = .now) -> [InboxItem] {
        let nass = UUID()
        return [
            InboxItem(
                venueID: venueID, kind: .note,
                title: "Court 4 net is loose — keep the little ones off it.",
                actorID: nass,
                pinned: true,
                createdAt: now.addingTimeInterval(-2 * 60 * 60)
            ),
            InboxItem(
                venueID: venueID, kind: .note,
                title: "Nass pinned a note",
                detail: "Skills rotation · net on 4 is loose",
                actorID: nass,
                pinned: true,
                createdAt: now.addingTimeInterval(-3 * 60 * 60)
            ),
        ]
    }

    /// The same person and the same camp as `AppStore.preview`, with the admin membership.
    ///
    /// `AppStore.preview` reads as a *worker* at UCLA — `SampleData.uclaMembership` is
    /// `role: .worker` — which is the right default for these screens and the wrong one for the
    /// composer. Deliberately not `AppStore.previewAdmin`, which is admin of a *different* camp
    /// (Westside Swim): its venues are not the ones these fixtures are seeded against, so the
    /// Inbox would read an empty venue and the section would have nothing to draw.
    @MainActor
    static var adminStore: AppStore {
        var membership = SampleData.uclaMembership
        membership.role = .admin

        let store = AppStore.preview
        store.memberships = [membership, SampleData.westsideMembership]
        store.selectedMembership = membership
        store.selectedTab = .inbox
        return store
    }
}
#endif
