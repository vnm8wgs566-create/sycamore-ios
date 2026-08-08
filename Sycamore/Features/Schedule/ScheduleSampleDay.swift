//
//  ScheduleSampleDay.swift
//  Sycamore
//
//  The Tuesday `8k` draws, so the previews for the card, the list and the opened block all show
//  the same morning. Beside `SampleData` in spirit — the camp graph has no schedule of its own
//  yet, because `schedule_blocks` was created empty.
//

import Foundation

enum ScheduleSampleDay {

    /// `8k`, block for block: a drop-off already behind us, the skills rotation running now with
    /// three notes on it, a break, the match play nobody is running, and lunch.
    static func blocks(venueID: Venue.ID, day: Weekday = .tue) -> [ScheduleBlock] {
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
                ]
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

    /// A note with a minted id, because a fixture has no server to get one from. Fresh per call
    /// so two notes reading the same words are still two rows.
    private static func note(_ text: String, by author: String? = nil) -> BlockNote {
        BlockNote(id: UUID(), text: text, authorName: author, at: .now)
    }
}
