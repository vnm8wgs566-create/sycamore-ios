//
//  GroupsMoveTests.swift
//  SycamoreTests
//
//  The latched move on `8p`: a kid held in the air, and the slot they come down into.
//
//  All three functions here are decided by arithmetic nobody can see. `isNoop` is the sharp one
//  — a drop boundary belongs to two rows at once, so the slot *below* a kid and the slot *above*
//  whoever stands next are the same line, and putting someone back exactly where they were can
//  be spelled either way. Recognising only one of the two spellings costs a write, a reload and
//  a re-render to produce the ladder that was already on screen, and on a bad connection it
//  fails visibly for a gesture that asked for nothing.
//

import CoreGraphics
import Foundation
import Testing
@testable import Sycamore

@Suite("GroupsMove")
struct GroupsMoveTests {

    // MARK: A court, and every place a kid could land in it

    /// Two courts of three, laid out down the list. Each court contributes a slot above every
    /// kid on it plus one at its back, which is the shape `GroupsView` measures at lift time.
    struct Board {
        let venueID = Venue.ID()
        let courtA = Group.ID()
        let courtB = Group.ID()
        let a1 = Player.ID(), a2 = Player.ID(), a3 = Player.ID()
        let b1 = Player.ID(), b2 = Player.ID()

        var slots: [GroupsDropSlot] {
            [
                slot(courtA, above: a1, y: 100, rank: 1),
                slot(courtA, above: a2, y: 160, rank: 2),
                slot(courtA, above: a3, y: 220, rank: 3),
                slot(courtA, above: nil, y: 280, rank: 4),
                slot(courtB, above: b1, y: 360, rank: 5),
                slot(courtB, above: b2, y: 420, rank: 6),
                slot(courtB, above: nil, y: 480, rank: 7),
            ]
        }

        func slot(_ group: Group.ID, above anchor: Player.ID?, y: CGFloat, rank: Int) -> GroupsDropSlot {
            GroupsDropSlot(
                landing: GroupsLanding(groupID: group, venueID: venueID, anchor: anchor),
                y: y,
                rank: rank
            )
        }

        /// A kid lifted off court A. `next` is whoever stands directly below them there.
        func move(
            _ id: Player.ID,
            next: Player.ID?,
            from group: Group.ID? = nil,
            originMidY: CGFloat = 130,
            slots: [GroupsDropSlot]? = nil
        ) -> GroupsMove {
            GroupsMove(
                row: row(id),
                sourceGroupID: group ?? courtA,
                nextRowID: next,
                origin: CGRect(x: 0, y: originMidY - 20, width: 300, height: 40),
                slots: slots ?? self.slots
            )
        }

        func row(_ id: Player.ID) -> PlayerRow {
            PlayerRow(
                id: id,
                player: Player(
                    id: id,
                    firstName: "Kid",
                    lastInitial: "T",
                    age: 12,
                    gender: .x,
                    isReturning: false,
                    venueID: venueID,
                    groupID: courtA,
                    overallRank: 1,
                    courtRank: 1
                ),
                rank: 1,
                isAway: false,
                leavesAt: nil
            )
        }
    }

    // MARK: isNoop

    @Test("The slot above the mover is where they already are")
    func aboveThemselvesIsANoop() {
        let board = Board()
        let move = board.move(board.a2, next: board.a3)

        #expect(move.isNoop(board.slot(board.courtA, above: board.a2, y: 160, rank: 2)))
    }

    /// The other half of the same line. Without `nextRowID` this drop would be committed as a
    /// real move even though it puts the kid back between exactly the same two neighbours.
    @Test("The slot above the next kid down is the same boundary, and also a no-op")
    func belowThemselvesIsANoop() {
        let board = Board()
        let move = board.move(board.a2, next: board.a3)

        #expect(move.isNoop(board.slot(board.courtA, above: board.a3, y: 220, rank: 3)))
    }

    @Test("Any other slot on the same court is a real move")
    func aDifferentSlotIsAMove() {
        let board = Board()
        let move = board.move(board.a2, next: board.a3)

        #expect(!move.isNoop(board.slot(board.courtA, above: board.a1, y: 100, rank: 1)))
        #expect(!move.isNoop(board.slot(board.courtA, above: nil, y: 280, rank: 4)))
    }

    /// When the mover was last on their court, both `nextRowID` and the back-of-court slot's
    /// anchor are nil, and the comparison that handles every other case handles this one too.
    @Test("The back of the court is a no-op for the kid who was already last")
    func backOfCourtIsANoopForTheLastKid() {
        let board = Board()
        let move = board.move(board.a3, next: nil)

        #expect(move.isNoop(board.slot(board.courtA, above: nil, y: 280, rank: 4)))
    }

    @Test("The back of the court is a real move for a kid who was not last")
    func backOfCourtIsAMoveForEveryoneElse() {
        let board = Board()
        let move = board.move(board.a1, next: board.a2)

        #expect(!move.isNoop(board.slot(board.courtA, above: nil, y: 280, rank: 4)))
    }

    /// The group guard runs first, and it has to: a kid moving to a different court is the whole
    /// point of the gesture, and an anchor id says nothing about which court it belongs to.
    @Test("A slot on another court is never a no-op, whatever it is anchored on")
    func anotherCourtIsAlwaysAMove() {
        let board = Board()
        let move = board.move(board.a2, next: board.a3)

        // Same anchors, different court.
        #expect(!move.isNoop(board.slot(board.courtB, above: board.a2, y: 360, rank: 5)))
        #expect(!move.isNoop(board.slot(board.courtB, above: board.a3, y: 420, rank: 6)))
    }

    /// Two nils meeting across a court boundary is the trap: without the group check, the last
    /// kid on court A could not be sent to the back of court B, and the gesture would appear to
    /// do nothing at all.
    @Test("The last kid on one court can still be sent to the back of another")
    func nilAnchorsDoNotMatchAcrossCourts() {
        let board = Board()
        let move = board.move(board.a3, next: nil)

        #expect(!move.isNoop(board.slot(board.courtB, above: nil, y: 480, rank: 7)))
    }

    @Test("Every slot on another court is a move, and exactly two on the mover's own are not")
    func exactlyTwoNoops() {
        let board = Board()
        let move = board.move(board.a2, next: board.a3)

        #expect(board.slots.count { move.isNoop($0) } == 2)
    }

    @Test("A kid alone on a court is already in every place that court offers")
    func aLoneKidHasOneNoop() {
        let board = Board()
        let onlyCourt = Group.ID()
        let slots = [
            board.slot(onlyCourt, above: board.a1, y: 100, rank: 1),
            board.slot(onlyCourt, above: nil, y: 160, rank: 2),
        ]
        let move = board.move(board.a1, next: nil, from: onlyCourt, slots: slots)

        // Above themselves, and the back of the court they are alone on: the same place twice.
        #expect(slots.allSatisfy { move.isNoop($0) })
    }

    // MARK: centre and nearestSlot

    @Test("The card's middle is its lift position plus however far it has travelled")
    func centreFollowsTheTranslation() {
        let board = Board()
        var move = board.move(board.a2, next: board.a3, originMidY: 160)

        #expect(move.centre == 160)

        move.translation = 60
        #expect(move.centre == 220)

        move.translation = -45
        #expect(move.centre == 115)
    }

    /// The drop aims with the middle of the card rather than with the fingertip, because a
    /// fingertip is a worse pointer than the thing it is carrying.
    @Test("Aims at the slot nearest the middle of the carried card")
    func nearestFollowsTheCard() {
        let board = Board()
        var move = board.move(board.a2, next: board.a3, originMidY: 160)

        #expect(move.nearestSlot()?.y == 160)

        // Dragged most of the way to the next boundary, but not past the halfway line.
        move.translation = 25
        #expect(move.nearestSlot()?.y == 160)

        move.translation = 35
        #expect(move.nearestSlot()?.y == 220)

        // All the way down to the other court.
        move.translation = 320
        #expect(move.nearestSlot()?.y == 480)
    }

    @Test("Aims upward as readily as downward")
    func nearestAimsUpward() {
        let board = Board()
        var move = board.move(board.a3, next: nil, originMidY: 220)
        move.translation = -120

        #expect(move.nearestSlot()?.y == 100)
    }

    /// Exactly halfway between two boundaries the card has to pick one, and it picks the one
    /// higher up the list. Left to chance this flickers between two targets on a still finger.
    @Test("A dead-even tie goes to the slot higher up the list")
    func tiesGoUpward() {
        let board = Board()
        var move = board.move(board.a2, next: board.a3, originMidY: 160)
        move.translation = 30  // centre 190, exactly between 160 and 220

        #expect(move.nearestSlot()?.y == 160)
    }

    @Test("With nowhere to land there is no target")
    func noSlotsMeansNoTarget() {
        let board = Board()
        let move = board.move(board.a1, next: board.a2, slots: [])

        #expect(move.nearestSlot() == nil)
    }

    @Test("A single slot wins however far away the card is")
    func oneSlotAlwaysWins() {
        let board = Board()
        let only = board.slot(board.courtA, above: nil, y: 9_000, rank: 1)
        var move = board.move(board.a1, next: nil, slots: [only])
        move.translation = -5_000

        #expect(move.nearestSlot() == only)
    }

    // MARK: lastSlot

    /// Tapping a court's card means "put them at the back of it", so the slot this returns has
    /// to be the back-of-court one — the one with no anchor. If the measured slots ever came out
    /// in another order, a tap would insert the kid somewhere in the middle instead.
    @Test("The last slot in a court is its back-of-court slot")
    func lastSlotIsTheBackOfTheCourt() {
        let board = Board()
        let move = board.move(board.a1, next: board.a2)

        #expect(move.lastSlot(in: board.courtA)?.y == 280)
        #expect(move.lastSlot(in: board.courtA)?.landing.anchor == nil)
        #expect(move.lastSlot(in: board.courtB)?.y == 480)
        #expect(move.lastSlot(in: board.courtB)?.landing.anchor == nil)
    }

    @Test("A court with nothing measured for it has no last slot")
    func lastSlotOfAnUnknownCourt() {
        let board = Board()
        let move = board.move(board.a1, next: board.a2)

        #expect(move.lastSlot(in: Group.ID()) == nil)
    }

    /// The two functions have to agree: tapping the card of the court a kid is already last on
    /// must be recognised as asking for nothing.
    @Test("Tapping the mover's own court is a no-op when they are already last on it")
    func tappingYourOwnCourtWhenLast() {
        let board = Board()
        let move = board.move(board.a3, next: nil)

        let target = move.lastSlot(in: board.courtA)
        #expect(target != nil)
        #expect(target.map { move.isNoop($0) } == true)
    }

    @Test("Tapping the mover's own court is a real move when they are not last")
    func tappingYourOwnCourtWhenNotLast() {
        let board = Board()
        let move = board.move(board.a1, next: board.a2)

        let target = move.lastSlot(in: board.courtA)
        #expect(target.map { move.isNoop($0) } == false)
    }
}
