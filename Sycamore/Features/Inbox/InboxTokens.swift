//
//  InboxTokens.swift
//  Sycamore
//
//  The two things `8r` draws that the shared design system has no name for yet: a third icon
//  tint, and the row metrics the design writes in the Inbox and nowhere else.
//
//  Local rather than added to `Theme` / `Spacing` on purpose. Every screen in section 8 is
//  being built at once, and a token added to a shared file is a merge conflict for all of them.
//  Both belong upstairs once the section lands — see the pull request.
//

import SwiftUI

// MARK: - Icon tint

/// The three colours an Inbox row's icon tile comes in.
///
/// The design uses them as a severity ramp rather than as decoration: green is something a
/// person did or asked for, amber is a gap in the morning that nobody has filled, grey is
/// history. It reads down the list — the two things that are still open carry colour, the four
/// things that already happened do not.
enum InboxTint: Sendable {
    /// `#F6FAF7` tile, `#1A7F55` glyph — an ask, a pin. Resolves through `Theme.accentTint`
    /// and `Theme.accent`, which is the same green a shade deeper.
    case accent
    /// `#FAF6EC` tile, `#B67A16` glyph — a court short of a coach, a kid leaving early.
    case warning
    /// `#F4F5F7` tile, `#5C6068` glyph — the feed.
    case neutral

    var tile: Color {
        switch self {
        case .accent: Theme.accentTint
        // The one pair the design draws that `Theme` has no counterpart for. The dark values
        // are derived the way `Theme` derives its own: the tile climbs to a warm near-black
        // rather than going flat, and the glyph brightens because `#B67A16` on a dark surface
        // falls well under 4.5:1.
        case .warning: Theme.warningTint
        case .neutral: Theme.fill
        }
    }

    var glyph: Color {
        switch self {
        case .accent: Theme.accent
        case .warning: Theme.warning
        case .neutral: Theme.inkSecondary
        }
    }
}

// MARK: - Row metrics

/// Sizes the design writes into the Inbox's own CSS. Named here so no row spells a number.
enum InboxMetrics {
    /// `width:34px;height:34px` — the icon tile.
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
    /// `opacity:.62` — a row on `8h`'s cleared list. Dealt with, still legible.
    static let clearedOpacity: Double = 0.62
}
