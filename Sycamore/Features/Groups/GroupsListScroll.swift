//
//  GroupsListScroll.swift
//  Sycamore
//
//  Driving `8o`'s list from code, and reading back what it is showing — the two things `8p`'s
//  autoscroll needs from the scroll view, behind one platform door.
//
//  `ScrollPosition` and `onScrollGeometryChange` are iOS 18 and macOS **15**, and this module's
//  floor is macOS 14 (`Package.swift`) so that `swift test` runs against the SDK a plain Command
//  Line Tools install carries. Every other iOS-only API in the app is shimmed where it is used —
//  `FullScreenPresentation`, `SwipeToDelete` — and both of those are one modifier in one place.
//  This is two, in the middle of the chain that builds the list, and a `#if` between `.padding`
//  and `.overlay` makes the shape of that chain hard to read. So the door is here instead, with
//  the reason on it.
//
//  On macOS the list simply does not scroll itself: `GroupsViewport` stays at its zero value, and
//  `GroupsAutoscroll.step` answers zero for a viewport with no height. Nothing else about the
//  move changes, and the Mac build exists to be typechecked and tested rather than dragged in.
//

import SwiftUI

/// The scroll view's position, held by `GroupsView` and nudged a frame at a time while a kid is
/// being carried towards an edge.
struct GroupsListScroll {

    #if os(iOS)
    var position = ScrollPosition()
    #endif

    /// Put the top of the viewport at `y`, in the list's own coordinate space.
    ///
    /// Unanimated on purpose. The caller is already running at one step per frame, and an
    /// animation per step would queue sixty overlapping curves a second — each one still easing
    /// towards a destination the next has already replaced.
    mutating func scroll(to y: CGFloat) {
        #if os(iOS)
        position.scrollTo(y: y)
        #endif
    }
}

/// What the list is showing, held by reference.
///
/// A box, and deliberately neither `@State` holding the struct nor `@Observable`.
/// `onScrollGeometryChange` fires on **every** frame of an ordinary scroll, so writing this into
/// `@State` re-rendered the whole of `8o` at display rate for a value nothing on the screen draws:
/// the only readers are `GroupsView.tickAutoscroll()` and, through it, `GroupsAutoscroll`, both of
/// which only run while a kid is being carried.
///
/// Guarding the *write* on a live move instead is the obvious cheaper fix and it is wrong. Nothing
/// reports scroll geometry when a lift begins — the list is not moving at that moment — so the box
/// would still be holding whatever was on screen before the reader's last scroll, and the first
/// tick of an autoscroll would compute its destination from it and throw the list back there. It
/// is always written, and it never invalidates anybody.
///
/// Not `Sendable` and not isolated: `onScrollGeometryChange`'s action is a plain escaping closure
/// on the main thread, and the two readers are `@MainActor` already.
final class GroupsViewportBox {
    var value = GroupsViewport()
}

extension View {

    /// Hands the list's position to `scroll`, keeps `viewport` current, and reports each step the
    /// content actually took to `onTravel`.
    ///
    /// `visibleRect` is in the content's own coordinates, which is the space `GroupsSpace.list`
    /// names and the space every drop slot and row rectangle is already stated in — so "the
    /// carried card has reached the bottom edge" is two numbers measured the same way, with no
    /// conversion in between to get wrong.
    ///
    /// `onTravel` is called for every geometry change rather than only the ones that moved the
    /// content, and with the raw difference rather than a filtered one: the caller is already the
    /// place that decides whether a step counts — see `GroupsView.creditListTravel(_:)`, which
    /// ignores a zero and ignores anything at all unless a finger is down.
    func groupsListScroll(
        _ scroll: Binding<GroupsListScroll>,
        viewport: GroupsViewportBox,
        onTravel: @escaping (CGFloat) -> Void
    ) -> some View {
        #if os(iOS)
        return self
            .scrollPosition(scroll.position)
            .onScrollGeometryChange(for: GroupsViewport.self) {
                GroupsViewport(visible: $0.visibleRect, contentHeight: $0.contentSize.height)
            } action: { was, now in
                viewport.value = now
                onTravel(now.visible.minY - was.visible.minY)
            }
        #else
        return self
        #endif
    }
}
