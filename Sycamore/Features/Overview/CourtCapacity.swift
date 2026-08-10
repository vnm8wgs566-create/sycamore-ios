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
//  ── `Flag` is a state, and it is the only thing that decides what a court wears ───────────────
//
//  Two screens read this: Overview's `CourtCapacityBadge`, and the sheet that moves a kid
//  (`PlayerCourtChoices`). They used to reach their conclusions separately — Overview through a
//  `pillLabel` that went nil at exactly the ceiling, the picker through its own `isOver` test with
//  the word "Full" bolted on underneath — and predictably drifted at the boundaries. At 8 of 8 the
//  picker warned and Overview said nothing while telling VoiceOver "Full", so on the same court the
//  eye and the ear disagreed and so did the two screens.
//
//  `Flag` is that decision, made once. Four states, exclusive by construction, each with the one
//  word it is called by and the one sentence it is heard as. A screen may not ask "spots?" and then
//  "over?" and draw both, and it cannot say something aloud it did not draw, because there is
//  nothing left to branch on twice.
//
//  What a screen *does* keep is its own treatment. Overview draws `.room` as the design's dashed
//  green pill with a `+` in it; the picker draws nothing for it, because its row already carries
//  "6 of 8" in the line under the court's name and a sheet of green pills is noise. That is a
//  difference in plate, stated in one `switch` on each side, and not a difference in which courts
//  are flagged.
//
//  The rule that keeps the two honest is `isWarning`. **A warning is seen and heard, or neither.**
//  Anything that is somebody's problem this morning — full, over, out of play — wears amber on
//  every screen that draws the court and is read out on every screen that speaks it. Anything that
//  is not may be spoken more fully than it is drawn, because the reading beside it ("0 of 4")
//  already carries the fact for the eye.
//
//  ── Over capacity is not in the design, and neither is full ──────────────────────────────────
//
//  `8i` draws three courts under their ceiling and one closed; it never draws a full-and-then-some
//  court, and the one it draws at exactly 8 of 8 wears no pill at all. Both states exist all the
//  same — `Group.capacityBanner` writes "1 over — move one kid down", though nothing draws it:
//  that property has no caller outside its own tests, so it argues for the state rather than
//  evidencing it —
//  so this names them rather than letting the pill that says "2 spots" quietly say "-1 spots", or
//  letting a court with nowhere left to put a child look exactly like one with room.
//
//  The treatment is the design's own amber, which is what section 8 spends on "somebody's problem
//  this morning"; see `CourtCapacityBadge`. Drawing it at exactly the ceiling as well as past it is
//  the one thing here that overrides a state `8i` does draw, and it is the same argument extended
//  by one: the design has no picture of *this court needs looking at*, the app decided amber was
//  that picture when it named the over-full court, and a court at 8 of 8 is the state an admin most
//  needs to see before sending a ninth child to it.
//
//  ── Closure is a state a court can be in, and not one this type can work out ──────────────────
//
//  `.closed` is in `Flag` because it is the fourth thing a court's row can say and it belongs in
//  the same closed set as the other three — a screen that switched over the fill and then asked a
//  separate question about closure would be two owners again. It is not, however, something
//  `CourtCapacity.flag` can ever return: closure is `CourtStatus` on a `CourtCard`, a row of
//  `today_courts`, and this type is built from a head-count and a ceiling. Whoever holds both facts
//  is the one who names the state — `PlayerCourtOption.flag` does it for the picker, and Overview
//  does it a card earlier by drawing `CourtStatusBadge` and no reading at all.
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

    /// Which of the three measurable states this court is in — and therefore what it wears.
    ///
    /// One property rather than a run of predicates, because the states are exclusive and a view
    /// asking "spots?" and then "over?" would be free to draw both. `8i` puts one pill in this slot
    /// or none, and now so does every screen that reads this.
    ///
    /// Never `.closed`; see the file header. A closed court is one this type was not built for.
    var flag: Flag {
        if isOver { return .over(overBy) }
        let free = spotsFree
        return free > 0 ? .room(free) : .full
    }

    /// `8 of 8 kids` — the figure, said so it cannot be mistaken for a score or a date.
    ///
    /// Split from `spokenLabel` because the picker composes its own sentence around the same
    /// figure: a row there is a court, a fill, a flag and a coach, and it needs the head of this
    /// sentence without the tail. Two spellings of "8 of 8 kids" is exactly the kind of drift the
    /// rest of this file exists to prevent.
    var spokenReading: String { "\(here) of \(capacity) kids" }

    /// What VoiceOver hears in place of "8 of 8", which on its own reads as a score or a date.
    ///
    /// The flag is folded in rather than announced separately: it is the same fact said twice for
    /// the eye, and a reader working down a screen of courts wants one sentence per card.
    var spokenLabel: String { "\(spokenReading). \(flag.spokenLabel)" }
}

// MARK: - What a court's row says

extension CourtCapacity {

    /// The one state a court is in, and the only thing that decides what it wears.
    ///
    /// Nested here because this is where the vocabulary lives, and closed because the four cases
    /// are the whole of what a court's row can say. `PlayerCourtOption.flag` is the other producer
    /// — see the file header for why `.closed` cannot come from the arithmetic.
    enum Flag: Hashable, Sendable {
        /// Places left, always at least one. A court exactly at its ceiling is `.full`.
        case room(Int)
        /// Exactly at the ceiling. Nowhere left to put a child without going over.
        case full
        /// Past the ceiling, by at least one.
        case over(Int)
        /// Out of play today — "Net down", "Tom is on it".
        case closed

        /// `2 spots`, `1 spot`, `Full`, `1 over`, `Closed` — what the pill says.
        ///
        /// Pluralised by hand rather than with `^[…](inflect: true)`. That markup is resolved by
        /// `LocalizedStringKey` and this is a plain `String` — `MoreRow.spokenLabel` can use the
        /// markup because it returns a `Text`. Written out here means it is also a thing a test can
        /// assert on, which is the half of the contract nothing else checks.
        ///
        /// `Closed` is `CourtStatus.badge`'s word restated, for the reason `isOver` restates
        /// `Group.isOverCapacity`: a court that is closed *and* over shows this pill an inch from
        /// Overview's `CourtStatusBadge` on the same morning, and two spellings would land side by
        /// side. `CourtCapacityFlagTests.closedBorrowsTheStatusWord` is what holds them equal.
        var label: String {
            switch self {
            case .room(let free): free == 1 ? "1 spot" : "\(free) spots"
            case .full: "Full"
            case .over(let by): "\(by) over"
            // Borrowed rather than spelled a third time. `CourtStatus.badge` already owns this
            // word (`SectionEight.swift:92-97`) and a court card draws it from there, so a
            // literal here would be two screens agreeing by coincidence — which is what
            // `OverviewCapacityTests` was left asserting. A test doing work an expression can do
            // is a test that fails the day somebody rewords one of them and not the other.
            case .closed: CourtStatus.closed(reason: "").badge
            }
        }

        /// What VoiceOver hears in its place. Longer than `label`, because a word read out after a
        /// court's name and its fill has to be a claim rather than a fragment.
        var spokenLabel: String {
            switch self {
            case .room(let free): "\(free) \(free == 1 ? "spot" : "spots") left"
            case .full: "Full"
            case .over(let by): "\(by) over capacity"
            // The same word from the same owner, for the same reason as `label` above.
            case .closed: CourtStatus.closed(reason: "").badge
            }
        }

        /// Whether this is somebody's problem this morning, and therefore amber.
        ///
        /// The one rule that keeps the screens honest: a warning is seen and heard, or neither. A
        /// screen may draw `.room` however it likes — Overview gives it the design's green pill and
        /// the picker gives it nothing — but it may not quietly drop a warning, and it may not
        /// speak one it did not draw. See the file header.
        ///
        /// **A flag, not a bar.** Nothing downstream disables anything on the strength of this: the
        /// app flags a clash rather than refusing one, which is argued at length for the schedule's
        /// overlaps in `ScheduleResize.swift:19-42` and `BlockEditorDraft.swift:96-125` and holds
        /// here for the same reasons. A camp may legitimately go over, and somebody wants to *see*
        /// it rather than be stopped at seven in the morning.
        var isWarning: Bool {
            switch self {
            case .room: false
            case .full, .over, .closed: true
            }
        }
    }
}

// MARK: - Reading one off the graph

extension CourtCapacity {

    /// The reading for a card, or nil when there is nothing to measure it against.
    ///
    /// Nil in three cases, and all three draw no figure at all rather than a half-one:
    ///
    ///   - the court is closed. There is nobody on it and no room on it; `8i` gives Court 4 a
    ///     `Closed` badge in this slot and no numbers whatsoever. The state is not lost by being
    ///     absent here — the card draws `CourtStatusBadge` beside this slot and that badge is the
    ///     amber `.closed` wears on Overview.
    ///   - the camp graph has no group for the card. A `today_courts` row the graph cannot match
    ///     is a read that has got ahead of the camp, not a court with a ceiling of zero.
    ///   - the ceiling is zero or less. `SampleData` derives capacity as
    ///     `venue.playerMax / venue.groupCount` (`Models.swift:1377`), which is guarded to at
    ///     least 1 — so this is defence against a graph that has been edited, and "of 0" is not a
    ///     sentence.
    static func reading(for card: CourtCard, capacity: Int?) -> CourtCapacity? {
        guard !card.isClosed else { return nil }
        return reading(here: card.playersHere, capacity: capacity)
    }

    /// The reading for a court taken straight off the camp graph, or nil at a ceiling of zero.
    ///
    /// What the move sheet lists from, and the sibling that stopped the guard above having a second
    /// owner. `PlayerCourtChoices` used to build a `CourtCapacity` itself with its own copy of the
    /// `capacity > 0` test written out beside a comment asking for exactly this.
    ///
    /// `presentCount` is the numerator, not `playerCount`, and the two differ by whoever is away.
    /// `Group.isOverCapacity` measures against today's count on purpose — `Models.swift:495-498`
    /// argues it, and `Group.capacityBanner` and Overview's amber both follow it — so a reading
    /// built on the roll would let a row say "8 of 8 · Full" beside a court the rest of the app
    /// calls in range. One numerator, or the figure and the flag drift apart the first day somebody
    /// is off sick.
    ///
    /// **It takes no view of closure**, where the card overload above does, and that is not an
    /// inconsistency: a `Group` is a court in the camp, and whether it is out of play *today* is a
    /// `today_courts` fact the graph does not carry. The caller that knows names the state; see
    /// `PlayerCourtOption.flag`.
    static func reading(for group: Group) -> CourtCapacity? {
        reading(here: group.presentCount, capacity: group.capacity)
    }

    /// The guard both entry points share, and the reason they are siblings rather than two
    /// functions that happen to agree.
    private static func reading(here: Int, capacity: Int?) -> CourtCapacity? {
        guard let capacity, capacity > 0 else { return nil }
        return CourtCapacity(here: here, capacity: capacity)
    }
}
