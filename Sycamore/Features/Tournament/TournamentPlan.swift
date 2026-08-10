//
//  TournamentPlan.swift
//  Sycamore
//
//  Everything a tournament card draws, worked out once from the draw and the camp.
//
//  This is `tCard(camp, venue, t, ti, kmap)` (`design/app/state1.js:761-892`) as a value type. The
//  prototype builds its card as a bag of closures and colour strings inside the render pass; what
//  is left once the colours and the taps are peeled off is a real derivation — resolve every
//  bracket reference, spread the rounds over the days, move a match when somebody in it is away,
//  front-load the early leavers, *then* number the matches M1…Mn in the order they come out. Six
//  steps that depend on each other in that order, and the numbering depends on all five before it.
//
//  ── WHY IT IS NOT IN `Tournament` ─────────────────────────────────────────────────────────────
//
//  `Models/Tournament.swift` is pure and takes no camp. Half of what is below needs one: a kid's
//  name, whether they are away on Tuesday, what time they go home. The model's own header says so
//  — "availability is the one thing that legitimately re-orders a finished draw, and it is not
//  here … what this file gives that layer is `day(ofRound:)`, the *base* day". This is that layer,
//  and `day(ofRound:)` is exactly where it starts.
//
//  ── WHY IT IS NOT IN THE VIEW ─────────────────────────────────────────────────────────────────
//
//  Because it is arithmetic with corners, and a corner in a `body` is a corner nobody checks. A
//  bracket whose feeder was a bye; a round robin where everybody in one match is away every day;
//  a doubles pool of nineteen. Each is a branch below and each is a line somebody can read
//  without driving the app to it.
//
//  It is also what keeps the card cheap. `TournamentCard` is handed a finished plan, so the whole
//  derivation runs once per card per change rather than once per `body` — and this `body` runs
//  whenever a day pill is tapped, a fold opens, or a score lands.
//

import Foundation

// MARK: - The plan

/// One tournament, resolved against the camp it is drawn from.
struct TournamentPlan: Identifiable, Hashable, Sendable {

    // MARK: Pieces

    /// One day of the draw: which day of the tournament, which day of the camp week.
    struct Day: Identifiable, Hashable, Sendable {
        /// 1-based, as `Tournament.day(ofRound:)` counts.
        var index: Int
        var weekday: Weekday
        /// "Today", "Tue" — what the pill says.
        var label: String

        var id: Int { index }
    }

    /// A fixture, placed on a day and numbered.
    struct OrderedMatch: Identifiable, Hashable, Sendable {
        var id: Tournament.Match.ID
        /// "M7". The bracket points back at this — "Winner of M7" — so it is a label somebody
        /// reads and not an index.
        var number: String
        /// Which day of the draw it lands on, after any move for an away day.
        var dayIndex: Int
        var aName: String
        var bName: String
        /// "Serene C + Liam P vs Austin Z + Mia K".
        var label: String
        var score: Tournament.Score?
        /// "Moved — Serene C away Monday", or "Serene C away — walkover risk". Nil when nothing
        /// stands in the way of it.
        var flag: String?
        /// Somebody real on both sides, so there is something to score.
        ///
        /// Not the same question as `Match.isBye`: a bracket's later rounds always have two sides,
        /// and both of them read "Winner of M7" until the feeders have been played. The design
        /// guards its own tap on exactly this (`state1.js:846`, `if (x.A && x.B)`), and a score
        /// sheet opened over two unresolved names would be asking who won between nobody and
        /// nobody.
        var isReady: Bool

        /// `6–2`, or nil until somebody has entered one. An en dash, as the design writes it.
        var scoreLabel: String? {
            score.map { "\($0.a)–\($0.b)" }
        }
    }

    /// A team-tennis roster.
    struct TeamRoster: Identifiable, Hashable, Sendable {
        /// The draft position — `Tournament.Team.id`, which is an `Int` and not a uuid.
        var id: Int
        var name: String
        /// "5 kids".
        var count: String
        /// "Serene C · Liam P · Austin Z", or a line saying there is nobody in it yet.
        var roster: String
        var coachIDs: [StaffMember.ID]
    }

    /// One column of a knockout bracket.
    struct BracketColumn: Identifiable, Hashable, Sendable {
        var round: Int
        /// "Round of 16", "Quarters", "Semis", "Final" — `Tournament.roundName(_:)`.
        var name: String
        var boxes: [BracketBox]

        var id: Int { round }
    }

    /// One fixture inside a bracket column.
    struct BracketBox: Identifiable, Hashable, Sendable {
        var id: Tournament.Match.ID
        var a: BracketSide
        var b: BracketSide
        /// Somebody on both sides, so there is a score to enter.
        var isPlayable: Bool
    }

    /// Half of a bracket box.
    struct BracketSide: Hashable, Sendable {
        /// A name, "Winner of M7", or "bye".
        var name: String
        /// Whether an entrant is actually standing here yet.
        var isResolved: Bool
        /// Whether they came out of it. A bye wins without a score.
        var isWinner: Bool
        var score: String?
    }

    /// A row of the round-robin table.
    struct StandingRow: Identifiable, Hashable, Sendable {
        var id: Tournament.Entrant.ID
        /// 1-based place.
        var position: Int
        var label: String
        /// `4–1`.
        var record: String
        /// Top of a table where everything has been played.
        var isChampion: Bool
    }

    // MARK: Stored

    var id: Tournament.ID
    var title: String
    var kind: Tournament.Kind
    /// Nil exactly for team tennis, which has no fixtures to lay out — the model's own invariant
    /// (`Tournament.mode`). Carried optional rather than defaulted here so the two states this
    /// screen actually draws, a bracket and a table, cannot be reached by a team draw.
    var mode: Tournament.Mode?
    /// "Singles", "Round robin", "2 days", "Group 1+2" — the row of grey tags under the title.
    var tags: [String]

    var teams: [TeamRoster]
    var days: [Day]
    /// Every playable match, in the order they are to be played, numbered.
    var order: [OrderedMatch]
    /// "12 of 21 played".
    var playedLine: String
    /// Empty unless this is a knockout.
    var bracket: [BracketColumn]
    /// Empty unless this is a round robin.
    var standings: [StandingRow]
    /// "Standings" until everything is played, then "Final standings".
    var standingsTitle: String

    /// Kids the doubles pairing left without a partner, by name.
    ///
    /// **The thing the design drops on the floor.** `state1.js:915` pairs the unrequested kids two
    /// at a time and walks off the end of an odd list, so a camp of nineteen is shown nine pairs
    /// and no nineteenth child — no entrant, no match, no mention. `Tournament.unpairedEntrants` is the
    /// model's fix and this is the screen's: the card says their name out loud and asks the person
    /// running the camp to decide, because whether they sit out, play with a coach or make somebody
    /// a three is not a decision arithmetic gets to make silently.
    var soloNames: [String]

    // MARK: Reads

    var isTeam: Bool { kind == .team }
    /// `mode` is nil exactly for team tennis, so neither of these needs a second guard against it.
    var isKnockout: Bool { mode == .knockout }
    var isRoundRobin: Bool { mode == .roundRobin }

    /// The matches on one day of the draw.
    func matches(onDay index: Int) -> [OrderedMatch] {
        order.filter { $0.dayIndex == index }
    }

    /// The first match of the day nobody has scored — the one the card rings.
    ///
    /// Nil on a day that is finished, which is the state worth having: a ring around nothing would
    /// be a card claiming there is something left to do.
    func upNext(onDay index: Int) -> OrderedMatch? {
        matches(onDay: index).first { $0.score == nil && $0.isReady }
    }
}

// MARK: - Building one

extension TournamentPlan {

    /// Resolves `tournament` against the camp it was drawn from.
    ///
    /// `today` is passed rather than read, for `AppClock`'s reason: a screen that asks the calendar
    /// itself cannot be previewed on a Tuesday and tested on a Thursday.
    init(_ tournament: Tournament, in camp: Camp, today: Weekday) {
        let players = Dictionary(camp.players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let entrants = Dictionary(
            tournament.entrants.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )

        /// "Serene C", or "Serene C + Liam P" for a pair.
        ///
        /// The design's `shortName` (`state1.js:571`) — a first name and a last initial, which is
        /// how camps write kids down so that two Liams stay apart. Deliberately not
        /// `Player.displayName`, which resolves to the whole surname once a camp has collected one:
        /// two full names joined with " + " and then two of *those* joined with " vs " is a line
        /// that wraps twice in a 12.5pt row.
        func short(_ id: Player.ID) -> String {
            guard let player = players[id] else { return "?" }
            return player.lastInitial.isEmpty
                ? player.firstName
                : "\(player.firstName) \(player.lastInitial)"
        }

        func label(_ entrantID: Tournament.Entrant.ID?) -> String {
            guard let entrantID, let entrant = entrants[entrantID] else { return "?" }
            return entrant.playerIDs.map(short).joined(separator: " + ")
        }

        // MARK: The days

        // Which day of the camp week each day of the draw falls on.
        //
        // The design has no calendar — `dayLabelT` (`state1.js:713`) writes "Today" and "Day 2" —
        // and this app does: `CampDays` knows which days the camp opens and `Attendance` is keyed
        // by `Weekday`. So a draw's days are the camp's next `n` opening days, and the pills say
        // "Today", "Thu", "Fri" rather than "Day 1", "Day 2", "Day 3". A coach reading "away Thu"
        // can act on it; "away Day 3" is arithmetic they have to do themselves.
        let campDays = camp.days.isValid ? camp.days : .weekdays
        let running = TournamentPlan.runningDays(tournament.days, in: campDays, from: today)
        let days = running.enumerated().map { offset, weekday in
            Day(
                index: offset + 1,
                weekday: weekday,
                label: weekday == today ? "Today" : weekday.shortName
            )
        }

        // Attendance, indexed once.
        //
        // `Camp.isAway(_:on:)` and `leavesAt(_:on:)` each scan the whole sparse attendance array,
        // and the walk below asks them per player, per side, per candidate day — which on a
        // twelve-kid round robin over five days is a few thousand scans of an array the length of
        // the camp, inside a derivation that runs whenever a day pill is tapped. Two dictionaries
        // built once turn all of it into hashing.
        var awayOn: [Weekday: Set<Player.ID>] = [:]
        var leavesOn: [Weekday: [Player.ID: Int]] = [:]
        for record in camp.attendance {
            if !record.present { awayOn[record.day, default: []].insert(record.playerID) }
            if let leavesAt = record.leavesAt { leavesOn[record.day, default: [:]][record.playerID] = leavesAt.id }
        }

        /// Anybody in this entrant who is not at camp on that day of the draw.
        func awayNames(_ entrantID: Tournament.Entrant.ID?, onDay index: Int) -> [String] {
            guard let entrantID, let entrant = entrants[entrantID],
                  let day = days.first(where: { $0.index == index }),
                  let away = awayOn[day.weekday]
            else { return [] }
            return entrant.playerIDs.filter(away.contains).map(short)
        }

        /// The earliest anybody in this match goes home on that day, in minutes, or nil.
        ///
        /// **Generalised past the design, which only looks at day one** (`state1.js:825` filters
        /// `x.day === 'Today'`). The prototype's leave times only ever exist for "Today" because
        /// its data has nowhere else to put them; `Attendance` here is keyed by `Weekday` and holds
        /// a `leavesAt` for any of them. Restricting the sort to day one would mean a Thursday
        /// match involving a kid who leaves at two o'clock got no priority over one that could run
        /// at four — which is exactly the promise the empty state makes ("front-loads early
        /// leavers") failing on every day but the first.
        func earliestLeave(_ entrantIDs: [Tournament.Entrant.ID?], onDay index: Int) -> Int? {
            guard let day = days.first(where: { $0.index == index }),
                  let leaving = leavesOn[day.weekday]
            else { return nil }
            return entrantIDs
                .compactMap { $0 }
                .compactMap { entrants[$0] }
                .flatMap(\.playerIDs)
                .compactMap { leaving[$0] }
                .min()
        }

        // MARK: Placing the matches

        // One entry per playable fixture, carrying where it should be played and why.
        //
        // Transcribed from `state1.js:804-827`, with the one change named at `earliestLeave`. The
        // rule: take the round's base day; if anybody in the match is away that day, look for a
        // day where nobody is. A round robin may look from day one, because its rounds are a
        // circle and any of them can be played first. A knockout may only look *forward* from the
        // base day, because a semi-final cannot be played before its quarters.
        struct Placement {
            var match: Tournament.Match
            var day: Int
            var flag: String?
            var leave: Int
            var a: Tournament.Entrant.ID?
            var b: Tournament.Entrant.ID?
        }

        let placements: [Placement] = tournament.playableMatches.map { match in
            let base = tournament.day(ofRound: match.round)
            let a = tournament.entrantID(of: match.a)
            let b = tournament.entrantID(of: match.b)

            func awayAt(_ index: Int) -> [String] {
                awayNames(a, onDay: index) + awayNames(b, onDay: index)
            }

            var day = base
            var flag: String?
            let blocked = awayAt(base)

            if !blocked.isEmpty {
                let first = tournament.mode == .roundRobin ? 1 : base
                let clear = (first...max(first, days.count)).first { awayAt($0).isEmpty }
                if let clear, clear != base {
                    day = clear
                    let baseLabel = days.first { $0.index == base }?.label ?? "day \(base)"
                    flag = "Moved — \(blocked.joined(separator: ", ")) away \(baseLabel)"
                } else if clear == nil {
                    // Nowhere to put it. Said out loud rather than moved somewhere it will not be
                    // played either — the design's own wording, and the honest one.
                    flag = "\(blocked.joined(separator: ", ")) away — walkover risk"
                }
            }

            return Placement(
                match: match,
                day: day,
                flag: flag,
                leave: earliestLeave([a, b], onDay: day) ?? Int.max,
                a: a,
                b: b
            )
        }

        // Day first, then whoever goes home earliest, then the draw's own order. The last two
        // terms are the tie-break the design spells out (`:827`) and they matter: Swift's sort is
        // not stable, and a card that renumbered its own matches between two reads of the same
        // data would look like the draw had been reseeded.
        let sorted = placements.sorted { left, right in
            if left.day != right.day { return left.day < right.day }
            if left.leave != right.leave { return left.leave < right.leave }
            if left.match.round != right.match.round { return left.match.round < right.match.round }
            return left.match.id < right.match.id
        }

        var numbers: [Tournament.Match.ID: String] = [:]
        for (offset, placement) in sorted.enumerated() {
            numbers[placement.match.id] = "M\(offset + 1)"
        }

        /// A side of a fixture as the order of play writes it: a name, or what it is waiting on.
        func sideName(_ entrantID: Tournament.Entrant.ID?, from side: Tournament.Side?) -> String {
            if entrantID != nil { return label(entrantID) }
            if case .winner(let matchID) = side {
                return "Winner of \(numbers[matchID] ?? "an earlier match")"
            }
            return "—"
        }

        let order = sorted.map { placement -> OrderedMatch in
            let aName = sideName(placement.a, from: placement.match.a)
            let bName = sideName(placement.b, from: placement.match.b)
            return OrderedMatch(
                id: placement.match.id,
                number: numbers[placement.match.id] ?? "",
                dayIndex: placement.day,
                aName: aName,
                bName: bName,
                label: "\(aName) vs \(bName)",
                score: tournament.scores[placement.match.id],
                flag: placement.flag,
                isReady: placement.a != nil && placement.b != nil
            )
        }

        // MARK: The bracket

        var bracket: [BracketColumn] = []
        if tournament.mode == .knockout {
            bracket = tournament.rounds.map { round in
                let boxes = tournament.matches.filter { $0.round == round }.map { match -> BracketBox in
                    let a = tournament.entrantID(of: match.a)
                    let b = tournament.entrantID(of: match.b)
                    let score = tournament.scores[match.id]

                    /// A side of a bracket box. "bye" where the draw padded up to a power of two —
                    /// which is a real state and not an error: `knockoutMatches` gives the top
                    /// seeds their first round off, and the box has to say so.
                    func side(
                        _ entrantID: Tournament.Entrant.ID?,
                        from reference: Tournament.Side?,
                        mine: Int?,
                        theirs: Int?,
                        walksOver: Bool
                    ) -> BracketSide {
                        let name: String = if entrantID != nil {
                            label(entrantID)
                        } else if case .winner(let matchID) = reference {
                            "Winner of \(numbers[matchID] ?? "an earlier match")"
                        } else {
                            "bye"
                        }
                        let won: Bool = if let mine, let theirs { mine > theirs } else { walksOver }
                        return BracketSide(
                            name: name,
                            isResolved: entrantID != nil,
                            isWinner: won,
                            score: mine.map(String.init)
                        )
                    }

                    return BracketBox(
                        id: match.id,
                        a: side(a, from: match.a, mine: score?.a, theirs: score?.b,
                                walksOver: match.a != nil && match.b == nil),
                        b: side(b, from: match.b, mine: score?.b, theirs: score?.a,
                                walksOver: match.a == nil && match.b != nil),
                        isPlayable: a != nil && b != nil
                    )
                }
                return BracketColumn(round: round, name: tournament.roundName(round), boxes: boxes)
            }
        }

        // MARK: The table

        let playable = tournament.playableMatches
        let played = tournament.playedCount
        let allPlayed = !playable.isEmpty && played == playable.count

        var standings: [StandingRow] = []
        if tournament.mode == .roundRobin {
            standings = tournament.standings.enumerated().map { offset, standing in
                StandingRow(
                    id: standing.entrantID,
                    position: offset + 1,
                    label: label(standing.entrantID),
                    record: "\(standing.won)–\(standing.lost)",
                    isChampion: offset == 0 && allPlayed
                )
            }
        }

        // MARK: The teams

        let teams = tournament.teams.map { team in
            let names = team.playerIDs.filter { players[$0] != nil }.map(short)
            return TeamRoster(
                id: team.id,
                name: team.name,
                count: "\(names.count) kid\(names.count == 1 ? "" : "s")",
                // Not an empty string when a team drew nobody — a blank line under a heading reads
                // as a rendering fault. A team can genuinely be empty: `Tournament.teams(pool:count:)`
                // deals as far as the ladder goes and stops.
                roster: names.isEmpty ? "Nobody dealt in yet" : names.joined(separator: " · "),
                coachIDs: team.coachIDs
            )
        }

        // MARK: The tags

        // `[format, shape, days, courts]` — `state1.js:766`.
        let courtLabel = tournament.courtIndices.map { "\($0 + 1)" }.joined(separator: "+")
        var tags = [TournamentPlan.kindLabel(tournament.kind)]
        // What shape the play takes — which for team tennis is not a shape at all but a count,
        // because `mode` is nil there and there are no fixtures for it to describe.
        switch tournament.mode {
        case .roundRobin: tags.append("Round robin")
        case .knockout: tags.append("Draw")
        case nil: tags.append("\(tournament.teams.count) team\(tournament.teams.count == 1 ? "" : "s")")
        }
        tags.append("\(tournament.days) day\(tournament.days == 1 ? "" : "s")")
        if !courtLabel.isEmpty {
            tags.append(tournament.courtIndices.count == 1 ? "Group \(courtLabel)" : "Groups \(courtLabel)")
        }

        // MARK: Assemble

        self.id = tournament.id
        self.title = tournament.name
        self.kind = tournament.kind
        self.mode = tournament.mode
        self.tags = tags
        self.teams = teams
        self.days = days
        self.order = order
        self.playedLine = "\(played) of \(playable.count) played"
        self.bracket = bracket
        self.standings = standings
        self.standingsTitle = allPlayed ? "Final standings" : "Standings"
        self.soloNames = tournament.unpairedEntrants.flatMap { $0.playerIDs }.map(short)
    }

    /// The next `count` days the camp opens, starting from `today` if it opens today.
    ///
    /// Wraps into next week the way `CampDays.openingDay(from:)` does, so a three-day draw struck
    /// on a Friday at a Monday-to-Friday camp runs Friday, Monday, Tuesday rather than running out
    /// of week. A camp with no valid days cannot reach this — the caller substitutes `.weekdays` —
    /// but the guard is here anyway, because the alternative to it is a loop that never ends.
    static func runningDays(_ count: Int, in campDays: CampDays, from today: Weekday) -> [Weekday] {
        let ordered = campDays.ordered
        guard !ordered.isEmpty, count > 0 else { return [] }

        let start = campDays.openingDay(from: today) ?? ordered[0]
        let first = ordered.firstIndex(of: start) ?? 0
        return (0..<count).map { ordered[(first + $0) % ordered.count] }
    }

    /// The design's chips: "Singles", "Doubles", "Team tennis".
    static func kindLabel(_ kind: Tournament.Kind) -> String {
        switch kind {
        case .singles: "Singles"
        case .doubles: "Doubles"
        case .team: "Team tennis"
        }
    }

    /// The one line a team draw has instead of fixtures.
    ///
    /// `state1.js:788` — team tennis seeds rosters and stops, so the card says why rather than
    /// drawing an empty order of play under a heading.
    static let teamNote = "Team matchups come later — rosters and coaches for now."
}
