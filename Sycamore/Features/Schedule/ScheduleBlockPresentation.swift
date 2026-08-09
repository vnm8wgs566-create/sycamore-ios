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

    /// `Water break · 8:30am – 10:00am` — this block named, and when it runs.
    ///
    /// `·` rather than a comma or a bracket, because that is how this screen already joins a thing
    /// to a fact about it — "Drop-off · done", "8 players · rotate at 10:30am", "1 note · shade
    /// tent is up".
    var titledSpan: String { "\(title) · \(timeLabel)" }

    /// `Clashes with Water break · 8:30am – 10:00am` — how a clash reads, in the words of the
    /// block that is being run into.
    ///
    /// A property of the block being *named* rather than of the one wearing the flag, because the
    /// sentence is made entirely of the named one. It reads at the call site as the line this
    /// clash produces: `Text(conflict.clashLine)`.
    ///
    /// Naming the other block is the whole point of drawing it. "Overlaps" on its own tells a
    /// coach holding a ball cart that something is wrong and not what; the name and the span
    /// together are enough to go and look at the other card, which is the only thing anybody can
    /// do about it.
    ///
    /// One spelling, two places: `ScheduleBlockCard` draws it and stops, and `BlockEditorSheet`
    /// continues it with the way out. A second spelling in the sheet is what this replaced.
    ///
    /// It does not say *which court* they share. Court names live on the camp graph and this
    /// extension is handed a block, so saying so would mean threading the venue's groups down to
    /// every card to add three words to a line that is already the second-longest on it.
    var clashLine: String { "Clashes with \(titledSpan)" }

    /// How many notes are hiding behind the one the card shows. Renders as the design's `+2`.
    var additionalNoteCount: Int { max(0, notes.count - 1) }

    /// `3 notes on this block`, `1 note on this block`, `No notes on this block yet`.
    ///
    /// The zero case is new, and it is only ever drawn for somebody who can do something about it
    /// — `BlockDetailView` still hides the card outright from everybody else, because "0 notes on
    /// this block" is a row that exists only to say there is nothing in it. Worded as a state
    /// rather than as a count ("No notes …" rather than "0 notes …") because it is the label on a
    /// row that opens a composer, not a tally.
    var notesRowLabel: String {
        guard !notes.isEmpty else { return "No notes on this block yet" }
        return "\(notes.count) note\(notes.count == 1 ? "" : "s") on this block"
    }

    /// `8 players · rotate at 10:30am`, or just the head-count when the block runs open-ended.
    func courtMetaLine(playersHere: Int) -> String {
        let players = "\(playersHere) player\(playersHere == 1 ? "" : "s")"
        guard let endsAt else { return players }
        return "\(players) · rotate at \(endsAt.clockLabel)"
    }

    /// What VoiceOver reads for one card on `8k`.
    ///
    /// The card is a stack of five or six runs — a time, a title, a grey line, an amber line, a
    /// rule, a glyph, a note, a count — and read one at a time they arrive as a list of fragments
    /// with the glyphs interleaved. Combined into a single sentence they arrive as the row a
    /// sighted reader sees in one glance: when it is, what it is, and what is wrong with it.
    ///
    /// - Parameter conflict: the block this one clashes with, so the flag is spoken rather than
    ///   only coloured. Amber is the whole of the warning on screen, and a colour is not available
    ///   to somebody listening.
    func accessibilityLine(isCurrent: Bool, conflict: ScheduleBlock?) -> String {
        var parts = [startsAt.clockLabel, title]
        if let subtitle { parts.append(subtitle) }
        if let conflict { parts.append(conflict.clashLine) }
        if isCurrent { parts.append("on now") }
        if !notes.isEmpty {
            parts.append("\(notes.count) note\(notes.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Status

extension ScheduleBlockStatus {

    /// The ink section 8 writes each state in. Amber is spent on exactly one of them.
    var tint: Color {
        switch self {
        case .planned: Theme.inkMuted
        case .done: Theme.chevron
        case .needsCoach: Theme.warning
        }
    }
}

// MARK: - The day

/// Where a day is up to, and how that reads.
///
/// *Which* block is running is `ScheduleBlock.running(in:at:)` — a fact about a list of blocks
/// and a clock, which lives on the model because Overview, the Postgres repository and this
/// screen all have to agree on it. This enum only turns that answer into words.
enum ScheduleDay {

    /// `On now · 41 min left`, `On now`, `Needs a coach`, `Done`, `Later today`.
    ///
    /// - Parameter now: injected rather than read from `Date()` inside, so a preview can put the
    ///   clock inside the block the design depicts instead of wherever today happens to be.
    static func statusLine(
        for block: ScheduleBlock, isCurrent: Bool, now: TimeOfDay = .now()
    ) -> String {
        switch block.status {
        case .done:
            return "Done"
        case .needsCoach:
            return "Needs a coach"
        case .planned:
            guard isCurrent else {
                // "Later today" for everything not running was a lie every afternoon: once the
                // last block ends, nothing is current and the whole day claimed to be ahead.
                return block.startsAt <= now ? "Earlier today" : "Later today"
            }
            guard let endsAt = block.endsAt, now >= block.startsAt, now < endsAt else {
                return "On now"
            }
            return "On now · \(endsAt.id - now.id) min left"
        }
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
