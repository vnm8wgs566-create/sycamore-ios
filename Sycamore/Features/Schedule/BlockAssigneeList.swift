//
//  BlockAssigneeList.swift
//  Sycamore
//
//  What is left of "Logistics" on `8l`: the one line of it that was not a drawing.
//
//  ── The card this file is named after is gone ────────────────────────────────────────────────
//
//  It was a `Card` of facts — When, Where, Courts — over a row per coach, headed by a tracked
//  uppercase overline. `5d` (`design/rebuild/section-t5.html:179-226`) replaces all four of those
//  facts and every one of its rows. When and where moved up into the header subtitle, which now
//  reads `10:45 – 12:15 · Sycamore · 3 courts` and says the same three things in one line; who is
//  running it moved down into `BlockCourtCard`, one card per court, because the question the
//  screen is actually opened with is not "who is on this block" but "is Court 2 covered" — and a
//  single list of names over a three-court block cannot answer it. The overline went with the
//  rest: `5d` distils five section headers into flat labels, and no new screen introduces tracked
//  caps.
//
//  Its "Nobody assigned · Assign" row is the one piece worth naming as *moved* rather than
//  deleted. That row's own comment argued that hiding an empty card is how a block goes uncovered
//  quietly, and that `ScheduleBlockStatus.needsCoach` had been drawing the fact in amber on `8k`
//  with nowhere to act on it. Both halves still hold and are now said per court, in amber, beside
//  a control that opens `4d` — which is a better answer to that comment than the comment's own
//  was, since "Assign" here opened the whole block editor.
//
//  ── Why the file stayed ──────────────────────────────────────────────────────────────────────
//
//  `coaches(on:in:)` is not a drawing. It is the rule about resolving a block's coach ids against
//  a camp — specifically the rule that an id which no longer resolves is *ordinary* rather than a
//  bug — and four other files cite it by name at this address, three of which are not this unit's
//  to edit. Moving it would have been a rename dressed as a tidy-up. An `enum` rather than the
//  `View` struct it hung off, because a namespace that cannot be instantiated is what it now is,
//  and because a `View`'s statics inherit its `@MainActor` inference for nothing — the reason
//  `BlockCoachPicker.pool` had to spell `nonisolated`.
//

import SwiftUI

// MARK: - Resolving the block's coaches

enum BlockAssigneeList {

    /// `block.coachIDs` against `camp.staff`, in the order the block names them.
    ///
    /// `compactMap`, never `first(where:)!`. `removeStaff` deactivates rather than deletes, so an
    /// id on a block can outlive the person's presence in `camp.staff` — that row is a fact about
    /// last Tuesday, not a dangling pointer, and it drops out of the list rather than taking the
    /// screen with it.
    ///
    /// The block as a whole, deliberately: this is the answer for a `.regular` block, which names
    /// no courts to ask about. `BlockCourtCard.coaches(on:court:in:)` is the per-court reader and
    /// calls straight through to this one when it is handed no court, so the two cannot come to
    /// disagree about a lunch.
    static func coaches(on block: ScheduleBlock, in camp: Camp?) -> [StaffMember] {
        guard let camp else { return [] }
        return block.coachIDs.compactMap { id in camp.staff.first { $0.id == id } }
    }
}
