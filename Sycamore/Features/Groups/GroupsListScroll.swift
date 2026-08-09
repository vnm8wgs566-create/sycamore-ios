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

extension View {

    /// Hands the list's position to `scroll`, and reports back what it is showing into `viewport`.
    ///
    /// `visibleRect` is in the content's own coordinates, which is the space `GroupsSpace.list`
    /// names and the space every drop slot and row rectangle is already stated in — so "the
    /// carried card has reached the bottom edge" is two numbers measured the same way, with no
    /// conversion in between to get wrong.
    func groupsListScroll(
        _ scroll: Binding<GroupsListScroll>,
        viewport: Binding<GroupsViewport>
    ) -> some View {
        #if os(iOS)
        return self
            .scrollPosition(scroll.position)
            .onScrollGeometryChange(for: GroupsViewport.self) {
                GroupsViewport(visible: $0.visibleRect, contentHeight: $0.contentSize.height)
            } action: { _, updated in
                viewport.wrappedValue = updated
            }
        #else
        return self
        #endif
    }
}
