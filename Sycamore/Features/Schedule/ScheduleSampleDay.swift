//
//  ScheduleSampleDay.swift
//  Sycamore
//
//  The Tuesday `8k` draws, so the previews for the card, the canvas and the opened block all show
//  the same morning. Beside `SampleData` in spirit — the camp graph has no schedule of its own
//  yet, because `schedule_blocks` was created empty.
//
//  Two mornings now. `blocks(venueID:day:)` is the design's own, simply in order; the canvas made
//  the interesting cases the ones where a day is *not* in order, and those are
//  `overlappingBlocks(venueID:day:)`.
//

import Foundation

enum ScheduleSampleDay {

    /// `8k`, block for block: a drop-off already behind us, the skills rotation running now with
    /// three notes on it, a break, the match play nobody is running, and lunch.
    ///
    /// - Parameter coachIDs: who is running the skills rotation. Empty by default, which is the
    ///   state every preview written before blocks carried coaches expects — and the state the
    ///   real backend still returns, because `scheduleBlocks(…)` does not populate the column yet.
    ///   Pass ids to draw the block with its logistics filled in. Only that one block takes them:
    ///   the design's other four say nothing about who is on them, and putting the same names
    ///   under all five would be the "everyone at this venue" answer this change exists to stop
    ///   giving.
    static func blocks(
        venueID: Venue.ID,
        day: Weekday = .tue,
        coachIDs: [StaffMember.ID] = []
    ) -> [ScheduleBlock] {
        [
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(8, 30), endsAt: TimeOfDay(9, 0),
                title: "Drop-off", status: .done
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(9, 0), endsAt: TimeOfDay(10, 30),
                title: "Skills rotation", detail: "Courts 1–3 · 22 players",
                notes: [
                    note("Net on 4 is loose", by: "Nass"),
                    note("Cones on the service line, cart stays north"),
                    note("Volley ladder after the forehand feeds"),
                ],
                coachIDs: coachIDs
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(10, 30), endsAt: TimeOfDay(10, 45),
                title: "Water & regroup", detail: "15 min",
                notes: [note("shade tent is up")]
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(10, 45), endsAt: TimeOfDay(12, 0),
                title: "Match play", status: .needsCoach,
                notes: [note("Alina can referee court 2"), note("Winners stay on")]
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(12, 0), endsAt: TimeOfDay(13, 0),
                title: "Lunch", detail: "Shade lawn",
                notes: [note("two nut allergies")]
            ),
        ]
    }

    /// A busier Tuesday: the same camp with three things running at once.
    ///
    /// `blocks(venueID:day:)` is the design's own morning and is deliberately left alone — every
    /// other preview and two test suites are calibrated against it, and it is simply in order, one
    /// block after another. That made it the wrong fixture for the day `8k` became a canvas, where
    /// the interesting cases are all about what happens when a morning is *not* in order.
    ///
    /// What it puts on the screen, in one call:
    ///
    ///   - an **open-ended** block, `Drop-off`, which has no `ends_at` and is closed by whatever
    ///     starts next in the same space (`ScheduleTimeline.drawnEnd(of:in:)`) — and is `.done`, so
    ///     it also draws the hollow treatment at its true position;
    ///   - a **three-deep overlap** at ten past nine, which is the packing's hardest case;
    ///   - two `.assigned` blocks on **disjoint courts**, which run alongside each other and are
    ///     *not* a clash — the distinction `ScheduleTimeline`'s header exists to make;
    ///   - a **real clash**, the coach huddle laid over match play, which shares the venue with it;
    ///   - blocks at all three of the card's layout heights: fifteen minutes (30pt), half an hour
    ///     (60pt) and an hour and more.
    ///
    /// The courts are minted per call rather than taken from `SampleData`, because what matters
    /// about them here is only that two of them are not the third.
    static func overlappingBlocks(venueID: Venue.ID, day: Weekday = .tue) -> [ScheduleBlock] {
        let courtOne = CourtGroup.ID()
        let courtTwo = CourtGroup.ID()
        let courtThree = CourtGroup.ID()

        return [
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(8, 30), endsAt: nil,
                title: "Drop-off", status: .done
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(9, 0), endsAt: TimeOfDay(9, 15),
                title: "Warm-up", detail: "Court 1", kind: .assigned, courtIDs: [courtOne]
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(9, 0), endsAt: TimeOfDay(10, 0),
                title: "Free play", detail: "Courts 2–3",
                notes: [note("cart stays north")],
                kind: .assigned, courtIDs: [courtTwo, courtThree]
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(9, 10), endsAt: TimeOfDay(9, 40),
                title: "Parent tour", detail: "Meet at the gate"
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(10, 0), endsAt: TimeOfDay(10, 15),
                title: "Water & regroup", detail: "15 min"
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(10, 15), endsAt: TimeOfDay(12, 0),
                title: "Match play", status: .needsCoach,
                notes: [note("Alina can referee court 2"), note("Winners stay on")]
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(11, 0), endsAt: TimeOfDay(11, 30),
                title: "Coach huddle", detail: "Shade lawn"
            ),
            ScheduleBlock(
                venueID: venueID, day: day, startsAt: TimeOfDay(12, 0), endsAt: TimeOfDay(13, 0),
                title: "Lunch", detail: "Shade lawn",
                notes: [note("two nut allergies")]
            ),
        ]
    }

    /// A note with a minted id, because a fixture has no server to get one from. Fresh per call
    /// so two notes reading the same words are still two rows.
    private static func note(_ text: String, by author: String? = nil) -> BlockNote {
        BlockNote(id: UUID(), text: text, authorName: author, at: .now)
    }

}
