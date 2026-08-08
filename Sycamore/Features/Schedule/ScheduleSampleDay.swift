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

    /// A note with a minted id, because a fixture has no server to get one from. Fresh per call
    /// so two notes reading the same words are still two rows.
    private static func note(_ text: String, by author: String? = nil) -> BlockNote {
        BlockNote(id: UUID(), text: text, authorName: author, at: .now)
    }

    /// `AppStore.preview`, promoted.
    ///
    /// Three screens on Schedule now draw something only an admin sees — the note composer, the
    /// per-note delete, the "Assign" on an uncovered block — and `AppStore.preview` is Alex, who
    /// is a *worker* at UCLA. `AppStore.previewAdmin` is an admin, but of Westside Swim, which has
    /// none of the venues or staff these fixtures are built from, so its previews would draw an
    /// empty screen for the opposite reason.
    ///
    /// Promoting the membership is the smallest change that keeps the camp: `role` lives on the
    /// membership and never on the account, which is the whole point of `Role`'s own header —
    /// "the same login can be an admin at one camp and a worker at another".
    @MainActor
    static func adminStore() -> AppStore {
        let store = AppStore.preview
        var membership = SampleData.uclaMembership
        membership.role = .admin
        store.selectedMembership = membership
        return store
    }
}
