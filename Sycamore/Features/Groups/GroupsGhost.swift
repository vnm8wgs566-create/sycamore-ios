//
//  GroupsGhost.swift
//  Sycamore
//
//  `8p` — the greyed kid that travels to wherever they would land, and the space that opens
//  under them.
//
//  The screen used to answer "where is this kid going" with a dot and a rule drawn between two
//  rows. It answers it by showing the kid instead: their row, greyed, sitting in a space the
//  list has genuinely opened for it. The rows above and below shift to make room, and the row
//  they were lifted from gives its space up — so a card a kid leaves closes by one row and a
//  card they are aimed at opens by one, which is the part a drawn indicator could never say.
//
//  Two pieces live here, and both are pure:
//
//  * `seat` — *which* of a card's drawn rows the space opens above, said in the card's own
//    terms so `GroupCard` can put a real row in its real stack.
//  * `top` — *where* that space's top edge lands, in the list's coordinate space.
//
//  They are two answers to one question, and that is deliberate. The layout is the thing the
//  reader sees; the arithmetic is the model of it, and the only place the model is actually
//  evaluated at runtime is `GroupsView.aim(at:)`, which parks the carried card on the space.
//  An overlay ghost drawn at `top` over a separately-opened spacer would be two things that
//  must agree pixel-for-pixel across Dynamic Type, a folded card and the "+N more" row — and
//  any disagreement shows as the ghost sitting beside its own hole. So `GroupsGhostTests`
//  computes the layout the long way and asserts it comes out where `top` says it does.
//
//  In its own file, with no SwiftUI in it, for the reason `GroupsLandingPlan` is: this is
//  arithmetic that decides where a dragged kid appears to land, it needs neither the store, the
//  environment nor the main actor, and all three stood between the last such arithmetic and a
//  test.
//

import CoreGraphics
import Foundation

enum GroupsGhost {

    // MARK: - Where the space opens

    /// Where the space opens among a card's *drawn* rows.
    ///
    /// Said in drawn-row terms rather than in points, because `GroupCard` opens the space by
    /// putting a real row of the mover's height into its real stack — see `GroupCard.ghost(_:)`
    /// for why an `.offset` cannot do that job.
    enum Seat: Equatable, Hashable {
        /// Directly above this drawn row.
        case above(Player.ID)
        /// Under the last drawn row, above "+N more".
        case belowLastRow
        /// Under everything the card draws, "+N more" included.
        case backOfCard
    }

    /// Which seat this card should open, or nil if the kid is not aimed at this card at all.
    ///
    /// Total over every slot `GroupsView.slots(for:)` can produce, and exhaustive by
    /// construction rather than by a default case. A card emits exactly three shapes of slot:
    /// one per drawn row, anchored on that row; one below the last drawn row, anchored on
    /// whoever the group holds *next* — a kid a fold may be hiding, or nil when the drawn rows
    /// run to the end of the group; and one at the card's foot, anchored on nobody. So an
    /// anchor is either drawn, or not drawn, or absent, and those are the three cases below.
    ///
    /// `backOfCard` sits **below** "+N more" on purpose. On a folded card, "above the fourth
    /// kid" and "at the back of this group" are different landings that commit to different
    /// ladders, and drawing both above the "+N more" row would put them in the same place —
    /// losing a distinction the dot-and-line kept by drawing them at different y.
    static func seat(
        aimedAt target: GroupsDropSlot?,
        card: Group.ID,
        drawnRows: [PlayerRow]
    ) -> Seat? {
        guard let target, target.groupID == card else { return nil }
        guard let anchor = target.landing.anchor else { return .backOfCard }
        return drawnRows.contains { $0.id == anchor } ? .above(anchor) : .belowLastRow
    }

    // MARK: - Where its top edge lands

    /// The y of the ghost's top edge in the list's coordinate space, once the rows have shifted.
    ///
    ///     ghostTop(slot) = slot.y - (slot.y >= origin.maxY ? origin.height : 0)
    ///
    /// `slot.y` is frozen. `GroupsMove.slots` is measured once at lift and never rebuilt, so
    /// every boundary in it is stated against the layout as it stood *before* the mover gave up
    /// their space. That is what makes it a stable thing to aim at — see the argument on
    /// `GroupsMove.slots` — and it is also why the visual insertion point is no longer `slot.y`
    /// the moment anything moves. The one line above is the whole of the difference.
    ///
    /// The derivation. Taking the mover's row out lifts everything at or below `origin.maxY` by
    /// exactly one row height `H`: inside the source card the rows below them slide up `H`; the
    /// source card is itself `H` shorter, so every card below it rises `H` too. The same `H`
    /// both times, which is why there is no branch on which group the slot belongs to. Then a
    /// space of height `H` opens at that adjusted boundary, and the ghost's top edge *is* that
    /// boundary.
    ///
    /// This is the pixel analogue of the index adjustment `GroupsLandingPlan` already makes —
    /// take the mover out of every ladder first, and then the anchor's index *is* the insertion
    /// point. The same move, counted in points rather than in places, which is why what the
    /// reader sees and what gets written cannot disagree about where the kid ends up.
    ///
    /// Both spellings of "put them back" come out at `origin.minY`, and that is the sharpest
    /// property here. A boundary belongs to two rows at once, so "above the mover" and "above
    /// the next kid down" are the same line said twice — see `GroupsMove.isNoop`, which is this
    /// same fact counted in ids. The first has `slot.y == origin.minY`, which is above
    /// `origin.maxY` and so is left alone; the second has `slot.y == origin.maxY`, which is
    /// lifted by `H` back onto `origin.minY`. A rule that returned two different places for the
    /// two would draw the ghost a row away from where the kid actually is, for a gesture that
    /// has asked for nothing.
    ///
    /// Stated against `origin.maxY` rather than `origin.minY` deliberately: it is the removal of
    /// the **whole row** that lifts what is below it, so the boundary that decides is the row's
    /// foot and not its head. On the real slot set the two predicates agree anyway — a row's
    /// interior holds no boundary, so no slot's y ever falls strictly inside the mover's own
    /// row. Deliberately not the `minY` form all the same: in the degenerate case where one did
    /// fall inside, `maxY` resolves it as "above", which can never place the ghost higher than
    /// the top of its own card, where `minY` would.
    ///
    /// - Note: the card-foot slot is the one place this parks a little low. That slot's y is the
    ///   card's own bottom edge rather than a row boundary, so it sits `Spacing.tight` below the
    ///   line the space actually opens at. It is left that way because it is where the kid
    ///   *aims* — see `GroupsView.slots(for:)`.
    static func top(of target: GroupsDropSlot, lifted origin: CGRect) -> CGFloat {
        target.y - (target.y >= origin.maxY ? origin.height : 0)
    }
}
