//
//  GroupsMove.swift
//  Sycamore
//
//  `8p` — a kid held in the air, and the bar that lands them.
//
//  The move is *latched*, not a single continuous drag. Holding the handle picks the kid up and
//  they stay up when the finger leaves: from there you can drag them, scroll the list, or tap
//  any group to aim at it, and the move only happens when "Drop here" is pressed. That is what
//  the design draws — a lifted card, a highlighted target and two buttons — and a plain
//  drag-and-release could not draw it, because a finger that is still down cannot reach a
//  Cancel button. It is also the only shape of this gesture that works on a screen taller than
//  a thumb: the target group is often not on screen when the kid is picked up.
//

import SwiftUI

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
    let sourceGroupID: Group.ID
    /// The kid immediately below the mover in their own group at lift time, or nil if they were
    /// last in it.
    ///
    /// A boundary belongs to two rows at once: the slot directly *below* the mover is the same
    /// line as the slot directly *above* whoever stands next. Without this, only one of the two
    /// ways of putting a kid back exactly where they were would be recognised as doing nothing.
    let nextRowID: Player.ID?
    /// The row's rectangle at lift time, in the list's coordinate space. The lifted card is
    /// positioned from it, so it has to be captured before the row goes invisible.
    let origin: CGRect
    /// Every place the kid could land, measured once at lift.
    ///
    /// Captured rather than rebuilt each pass because the list is frozen for the duration: while
    /// a kid is in the air a card header aims instead of folding, "+N more" is disabled, "Add a
    /// group" is hidden, and the search field and chips are swapped out for the moving line. The
    /// geometry these were measured from cannot move, so measuring it again every frame of
    /// finger travel would produce the same array a hundred times a second.
    let slots: [GroupsDropSlot]

    /// Offset from `origin`. Follows the finger while the handle is held; afterwards it is set
    /// so the card sits centred on wherever the kid is now aimed.
    var translation: CGFloat = 0
    /// True only while the finger is actually down on the handle.
    var isDragging: Bool = false
    var target: GroupsDropSlot?

    /// Where the middle of the lifted card currently sits, which is what the drop aims with —
    /// a fingertip is a worse pointer than the thing it is carrying.
    var centre: CGFloat { origin.midY + translation }

    /// The slot nearest the card being carried.
    func nearestSlot() -> GroupsDropSlot? {
        let centre = centre
        return slots.min { abs($0.y - centre) < abs($1.y - centre) }
    }

    /// The last slot in a group, which is what tapping its card means: put them at the back.
    func lastSlot(in groupID: Group.ID) -> GroupsDropSlot? {
        slots.last { $0.groupID == groupID }
    }

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
    func isNoop(_ slot: GroupsDropSlot) -> Bool {
        guard slot.landing.groupID == sourceGroupID else { return false }
        return slot.landing.anchor == row.id || slot.landing.anchor == nextRowID
    }
}

/// A place a kid can land: a boundary between two rows, or the end of a group.
struct GroupsDropSlot: Equatable, Hashable {

    let landing: GroupsLanding
    /// The boundary's y in the list's coordinate space.
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

// MARK: - The bar

/// `Cancel` / `Drop here`, on the same floating plate as the tab bar.
///
/// The design puts this *in place of* the tab bar, which this app draws from `RootView` rather
/// than from the tab it belongs to. So it is stacked a tab bar's height higher instead — one
/// pill above the other, both reachable, neither hidden.
struct GroupsMoveBar: View {

    /// False until the kid is aimed somewhere, which cannot happen before the first frame.
    let canDrop: Bool
    let onCancel: () -> Void
    let onDrop: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Button(action: onCancel) {
                Text("Cancel")
                    .typeStyle(.chip, color: Theme.inkMuted)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.small)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)

            Pill("Drop here", tone: .accent, font: .chip, action: onDrop)
                .frame(minHeight: HitTarget.minimum)
                .opacity(canDrop ? 1 : GroupsMetrics.bystanderOpacity)
                .disabled(!canDrop)
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.tight)
        .background(plate)
        .overlay { ring }
        .overlay { lip }
        .shadow(Shadows.tabBar)
    }

    // The tab bar's three layers, restated so the two pills read as one piece of furniture while
    // they are on screen together. They are a copy — `FloatingTabBar` owns the original in
    // `TabBar.swift` — and want hoisting into a shared `floatingPlate()` modifier.

    /// `rgba(250,250,251,.82)` over a blur.
    private var plate: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay { Capsule(style: .continuous).fill(Theme.tabBarPlate) }
    }

    /// `0 0 0 .5px rgba(11,11,12,.07)`.
    private var ring: some View {
        Capsule(style: .continuous)
            .strokeBorder(Theme.ink.opacity(0.07), lineWidth: BorderWidth.ring)
    }

    /// `inset 0 1px 0 rgba(255,255,255,.95)` — a catch of light along the top edge only.
    private var lip: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Theme.tabBarLip, Theme.tabBarLip.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: BorderWidth.hairline
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Previews

#Preview("Move bar") {
    VStack(spacing: Spacing.large) {
        GroupsMoveBar(canDrop: true, onCancel: {}, onDrop: {})
        GroupsMoveBar(canDrop: false, onCancel: {}, onDrop: {})
    }
    .padding(Spacing.section)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.grouped)
}
