//
//  GroupsGhostTests.swift
//  SycamoreTests
//
//  `8p`'s travelling ghost: which seat a card opens, and where the top of that seat lands.
//
//  Both halves are decided by arithmetic nobody can see, and the second one is a single line.
//  An off-by-one-row hides very comfortably inside a single line — it looks right on the two
//  slots either side of the kid and is a whole row out at the far end of the list, which is
//  exactly the shape of bug that ships. So the layout is done twice here: once by
//  `GroupsGhost.top`, and once the long way by `Board.relaid(seat:in:moving:height:)`, which
//  re-stacks every box in the list from the top with the mover taken out and a space opened at
//  the seat. The test is that the two agree.
//
//  The sharp one is the pair of no-ops. A boundary belongs to two rows at once, so "above the
//  mover" and "above the next kid down" are the same line said twice — `GroupsMoveTests` checks
//  that both are recognised as asking for nothing, and this file checks that both *draw* in the
//  same place. A rule that put the ghost a row away from the kid it is a ghost of, for a gesture
//  that has asked for nothing, would be the first thing anybody noticed.
//

import CoreGraphics
import Foundation
import Testing
@testable import Sycamore

@Suite("GroupsGhost")
struct GroupsGhostTests {

    // MARK: - A list, laid out the long way

    /// One card in the fixture: everybody the group holds, and how many of them it is drawing.
    struct CardShape {
        let id: Group.ID
        let all: [Player.ID]
        let drawnCount: Int

        var drawn: [Player.ID] { Array(all.prefix(drawnCount)) }
        /// A folded card closes with "+N more".
        var hasMore: Bool { drawnCount < all.count }
        /// The kid directly below the last drawn one, whom a fold may be hiding. This is what
        /// `GroupsView.slots(for:)` anchors its below-the-last-row slot on.
        var following: Player.ID? { all.indices.contains(drawnCount) ? all[drawnCount] : nil }
    }

    /// Two cards down a list: a folded one of four kids drawing three, and a whole one of two.
    ///
    /// The numbers are chosen so the first drawn row starts at 100 and every row is 44 — the
    /// same board the unit's worked example is written against, so a failure can be read off
    /// against a table on paper.
    struct Board {

        let venueID = Venue.ID()
        let courtA = Group.ID(), courtB = Group.ID()
        let a1 = Player.ID(), a2 = Player.ID(), a3 = Player.ID(), a4 = Player.ID()
        let b1 = Player.ID(), b2 = Player.ID()

        /// `HitTarget.minimum` — a 27pt line of type inside a 44pt touch target.
        static let rowHeight: CGFloat = 44
        /// "+N more" is a row like any other.
        static let moreHeight: CGFloat = 44
        /// A card's chrome above its first drawn row: padding, title, band, `rowsGap`, the rule
        /// and `Spacing.tight` under it. Rounded to put the first row on 100.
        static let headerHeight: CGFloat = 86
        /// `Spacing.tight` under the last thing a card draws, inside the card's own edge.
        static let footPadding = Spacing.tight
        /// `GroupsMetrics.cardGap`.
        static let cardGap = GroupsMetrics.cardGap
        /// `GroupsMetrics.listTop`.
        static let listTop = GroupsMetrics.listTop

        var cards: [CardShape] {
            [
                CardShape(id: courtA, all: [a1, a2, a3, a4], drawnCount: 3),
                CardShape(id: courtB, all: [b1, b2], drawnCount: 2),
            ]
        }

        // MARK: The list at rest

        /// Every drawn row's top, every card's below-the-last-row boundary, and every card's
        /// bottom edge — walking the boxes from the top of the list, exactly once.
        ///
        /// Court A: `a1 100, a2 144, a3 188`, below-last `232`, "+1 more" to `276`, foot `282`.
        /// Court B: `b1 377, b2 421`, below-last `465`, foot `471`.
        func layout() -> (rows: [Player.ID: CGFloat], belowLast: [Group.ID: CGFloat], foot: [Group.ID: CGFloat]) {
            var y = Board.listTop
            var rows: [Player.ID: CGFloat] = [:]
            var belowLast: [Group.ID: CGFloat] = [:]
            var foot: [Group.ID: CGFloat] = [:]

            for (index, card) in cards.enumerated() {
                if index > 0 { y += Board.cardGap }
                y += Board.headerHeight
                for row in card.drawn {
                    rows[row] = y
                    y += Board.rowHeight
                }
                belowLast[card.id] = y
                if card.hasMore { y += Board.moreHeight }
                y += Board.footPadding
                foot[card.id] = y
            }
            return (rows, belowLast, foot)
        }

        /// The rectangle a kid's row occupies at rest — what `GroupsMove.origin` captures.
        func origin(of row: Player.ID) -> CGRect {
            CGRect(x: 0, y: layout().rows[row] ?? 0, width: 300, height: Board.rowHeight)
        }

        // MARK: Every place a kid could land in it

        /// What shape of slot this is. Exactly the three `GroupsView.slots(for:)` emits per
        /// card, kept apart here because the card-foot one is a card *edge* rather than a row
        /// boundary and is the one place the arithmetic deliberately parks low.
        enum Kind { case aboveDrawnRow, belowLastRow, cardFoot }

        struct Measured {
            let slot: GroupsDropSlot
            let kind: Kind
        }

        /// The slot array `beginMove` would capture off this board.
        var measured: [Measured] {
            let layout = layout()
            var measured: [Measured] = []

            for card in cards {
                for row in card.drawn {
                    measured.append(Measured(
                        slot: slot(card.id, above: row, y: layout.rows[row] ?? 0),
                        kind: .aboveDrawnRow
                    ))
                }
                measured.append(Measured(
                    slot: slot(card.id, above: card.following, y: layout.belowLast[card.id] ?? 0),
                    kind: .belowLastRow
                ))
                measured.append(Measured(
                    slot: slot(card.id, above: nil, y: layout.foot[card.id] ?? 0),
                    kind: .cardFoot
                ))
            }
            return measured
        }

        var slots: [GroupsDropSlot] { measured.map(\.slot) }

        /// Every kid a finger could pick up — the drawn ones. A kid a fold is hiding has no
        /// handle on screen to lift them by.
        var liftable: [Player.ID] { cards.flatMap(\.drawn) }

        func slot(_ group: Group.ID, above anchor: Player.ID?, y: CGFloat, rank: Int = 1) -> GroupsDropSlot {
            GroupsDropSlot(
                landing: GroupsLanding(groupID: group, venueID: venueID, anchor: anchor),
                y: y,
                rank: rank
            )
        }

        func drawnRows(in group: Group.ID) -> [PlayerRow] {
            (cards.first { $0.id == group }?.drawn ?? []).map { row($0, in: group) }
        }

        func row(_ id: Player.ID, in group: Group.ID? = nil) -> PlayerRow {
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
                    groupID: group ?? courtA,
                    overallRank: 1,
                    courtRank: 1
                ),
                rank: 1,
                isAway: false,
                leavesAt: nil
            )
        }

        // MARK: The list, laid out again

        /// The same board re-stacked from the top of the list with the mover taken out of it and
        /// a space of `height` opened at `seat`. Returns that space's top edge.
        ///
        /// This is the second opinion, and it is arrived at differently on purpose: it adds up
        /// every box in the list rather than adjusting one boundary, and it never mentions
        /// `origin.maxY`. The mover is skipped where they stand, which is precisely what
        /// `GroupCard.rowView(_:)`'s negative bottom padding does — the row keeps its place in
        /// the tree, because it owns the live gesture, and gives up only its space.
        func relaid(
            seat: GroupsGhost.Seat,
            in cardID: Group.ID,
            moving mover: Player.ID,
            height: CGFloat
        ) -> CGFloat? {
            var y = Board.listTop
            var gapTop: CGFloat?

            for (index, card) in cards.enumerated() {
                if index > 0 { y += Board.cardGap }
                y += Board.headerHeight

                let opens = card.id == cardID
                for row in card.drawn {
                    if opens, seat == .above(row) {
                        gapTop = y
                        y += height
                    }
                    guard row != mover else { continue }
                    y += Board.rowHeight
                }
                if opens, seat == .belowLastRow {
                    gapTop = y
                    y += height
                }
                if card.hasMore { y += Board.moreHeight }
                if opens, seat == .backOfCard {
                    gapTop = y
                    y += height
                }
                y += Board.footPadding
            }
            return gapTop
        }
    }

    // MARK: - The worked example

    /// The table this unit was designed against, checked a number at a time.
    ///
    /// Rows of 44 at `a1[100,144) a2[144,188) a3[188,232)`, a card foot at 238, and `a2` lifted
    /// — so `origin` is `[144,188)` and `H` is 44.
    @Test("Every slot on a three-row card, against the table on paper")
    func theWorkedExample() {
        let board = Board()
        let origin = CGRect(x: 0, y: 144, width: 300, height: 44)
        func top(_ y: CGFloat) -> CGFloat {
            GroupsGhost.top(of: board.slot(board.courtA, above: nil, y: y), lifted: origin)
        }

        #expect(top(100) == 100)  // above a1 — untouched, it is above the mover
        #expect(top(144) == 144)  // above a2, the mover themselves: put them back
        #expect(top(188) == 144)  // above a3: the same boundary, the same place
        #expect(top(232) == 188)  // below the last row: a row height up
        #expect(top(238) == 194)  // the card's own foot, likewise
    }

    // MARK: - The two ways of asking for nothing

    /// The pixel twin of `GroupsMove.isNoop`. A boundary belongs to two rows, so putting a kid
    /// back exactly where they were can be spelled either "above themselves" or "above whoever
    /// stands next" — and both have to draw the ghost on the row the kid is standing in.
    @Test("Both spellings of putting a kid back land on the row they were lifted from")
    func bothNoopSpellingsAgree() {
        let board = Board()

        for mover in board.liftable {
            let origin = board.origin(of: mover)
            let aboveSelf = board.slot(board.courtA, above: mover, y: origin.minY)
            let aboveTheNextKidDown = board.slot(board.courtA, above: nil, y: origin.maxY)

            #expect(GroupsGhost.top(of: aboveSelf, lifted: origin) == origin.minY)
            #expect(GroupsGhost.top(of: aboveTheNextKidDown, lifted: origin) == origin.minY)
        }
    }

    // MARK: - Above and below

    @Test("A slot below the mover rises by exactly one row height")
    func belowRisesByARow() {
        let board = Board()
        let origin = board.origin(of: board.a1)

        let belowLast = board.slot(board.courtA, above: board.a4, y: 232)
        #expect(GroupsGhost.top(of: belowLast, lifted: origin) == 232 - Board.rowHeight)

        let otherCard = board.slot(board.courtB, above: board.b2, y: 421)
        #expect(GroupsGhost.top(of: otherCard, lifted: origin) == 421 - Board.rowHeight)
    }

    @Test("A slot above the mover is left exactly where it was measured")
    func aboveIsUntouched() {
        let board = Board()
        let origin = board.origin(of: board.a3)

        for y in [CGFloat(100), 144, 188] {
            let slot = board.slot(board.courtA, above: board.a1, y: y)
            #expect(GroupsGhost.top(of: slot, lifted: origin) == y)
        }
    }

    /// The boundary between the two cases is the mover's *foot*, not their head — it is the
    /// removal of the whole row that lifts what is below it. On the real slot set nothing lands
    /// strictly inside a row, because a row's interior holds no boundary; if one ever did, this
    /// is the answer it gets, and it is the safe one: the ghost can never be placed higher than
    /// the top of the card it belongs to.
    @Test("A y strictly inside the lifted row resolves as above it, not below")
    func insideTheLiftedRowResolvesAsAbove() {
        let board = Board()
        let origin = board.origin(of: board.a2)
        let inside = board.slot(board.courtA, above: board.a2, y: origin.midY)

        #expect(GroupsGhost.top(of: inside, lifted: origin) == origin.midY)
    }

    // MARK: - Across two cards

    /// Downward: a kid off the first card aimed into the second. Everything below the source
    /// rises by a row — the rows under them inside their own card, the card itself, and every
    /// card after it — which is why there is no branch on group in the rule.
    @Test("A kid moving down the list opens a space one row above the frozen boundary")
    func downwardAcrossCards() {
        let board = Board()
        let origin = board.origin(of: board.a2)

        #expect(GroupsGhost.top(of: board.slot(board.courtB, above: board.b1, y: 377), lifted: origin) == 333)
        #expect(GroupsGhost.top(of: board.slot(board.courtB, above: board.b2, y: 421), lifted: origin) == 377)
    }

    /// Upward: a kid off the second card aimed into the first. Nothing above them has moved, so
    /// every slot in the card they are aiming at is exactly where it was measured.
    @Test("A kid moving up the list opens a space precisely on the frozen boundary")
    func upwardAcrossCards() {
        let board = Board()
        let origin = board.origin(of: board.b1)

        #expect(GroupsGhost.top(of: board.slot(board.courtA, above: board.a1, y: 100), lifted: origin) == 100)
        #expect(GroupsGhost.top(of: board.slot(board.courtA, above: board.a4, y: 232), lifted: origin) == 232)
    }

    // MARK: - The arithmetic against the layout

    /// Every kid on the board lifted in turn, against every row boundary on it, checked against
    /// a layout done from scratch. This is the test the one-line rule is actually held to.
    @Test("Every row boundary opens where the arithmetic says it will, for every kid")
    func theArithmeticAgreesWithTheLayout() {
        let board = Board()

        for mover in board.liftable {
            let origin = board.origin(of: mover)

            for measured in board.measured where measured.kind != .cardFoot {
                let slot = measured.slot
                guard let seat = GroupsGhost.seat(
                    aimedAt: slot,
                    card: slot.groupID,
                    drawnRows: board.drawnRows(in: slot.groupID)
                ) else {
                    Issue.record("every slot on the board seats somewhere in its own card")
                    continue
                }

                let relaid = board.relaid(
                    seat: seat,
                    in: slot.groupID,
                    moving: mover,
                    height: origin.height
                )
                #expect(GroupsGhost.top(of: slot, lifted: origin) == relaid)
            }
        }
    }

    /// The one deliberate divergence, pinned to its exact size so it cannot drift.
    ///
    /// A card-foot slot's y is the card's own bottom edge, which is `Spacing.tight` below the
    /// line the space opens at. It is left that way because that y is what the kid *aims* with,
    /// and the card-foot slot is what tapping a card means — "somewhere at the back of this
    /// one", a request in which six points of parking is not the thing being asked about. The
    /// ghost is unaffected either way: it is placed by layout, at the back of the card's real
    /// stack, and never from this number.
    @Test("The card-foot slot parks exactly Spacing.tight below where the space opens")
    func theCardFootSlotParksLow() {
        let board = Board()

        for mover in board.liftable {
            let origin = board.origin(of: mover)

            for measured in board.measured where measured.kind == .cardFoot {
                let slot = measured.slot
                let relaid = board.relaid(
                    seat: .backOfCard,
                    in: slot.groupID,
                    moving: mover,
                    height: origin.height
                )
                #expect(GroupsGhost.top(of: slot, lifted: origin) == relaid.map { $0 + Board.footPadding })
            }
        }
    }

    // MARK: - Seats

    @Test("A card with nobody aimed at it seats nothing")
    func noTargetSeatsNothing() {
        let board = Board()

        #expect(GroupsGhost.seat(
            aimedAt: nil,
            card: board.courtA,
            drawnRows: board.drawnRows(in: board.courtA)
        ) == nil)
    }

    @Test("A card seats nothing while the kid is aimed at another one")
    func anotherCardsTargetSeatsNothing() {
        let board = Board()
        let elsewhere = board.slot(board.courtB, above: board.b1, y: 377)

        #expect(GroupsGhost.seat(
            aimedAt: elsewhere,
            card: board.courtA,
            drawnRows: board.drawnRows(in: board.courtA)
        ) == nil)
    }

    @Test("An anchor the card is drawing seats the space directly above that row")
    func aDrawnAnchorSeatsAboveItsRow() {
        let board = Board()
        let drawn = board.drawnRows(in: board.courtA)

        for row in drawn {
            let slot = board.slot(board.courtA, above: row.id, y: 0)
            #expect(GroupsGhost.seat(aimedAt: slot, card: board.courtA, drawnRows: drawn) == .above(row.id))
        }
    }

    /// The fourth kid on a folded card has no row of their own on screen, so "directly above
    /// them" can only be drawn as "under the last row this card is drawing".
    @Test("An anchor a fold is hiding seats the space under the last drawn row")
    func anUndrawnAnchorSeatsBelowTheLastDrawnRow() {
        let board = Board()
        let slot = board.slot(board.courtA, above: board.a4, y: 232)

        #expect(GroupsGhost.seat(
            aimedAt: slot,
            card: board.courtA,
            drawnRows: board.drawnRows(in: board.courtA)
        ) == .belowLastRow)
    }

    @Test("No anchor at all seats the space at the back of the card")
    func noAnchorSeatsTheBackOfTheCard() {
        let board = Board()
        let slot = board.slot(board.courtA, above: nil, y: 282)

        #expect(GroupsGhost.seat(
            aimedAt: slot,
            card: board.courtA,
            drawnRows: board.drawnRows(in: board.courtA)
        ) == .backOfCard)
    }

    /// The mover's own row is a legal anchor and has to be — it is the very first target
    /// `GroupsView.beginMove` builds, so that the first frame of a lift is not a screen with a
    /// bar and nothing aimed at.
    @Test("The mover's own row seats the space above the row they were lifted from")
    func theMoversOwnRowIsALegalAnchor() {
        let board = Board()
        let slot = board.slot(board.courtA, above: board.a2, y: 144)

        #expect(GroupsGhost.seat(
            aimedAt: slot,
            card: board.courtA,
            drawnRows: board.drawnRows(in: board.courtA)
        ) == .above(board.a2))
    }

    /// A group folded to its header, or searched down to nothing, still has to be somewhere a
    /// kid can be put — `GroupsView.slots(for:)` emits a card-foot slot for it whatever else it
    /// does. `GroupCard` grows a rows section around the ghost when this happens.
    @Test("A card drawing no kids at all still seats a ghost")
    func aCardDrawingNothingStillSeatsAGhost() {
        let board = Board()
        let slot = board.slot(board.courtA, above: nil, y: 200)

        #expect(GroupsGhost.seat(aimedAt: slot, card: board.courtA, drawnRows: []) == .backOfCard)
    }
}
