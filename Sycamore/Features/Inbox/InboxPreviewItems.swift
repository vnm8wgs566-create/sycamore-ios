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
//  Compiled in release as well as debug, which is not where this file started. All of it sat
//  behind `#if DEBUG` and the previews that read it did not, which is a contradiction rather
//  than an arrangement: `#Preview` expands in every configuration, so a release build reached for
//  `InboxPreviewItems` and found nothing there. Debug was clean and release was 29 errors, all of
//  them in this feature and in `DesignSystem/MoreRow.swift`, and TestFlight was on the far side
//  of them.
//
//  The alternative was to guard the previews to match — `#if DEBUG` around each `#Preview` as
//  well as around the scenery. Rejected on the evidence of the rest of the app: 173 `#Preview`
//  blocks across 97 files already compile in release, beside harnesses declared plainly at file
//  scope (`TabBarPreviewHarness`, `GroupCardPreviewHarness`) and fixtures reached the same way
//  (`AppStore.preview`, `SampleData`). Guarding six files would have made them the exception a
//  second time, in the opposite direction, and left the next preview added here to guess which
//  half of the app it belonged to. Release carries a few kilobytes of scenery for that; nothing
//  in this file is reachable from the running app, whose only route in would be a call, and
//  `#Preview` is the only caller there is.
//

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

}
