//
//  CampPartitionTests.swift
//  SycamoreTests
//
//  "Partition the camp" and "Even out" decide which child stands on which court. There is no
//  screen that shows the arithmetic and no error a wrong answer can raise — a bad split just
//  looks like a camp somebody organised badly.
//
//  The clamping in `partition()` is the part worth pinning. An even share is only the starting
//  guess; it is then squeezed between what the venues below still need to reach their minimums
//  and what they can hold before their maximums, and those two bounds can cross. Which of the
//  three branches fires decides whether a venue is starved, stuffed, or left at its share.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("Camp.partition")
struct CampPartitionTests {

    // MARK: The ordinary case

    @Test("Splits evenly when nobody's limits are in the way")
    func splitsEvenly() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 6, min: 40, max: 60), .init("LATC", courts: 6, min: 40, max: 60)],
            players: 100
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp) == [50, 50])
    }

    @Test("Fills the venues by rank, in the venues' own order")
    func fillsByRank() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 2), .init("LATC", courts: 2)],
            players: 10
        )

        camp.partition()

        let venues = camp.orderedVenues
        #expect(camp.players(in: venues[0].id).map(\.overallRank) == [1, 2, 3, 4, 5])
        #expect(camp.players(in: venues[1].id).map(\.overallRank) == [6, 7, 8, 9, 10])
    }

    @Test("Leaves the camp ladder alone — it decides venues, not rank")
    func doesNotReorderTheLadder() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 3), .init("LATC", courts: 3)],
            players: 20
        )
        let before = Fixture.ladder(camp)

        camp.partition()

        #expect(Fixture.ladder(camp) == before)
    }

    @Test("Running it twice changes nothing the second time")
    func isIdempotent() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 4, min: 10, max: 30), .init("LATC", courts: 3, min: 5, max: 30)],
            players: 37
        )

        camp.partition()
        let once = camp

        camp.partition()

        #expect(Fixture.venueSizes(camp) == Fixture.venueSizes(once))
        #expect(camp.players.map(\.groupID) == once.players.map(\.groupID))
    }

    // MARK: The clamps

    /// `high` — `remaining - floorForRest` — is what stops an early venue from taking its even
    /// share when doing so would leave the venues below unable to reach their minimums. Here
    /// the middle venue is starved to nothing so the last one can fill.
    @Test("A later venue's minimum beats an earlier venue's even share")
    func aLaterMinimumStarvesAnEarlierVenue() {
        var camp = Fixture.camp(
            [
                .init("A", courts: 2, min: 0, max: 30),
                .init("B", courts: 2, min: 0, max: 30),
                .init("C", courts: 2, min: 20, max: 30),
            ],
            players: 30
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp) == [10, 0, 20])
        // The one that matters: C reached its floor.
        #expect(camp.players(in: camp.orderedVenues[2].id).count >= 20)
    }

    /// `low` — `remaining - ceilingForRest` — is the mirror image: an early venue has to take
    /// *more* than its even share when the venues below cannot hold the rest.
    @Test("A later venue's maximum forces an earlier venue past its even share")
    func aLaterMaximumStuffsAnEarlierVenue() {
        var camp = Fixture.camp(
            [.init("A", courts: 3, min: 0, max: 30), .init("B", courts: 1, min: 0, max: 5)],
            players: 30
        )

        camp.partition()

        // An even share would have been 15. B can only hold 5, so A takes 25.
        #expect(Fixture.venueSizes(camp) == [25, 5])
    }

    @Test("A venue's own maximum caps what it takes")
    func aVenuesOwnMaximumCaps() {
        var camp = Fixture.camp(
            [.init("A", courts: 2, min: 0, max: 4), .init("B", courts: 2, min: 0, max: 100)],
            players: 20
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp) == [4, 16])
    }

    @Test("A venue's own minimum lifts what it takes")
    func aVenuesOwnMinimumLifts() {
        var camp = Fixture.camp(
            [.init("A", courts: 2, min: 16, max: 100), .init("B", courts: 2, min: 0, max: 100)],
            players: 20
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp) == [16, 4])
    }

    // MARK: When the limits cannot all be met

    /// `take = high >= low ? … : …`. When the bounds cross there is no answer that satisfies
    /// every limit, and the branch decides which way to fail. Falling back to the even share
    /// keeps the venues below in play; clamping to `high` instead would let one venue with an
    /// unreachable minimum swallow the camp and leave the rest empty.
    @Test("An unreachable minimum falls back to the even share rather than taking everything")
    func crossedBoundsFallBackToTheEvenShare() {
        var camp = Fixture.camp(
            [.init("A", courts: 2, min: 10, max: 20), .init("B", courts: 2, min: 0, max: 20)],
            players: 5
        )

        camp.partition()

        // A cannot reach 10 — there are only five kids in the camp — so it takes its share of
        // three and B still gets two. Clamping to `high` would have made this [5, 0].
        #expect(Fixture.venueSizes(camp) == [3, 2])
    }

    /// The invariant the whole clamp exists to protect. `ladder[cursor..<(cursor + take)]` traps
    /// if `take` ever runs past the end, and a `take` that is too small silently leaves kids
    /// wherever they happened to be — which after a partition reads as a court that was skipped.
    @Test("Every kid lands somewhere even when the camp does not fit inside its venues")
    func nobodyIsDroppedWhenTheCampOverflows() {
        var camp = Fixture.camp(
            [.init("A", courts: 2, min: 0, max: 5), .init("B", courts: 2, min: 0, max: 5)],
            players: 30
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp).reduce(0, +) == 30)
        #expect(camp.players.allSatisfy { $0.venueID != nil && $0.groupID != nil })
    }

    @Test("The last venue absorbs whatever is left, ceiling or no ceiling")
    func theLastVenueAbsorbsTheRemainder() {
        var camp = Fixture.camp(
            [.init("A", courts: 2, min: 0, max: 100), .init("B", courts: 2, min: 0, max: 3)],
            players: 9
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp).reduce(0, +) == 9)
        #expect(Fixture.venueSizes(camp)[1] > 0)
    }

    @Test("A camp with more venues than kids does not trap")
    func moreVenuesThanKids() {
        var camp = Fixture.camp(
            [.init("A", courts: 2), .init("B", courts: 2), .init("C", courts: 2), .init("D", courts: 2)],
            players: 2
        )

        camp.partition()

        #expect(Fixture.venueSizes(camp).reduce(0, +) == 2)
    }

    @Test("An empty camp partitions to nothing")
    func anEmptyCamp() {
        var camp = Fixture.camp([.init("A", courts: 2), .init("B", courts: 2)], players: 0)

        camp.partition()

        #expect(Fixture.venueSizes(camp) == [0, 0])
    }

    @Test("A camp with no venues is left alone")
    func noVenues() {
        var camp = Fixture.camp([], players: 4)

        camp.partition()

        #expect(camp.players.count == 4)
        #expect(camp.orderedPlayers.map(\.overallRank) == [1, 2, 3, 4])
    }

    // MARK: Courts

    @Test("Partitioning also deals each venue's block across its courts")
    func partitionDealsTheCourts() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 3), .init("LATC", courts: 2)],
            players: 20
        )

        camp.partition()

        let venues = camp.orderedVenues
        #expect(Fixture.courtSizes(camp, in: venues[0].id) == [4, 3, 3])
        #expect(Fixture.courtSizes(camp, in: venues[1].id) == [5, 5])
    }
}

@Suite("Camp.evenOut and redistribute")
struct CampEvenOutTests {

    @Test("Levels the courts inside a venue to within one kid of each other")
    func levelsTheCourts() {
        var camp = Fixture.camp([.init("Sycamore", courts: 6)], players: 50)

        camp.evenOut()

        let sizes = Fixture.courtSizes(camp, in: camp.venues[0].id)
        #expect(sizes == [9, 9, 8, 8, 8, 8])
        #expect((sizes.max() ?? 0) - (sizes.min() ?? 0) <= 1)
    }

    @Test("Gives the leftovers to the courts that come first")
    func leftoversGoToTheFirstCourts() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 10)

        camp.evenOut()

        #expect(Fixture.courtSizes(camp, in: camp.venues[0].id) == [3, 3, 2, 2])
    }

    @Test("Deals top-down by rank, so court 1 gets the top of the ladder")
    func dealsTopDownByRank() {
        var camp = Fixture.camp([.init("Sycamore", courts: 3)], players: 9)

        camp.evenOut()

        let courts = camp.groups(in: camp.venues[0].id)
        #expect(camp.players(inGroup: courts[0].id).map(\.overallRank) == [1, 2, 3])
        #expect(camp.players(inGroup: courts[1].id).map(\.overallRank) == [4, 5, 6])
        #expect(camp.players(inGroup: courts[2].id).map(\.overallRank) == [7, 8, 9])
    }

    /// Even-out is a court operation. A coach pressing it on the Rank tab should not find kids
    /// have crossed a venue rule, which is a different — and much louder — kind of change.
    @Test("Never moves a kid between venues")
    func staysInsideTheVenue() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 3), .init("LATC", courts: 3)],
            players: 20
        )
        camp.partition()
        let before = Dictionary(uniqueKeysWithValues: camp.players.map { ($0.id, $0.venueID) })

        camp.evenOut()

        for player in camp.players {
            #expect(player.venueID == before[player.id])
        }
    }

    @Test("Leaves the camp ladder alone")
    func doesNotReorderTheLadder() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 15)
        let before = Fixture.ladder(camp)

        camp.evenOut()

        #expect(Fixture.ladder(camp) == before)
    }

    @Test("Numbers each court from 1")
    func numbersEachCourtFromOne() {
        var camp = Fixture.camp([.init("Sycamore", courts: 3)], players: 8)

        camp.evenOut()

        for court in camp.groups(in: camp.venues[0].id) {
            let ranks = camp.players(inGroup: court.id).map(\.courtRank)
            #expect(ranks == ranks.indices.map { $0 + 1 })
        }
    }

    @Test("More courts than kids leaves the tail empty rather than trapping")
    func moreCourtsThanKids() {
        var camp = Fixture.camp([.init("Sycamore", courts: 5)], players: 2)

        camp.evenOut()

        #expect(Fixture.courtSizes(camp, in: camp.venues[0].id) == [1, 1, 0, 0, 0])
    }

    @Test("A venue with no kids evens out to nothing")
    func noKids() {
        var camp = Fixture.camp([.init("Sycamore", courts: 3)], players: 0)

        camp.evenOut()

        #expect(Fixture.courtSizes(camp, in: camp.venues[0].id) == [0, 0, 0])
    }

    @Test("A venue with no courts is skipped rather than crashing")
    func noCourts() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 4)
        // Trimming the last court is what Setup's stepper does; the kids fall back to the
        // venue's remaining courts, and here there are none.
        camp.groups.removeAll()

        camp.evenOut()

        #expect(camp.players.count == 4)
    }
}
