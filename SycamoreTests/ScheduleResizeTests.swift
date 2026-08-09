//
//  ScheduleResizeTests.swift
//  SycamoreTests
//
//  The resize's arithmetic, which is the whole of the reason it was lifted out of the card.
//
//  Every threshold here decides something a person can otherwise only check by putting a finger on
//  a device, and every way it can be wrong looks right: the edge moves, a time is written, nothing
//  throws. That is the argument `SwipeRevealPlanTests` and `GroupsLandingPlanTests` each make for
//  their own subject.
//
//  Two of these are guarding a *constraint* rather than a behaviour. `endsAfterStart` is
//  `schedule_blocks_ends_after_starts` (`20260805074039:38-39`), which refuses the write rather
//  than the drag — so a resize that could produce it would be a gesture that silently fails at the
//  end of a round trip. And `theGridIsBlockClocks` is the only thing keeping this file's `step`
//  and the editor's own quarter-hour menu from drifting apart.
//
//  The neighbour tests are gone with the neighbour. A drag used to clamp at the next block's start
//  and it does not any more — `ScheduleResize.swift`'s header argues that at length, and
//  `aDragMayNowCrossTheNextBlock` is what pins it, because a clamp quietly coming back is a
//  refusal nothing on screen would announce. What the rule became is `BlockRules`, and its tests
//  are in `BlockEditorDraftTests` beside the other rules the schedule holds itself to.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("ScheduleResizePlan")
struct ScheduleResizeTests {

    /// One step's worth of travel, so the tests read in steps rather than in points.
    private let travel = ScheduleResizePlan.travel
    private let step = ScheduleResizePlan.step

    /// A 9:00–10:00 block, which is the shape most of these ask about.
    private func plan(
        from startsAt: TimeOfDay = TimeOfDay(9, 0),
        to endsAt: TimeOfDay = TimeOfDay(10, 0)
    ) -> ScheduleResizePlan {
        ScheduleResizePlan(startsAt: startsAt, endsAt: endsAt, travelPerStep: travel)
    }

    // MARK: The grid it snaps to

    @Test("The step is the editor's own quarter-hour, not a second opinion about it")
    func theGridIsBlockClocks() {
        let grid = BlockClock.options
        #expect(grid.count > 1)
        #expect(grid[1].id - grid[0].id == step)
        #expect(ScheduleResizePlan.dayEnd == grid.last)
    }

    @Test("The shortest block the floor allows is the editor's own first end option")
    func theFloorIsTheEditorsFirstEndOption() {
        // The floor is arithmetic — the first grid line strictly after the start — rather than a
        // call to `BlockClock.endOptions(after:)`, because that helper is bounded by the grid and
        // returns nothing at all for a block starting outside it. Inside the grid the two must
        // agree, and this is what says so.
        for startsAt in BlockClock.options.dropLast() {
            var live = plan(from: startsAt, to: ScheduleResizePlan.dayEnd)
            live.drag(by: -travel * 100)

            #expect(live.endsAt == BlockClock.endOptions(after: startsAt).first)
        }
    }

    @Test("Every end a drag can produce is a time the block editor could also offer")
    func settlesOnTheEditorsGrid() {
        let grid = Set(BlockClock.options)

        for points in stride(from: CGFloat(-400), through: 400, by: 3) {
            var live = plan()
            live.drag(by: points)
            #expect(grid.contains(live.endsAt))
        }
    }

    // MARK: Snapping

    @Test("A drag of one step lengthens the block by exactly fifteen minutes")
    func oneStepIsOneQuarterHour() {
        var live = plan()
        live.drag(by: travel)

        #expect(live.endsAt == TimeOfDay(10, 15))
        #expect(live.hasMoved)
    }

    @Test("A drag upwards shortens it by the same amount")
    func upwardsShortens() {
        var live = plan()
        live.drag(by: -travel * 2)

        #expect(live.endsAt == TimeOfDay(9, 30))
    }

    @Test("A drag shorter than half a step leaves the block exactly where it was")
    func belowTheDeadzone() {
        var live = plan()
        live.drag(by: travel / 2 - 1)

        #expect(live.endsAt == TimeOfDay(10, 0))
        #expect(live.hasMoved == false)
    }

    @Test("A drag of one point never moves anything, in either direction")
    func aTwitchDoesNothing() {
        var down = plan()
        down.drag(by: 1)
        var up = plan()
        up.drag(by: -1)

        #expect(down.hasMoved == false)
        #expect(up.hasMoved == false)
    }

    @Test("A drag between two grid lines lands on the nearer one and never between them")
    func snapsToTheNearest() {
        // Six tenths of a step past 10:00 is nearer 10:15 than 10:00.
        var past = plan()
        past.drag(by: travel * 0.6)
        #expect(past.endsAt == TimeOfDay(10, 15))

        // Four tenths is not.
        var short = plan()
        short.drag(by: travel * 0.4)
        #expect(short.endsAt == TimeOfDay(10, 0))
    }

    @Test("A block already off the grid is put back onto it by the first drag that moves it")
    func repairsAnOffGridEnd() {
        var live = plan(to: TimeOfDay(10, 7))
        live.drag(by: travel)

        #expect(live.endsAt == TimeOfDay(10, 15))
    }

    // MARK: The neighbour, which is no longer a wall

    /// The judgement call this change made, asserted rather than described: the drag refuses
    /// nothing that the block editor's two time menus would accept.
    ///
    /// Built from the sample Tuesday so the neighbour is a real one — `Skills rotation` runs
    /// 9:00–10:30 with `Water & regroup` starting at 10:30 — and dragged well past it. A clamp
    /// creeping back in would be a second answer to a question `BlockRules.overlap(with:in:)`
    /// already answers, and the disagreement would be invisible: a wall does not announce itself.
    @Test("A drag may now cross the next block's start, and the flag is what catches it")
    func aDragMayNowCrossTheNextBlock() {
        let day = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
        var skills = day[1]

        var live = plan(from: TimeOfDay(9, 0), to: TimeOfDay(10, 30))
        live.drag(by: travel * 4)
        #expect(skills.startsAt == TimeOfDay(9, 0))
        #expect(skills.endsAt == TimeOfDay(10, 30))
        #expect(live.endsAt == TimeOfDay(11, 30))

        // …and the day that produces says so, on both cards, rather than the drag having refused.
        skills.endsAt = live.endsAt
        let after = day.map { $0.id == skills.id ? skills : $0 }
        #expect(BlockRules.overlap(with: skills, in: after)?.title == "Water & regroup")
        #expect(ScheduleConflicts(day: after)[day[2].id]?.title == "Skills rotation")
    }

    // MARK: The day's bounds

    @Test("Nothing can be dragged past the end of the camp day")
    func clampsAtTheDayEnd() {
        var live = plan(from: TimeOfDay(19, 0), to: TimeOfDay(19, 30))
        live.drag(by: travel * 40)

        #expect(live.endsAt == ScheduleResizePlan.dayEnd)
        #expect(live.endsAt == TimeOfDay(20, 0))
    }

    @Test("A block that already runs past the day's end keeps its length rather than being cut")
    func doesNotCutAnEveningBlock() {
        var live = plan(from: TimeOfDay(19, 0), to: TimeOfDay(20, 30))
        live.drag(by: travel * 40)

        #expect(live.endsAt == TimeOfDay(20, 30))
    }

    @Test("The day's end is the injected one, so a shorter day clamps sooner")
    func honoursAnInjectedDayEnd() {
        // The seam earns its keep here rather than being an unused parameter: a camp whose grid
        // stopped at noon would clamp against noon, and nothing about the arithmetic assumes 20:00.
        var live = ScheduleResizePlan(
            startsAt: TimeOfDay(9, 0),
            endsAt: TimeOfDay(10, 0),
            dayEnd: TimeOfDay(12, 0),
            travelPerStep: travel
        )
        live.drag(by: travel * 40)

        #expect(live.endsAt == TimeOfDay(12, 0))
    }

    @Test("The travel per step is the injected one, so retuning the ratio retunes the drag")
    func honoursAnInjectedTravel() {
        // `ScheduleResizePlan.travel` is a feel number and will be retuned. The arithmetic is
        // stated in steps, not in points, and this is what holds that apart from the constant.
        var doubled = ScheduleResizePlan(
            startsAt: TimeOfDay(9, 0),
            endsAt: TimeOfDay(10, 0),
            travelPerStep: travel * 2
        )
        doubled.drag(by: travel * 2)

        #expect(doubled.endsAt == TimeOfDay(10, 15))

        // …and the same travel against the default ratio moves twice as far.
        var standard = plan()
        standard.drag(by: travel * 2)
        #expect(standard.endsAt == TimeOfDay(10, 30))
    }

    @Test("Dragged all the way up, a block stops one step after it starts")
    func clampsAtTheShortestBlock() {
        var live = plan()
        live.drag(by: -travel * 40)

        #expect(live.endsAt == TimeOfDay(9, 15))
    }

    @Test("A block already shorter than one step is not lengthened by being touched")
    func doesNotGrowAShortBlock() {
        // 9:00–9:05 is a block Postgres will hold: the CHECK is `ends_at > starts_at` and says
        // nothing about a minimum. The floor gives way to it rather than snapping it open.
        var live = plan(to: TimeOfDay(9, 5))
        live.drag(by: -travel * 10)

        #expect(live.endsAt == TimeOfDay(9, 5))
    }

    // MARK: The CHECK

    @Test("No drag from any block, in any direction, can end a block at or before it starts")
    func endsAfterStart() {
        let starts = [TimeOfDay(7, 0), TimeOfDay(9, 0), TimeOfDay(12, 37), TimeOfDay(19, 45)]
        let lengths = [5, 15, 45, 90]

        for startsAt in starts {
            for minutes in lengths {
                let end = TimeOfDay((startsAt.id + minutes) / 60, (startsAt.id + minutes) % 60)
                // Strided coarsely on purpose. Both clamps bite long before ±600, so the corners
                // are reached either way, and a finer sweep is thousands of `#expect` macro
                // evaluations buying nothing.
                for points in stride(from: CGFloat(-600), through: 600, by: 47) {
                    var live = plan(from: startsAt, to: end)
                    live.drag(by: points)

                    let settled = live.endsAt
                    #expect(settled > startsAt)
                    #expect(BlockRules.endsAfterStart(startsAt: startsAt, endsAt: settled))
                }
            }
        }
    }

    @Test("A plan always starts on the block it was handed, whatever is around it")
    func restingIsAlwaysReachable() {
        // The invariant the walls are widened for: a finger landing on the handle and lifting
        // again writes nothing, even on a day the app itself could not have produced.
        let awkward = [
            plan(to: TimeOfDay(9, 5)),
            plan(from: TimeOfDay(19, 0), to: TimeOfDay(21, 0)),
            plan(from: TimeOfDay(6, 3), to: TimeOfDay(6, 4)),
        ]

        for var live in awkward {
            live.drag(by: 0)
            #expect(live.hasMoved == false)
            #expect(live.endsAt == live.restingEnd)
        }
    }

    // MARK: The rotor

    @Test("One adjustable step is one drag step, and it starts from the block rather than the drag")
    func adjustsByOneStep() {
        let live = plan()

        #expect(live.adjusted(by: 1) == TimeOfDay(10, 15))
        #expect(live.adjusted(by: -1) == TimeOfDay(9, 45))
        #expect(live.adjusted(by: 4) == TimeOfDay(11, 0))
    }

    @Test("The rotor stops at the same walls the finger does")
    func adjustingClamps() {
        let againstTheDayEnd = plan(from: TimeOfDay(19, 30), to: TimeOfDay(19, 45))
        #expect(againstTheDayEnd.adjusted(by: 8) == ScheduleResizePlan.dayEnd)

        let againstStart = plan()
        #expect(againstStart.adjusted(by: -8) == TimeOfDay(9, 15))
    }

    @Test("At a wall the rotor returns the resting end, which is what stops it writing")
    func adjustingAtAWallWritesNothing() {
        let stuck = plan(from: TimeOfDay(19, 45), to: ScheduleResizePlan.dayEnd)

        #expect(stuck.adjusted(by: 1) == stuck.restingEnd)
    }

    // MARK: What it reads out

    @Test("The live readout is spelled the way the card underneath it spells the same span")
    func spanLabelMatchesTheCard() {
        var live = plan()
        live.drag(by: travel)

        let block = ScheduleBlock(
            venueID: SampleData.sycamore.id, day: .tue,
            startsAt: TimeOfDay(9, 0), endsAt: TimeOfDay(10, 15), title: "Skills rotation"
        )

        #expect(live.spanLabel == "9:00am – 10:15am")
        #expect(live.spanLabel == block.timeLabel)
    }
}
