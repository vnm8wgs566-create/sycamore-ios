//
//  ScheduleTimeline.swift
//  Sycamore
//
//  Where a block sits on `8k`'s canvas — a y, a height, and a column to draw in. The arithmetic,
//  with no view in it.
//
//  Lifted out for the reason `ScheduleResizePlan` was (`ScheduleResize.swift:8-11`),
//  `SwipeRevealPlan` before it (`SwipeToDelete.swift:81-86`) and `GroupsLandingPlan` before that
//  (`GroupsLandingPlan.swift:7-11`): every threshold below decides something a person can otherwise
//  only check by putting a finger on a device, and every way it can be wrong looks right. A card
//  draws, it has a time on it, nothing throws — and the card is in the wrong place.
//
//  ── WHY THE SCREEN CHANGED SHAPE ──────────────────────────────────────────────────────────────
//
//  `8k` was a `LazyVStack` of equal cards in time order. A fifteen-minute block and a two-hour
//  block drew identically, and a three-note block drew taller than either — so the one thing the
//  screen is *for*, the shape of a morning, was the one thing it could not show. Two blocks running
//  at once drew one under the other, which reads as one after the other.
//
//  So the day is a canvas now: minutes are points, a block's height is its length, and blocks that
//  run at the same time sit side by side. Everything below is what that costs in arithmetic.
//
//  ── LANES KEY ON TIME ALONE ───────────────────────────────────────────────────────────────────
//
//  This is a deliberate distinction from the clash rule and it is written down rather than left to
//  be rediscovered. `BlockRules.overlap(with:in:)` (`BlockEditorDraft.swift:134`) flags a clash
//  only when two blocks overlap in time **and** `sharesSpace` — unless both name courts and those
//  court lists are disjoint. That rule is untouched and still drives the amber "Runs into…" line —
//  now live under a finger as well as at rest (`ScheduleConflicts.live(_:startsAt:endsAt:in:)`),
//  which changes when it is asked and nothing about what it answers. Lanes are not that question: two blocks running at once sit side by side whether or not
//  they share courts, because **concurrency is a layout fact and a clash is a judgement**. A
//  warm-up on Court 1 beside free play on Courts 2–4 is a morning the camp is meant to be able to
//  write down, and drawing the two on top of each other to prove they are compatible would hide
//  the very thing the canvas exists to show.
//
//  Space does come back in one place, and only one: what closes an open-ended block. See
//  `drawnEnd(of:in:)`, which is `ScheduleBlock.hasFinished(_:by:amongst:)`'s rule and not a second
//  opinion about it.
//

import CoreGraphics
import Foundation

/// A day's blocks, placed on the canvas.
///
/// Built from a day and read per block, exactly as `ScheduleConflicts` is and for the same reason
/// (`ScheduleConflicts.swift:14-19`): the packing is a walk of the whole day, `ScheduleView.body`
/// re-runs every time the app's clock ticks, and a day that has not changed cannot have changed
/// which of its blocks run alongside which.
struct ScheduleTimeline: Equatable, Sendable {

    // MARK: - The scale

    /// `2.0` — how many points one minute of the day is drawn as.
    ///
    /// Chosen so the grid's own step is legible rather than to fill a screen. `ScheduleResizePlan`
    /// snaps every edge to fifteen minutes, and at this ratio fifteen minutes is 30pt — one line of
    /// type, so the shortest block this app can express is still a block with a word on it. An hour
    /// is 120pt and the whole 07:00–20:00 day is 1560pt, about a screen and a half, which is the
    /// proportion Apple Calendar gives a day.
    ///
    /// **No minimum-height clamp is needed at this ratio, and that is why it was chosen.** A clamp
    /// is the obvious next thing to reach for and it is the thing that breaks the screen: two
    /// consecutive quarter-hour blocks inflated to a readable height would draw on top of each
    /// other, and from that moment the canvas is no longer telling the truth about when anything
    /// happens. A canvas whose geometry lies is worse than the list it replaced, because the list
    /// never claimed to be measuring anything.
    ///
    /// `span(of:in:)` does floor one thing, and says at length why that is not this: a block with
    /// no extent *inside the canvas at all* is given a step at the edge. Nothing it can touch is a
    /// block two consecutive quarter-hours could ever be.
    static let pointsPerMinute: CGFloat = 2.0

    /// The top of the canvas — 07:00.
    ///
    /// Restated from `BlockClock.options` rather than derived, the way `ScheduleResizePlan.step`
    /// restates the grid's spacing (`ScheduleResize.swift:56-64`): the clever spelling traps on an
    /// empty grid, and `ScheduleTimelineTests` asserts the two agree instead — so the day the camp
    /// clock moves it is a red test rather than a canvas quietly drawing hours nothing can be
    /// scheduled in.
    static let dayStart: TimeOfDay = BlockClock.options.first ?? TimeOfDay(7, 0)

    /// The bottom of it — 20:00.
    ///
    /// `ScheduleResizePlan.dayEnd` rather than a second `BlockClock.options.last`, and the
    /// borrowing is the point: the minute a drag stops at and the minute the canvas stops drawing
    /// are the same minute *by construction*. Written out twice they could differ by a grid step,
    /// and the symptom would be either a strip of canvas nothing can ever be dragged into or a
    /// block dragged off the bottom of the screen.
    static let dayEnd: TimeOfDay = ScheduleResizePlan.dayEnd

    /// `1560` — the whole day, in points.
    static let dayHeight: CGFloat = CGFloat(dayEnd.id - dayStart.id) * pointsPerMinute

    /// `120` — one hour of it, which is also the height of one row of the drawn grid.
    static let hourHeight: CGFloat = 60 * pointsPerMinute

    /// `30` — how far a finger travels for one `ScheduleResizePlan.step`.
    ///
    /// The ratio a drag is measured by, and on this screen it is no longer a chosen number: it is
    /// the height the grid draws that same fifteen minutes at, so the edge under the finger is the
    /// edge on the screen. `ScheduleResizePlan.travel` argues for its own 22 and stays as the
    /// default for the callers that have no geometry to hand; this is what the canvas passes.
    static let travelPerStep: CGFloat = pointsPerMinute * CGFloat(ScheduleResizePlan.step)

    /// The whole hours the canvas rules and labels: 07:00 … 19:00.
    ///
    /// Top-inclusive and bottom-exclusive, so thirteen rows of `hourHeight` come to exactly
    /// `dayHeight`. 20:00 gets no row of its own because it is the canvas's bottom edge rather than
    /// an hour anything can happen in — `BlockClock.endOptions(after:)` says the same thing from
    /// the other side, offering 20:00 as an end and never as a start with an end after it.
    ///
    /// Computed rather than written `7...19`, because `dayStart` is allowed to move and a grid
    /// starting at half past would otherwise rule its hours half an hour out.
    static let hours: [TimeOfDay] = {
        let first = (dayStart.id + 59) / 60
        let last = (dayEnd.id - 1) / 60
        guard first <= last else { return [] }
        return (first...last).map { TimeOfDay($0, 0) }
    }()

    /// The length a block gets when it is created by tapping empty canvas — one hour.
    ///
    /// The same hour `BlockEditorDraft(creatingIn:day:)` already defaults to
    /// (`BlockEditorDraft.swift:336-345`), restated so the two entrances into the composer do not
    /// hand somebody a different block depending on which one they used.
    static let draftLength = 60

    // MARK: - Points and minutes

    /// Where a time sits, in points down from the top of the canvas.
    ///
    /// Clamped into the day. A block outside 07:00–20:00 is not something this app can produce —
    /// the editor's two menus, the resize's ceiling and the move's walls are all `BlockClock` — but
    /// Postgres will hold one, and drawing it at a negative offset would put it above the scroll
    /// view's own top where nothing can reach it.
    static func y(for time: TimeOfDay) -> CGFloat {
        CGFloat(inside(time.id) - dayStart.id) * pointsPerMinute
    }

    /// How tall a span draws.
    ///
    /// Never negative, and never inflated: two times in, the points between them out, and a pair
    /// with nothing between them measures nothing. `pointsPerMinute` says why a minimum here would
    /// be the wrong repair, and `span(of:in:)` is where a block that would otherwise measure
    /// nothing is given somewhere to be — before the packing, so it displaces rather than covers.
    /// The distinction is that this is arithmetic about two times and that is a decision about a
    /// block.
    static func height(from startsAt: TimeOfDay, to endsAt: TimeOfDay) -> CGFloat {
        max(0, y(for: endsAt) - y(for: startsAt))
    }

    /// The time a point on the canvas means, snapped to the grid and inside the day.
    ///
    /// `ScheduleResizePlan.settled(_:between:and:)` rather than the same four lines a third time —
    /// that is the routine's whole argument for existing, and a tap on empty canvas has to land on
    /// exactly the grid line a drag would.
    static func time(atY y: CGFloat) -> TimeOfDay {
        ScheduleResizePlan.settled(
            CGFloat(dayStart.id) + y / pointsPerMinute,
            between: dayStart.id,
            and: dayEnd.id
        )
    }

    /// The span a tap on empty canvas proposes: an hour from where the finger landed.
    ///
    /// The start is held back from the day's last grid line so the hour has somewhere to go, and
    /// the end is trimmed to the bottom of the canvas — a tap at ten to eight in the evening makes
    /// a fifteen-minute block rather than one the editor's own end menu could not offer. The final
    /// `max` is what guarantees `BlockRules.endsAfterStart` on a grid too short to hold an hour,
    /// which is a shape no camp has and this type is not entitled to assume away.
    static func draftSpan(atY y: CGFloat) -> (startsAt: TimeOfDay, endsAt: TimeOfDay) {
        let step = ScheduleResizePlan.step
        let startMinutes = max(dayStart.id, min(time(atY: y).id, dayEnd.id - step))
        let endMinutes = max(startMinutes + step, min(startMinutes + draftLength, dayEnd.id))
        return (clock(startMinutes), clock(endMinutes))
    }

    private static func inside(_ minutes: Int) -> Int {
        min(max(minutes, dayStart.id), dayEnd.id)
    }

    // MARK: - Where one block draws

    /// One block's place on the canvas: its span as drawn, and its column within the blocks it
    /// runs alongside.
    struct Placement: Equatable, Sendable {

        /// Where the block is drawn from — its own start, clamped into the canvas.
        let startsAt: TimeOfDay
        /// …and to: the block's own end unless it runs open-ended (see
        /// `ScheduleTimeline.drawnEnd(of:in:)`), likewise clamped.
        let endsAt: TimeOfDay
        /// Which column, from zero on the left.
        let lane: Int
        /// How many columns the run of overlapping blocks this one belongs to was divided into.
        /// `1` for a block with nothing running alongside it, which is most of them.
        let laneCount: Int

        var y: CGFloat { ScheduleTimeline.y(for: startsAt) }
        var height: CGFloat { ScheduleTimeline.height(from: startsAt, to: endsAt) }

        /// This block's share of `width` points of canvas, with `gap` points between columns.
        ///
        /// The gap is a parameter rather than a constant here, so the one drawn number stays in
        /// `ScheduleMetrics` where the rest of what is drawn lives — the split
        /// `ScheduleTokens.swift:20-26` sets out.
        func width(in width: CGFloat, gap: CGFloat) -> CGFloat {
            guard laneCount > 1 else { return max(0, width) }
            return max(0, (width - gap * CGFloat(laneCount - 1)) / CGFloat(laneCount))
        }

        /// How far in from the left of the block area this column starts.
        func x(in width: CGFloat, gap: CGFloat) -> CGFloat {
            CGFloat(lane) * (self.width(in: width, gap: gap) + gap)
        }
    }

    /// Every block that has a place, by id. A day with nothing on it stores nothing at all.
    private let placements: [ScheduleBlock.ID: Placement]

    /// Where each block on `day` draws.
    ///
    /// One pass, in three parts: close the open-ended blocks, cut the day into runs of
    /// transitively overlapping blocks, and give each run its columns.
    init(day: [ScheduleBlock]) {
        // Sorted, because the input is not — `scheduleBlocks(forVenue:day:campID:)` orders by
        // `starts_at` and nothing else. The tie-break is `ScheduleBlock.running(in:at:)`'s
        // (`SectionEight.swift:462-467`), arbitrary but fixed, so two blocks starting on the same
        // minute do not swap columns between one read and the next.
        let spans = day
            .map { Self.span(of: $0, in: day) }
            // Branched rather than written as a tuple comparison, which reads better and costs
            // more than it looks: Swift builds both tuples before comparing either element, so
            // `uuidString` — a UUID formatted into a fresh 36-character String — would run twice
            // per comparison instead of only on the tie it is there to break. A twelve-block day
            // makes about thirty-five comparisons, so that is seventy allocations to settle a
            // question no ordinary day asks.
            // Written long rather than as a ternary, which the type-checker would not chew through
            // inside this chain.
            .sorted { lhs, rhs in
                if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        var placements: [ScheduleBlock.ID: Placement] = [:]
        // The run being built, and how far into the day anything in it reaches. A block starting
        // at or after that is the start of a new run: half-open, so a block ending exactly when
        // the next begins is an ordinary camp morning rather than an overlap — the same edge
        // `BlockRules.overlaps(_:_:)` draws (`BlockEditorDraft.swift:139-142`).
        var runStart = spans.startIndex
        var runEnd = Int.min

        for index in spans.indices {
            if index > runStart, spans[index].startsAt.id >= runEnd {
                Self.pack(spans[runStart..<index], into: &placements)
                runStart = index
                runEnd = Int.min
            }
            runEnd = max(runEnd, spans[index].endsAt.id)
        }
        if runStart < spans.endIndex {
            Self.pack(spans[runStart...], into: &placements)
        }

        self.placements = placements
    }

    /// Where `id` draws, or nil for a block that is not on this day.
    subscript(id: ScheduleBlock.ID) -> Placement? { placements[id] }

    // MARK: - The parts

    /// A block reduced to what the packing needs: an identity and a drawn span.
    private struct Span: Equatable, Sendable {
        let id: ScheduleBlock.ID
        let startsAt: TimeOfDay
        let endsAt: TimeOfDay
    }

    /// The span a block is drawn over: its end resolved, then both ends brought onto the canvas.
    ///
    /// Clamped **before** the packing rather than after it, so a block that begins before seven is
    /// packed against the blocks it will actually be drawn beside. Clamping only at the drawing end
    /// would place it in a run of its own and then draw it on top of a run it was never compared
    /// with.
    ///
    /// ── THE ONE FLOOR ─────────────────────────────────────────────────────────────────────────
    ///
    /// A span with nothing left after clamping — a block wholly before seven or after eight, which
    /// no path in this app can write but which Postgres will hold — is given one grid step at the
    /// edge it was clamped to. **This is not the minimum height `pointsPerMinute` was chosen to
    /// make unnecessary**, and the distinction is the whole of why it is allowed here: that clamp
    /// would inflate genuinely short blocks *inside* the day and make two consecutive quarter-hours
    /// draw over each other. This one cannot touch a block with any extent in the day at all. What
    /// it replaces is a card 0pt tall: no hit area, nothing to open or move or delete, and a header
    /// still counting it. A row nobody can reach is worse than a row drawn at the edge of the grid,
    /// and the row is now packed against whatever else is there, so it displaces rather than
    /// covers.
    private static func span(of block: ScheduleBlock, in day: [ScheduleBlock]) -> Span {
        let step = ScheduleResizePlan.step
        var lower = inside(block.startsAt.id)
        var upper = max(lower, inside(drawnEnd(of: block, in: day).id))

        if upper == lower {
            if lower + step <= dayEnd.id {
                upper = lower + step
            } else {
                lower = max(dayStart.id, dayEnd.id - step)
                upper = dayEnd.id
            }
        }

        return Span(id: block.id, startsAt: clock(lower), endsAt: clock(upper))
    }

    private static func clock(_ minutes: Int) -> TimeOfDay {
        TimeOfDay(minutes / 60, minutes % 60)
    }

    /// How far down the canvas a block reaches.
    ///
    /// A stated end is an end. An unstated one is closed by the next block that `sharesSpace` with
    /// it, and by the bottom of the canvas when nothing does.
    ///
    /// **That is `ScheduleBlock.hasFinished(_:by:amongst:)`'s rule** (`SectionEight.swift:496-522`)
    /// asked for a moment rather than about one, and it is stated the same way on purpose: read
    /// any other way, an 8:30 "Drop-off" with no end is the activity on every court all afternoon,
    /// and a canvas is the one place that sentence would be drawn at full height in front of
    /// everybody. That function is `private`, so this is the rule restated rather than called;
    /// `ScheduleTimelineTests` pins the two together on the cases that separate them.
    ///
    /// Deliberately **not** `BlockRules.latestEnd(for:in:)`, which is the same shape of question
    /// with one filter more — it skips a neighbour that has no stated end of its own, because it
    /// is offering advice a reader can check. An open-ended block standing behind another
    /// open-ended block is still stopped by it, so that filter would draw the first one straight
    /// through the second.
    private static func drawnEnd(of block: ScheduleBlock, in day: [ScheduleBlock]) -> TimeOfDay {
        if let endsAt = block.endsAt { return endsAt }
        // Two integer compares before the set-building one, the ordering `BlockRules.overlaps`
        // states and for its reason: on a day that is simply in order no set is ever built.
        let closing = day.lazy
            .filter { $0.startsAt > block.startsAt && BlockRules.sharesSpace($0, block) }
            .map(\.startsAt)
            .min()
        return closing ?? dayEnd
    }

    /// One run of overlapping blocks, divided into columns.
    ///
    /// Each block takes the lowest-numbered column that is free at its start; a column is free once
    /// the block in it has ended. The run's width is then divided by however many columns it turned
    /// out to need, so a pair splits the canvas in half and a lone block keeps all of it.
    ///
    /// The whole run shares one `laneCount`, which is what keeps the columns lined up: working it
    /// out per block would give the second of three overlapping blocks a different width from the
    /// third, and the canvas would read as a ragged edge rather than as columns.
    private static func pack(
        _ run: ArraySlice<Span>, into placements: inout [ScheduleBlock.ID: Placement]
    ) {
        // How far into the day each column is occupied to, in minutes.
        var laneEnds: [Int] = []
        var lanes: [(span: Span, lane: Int)] = []

        for span in run {
            // Half-open again: a column freed at 10:30 takes a block starting at 10:30.
            let lane = laneEnds.firstIndex { $0 <= span.startsAt.id } ?? laneEnds.count
            if lane == laneEnds.count {
                laneEnds.append(span.endsAt.id)
            } else {
                laneEnds[lane] = span.endsAt.id
            }
            lanes.append((span, lane))
        }

        for (span, lane) in lanes {
            placements[span.id] = Placement(
                startsAt: span.startsAt,
                endsAt: span.endsAt,
                lane: lane,
                laneCount: laneEnds.count
            )
        }
    }
}
