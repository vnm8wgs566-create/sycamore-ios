//
//  InboxTokens.swift
//  Sycamore
//
//  Everything `8r` and `8h` spell that the shared design system has no name for yet: a severity
//  ramp for the row glyphs, the metrics the design writes in the Inbox and nowhere else, and
//  section 8's own type scale.
//
//  Local rather than added to `Theme` / `Radius` / `TypeStyle` on purpose. Every screen in
//  section 8 is being built at once and a token added to a shared file is a merge conflict for
//  all of them — `ScheduleTokens` and `OnTheDayTokens` carry their own copies of the same idea
//  for the same reason. All of it belongs upstairs once the section lands; see the pull request.
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
    /// `padding:10px 13px` — that "2 more" row.
    static let morePaddingV: CGFloat = 10
    /// `gap:7px` between its caret and its label.
    static let moreSpacing: CGFloat = 7
    /// `font-size:14px` — the caret itself.
    static let moreCaret: CGFloat = 14
}

// MARK: - Type

/// Section 8's own type scale, for the Inbox's share of it.
///
/// It runs a weight lighter than the rest of the app — row titles are 600 where `Sycamore Flow`
/// sets them at 700 — so these are separate styles rather than tweaks to the shared table, which
/// every screen outside section 8 is still drawn from.
enum InboxType {
    /// `600 14.5`, `-.025em` — a row's title.
    static let rowTitle = TypeStyle(size: 14.5, weight: .semibold, trackingEm: -0.025)
    /// `400 12.5` — its grey second line.
    static let rowDetail = TypeStyle(size: 12.5, weight: .regular)
    /// `600 10.5`, `+.14em`, uppercase — "NEEDS YOU · 2", "THIS MORNING".
    static let overline = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.14, isUppercased: true)
    /// `600 10.5`, `+.15em`, uppercase — "CLEARED TODAY · 4", a hair wider than `8r`'s.
    static let clearedOverline = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.15, isUppercased: true)
    /// `600 14`, `-.02em` — a cleared row's title, half a point down from a live one.
    static let clearedTitle = TypeStyle(size: 14, weight: .semibold, trackingEm: -0.02)
    /// `400 12` — its second line.
    static let clearedDetail = TypeStyle(size: 12, weight: .regular)
    /// `600 13` — a filter chip.
    static let filterChip = TypeStyle(size: 13, weight: .semibold)
    /// `600 12.5` — "2 more".
    static let moreLabel = TypeStyle(size: 12.5, weight: .semibold)
    /// `24/1.15`, `-.02em` — "All clear.".
    ///
    /// The design sets this in Newsreader at 400 and the app has no serif; the app-wide
    /// translation of a design heading is Instrument Sans at its heaviest, which is what this is.
    /// Size, tracking and leading are the design's.
    static let allClearTitle = TypeStyle(size: 24, weight: .extraBold, trackingEm: -0.02, lineHeightMultiple: 1.15)
    /// `400 13.5/1.6` — the sentence under it.
    static let allClearBody = TypeStyle(size: 13.5, weight: .regular, lineHeightMultiple: 1.6)
    /// `600 17`, `-.02em` — the heading of the filtered-empty state, which the design never
    /// draws. Sized to `ContentUnavailableView`'s own proportions rather than to a CSS rule.
    static let narrowedTitle = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.02)
}
