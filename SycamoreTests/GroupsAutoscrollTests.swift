//
//  GroupsAutoscrollTests.swift
//  SycamoreTests
//
//  The list coming to the finger.
//
//  This arithmetic replaced a latch. The move used to survive the finger leaving the handle, and
//  that is how a reader reached the twelfth court: park the kid, scroll with a second gesture,
//  press "Drop here". Releasing commits now, so the only reach left is the one a finger can take
//  without lifting — which makes these two thresholds the difference between "I can move a kid
//  anywhere" and "I can move a kid as far as one screen".
//
//  Worth testing rather than eyeballing, because every way it can be wrong is a way that *looks*
//  like a gesture problem. A band that never triggers reads as a list that will not scroll; a band
//  that triggers in the middle of the screen reads as a list that will not hold still; a
//  destination that is not clamped reads as a list that scrolls past its own end and springs back
//  under the finger. None of those are visible in the code, and the last one is not visible on a
//  short list either.
//
//  The sharp one is `destination` answering **nil** rather than "the place it is already at".
//  Nil is what stops the caller re-aiming sixty times a second for a still finger, and it is what
//  makes running out of list a stop rather than a stutter — a card held below the last card asks
//  every tick for a scroll the list cannot make, and answering that with a zero-length step would
//  move the target by nothing, repeatedly, forever.
//

import CoreGraphics
import Foundation
import Testing
@testable import Sycamore

@Suite("GroupsAutoscroll")
struct GroupsAutoscrollTests {

    /// A phone's worth of list: 800pt of viewport looking at 4,000pt of content, parked 1,000pt
    /// down so there is room to travel in both directions.
    static let viewport = GroupsViewport(
        visible: CGRect(x: 0, y: 1_000, width: 400, height: 800),
        contentHeight: 4_000
    )

    /// The carried card, a row high, with its middle at `y`.
    static func card(at y: CGFloat) -> CGRect {
        CGRect(x: 0, y: y - 22, width: 360, height: 44)
    }

    // MARK: The dead middle

    @Test("A card in the middle of the screen moves nothing")
    func theMiddleIsStill() {
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 1_400), in: Self.viewport) == 0)
        #expect(GroupsAutoscroll.destination(carrying: Self.card(at: 1_400), in: Self.viewport) == nil)
    }

    /// The band is `zone` deep, so the first point outside it has to be still. An off-by-a-band
    /// here is a list that creeps while a reader is trying to aim at a boundary near the middle.
    @Test("The inside edge of each band is still")
    func theBandsStopWhereTheySay() {
        let top = Self.viewport.visible.minY + GroupsAutoscroll.zone
        let bottom = Self.viewport.visible.maxY - GroupsAutoscroll.zone

        // A card whose top edge is exactly on the top band's inside edge is not in it.
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: top + 22), in: Self.viewport) == 0)
        // And the same for its bottom edge against the bottom band's.
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: bottom - 22), in: Self.viewport) == 0)
    }

    // MARK: The ramp

    @Test("Nearing the bottom edge walks the list forwards, nearing the top walks it back")
    func theDirections() {
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 1_780), in: Self.viewport) > 0)
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 1_020), in: Self.viewport) < 0)
    }

    /// The ramp is what makes the speed controllable with the one input a dragging finger has
    /// left, which is where it is. A switch instead would scroll at full tilt from the moment the
    /// card crossed the line.
    @Test("The deeper into the band, the faster it travels")
    func theRampRamps() {
        let shallow = GroupsAutoscroll.step(carrying: Self.card(at: 1_740), in: Self.viewport)
        let deeper = GroupsAutoscroll.step(carrying: Self.card(at: 1_780), in: Self.viewport)

        #expect(deeper > shallow)
        #expect(shallow > 0)
    }

    @Test("However far past the edge the card is carried, one tick is one step at most")
    func theRampIsCapped() {
        // Dragged clean off the bottom of the screen, and then a thousand points further.
        let offscreen = GroupsAutoscroll.step(carrying: Self.card(at: 3_000), in: Self.viewport)

        #expect(offscreen == GroupsAutoscroll.maxStep)
    }

    @Test("And the same at the top")
    func theRampIsCappedUpward() {
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: -500), in: Self.viewport) == -GroupsAutoscroll.maxStep)
    }

    // MARK: A viewport too short for two bands

    /// Two 96pt bands do not fit in a 200pt viewport, and a card in the middle of one would
    /// otherwise be inside both. The cap keeps them apart; ties go upward regardless, which is
    /// what the assertion below is really pinning — a screen that cannot decide which way to
    /// scroll is worse than one that picks a direction.
    @Test("In a viewport shorter than two bands, the zones are capped rather than overlapping")
    func aShortViewport() {
        let short = GroupsViewport(
            visible: CGRect(x: 0, y: 0, width: 400, height: 200),
            contentHeight: 4_000
        )

        // Dead centre of a 200pt viewport: outside both capped bands, so nothing moves.
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 100), in: short) == 0)
        // And the ends still work.
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 10), in: short) < 0)
        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 190), in: short) > 0)
    }

    @Test("A viewport with no height has no bands and cannot be scrolled")
    func anUnmeasuredViewport() {
        let unmeasured = GroupsViewport()

        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 0), in: unmeasured) == 0)
        #expect(GroupsAutoscroll.destination(carrying: Self.card(at: 0), in: unmeasured) == nil)
    }

    // MARK: Where the list actually ends up

    @Test("A step becomes a destination the list can be sent to")
    func destinationFollowsTheStep() throws {
        let card = Self.card(at: 1_780)
        let step = GroupsAutoscroll.step(carrying: card, in: Self.viewport)
        let destination = try #require(GroupsAutoscroll.destination(carrying: card, in: Self.viewport))

        #expect(destination == Self.viewport.visible.minY + step)
    }

    /// The list stops at its own end rather than scrolling past it. Unclamped, `scrollTo` would
    /// be asked for a position beyond the content on every tick, and every tick would also add
    /// that phantom travel to the carried card — so the kid would drift on past the last group
    /// while the screen stood still.
    @Test("The list stops at the foot of the content")
    func clampedAtTheFoot() throws {
        let nearlyAtTheEnd = GroupsViewport(
            visible: CGRect(x: 0, y: 3_195, width: 400, height: 800),
            contentHeight: 4_000
        )
        let destination = try #require(
            GroupsAutoscroll.destination(carrying: Self.card(at: 3_980), in: nearlyAtTheEnd)
        )

        #expect(destination == 3_200)
    }

    @Test("A list already at its foot is asked for nothing")
    func nothingLeftToScroll() {
        let atTheEnd = GroupsViewport(
            visible: CGRect(x: 0, y: 3_200, width: 400, height: 800),
            contentHeight: 4_000
        )

        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 3_980), in: atTheEnd) > 0)
        #expect(GroupsAutoscroll.destination(carrying: Self.card(at: 3_980), in: atTheEnd) == nil)
    }

    @Test("And the same at the top of the list")
    func nothingLeftToScrollUpward() {
        let atTheTop = GroupsViewport(
            visible: CGRect(x: 0, y: 0, width: 400, height: 800),
            contentHeight: 4_000
        )

        #expect(GroupsAutoscroll.step(carrying: Self.card(at: 20), in: atTheTop) < 0)
        #expect(GroupsAutoscroll.destination(carrying: Self.card(at: 20), in: atTheTop) == nil)
    }

    /// Content shorter than the viewport has nowhere to go in either direction, which is the
    /// ordinary state of a camp with two groups in it.
    @Test("A list shorter than the screen never scrolls")
    func aShortList() {
        let short = GroupsViewport(
            visible: CGRect(x: 0, y: 0, width: 400, height: 800),
            contentHeight: 300
        )

        #expect(GroupsAutoscroll.destination(carrying: Self.card(at: 780), in: short) == nil)
    }
}
