//
//  ScheduleConflicts.swift
//  Sycamore
//
//  Which blocks on a day clash with which, worked out once for the whole day.
//
//  The rule is `BlockRules.overlap(with:in:)` and none of it is restated here. What this type is
//  for is *when* the rule is asked.
//
//  Asking it per card is O(N²) — every card walks the whole day — and `ScheduleView.body` re-runs
//  every time the app's clock ticks, because it reads `store.timeOfDay` to mark the block running
//  now. So the naive spelling pays a whole day of pair comparisons a minute, for ever, to draw a
//  warning that changes only when somebody writes a block. This screen used to record the same
//  bill being paid once for a `currentBlockIDs` set; that set is gone — the calendar canvas asks
//  `ScheduleBlock.running(in:at:)` from `ScheduleBlockLayer`, which is its own `View` precisely so
//  a clock tick invalidates the layer and not the day around it.
//
//  So the index is built from `.onChange(of: blocks, initial: true)` and held, rather than
//  computed in a body: it depends on exactly one value, and that value is what re-derives it.
//  There is no second source of truth to keep in step — a day that has not changed cannot have
//  changed which of its blocks clash.
//
//  It holds the other *block* rather than the sentence about it, so the wording stays in
//  `ScheduleBlockPresentation` with the rest of `8k`'s copy.
//

import Foundation

/// A day's clashes, by block.
struct ScheduleConflicts: Sendable {

    /// The block each block clashes with. A block that clashes with nothing has no entry, so the
    /// common case — a morning that is simply in order — stores nothing at all.
    private let clashes: [ScheduleBlock.ID: ScheduleBlock]

    /// One pass over the day, asking the rule the same question each card would have asked.
    ///
    /// Deliberately N calls to `BlockRules.overlap(with:in:)` rather than one hand-rolled sweep
    /// over pairs. A sweep would be the same order of work with a second copy of the rule inside
    /// it, and the one thing this index must never do is disagree with the editor about what a
    /// clash is.
    init(day: [ScheduleBlock]) {
        var clashes: [ScheduleBlock.ID: ScheduleBlock] = [:]
        for block in day {
            clashes[block.id] = BlockRules.overlap(with: block, in: day)
        }
        self.clashes = clashes
    }

    /// The block `id` clashes with, or nil.
    subscript(id: ScheduleBlock.ID) -> ScheduleBlock? { clashes[id] }

    /// What a block runs into at the times a **finger** is holding it at, rather than at the times
    /// the store has for it.
    ///
    /// The index above cannot answer this and should not be made to. It is keyed on a day that has
    /// landed, and a drag is a day that has not: `8k`'s amber line was the *pre-drag* clash for the
    /// whole of every gesture, saying nothing about the one being created and — worse — still
    /// naming one that had just been dragged out of. The finger is the one moment on this screen
    /// when the flag is about a decision somebody is still making.
    ///
    /// **`BlockRules.overlap(with:in:)` again, and not a second spelling of it.** That is this
    /// type's own argument (`:36-41`) and it holds harder here: a live line disagreeing with the
    /// line that appears a round trip later would be the app contradicting itself across a single
    /// lift of a finger. The block is copied and its times overwritten because the rule takes a
    /// block and this screen has a plan; `BlockEditorDraft.overlap(in:)` builds its own draft block
    /// the same way for the same reason.
    ///
    /// `day` may — and normally does — still hold this block at its stored times. That copy is not
    /// a clash with itself: `overlap(with:in:)` drops `$0.id == block.id` before it compares, so
    /// the stale twin is invisible to the question rather than something a caller has to strip out
    /// first.
    ///
    /// **Cost.** One walk of the day per call, which is what a card would have paid per body. Its
    /// callers are `ScheduleBlockCard.trackResize`/`trackMove`, which run only when the *settled*
    /// quarter-hour changes — four to eight times across a whole drag, not once a frame — so this
    /// adds nothing to the per-tick bill the header above is written to protect.
    static func live(
        _ block: ScheduleBlock,
        startsAt: TimeOfDay,
        endsAt: TimeOfDay?,
        in day: [ScheduleBlock]
    ) -> ScheduleBlock? {
        var live = block
        live.startsAt = startsAt
        live.endsAt = endsAt
        return BlockRules.overlap(with: live, in: day)
    }
}
