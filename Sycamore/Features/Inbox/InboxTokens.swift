//
//  InboxTokens.swift
//  Sycamore
//
//  Everything `8r` and `8h` spell that the shared design system has no name for yet: a severity
//  ramp for the row glyphs, the metrics the design writes in the Inbox and nowhere else, and
//  section 8's own type scale.
//
//  The colour and the metrics are local rather than added to `Theme` / `Radius` on purpose. Every
//  screen in section 8 is being built at once and a token added to a shared file is a merge
//  conflict for all of them — `ScheduleTokens` and `OnTheDayTokens` carry their own copies of the
//  same idea for the same reason. Both belong upstairs once the section lands.
//
//  The type already went. `InboxType` is now a set of names onto `TypeStyle`, not a scale.
//
//  Not one number here is invented. Each is transcribed from the inline CSS of `8r` / `8h` in
//  `Sycamore 3a System.dc.html`, and the reference is quoted beside it.
//

import SwiftUI

// MARK: - Icon tint

/// The four colours an Inbox row's icon tile comes in.
///
/// The design uses them as a severity ramp rather than as decoration: green is something a
/// person did or asked for, amber is a gap in the morning that nobody has filled, grey is
/// history. It reads down the list — the two things that are still open carry colour, the four
/// things that already happened do not.
enum InboxTint: Sendable {
    /// `#F6FAF7` tile, `#1A7F55` glyph — an ask, a pin.
    case accent
    /// `#FAF6EC` tile, `#B67A16` glyph — a court short of a coach, a kid leaving early.
    case warning
    /// `#F4F5F7` tile, `#5C6068` glyph — the feed.
    case neutral
    /// `#F4F5F7` tile, `#8A8E96` glyph — `8h`'s cleared list. Same plate as the feed, but the
    /// glyph drops a step: a row you have dealt with is quieter than one you have only read.
    case cleared

    var tile: Color {
        switch self {
        // `accentSurface`, deliberately not `accentTint`. The design draws two different green
        // plates on this one screen — `#F6FAF7` under a glyph and `#EDF6F1` under the "Review"
        // label — and reaching for the nearest one turns an icon tile a shade too saturated.
        case .accent: Theme.accentSurface
        case .warning: Theme.warningTint
        // `#F4F5F7`, which `Theme` happens to name for its other job (list row dividers).
        // Reached through the token rather than respelled: a hex in feature code is how a
        // palette forks. A `Theme.tileFaint` alias is a hoist candidate.
        case .neutral, .cleared: Theme.hairlineFaint
        }
    }

    var glyph: Color {
        switch self {
        case .accent: Theme.accent
        case .warning: Theme.warning
        case .neutral: Theme.inkSecondary
        case .cleared: Theme.inkMuted
        }
    }
}

// MARK: - Geometry

/// Sizes the design writes into the Inbox's own CSS, so no row spells a number.
enum InboxMetrics {

    // MARK: Cards and rows

    /// `border-radius:16px`. Section 8 draws its cards a point tighter than `Radius.card` (17),
    /// on all twenty of its screens. Spelled out rather than borrowing `Radius.button`, which is
    /// 16 by coincidence.
    static let cardRadius: CGFloat = 16
    /// `padding:12px 13px` — a live row. The horizontal half is `CardRow`'s own default.
    static let rowPaddingV: CGFloat = 12
    static let rowPaddingH: CGFloat = 13
    /// `width:34px;height:34px` — the icon tile. Its `border-radius:11px` is `Radius.control`.
    static let iconTile: CGFloat = 34
    /// `font-size:16px` — the glyph inside it.
    static let iconGlyph: CGFloat = 16
    /// `margin-top:3px` — between a row's title and its detail line.
    static let titleGap: CGFloat = 3
    /// `font-size:15px` — the trailing caret on a feed row.
    static let caret: CGFloat = 15
    /// `padding:7px 12px` — the "Review" / "Assign" button.
    static let actionPaddingH: CGFloat = 12
    static let actionPaddingV: CGFloat = 7

    // MARK: Headings and the gaps between sections

    /// `padding:… 4px …` — the inset that lines an overline up with the copy in the card below.
    static let overlineInset: CGFloat = 4
    /// The list's `gap:9px`, which is all that separates an overline from its card.
    static let overlineBottom: CGFloat = 9
    /// From a card to the next overline: the same `gap:9px` plus the `padding-top:6px` every
    /// heading but the first carries.
    static let sectionGap: CGFloat = 15
    /// `gap:6px` between the filter chips.
    static let chipGap: CGFloat = 6
    /// `padding:8px 15px` — a filter chip.
    static let chipPaddingH: CGFloat = 15
    static let chipPaddingV: CGFloat = 8
    /// The drop from the chips to the header's rule. The design writes `padding-bottom:16px`;
    /// this is that less the invisible overhang of the chips' 44pt hit region, so the header
    /// block still ends where the design ends it.
    static let chipRowBottom: CGFloat = 10

    // MARK: `8h`

    /// `gap:14px` — `8h`'s list is a shade airier than `8r`'s.
    static let allClearGap: CGFloat = 14
    /// `padding:28px 20px` — inside the all-clear card.
    static let allClearPaddingV: CGFloat = 28
    static let allClearPaddingH: CGFloat = 20
    /// `width:56px;height:56px` — the green disc with the tick.
    static let allClearMark: CGFloat = 56
    /// `font-size:26px` — the tick inside it.
    static let allClearMarkGlyph: CGFloat = 26
    /// `margin-top:16px` — disc to "All clear.".
    static let allClearTitleTop: CGFloat = 16
    /// `margin-top:9px` — "All clear." to the sentence under it.
    static let allClearBodyTop: CGFloat = 9
    /// `max-width:250px`. The design caps the sentence well short of the card so it stays a
    /// paragraph rather than a banner.
    static let allClearBodyWidth: CGFloat = 250
    /// `padding:0 5px 8px` — "CLEARED TODAY · 4" sits a point wider than `8r`'s headings.
    static let clearedOverlineInset: CGFloat = 5
    static let clearedOverlineBottom: CGFloat = 8
    /// `padding:11px 13px` — a cleared row, a point tighter than a live one.
    static let clearedRowPaddingV: CGFloat = 11
    /// `margin-top:2px` — its title to its detail line.
    static let clearedTitleGap: CGFloat = 2
    /// `opacity:.62` — dealt with, still legible.
    static let clearedOpacity: Double = 0.62
    /// The design draws four cleared rows as two and a "2 more".
    static let clearedCollapsedCount = 2
    // The "2 more" row's own padding, gap and caret moved to `MoreRowMetrics.plate` when the
    // three folded lists stopped drawing three different rows. The CSS they came from is quoted
    // there.
}

// MARK: - Type

/// What `8r` and `8h` need beyond the shared table.
///
/// This used to be a parallel type scale, written when the shared table still ran a weight or two
/// heavier than section 8 — row titles at 700 where the design sets 600. The table carries the
/// design's weights now, so these are aliases: the names stay so the rows keep reading in the
/// Inbox's own vocabulary, and the numbers behind them are shared.
enum InboxType {
    /// `600 14.5`, `-.025em` — a row's title.
    static let rowTitle = TypeStyle.rowLabel.tracking(em: -0.025)
    /// `400 12.5` — its grey second line.
    static let rowDetail = TypeStyle.rowDetail
    /// `600 10.5`, `+.14em`, uppercase — "NEEDS YOU · 2", "THIS MORNING".
    static let overline = TypeStyle.overlineSmall
    /// `600 10.5`, `+.15em`, uppercase — "CLEARED TODAY · 4", a hair wider than `8r`'s.
    static let clearedOverline = TypeStyle.overlineSmall.tracking(em: 0.15)
    /// `600 14`, `-.02em` — a cleared row's title, half a point down from a live one.
    static let clearedTitle = TypeStyle.rowTitleSm
    /// `400 12` — its second line.
    static let clearedDetail = TypeStyle.meta
    /// `600 13` — a filter chip.
    static let filterChip = TypeStyle.chip
    /// `400 24/1.15 Newsreader`, `-.02em` — "All clear.".
    ///
    /// `8h` sets this `font:400 24px/1.15 Newsreader,Georgia,serif`, which is `profileName`
    /// exactly. It was drawn here at 800 in the sans on the reasoning that "the app has no serif,
    /// and the app-wide translation of a design heading is Instrument Sans at its heaviest" —
    /// true when it was written, wrong twice over now. Newsreader is bundled, and a heading the
    /// design sets at its *lightest* weight is not one to translate to the heaviest: it was the
    /// only style in section 8 pointing the opposite way to every other display line.
    static let allClearTitle = TypeStyle.profileName
    /// `400 13.5/1.6` — the sentence under it.
    static let allClearBody = TypeStyle.emptyBody
    /// `600 17`, `-.03em` — the heading of the filtered-empty state, which the design never
    /// draws. It takes the shared 17 rather than an invented tracking of its own, precisely
    /// because there is no CSS to be exact against.
    static let narrowedTitle = TypeStyle.venueHeading
}
