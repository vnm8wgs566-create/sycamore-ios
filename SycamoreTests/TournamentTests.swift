//
//  TournamentTests.swift
//  SycamoreTests
//
//  A draw is struck once, printed, and played all Friday. Nothing on the card shows the arithmetic
//  and no seeding can raise an error — a bracket that pairs the wrong two kids just looks like a
//  draw somebody made badly, and a doubles draw that quietly leaves a kid out looks exactly like a
//  doubles draw.
//
//  Three properties carry most of this file, and all three are the kind that break silently:
//
//    - **Everybody who went in comes out.** `everyoneIsInTheDraw` counts the pool back out of the
//      entrants for pools of every parity. This is the invariant the prototype breaks
//      (`state1.js:915` steps past the last of an odd list), and it is checked as a count rather
//      than as "the odd case works", because the defect is one loop condition and one loop
//      condition can go wrong for even pools too.
//    - **The same pool always draws the same way.** Entrant and match ids are derived, not minted,
//      and `Tournament` is `Hashable` on that basis. `seedingIsDeterministic` pins it — a sort that
//      was stable only by accident would pass every other test here and reorder the moment the
//      standard library's sort changed.
//    - **Nobody plays twice at once.** A round of a round robin has to be playable in an hour, so
//      an entrant may appear at most once in it. `roundRobinPlaysEachRoundOnce` checks every round
//      rather than the totals, because the right number of matches distributed wrongly is the
//      failure that a match count cannot see.
//
//  Where a test asserts a whole roster it does so by ladder position — `[0, 3]` reads as "the top
//  seed with the fourth" — since a failure printing two uuids says only that something moved.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()

/// `count` kids, ranked 1…count, in ladder order. Index in this array is the kid's seed.
private func kids(_ count: Int) -> [Player] {
    (0..<count).map { offset in
        Player(
            firstName: "K\(offset + 1)",
            lastInitial: "T",
            age: 12,
            gender: .x,
            isReturning: true,
            venueID: venueID,
            groupID: nil,
            overallRank: offset + 1,
            courtRank: offset + 1
        )
    }
}

/// Ladder positions, so an expectation reads `[0, 3]` rather than two uuids.
private func seats(_ ids: [Player.ID], in pool: [Player]) -> [Int] {
    ids.compactMap { id in pool.firstIndex { $0.id == id } }
}

private func seats(_ entrant: Tournament.Entrant, in pool: [Player]) -> [Int] {
    seats(entrant.playerIDs, in: pool)
}

private func seats(_ entrants: [Tournament.Entrant], in pool: [Player]) -> [[Int]] {
    entrants.map { seats($0, in: pool) }
}

/// The entrants on each side of a match, resolved through the bracket, as ladder positions.
private func fixture(
    _ match: Tournament.Match, in tournament: Tournament, pool: [Player]
) -> [[Int]?] {
    [match.a, match.b].map { side in
        guard let entrantID = tournament.entrantID(of: side),
              let entrant = tournament.entrant(entrantID)
        else { return nil }
        return seats(entrant, in: pool)
    }
}

@Suite("Tournament")
struct TournamentTests {

    // MARK: - Bands

    @Test("Splits a ladder into bands within one of each other, remainder to the stronger")
    func bandSizesPutTheRemainderAtTheTop() {
        #expect(Tournament.bandSizes(20, into: 3) == [7, 7, 6])
        #expect(Tournament.bandSizes(10, into: 4) == [3, 3, 2, 2])
        #expect(Tournament.bandSizes(12, into: 4) == [3, 3, 3, 3])
        #expect(Tournament.bandSizes(1, into: 3) == [1, 0, 0])
        #expect(Tournament.bandSizes(0, into: 3) == [0, 0, 0])
    }

    @Test("Agrees with the deal the app already does across courts")
    func bandSizesMatchCampDeal() {
        // `Camp.deal(_:across:)` is the same arithmetic over courts instead of tournaments; the
        // two are written out separately and must not drift. 37 kids over 6 courts is the shape
        // `CampPartitionTests` exercises.
        var camp = Fixture.camp([.init("Sycamore", courts: 6)], players: 37)
        camp.evenOut()
        let venue = camp.orderedVenues[0]
        let courtSizes = camp.groups(in: venue.id).map { camp.players(inGroup: $0.id).count }

        #expect(courtSizes == Tournament.bandSizes(37, into: 6))
    }

    @Test("A band is a contiguous slice of the ladder, strongest band first")
    func bandsAreContiguousAndRanked() {
        let pool = kids(10)

        let bands = Tournament.bands(pool, into: 3)

        // 10 into 3 is 4/3/3 — the spare kid goes to the band where the standard is highest, not
        // to the one at the bottom of the ladder.
        #expect(bands.map { seats($0.map(\.id), in: pool) } == [[0, 1, 2, 3], [4, 5, 6], [7, 8, 9]])
    }

    @Test("Zero bands is no bands, not a division by zero")
    func zeroBands() {
        #expect(Tournament.bandSizes(10, into: 0).isEmpty)
        #expect(Tournament.bands(kids(10), into: 0).isEmpty)
        #expect(Tournament.bands(kids(10), into: -2).isEmpty)
    }

    @Test("A ladder shorter than the count still returns every band asked for, some empty")
    func bandsKeepTheirCountWhenTheLadderIsShort() {
        let bands = Tournament.bands(kids(3), into: 5)

        #expect(bands.map(\.count) == [1, 1, 1, 0, 0])
    }

    @Test("Banding into more tournaments than there are kids makes only the ones with kids in them")
    func bandedDropsTheEmptyTournaments() {
        let pool = kids(3)

        let tournaments = Tournament.banded(
            .singles(.roundRobin), ladder: pool, into: 5, courtIndices: [0]
        )

        // Three kids cannot fill five tournaments and a tournament of nobody is not a thing a camp
        // can run. What comes back is the honest count, not five cards with two of them blank.
        #expect(tournaments.count == 3)
        #expect(tournaments.map(\.name) == ["Tournament 1", "Tournament 2", "Tournament 3"])
        #expect(tournaments.flatMap { seats($0.entrants, in: pool) } == [[0], [1], [2]])
    }

    @Test("Banded tournaments partition the ladder — everybody in exactly one")
    func bandedPartitionsTheLadder() {
        let pool = kids(23)

        let tournaments = Tournament.banded(
            .singles(.knockout), ladder: pool, into: 4, courtIndices: [0, 1], days: 2
        )

        let drawn = tournaments.flatMap { $0.entrants.flatMap(\.playerIDs) }
        #expect(tournaments.map(\.entrants.count) == [6, 6, 6, 5])
        #expect(drawn.count == pool.count)
        #expect(Set(drawn) == Set(pool.map(\.id)))
        // Every tournament carries the shape it was asked for, not just the kids.
        #expect(tournaments.allSatisfy { $0.mode == .knockout && $0.days == 2 && $0.courtIndices == [0, 1] })
    }

    // MARK: - The pool

    @Test("The pool is the venue ladder narrowed to the chosen courts, best first")
    func poolFollowsCourtOrderThenCourtRank() {
        let courts = (0..<3).map { number in
            Group(venueID: venueID, number: number + 1, label: "Court \(number + 1)",
                  rankOrder: number, capacity: 8)
        }
        // Three kids per court, handed over shuffled so a pool that trusted array order would fail.
        var roll = kids(9)
        for (offset, index) in (0..<9).enumerated() {
            roll[index].groupID = courts[offset / 3].id
            roll[index].courtRank = offset % 3 + 1
        }
        let shuffled = [roll[8], roll[0], roll[5], roll[3], roll[1], roll[7], roll[2], roll[6], roll[4]]

        let whole = Tournament.ladder(shuffled, across: courts)
        let narrowed = Tournament.pool(shuffled, across: courts, courtIndices: [0, 2])

        #expect(whole.map(\.firstName) == roll.map(\.firstName))
        #expect(narrowed.map(\.firstName) == ["K1", "K2", "K3", "K7", "K8", "K9"])
    }

    @Test("Court positions and court ids convert both ways")
    func courtIndicesAndIDsRoundTrip() {
        let courts = (0..<4).map { number in
            Group(venueID: venueID, number: number + 1, label: "Court \(number + 1)",
                  rankOrder: number, capacity: 8)
        }

        #expect(Tournament.courtIDs(of: [0, 2], in: courts) == [courts[0].id, courts[2].id])
        #expect(Tournament.courtIndices(of: [courts[2].id, courts[0].id], in: courts) == [0, 2])

        // A court that has since been deleted, and a position past the end of the venue, are both
        // courts that are not there. Neither traps and neither invents one.
        #expect(Tournament.courtIDs(of: [1, 9], in: courts) == [courts[1].id])
        #expect(Tournament.courtIndices(of: [Group.ID()], in: courts).isEmpty)
    }

    @Test("A kid on no court is on no ladder")
    func poolSkipsPlayersWithoutACourt() {
        let court = Group(venueID: venueID, number: 1, label: "Court 1", rankOrder: 0, capacity: 8)
        var roll = kids(3)
        roll[0].groupID = court.id
        roll[2].groupID = court.id

        // A kid mid-import has no court, and inventing a rung for them in a draw is exactly the
        // guess the ladder screen exists to avoid.
        #expect(Tournament.ladder(roll, across: [court]).map(\.firstName) == ["K1", "K3"])
        #expect(Tournament.pool(roll, across: [court], courtIndices: [7]).isEmpty)
    }

    // MARK: - Singles

    @Test("Singles enters every kid once, in ladder order")
    func singlesIsTheLadder() {
        let pool = kids(6)

        let tournament = Tournament.seeded(
            .singles(.roundRobin), name: "Tournament 1", pool: pool, courtIndices: [0]
        )

        #expect(seats(tournament.entrants, in: pool) == [[0], [1], [2], [3], [4], [5]])
        #expect(tournament.entrants.map(\.ladderIndex) == [0, 1, 2, 3, 4, 5])
        #expect(tournament.unpairedEntrants.isEmpty)
    }

    // MARK: - Doubles

    @Test("Doubles pairs adjacently down the ladder")
    func doublesPairsAdjacently() {
        let pool = kids(8)

        let entrants = Tournament.doublesEntrants(pool: pool)

        // 1 with 2, 3 with 4 — not 1 with 8. Balancing every pair would flatten the seeding out
        // of the draw entirely; see `doublesEntrants`.
        #expect(seats(entrants, in: pool) == [[0, 1], [2, 3], [4, 5], [6, 7]])
        #expect(entrants.map(\.ladderIndex) == [0.5, 2.5, 4.5, 6.5])
        #expect(entrants.allSatisfy { !$0.isRequested })
    }

    @Test("A requested pair is honoured and seeded at its members' mean")
    func doublesHonoursRequestedPairs() {
        let pool = kids(8)
        let request = Tournament.PairRequest(pool[0].id, pool[3].id)

        let entrants = Tournament.doublesEntrants(pool: pool, requestedPairs: [request])

        #expect(seats(entrants, in: pool) == [[0, 3], [1, 2], [4, 5], [6, 7]])
        #expect(entrants.map(\.isRequested) == [true, false, false, false])
        // The 1st with the 4th seeds at 1.5 — the same as the 2nd with the 3rd, which is the tie
        // the sort has to break the same way every time. Requested first, then down the ladder.
        #expect(entrants.map(\.ladderIndex) == [1.5, 1.5, 4.5, 6.5])
    }

    @Test("A requested pair sits where its strength puts it, not where it was asked")
    func requestedPairsAreSortedByStrength() {
        let pool = kids(8)
        let request = Tournament.PairRequest(pool[6].id, pool[7].id)

        let entrants = Tournament.doublesEntrants(pool: pool, requestedPairs: [request])

        // Asked for first, drawn last: the bottom two of the ladder are the bottom seed whoever
        // put them together.
        #expect(seats(entrants, in: pool) == [[0, 1], [2, 3], [4, 5], [6, 7]])
        #expect(entrants.map(\.isRequested) == [false, false, false, true])
    }

    @Test("A requested pair with one member outside the pool is not honoured, and neither kid is lost")
    func requestedPairAcrossThePoolBoundary() {
        let pool = kids(6)
        let outsider = kids(1)[0]
        let request = Tournament.PairRequest(pool[1].id, outsider.id)

        let entrants = Tournament.doublesEntrants(pool: pool, requestedPairs: [request])

        // The in-pool half of a broken request is just a kid who needs a partner, and gets one.
        // The superseded version of this loop left them out of `rest` as well and dropped them.
        #expect(seats(entrants, in: pool) == [[0, 1], [2, 3], [4, 5]])
        #expect(entrants.allSatisfy { !$0.isRequested })
        #expect(!entrants.flatMap(\.playerIDs).contains(outsider.id))
    }

    @Test("An odd pool leaves one kid on their own, and says so")
    func doublesOddPoolKeepsTheLastKid() {
        let pool = kids(7)

        let tournament = Tournament.seeded(
            .doubles(.roundRobin), name: "Tournament 1", pool: pool, courtIndices: [0]
        )

        // The whole reason this file exists. The prototype's `i + 1 < rest.length` walks past K7
        // and nothing anywhere mentions them again.
        #expect(seats(tournament.entrants, in: pool) == [[0, 1], [2, 3], [4, 5], [6]])
        #expect(seats(tournament.unpairedEntrants, in: pool) == [[6]])
        #expect(tournament.entrants.last?.ladderIndex == 6)
    }

    @Test("An odd pool with a requested pair still leaves exactly one kid on their own")
    func doublesOddPoolWithARequest() {
        let pool = kids(9)
        let request = Tournament.PairRequest(pool[0].id, pool[8].id)

        let entrants = Tournament.doublesEntrants(pool: pool, requestedPairs: [request])

        #expect(seats(entrants, in: pool) == [[1, 2], [3, 4], [0, 8], [5, 6], [7]])
        #expect(entrants.filter(\.isSolo).count == 1)
    }

    @Test("Everybody in the pool is in the draw, whatever the parity")
    func everyoneIsInTheDraw() {
        for size in 0...13 {
            let pool = kids(size)
            let entrants = Tournament.doublesEntrants(pool: pool)
            let drawn = entrants.flatMap(\.playerIDs)

            #expect(drawn.count == size, "doubles pool of \(size)")
            #expect(Set(drawn) == Set(pool.map(\.id)), "doubles pool of \(size)")
            #expect(entrants.filter(\.isSolo).count == size % 2, "doubles pool of \(size)")
        }
    }

    @Test("The same pool always draws the same way")
    func seedingIsDeterministic() {
        let pool = kids(11)
        let requests = [
            Tournament.PairRequest(pool[0].id, pool[5].id),
            Tournament.PairRequest(pool[2].id, pool[3].id),
        ]

        let first = Tournament.seeded(
            .doubles(.knockout, requestedPairs: requests), name: "T", pool: pool, courtIndices: [0]
        )
        let second = Tournament.seeded(
            .doubles(.knockout, requestedPairs: requests), name: "T", pool: pool, courtIndices: [0]
        )

        // Ids are derived, not minted, so these compare as values. Only `id` differs.
        #expect(first.entrants == second.entrants)
        #expect(first.matches == second.matches)
    }

    // MARK: - Team

    @Test("The snake draft turns back on itself")
    func teamDraftSnakes() {
        let pool = kids(10)

        let teams = Tournament.teams(pool: pool, count: 3)

        #expect(teams.map { seats($0.playerIDs, in: pool) } == [[0, 5, 6], [1, 4, 7], [2, 3, 8, 9]])
        #expect(teams.map(\.name) == ["Team 1", "Team 2", "Team 3"])
        #expect(teams.map(\.id) == [0, 1, 2])
    }

    @Test("Teams come out the same size, within one")
    func teamSizesAreEven() {
        for (size, count) in [(10, 3), (24, 4), (7, 5), (5, 8), (100, 6)] {
            let teams = Tournament.teams(pool: kids(size), count: count)
            let sizes = teams.map(\.playerIDs.count)

            #expect(teams.count == count, "\(size) into \(count)")
            #expect(sizes.reduce(0, +) == size, "\(size) into \(count)")
            #expect((sizes.max() ?? 0) - (sizes.min() ?? 0) <= 1, "\(size) into \(count)")
        }
    }

    @Test("Over an even number of complete rounds the teams are exactly level")
    func teamStrengthIsExactlyLevelOnPairedRounds() {
        // Rounds pair off: round r gives a team `r·c + pos` and round r+1 gives it
        // `(r+1)·c + (c-1-pos)`, which is the same total for every position. Over an even number
        // of complete rounds the ladder-position sums are therefore identical, and that is the
        // whole reason to snake rather than deal straight round and round.
        let pool = kids(24)

        let teams = Tournament.teams(pool: pool, count: 4)
        let strength = teams.map { seats($0.playerIDs, in: pool).reduce(0, +) }

        #expect(Set(strength).count == 1)
    }

    @Test("Over complete rounds the teams are within one round of each other")
    func teamStrengthIsWithinARound() {
        for (size, count) in [(15, 5), (18, 3), (28, 4), (30, 6)] {
            let pool = kids(size)
            let teams = Tournament.teams(pool: pool, count: count)
            let strength = teams.map { seats($0.playerIDs, in: pool).reduce(0, +) }
            let spread = (strength.max() ?? 0) - (strength.min() ?? 0)

            // An odd number of complete rounds leaves one round unpaired, and one round is worth
            // `count - 1` positions of spread. A straight round-and-round deal would be worth
            // `rounds · (count - 1)`, which is what this bound is here to rule out.
            #expect(spread <= count - 1, "\(size) into \(count) spread \(spread)")
        }
    }

    @Test("A team draw seeds rosters and no fixtures")
    func teamDrawHasNoMatches() {
        let pool = kids(12)

        let tournament = Tournament.seeded(
            .team(count: 3), name: "Tournament 1", pool: pool, courtIndices: [0, 1], days: 2
        )

        #expect(tournament.kind == .team)
        #expect(tournament.teams.count == 3)
        #expect(tournament.entrants.isEmpty)
        // "Team matchups come later — rosters and coaches for now."
        #expect(tournament.matches.isEmpty)
        // And no mode either. A team draw that claimed to be a round robin is a claim somebody
        // downstream would act on; `tournaments_team_has_no_mode` says the same at the column.
        #expect(tournament.mode == nil)
    }

    @Test("A team draw of no teams drafts nobody rather than dividing by zero")
    func teamDrawOfZero() {
        #expect(Tournament.teams(pool: kids(8), count: 0).isEmpty)
        #expect(Tournament.teams(pool: kids(8), count: -1).isEmpty)
    }

    // MARK: - Round robin

    @Test("Everybody plays everybody once")
    func roundRobinPlaysEveryPairOnce() {
        for size in 2...9 {
            let entrants = Tournament.singlesEntrants(pool: kids(size))
            let matches = Tournament.roundRobinMatches(entrants)

            let pairings = Set(matches.map { match -> Set<String> in
                Set([match.a, match.b].compactMap { side -> String? in
                    if case .entrant(let id) = side { return id }
                    return nil
                })
            })
            #expect(matches.count == size * (size - 1) / 2, "pool of \(size)")
            #expect(pairings.count == matches.count, "pool of \(size)")
            #expect(matches.allSatisfy { $0.a != nil && $0.b != nil }, "pool of \(size)")
        }
    }

    @Test("Nobody is on two courts at once")
    func roundRobinPlaysEachRoundOnce() {
        for size in 2...9 {
            let entrants = Tournament.singlesEntrants(pool: kids(size))
            let matches = Tournament.roundRobinMatches(entrants)
            let rounds = Set(matches.map(\.round)).sorted()

            // An odd count pads with a nil seat, so exactly one entrant sits out each round —
            // and it is a different one each round, because the nil rotates like anybody else.
            let expectedPerRound = size / 2
            #expect(rounds == Array(1...(size % 2 == 0 ? size - 1 : size)), "pool of \(size)")

            for round in rounds {
                let playing = matches.filter { $0.round == round }
                    .flatMap { [$0.a, $0.b] }
                    .compactMap { side -> String? in
                        if case .entrant(let id) = side { return id }
                        return nil
                    }
                #expect(playing.count == expectedPerRound * 2, "pool of \(size), round \(round)")
                #expect(Set(playing).count == playing.count, "pool of \(size), round \(round)")
            }
        }
    }

    @Test("A round robin references entrants directly — there is nothing to wait for")
    func roundRobinHasNoForwardReferences() {
        let matches = Tournament.roundRobinMatches(Tournament.singlesEntrants(pool: kids(6)))

        #expect(matches.allSatisfy { match in
            [match.a, match.b].allSatisfy { side in
                if case .entrant = side { return true }
                return false
            }
        })
        #expect(matches.map(\.id).prefix(3) == ["m1", "m2", "m3"])
    }

    // MARK: - Knockout

    @Test("The bracket pads to the next power of two and pairs 1 against N")
    func knockoutSeedsTopAgainstBottom() {
        let pool = kids(8)
        let tournament = Tournament.seeded(
            .singles(.knockout), name: "Tournament 1", pool: pool, courtIndices: [0]
        )

        let firstRound = tournament.matches.filter { $0.round == 1 }
        #expect(firstRound.map { fixture($0, in: tournament, pool: pool) }
            == [[[0], [7]], [[1], [6]], [[2], [5]], [[3], [4]]])
        // 4 + 2 + 1.
        #expect(tournament.matches.count == 7)
        #expect(tournament.rounds == [1, 2, 3])
    }

    @Test("A bracket that is not a power of two gives the top seeds the byes")
    func knockoutByesGoToTheTopSeeds() {
        let pool = kids(5)
        let tournament = Tournament.seeded(
            .singles(.knockout), name: "Tournament 1", pool: pool, courtIndices: [0]
        )

        let firstRound = tournament.matches.filter { $0.round == 1 }
        #expect(firstRound.count == 4)
        #expect(firstRound.map { fixture($0, in: tournament, pool: pool) }
            == [[[0], nil], [[1], nil], [[2], nil], [[3], [4]]])
        // A bye is not a fixture: only one first-round match can be scored.
        #expect(tournament.playableMatches.filter { $0.round == 1 }.count == 1)
        #expect(tournament.matches.count == 7)
    }

    @Test("Later rounds name the matches that feed them")
    func knockoutCarriesForwardReferences() throws {
        let tournament = Tournament.seeded(
            .singles(.knockout), name: "T", pool: kids(4), courtIndices: [0]
        )

        let final = try #require(tournament.matches.last)
        #expect(final.a == .winner(of: "m1"))
        #expect(final.b == .winner(of: "m2"))
        #expect(tournament.entrantID(of: final.a) == nil)
    }

    @Test("A bye carries its entrant through unplayed")
    func knockoutByeAdvancesWithoutAScore() throws {
        let pool = kids(3)
        var tournament = Tournament.seeded(
            .singles(.knockout), name: "T", pool: pool, courtIndices: [0]
        )
        let top = try #require(tournament.entrants.first)

        // Nothing has been scored, and the top seed is already in the final.
        #expect(tournament.winner(of: "m1") == top.id)
        #expect(tournament.winner(of: "m2") == nil)

        tournament.scores["m2"] = Tournament.Score(6, 2)
        let final = try #require(tournament.matches.last)
        #expect(fixture(final, in: tournament, pool: pool) == [[0], [1]])
    }

    @Test("Rounds are named from the end of the bracket")
    func roundNamesCountBackFromTheFinal() {
        let sixteen = Tournament.seeded(
            .singles(.knockout), name: "T", pool: kids(16), courtIndices: [0]
        )
        let four = Tournament.seeded(
            .singles(.knockout), name: "T", pool: kids(4), courtIndices: [0]
        )

        #expect(sixteen.rounds.map { sixteen.roundName($0) }
            == ["Round of 16", "Quarters", "Semis", "Final"])
        // The last round is the final whether the draw started at 16 or at 4.
        #expect(four.rounds.map { four.roundName($0) } == ["Semis", "Final"])
    }

    // MARK: - Days

    @Test("Rounds fill each day before starting the next")
    func roundsSpreadAcrossTheDays() {
        var tournament = Tournament.seeded(
            .singles(.knockout), name: "T", pool: kids(16), courtIndices: [0], days: 2
        )

        // Four rounds over two days is 2 and 2.
        #expect(tournament.rounds.map { tournament.day(ofRound: $0) } == [1, 1, 2, 2])

        tournament.days = 3
        // Four rounds over three days is 2, 2 and nothing — the ceiling is what makes them fit,
        // and a floor would leave the last round past the last day.
        #expect(tournament.rounds.map { tournament.day(ofRound: $0) } == [1, 1, 2, 2])

        tournament.days = 1
        #expect(tournament.rounds.map { tournament.day(ofRound: $0) } == [1, 1, 1, 1])
    }

    @Test("A draw of no days is a draw of one day")
    func daysNeverFallBelowOne() {
        let tournament = Tournament.seeded(
            .singles(.roundRobin), name: "T", pool: kids(4), courtIndices: [0], days: 0
        )

        #expect(tournament.days == 1)
        #expect(tournament.rounds.allSatisfy { tournament.day(ofRound: $0) == 1 })
    }

    // MARK: - Standings

    @Test("The table orders by wins, then by losses, then by seed")
    func standingsFollowTheResults() throws {
        let pool = kids(4)
        var tournament = Tournament.seeded(
            .singles(.roundRobin), name: "T", pool: pool, courtIndices: [0]
        )
        let entrants = tournament.entrants

        // Nothing played: every row is 0–0, and the order is seed order rather than whatever the
        // sort happens to produce.
        #expect(tournament.standings.map(\.entrantID) == entrants.map(\.id))

        for match in tournament.matches {
            guard let a = tournament.entrantID(of: match.a),
                  let b = tournament.entrantID(of: match.b),
                  let left = entrants.firstIndex(where: { $0.id == a }),
                  let right = entrants.firstIndex(where: { $0.id == b })
            else { continue }
            // The better seed wins every match, so the table should come out as the ladder.
            tournament.scores[match.id] = left < right
                ? Tournament.Score(6, 2)
                : Tournament.Score(2, 6)
        }

        #expect(tournament.standings.map(\.entrantID) == entrants.map(\.id))
        #expect(tournament.standings.map(\.won) == [3, 2, 1, 0])
        #expect(tournament.standings.map(\.lost) == [0, 1, 2, 3])
        #expect(tournament.playedCount == 6)
    }

    // MARK: - Corners

    @Test("An empty pool draws an empty tournament rather than a broken one")
    func emptyPool() {
        for seeding: Tournament.Seeding in [.singles(.roundRobin), .singles(.knockout),
                                            .doubles(.roundRobin), .doubles(.knockout)] {
            let tournament = Tournament.seeded(
                seeding, name: "T", pool: [], courtIndices: [0]
            )
            #expect(tournament.entrants.isEmpty)
            #expect(tournament.matches.isEmpty)
            #expect(tournament.standings.isEmpty)
            #expect(tournament.playedCount == 0)
        }

        let teamDraw = Tournament.seeded(.team(count: 3), name: "T", pool: [], courtIndices: [0])
        // Three named teams with nobody in them, which is what a camp that drafted before the
        // roster arrived should see.
        #expect(teamDraw.teams.map(\.name) == ["Team 1", "Team 2", "Team 3"])
        #expect(teamDraw.teams.flatMap(\.playerIDs).isEmpty)

        #expect(Tournament.banded(.singles(.roundRobin), ladder: [], into: 3, courtIndices: [0]).isEmpty)
    }

    @Test("One kid is an entrant with nobody to play")
    func singleEntrantPool() {
        let pool = kids(1)

        let roundRobin = Tournament.seeded(
            .singles(.roundRobin), name: "T", pool: pool, courtIndices: [0]
        )
        let knockout = Tournament.seeded(
            .singles(.knockout), name: "T", pool: pool, courtIndices: [0]
        )

        // One entrant, and no fixture invented for them — a card reading "K1 vs —" would be asking
        // somebody to score a match that cannot happen.
        #expect(roundRobin.entrants.count == 1)
        #expect(roundRobin.matches.isEmpty)
        #expect(knockout.entrants.count == 1)
        #expect(knockout.matches.isEmpty)
        #expect(knockout.rounds.isEmpty)

        // Doubles over one kid is the solo entrant, not an empty draw.
        let doubles = Tournament.seeded(
            .doubles(.roundRobin), name: "T", pool: pool, courtIndices: [0]
        )
        #expect(seats(doubles.unpairedEntrants, in: pool) == [[0]])
    }

    @Test("Court indices are stored in the venue's order, numerically")
    func courtIndicesAreSorted() {
        let tournament = Tournament.seeded(
            .singles(.roundRobin), name: "T", pool: kids(4), courtIndices: [10, 2, 0]
        )

        // Numerically, not the prototype's lexicographic `.sort()`, which would give 0, 10, 2 and
        // draw the chip as "Group 1+11+3".
        #expect(tournament.courtIndices == [0, 2, 10])
    }

    @Test("A bracket that names a cycle resolves to nobody instead of hanging")
    func cyclesInADecodedBracketTerminate() {
        var tournament = Tournament.seeded(
            .singles(.knockout), name: "T", pool: kids(4), courtIndices: [0]
        )
        // Not reachable through `seeded` — this is what a hand-edited or corrupted row looks like.
        tournament.matches = [
            .init(id: "m1", round: 1, a: .winner(of: "m2"), b: .winner(of: "m2")),
            .init(id: "m2", round: 1, a: .winner(of: "m1"), b: .winner(of: "m1")),
        ]

        #expect(tournament.winner(of: "m1") == nil)
        #expect(tournament.entrantID(of: .winner(of: "m2")) == nil)
    }

    // MARK: - Wire shape

    @Test("A draw survives a round trip through JSON")
    func codableRoundTrip() throws {
        let pool = kids(7)
        var tournament = Tournament.seeded(
            .doubles(.knockout, requestedPairs: [.init(pool[0].id, pool[4].id)]),
            name: "Tournament 2", pool: pool, courtIndices: [0, 1], days: 3
        )
        tournament.scores["m1"] = Tournament.Score(6, 4)

        let data = try JSONEncoder().encode(tournament)
        let decoded = try JSONDecoder().decode(Tournament.self, from: data)

        #expect(decoded == tournament)
        // The prototype's own shape: a bare string for an entrant, `{"w": …}` for a forward
        // reference. Three agents have to agree about this column, so it is asserted rather than
        // left to the synthesised encoding.
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("{\"w\":\"m1\"}"))
    }
}

// MARK: - The fold control

@Suite("Tournament — folding a table")
struct TournamentFoldTests {

    /// The defect this pins was on screen: a four-entrant round robin drew all four places and then
    /// offered "+0 more" underneath them.
    @Test("A table one row over the preview draws in full and offers no fold")
    func oneOverPreviewDoesNotFold() {
        let preview = TournamentRules.standingsPreviewRows

        #expect(TournamentRules.visibleCount(of: preview + 1, preview: preview, isExpanded: false) == preview + 1)
        #expect(!TournamentRules.showsMoreRow(of: preview + 1, preview: preview, isExpanded: false))
    }

    @Test("The two rules never disagree, at any size")
    func theGateFollowsTheRows() {
        for preview in 1...6 {
            for count in 0...40 {
                let shown = TournamentRules.visibleCount(of: count, preview: preview, isExpanded: false)
                let offered = TournamentRules.showsMoreRow(of: count, preview: preview, isExpanded: false)

                // The control appears exactly when it has rows to reveal. Never "+0 more", and
                // never rows hidden with no way to reach them.
                #expect(offered == (shown < count))
            }
        }
    }

    @Test("Expanded, the fold stays so the table can be closed again")
    func expandedKeepsTheControl() {
        for count in 0...12 {
            #expect(TournamentRules.showsMoreRow(of: count, preview: 3, isExpanded: true))
            #expect(TournamentRules.visibleCount(of: count, preview: 3, isExpanded: true) == count)
        }
    }

    @Test("A table well past the preview folds to the preview and says how many are left")
    func aLongTableFolds() {
        #expect(TournamentRules.visibleCount(of: 12, preview: 3, isExpanded: false) == 3)
        #expect(TournamentRules.showsMoreRow(of: 12, preview: 3, isExpanded: false))
    }
}
