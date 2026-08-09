//
//  CourtCapacity.swift
//  Sycamore
//
//  How full a court is — "8 of 8", "6 of 8 · 2 spots", "7 of 8 · 1 spot".
//
//  The one thing `8i` draws on every open card that the app drew nowhere. Overview's whole job on
//  a camp morning is which courts are running and how many kids are on them, and the screen could
//  say the second half only as prose in a subtitle ("Court 1 – 8 players") with nothing to measure
//  it against. A number with no denominator cannot answer the question an admin actually has,
//  which is *where is there room*.
//
//  ── Where the two numbers come from ──────────────────────────────────────────────────────────
//
//  They come from two different places, and that is the reason this is a type and not a string
//  interpolated in a view.
//
//      here      `CourtCard.playersHere`, off the `today_courts` row.
//      capacity  `Group.capacity`, off the camp graph.
//
//  The numerator is deliberately the card's and not the group's `presentCount`, even though the
//  two are the same count derived the same way (`SectionEightRepository.swift:342-343` against
//  `Camp.reindex` in `Models.swift:1116`). `playersHere` is what everything else on this card is
//  already drawn from — the roster under it adds up to exactly this figure, which is the invariant
//  `OverviewRosterTests.theListAddsUpToTheHeadcount` exists to hold — so taking the head-count from
//  anywhere else would let the line above the list disagree with the list.
//
//  What `Group` still owns is `capacity`, and the two predicates over it. `isOver` and `overBy`
//  below are `Group.isOverCapacity` and `Group.overCapacityBy` (`Models.swift:497-498`) restated
//  against this type's own numerator rather than delegated to, because delegating would reintroduce
//  precisely the disagreement the paragraph above avoids: a card reading "8 of 8" while a badge
//  beside it claimed one over.
//
//  ── Over capacity is not in the design ───────────────────────────────────────────────────────
//
//  `8i` draws three courts under their ceiling and one closed; it never draws a full-and-then-some
//  court. The state exists all the same — `Group.capacityBanner` writes "1 over — move one kid
//  down" for it, and Groups draws that today — so this names it rather than letting the pill that
//  says "2 spots" quietly say "-1 spots". The treatment is the design's own amber, which is what
//  section 8 spends on "somebody's problem this morning"; see `CourtCapacityBadge`.
//

import Foundation

/// How full one court is, and therefore whether there is room on it.
struct CourtCapacity: Hashable, Sendable {

    /// Kids standing on the court today — `CourtCard.playersHere`.
    let here: Int
    /// The court's working ceiling — `Group.capacity`.
    let capacity: Int

    /// `8 of 8` — the grey figure at the head of the card.
    var reading: String { "\(here) of \(capacity)" }

    /// Places left. Negative is impossible by construction; an over-full court reports zero and
    /// says so through `overBy` instead, so a caller cannot draw "-1 spots".
    var spotsFree: Int { max(0, capacity - here) }

    /// `Group.isOverCapacity`'s rule, over this type's numerator. See the file header for why it
    /// is restated rather than delegated.
    var isOver: Bool { here > capacity }

    /// `Group.overCapacityBy`'s rule, likewise.
    var overBy: Int { max(0, here - capacity) }

    /// `2 spots`, `1 spot`, `1 over`, `2 over` — the pill beside the reading, or nil on a court
    /// that is exactly full.
    ///
    /// One property rather than two, because the three states are exclusive and a view asking
    /// "spots?" and then "over?" would be free to draw both. `8i` puts one pill in this slot or
    /// none.
    var pillLabel: String? {
        if isOver { return "\(overBy) over" }
        let free = spotsFree
        guard free > 0 else { return nil }
        return free == 1 ? "1 spot" : "\(free) spots"
    }

    /// What VoiceOver hears in place of "8 of 8", which on its own reads as a score or a date.
    ///
    /// The pill is folded in rather than announced separately: it is the same fact said twice for
    /// the eye, and a reader working down a screen of courts wants one sentence per card.
    ///
    /// Pluralised by hand rather than with `^[…](inflect: true)`. That markup is resolved by
    /// `LocalizedStringKey`, and this is a plain `String` — `MoreRow.spokenLabel` can use the
    /// markup because it returns a `Text`. Written out here means it is also a thing a test can
    /// assert on, which is the half of the contract nothing else checks.
    var spokenLabel: String {
        let head = "\(here) of \(capacity) kids"
        if isOver { return "\(head). \(overBy) over capacity" }
        let free = spotsFree
        guard free > 0 else { return "\(head). Full" }
        return "\(head). \(free) \(free == 1 ? "spot" : "spots") left"
    }
}

// MARK: - Reading one off the graph

extension CourtCapacity {

    /// The reading for a card, or nil when there is nothing to measure it against.
    ///
    /// Nil in three cases, and all three draw no figure at all rather than a half-one:
    ///
    ///   - the court is closed. There is nobody on it and no room on it; `8i` gives Court 4 a
    ///     `Closed` badge in this slot and no numbers whatsoever.
    ///   - the camp graph has no group for the card. A `today_courts` row the graph cannot match
    ///     is a read that has got ahead of the camp, not a court with a ceiling of zero.
    ///   - the ceiling is zero or less. `SampleData` derives capacity as
    ///     `venue.playerMax / venue.groupCount` (`Models.swift:1377`), which is guarded to at
    ///     least 1 — so this is defence against a graph that has been edited, and "of 0" is not a
    ///     sentence.
    static func reading(for card: CourtCard, capacity: Int?) -> CourtCapacity? {
        guard !card.isClosed, let capacity, capacity > 0 else { return nil }
        return CourtCapacity(here: card.playersHere, capacity: capacity)
    }
}
