//
//  CampCourtSubsetTests.swift
//  SycamoreTests
//
//  Dealing a venue's kids across *some* of its courts, which is what an assigned block asks for.
//
//  `CampPartitionTests` already covers the whole-venue deal — that it levels to within one, that
//  it fills top-down by rank, that it never crosses a venue rule. This file is about the argument
//  those tests do not pass, and it earns a file of its own because of what its failure looks like:
//  nothing throws, nothing draws red, kids are simply standing on the wrong courts and the only
//  way to find out is to walk outside and count them.
//
//  Three questions, asked in several shapes:
//
//  1. Does the court set actually narrow the deal, or does something quietly fall back to every
//     court in the venue? A subset that is ignored is the exact bug "warm-up on one court" exists
//     to avoid, and on the screen it looks identical to a correct even-out.
//  2. Does the order of the ids leak into the answer? They arrive from a `Set` in a picker, which
//     has no order worth having, so the deal has to take the venue's own.
//  3. Does an id the venue does not own do anything at all? A block carries court ids as data, and
//     data goes stale the moment somebody deletes a court in Setup.
//
//  Written with the setup inline rather than behind a helper, the way `CampPartitionTests` writes
//  it: a shared `var camp` in a fixture would be one more thing between the numbers asserted and
//  the numbers set up.
//

import Testing
@testable import Sycamore

@Suite("Camp.redistribute across a court subset")
struct CampCourtSubsetTests {

    /// Everyone starts parked on court 1 — `Fixture.camp`'s own arrangement, and right here for
    /// its stated reason: a test that asserts where a deal *put* somebody proves nothing if they
    /// were already there.
    private static let sycamore = Fixture.VenueSpec("Sycamore", courts: 6)

    // MARK: The subset is the subset

    /// The sentence the whole change exists to be able to say.
    @Test("Warm-up: one court, every kid at the venue")
    func allKidsOntoOneCourt() {
        var camp = Fixture.camp([Self.sycamore], players: 22)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[0]])

        #expect(Fixture.courtSizes(camp, in: venueID) == [22, 0, 0, 0, 0, 0])
    }

    @Test("Deals across the courts named and empties the ones that were not")
    func narrowsToTheSubset() {
        var camp = Fixture.camp([Self.sycamore], players: 10)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[0], courts[1], courts[2]])

        #expect(Fixture.courtSizes(camp, in: venueID) == [4, 3, 3, 0, 0, 0])
    }

    /// The failure this file is really written for: a subset silently widening to the venue.
    /// Twelve kids over six courts is `[2, 2, 2, 2, 2, 2]` and over the first two is `[6, 6]`, so
    /// a fallback to "all courts" cannot hide behind the arithmetic.
    @Test("A subset never widens to the whole venue")
    func doesNotFallBackToEveryCourt() {
        var camp = Fixture.camp([Self.sycamore], players: 12)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[0], courts[1]])

        #expect(Fixture.courtSizes(camp, in: venueID) == [6, 6, 0, 0, 0, 0])
    }

    @Test("Levels the chosen courts to within one kid of each other")
    func levelsWithinOne() {
        var camp = Fixture.camp([Self.sycamore], players: 23)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: Array(courts.prefix(4)))

        let sizes = Fixture.courtSizes(camp, in: venueID)
        #expect(sizes == [6, 6, 6, 5, 0, 0])
        let chosen = sizes.prefix(4)
        #expect((chosen.max() ?? 0) - (chosen.min() ?? 0) <= 1)
    }

    @Test("Numbers each chosen court's kids from 1")
    func courtRanksStartAtOne() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 9)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[0], courts[1]])

        for court in camp.groups(in: venueID) {
            let ranks = camp.players(inGroup: court.id).map(\.courtRank)
            #expect(ranks == ranks.indices.map { $0 + 1 })
        }
    }

    // MARK: Order comes from the venue, not from the caller

    @Test("The top of the ladder goes to the first court, whatever order the ids arrived in")
    func ignoresTheOrderOfTheIDs() {
        var forwards = Fixture.camp([.init("Sycamore", courts: 4)], players: 9)
        let venueID = forwards.venues[0].id
        let courts = forwards.groups(in: venueID).map(\.id)
        var backwards = forwards
        let chosen = [courts[0], courts[1], courts[2]]

        forwards.redistribute(in: venueID, across: chosen)
        backwards.redistribute(in: venueID, across: chosen.reversed())

        // Court 1 takes ranks 1–3 both ways round. Handed the ids backwards, a deal that trusted
        // the argument's order would have put the bottom of the ladder there.
        #expect(forwards.players(inGroup: courts[0]).map(\.overallRank) == [1, 2, 3])
        #expect(backwards.players(inGroup: courts[0]).map(\.overallRank) == [1, 2, 3])
        #expect(
            Fixture.courtSizes(forwards, in: venueID) == Fixture.courtSizes(backwards, in: venueID)
        )
    }

    @Test("Deals top-down, so the best kids land on the lowest-ranked court chosen")
    func dealsTopDownByRank() {
        var camp = Fixture.camp([.init("Sycamore", courts: 5)], players: 9)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[1], courts[3], courts[4]])

        #expect(camp.players(inGroup: courts[1]).map(\.overallRank) == [1, 2, 3])
        #expect(camp.players(inGroup: courts[3]).map(\.overallRank) == [4, 5, 6])
        #expect(camp.players(inGroup: courts[4]).map(\.overallRank) == [7, 8, 9])
    }

    // MARK: Ids the venue does not own

    @Test("A court named twice is dealt to once")
    func deduplicates() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 8)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[0], courts[0], courts[1]])

        // Two courts, not three — and certainly not court 1 twice, which would have dealt it four
        // kids and then overwritten them with four more.
        #expect(Fixture.courtSizes(camp, in: venueID) == [4, 4, 0, 0])
    }

    @Test("An id from another venue is ignored, and nobody changes venue")
    func ignoresAnotherVenuesCourt() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 3), .init("LATC", courts: 3)], players: 12
        )
        camp.partition()
        let venues = camp.orderedVenues
        let elsewhere = camp.groups(in: venues[1].id)[0].id
        let home = camp.groups(in: venues[0].id).map(\.id)
        let before = Dictionary(uniqueKeysWithValues: camp.players.map { ($0.id, $0.venueID) })

        camp.redistribute(in: venues[0].id, across: [home[0], elsewhere])

        // Every kid at Sycamore on Sycamore's court 1; LATC untouched by a call about Sycamore.
        #expect(Fixture.courtSizes(camp, in: venues[0].id) == [6, 0, 0])
        #expect(Fixture.courtSizes(camp, in: venues[1].id) == [2, 2, 2])
        for player in camp.players {
            #expect(player.venueID == before[player.id])
        }
    }

    @Test("A court that has been deleted takes nobody with it")
    func ignoresAStaleCourt() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 8)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        camp.venues[0].groupCount = 3
        camp.syncGroups(for: venueID)

        camp.redistribute(in: venueID, across: [courts[0], courts[3]])

        #expect(camp.groups(in: venueID).count == 3)
        #expect(Fixture.courtSizes(camp, in: venueID) == [8, 0, 0])
    }

    /// Every id gone means no courts to deal to, which is a no-op rather than a crash or an
    /// emptied venue. `redistribute(in:)` has always answered a venue with no courts this way.
    @Test("An empty subset moves nobody")
    func emptySubsetIsANoOp() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 8)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        camp.redistribute(in: venueID, across: [courts[1]])
        let before = Fixture.courtSizes(camp, in: venueID)

        camp.redistribute(in: venueID, across: [])

        #expect(Fixture.courtSizes(camp, in: venueID) == before)
        #expect(before == [0, 8, 0, 0])
    }

    @Test("More courts than kids leaves the tail of the subset empty rather than trapping")
    func moreCourtsThanKids() {
        var camp = Fixture.camp([.init("Sycamore", courts: 5)], players: 2)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: Array(courts.prefix(4)))

        #expect(Fixture.courtSizes(camp, in: venueID) == [1, 1, 0, 0, 0])
    }

    // MARK: The old spelling still means what it meant

    @Test("The no-argument call is the whole venue, exactly as it was")
    func wholeVenueIsUnchanged() {
        var byName = Fixture.camp([Self.sycamore], players: 50)
        var byHand = byName
        let venueID = byName.venues[0].id

        byName.redistribute(in: venueID)
        byHand.redistribute(in: venueID, across: byHand.groups(in: venueID).map(\.id))

        // The number `CampEvenOutTests.levelsTheCourts` already pins, restated here because this
        // is the call that now goes through the generalisation.
        #expect(Fixture.courtSizes(byName, in: venueID) == [9, 9, 8, 8, 8, 8])
        #expect(Fixture.courtSizes(byName, in: venueID) == Fixture.courtSizes(byHand, in: venueID))
        #expect(Fixture.ladder(byName) == Fixture.ladder(byHand))
    }

    @Test("Leaves the camp ladder alone")
    func doesNotReorderTheLadder() {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 15)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        let before = Fixture.ladder(camp)

        camp.redistribute(in: venueID, across: [courts[0], courts[2]])

        #expect(Fixture.ladder(camp) == before)
    }
}

@Suite("Camp.evenOut over a court subset")
struct CampSubsetEvenOutTests {

    /// Six courts, three kids on each — a venue a levelling call has something to level *and*
    /// something to leave alone.
    private static func filled() -> Camp {
        var camp = Fixture.camp([.init("Sycamore", courts: 6)], players: 18)
        camp.redistribute(in: camp.venues[0].id)
        return camp
    }

    /// The difference between the two operations, stated as a test. This is the one that catches
    /// "divide evenly" quietly behaving like "put every kid on these courts" — which on a venue
    /// where another block owns courts 4–6 would empty those courts without saying so.
    @Test("Touches only the kids already on the courts named")
    func leavesTheOtherCourtsAlone() {
        var camp = Self.filled()
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.evenOut([courts[0], courts[1], courts[2]], in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 3, 3, 3, 3, 3])
    }

    /// The state a warm-up leaves behind: everybody on court 1, the rest of the venue empty. The
    /// block after it levels the courts it uses, and the eighteen it finds are the eighteen it
    /// deals.
    @Test("Levels a lopsided subset without pulling anybody in")
    func levelsWhatIsThere() {
        var camp = Self.filled()
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        camp.redistribute(in: venueID, across: [courts[0]])

        camp.evenOut([courts[0], courts[1], courts[2]], in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [6, 6, 6, 0, 0, 0])
    }

    @Test("Keeps the deal top-down by rank")
    func dealsTopDownByRank() {
        var camp = Self.filled()
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        camp.redistribute(in: venueID, across: [courts[0]])

        camp.evenOut([courts[0], courts[1]], in: venueID)

        #expect(camp.players(inGroup: courts[0]).map(\.overallRank) == Array(1...9))
        #expect(camp.players(inGroup: courts[1]).map(\.overallRank) == Array(10...18))
    }

    @Test("Levelling courts nobody is standing on moves nobody")
    func emptyCourtsAreANoOp() {
        var camp = Self.filled()
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        camp.redistribute(in: venueID, across: [courts[0]])
        let before = Fixture.courtSizes(camp, in: venueID)

        camp.evenOut([courts[3], courts[4]], in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == before)
        #expect(before == [18, 0, 0, 0, 0, 0])
    }

    @Test("Never moves a kid between venues")
    func staysInsideTheVenue() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 3), .init("LATC", courts: 3)], players: 20
        )
        camp.partition()
        let venues = camp.orderedVenues
        let courts = camp.groups(in: venues[0].id).map(\.id)
        let before = Dictionary(uniqueKeysWithValues: camp.players.map { ($0.id, $0.venueID) })

        camp.evenOut([courts[0], courts[1]], in: venues[0].id)

        for player in camp.players {
            #expect(player.venueID == before[player.id])
        }
    }
}
