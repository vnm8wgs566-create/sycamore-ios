//
//  ScheduleBlockPresentation.swift
//  Sycamore
//
//  How a `ScheduleBlock` reads on `8k` and `8l`. Derivations only — the model is the shared
//  section 8 contract and stays free of anything that is really a drawing decision.
//

import SwiftUI

// MARK: - A block on the page

extension ScheduleBlock {

    /// `8:30`, `10:45`, `12:00` — the 52pt gutter down the left of the day.
    ///
    /// Not `startsAt.clockLabel`: that spells `8:30am`, which is seven characters in a column
    /// the design draws for four. The meridiem is redundant here anyway, because the gutter is
    /// a column of times in order and a camp day does not wrap around midnight.
    var gutterLabel: String {
        let hour12 = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12
        let minute = startsAt.minute < 10 ? "0\(startsAt.minute)" : "\(startsAt.minute)"
        return "\(hour12):\(minute)"
    }

    /// `Drop-off · done` — a finished block gets one grey line instead of a card.
    var doneLabel: String { "\(title) · done" }

    /// The grey second line, or the amber one. `.needsCoach` outranks whatever `detail` says:
    /// a court with nobody on it is the most important thing about that block.
    var subtitle: String? {
        status == .needsCoach ? "Needs a coach" : detail
    }

    /// How many notes are hiding behind the one the card shows. Renders as the design's `+2`.
    var additionalNoteCount: Int { max(0, notes.count - 1) }

    /// `3 notes on this block`, `1 note on this block`.
    var notesRowLabel: String {
        "\(notes.count) note\(notes.count == 1 ? "" : "s") on this block"
    }

    /// `8 players · rotate at 10:30am`, or just the head-count when the block runs open-ended.
    func courtMetaLine(playersHere: Int) -> String {
        let players = "\(playersHere) player\(playersHere == 1 ? "" : "s")"
        guard let endsAt else { return players }
        return "\(players) · rotate at \(endsAt.clockLabel)"
    }
}

// MARK: - Status

extension ScheduleBlockStatus {

    /// The ink section 8 writes each state in. Amber is spent on exactly one of them.
    var tint: Color {
        switch self {
        case .planned: Theme.inkMuted
        case .done: Theme.chevron
        case .needsCoach: ScheduleTheme.warning
        }
    }
}

// MARK: - The day

/// Section 8's Schedule reads top to bottom, so where you are in the day is a position in the
/// list rather than a field on a row: the first block that is not behind you is the one you are
/// on. That keeps the green card in the right place with no clock at all, which matters because
/// `Weekday.today` is still stubbed and a wrong "On now" is worse than none.
///
/// The minutes remaining *do* need a real clock, so they are asked for separately and only
/// answered when the wall clock actually falls inside the block.
enum ScheduleDay {

    /// The block the day is on, or nil once every block is done.
    static func currentBlockID(in blocks: [ScheduleBlock]) -> ScheduleBlock.ID? {
        blocks.first { $0.status != .done }?.id
    }

    /// `On now · 41 min left`, `On now`, `Needs a coach`, `Done`, `Later today`.
    ///
    /// - Parameter now: injected rather than read from `Date()` inside, so a preview can put the
    ///   clock inside the block the design depicts instead of wherever today happens to be.
    static func statusLine(
        for block: ScheduleBlock, isCurrent: Bool, now: TimeOfDay = .now
    ) -> String {
        switch block.status {
        case .done:
            return "Done"
        case .needsCoach:
            return "Needs a coach"
        case .planned:
            guard isCurrent else { return "Later today" }
            guard let endsAt = block.endsAt, now >= block.startsAt, now < endsAt else {
                return "On now"
            }
            return "On now · \(endsAt.id - now.id) min left"
        }
    }
}

// MARK: - Clock

extension TimeOfDay {

    /// The wall clock, for the one thing on these screens that genuinely needs it.
    ///
    /// `Weekday.today` is pinned to Wednesday until the backend lands, but the *time* has no
    /// such stand-in and inventing one would make "41 min left" a decoration.
    static var now: TimeOfDay {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return TimeOfDay(parts.hour ?? 0, parts.minute ?? 0)
    }
}

// MARK: - Day shapes

extension DayShape {

    /// The glyph on `8f`'s tinted tile. SF Symbols standing in for the design's Phosphor set,
    /// the same substitution `AppTab.symbol` makes.
    var symbol: String {
        switch self {
        case .halfDay: "sunrise"
        case .fullDay: "clock"
        case .tournament: "trophy"
        }
    }
}
