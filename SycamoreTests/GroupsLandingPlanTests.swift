//
//  GroupsLandingPlanTests.swift
//  SycamoreTests
//
//  Where a dragged child actually lands.
//
//  This is the highest-consequence arithmetic in the app and the least visible: it decides a
//  child's place in the camp ladder and on their court, and every way it can be wrong looks
//  right. The kid appears on a card, the card has a number on it, nothing throws. Only the
//  person who made the drag knows the answer, and they are standing on a court.
//
//  The insertion index is the sharp part. The mover is taken out of every venue's ladder before
//  the anchor is looked up, which is what keeps the arithmetic to one step — every row below
//  them has already shifted up, so the anchor's index *is* the insertion point. Do the removal
//  after the lookup instead and every downward move lands one row short.
//

import CoreGraphics
import Foundation
import Testing
@testable import Sycamore

/// Only the id and the overall rank are read here; where the kid stands is said by the ladder
/// and the roster, not by the record.
private func kid(_ name: String, rank: Int) -> Player {
    Player(
        firstName: name, lastInitial: "T", age: 12, gender: .x, isReturning: false,
        venueID: nil, groupID: nil, overallRank: rank, courtRank: rank
    )
}

@Suite("GroupsLandingPlan")
struct GroupsLandingPlanTests {

    /// One venue, five kids ranked 1…5, split over two courts. Court 1 holds A, C and E, which
    /// is deliberately not a clean block of the ladder — courts are not rank blocks, and an
    /// arithmetic that only works when they are would pass on a tidier fixture.
    struct Board {
        let venue = Venue.ID()
        let otherVenue = Venue.ID()
        let courtOne = Group.ID()
        let courtTwo = Group.ID()
        let emptyCourt = Group.ID()

        let a = kid("A", rank: 1)
        let b = kid("B", rank: 2)
        let c = kid("C", rank: 3)
        let d = kid("D", rank: 4)
        let e = kid("E", rank: 5)

        var ladder: [RankAssignment] {
            [RankAssignment(venueID: venue, playerIDs: [a.id, b.id, c.id, d.id, e.id])]
        }

        var courtOneRoster: [Player] { [a, c, e] }
        var courtTwoRoster: [Player] { [b, d] }

        func landing(_ court: Group.ID, above anchor: Player.ID?, venue: Venue.ID? = nil) -> GroupsLanding {
            GroupsLanding(groupID: court, venueID: venue ?? self.venue, anchor: anchor)
        }

        /// The ladder as names, so a failure reads as an order rather than as UUIDs.
        func names(_ ids: [Player.ID]) -> [String] {
            let byID = Dictionary(uniqueKeysWithValues: [a, b, c, d, e].map { ($0.id, $0.firstName) })
            return ids.map { byID[$0] ?? "?" }
        }
    }

    // MARK: Inside one court

    @Test("Landing above a kid puts the mover directly above them")
    func landsAboveTheAnchor() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtOne, above: board.e.id),
                ladder: board.ladder,
                roster: board.courtOneRoster
            )
        )

        #expect(board.names(plan.assignments[0].playerIDs) == ["B", "C", "D", "A", "E"])
    }

    /// The off-by-one the removal-first ordering exists to prevent. Moving down past two rows has
    /// to clear both of them; doing the lookup before the removal lands the mover above D instead
    /// of below it, which is a move of one row when two were asked for.
    @Test("Moving down clears every row it was dragged past")
    func movingDownClearsThePassedRows() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.b.id,
                to: board.landing(board.courtTwo, above: nil),
                ladder: board.ladder,
                roster: board.courtTwoRoster
            )
        )

        // Court two is B and D; sending B to its back means landing behind D.
        #expect(board.names(plan.assignments[0].playerIDs) == ["A", "C", "D", "B", "E"])
    }

    @Test("Moving up lands above the kid that was passed")
    func movingUp() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.e.id,
                to: board.landing(board.courtOne, above: board.c.id),
                ladder: board.ladder,
                roster: board.courtOneRoster
            )
        )

        #expect(board.names(plan.assignments[0].playerIDs) == ["A", "B", "E", "C", "D"])
    }

    /// "The back of the court" is one past the court's own lowest-ranked kid, not the bottom of
    /// the venue. Court one ends at E, who happens to be last in the venue too; court two ends at
    /// D, who is not — and that is the case that tells the two rules apart.
    @Test("The back of a court is behind that court's last kid, not the venue's")
    func backOfCourtIsNotBackOfVenue() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtTwo, above: nil),
                ladder: board.ladder,
                roster: board.courtTwoRoster
            )
        )

        // Behind D, not behind E.
        #expect(board.names(plan.assignments[0].playerIDs) == ["B", "C", "D", "A", "E"])
    }

    @Test("The back of the mover's own court is behind whoever is left on it")
    func backOfTheirOwnCourt() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtOne, above: nil),
                ladder: board.ladder,
                roster: board.courtOneRoster
            )
        )

        // Court one keeps C and E; behind E is the end of the venue.
        #expect(board.names(plan.assignments[0].playerIDs) == ["B", "C", "D", "E", "A"])
    }

    /// An empty court has no place of its own in the ladder yet, and the back of the venue is the
    /// only answer that does not invent one.
    @Test("An empty court sends the mover to the back of the venue")
    func anEmptyCourt() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.emptyCourt, above: nil),
                ladder: board.ladder,
                roster: []
            )
        )

        #expect(board.names(plan.assignments[0].playerIDs) == ["B", "C", "D", "E", "A"])
        #expect(board.names(plan.courtOrder) == ["A"])
    }

    @Test("A court of one is left holding just the mover")
    func aCourtOfOne() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.emptyCourt, above: nil),
                ladder: board.ladder,
                roster: [board.a]
            )
        )

        #expect(board.names(plan.courtOrder) == ["A"])
    }

    @Test("Landing above whoever follows in the ladder leaves the ladder unchanged")
    func landingAboveTheNextInTheLadder() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtTwo, above: board.b.id),
                ladder: board.ladder,
                roster: board.courtTwoRoster
            )
        )

        #expect(plan.assignments[0].playerIDs == board.ladder[0].playerIDs)
    }

    /// The anchor is looked up *after* the mover has been taken out, so an anchor that is the
    /// mover has no index to find and the fallback sends them to the back of the venue.
    ///
    /// That slot is real — it is the boundary above the mover's own row, and it is the slot a
    /// finger that has not moved is nearest to. `GroupsMove.isNoop` is therefore a correctness
    /// guard rather than a saved round trip: without it, picking a kid up and putting them
    /// straight back down would drop them to the bottom of the venue.
    @Test("Anchoring on the mover has no index left to find — which is what isNoop guards")
    func anchoringOnTheMoverFallsToTheBack() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtOne, above: board.a.id),
                ladder: board.ladder,
                roster: board.courtOneRoster
            )
        )

        #expect(board.names(plan.assignments[0].playerIDs) == ["B", "C", "D", "E", "A"])

        // The guard that means this is never reached.
        let move = GroupsMove(
            row: PlayerRow(id: board.a.id, player: board.a, rank: 1, isAway: false, leavesAt: nil),
            sourceGroupID: board.courtOne,
            nextRowID: board.c.id,
            origin: .zero,
            slots: []
        )
        #expect(move.isNoop(GroupsDropSlot(
            landing: board.landing(board.courtOne, above: board.a.id), y: 0, rank: 1
        )))
    }

    // MARK: Across a venue rule

    @Test("A kid dropped in another venue leaves the one they came from")
    func crossesAVenueRule() throws {
        let board = Board()
        let f = Player(
            firstName: "F", lastInitial: "T", age: 12, gender: .x, isReturning: false,
            venueID: board.otherVenue, groupID: board.emptyCourt, overallRank: 6, courtRank: 1
        )
        let ladder = [
            RankAssignment(venueID: board.venue, playerIDs: [board.a.id, board.b.id, board.c.id]),
            RankAssignment(venueID: board.otherVenue, playerIDs: [f.id]),
        ]

        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.emptyCourt, above: f.id, venue: board.otherVenue),
                ladder: ladder,
                roster: [f]
            )
        )

        #expect(plan.assignments[0].playerIDs == [board.b.id, board.c.id])
        #expect(plan.assignments[1].playerIDs == [board.a.id, f.id])
    }

    /// The removal runs over *every* venue, not just the one being landed in. A kid who somehow
    /// appears in two venues' ladders — a projection that has not caught up, a reload that
    /// crossed a write — must not come out of this appearing in three places.
    @Test("The mover is taken out of every venue before being put back once")
    func removedFromEveryVenue() throws {
        let board = Board()
        let ladder = [
            RankAssignment(venueID: board.venue, playerIDs: [board.a.id, board.b.id]),
            RankAssignment(venueID: board.otherVenue, playerIDs: [board.a.id, board.c.id]),
        ]

        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtTwo, above: board.c.id, venue: board.otherVenue),
                ladder: ladder,
                roster: [board.c]
            )
        )

        let everywhere = plan.assignments.flatMap(\.playerIDs)
        #expect(everywhere.count { $0 == board.a.id } == 1)
        #expect(plan.assignments[0].playerIDs == [board.b.id])
        #expect(plan.assignments[1].playerIDs == [board.a.id, board.c.id])
    }

    @Test("A landing in a venue the ladder does not have is not written")
    func anUnknownVenueIsNotWritten() {
        let board = Board()

        #expect(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtOne, above: nil, venue: Venue.ID()),
                ladder: board.ladder,
                roster: board.courtOneRoster
            ) == nil
        )
    }

    // MARK: The court's own order

    /// The court order is filtered out of the ladder rather than authored, so the two cannot
    /// disagree — which matters because they are written by two separate calls, and a screen that
    /// reloads between them would show a card whose numbers contradict the ladder above it.
    @Test("The court order is read back off the ladder that was just built")
    func courtOrderFollowsTheLadder() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtOne, above: nil),
                ladder: board.ladder,
                roster: board.courtOneRoster
            )
        )

        let ladder = plan.assignments[0].playerIDs
        #expect(board.names(plan.courtOrder) == ["C", "E", "A"])
        // Same relative order as the ladder, with nobody added or dropped.
        #expect(plan.courtOrder == ladder.filter { plan.courtOrder.contains($0) })
    }

    @Test("The court order is exactly that court's kids plus the mover")
    func courtOrderIsTheWholeCourt() throws {
        let board = Board()
        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtTwo, above: board.d.id),
                ladder: board.ladder,
                roster: board.courtTwoRoster
            )
        )

        #expect(Set(plan.courtOrder) == Set([board.a.id, board.b.id, board.d.id]))
        #expect(board.names(plan.courtOrder) == ["B", "A", "D"])
    }

    /// Nobody may be lost and nobody duplicated, whichever way the drop went. This is the
    /// invariant that a wrong index breaks loudest and a screen shows least.
    @Test("Nobody is lost or duplicated, wherever the kid is put down", arguments: [0, 1, 2, 3])
    func theLadderKeepsEveryone(_ choice: Int) throws {
        let board = Board()
        let anchors: [Player.ID?] = [board.c.id, board.e.id, nil, board.a.id]
        let before = board.ladder[0].playerIDs

        let plan = try #require(
            GroupsLandingPlan(
                moving: board.a.id,
                to: board.landing(board.courtOne, above: anchors[choice]),
                ladder: board.ladder,
                roster: board.courtOneRoster
            )
        )

        let after = plan.assignments[0].playerIDs
        #expect(after.count == before.count)
        #expect(Set(after) == Set(before))
    }
}
