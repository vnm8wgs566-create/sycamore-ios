//
//  RosterAgeFitTests.swift
//  SycamoreTests
//
//  Where an arriving kid lands once the venues' age bands have had their say.
//
//  Two things are worth pinning and neither is arithmetic. The first is that `AgeBand.admits` stays
//  the only judge — in particular of a **missing** age, which it refuses at a restricted band on
//  purpose. The second is the copy: a kid with no age on file and a kid who is genuinely the wrong
//  age end up in the same place on screen, and the sentence beside them must not say the same thing.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("RosterAgeFit")
struct RosterAgeFitTests {

    // MARK: Fixtures

    private static func venue(_ name: String, _ band: AgeBand) -> RosterVenue {
        RosterVenue(id: UUID(), name: name, band: band)
    }

    private static func kid(_ name: String, age: Int?, at venueIndex: Int = 0) -> IntakePlayer {
        IntakePlayer(firstName: name, lastName: "T", age: age, venueIndex: venueIndex)
    }

    // MARK: A venue that is not asking

    @Test("An all-ages venue takes everybody, including the kids with no age")
    func allAgesTakesEverybody() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 8), Self.kid("Bo", age: 15), Self.kid("Cy", age: nil)],
            venues: [Self.venue("Sycamore", .all)]
        )

        #expect(fit.isEverybodyPlaced)
        #expect(fit.unplaced.isEmpty)
        #expect(!fit.anyVenueAsks)
        // Hoisted rather than written inside `#expect`: the macro decomposes a function call into
        // a generic closure, which turns `allSatisfy`'s `rethrows` into a throwing call it then
        // refuses without a `try`. A plain `Bool` has nothing to decompose.
        let allAtTheFirst = fit.landings.allSatisfy { $0.venueIndex == 0 }
        #expect(allAtTheFirst)
    }

    @Test("No venues at all places everybody and refuses nobody")
    func noVenuesRefusesNobody() {
        let fit = RosterAgeFit([Self.kid("Ana", age: 8), Self.kid("Cy", age: nil)], venues: [])

        #expect(fit.isEverybodyPlaced)
        let allAtTheFirst = fit.routedRows.allSatisfy { $0.venueIndex == 0 }
        #expect(allAtTheFirst)
    }

    // MARK: A venue that is asking

    @Test("A kid outside the band goes to a venue that takes them")
    func routedToTheVenueThatTakesThem() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 9), Self.kid("Bo", age: 14)],
            venues: [Self.venue("Juniors", .upTo(11)), Self.venue("Seniors", .from(12))]
        )

        #expect(fit.isEverybodyPlaced)
        #expect(fit.landings.map(\.venueIndex) == [0, 1])
        #expect(fit.landings.map(\.venueName) == ["Juniors", "Seniors"])
        // The rewritten row is what the commit sends; the untouched one still says 0.
        #expect(fit.routedRows.map(\.venueIndex) == [0, 1])
    }

    @Test("Nobody takes them, so they are still created and still reported")
    func nobodyTakesThem() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 9), Self.kid("Bo", age: 14)],
            venues: [Self.venue("Seniors", .from(12))]
        )

        #expect(fit.placed.count == 1)
        #expect(fit.unplaced.count == 1)

        let stranded = fit.unplaced[0]
        #expect(stranded.row.firstName == "Ana")
        #expect(stranded.refusal == .outsideTheAges)
        // Created, not dropped: they still carry a venue, because nothing in this app can write a
        // kid who belongs to none.
        #expect(stranded.venueIndex == 0)
        #expect(fit.routedRows.count == 2)
    }

    // MARK: The missing age

    /// `AgeBand.admits` refuses a nil age at a restricted band and gives the argument for it. This
    /// only checks that the fit does not second-guess it, and that the kid is counted.
    @Test("No age does not satisfy a restricted band")
    func missingAgeIsRefusedByARestrictedBand() {
        let fit = RosterAgeFit(
            [Self.kid("Cy", age: nil)],
            venues: [Self.venue("Seniors", .from(12))]
        )

        #expect(fit.unplaced.count == 1)
        #expect(fit.unplaced[0].refusal == .noAgeOnFile)
    }

    @Test("No age lands at an all-ages venue when the camp has one")
    func missingAgeFindsTheOpenVenue() {
        let fit = RosterAgeFit(
            [Self.kid("Cy", age: nil)],
            venues: [Self.venue("Seniors", .from(12)), Self.venue("Sycamore", .all)]
        )

        #expect(fit.isEverybodyPlaced)
        #expect(fit.landings[0].venueIndex == 1)
    }

    /// The whole reason `Refusal` has two cases. A blank cell in a spreadsheet is not a child being
    /// the wrong age, and the line next to their name must not say it was.
    @Test("The two refusals read as different sentences")
    func theTwoRefusalsReadDifferently() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 9), Self.kid("Cy", age: nil)],
            venues: [Self.venue("Seniors", .from(12))]
        )

        let wrongAge = fit.reason(for: fit.unplaced[0])
        let noAge = fit.reason(for: fit.unplaced[1])

        #expect(wrongAge == "9 years · no venue takes that age")
        #expect(noAge == "No age on file · 12 & up needs one")
        #expect(!noAge.contains("that age"))
    }

    // MARK: The summary

    @Test("The outcome line names the venue when one took them all")
    func outcomeLineOneVenue() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 13), Self.kid("Bo", age: 14), Self.kid("Cy", age: 9)],
            venues: [Self.venue("Seniors", .from(12))]
        )

        #expect(fit.outcomeLine == "2 go to Seniors · 1 needs someone to place them")
    }

    @Test("The outcome line drops its second half when everybody landed")
    func outcomeLineWhenAllPlaced() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 13), Self.kid("Bo", age: 14)],
            venues: [Self.venue("Seniors", .from(12))]
        )

        #expect(fit.outcomeLine == "2 go to Seniors")
    }

    @Test("A split across venues is summarised rather than listed")
    func outcomeLineAcrossVenues() {
        let fit = RosterAgeFit(
            [Self.kid("Ana", age: 9), Self.kid("Bo", age: 14)],
            venues: [Self.venue("Juniors", .upTo(11)), Self.venue("Seniors", .from(12))]
        )

        #expect(fit.outcomeLine == "2 go to their venues")
    }

    // MARK: What a commit writes

    /// The band decides where an arrival lands, once. It has no say over a kid already at the camp
    /// — `updatePlayers` is explicit that a file has no opinion about venue, court or rank.
    @Test("Routing a commit touches the arrivals and nothing else")
    func routingTouchesArrivalsOnly() {
        let existing = Player(
            firstName: "Dee", lastInitial: "T", age: 9, gender: .x,
            isReturning: true, overallRank: 1, courtRank: 1
        )
        let commit = RosterReconciliation.Commit(
            inserting: [Self.kid("Ana", age: 14)],
            updating: [existing],
            removing: [UUID()]
        )

        let routed = commit.routed(
            by: [Self.venue("Juniors", .upTo(11)), Self.venue("Seniors", .from(12))]
        )

        #expect(routed.inserting.map(\.venueIndex) == [1])
        #expect(routed.updating == [existing])
        #expect(routed.removing == commit.removing)
    }

    // MARK: `8e`'s line under the chips

    @Test("No note when the chosen venue will have them")
    func noNoteWhenAdmitted() {
        let venues = [Self.venue("Sycamore", .all)]
        #expect(RosterAgeFit.note(forAge: 9, atVenue: 0, among: venues) == nil)
        #expect(RosterAgeFit.note(forAge: nil, atVenue: 0, among: venues) == nil)
    }

    @Test("The note names where they go instead")
    func noteNamesTheTaker() {
        let venues = [Self.venue("Juniors", .upTo(11)), Self.venue("Seniors", .from(12))]
        let note = RosterAgeFit.note(forAge: 14, atVenue: 0, among: venues)

        #expect(note == "Juniors takes 11 & under, so they go to Seniors instead.")
    }

    @Test("The note asks for an age rather than blaming one")
    func noteAsksForAnAge() {
        let venues = [Self.venue("Seniors", .from(12))]
        let note = try? #require(RosterAgeFit.note(forAge: nil, atVenue: 0, among: venues))

        #expect(note == "Seniors takes 12 & up. Add an age, or they join with no group.")
    }

    @Test("An index no chip answers to has no note")
    func noteOutOfRange() {
        #expect(RosterAgeFit.note(forAge: 9, atVenue: 4, among: [Self.venue("A", .from(12))]) == nil)
    }
}

// MARK: - The band survives the trip to the enrolment screens

/// The band was collectable on `8b` and ignored two screens later, because both enrolment screens
/// took it through an optional parameter the onboarding call sites omitted — so it compiled, and
/// silently admitted everybody. These pin the route rather than the rule.
@Suite("Age band — reaching the screens that use it")
struct AgeBandReachesEnrolmentTests {

    private static func kid(_ name: String, age: Int?) -> IntakePlayer {
        IntakePlayer(firstName: name, lastName: "T", age: age, venueIndex: 0)
    }

    @Test("A venue's band survives Venue -> VenueShape")
    func theAdapterCarriesTheBand() {
        for band in [AgeBand.all, .upTo(11), .from(12)] {
            var venue = SampleData.sycamore
            venue.ageBand = band

            #expect(venue.shape.ageBand == band)
            // The two routes the screens actually take — one either side of camp creation.
            #expect(venue.shape.rosterVenue.band == band)
            #expect(venue.rosterVenue.band == band)
        }
    }

    @Test("A shape narrowed on 8b turns a kid away two screens later")
    func aNarrowedShapeIsEnforcedAtEnrolment() {
        var shape = CampShape.initial(venueCount: 1, courts: 4)
        shape.venues[0].ageBand = .from(12)

        // Exactly what `OnboardingFlowView` now hands the enrolment screens.
        let venues = shape.venues.map(\.rosterVenue)
        let fit = RosterAgeFit([Self.kid("Nine", age: 9), Self.kid("Thirteen", age: 13)], venues: venues)

        // Before the fix this venue arrived as `.all`, and the nine-year-old was filed into it in
        // silence — no warning on the chip row, no reroute, no refusal.
        #expect(fit.anyVenueAsks)
        #expect(!fit.isEverybodyPlaced)
        #expect(fit.landings[0].refusal == .outsideTheAges)
        #expect(fit.landings[1].isPlaced)
    }

    @Test("A shape nobody narrowed still admits everybody")
    func anUnnarrowedShapeAdmitsEverybody() {
        let shape = CampShape.initial(venueCount: 2, courts: 4)
        let venues = shape.venues.map(\.rosterVenue)
        let fit = RosterAgeFit([6, 11, 12, 17].map { Self.kid("K\($0)", age: $0) }, venues: venues)

        #expect(!fit.anyVenueAsks)
        #expect(fit.isEverybodyPlaced)
    }
}
