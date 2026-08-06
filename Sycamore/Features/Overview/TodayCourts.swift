//
//  TodayCourts.swift
//  Sycamore
//
//  What Overview draws, worked out from what the app actually knows.
//
//  `CourtCard` is backed by the `today_courts` view, and nothing on the device talks to
//  Postgres yet — so `courts(forVenue:campID:)` comes back empty on every launch. The screen
//  does not fake that away and it does not shrug at it either: every column that view selects
//  is already in the camp graph the app has loaded, so the cards are computed from it here
//  until the view exists. The one thing the graph cannot answer is which activity is running,
//  which is why that arrives as a parameter rather than being guessed at.
//
//  This whole file is the thing to delete once `today_courts` is live.
//

import Foundation

// MARK: - Derivation

enum TodayCourts {

    /// Every court at a venue, as `today_courts` would return it.
    ///
    /// `playersHere` counts the kids who are *here* rather than the kids on the roll, which is
    /// what makes a court of nine with one away read "8 players" — the number the design
    /// prints, and the same number the roster below it adds up to.
    static func derive(
        forVenue venueID: Venue.ID,
        in camp: Camp,
        activity: String?,
        day: Weekday = .today
    ) -> [CourtCard] {
        camp.groups(in: venueID).map { group in
            let coach = camp.coach(forGroup: group.id)
            return CourtCard(
                id: group.id,
                venueID: group.venueID,
                groupName: group.label,
                courtLabel: group.label,
                rankOrder: group.rankOrder,
                coachID: coach?.id,
                coachName: coach?.name,
                playersHere: camp.players(inGroup: group.id).count { !camp.isAway($0.id, on: day) },
                activity: activity,
                status: .open
            )
        }
    }

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

    // MARK: The block running now

    /// The block covering `time` — "Skills rotation · until 10:30".
    ///
    /// Blocks arrive in start order, so the last one that has started is the current one. A
    /// block with no end runs until the next one begins, which is what makes the search a
    /// last-match rather than a first-match.
    static func running(in blocks: [ScheduleBlock], at time: TimeOfDay) -> ScheduleBlock? {
        blocks.last { block in
            guard block.startsAt <= time else { return false }
            guard let ends = block.endsAt else { return true }
            return time < ends
        }
    }

    /// The camp's own clock. Takes its inputs so a preview can stand somewhere else in the day.
    static func now(_ date: Date = .now, calendar: Calendar = .current) -> TimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(parts.hour ?? 0, parts.minute ?? 0)
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
