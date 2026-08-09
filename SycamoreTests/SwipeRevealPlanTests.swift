//
//  SwipeRevealPlanTests.swift
//  SycamoreTests
//
//  The swipe's arithmetic, which is the whole of the reason it was lifted out of the view.
//
//  Every threshold here decides something a person can otherwise only check by putting a finger on
//  a device, and every way it can be wrong looks right: the row moves, something happens, nothing
//  throws. That is the same argument `GroupsLandingPlanTests` makes for its own subject.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("SwipeRevealPlan")
struct SwipeRevealPlanTests {

    private let width = SwipeMetrics.actionWidth

    /// A drag of `dx` with no vertical component, past the lock in one step.
    private func left(_ dx: CGFloat) -> CGSize { CGSize(width: -dx, height: 0) }

    // MARK: Deciding the axis

    @Test("A drag shorter than the lock decides nothing and moves nothing")
    func belowTheLock() {
        var plan = SwipeRevealPlan()
        let claimed = plan.drag(left(SwipeMetrics.axisLock - 1))

        #expect(claimed == false)
        #expect(plan.axis == .undecided)
        #expect(plan.offset == 0)
    }

    @Test("A drag that is mostly vertical is refused and the row does not move")
    func verticalIsRefused() {
        var plan = SwipeRevealPlan()
        let claimed = plan.drag(CGSize(width: -10, height: -40))

        #expect(claimed == false)
        #expect(plan.axis == .vertical)
        #expect(plan.offset == 0)
    }

    @Test("A drag that is mostly horizontal claims the finger and the row follows it point for point")
    func horizontalFollowsTheFinger() {
        var plan = SwipeRevealPlan()
        let claimed = plan.drag(CGSize(width: -40, height: -10))

        #expect(claimed == true)
        #expect(plan.axis == .horizontal)
        #expect(plan.offset == -40)
    }

    @Test("The axis is decided once — a horizontal swipe that curves downward keeps the row")
    func horizontalStaysHorizontal() {
        var plan = SwipeRevealPlan()
        plan.drag(left(30))
        let claimed = plan.drag(CGSize(width: -50, height: -400))

        #expect(claimed == true)
        #expect(plan.offset == -50)
    }

    @Test("The axis is decided once — a scroll that drifts sideways never gets the row")
    func verticalStaysVertical() {
        var plan = SwipeRevealPlan()
        plan.drag(CGSize(width: 0, height: -30))
        let claimed = plan.drag(CGSize(width: -400, height: -50))

        #expect(claimed == false)
        #expect(plan.offset == 0)
    }

    // MARK: Travel

    @Test("A leftward drag stops at the panel's width")
    func stopsAtThePanel() {
        var plan = SwipeRevealPlan()
        plan.drag(left(width))

        #expect(plan.offset == -width)
    }

    @Test("Past the stop the row moves a third as far as the finger and never further")
    func rubberBands() {
        var plan = SwipeRevealPlan()
        plan.drag(left(width + 100))

        #expect(plan.offset == -width - 100 * SwipeMetrics.resistance)
        #expect(plan.offset > -width - 100)
    }

    @Test("A rightward drag on a closed row leaves it exactly where it is")
    func noLeadingAction() {
        var plan = SwipeRevealPlan()
        plan.drag(CGSize(width: 80, height: 0))

        #expect(plan.offset == 0)
    }

    @Test("A rightward drag on an open row closes it and stops at zero")
    func rightwardClosesAndStops() {
        var plan = SwipeRevealPlan(isOpen: true)
        plan.drag(CGSize(width: width / 2, height: 0))
        #expect(plan.offset == -width / 2)

        plan.drag(CGSize(width: width + 60, height: 0))
        #expect(plan.offset == 0)
    }

    // MARK: Settling

    @Test("Releasing past the middle of the panel settles open, short of it settles closed")
    func settlesOnTheHalfway() {
        let justPast = width * SwipeMetrics.settleFraction + 1
        var past = SwipeRevealPlan()
        past.drag(left(justPast))
        let pastOpened = past.end(predictedEndTranslation: left(justPast))
        #expect(pastOpened)
        #expect(past.offset == -width)

        let justShort = width * SwipeMetrics.settleFraction - 1
        var short = SwipeRevealPlan()
        short.drag(left(justShort))
        let shortOpened = short.end(predictedEndTranslation: left(justShort))
        #expect(shortOpened == false)
        #expect(short.offset == 0)
    }

    @Test("A fast flick settles on where it was going, not on where the finger stopped")
    func flickUsesThePrediction() {
        var plan = SwipeRevealPlan()
        plan.drag(left(20))

        // Twenty points of travel, but momentum carrying it well past the halfway mark.
        let opened = plan.end(predictedEndTranslation: left(200))
        #expect(opened)
        #expect(plan.offset == -width)
    }

    @Test("A rightward flick on an open row settles it closed")
    func flickClosesAnOpenRow() {
        var plan = SwipeRevealPlan(isOpen: true)
        plan.drag(CGSize(width: 20, height: 0))

        let opened = plan.end(predictedEndTranslation: CGSize(width: 200, height: 0))
        #expect(opened == false)
        #expect(plan.offset == 0)
    }

    @Test("A settled row sits on nothing but zero or the panel's width")
    func settlesOnlyOnRests() {
        for travel in stride(from: CGFloat(0), through: width * 2, by: 7) {
            var plan = SwipeRevealPlan()
            plan.drag(left(max(travel, SwipeMetrics.axisLock)))
            plan.end(predictedEndTranslation: left(travel))

            #expect(plan.offset == 0 || plan.offset == -width)
            #expect(plan.restingOffset == plan.offset)
        }
    }

    // MARK: Cancelling and carrying on

    @Test("A cancelled drag returns an open row to open, not to closed")
    func cancelKeepsTheRest() {
        var plan = SwipeRevealPlan(isOpen: true)
        plan.drag(CGSize(width: 40, height: 0))
        #expect(plan.offset == -width + 40)

        plan.cancel()
        #expect(plan.offset == -width)
        #expect(plan.isOpen)
    }

    @Test("A vertical drag that ends is a cancel, so an open row stays open")
    func verticalEndDoesNotClose() {
        var plan = SwipeRevealPlan(isOpen: true)
        plan.drag(CGSize(width: 0, height: -60))

        let stillOpen = plan.end(predictedEndTranslation: CGSize(width: 0, height: -200))
        #expect(stillOpen)
        #expect(plan.offset == -width)
    }

    @Test("A second drag starts from where the first one left the row")
    func restCarriesForward() {
        var plan = SwipeRevealPlan()
        plan.drag(left(width))
        plan.end(predictedEndTranslation: left(width))
        #expect(plan.isOpen)

        // A fresh gesture: the translation starts at zero again, so without a carried rest the
        // row would jump back to closed on the first sample.
        plan.drag(CGSize(width: -20, height: 0))
        #expect(plan.offset == -width - 20 * SwipeMetrics.resistance)
    }

    @Test("Closing forgets the axis, so the next finger is judged on its own")
    func closeResetsTheAxis() {
        var plan = SwipeRevealPlan()
        plan.drag(CGSize(width: 0, height: -40))
        #expect(plan.axis == .vertical)

        plan.close()
        #expect(plan.axis == .undecided)
        let claimed = plan.drag(left(40))
        #expect(claimed)
    }
}
