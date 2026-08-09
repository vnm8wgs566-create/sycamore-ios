//
//  GroupsAutoscroll.swift
//  Sycamore
//
//  `8p` — the list moving itself while a kid is carried towards its edge.
//
//  This exists because the drop stopped being latched. The move used to survive the finger
//  leaving the handle, and the reach that bought was real: with the kid parked in the air you
//  could scroll the whole way down the venue with a second gesture and then press "Drop here".
//  Releasing commits now — the reader asked for a row that lands where they let go of it — so
//  the only reach left is the one a finger can take without lifting, and a venue is a great deal
//  taller than a thumb. The list has to come to the finger instead.
//
//  In its own file, with no SwiftUI in it, for the reason `GroupsGhost` and `GroupsLandingPlan`
//  are: an autoscroll is a pair of thresholds and a ramp, it needs neither the store, the
//  environment nor the main actor, and a threshold written inline in a gesture callback is a
//  threshold nobody can check. Every number this feature's motion depends on is one line of
//  arithmetic away from a test.
//

import CoreGraphics
import Foundation

// MARK: - What the list looks like

/// The scroll view, as far as the autoscroll is concerned: what part of the content is on screen,
/// and how much content there is to run out of.
///
/// Both measurements are in the list's own coordinate space (`GroupsSpace.list`), which is the
/// space every drop slot and every row rectangle is already stated in — so "the carried card is
/// near the bottom edge" is a comparison between two numbers that were measured the same way,
/// with no conversion in between to get wrong.
struct GroupsViewport: Equatable {

    /// The slice of the list content currently on screen.
    var visible: CGRect = .zero
    /// The whole content's height, which is what says when a scroll has hit the end.
    var contentHeight: CGFloat = 0
}

// MARK: - The ramp

enum GroupsAutoscroll {

    /// How close to an edge the carried card has to come before the list starts moving.
    ///
    /// A card's own height, near enough, and that is the point: the band has to be deep enough
    /// that a reader who has dragged to the very bottom of the screen is inside it, and shallow
    /// enough that an ordinary drag across two neighbouring rows never triggers it. Ninety-six
    /// points is a little over two 44pt rows.
    ///
    /// Deliberately not a `GroupsMetrics` token. Nothing is drawn at this size — it is the reach
    /// of a gesture, not a measurement off the design — and the tokens file is explicitly for
    /// numbers read off the CSS.
    static let zone: CGFloat = 96

    /// The fastest the list travels, in points per tick.
    ///
    /// Fourteen points every sixteen milliseconds is about 875pt/s at full tilt, which crosses a
    /// phone's worth of list in a second. Faster than that and a reader overshoots the group they
    /// were aiming for; slower and reaching the twelfth court is a chore rather than a gesture.
    static let maxStep: CGFloat = 14

    /// One frame at 60Hz. The loop that drives this sleeps for it between steps.
    static let tick: Duration = .milliseconds(16)

    /// How far the list should travel this tick, signed — negative towards the top of the list.
    ///
    /// A ramp rather than a switch: at the very edge of the viewport the list runs at `maxStep`,
    /// and at the inside edge of the band it barely creeps. That is what makes the speed
    /// controllable with the one input a dragging finger has left, which is where it is.
    ///
    /// The band is capped at a third of the viewport so the two zones cannot meet. In a short
    /// viewport — a small phone in landscape, or the largest accessibility type sizes, where two
    /// rows fill the screen — an uncapped 96pt band top and bottom would overlap in the middle,
    /// and every position would be inside both. The overlap is resolved towards the top anyway
    /// (below), so the cap is belt and braces; it also keeps the *ramp* meaningful, because a
    /// zone deeper than the viewport can never reach its own full speed.
    ///
    /// Ties go to the top, matching `GroupsMove.nearestSlot()`: two answers is a flicker, and a
    /// screen that cannot decide which way to scroll is worse than one that picks the wrong way.
    static func step(carrying card: CGRect, in viewport: GroupsViewport) -> CGFloat {
        let visible = viewport.visible
        guard visible.height > 0 else { return 0 }

        let zone = min(self.zone, visible.height / 3)
        guard zone > 0 else { return 0 }

        // How far into each band the card has reached. Positive means it is inside.
        let above = (visible.minY + zone) - card.minY
        let below = card.maxY - (visible.maxY - zone)

        if above > 0, above >= below { return -maxStep * min(1, above / zone) }
        if below > 0 { return maxStep * min(1, below / zone) }
        return 0
    }

    /// Where the top of the viewport should stand after one tick, or nil if the list should not
    /// move at all.
    ///
    /// Nil rather than "the position it is already at" for two reasons. It is what lets the
    /// caller skip the scroll *and* skip the re-aim that follows one, so a still finger in the
    /// middle of the screen costs nothing sixty times a second. And it is what makes running out
    /// of list a stop rather than a stutter: clamped against the content, a card held below the
    /// last card asks for a scroll the list cannot make, and the answer to that is "no" rather
    /// than a delta of zero applied over and over.
    static func destination(carrying card: CGRect, in viewport: GroupsViewport) -> CGFloat? {
        let step = step(carrying: card, in: viewport)
        guard step != 0 else { return nil }

        let limit = max(0, viewport.contentHeight - viewport.visible.height)
        let destination = min(max(0, viewport.visible.minY + step), limit)
        guard destination != viewport.visible.minY else { return nil }
        return destination
    }
}
