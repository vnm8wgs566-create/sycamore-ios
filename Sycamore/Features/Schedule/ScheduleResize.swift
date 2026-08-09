//
//  ScheduleResize.swift
//  Sycamore
//
//  What a finger on a block's bottom edge does to the block's end time — the arithmetic, with no
//  view in it.
//
//  Lifted out for the reason `SwipeRevealPlan` was (`SwipeToDelete.swift:81-86`) and
//  `GroupsLandingPlan` before it (`GroupsLandingPlan.swift:7-11`): every threshold below decides
//  something a person can otherwise only check by putting a finger on a device, and every way it
//  can be wrong looks right. The edge moves, a time is written, nothing throws.
//
//  It moves the **end** and never the start. `8k` is a list in time order rather than a timeline —
//  a fifteen-minute block and a two-hour block draw the same height — so there is no proportional
//  height for a drag to be measured against and no top edge worth grabbing. The mapping from
//  travel to minutes is therefore a chosen ratio rather than a geometric one, and the ratio is
//  `ScheduleMetrics.resizeTravel`, which argues for its own number.
//
//  There is no overlap validation anywhere. Not in Swift, and not in Postgres: the only time CHECK
//  on `schedule_blocks` is `schedule_blocks_ends_after_starts` (`20260805074039:38-39`), which
//  says nothing at all about the *next* block. A resize dragged past its neighbour would be
//  accepted by every layer and simply be wrong — one block silently swallowing the start of
//  another on a screen whose whole job is saying what happens when. `ceiling` is where that is
//  stopped, and here is the only place it is stopped.
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
    /// Fifteen, which is `BlockClock.options`' own spacing (`BlockEditorDraft.swift:89`) rather
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

    /// `22` — how far a finger travels for one `step` of the block's end.
    ///
    /// Here rather than in `ScheduleMetrics`, and that is where `SwipeMetrics.actionWidth` sits
    /// too (`SwipeToDelete.swift:32-43`): this is not a drawn dimension. `8k` is a list and not a
    /// timeline, so there is no height on the screen a drag could be measured against and the
    /// ratio had to be chosen — which makes it a property of the arithmetic below rather than of
    /// anything transcribed. What *is* drawn — the grabber, its column — is in `ScheduleMetrics`.
    ///
    /// An hour costs 88pt, a little more than a card's own height, so a drag of "about one card"
    /// reads as about an hour. Half of it, 11pt, is the deadzone before anything moves at all,
    /// which is about the travel the platform itself already treats as a drag rather than as a
    /// touch — `SwipeMetrics.axisLock` arrives at 12 from the other side and says why.
    static let travel: CGFloat = 22

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
    ///   - nextStart: the block that starts next, or nil when this is the day's last. See
    ///     `nextStart(after:in:)`.
    ///   - dayEnd: injected so a test can ask what happens at the end of the grid without
    ///     building an evening.
    init(
        startsAt: TimeOfDay,
        endsAt: TimeOfDay,
        nextStart: TimeOfDay?,
        dayEnd: TimeOfDay = ScheduleResizePlan.dayEnd,
        travelPerStep: CGFloat = ScheduleResizePlan.travel
    ) {
        self.startsAt = startsAt
        self.restingEnd = endsAt
        self.endsAt = endsAt
        self.travelPerStep = travelPerStep

        // The shortest block the grid can express: the first grid line strictly after the start.
        // Strictly, because `check (ends_at is null or ends_at > starts_at)` is strict — a block
        // that ends when it starts is not a block (`BlockEditorDraft.swift:62-74`).
        let shortest = Self.step * (startsAt.id / Self.step + 1)
        // …but never longer than the block already is. A block already shorter than one grid step
        // is data this app cannot produce and Postgres will happily hold, and a plan whose floor
        // sat above its resting end would lengthen that block the instant a finger touched the
        // handle — before any travel at all.
        self.floor = min(endsAt.id, shortest)

        // Clamped at the next block's start, because nothing else clamps it. Abutting is allowed
        // and overlapping is not: a block that ends exactly when the next begins is an ordinary
        // camp morning, and one that ends a minute later is two blocks claiming the same minute.
        let wall = min(nextStart?.id ?? dayEnd.id, dayEnd.id)
        // …and again never shorter than the block already is. A day that already overlaps — or a
        // block that already runs past eight — can be shortened out of it, but touching the
        // handle must not shorten it on its own.
        self.ceiling = max(endsAt.id, wall)
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
    /// `ScheduleBlock.timeLabel`'s spelling (`SectionEight.swift:118-121`), restated rather than
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

    /// Onto the grid, then inside the walls — in that order, and the order is load-bearing.
    ///
    /// Snapping a value that has already been clamped would push it straight back out of the wall
    /// it was just held at: a neighbour starting at 10:20 would round to 10:15 and leave the block
    /// five minutes short of a gap it is allowed to fill. Clamping second means the walls win, and
    /// a block may end exactly when its neighbour begins even when that moment is off-grid.
    ///
    /// Rounds to the nearest step rather than towards zero, so the edge lands on the grid line
    /// nearest the finger. Truncating instead would make the first half of every step inert and
    /// the edge would lag the finger by up to fifteen minutes; what a nudge must not do is *creep*,
    /// and half a step — `ScheduleMetrics.resizeTravel / 2` — is the deadzone that stops it.
    private func settled(_ minutes: CGFloat) -> TimeOfDay {
        let step = CGFloat(Self.step)
        // Bounded before the conversion rather than after it. `Int(_:)` traps on a value past
        // `Int.max`, and the travel is a number this type is handed rather than one it controls;
        // one step of slack either side leaves every reachable answer untouched.
        let bounded = min(max(minutes, CGFloat(floor) - step), CGFloat(ceiling) + step)
        let onGrid = Int((bounded / step).rounded() * step)
        let clamped = min(max(onGrid, floor), ceiling)
        return TimeOfDay(clamped / 60, clamped % 60)
    }
}

// MARK: - The neighbour

extension ScheduleResizePlan {

    /// The start of the block after this one, which is as far as this one's end may be dragged.
    ///
    /// Read off the day rather than off an index, because `8k`'s list is only sorted by
    /// convention: `scheduleBlocks(forVenue:day:campID:)` returns whatever order the query gives
    /// and nothing in Swift re-sorts it. The smallest start strictly after this block's own is the
    /// answer whichever order the array arrives in.
    ///
    /// Finished blocks count. A `.done` drop-off draws as one grey line rather than as a card, but
    /// it still occupies eight-thirty to nine, and a block allowed to grow over it would be wrong
    /// in exactly the way a block allowed to grow over a planned one is.
    ///
    /// Two blocks sharing a start neither follow nor clamp each other — they already overlap, and
    /// this is a wall against making an overlap, not a repair for one that is already there.
    static func nextStart(after block: ScheduleBlock, in blocks: [ScheduleBlock]) -> TimeOfDay? {
        blocks.map(\.startsAt).filter { $0 > block.startsAt }.min()
    }
}
