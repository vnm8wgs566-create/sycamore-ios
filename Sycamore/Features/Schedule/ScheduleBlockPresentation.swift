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
    ///
    /// **`TimeOfDay.shortLabel` and not that argument written out as arithmetic**, which is what
    /// stood here: a 12-hour hour, a minute zero-padded by hand, and a colon between them. The
    /// property (`Models.swift:309-326`) is the same format, and its own doc names *this* call
    /// site as the reason it was hoisted — `4d` writes "Free at 10:30" and
    /// `ScheduleBlock.shortTimeLabel` writes "10:45 – 12:15", which is the same spelling in a
    /// third and fourth place, and "three hand-spellings of one format is how two of them come to
    /// disagree". The two agreed today only by the coincidence of two different algorithms
    /// arriving at the same string; the assumption underneath both — a camp day does not wrap
    /// round midnight — is stated there now as well as here.
    var gutterLabel: String { startsAt.shortLabel }

    /// `Drop-off · done` — a finished block gets one grey line instead of a card.
    var doneLabel: String { "\(title) · done" }

    /// The grey second line, or the amber one. `.needsCoach` outranks whatever `detail` says:
    /// a court with nobody on it is the most important thing about that block.
    var subtitle: String? {
        status == .needsCoach ? "Needs a coach" : detail
    }

    // `titledSpan` used to sit here: `Water break · 8:30am – 10:00am`, this block named and when it
    // runs, joined by the `·` this screen joins a thing to a fact about it with. `clashLine` was
    // its only reader and no longer names a span at all — see below — so it is gone rather than
    // left as a spelling nothing spells. `courtMetaLine` — `8 players · rotate at 10:30am` — has
    // since gone the same way: `BlockCourtCard` was its only caller and `5d` redrew that card
    // around a head-count and a coach row, so the sentence had nobody left to say it. The `·` form
    // itself is alive in three other places (`doneLabel`, `5d`'s header subtitle, the editor's
    // eyebrow), which is where anybody needing it again should look first.

    /// `Runs into Cool-down at 12:00pm` — how a clash reads: the block being run into, and the
    /// minute the running-into starts (`design/rebuild/section-t5.html:169`).
    ///
    /// A method on the block being *named* rather than on the one wearing the flag, because all
    /// but one word of the sentence is made of the named one. It reads at the call site as the
    /// line this clash produces: `Text(conflict.runsIntoLine(from: block.startsAt))`.
    ///
    /// **"Runs into" and not "Clashes with"**, which is what this said and what `BlockEditorSheet`
    /// used to say beside it. The argument is already written down at
    /// `BlockEditorSheet.swift:547-550` and is not restated here: a clash is a state the app has
    /// decided you are in; running into something is what the block does, in the order a morning
    /// happens. That sheet wrote the design's words out longhand and left a note saying they would
    /// go back to being this property the day it agreed with them. They agree, and the note is
    /// gone: `overlapAdvice` opens on `clash.clashLine`, so the sentence has one speller and the
    /// three screens cannot come to quote different minutes.
    ///
    /// **What the span went to.** The old sentence carried the named block's whole span —
    /// `Clashes with Water break · 8:30am – 10:00am` — and the design replaces it with one minute.
    /// That is the more useful half: a span tells you when the other block runs, which its own card
    /// on the canvas already draws to scale; the minute tells you where this block stops being
    /// yours alone, which is the number a finger on the bottom edge is aiming at.
    ///
    /// - Parameter liveStart: where the block *wearing* the flag starts. During a drag that is not
    ///   where the store thinks it starts, which is the whole reason this takes it rather than
    ///   reading a stored block.
    ///
    /// The `max` is the minute the overlap actually begins, and it moves with which block is
    /// inside which. For a block whose bottom edge has been pulled down onto a later one, that is
    /// the later one's start (12:00pm, the design's case). For a block *carried down* onto one
    /// already running, it is the dragged block's own new start — the neighbour began without it.
    ///
    /// It does not say *which court* they share. Court names live on the camp graph and this
    /// extension is handed a block, so saying so would mean threading the venue's groups down to
    /// every card to add three words to a line that is already the second-longest on it.
    func runsIntoLine(from liveStart: TimeOfDay) -> String {
        "Runs into \(title) at \(max(liveStart, startsAt).clockLabel)"
    }

    /// The same sentence for a caller that holds only the named block.
    ///
    /// `runsIntoLine(from:)` with the named block's own start standing in for the flagged one's,
    /// which makes the `max` inert and quotes the named block's start. That is exactly right for
    /// the common case — the flag is nearly always on the earlier block, and the overlap begins
    /// where the later one does — and it is what `BlockEditorSheet.overlapAdvice` quotes too, so
    /// the three screens say one number.
    ///
    /// Prefer the method wherever the flagged block is in hand: `accessibilityLine` below and
    /// `ScheduleBlockCard` both are, and both pass their own start so a block that sits *inside*
    /// its clash is told the minute it itself began rather than the minute the other one did.
    var clashLine: String { runsIntoLine(from: startsAt) }

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
        // `runsIntoLine(from:)` rather than `clashLine`, this being a method on the flagged block
        // and so one of the two callers that can hand the sentence a start. A card mid-drag hands
        // it the live one; this hands it the stored one, which is the same number every moment a
        // rotor is what is reading the card.
        if let conflict { parts.append(conflict.runsIntoLine(from: startsAt)) }
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
