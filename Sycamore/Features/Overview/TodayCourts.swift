//
//  TodayCourts.swift
//  Sycamore
//
//  The three things a court card says that the `today_courts` row itself does not: the numbered
//  list of kids under it, the ceiling its head-count is measured against, and how its two lines of
//  heading are composed.
//
//  It used to derive the cards as well, because the repository answered `[]` and the screen made
//  up the difference in the feature layer. `InMemoryRepository` derives them from the camp graph
//  now — one implementation of "what is on each court today", where there were two with no way to
//  check them against each other — so what is left here is drawing, not data.
//
//  The roster stays because no relation returns it: `today_courts` is one row per court, and the
//  kids on a court come out of the graph the app has already loaded. The ceiling is here for the
//  same reason — `CourtCard` carries `playersHere` and no denominator, and `groups.capacity` is a
//  column of the camp.
//
//  It builds every court's list in a single call now rather than one court's on request. Overview
//  used to name a single "detailed" card and hand back `.none` for the rest, so the screen showed
//  the kids on exactly one court out of twelve; every card carries its own list today, folded to
//  a few names with a control to open it. See `rosters(in:day:)` for why that is one pass and not
//  a loop of the old call.
//

import Foundation

// MARK: - The list under a card

enum TodayCourts {

    /// Every court's kids at once, renumbered 1…n, in one pass over the camp.
    ///
    /// Away kids are left out entirely rather than greyed the way Groups draws them. Overview
    /// answers "who is on this court right now", and the design's own list bears that out — it
    /// runs 1 to 5 with no gap where the away kid sits, and its `+3 more` adds up to the
    /// headcount in the line above rather than to the roll. So an expanded court card here is
    /// still shorter than the group card for the same court, and that is correct.
    ///
    /// **Why every court in one call.** Overview used to list exactly one, so asking the graph
    /// for that court's roster cost nothing. Every card listing its kids changes the arithmetic:
    /// `Camp.players(inGroup:)` filters *and sorts* the whole player array, and
    /// `Camp.isAway(_:on:)` scans the whole attendance table for each kid — once per card that
    /// is O(courts × players) on every `body` pass, twelve walks of a hundred kids on a
    /// twelve-court camp. `GroupsView` hit the same wall and answered it the same way; see
    /// `rankRanges(in:)` there. This is that answer, in O(players), once.
    ///
    /// Courts with nobody on them today are simply absent from the dictionary. A lookup that
    /// misses and an empty roster are the same thing to a card, and `roster(for:from:)` reads
    /// the miss as `.none`.
    ///
    /// `venueID` narrows the walk to the venue being drawn. Nil builds the whole camp, which is
    /// what the tests and the fixtures want.
    ///
    /// `courts` narrows it further, to the courts that will actually draw a list. `8j` is why:
    /// a coach sees their own court in full and every other one as a `CondensedCourtRow`, which
    /// takes no roster at all — so on a twelve-court venue eleven of these were built, sorted and
    /// allocated a `PlayerRow` per kid on every tick of the clock, for nobody. Nil is every court,
    /// which is `8i`.
    static func rosters(
        in camp: Camp, day: Weekday = .today, venueID: Venue.ID? = nil, courts: Set<Group.ID>? = nil
    ) -> [Group.ID: CourtRoster] {
        // The day's attendance, indexed once.
        //
        // First row wins, because `Camp.attendance(for:on:)` takes `first` and this has to be
        // the same reading of the same table. `upsertAttendance` keeps at most one row per kid
        // per day, so the two can only differ on a graph that is already wrong — but differing
        // *quietly* is how two readings drift apart in the first place.
        var attendance: [Player.ID: Attendance] = [:]
        for record in camp.attendance where record.day == day {
            if attendance[record.playerID] == nil { attendance[record.playerID] = record }
        }

        var byCourt: [Group.ID: [Player]] = [:]
        for player in camp.players {
            guard let courtID = player.groupID else { continue }
            // Overview draws one venue at a time — `store.courts` is `readVenueID`'s courts —
            // so on a multi-venue camp the rest of the roll would be built into rows nothing
            // ever looks up. One comparison in a loop that already runs, rather than a second
            // pass to filter afterwards.
            if let venueID, player.venueID != venueID { continue }
            if let courts, !courts.contains(courtID) { continue }
            // Sparse by design — a kid with no row is here all day, which is why this asks
            // `!= false` rather than `== true`.
            guard attendance[player.id]?.present != false else { continue }
            byCourt[courtID, default: []].append(player)
        }

        return byCourt.mapValues { players in
            CourtRoster(
                rows: players
                    .sorted { $0.courtRank < $1.courtRank }
                    .enumerated()
                    .map { position, player in
                        PlayerRow(
                            id: player.id,
                            player: player,
                            // 1…n, not `courtRank`. Renumbering is what closes the gap an away
                            // kid leaves, and what makes `+N more` add up to `playersHere`.
                            rank: position + 1,
                            isAway: false,
                            leavesAt: attendance[player.id]?.leavesAt
                        )
                    },
                overflow: 0
            )
        }
    }

    /// The list one card draws: its court's kids folded to `preview`, or nobody at all.
    ///
    /// A closed court lists nobody — there is nobody on it — and that guard lives here rather
    /// than in the view so it can be tested with the fold arithmetic it sits beside.
    static func roster(
        for card: CourtCard,
        from rosters: [Group.ID: CourtRoster],
        preview: Int,
        isExpanded: Bool
    ) -> CourtRoster {
        guard !card.isClosed, let roster = rosters[card.id] else { return .none }
        return roster.folded(to: preview, isExpanded: isExpanded)
    }

    /// One court on its own, folded to `limit`.
    ///
    /// The screen no longer asks for a single court — it draws them all — but a preview that
    /// puts one card on screen still does. Expressed through `rosters(in:)` rather than
    /// filtering the roll again, so there is one implementation of "who is on a court" and not
    /// two that can quietly drift apart.
    ///
    /// **Fixtures and tests only. Do not call this from a screen.** Sharing the implementation
    /// is what makes it correct and also what makes it wasteful: it builds every court in the
    /// camp and returns one, so asking it per card in a loop is quadratic in the roll. A view
    /// wants `rosters(in:day:venueID:)` once, held for the pass, and `roster(for:from:…)` per
    /// card — which is exactly what `OverviewScreen` does.
    static func roster(
        forCourt courtID: Group.ID,
        in camp: Camp,
        day: Weekday = .today,
        limit: Int
    ) -> CourtRoster {
        (rosters(in: camp, day: day)[courtID] ?? .none).folded(to: limit)
    }
}

// MARK: - How full each court can be

extension TodayCourts {

    /// Every court's ceiling, keyed the way the cards are.
    ///
    /// The other half of `8i`'s "6 of 8". `CourtCard` carries `playersHere` and nothing to measure
    /// it against, because `today_courts` is a view over attendance and a court's ceiling is a
    /// column of `groups` — so the denominator has to come off the camp graph, and this is where
    /// Overview reads the camp.
    ///
    /// One pass and one dictionary, handed down, for the reason `rosters(in:day:venueID:)` gives
    /// about itself: `Camp.group(_:)` is a linear search (`Models.swift:974`), and a card asking
    /// for its own ceiling inside `body` would be that search once per court on every tick of the
    /// clock. Courts are few and it would not have shown up in a profile — which is exactly why it
    /// is worth refusing here rather than after somebody adds a twelfth venue.
    ///
    /// `venueID` narrows it to the venue being drawn. Nil takes the whole camp, which is what the
    /// previews and the tests want.
    static func capacities(in camp: Camp, venueID: Venue.ID? = nil) -> [Group.ID: Int] {
        var byCourt: [Group.ID: Int] = [:]
        for group in camp.groups where venueID == nil || group.venueID == venueID {
            byCourt[group.id] = group.capacity
        }
        return byCourt
    }
}

// MARK: - What a card says

extension CourtCard {

    /// The card's big line — what is happening on this court.
    ///
    /// `8i` heads every card with the activity: "Drills", "Match play", "Skills rotation", "Net
    /// down". With no schedule to resolve one from, the court itself is the truest heading there
    /// is — and in that case it is *not* also drawn as the overline, which is the whole of what
    /// `overviewCourtLabel` says.
    var overviewTitle: String { activity ?? courtLabel ?? groupName }

    /// `COURT 1` — the overline above it, or nil when the title is already the court's name.
    ///
    /// The design draws these as two rows of one heading: a small tracked label, and the activity
    /// under it. That only works while they say different things. A court with no activity has one
    /// heading and it is the court, so the overline stands down rather than repeating the line
    /// directly beneath it.
    ///
    /// The pair is expressed as two properties over one rule rather than as a title that sometimes
    /// contains its own label, so a caller cannot draw the second without having asked about the
    /// first. `CondensedCourtRow` reads both for the same reason.
    var overviewCourtLabel: String? { activity == nil ? nil : (courtLabel ?? groupName) }

    var isClosed: Bool { status.isClosed }
}
