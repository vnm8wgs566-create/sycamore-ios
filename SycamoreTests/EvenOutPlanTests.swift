//
//  EvenOutPlanTests.swift
//  SycamoreTests
//
//  The "Even out the groups?" preview, which is the one screen in the app whose entire job is to
//  be right about something that has not happened yet.
//
//  Everything here is really one assertion made four ways: **the preview and the button agree**.
//  `EvenOutPlan` buys that by running the repository's own mutation against a copy of the camp
//  rather than re-deriving the split, so these tests check the two things that could still come
//  apart — the sizes it reports, and the count of children it says will move, which is not the
//  same number as "how much the sizes changed" and is the one in the button's label.
//
//  The third case is the one that would crash a hand-written split: fewer kids than courts, where
//  the share is zero and the remainder is everybody.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("EvenOutPlan")
struct EvenOutPlanTests {

    // MARK: Already level

    @Test("A venue that is already even reports no moves")
    func evenVenueMovesNobody() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 32)
        camp.evenOut()

        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.moves == 0)
        #expect(plan.isNoOp)
        #expect(plan.rows.map(\.from) == [8, 8, 8, 8])
        #expect(plan.rows.map(\.to) == [8, 8, 8, 8])
        // Hoisted rather than written inside `#expect`. The macro decomposes a function call into
        // a generic closure, which turns `allSatisfy`'s `rethrows` into a throwing call it then
        // refuses to make without a `try`. A plain `Bool` has nothing to decompose.
        let allUnchanged = plan.rows.allSatisfy(\.isUnchanged)
        #expect(allUnchanged)
    }

    /// Levelling a venue and then levelling it again must be a no-op, or the sheet would offer a
    /// button that does nothing every time it is opened after a successful press.
    @Test("Running the deal twice changes nothing the second time")
    func secondPassIsStable() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 5)], players: 23)
        let venue = try #require(camp.orderedVenues.first)

        camp.redistribute(in: venue.id)
        camp.reindex()

        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))
        #expect(plan.moves == 0)
    }

    // MARK: Lopsided

    /// The fixture parks every kid on court 1, which is the most lopsided a venue can be. The split
    /// has to land within one of itself, with the leftovers on the courts that come first — the
    /// promise `Camp.deal(_:across:)` makes and the only thing this sheet is previewing.
    @Test("A lopsided venue previews the ±1 split, leftovers first")
    func lopsidedVenueSplitsWithinOne() throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 30)
        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.rows.map(\.from) == [30, 0, 0, 0])
        #expect(plan.rows.map(\.to) == [8, 8, 7, 7])

        // Everybody except the eight who were already at the top of court 1.
        #expect(plan.moves == 22)
        #expect(!plan.isNoOp)
    }

    /// A court can keep its size and still change hands. This is the case a preview built from
    /// `from`/`to` alone would report as zero moves while the button re-seated half the venue.
    @Test("Moves count children, not the change in the sizes")
    func movesCountChildrenNotSizes() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        let venue = try #require(camp.orderedVenues.first)
        let courts = camp.groups(in: venue.id)

        // Two apiece, but the wrong two: the ladder's 1st and 3rd on one court, 2nd and 4th on the
        // other. The sizes are already level and every child is on the wrong side of the split.
        for index in camp.players.indices {
            camp.players[index].groupID = camp.players[index].overallRank % 2 == 1
                ? courts[0].id : courts[1].id
        }
        camp.reindex()

        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.rows.map(\.from) == [2, 2])
        #expect(plan.rows.map(\.to) == [2, 2])
        let allUnchanged = plan.rows.allSatisfy(\.isUnchanged)
        #expect(allUnchanged)
        // Ranks 2 and 3 swap courts; 1 and 4 are already where the deal wants them.
        #expect(plan.moves == 2)
        #expect(!plan.isNoOp)
    }

    /// An import leaves `groupID` nil on purpose, so "even out" is often what first places those
    /// kids. They have to count, or the button reads `0 moves` on the venue it does the most for.
    @Test("A kid with no court counts as a move")
    func unassignedKidsCountAsMoves() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 6)
        let venue = try #require(camp.orderedVenues.first)

        camp.evenOut()
        // Two kids taken off their courts, still at the venue — the shape `importPlayers` leaves.
        for index in camp.players.indices.prefix(2) { camp.players[index].groupID = nil }
        camp.reindex()

        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.rows.map(\.to) == [3, 3])
        #expect(plan.moves >= 2)
    }

    // MARK: Fewer kids than courts

    /// `base` is 0 and the remainder is everybody. A venue that cannot fill its courts ends with
    /// empty ones rather than a crash — and the preview says so, which is the point: an empty
    /// group is a real answer and a coach standing on that court needs to see it coming.
    @Test("Fewer kids than groups leaves empty groups rather than crashing")
    func fewerKidsThanGroups() throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 5)], players: 3)
        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.rows.count == 5)
        #expect(plan.rows.map(\.to) == [1, 1, 1, 0, 0])
        // The top of the ladder is already on court 1; the other two walk.
        #expect(plan.moves == 2)
    }

    @Test("A venue with no kids at all previews five empty groups and no moves")
    func noKidsAtAll() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2), .init("LATC", courts: 3)], players: 8)
        let empty = try #require(camp.orderedVenues.last)
        camp.reindex()

        let plan = try #require(EvenOutPlan(camp: camp, venueID: empty.id))

        #expect(plan.rows.map(\.to) == [0, 0, 0])
        #expect(plan.moves == 0)
        #expect(plan.isNoOp)
    }

    @Test("A venue with no courts previews nothing and does not crash")
    func noCourtsAtAll() throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 4), .init("Overflow", courts: 0)], players: 10)
        let bare = try #require(camp.orderedVenues.last)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: bare.id))

        #expect(plan.rows.isEmpty)
        #expect(plan.moves == 0)
        #expect(plan.contextLine == "Overflow")
    }

    @Test("An id no venue answers to has no plan")
    func unknownVenue() {
        let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 10)
        #expect(EvenOutPlan(camp: camp, venueID: UUID()) == nil)
    }

    // MARK: The copy

    @Test("The context line names the venue and its sizes today")
    func contextLineReadsAsTheDesignDraws() throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 30)
        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.contextLine == "Sycamore · 30 · 0 · 0 · 0")
        #expect(plan.rows.map(\.title) == ["Group 1", "Group 2", "Group 3", "Group 4"])
    }

    @Test("One move is singular in both the line and the button")
    func singularCopy() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        let venue = try #require(camp.orderedVenues.first)
        camp.evenOut()

        // One kid lifted off a court: exactly one child has somewhere to go.
        let strayIndex = try #require(camp.players.indices.last)
        camp.players[strayIndex].groupID = nil
        camp.reindex()

        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.moves == 1)
        #expect(plan.movesLine == "1 kid moves.")
        #expect(plan.ctaTitle == "Even out · 1 move")
    }

    @Test("Several moves are plural in both")
    func pluralCopy() throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 30)
        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.movesLine == "22 kids move.")
        #expect(plan.ctaTitle == "Even out · 22 moves")
    }

    /// VoiceOver gets the sentence the layout gives a sighted reader, not three loose numerals.
    @Test("Each row reads as one phrase")
    func rowsReadAsOnePhrase() throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 30)
        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.rows[0].accessibilityPhrase == "Group 1, 30 kids, becomes 8")
        #expect(plan.rows[1].accessibilityPhrase == "Group 2, 0 kids, becomes 8")
    }

    @Test("An unchanged group says it stays rather than that it becomes")
    func unchangedRowPhrase() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 32)
        camp.evenOut()

        let venue = try #require(camp.orderedVenues.first)
        let plan = try #require(EvenOutPlan(camp: camp, venueID: venue.id))

        #expect(plan.rows[0].accessibilityPhrase == "Group 1, stays at 8 kids")
    }

    // MARK: What it must not touch

    /// The whole promise of a venue-scoped even-out: the venue next door is not rearranged as a
    /// side effect of levelling this one.
    @Test("The preview is about one venue and reads only its courts")
    func oneVenueOnly() throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 3), .init("LATC", courts: 2)], players: 20)
        let venues = camp.orderedVenues
        let home = try #require(venues.first)
        let other = try #require(venues.last)

        // Half the camp moved next door, all onto its first court.
        let neighbourCourt = try #require(camp.groups(in: other.id).first)
        for index in camp.players.indices.suffix(10) {
            camp.players[index].venueID = other.id
            camp.players[index].groupID = neighbourCourt.id
        }
        camp.reindex()

        let plan = try #require(EvenOutPlan(camp: camp, venueID: home.id))

        #expect(plan.rows.count == 3)
        #expect(plan.courtIDs == camp.groups(in: home.id).map(\.id))
        #expect(plan.rows.map(\.to) == [4, 3, 3])
        #expect(plan.venueName == "Sycamore")
    }
}
