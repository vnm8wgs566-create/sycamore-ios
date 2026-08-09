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
//  warning that changes only when somebody writes a block. `ScheduleView.swift:286-291` already
//  records this screen paying that bill once for `currentBlockIDs`.
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
}
