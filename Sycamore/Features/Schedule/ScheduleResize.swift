//
//  ScheduleResize.swift
//  Sycamore
//
//  What a finger on a block does to the block's times — the arithmetic, with no view in it. Two
//  plans: `ScheduleResizePlan` moves the end, `ScheduleMovePlan` moves both together.
//
//  Lifted out for the reason `SwipeRevealPlan` was (`SwipeToDelete.swift:81-86`) and
//  `GroupsLandingPlan` before it (`GroupsLandingPlan.swift:7-11`): every threshold below decides
//  something a person can otherwise only check by putting a finger on a device, and every way it
//  can be wrong looks right. The edge moves, a time is written, nothing throws.
//
//  ── THE RATIO IS GEOMETRIC NOW ────────────────────────────────────────────────────────────────
//
//  This header used to argue that it could not be. `8k` was a list in time order rather than a
//  timeline — a fifteen-minute block and a two-hour block drew the same height — so there was no
//  proportional height for a drag to be measured against, the mapping from travel to minutes had
//  to be a chosen number, and `ScheduleBlockCard` could offer nothing but a text capsule while a
//  finger was down.
//
//  `8k` is a duration-proportional canvas now (`ScheduleTimeline.swift`), so all of that is
//  false. `travelPerStep` is an `init` parameter and always was; what changed is what the screen
//  passes it — `ScheduleTimeline.travelPerStep`, which is the height the grid itself draws fifteen
//  minutes at. The edge is under the finger because the two are the same number, rather than
//  because a number was tuned until they looked alike. `travel` survives as the default for the
//  callers with no geometry in hand, and says so.
//
//  There is a top edge worth grabbing now too, and `ScheduleMovePlan` is what a hand on it does.
//
//  ── THE NEIGHBOUR IS NO LONGER A WALL ─────────────────────────────────────────────────────────
//
//  `ceiling` used to be clamped at the next block's start, and this header used to say that here
//  was the only place an overlap was stopped. It is not stopped anywhere now, and that is the
//  decision rather than a regression.
//
//  An overlap is a *flag*: `BlockRules.overlap(with:in:)` holds the rule and argues the case, and
//  `ScheduleBlockCard` draws an amber line naming what a block runs into. The editor's two time
//  menus will take an overlapping end and save it. A drag that refused one would be the second
//  answer to a question that now has one — and the day the two disagreed, the disagreement would
//  be invisible, because a wall does not announce itself.
//
//  There is a stronger reason than consistency, and it is the same one that sank the constraint.
//  The wall was keyed on the *day*: the earliest start after this block's own, whatever that block
//  was doing. With `ScheduleBlockKind.assigned` and `courtIDs`, "Warm-up on Court 1" and "Free
//  play on Courts 2–4" may share a morning, so a finger on Court 1's bottom edge would have been
//  stopped by a block on courts it never touches. A court-aware wall was the obvious repair and is
//  worse than none: the minute a drag stopped at would depend on which courts were ticked inside
//  a sheet that is not open, so the same gesture on two cards would stop in different places for
//  reasons nothing on screen could explain.
//
//  What is left is the arithmetic of the *grid* — a step, a floor at the shortest block the CHECK
//  allows, and a ceiling at the end of the camp day. Those are all still walls, and all three are
//  about what this app can express rather than about what else is on the morning.
//

import Foundation

/// One block's bottom edge, mid-drag.
///
/// Built when the finger lands, fed the drag's travel, and read for the end time to write. The
/// walls it will not cross are decided once, in `init`, from where the block sat at that moment —
/// so a plan cannot be made to clamp against a list that has changed underneath it.
struct ScheduleResizePlan: Equatable, Sendable {

    // MARK: The grid

    /// The grid every end time lands on, in minutes.
    ///
    /// Fifteen, which is `BlockClock.options`' own spacing (`BlockEditorDraft.swift:229`) rather
    /// than a second opinion about it: the editor's two time menus offer quarter-hours, so a
    /// resize snapping to anything else would write a time its own editor could not read back.
    ///
    /// Restated rather than derived as `options[1].id - options[0].id`, which is a clever line
    /// that traps on a one-entry grid. `ScheduleResizeTests` asserts the two agree instead, so the
    /// day the grid moves it is a red test rather than a silent divergence.
    static let step = 15

    /// The last time on that grid — 20:00.
    ///
    /// A camp day does not run past eight in the evening, and a block dragged beyond the grid
    /// would be a block its own editor cannot offer an end for.
    static let dayEnd: TimeOfDay = BlockClock.options.last ?? TimeOfDay(20, 0)

    /// `22` — how far a finger travels for one `step`, when nobody says otherwise.
    ///
    /// **A default and no longer a decision.** `8k` draws a proportional canvas now, so the screen
    /// passes `ScheduleTimeline.travelPerStep` — 30pt, the height the grid rules a quarter of an
    /// hour at — and the edge lands where the finger is because the two numbers are one number.
    /// This paragraph used to argue at length that no such height existed to measure against.
    ///
    /// Its readers today are the two test suites, which state their cases in points and so need a
    /// ratio that does not move when the canvas is retuned. That is thin ground for a constant and
    /// it is worth being exact about: the VoiceOver rotor is *not* a second reader, because
    /// `adjusted(by:)` never touches a ratio at all — a rotor step is one grid step whatever the
    /// screen looks like. What keeps it is that a plan built without a ratio still has to settle
    /// somewhere sane, and 22 is a working drag rather than a zero.
    ///
    /// Here rather than in `ScheduleMetrics`, and that is where `SwipeMetrics.actionWidth` sits too
    /// (`SwipeToDelete.swift:32-43`): it is a fallback belonging to the arithmetic below rather
    /// than a dimension anything draws. What *is* drawn — the grabber, its column — is in
    /// `ScheduleMetrics`.
    static let travel: CGFloat = 22

    /// A minute onto the grid, then inside a pair of walls — in that order, and the order is
    /// load-bearing.
    ///
    /// One function because there are three callers and the order is the thing every comment on it
    /// calls load-bearing: this plan's `settled`, `ScheduleMovePlan`'s, and
    /// `ScheduleTimeline.time(atY:)`, which asks the same question of a point on the canvas. Three
    /// copies is three places to get it right and two places for a fix to be silently missed.
    ///
    /// Snapping a value that has already been clamped would push it straight back out of the wall
    /// it was just held at. The floor is where that shows: a 9:00–9:05 block has a floor of 9:05,
    /// and snapping *after* clamping would round that to 9:00 — an end equal to its start, which is
    /// the one thing `ends_after_starts` forbids. Clamping second means the walls win, and a value
    /// may sit exactly on one even when that moment is off-grid.
    ///
    /// Rounds to the nearest step rather than towards zero, so an edge lands on the grid line
    /// nearest the finger. Truncating instead would make the first half of every step inert and the
    /// edge would lag the finger by up to fifteen minutes; what a nudge must not do is *creep*, and
    /// half a step is the deadzone that stops it.
    static func settled(_ minutes: CGFloat, between floor: Int, and ceiling: Int) -> TimeOfDay {
        let step = CGFloat(Self.step)
        // Bounded before the conversion rather than after it. `Int(_:)` traps on a value past
        // `Int.max`, and the travel is a number these types are handed rather than one they
        // control; one step of slack either side leaves every reachable answer untouched.
        let bounded = min(max(minutes, CGFloat(floor) - step), CGFloat(ceiling) + step)
        let onGrid = Int((bounded / step).rounded() * step)
        let clamped = min(max(onGrid, floor), ceiling)
        return TimeOfDay(clamped / 60, clamped % 60)
    }

    /// The frame a drag is measured in.
    ///
    /// The name lives beside the arithmetic that assumes it rather than on the screen that
    /// declares the space, so the screen and the card both depend downwards on this file instead
    /// of the card depending upwards on the screen. `RankView.swift:40` can keep its own private
    /// because there the gesture and the space are declared in one type; here they are not.
    static let listSpace = "schedule.list"

    // MARK: Where the block sat when the finger landed

    /// The block's start. A bottom-edge drag never moves it — which is what makes this a `let`,
    /// and what makes the whole of `schedule_blocks_ends_after_starts` a question about `floor`.
    let startsAt: TimeOfDay

    /// Where the block ended when the finger landed. A drag of nothing settles back on exactly
    /// this, which is what stops merely touching the handle changing anything.
    let restingEnd: TimeOfDay

    /// The walls, in minutes past midnight, both inclusive.
    ///
    /// Each is widened to admit `restingEnd` if it has to be — see `init`. That is the invariant
    /// the rest of this type rests on: the resting end is always inside the walls, so a plan can
    /// never move a block that has not been dragged.
    let floor: Int
    let ceiling: Int

    /// How far a finger travels for one `step`.
    let travelPerStep: CGFloat

    /// Where the end sits right now: snapped to the grid and inside the walls, at every moment
    /// and not only on release.
    private(set) var endsAt: TimeOfDay

    // MARK: Building one

    /// - Parameters:
    ///   - endsAt: not optional, deliberately. `ScheduleBlock.endsAt` is — a block may run
    ///     open-ended — but a block with no end has no bottom edge to drag and no span to draw,
    ///     so the card does not offer a handle at all rather than this type inventing one.
    ///   - dayEnd: injected so a test can ask what happens at the end of the grid without
    ///     building an evening.
    ///
    /// It takes no neighbour. It used to, and the header says at length why it no longer does.
    init(
        startsAt: TimeOfDay,
        endsAt: TimeOfDay,
        dayEnd: TimeOfDay = ScheduleResizePlan.dayEnd,
        travelPerStep: CGFloat = ScheduleResizePlan.travel
    ) {
        self.startsAt = startsAt
        self.restingEnd = endsAt
        self.endsAt = endsAt
        self.travelPerStep = travelPerStep

        // The shortest block the grid can express: the first grid line strictly after the start.
        // Strictly, because `check (ends_at is null or ends_at > starts_at)` is strict — a block
        // that ends when it starts is not a block (`BlockEditorDraft.swift:73-85`).
        let shortest = Self.step * (startsAt.id / Self.step + 1)
        // …but never longer than the block already is. A block already shorter than one grid step
        // is data this app cannot produce and Postgres will happily hold, and a plan whose floor
        // sat above its resting end would lengthen that block the instant a finger touched the
        // handle — before any travel at all.
        self.floor = min(endsAt.id, shortest)

        // The end of the camp day, and nothing about the neighbours. A block dragged over the one
        // after it is a morning the camp is allowed to have and the card is about to flag; the
        // grid's own last line is where the *editor* stops offering ends, so a drag past it would
        // write a time its own menu cannot read back.
        //
        // …and never shorter than the block already is. A block that already runs past eight can
        // be shortened out of it, but touching the handle must not shorten it on its own.
        self.ceiling = max(endsAt.id, dayEnd.id)
    }

    // MARK: What the drag produces

    /// True once the drag has actually moved the end off where it started.
    ///
    /// The commit is guarded on this. `AppStore.perform` tracks in-flight work with a single
    /// `Bool` (`AppStore.swift:1111-1119`), so a write that changes nothing still flickers the
    /// screen's spinner and still costs a round trip.
    var hasMoved: Bool { endsAt != restingEnd }

    /// `9:00am – 10:15am` — the span the block will have if the finger lifts now.
    ///
    /// `ScheduleBlock.timeLabel`'s spelling (`SectionEight.swift:156-160`), restated rather than
    /// borrowed because a plan holds two times and not a block. The two are tested against each
    /// other so the live readout and the card underneath it cannot start disagreeing.
    var spanLabel: String { "\(startsAt.clockLabel) – \(endsAt.clockLabel)" }

    /// One `onChanged`.
    ///
    /// - Parameter height: the drag's vertical travel in points, downward positive — a longer
    ///   block. Measured in the list's own named coordinate space; see `ScheduleView.listSpace`.
    mutating func drag(by height: CGFloat) {
        endsAt = settled(CGFloat(restingEnd.id) + height * CGFloat(Self.step) / travelPerStep)
    }

    /// One step of the rotor, for the adjustable action that is the non-pointer route to the same
    /// answer. Non-mutating: VoiceOver adjusts the block rather than a live drag, so each call
    /// starts again from where the block actually sits.
    func adjusted(by steps: Int) -> TimeOfDay {
        settled(CGFloat(restingEnd.id + steps * Self.step))
    }

    /// Onto the grid, then inside this plan's own two walls. The order, and why it is load-bearing,
    /// is on `ScheduleResizePlan.settled(_:between:and:)`.
    ///
    /// The neighbour used to be the example that argument gave, and it is gone with the clamp.
    private func settled(_ minutes: CGFloat) -> TimeOfDay {
        Self.settled(minutes, between: floor, and: ceiling)
    }
}

// `ScheduleResizePlan.nextStart(after:in:)` used to be here: four lines finding the smallest start
// after this block's own, so `init` could clamp against it. Both are gone, and what replaced the
// answer is `BlockRules.latestEnd(for:in:)` — the same shape of question asked court-aware, which
// the block editor quotes in words rather than enforcing in a gesture.
//
// A forwarding shim was considered and is worse than either: it would keep a name that means
// "wall" alive in a file that no longer has one.

// MARK: - Moving a block

/// One block being carried up or down the canvas, mid-drag.
///
/// `ScheduleResizePlan`'s shape, one axis over: built when the finger lands, fed the drag's travel,
/// read for the two times to write. It moves `startsAt` and `endsAt` **together** — the block keeps
/// its length and changes when it happens, which is the one thing the resize cannot express and the
/// thing the canvas made askable. A morning that has slipped twenty minutes is a drag now rather
/// than four taps through two menus.
///
/// It has the same three properties that make its sibling safe. The walls are decided once, in
/// `init`, from where the block sat at that moment, so a plan cannot be made to clamp against a day
/// that has changed underneath it. They are widened to admit the resting start, so a finger that
/// lands and lifts writes nothing. And it snaps to `ScheduleResizePlan.step`, so every start it can
/// produce is one the editor's own menu could offer back.
///
/// **It adds no overlap wall either**, and that is the same decision rather than a second one. A
/// block dragged over its neighbour is a morning the camp is allowed to have; the amber line names
/// it and, since `8k` became a canvas, the two now visibly sit side by side. The long argument is
/// in this file's header and in `BlockRules.overlap(with:in:)`.
struct ScheduleMovePlan: Equatable, Sendable {

    // MARK: Where the block sat when the finger landed

    /// The block's start when the finger landed. A drag of nothing settles back on exactly this,
    /// which is what stops merely picking a card up changing anything.
    let restingStart: TimeOfDay

    /// Its end at that moment, or nil for a block running open-ended.
    let restingEnd: TimeOfDay?

    /// How long the block is, in minutes, or nil when it has no stated end.
    ///
    /// Held rather than recomputed from the two times on every frame, because it is the invariant:
    /// a move is the one gesture that must not change it, and a length read back out of a clamped
    /// pair of times is a length that can quietly shrink at a wall.
    private let length: Int?

    /// The walls, as the earliest and latest start, both inclusive.
    ///
    /// Each widened to admit `restingStart` — see `init`. A block already sitting outside the grid
    /// keeps its place until it is actually dragged.
    let floor: Int
    let ceiling: Int

    /// How far a finger travels for one `ScheduleResizePlan.step`.
    let travelPerStep: CGFloat

    /// Where the start sits right now: snapped to the grid and inside the walls, at every moment
    /// and not only on release.
    private(set) var startsAt: TimeOfDay

    /// …and the end that follows it, still `length` minutes later, still nil if it always was.
    var endsAt: TimeOfDay? { end(after: startsAt) }

    private func end(after start: TimeOfDay) -> TimeOfDay? {
        guard let length else { return nil }
        let minutes = start.id + length
        return TimeOfDay(minutes / 60, minutes % 60)
    }

    // MARK: Building one

    /// - Parameters:
    ///   - endsAt: optional, unlike `ScheduleResizePlan`'s. A block with no stated end has no
    ///     bottom edge to drag, which is why that type refuses one — but it has a start, and a
    ///     start is the whole of what this one moves.
    ///   - dayStart / dayEnd: injected so a test can ask what happens at either end of the grid
    ///     without building a morning around it.
    init(
        startsAt: TimeOfDay,
        endsAt: TimeOfDay?,
        dayStart: TimeOfDay = ScheduleTimeline.dayStart,
        dayEnd: TimeOfDay = ScheduleTimeline.dayEnd,
        travelPerStep: CGFloat = ScheduleResizePlan.travel
    ) {
        self.restingStart = startsAt
        self.restingEnd = endsAt
        self.startsAt = startsAt
        self.travelPerStep = travelPerStep
        // Nil rather than zero for an open end, so `endsAt` cannot invent one. A negative length is
        // data the CHECK forbids and Postgres would still hold; carried as it is rather than
        // repaired, because a move is not the gesture that gets to decide a block's length.
        self.length = endsAt.map { $0.id - startsAt.id }

        // The top of the grid, …and never later than the block already starts. A block that begins
        // before seven can be dragged into the day, but picking it up must not drag it on its own.
        self.floor = min(startsAt.id, dayStart.id)

        // The bottom of the grid, less the block's own length, so the *end* is what stops at 20:00
        // rather than the start — which is the whole of "clamped so neither end leaves the day". A
        // block with no end has none to keep inside, so its start may reach the grid's last line;
        // that is exactly the block `BlockClock` can express there, since `endOptions(after:)`
        // offers nothing after 20:00 and a block starting on it can only be open-ended.
        //
        // …and never earlier than the block already starts, for `floor`'s reason from the other
        // side: an evening block that already runs past eight keeps its place until it is dragged.
        // The two widenings together are what guarantee `floor <= ceiling` on any pair of times.
        self.ceiling = max(startsAt.id, dayEnd.id - (self.length ?? 0))
    }

    // MARK: What the drag produces

    /// True once the drag has actually moved the block off where it started. The commit is guarded
    /// on this, for the reason `ScheduleResizePlan.hasMoved` gives: `AppStore.perform` tracks
    /// in-flight work with a single `Bool`, so a write that changes nothing still costs a round
    /// trip and still flickers the screen's spinner.
    var hasMoved: Bool { startsAt != restingStart }

    /// `9:00am – 10:15am`, or `8:30am` for a block with no stated end.
    ///
    /// `ScheduleBlock.timeLabel`'s spelling (`SectionEight.swift:157-160`) including its nil case,
    /// restated rather than borrowed because a plan holds two times and not a block. The two are
    /// tested against each other so a live readout and the card under it cannot start disagreeing.
    var spanLabel: String {
        guard let endsAt else { return startsAt.clockLabel }
        return "\(startsAt.clockLabel) – \(endsAt.clockLabel)"
    }

    /// One `onChanged`.
    ///
    /// - Parameter height: the drag's vertical travel in points, downward positive — a later block.
    ///   Measured in the canvas's own named coordinate space; see `ScheduleResizePlan.listSpace`.
    mutating func drag(by height: CGFloat) {
        let step = CGFloat(ScheduleResizePlan.step)
        startsAt = settled(CGFloat(restingStart.id) + height * step / travelPerStep)
    }

    /// One step of the rotor, for the adjustable action that is the non-pointer route to the same
    /// answer. Non-mutating, like its sibling's: VoiceOver adjusts the block rather than a live
    /// drag, so each call starts again from where the block actually sits.
    ///
    /// Returns **both** times, where `ScheduleResizePlan.adjusted(by:)` returns one — because a
    /// move writes both, and a caller left to add the length back on itself is a second place the
    /// length could be got wrong. Non-mutating is also what lets `#expect` call it: Swift Testing's
    /// macro cannot reach a `mutating` member.
    func adjusted(by steps: Int) -> (startsAt: TimeOfDay, endsAt: TimeOfDay?) {
        let start = settled(CGFloat(restingStart.id + steps * ScheduleResizePlan.step))
        return (start, end(after: start))
    }

    /// Onto the grid, then inside this plan's own two walls — the shared routine, for the reason it
    /// gives for being shared.
    private func settled(_ minutes: CGFloat) -> TimeOfDay {
        ScheduleResizePlan.settled(minutes, between: floor, and: ceiling)
    }
}
