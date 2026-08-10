//
//  ScheduleTimelineTests.swift
//  SycamoreTests
//
//  The canvas's arithmetic, which is the whole of the reason it was lifted out of the screen.
//
//  Every threshold here decides something a person can otherwise only check by putting a finger on
//  a device, and every way it can be wrong looks right: a card draws, it has a time written on it,
//  nothing throws — and it is in the wrong place, or on top of something. That is the argument
//  `ScheduleResizeTests`, `SwipeRevealPlanTests` and `GroupsLandingPlanTests` each make for their
//  own subject.
//
//  The **packing** is the sharp part, and most of this file. Two things about it are easy to get
//  wrong and impossible to see: a run of overlapping blocks is transitive — A over B and B over C
//  puts all three in one run even when A and C never meet — and every block in a run has to be told
//  the *run's* column count rather than its own, or three overlapping blocks draw at three
//  different widths. Both are asserted here rather than eyeballed.
//
//  `lanesIgnoreCourts` is guarding a judgement rather than a behaviour. Lanes key on time alone and
//  the clash rule keys on time *and* space, so two blocks on disjoint courts run side by side while
//  `BlockRules.overlap(with:in:)` reports nothing — and the day somebody "fixes" the packing to
//  agree with the flag, a morning the schedule exists to be able to write down starts drawing on
//  top of itself.
//

import CoreGraphics
import Foundation
import Testing
@testable import Sycamore

@Suite("ScheduleTimeline")
struct ScheduleTimelineTests {

    private let venue = Venue.ID()
    private let step = ScheduleResizePlan.step

    /// One block, said in the fewest words the packing needs.
    private func block(
        _ title: String,
        _ startsAt: TimeOfDay,
        _ endsAt: TimeOfDay?,
        courts: [CourtGroup.ID] = []
    ) -> ScheduleBlock {
        ScheduleBlock(
            venueID: venue, day: .tue, startsAt: startsAt, endsAt: endsAt, title: title,
            kind: courts.isEmpty ? .regular : .assigned, courtIDs: courts
        )
    }

    private func at(_ hour: Int, _ minute: Int) -> TimeOfDay { TimeOfDay(hour, minute) }

    // MARK: The grid it is ruled on

    @Test("The canvas begins and ends where the editor's own clock does")
    func theGridIsBlockClocks() {
        // The one thing keeping a canvas from ruling hours nothing can be scheduled in, or from
        // stopping short of hours that can. Restated rather than derived — see `dayStart` — so
        // this is what catches the day the camp clock moves.
        #expect(ScheduleTimeline.dayStart == BlockClock.options.first)
        #expect(ScheduleTimeline.dayEnd == BlockClock.options.last)
        #expect(ScheduleTimeline.dayStart == TimeOfDay(7, 0))
        #expect(ScheduleTimeline.dayEnd == TimeOfDay(20, 0))
        // …and the minute a drag stops at is the minute the canvas stops drawing.
        #expect(ScheduleTimeline.dayEnd == ScheduleResizePlan.dayEnd)
    }

    @Test("A quarter of an hour is one line of type, an hour is 120 points, the day is a screen and a half")
    func theScaleIsLegible() {
        #expect(ScheduleTimeline.pointsPerMinute * CGFloat(step) == 30)
        #expect(ScheduleTimeline.hourHeight == 120)
        #expect(ScheduleTimeline.dayHeight == 1560)
        // The ratio a drag is measured by is the ratio the grid is drawn at, and not a second
        // number that happens to look like it.
        #expect(ScheduleTimeline.travelPerStep == ScheduleTimeline.hourHeight / 4)
    }

    @Test("Every ruled hour is a whole hour inside the day, and they tile it exactly")
    func theHoursTileTheDay() {
        let hours = ScheduleTimeline.hours

        #expect(hours.first == TimeOfDay(7, 0))
        #expect(hours.last == TimeOfDay(19, 0))
        #expect(hours.count == 13)
        #expect(hours.allSatisfy { $0.minute == 0 })
        // Thirteen rows of `hourHeight` come to `dayHeight` with nothing over, which is what lets
        // the grid be a stack of rows rather than rules placed by hand.
        #expect(CGFloat(hours.count) * ScheduleTimeline.hourHeight == ScheduleTimeline.dayHeight)
    }

    // MARK: Points and minutes

    @Test("The top of the canvas is the start of the day and the bottom is the end of it")
    func theEndsOfTheCanvas() {
        #expect(ScheduleTimeline.y(for: ScheduleTimeline.dayStart) == 0)
        #expect(ScheduleTimeline.y(for: ScheduleTimeline.dayEnd) == ScheduleTimeline.dayHeight)
        #expect(ScheduleTimeline.y(for: at(9, 0)) == 240)
        #expect(ScheduleTimeline.y(for: at(9, 30)) == 300)
    }

    @Test("A block's height is its length, at every length the grid can express")
    func heightIsLength() {
        #expect(ScheduleTimeline.height(from: at(9, 0), to: at(9, 15)) == 30)
        #expect(ScheduleTimeline.height(from: at(9, 0), to: at(9, 30)) == 60)
        #expect(ScheduleTimeline.height(from: at(9, 0), to: at(10, 0)) == 120)
        #expect(ScheduleTimeline.height(from: at(9, 0), to: at(11, 0)) == 240)
    }

    @Test("Two consecutive quarter-hour blocks are drawn end to end and never on top of each other")
    func shortBlocksDoNotCollide() {
        // The case `pointsPerMinute` was chosen to make unnecessary to clamp. A minimum height
        // here would put the second block's top edge above the first block's bottom, and from
        // that moment the canvas is not measuring anything.
        let first = ScheduleTimeline.y(for: at(9, 0))
        let firstBottom = first + ScheduleTimeline.height(from: at(9, 0), to: at(9, 15))
        let second = ScheduleTimeline.y(for: at(9, 15))

        #expect(firstBottom == second)
        #expect(ScheduleTimeline.height(from: at(9, 0), to: at(9, 15)) >= 30)
    }

    @Test("A time outside the grid is pinned to the edge nearest it rather than drawn off-canvas")
    func clampsToTheDay() {
        #expect(ScheduleTimeline.y(for: at(6, 0)) == 0)
        #expect(ScheduleTimeline.y(for: at(23, 0)) == ScheduleTimeline.dayHeight)
        // …and a span wholly outside it draws as nothing, rather than as a sliver at a minute it
        // did not happen at.
        #expect(ScheduleTimeline.height(from: at(21, 0), to: at(22, 0)) == 0)
        #expect(ScheduleTimeline.height(from: at(5, 0), to: at(6, 0)) == 0)
        // A backwards span is data the CHECK forbids and Postgres would hold. It draws nothing
        // rather than a negative frame.
        #expect(ScheduleTimeline.height(from: at(10, 0), to: at(9, 0)) == 0)
    }

    // MARK: Back from points

    @Test("Every point on the canvas maps back to the time drawn there")
    func timeRoundTripsY() {
        for option in BlockClock.options {
            #expect(ScheduleTimeline.time(atY: ScheduleTimeline.y(for: option)) == option)
        }
    }

    @Test("A tap between two grid lines means the nearer one, and never a minute between them")
    func snapsToTheGrid() {
        let grid = Set(BlockClock.options)

        for y in stride(from: CGFloat(-200), through: ScheduleTimeline.dayHeight + 200, by: 7) {
            #expect(grid.contains(ScheduleTimeline.time(atY: y)))
        }

        // Six tenths of a step past nine is nearer 9:15 than 9:00.
        let quarter = ScheduleTimeline.travelPerStep
        #expect(ScheduleTimeline.time(atY: 240 + quarter * 0.6) == at(9, 15))
        #expect(ScheduleTimeline.time(atY: 240 + quarter * 0.4) == at(9, 0))
    }

    @Test("A tap above or below the canvas means its first or last minute")
    func timeClampsToTheDay() {
        #expect(ScheduleTimeline.time(atY: -5000) == ScheduleTimeline.dayStart)
        #expect(ScheduleTimeline.time(atY: 50_000) == ScheduleTimeline.dayEnd)
    }

    // MARK: What a tap on empty canvas proposes

    @Test("A tap on empty canvas proposes an hour from where the finger landed")
    func draftIsAnHour() {
        let span = ScheduleTimeline.draftSpan(atY: ScheduleTimeline.y(for: at(9, 0)))

        #expect(span.startsAt == at(9, 0))
        #expect(span.endsAt == at(10, 0))
        // The same hour the composer's own default is, so the two entrances agree.
        #expect(span.endsAt.id - span.startsAt.id == ScheduleTimeline.draftLength)
    }

    @Test("A tap at the foot of the day proposes what is left of it rather than an hour past it")
    func draftClampsAtTheDayEnd() {
        let late = ScheduleTimeline.draftSpan(atY: ScheduleTimeline.dayHeight)

        #expect(late.startsAt == at(19, 45))
        #expect(late.endsAt == ScheduleTimeline.dayEnd)
    }

    @Test("No tap anywhere on the canvas proposes a block the database would refuse")
    func draftAlwaysEndsAfterItStarts() {
        for y in stride(from: CGFloat(-500), through: ScheduleTimeline.dayHeight + 500, by: 11) {
            let span = ScheduleTimeline.draftSpan(atY: y)
            #expect(BlockRules.endsAfterStart(startsAt: span.startsAt, endsAt: span.endsAt))
            #expect(span.startsAt >= ScheduleTimeline.dayStart)
            #expect(span.endsAt <= ScheduleTimeline.dayEnd)
        }
    }

    // MARK: Packing — a day that is simply in order

    @Test("A morning with nothing overlapping is one column wide from top to bottom")
    func aTidyMorningIsOneColumn() {
        let day = [
            block("Drop-off", at(8, 30), at(9, 0)),
            block("Skills", at(9, 0), at(10, 30)),
            block("Water", at(10, 30), at(10, 45)),
        ]
        let timeline = ScheduleTimeline(day: day)

        for each in day {
            #expect(timeline[each.id]?.lane == 0)
            #expect(timeline[each.id]?.laneCount == 1)
        }
    }

    @Test("A block that ends exactly when the next begins shares its column rather than splitting it")
    func halfOpenSpansMeetWithoutOverlapping() {
        // The same edge `BlockRules.overlaps` draws: an ordinary camp morning is blocks that touch,
        // and a canvas that read touching as overlapping would draw every day at half width.
        let first = block("Warm-up", at(9, 0), at(9, 30))
        let second = block("Drills", at(9, 30), at(10, 0))
        let timeline = ScheduleTimeline(day: [first, second])

        #expect(timeline[first.id]?.laneCount == 1)
        #expect(timeline[second.id]?.laneCount == 1)
        #expect(timeline[second.id]?.lane == 0)
    }

    @Test("A block hanging off the top of the grid is drawn from the grid's first minute")
    func aBlockStartingBeforeTheDayIsTrimmed() {
        let early = block("Early birds", at(6, 0), at(8, 0))
        let timeline = ScheduleTimeline(day: [early])

        #expect(timeline[early.id]?.startsAt == ScheduleTimeline.dayStart)
        #expect(timeline[early.id]?.endsAt == at(8, 0))
        #expect(timeline[early.id]?.y == 0)
    }

    @Test("A block wholly outside the grid still gets a card, at the edge nearest it")
    func aBlockOutsideTheDayIsPinned() {
        // No path in this app writes one — the editor's menus, the resize's ceiling and the move's
        // walls are all `BlockClock` — but Postgres holds it and the header counts it. Drawn at
        // zero height it is a card with no hit area: nothing to open, move or delete.
        let dawn = block("Dawn", at(5, 0), at(6, 0))
        let night = block("Night", at(22, 0), at(23, 0))
        let timeline = ScheduleTimeline(day: [dawn, night])

        #expect(timeline[dawn.id]?.startsAt == ScheduleTimeline.dayStart)
        #expect(timeline[dawn.id]?.height == CGFloat(step) * ScheduleTimeline.pointsPerMinute)
        #expect(timeline[night.id]?.endsAt == ScheduleTimeline.dayEnd)
        #expect(timeline[night.id]?.height == CGFloat(step) * ScheduleTimeline.pointsPerMinute)
    }

    @Test("A block pinned to the grid's edge is packed against what is already there")
    func aPinnedBlockTakesItsOwnColumn() {
        // Clamped *before* the packing, not after: pinned into a run it was never compared with,
        // it would be drawn on top of the block that genuinely starts at seven.
        let dawn = block("Dawn", at(5, 0), at(6, 0))
        let opening = block("Opening", at(7, 0), at(8, 0))
        let timeline = ScheduleTimeline(day: [dawn, opening])

        #expect(timeline[dawn.id]?.laneCount == 2)
        #expect(timeline[opening.id]?.laneCount == 2)
        #expect(timeline[dawn.id]?.lane != timeline[opening.id]?.lane)
    }

    @Test("No block anywhere on any day is drawn with nothing to touch")
    func everyBlockIsReachable() {
        let awkward = [
            block("Dawn", at(5, 0), at(6, 0)),
            block("Night", at(22, 0), at(23, 0)),
            block("Backwards", at(10, 0), at(9, 0)),
            block("Instant", at(10, 0), at(10, 0)),
            block("Open at the foot", at(20, 0), nil),
            block("Ordinary", at(9, 0), at(10, 0)),
        ]
        let timeline = ScheduleTimeline(day: awkward)

        for one in awkward {
            let placement = timeline[one.id]
            #expect(placement != nil)
            #expect((placement?.height ?? 0) > 0)
            #expect((placement?.y ?? -1) >= 0)
            #expect((placement?.y ?? 0) + (placement?.height ?? 0) <= ScheduleTimeline.dayHeight)
        }
    }

    @Test("A block on this day has no place on any other")
    func unknownBlocksHaveNoPlacement() {
        let day = [block("Skills", at(9, 0), at(10, 0))]
        let timeline = ScheduleTimeline(day: day)

        #expect(timeline[ScheduleBlock.ID()] == nil)
        #expect(ScheduleTimeline(day: [])[day[0].id] == nil)
    }

    // MARK: Packing — overlaps

    @Test("Two blocks running at once take a column each and half the width")
    func twoAtOnceIsTwoColumns() {
        let warmUp = block("Warm-up", at(9, 0), at(9, 30))
        let free = block("Free play", at(9, 15), at(10, 0))
        let timeline = ScheduleTimeline(day: [warmUp, free])

        #expect(timeline[warmUp.id]?.lane == 0)
        #expect(timeline[free.id]?.lane == 1)
        #expect(timeline[warmUp.id]?.laneCount == 2)
        #expect(timeline[free.id]?.laneCount == 2)
    }

    @Test("Three blocks over one another take three columns, and all three are told the same count")
    func threeDeep() {
        let one = block("One", at(9, 0), at(10, 0))
        let two = block("Two", at(9, 15), at(10, 0))
        let three = block("Three", at(9, 30), at(10, 0))
        let timeline = ScheduleTimeline(day: [one, two, three])

        #expect(timeline[one.id]?.lane == 0)
        #expect(timeline[two.id]?.lane == 1)
        #expect(timeline[three.id]?.lane == 2)
        // The count is the *run's*, not each block's own. Told its own, the third block would draw
        // at a third of the width and the first at all of it, over the same fifteen minutes.
        for each in [one, two, three] {
            #expect(timeline[each.id]?.laneCount == 3)
        }
    }

    @Test("A run of overlaps is transitive: A over B and B over C puts all three in one run")
    func runsAreTransitive() {
        // A and C never meet. They are still in one run, because B reaches both — and if they were
        // not, A would be drawn full width across a column C is standing in.
        let a = block("A", at(9, 0), at(9, 30))
        let b = block("B", at(9, 15), at(10, 0))
        let c = block("C", at(9, 45), at(10, 30))
        let timeline = ScheduleTimeline(day: [a, b, c])

        #expect(timeline[a.id]?.laneCount == 2)
        #expect(timeline[b.id]?.laneCount == 2)
        #expect(timeline[c.id]?.laneCount == 2)
        // C reuses the column A freed at half past.
        #expect(timeline[a.id]?.lane == 0)
        #expect(timeline[b.id]?.lane == 1)
        #expect(timeline[c.id]?.lane == 0)
    }

    @Test("One long block beside a cluster of short ones keeps its column and they queue in the other")
    func aLongBlockBesideShortOnes() {
        let long = block("Match play", at(9, 0), at(11, 0))
        let shorts = [
            block("First", at(9, 0), at(9, 15)),
            block("Second", at(9, 15), at(9, 30)),
            block("Third", at(9, 30), at(9, 45)),
        ]
        let timeline = ScheduleTimeline(day: [long] + shorts)

        // The long one lands first on a tie and holds column zero for the whole two hours; each
        // short block then finds column one free the moment the one before it ended.
        #expect(timeline[long.id]?.laneCount == 2)
        for short in shorts {
            #expect(timeline[short.id]?.laneCount == 2)
        }
        #expect(Set(shorts.compactMap { timeline[$0.id]?.lane }).count == 1)
        #expect(timeline[long.id]?.lane != timeline[shorts[0].id]?.lane)
    }

    @Test("Two runs of overlaps do not borrow each other's columns")
    func runsAreIndependent() {
        let morning = [
            block("A", at(9, 0), at(10, 0)),
            block("B", at(9, 30), at(10, 0)),
        ]
        let afternoon = block("Lunch", at(12, 0), at(13, 0))
        let timeline = ScheduleTimeline(day: morning + [afternoon])

        #expect(timeline[morning[0].id]?.laneCount == 2)
        // A day that widened everything because two blocks overlapped at half past nine would be
        // the whole afternoon paying for the morning.
        #expect(timeline[afternoon.id]?.laneCount == 1)
        #expect(timeline[afternoon.id]?.lane == 0)
    }

    @Test("Blocks that tie on their start time take a column each, in an order that does not wander")
    func tiesOnStart() {
        let first = block("First", at(9, 0), at(10, 0))
        let second = block("Second", at(9, 0), at(10, 0))
        let forwards = ScheduleTimeline(day: [first, second])
        let backwards = ScheduleTimeline(day: [second, first])

        #expect(forwards[first.id]?.laneCount == 2)
        #expect(forwards[first.id]?.lane != forwards[second.id]?.lane)
        // The tie-break is `ScheduleBlock.running(in:at:)`'s — arbitrary but fixed — so the two
        // blocks do not swap columns between one read of the day and the next. The repository
        // orders by `starts_at` and nothing else, so the array order genuinely does change.
        #expect(forwards[first.id]?.lane == backwards[first.id]?.lane)
        #expect(forwards[second.id]?.lane == backwards[second.id]?.lane)
    }

    // MARK: Packing — the judgement it does not make

    @Test("Blocks on disjoint courts still take a column each, though they are not a clash")
    func lanesIgnoreCourts() {
        let courtOne = CourtGroup.ID()
        let courtTwo = CourtGroup.ID()
        let warmUp = block("Warm-up", at(9, 0), at(9, 30), courts: [courtOne])
        let free = block("Free play", at(9, 0), at(10, 0), courts: [courtTwo])
        let day = [warmUp, free]

        // The rule that reads courts says these two are fine, and it is right.
        #expect(BlockRules.overlap(with: warmUp, in: day) == nil)
        #expect(BlockRules.overlap(with: free, in: day) == nil)

        // The canvas draws them side by side anyway, because they genuinely are: concurrency is a
        // layout fact and a clash is a judgement. Drawn in one column to agree with the flag, one
        // of them would be underneath the other for half an hour.
        let timeline = ScheduleTimeline(day: day)
        #expect(timeline[warmUp.id]?.laneCount == 2)
        #expect(timeline[free.id]?.laneCount == 2)
        #expect(timeline[warmUp.id]?.lane != timeline[free.id]?.lane)
    }

    // MARK: Packing — a block with no stated end

    @Test("A block with no end is closed by the next block that shares its space")
    func openEndsAreClosedByTheNextSharer() {
        let dropOff = block("Drop-off", at(8, 30), nil)
        let huddle = block("Huddle", at(9, 0), at(9, 15))
        let timeline = ScheduleTimeline(day: [dropOff, huddle])

        #expect(timeline[dropOff.id]?.endsAt == at(9, 0))
        #expect(timeline[dropOff.id]?.height == 60)
        // …so it does not need a column of its own, having ended when the huddle began.
        #expect(timeline[dropOff.id]?.laneCount == 1)
    }

    @Test("A block with no end that nothing follows runs to the bottom of the canvas")
    func openEndsRunToTheDayEnd() {
        let free = block("Free play", at(15, 0), nil)
        let timeline = ScheduleTimeline(day: [free])

        #expect(timeline[free.id]?.endsAt == ScheduleTimeline.dayEnd)
        #expect(timeline[free.id]?.height == ScheduleTimeline.height(from: at(15, 0), to: at(20, 0)))
    }

    @Test("A block with no end is not closed by one it shares no court with")
    func openEndsIgnoreABlockElsewhere() {
        // `ScheduleBlock.hasFinished(_:by:amongst:)`'s rule, and the case that separates it from a
        // plain "whatever starts next": a warm-up on Court 1 is not ended by free play on Court 2.
        let courtOne = CourtGroup.ID()
        let courtTwo = CourtGroup.ID()
        let warmUp = block("Warm-up", at(9, 0), nil, courts: [courtOne])
        let elsewhere = block("Free play", at(9, 30), at(10, 0), courts: [courtTwo])
        let later = block("Lunch", at(12, 0), at(13, 0))
        let timeline = ScheduleTimeline(day: [warmUp, elsewhere, later])

        #expect(timeline[warmUp.id]?.endsAt == at(12, 0))
        // …and while it runs, it and the block on the other court are two columns.
        #expect(timeline[warmUp.id]?.laneCount == 2)
    }

    @Test("A block with no end is closed by another that has none either")
    func openEndsCloseEachOther() {
        // Deliberately not `BlockRules.latestEnd(for:in:)`, which skips a neighbour with no stated
        // end because it is offering advice a reader can check. Used here, the first block would be
        // drawn straight through the second and down to eight in the evening.
        let first = block("First", at(9, 0), nil)
        let second = block("Second", at(10, 0), nil)
        let timeline = ScheduleTimeline(day: [first, second])

        #expect(timeline[first.id]?.endsAt == at(10, 0))
        #expect(timeline[second.id]?.endsAt == ScheduleTimeline.dayEnd)
        #expect(timeline[first.id]?.laneCount == 1)
    }

    @Test("A block with no end takes a column beside whatever it genuinely runs alongside")
    func openEndsTakeALane() {
        let courtOne = CourtGroup.ID()
        let courtTwo = CourtGroup.ID()
        let open = block("Free play", at(9, 0), nil, courts: [courtOne])
        let beside = block("Warm-up", at(9, 30), at(10, 30), courts: [courtTwo])
        let timeline = ScheduleTimeline(day: [open, beside])

        // Nothing shares Court 1 all day, so the open block runs to the canvas's foot — which puts
        // it alongside the warm-up, and side by side is where they belong.
        #expect(timeline[open.id]?.endsAt == ScheduleTimeline.dayEnd)
        #expect(timeline[open.id]?.laneCount == 2)
        #expect(timeline[beside.id]?.laneCount == 2)
    }

    // MARK: Columns, in points

    @Test("A block with nothing beside it takes the whole width")
    func oneColumnIsTheWholeWidth() {
        let alone = ScheduleTimeline.Placement(
            startsAt: at(9, 0), endsAt: at(10, 0), lane: 0, laneCount: 1
        )

        #expect(alone.width(in: 300, gap: 9) == 300)
        #expect(alone.x(in: 300, gap: 9) == 0)
    }

    @Test("Two columns split the width with one gap between them, and fill it exactly")
    func twoColumnsFillTheWidth() {
        let left = ScheduleTimeline.Placement(
            startsAt: at(9, 0), endsAt: at(10, 0), lane: 0, laneCount: 2
        )
        let right = ScheduleTimeline.Placement(
            startsAt: at(9, 0), endsAt: at(10, 0), lane: 1, laneCount: 2
        )

        #expect(left.width(in: 309, gap: 9) == 150)
        #expect(left.x(in: 309, gap: 9) == 0)
        #expect(right.x(in: 309, gap: 9) == 159)
        #expect(right.x(in: 309, gap: 9) + right.width(in: 309, gap: 9) == 309)
    }

    @Test("Columns never come out negative, however little width there is to divide")
    func columnsSurviveANarrowScreen() {
        // A `GeometryReader` proposes zero on its first pass, and a negative width is a frame
        // SwiftUI will complain about in a way nobody reads.
        for laneCount in 1...4 {
            for width in [CGFloat(0), 1, 20] {
                let placement = ScheduleTimeline.Placement(
                    startsAt: at(9, 0), endsAt: at(10, 0), lane: laneCount - 1,
                    laneCount: laneCount
                )
                #expect(placement.width(in: width, gap: 9) >= 0)
            }
        }
    }

    // MARK: The fixture the previews draw

    @Test("The busier sample Tuesday packs into the columns it was written to exercise")
    func theSampleDayPacks() {
        let day = ScheduleSampleDay.overlappingBlocks(venueID: venue)
        let timeline = ScheduleTimeline(day: day)

        // Every block is placed…
        #expect(day.allSatisfy { timeline[$0.id] != nil })

        func placed(_ title: String) -> ScheduleTimeline.Placement? {
            day.first { $0.title == title }.flatMap { timeline[$0.id] }
        }

        // …the open-ended drop-off is closed by the nine o'clock warm-up…
        #expect(placed("Drop-off")?.endsAt == at(9, 0))
        // …three things are on at ten past nine…
        #expect(placed("Parent tour")?.laneCount == 3)
        // …and the afternoon does not pay for it.
        #expect(placed("Lunch")?.laneCount == 1)
        #expect(placed("Water & regroup")?.laneCount == 1)
        // The coach huddle is laid over match play, which is both a clash and two columns.
        #expect(placed("Coach huddle")?.laneCount == 2)
        let huddle = day.first { $0.title == "Coach huddle" }
        #expect(huddle.flatMap { BlockRules.overlap(with: $0, in: day) }?.title == "Match play")
    }
}
