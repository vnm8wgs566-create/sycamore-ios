//
//  InboxPreviewItems.swift
//  Sycamore
//
//  The seven rows the design draws on `8r`, built against whatever day the preview runs on.
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

        return [
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
                venueID: venueID, kind: .note,
                title: "Nass pinned a note",
                detail: "Skills rotation · net on 4 is loose",
                actorID: nass,
                createdAt: at(9, 52)
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
}
#endif
