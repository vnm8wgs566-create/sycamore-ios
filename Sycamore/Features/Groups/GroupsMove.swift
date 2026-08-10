//
//  GroupsMove.swift
//  Sycamore
//
//  `8p` — a kid carried between groups, from the moment the handle is held to the moment the
//  finger leaves it.
//
//  **The move used to be latched, and is not any more.** Holding the handle picked the kid up and
//  they stayed up when the finger left: from there you could drag them, scroll the list, or tap
//  any group to aim at it, and the move only happened when "Drop here" was pressed. Two arguments
//  were made for that, and both have been answered.
//
//  The first was that a latch is what the design draws — a lifted card, a highlighted target and
//  two buttons — and that a plain drag-and-release cannot draw it, because a finger that is still
//  down cannot reach a Cancel button. True, and it is not what a reader expects a dragged row to
//  do: *"when I let go of a row it should drop into place"*. Letting go is the most natural
//  spelling of "here", and a screen that answers it by leaving the kid hanging over a button they
//  now have to find has turned one gesture into three. Release commits. Cancelling is the
//  confirmation's "Leave them where they are", which only appears when the kid changes court —
//  the one drop where a mistake costs something a reader cannot see from the row alone.
//
//  The second was reach: the target group is often not on screen when the kid is picked up, and
//  the latch is what let you scroll to it. That was real, and taking the latch away is what pays
//  for the two things that replace it. Every card in the venue unfolds for the length of the
//  move, so no kid's place is hidden behind "+3 more" (see `GroupsView.beginMove`), and the list
//  scrolls itself when the carried card nears an edge (`GroupsAutoscroll`). Between them a finger
//  that never lifts can reach any position in any group, which the latch could not do either —
//  a folded card offered three of its eight seats however long you hovered over it.
//

// No SwiftUI here any more: the bar was the only view in this file, and what is left is the state
// a move is, which is arithmetic and ids.
import CoreGraphics
import Foundation

// MARK: - Coordinate space

/// The list content's own coordinate space, so a slot measured before a scroll is still valid
/// after one.
///
/// At file scope rather than on `GroupsView`: a SwiftUI view is `@MainActor` in Swift 6, and the
/// closures `onGeometryChange` measures through are `Sendable` — a static on the view is not
/// reachable from inside them.
enum GroupsSpace {
    static let list = "groups.list"
}

// MARK: - State

/// One kid, off the ladder, waiting to be put back.
struct GroupsMove: Equatable {

    let row: PlayerRow
    /// The group the kid was picked up from, or **nil for a kid who was in none**.
    ///
    /// Nil is not a defensive spelling: the model leaves kids at a venue with no group two ways —
    /// a band that refuses them, and a group that was deleted out from under them — and
    /// `UnassignedCard` draws those kids as ordinary draggable rows, because the way to place one
    /// is the same drag that moves anybody else. So "where did this kid come from" genuinely has no
    /// answer for them, and every place that asks reads the nil correctly for free: no card is the
    /// source, `isNoop` can never fire (there is no boundary they already stand either side of),
    /// and `endTracking` parks the carried card because the landing is always a change of group.
    let sourceGroupID: Group.ID?
    /// The kid immediately below the mover in their own group at lift time, or nil if they were
    /// last in it.
    ///
    /// A boundary belongs to two rows at once: the slot directly *below* the mover is the same
    /// line as the slot directly *above* whoever stands next. Without this, only one of the two
    /// ways of putting a kid back exactly where they were would be recognised as doing nothing.
    let nextRowID: Player.ID?
    /// The row's rectangle at lift time, in the list's coordinate space. The lifted card is
    /// positioned from it, so it has to be captured before the row goes invisible.
    ///
    /// Re-anchored exactly once, if the lift's unfold moved the row down the list —
    /// `GroupsView.refreshDragGeometry()` shifts `translation` by the same amount in the other
    /// direction, so the card stays where the finger is holding it.
    var origin: CGRect
    /// Every place the kid could land, measured against the list **at rest**.
    ///
    /// The geometry these were measured from **does** move now — that is the whole of `8p`'s
    /// drag. The rows shift aside to open a space, the card the kid came out of closes up by
    /// one row and the card they are aimed at opens by one. Capturing the slots is what lets
    /// the target survive all of that.
    ///
    /// It has to be a capture rather than a per-frame rebuild, and not merely for cheapness. The
    /// shift is *caused by* the target, and the slots are what the target is picked from — so an
    /// array rebuilt from the shifted layout would be chasing its own tail: aim at a boundary,
    /// the rows move, the boundary moves, the nearest slot is now a different one, aim at that.
    /// Frozen, a slot means one fixed thing: where that boundary stood in the list at rest,
    /// which is the only state a drop can be measured from.
    ///
    /// **Captured, then recaptured exactly once.** The lift unfolds every card in the venue so
    /// that no seat is hidden behind "+3 more", and that changes the layout the first capture
    /// described. `awaitingGeometry` below is the window in which the list is drawn at rest so
    /// it can be measured again; `GroupsView.refreshDragGeometry()` replaces this array and
    /// re-anchors `origin` from the same pass. After it the array is frozen for good, because
    /// nothing else about the list changes while a kid is in the air — "Add a group" is hidden,
    /// the search field and chips are swapped out for the moving line, and there is no "+N more"
    /// left to press.
    ///
    /// The consequence is `GroupsGhost.top`: because a slot's y is stated against the layout
    /// before the mover left it, one row height has to come off it to find where the space
    /// actually opens. One line, derived there.
    var slots: [GroupsDropSlot]

    /// The cards *this move* opened, which are the only ones it may fold again.
    ///
    /// Inside the move rather than beside it, because that is exactly how long it is true for.
    /// Held as a sibling `@State` the invariant was a comment — one path that cleared `move`
    /// without reading it would leave every card the lift opened open for good, or worse, fold
    /// one the reader had opened themselves. `RankView.RankDrag.refoldOnEnd` (`:501`) puts the
    /// same fact in the same place.
    ///
    /// A card the reader opened is not in here and never fold shut underneath them: they opened
    /// it, and a gesture that has finished is not a reason to undo that.
    let unfolded: Set<Group.ID>

    /// Offset from `origin`. Follows the finger while the handle is held, plus however far the
    /// list has scrolled itself underneath it; on release it is set so the card sits with its top
    /// on the space that has opened for the kid — see `GroupsView.park()`.
    var translation: CGFloat = 0
    /// How much of `translation` the **list** put there rather than the finger.
    ///
    /// The drag is measured in `.global` (see `GroupCard.lift`), which knows nothing about the
    /// content moving underneath it — so a list that autoscrolls while the finger is still
    /// reports no travel at all, and one that grows above the mover reports none either. Two
    /// things add to this: every tick the list actually travels, and the single re-anchor the
    /// lift's unfold causes when it pushes the mover's row down (`GroupsView`).
    ///
    /// Held separately rather than simply added into `translation`, because `translation` is
    /// **rewritten** from the gesture on every frame of a drag — `travel + listTravel`. Folded in
    /// and forgotten, every correction would survive exactly until the next twitch of a finger
    /// and then vanish, snapping the card back by however far the list had moved since the lift.
    ///
    /// `RankView` has the same shape and no equivalent: it corrects `translation` in place after
    /// an unfold (`RankView.swift:420`) and overwrites it wholesale on the next frame (`:429`).
    /// Not fixed here because that screen is not this change's to edit — but whoever hoists this
    /// lift-and-re-anchor protocol into one component, which it should be, has to carry this with
    /// it or the correction goes back to lasting one frame.
    var listTravel: CGFloat = 0
    /// True only while the finger is actually down on the handle. It goes false on release, and
    /// the kid is only still in the air after that while a court change is being confirmed.
    var isDragging: Bool = false
    /// The fold changed under the move, so what is on screen no longer describes the list these
    /// slots were measured against.
    ///
    /// Set for the handful of frames between the lift unfolding the venue's cards and SwiftUI
    /// having laid the opened rows out. While it is true the card draws itself **at rest** —
    /// no ghost, and the lifted row keeps its space (`GroupCard`) — which is what makes the
    /// frames measured in that pass directly usable: they describe the same layout the frozen
    /// slots are stated against, with the unfold and nothing else applied to it.
    ///
    /// Copied from `RankView`'s drag, which unfolds a section at lift for exactly the same reason
    /// and calls this the same thing (`RankView.swift:409-425`). Aiming is suspended while it is
    /// true, because a target chosen against stale slots would move the ghost and take the
    /// at-rest guarantee with it.
    var awaitingGeometry: Bool = false
    var target: GroupsDropSlot?

    /// The carried card's rectangle in the list's coordinate space. The card is the mover's row,
    /// moved — which is what the autoscroll measures against the viewport's edges.
    var carried: CGRect { origin.offsetBy(dx: 0, dy: translation) }

    /// Where the middle of the lifted card currently sits, which is what the drop aims with —
    /// a fingertip is a worse pointer than the thing it is carrying.
    ///
    /// Read off `carried` rather than restated as `origin.midY + translation`, so the number the
    /// drop aims with and the rectangle the scroll reacts to cannot come apart. They were two
    /// spellings for one line and there is nothing to gain from keeping both honest by hand.
    var centre: CGFloat { carried.midY }

    /// The slot nearest the card being carried.
    func nearestSlot() -> GroupsDropSlot? {
        let centre = centre
        return slots.min { abs($0.y - centre) < abs($1.y - centre) }
    }

    // `lastSlot(in:)` lived here — the last slot in a group, which is what tapping its card meant:
    // put them at the back. Tapping a card was the latch's other half, and there is no moment left
    // at which it could happen: a move lasts exactly as long as the finger carrying it, plus a
    // confirmation that has the screen to itself. Removed rather than left as a spelling nothing
    // says, and the back of a group is still reachable — it is a slot like any other, and the two
    // rotor actions reach it by name (`GroupsView.nudgeAcross`).

    /// Landing either side of where the kid already stands is not a move.
    ///
    /// Both sides, because a boundary is shared: the slot above them anchors on the mover, and
    /// the slot below anchors on whoever stands next. When the mover was last in their group
    /// both `nextRowID` and the back-of-group slot's anchor are nil, so that case falls out of
    /// the same comparison rather than needing its own branch.
    ///
    /// Worth catching: committing one of these would spend a write, a reload and a re-render to
    /// put the ladder back exactly as it was — and on a flaky connection it would fail visibly
    /// for a gesture that asked for nothing.
    ///
    /// A kid lifted from no group has a nil `sourceGroupID`, which no slot's group can equal — so
    /// every landing is a real move for them, which is exactly right: there is no boundary they
    /// already stand either side of, and any group at all is somewhere they are not.
    func isNoop(_ slot: GroupsDropSlot) -> Bool {
        guard slot.landing.groupID == sourceGroupID else { return false }
        return slot.landing.anchor == row.id || slot.landing.anchor == nextRowID
    }
}

// MARK: - What one card sees

/// The kid in the air, cut down to the facts one `GroupCard` actually draws from.
///
/// `GroupCard` took the whole `GroupsMove` until this existed, and the cost of that only became
/// visible once a lift started unfolding the entire venue. `translation` is rewritten on every
/// frame of a drag — it is where the carried card is drawn, and it genuinely changes at display
/// rate — and **no card reads it**. So the one field that changed per frame was the one field
/// nothing on a card depended on, and handing the move to all twelve of them invalidated every
/// row of an opened venue sixty times a second to redraw the same pixels.
///
/// Everything here is either constant for the length of a move or changes only when the *aim*
/// does, which is what makes `GroupCard`'s `==` worth asking. A finger travelling inside one slot
/// produces a digest identical to last frame's for every card in the venue, so nothing redraws
/// until the kid is actually aimed somewhere else — and then only the two cards that say so.
struct GroupsCardMove: Equatable {

    /// `Drops in at #9` — what the target card writes where its head-count usually goes, and nil
    /// on every other card. It is also how a card knows it *is* the target: a `Bool` beside this
    /// would be a second answer to one question, and two fields that must agree.
    let dropLine: String?
    /// Whether the kid was picked up from this card. Only the fading of the cards that are
    /// neither this nor the target reads it — the gap the kid left is drawn from `heldRowID`.
    let isSource: Bool
    /// The kid in the air. Stated for every card rather than nil'd out for all but the source:
    /// no other card draws a row with this id, and a field that holds still for the length of a
    /// move is a field that never invalidates anybody.
    let heldRowID: Player.ID
    /// Where this card opens the space for them, or nil if they are not aimed here.
    let ghostSeat: GroupsGhost.Seat?
    // `isSettling` and `ghostHeight` used to be stored here and are not any more. Both lost their
    // readers when the design's drag landed — the kid's row stops giving up its space, so nothing
    // needs its height, and no card draws itself differently while the list is being measured.
    //
    // Keeping them was not free. This struct exists to hold *only* what a card draws, so that a
    // card not involved in a move compares equal across a frame and is not redrawn; `ghostHeight`
    // is `move.origin.height`, and `origin` is re-anchored at the settle boundary — so a field
    // nobody read was changing there and invalidating every card in an opened venue.
    //
    // `isSettling` survives as a local in `init`, below, where `ghostSeat` still gates on it.
    /// The kid's name, which is what the ghost says.
    let ghostName: String

    /// The kid is aimed at this card.
    var isTarget: Bool { dropLine != nil }

    /// Nil when nobody is being carried, which is the ordinary screen.
    init?(_ move: GroupsMove?, card: Group.ID, drawnRows: [PlayerRow]) {
        guard let move else { return nil }
        let isSettling = move.awaitingGeometry

        self.dropLine = move.target?.groupID == card ? move.target?.dropLine : nil
        self.isSource = move.sourceGroupID == card
        self.heldRowID = move.row.id
        // No ghost while the list is being re-measured: a row in the flow that was not there when
        // the slots were captured is precisely what would stop that pass describing the list at
        // rest. The lifted row keeps its space over the same window, so the two cancel.
        self.ghostSeat = isSettling
            ? nil
            : GroupsGhost.seat(aimedAt: move.target, card: card, drawnRows: drawnRows)
        self.ghostName = move.row.name
    }
}

/// A place a kid can land: a boundary between two rows, or the end of a group.
struct GroupsDropSlot: Equatable, Hashable {

    let landing: GroupsLanding
    /// The boundary's y in the list's coordinate space, **in the layout as it stood at lift**.
    ///
    /// An *aiming* coordinate, not a drawing one. It is what `nearestSlot()` measures the
    /// carried card against, and it stays fixed for the length of the gesture precisely so that
    /// the rows are free to move. Where the space actually opens on screen is one row height
    /// higher whenever this sits below the mover; `GroupsGhost.top` is that adjustment, and it
    /// is the only thing that should ever be drawn from this number.
    let y: CGFloat
    /// The overall rank the kid takes if they land here — `Drops in at #9`.
    let rank: Int

    var groupID: Group.ID { landing.groupID }

    /// The line the target card writes where its head-count usually goes.
    var dropLine: String { "Drops in at #\(rank)" }
}

/// Where a kid is going, said as "directly above this other kid".
///
/// A *kid* rather than a row number, because a row number only means anything alongside the list
/// it was counted against — and this screen's list is filtered by the search field, folded to
/// three rows, and about to have the mover taken out of it. An id survives all three. It is also
/// the only description both the drag and the rotor's "Move up" can produce, which is what lets
/// them share one commit.
struct GroupsLanding: Equatable, Hashable {
    let groupID: Group.ID
    let venueID: Venue.ID
    /// The kid the mover lands directly above. Nil for the back of the group.
    let anchor: Player.ID?
}

// MARK: - The bar that is not here any more
//
// `Cancel` / `Drop here` sat on a frosted capsule stacked above the tab bar, and both buttons and
// the plate they were drawn on have gone with the latch. The plate lived in `GroupsFloatingPlate`
// and was a copy of `FloatingTabBar`'s three layers awaiting a hoist into the design system; that
// hoist is still worth making, and it is `TabBar.swift` that should make it, from the one caller
// left. Nothing in this feature draws a floating pill now.
//
// The buttons' tokens are gone from `GroupsTokens` for the same reason. See the note there.
