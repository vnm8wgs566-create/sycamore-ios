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
    ///
    /// Every row here is an **offset from `now`**, which it was not. Three of them used to be
    /// clock times — 9:44, 9:31, 9:12, built from the day's midnight — so the feed under them
    /// read "This morning" at four in the afternoon, at ten at night, and for ever. That is the
    /// one thing `InboxBucket` exists to stop a screen doing (`InboxBucket.swift:5-9`), and the
    /// fixture meant to demonstrate it was quietly the counter-example.
    ///
    /// Offsets are what the design already used for half the file anyway, and the whole mock is
    /// one clock: the top ask is drawn "8 min" old, the one under it forty, and 9:52 less those
    /// forty minutes is exactly the 9:12 the last feed row was written at. So the morning is
    /// 8, 21 and 40 minutes back, which is the same picture with a clock that moves.
    ///
    /// Near a boundary the morning genuinely splits — a preview opened at 12:05 puts the eight
    /// minute-old row under "This afternoon" and the forty minute-old one under "This morning".
    /// That is not a flaw in the fixture; it is the screen being right, and it is only visible
    /// at all now that the fixture can reach noon.
    static func morning(
        venueID: Venue.ID,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [InboxItem] {
        func minutesAgo(_ minutes: Int) -> Date {
            now.addingTimeInterval(-Double(minutes) * 60)
        }

        // Yesterday's row is the one that still wants a clock time, because the hour is the only
        // part of it that does not matter: any time yesterday draws the same "Yesterday" heading,
        // and the design's 16:20 is what it says on the row. The last use of the day's own
        // midnight, so it is worked out here rather than through a helper nothing else calls.
        let midnight = calendar.startOfDay(for: now)
        let yesterdayAfternoon = calendar.date(
            byAdding: DateComponents(day: -1, hour: 16, minute: 20), to: midnight
        ) ?? midnight

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
                // The two rows the design labels by age rather than by clock — "8 min", "40 min"
                // — and the pair the rest of the morning is now measured against.
                createdAt: minutesAgo(8)
            ),
            InboxItem(
                venueID: venueID, kind: .needsAction,
                title: "LATC is 2 coaches short",
                detail: "10:45 match play · unassigned",
                actionLabel: "Assign",
                createdAt: minutesAgo(40)
            ),
            // The one row here whose sentence the app itself now writes differently. `8r` draws
            // "Mum collects at the gate", and there is no field on `InboxItem` for who collects
            // a kid — so `AppStore.pickupActivity` writes the day and the court instead, and
            // spells the time `2:30pm`. The design's line is kept as the scenery it is; the row
            // beneath it is the shape the shipped one has.
            InboxItem(
                venueID: venueID, kind: .activity,
                title: "Serene Chu leaves at 2:30",
                detail: "Mum collects at the gate · today",
                playerID: serene,
                createdAt: minutesAgo(8)
            ),
            InboxItem(
                venueID: venueID, kind: .note,
                title: "Hubert · Court 2",
                detail: "Two in sandals, benched until shoes turn up",
                groupID: court2,
                createdAt: minutesAgo(21)
            ),
            // Written "Dana · 9:12" until the timestamps above it started moving, at which point
            // a clock time typed into the second line was a number that disagreed with the row it
            // was on. `AppStore.awayActivity` never wrote one — the court and the author are what
            // it puts there, and the feed's own heading is where the time lives.
            InboxItem(
                venueID: venueID, kind: .activity,
                title: "Jonah Reyes marked away",
                detail: "Court 2 · by Dana",
                actorID: dana, playerID: jonah, groupID: court2,
                createdAt: minutesAgo(40)
            ),
            InboxItem(
                venueID: venueID, kind: .activity,
                title: "Rank order published",
                detail: "Sycamore · 6 groups · by Nass",
                actorID: nass,
                createdAt: yesterdayAfternoon
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
