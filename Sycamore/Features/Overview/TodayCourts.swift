//
//  TodayCourts.swift
//  Sycamore
//
//  The two things a court card says that the `today_courts` row itself does not: the numbered
//  list of kids under it, and how its two lines of copy are composed.
//
//  It used to derive the cards as well, because the repository answered `[]` and the screen made
//  up the difference in the feature layer. `InMemoryRepository` derives them from the camp graph
//  now — one implementation of "what is on each court today", where there were two with no way to
//  check them against each other — so what is left here is drawing, not data.
//
//  The roster stays because no relation returns it: `today_courts` is one row per court, and the
//  kids on a court come out of the graph the app has already loaded.
//

import Foundation

// MARK: - The list under a card

enum TodayCourts {

    /// The first `limit` kids on a court, renumbered 1…n.
    ///
    /// Away kids are left out entirely rather than greyed the way Groups draws them. Overview
    /// answers "who is on this court right now", and the design's own list bears that out — it
    /// runs 1 to 5 with no gap where the away kid sits, and its `+3 more` adds up to the
    /// headcount in the line above rather than to the roll.
    static func roster(
        forCourt courtID: Group.ID,
        in camp: Camp,
        day: Weekday = .today,
        limit: Int
    ) -> CourtRoster {
        let here = camp.players(inGroup: courtID).filter { !camp.isAway($0.id, on: day) }
        let shown = here.prefix(limit)
        return CourtRoster(
            rows: shown.enumerated().map { position, player in
                PlayerRow(
                    id: player.id,
                    player: player,
                    rank: position + 1,
                    isAway: false,
                    leavesAt: camp.leavesAt(player.id, on: day)
                )
            },
            overflow: here.count - shown.count
        )
    }
}

// MARK: - What a card says

extension CourtCard {

    /// The card's big line. The design heads every card with what is happening on the court;
    /// with no schedule to resolve an activity from, the court itself is the truest heading
    /// there is.
    var overviewTitle: String { activity ?? courtLabel ?? groupName }

    /// `Court 1 – 8 players`, or `Court 4 – Tom is on it`.
    ///
    /// `subtitle` leads with the court label, which is right under an activity and says the
    /// same thing twice under the fallback title above — so the label is dropped once it has
    /// already been read out as the title.
    var overviewSubtitle: String {
        guard activity == nil else { return subtitle }
        if case .closed(let reason) = status { return reason }
        return "\(playersHere) player\(playersHere == 1 ? "" : "s")"
    }

    var isClosed: Bool {
        if case .closed = status { return true }
        return false
    }
}
