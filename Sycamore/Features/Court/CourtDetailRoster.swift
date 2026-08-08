//
//  CourtDetailRoster.swift
//  Sycamore
//
//  Who is on one court today — and, unlike Overview, who is not.
//
//  **This is the one place the court screen deliberately parts company with the card that opens
//  it.** `TodayCourts.rosters(in:day:venueID:)` drops away kids from a court's list entirely, and
//  that is right for Overview: a card answers "who is on this court right now" in five lines
//  beside a headcount, and the design's own frame runs 1 to 5 with no gap where the away child
//  sits. A screen *about* one court is the other question. A coach standing on it wants to know
//  that Liam is not here, and the app currently has nowhere at all that says so for a court —
//  Groups greys away kids but is organised by group, not by the day.
//
//  So the two lists are kept apart rather than merged, and that is the whole design of this type:
//
//      here   the kids standing on the court, numbered 1…n — byte for byte the list the card
//             draws, so the screen and the card can never disagree about a name or a numeral.
//      away   the rest of the roll, in court order, drawn under their own heading.
//
//  Merging them would have broken both of Overview's invariants at once: the renumbering (an away
//  kid carrying `courtRank` 4 among kids numbered 1…n is two numbering schemes in one column) and
//  the head-count (`+N more` and "8 players" count the kids who are *here*). Split, neither moves.
//
//  Built one court at a time rather than through `TodayCourts.rosters`, which builds every court
//  in the camp in one pass. That call exists because Overview draws twelve cards at once and
//  asking per card was O(courts × players) on every `body`; this screen draws one court, so the
//  cheap thing and the shared thing point in opposite directions. `CourtDetailRosterTests` pins
//  the two answers together instead.
//

import Foundation

struct CourtDetailRoster: Hashable, Sendable {

    /// The kids on the court today, numbered 1…n.
    ///
    /// A `CourtRoster` rather than a bare array so the screen's list is the same type — and the
    /// same invariant — as the card's, and so `headcount` means the same thing on both.
    var here: CourtRoster

    /// The kids on this court's roll who are not in today, in court order. Empty on the ordinary
    /// morning, which is what keeps the section off the screen entirely.
    var away: [PlayerRow]

    /// A court with nobody on its roll at all: one that has not been dealt yet, or one that is
    /// not in the camp graph.
    static let none = CourtDetailRoster(here: .none, away: [])

    /// Everybody on the roll, here or not — which is the number the court's capacity is measured
    /// against, and deliberately not the number the lede reads out.
    var rollCount: Int { here.rows.count + away.count }

    var isEmpty: Bool { here.isEmpty && away.isEmpty }
}

// MARK: - Building it

extension CourtDetailRoster {

    /// One court's day, off the camp graph.
    ///
    /// `camp.players(inGroup:)` already sorts by `courtRank`, so the order below is the court's
    /// own order and the numbering that follows it is 1…n over the kids who turned up — the same
    /// rule `TodayCourts.rosters` applies, stated once more because this walks one court's roll
    /// rather than the whole camp's.
    ///
    /// Attendance is read through `Camp.attendance(for:on:)`, which takes the *first* matching
    /// row. `TodayCourts.rosters` indexes the table first-row-wins for the same reason, and the
    /// two have to be the same reading of the same table or the screen and the card can quietly
    /// disagree about who is here. `upsertAttendance` keeps at most one row per kid per day, so
    /// they can only differ on a graph that is already wrong.
    static func build(
        forCourt courtID: Group.ID, in camp: Camp, day: Weekday = .today
    ) -> CourtDetailRoster {
        var here: [PlayerRow] = []
        var away: [PlayerRow] = []

        for player in camp.players(inGroup: courtID) {
            let record = camp.attendance(for: player.id, on: day)
            // Sparse by design — a kid with no row is here all day, which is why this asks
            // `!= false` rather than `== true`.
            if record?.present != false {
                here.append(
                    PlayerRow(
                        id: player.id,
                        player: player,
                        // 1…n, not `courtRank`. Renumbering is what closes the gap an away kid
                        // leaves, and what keeps this list identical to the card's.
                        rank: here.count + 1,
                        isAway: false,
                        leavesAt: record?.leavesAt
                    )
                )
            } else {
                away.append(
                    PlayerRow(
                        id: player.id,
                        player: player,
                        // Their place on the court when they are on it. Nothing draws it — an
                        // away row shows no numeral, because it would be a number from the other
                        // scheme — but a row is not entitled to invent a rank it does not have,
                        // and 0 is a rank nobody holds.
                        rank: player.courtRank,
                        isAway: true,
                        // A kid who is not in has no pick-up today, whatever the row says: the
                        // clock beside a name means "goes home early", and they have gone.
                        leavesAt: nil
                    )
                )
            }
        }

        return CourtDetailRoster(here: CourtRoster(rows: here, overflow: 0), away: away)
    }
}
