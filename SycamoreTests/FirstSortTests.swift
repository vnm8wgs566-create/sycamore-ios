//
//  FirstSortTests.swift
//  SycamoreTests
//
//  `4c` asks somebody to tap the stronger of two kids, forty times, and hands the result to
//  `commitRankOrder`. Nothing on the screen shows the arithmetic and no answer can raise an error
//  — a ladder built wrongly just looks like a camp somebody ranked badly, which is precisely what
//  the screen exists to stop being true.
//
//  Two properties carry most of this file, and both are stated as invariants rather than as
//  examples because both are the kind that break quietly:
//
//    - **Nobody already placed is reshuffled.** Every answer inserts one kid and moves nobody, so
//      the ladder before an answer is always a subsequence of the ladder after it. `holdsSteady`
//      checks that after every mutation of a long random session rather than at the end, so a rule
//      that reorders on one branch in fifty cannot hide behind a correct final ordering.
//    - **The window belongs to its candidate.** A `skip()` that left `lo`/`hi` behind would seat
//      the *next* kid using the last one's answers, and the resulting ladder would still be
//      plausible — a wrong rung is not a crash. `skipMintsAFreshWindow` pins the probe itself.
//
//  Where a test drives a whole session it answers from an oracle: a known true order, consulted
//  per question. Asserting the finished ladder against that order is the only check that says the
//  search converges on the right rung rather than merely on *a* rung.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()

/// `count` kids, named by `prefix`, ranked from `firstRank` down.
///
/// Ranks are handed out explicitly rather than left to arrive in array order: `seeded` claims to
/// sort the returning half by `overallRank` and a fixture that only ever agrees with array order
/// could not tell the difference.
private func kids(
    _ prefix: String, _ count: Int, returning: Bool, from firstRank: Int = 1
) -> [Player] {
    (0..<count).map { offset in
        Player(
            firstName: "\(prefix)\(offset + 1)",
            lastInitial: "T",
            age: 12,
            gender: .x,
            isReturning: returning,
            venueID: venueID,
            groupID: nil,
            overallRank: firstRank + offset,
            courtRank: firstRank + offset
        )
    }
}

/// Names rather than uuids in every expectation — a failure that reads `["R1", "N1", "R2"]` says
/// what went wrong, and one that reads three uuids says only that something did.
private func names(_ ids: [Player.ID], in roll: [Player]) -> [String] {
    let byID = Dictionary(uniqueKeysWithValues: roll.map { ($0.id, $0.firstName) })
    return ids.compactMap { byID[$0] }
}

/// The same, for the one kid on screen. Nil reads as "nobody", which is a real state here.
private func name(_ id: Player.ID?, in roll: [Player]) -> String? {
    guard let id else { return nil }
    return roll.first { $0.id == id }?.firstName
}

/// Drives the session to the end, answering every question from `truth` — a total order over the
/// roll, best first. Returns how many questions it was asked.
///
/// The candidate wins exactly when `truth` puts them above the incumbent. Ties are never used
/// here: `truth` is a strict order, and a driver that guessed at "about even" would be inventing
/// an answer the person tapping never gave.
@discardableResult
private func answerAll(_ sort: inout FirstSort, by truth: [Player.ID]) -> Int {
    let rank = Dictionary(uniqueKeysWithValues: truth.enumerated().map { ($0.element, $0.offset) })
    var asked = 0
    // A hard ceiling rather than `while !sort.isSettled`: a rule that stopped converging would
    // otherwise hang the suite instead of failing it.
    while let pair = sort.pair, asked < 1_000 {
        asked += 1
        if rank[pair.candidate, default: .max] < rank[pair.incumbent, default: .max] {
            sort.chooseCandidate()
        } else {
            sort.chooseIncumbent()
        }
    }
    return asked
}

@Suite("FirstSort")
struct FirstSortTests {

    // MARK: Seeding

    @Test("Opens with the returning kids placed and the new ones queued")
    func seedsFromLastSummer() {
        let roll = kids("R", 5, returning: true) + kids("N", 3, returning: false, from: 6)

        let sort = FirstSort.seeded(venueID: venueID, players: roll)

        #expect(names(sort.ladder, in: roll) == ["R1", "R2", "R3", "R4", "R5"])
        #expect(sort.placed == 5)
        #expect(sort.total == 8)
        // "30 of 42 placed" — the screen opens part-way through, which is the whole point of
        // seeding. The first new kid is already on screen and is counted in the total, not in
        // the placed.
        #expect(name(sort.candidate, in: roll) == "N1")
        #expect(names(sort.pending, in: roll) == ["N2", "N3"])
    }

    @Test("Sorts the seed by rank, whatever order the roll arrives in")
    func seedIgnoresArrayOrder() {
        let roll = kids("R", 4, returning: true)
        let shuffled = [roll[2], roll[0], roll[3], roll[1]]

        let sort = FirstSort.seeded(venueID: venueID, players: shuffled)

        #expect(names(sort.ladder, in: roll) == ["R1", "R2", "R3", "R4"])
    }

    @Test("Asks about the new kids in the order they were handed over")
    func pendingKeepsArrivalOrder() {
        let newcomers = kids("N", 3, returning: false)
        let roll = [newcomers[2], newcomers[0], newcomers[1]]

        let sort = FirstSort.seeded(venueID: venueID, players: roll)

        // The first one seats itself into an empty ladder without a question; the rest queue
        // behind it in the order given, not in rank order.
        #expect(names(sort.ladder, in: roll) == ["N3"])
        #expect(name(sort.candidate, in: roll) == "N1")
        #expect(names(sort.pending, in: roll) == ["N2"])
    }

    @Test("A venue of returners alone has nothing to ask")
    func allReturningIsSettled() {
        let roll = kids("R", 6, returning: true)

        let sort = FirstSort.seeded(venueID: venueID, players: roll)

        #expect(sort.isSettled)
        #expect(sort.pair == nil)
        #expect(sort.placed == 6)
        #expect(sort.total == 6)
    }

    @Test("An empty venue settles with nothing in it")
    func emptyVenue() {
        let sort = FirstSort.seeded(venueID: venueID, players: [])

        #expect(sort.isSettled)
        #expect(sort.pair == nil)
        #expect(sort.placed == 0)
        #expect(sort.total == 0)
        #expect(sort.playerIDs().isEmpty)
    }

    @Test("The first kid into an empty ladder is placed without being asked about")
    func firstKidNeedsNoQuestion() {
        let roll = kids("N", 1, returning: false)

        let sort = FirstSort.seeded(venueID: venueID, players: roll)

        #expect(sort.isSettled)
        #expect(names(sort.ladder, in: roll) == ["N1"])
    }

    // MARK: The search

    @Test("Answers put every kid on the rung the answers describe")
    func convergesOnTheAnsweredOrder() {
        let returners = kids("R", 5, returning: true)
        let newcomers = kids("N", 3, returning: false, from: 6)
        let roll = returners + newcomers
        // A truth that keeps the returners in their seeded order — binary insertion assumes the
        // ladder it inserts into is already sorted, and a truth that contradicted the seed would
        // be asking the sort to fix something it never claimed to.
        let truth = [
            returners[0], newcomers[0], returners[1], returners[2],
            newcomers[1], returners[3], returners[4], newcomers[2],
        ].map(\.id)

        var sort = FirstSort.seeded(venueID: venueID, players: roll)
        answerAll(&sort, by: truth)

        #expect(sort.isSettled)
        #expect(names(sort.ladder, in: roll) == names(truth, in: roll))
        #expect(sort.placed == 8)
        #expect(sort.total == 8)
    }

    @Test("Costs a binary search's worth of questions, not a linear scan's")
    func asksLogarithmicallyManyQuestions() {
        let returners = kids("R", 3, returning: true)
        let newcomer = kids("N", 1, returning: false, from: 4)[0]
        // Straight to the top of a ladder of three: window 0..<3, then 0..<1, then seated.
        // ⌈log₂(3+1)⌉ = 2. A scan down the ladder would take three.
        let truth = [newcomer.id] + returners.map(\.id)

        var sort = FirstSort.seeded(venueID: venueID, players: returners + [newcomer])
        let asked = answerAll(&sort, by: truth)

        #expect(asked == 2)
        #expect(names(sort.ladder, in: returners + [newcomer]) == ["N1", "R1", "R2", "R3"])
    }

    @Test("Nobody already placed is reshuffled, at any point in a long session")
    func holdsSteady() {
        let roll = kids("R", 7, returning: true) + kids("N", 9, returning: false, from: 8)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)
        // Deterministic and arbitrary: a fixed generator so a failure is reproducible, and a mix
        // of all four answers so no branch is left out of the invariant.
        var seed: UInt64 = 0x5EED
        var steps = 0

        while sort.pair != nil, steps < 500 {
            steps += 1
            let before = sort.ladder
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            switch (seed >> 33) % 8 {
            case 0, 1, 2: sort.chooseCandidate()
            case 3, 4, 5: sort.chooseIncumbent()
            case 6: sort.tie()
            default: sort.skip()
            }
            #expect(isSubsequence(before, of: sort.ladder))
            #expect(sort.ladder.count - before.count <= 1)
        }

        #expect(sort.isSettled)
        // Everyone ends up somewhere: the ladder and the set-aside pile together are the roll.
        #expect(Set(sort.playerIDs()) == Set(roll.map(\.id)))
        #expect(sort.playerIDs().count == roll.count)
    }

    // MARK: About even

    @Test("A tie seats the candidate directly below the incumbent")
    func tieSeatsBelow() throws {
        let returners = kids("R", 3, returning: true)
        let newcomer = kids("N", 1, returning: false, from: 4)[0]
        let roll = returners + [newcomer]
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        // The opening probe on a ladder of three is the middle rung.
        #expect(name(try #require(sort.pair).incumbent, in: roll) == "R2")
        sort.tie()

        #expect(names(sort.ladder, in: roll) == ["R1", "R2", "N1", "R3"])
    }

    @Test("A tie costs no further questions and reshuffles nobody")
    func tieEndsTheInsertion() {
        let returners = kids("R", 5, returning: true)
        let newcomer = kids("N", 1, returning: false, from: 6)[0]
        let roll = returners + [newcomer]
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        sort.tie()

        #expect(sort.isSettled)
        #expect(sort.pair == nil)
        #expect(sort.placed == 6)
        // Every returner is where the seed left them, in the same order.
        #expect(names(sort.ladder.filter { $0 != newcomer.id }, in: roll)
            == ["R1", "R2", "R3", "R4", "R5"])
    }

    // MARK: Skip

    @Test("A skip sets the candidate aside without placing them")
    func skipSetsAside() {
        let roll = kids("R", 3, returning: true) + kids("N", 2, returning: false, from: 4)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        sort.skip()

        #expect(names(sort.skipped, in: roll) == ["N1"])
        #expect(names(sort.ladder, in: roll) == ["R1", "R2", "R3"])
        #expect(sort.placed == 3)
        // The roll does not shrink because somebody was hard to place.
        #expect(sort.total == 5)
        #expect(name(sort.candidate, in: roll) == "N2")
    }

    @Test("A skip throws the half-answered window away")
    func skipMintsAFreshWindow() throws {
        let roll = kids("R", 3, returning: true) + kids("N", 2, returning: false, from: 4)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        // Push N1's window down to the foot of the ladder — 0..<3 becomes 2..<3 — then abandon it.
        sort.chooseIncumbent()
        #expect(name(try #require(sort.pair).incumbent, in: roll) == "R3")
        sort.skip()

        // N2 opens against the middle rung. Against R3 would mean the dead window had survived
        // its candidate, and N2 would be seated using answers somebody gave about N1.
        let fresh = try #require(sort.pair)
        #expect(name(fresh.candidate, in: roll) == "N2")
        #expect(name(fresh.incumbent, in: roll) == "R2")
    }

    @Test("A skipped kid is not asked about again")
    func skippedIsNotRequeued() {
        let roll = kids("R", 2, returning: true) + kids("N", 2, returning: false, from: 3)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        sort.skip()
        answerAll(&sort, by: roll.map(\.id))

        #expect(sort.isSettled)
        #expect(names(sort.skipped, in: roll) == ["N1"])
        #expect(!sort.ladder.contains(roll[2].id))
    }

    @Test("Skipped kids fall to the foot of the venue, in the order they were set aside")
    func skippedGoToTheFoot() {
        let roll = kids("R", 2, returning: true) + kids("N", 3, returning: false, from: 3)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        sort.skip()          // N1
        sort.skip()          // N2
        answerAll(&sort, by: roll.map(\.id))

        #expect(names(sort.playerIDs(), in: roll) == ["R1", "R2", "N3", "N1", "N2"])
    }

    // MARK: Progress

    @Test("The kid on screen is in the total but not in the placed")
    func inFlightCandidateIsNotPlaced() {
        let roll = kids("R", 4, returning: true) + kids("N", 2, returning: false, from: 5)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)

        #expect(sort.placed == 4)
        #expect(sort.total == 6)

        // Answering half a question moves neither figure: the candidate is still in flight.
        sort.chooseIncumbent()
        #expect(sort.placed == 4)
        #expect(sort.total == 6)
    }

    @Test("The total never moves, whatever the answers are")
    func totalIsTheRoll() {
        let roll = kids("R", 3, returning: true) + kids("N", 4, returning: false, from: 4)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)
        var seen: Set<Int> = []

        while sort.pair != nil, seen.count < 100 {
            seen.insert(sort.total)
            sort.chooseCandidate()
        }
        seen.insert(sort.total)

        #expect(seen == [7])
    }

    // MARK: Answers with nothing on screen

    @Test("Answers after the ladder settles do nothing")
    func answersAfterSettlingAreInert() {
        let roll = kids("R", 3, returning: true)
        var sort = FirstSort.seeded(venueID: venueID, players: roll)
        let settled = sort

        sort.chooseCandidate()
        sort.chooseIncumbent()
        sort.tie()
        sort.skip()

        #expect(sort == settled)
    }
}

// MARK: - Helpers

/// Whether `small` appears inside `large` in order, gaps allowed — "nobody moved, somebody
/// arrived", written as a predicate.
private func isSubsequence(_ small: [Player.ID], of large: [Player.ID]) -> Bool {
    var iterator = large.makeIterator()
    for wanted in small {
        var found = false
        while !found, let next = iterator.next() {
            found = next == wanted
        }
        if !found { return false }
    }
    return true
}
