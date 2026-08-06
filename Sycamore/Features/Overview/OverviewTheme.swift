//
//  OverviewTheme.swift
//  Sycamore
//
//  The tokens `8i` / `8j` need that `Theme` does not carry yet: the warning amber a closed
//  court is written in, the accent-tinted lift under your own court, and the handful of
//  metrics the design draws Overview with.
//
//  Local to this folder on purpose. `Theme` is the file every feature touches and section 8 is
//  being built by several hands at once, so a new token there is a merge conflict for all of
//  them. The amber in particular belongs in `Theme` once the section lands — `8k` writes
//  "Needs a coach" in it too — and the PR says so.
//
//  Nothing here is invented. The amber is transcribed from the design's `#B67A16 / #8A6416 /
//  #FAF6EC`, and its dark column is derived the way `Theme` derives its own: the ink lightens
//  so it clears 4.5:1 on a dark surface, the plate climbs the elevation ladder rather than
//  going flat black.
//

import SwiftUI

enum OverviewTheme {

    // MARK: Warning amber

    /// A closed court's second line, and the warning glyph on its badge — `#B67A16`.
    static let warning = Theme.warning
    /// A closed court's title and the label on its badge — `#8A6416`. A step darker than
    /// `warning` so the two read apart at 12.5pt.
    static let warningInk = Theme.warningDark
    /// The plate a `Closed` badge sits on — `#FAF6EC`.
    static let warningTint = Theme.warningTint

    // MARK: Lift

    /// `0 8px 22px rgba(26,127,85,.08)` — the soft green lift under your own court's card.
    ///
    /// Green in the light scheme because the design casts it that way: the card is already
    /// bordered in `accentBorder`, and a neutral shadow under it read as grime rather than as
    /// the tint spreading. In the dark it reverts to the near-black every other shadow in the
    /// app uses — a green bloom on a near-black surface is a glow, not a lift.
    static let yourCourtLift = ShadowToken(
        color: Color(light: "1A7F55", dark: "000000").opacity(0.14), radius: 11, y: 8
    )

    // MARK: Metrics
    //
    // The design's own numbers, named rather than spelled at the call site.

    /// `gap:9px` between the cards down the page.
    static let cardGap: CGFloat = 9
    /// `padding:14px` inside a court card.
    static let cardPadding: CGFloat = 14
    /// The card header's `gap:10px`, between the title block and what closes the row.
    static let headerGap: CGFloat = 10
    /// `margin-top:4px` — title to subtitle.
    static let titleGap: CGFloat = 4
    /// `margin-bottom:9px` — the "Your court" overline to the header row.
    static let overlineGap: CGFloat = 9
    /// `padding:6px 4px 0` — the "Other courts" overline is inset a little from the cards it
    /// heads rather than sitting flush with their border.
    static let overlineInset: CGFloat = 4
    /// The `12px` either side of a card's inner rule.
    static let ruleGap: CGFloat = 12
    /// The roster's `gap:10px`, rank column to name.
    static let rosterGap: CGFloat = 10
    /// `width:17px` — the right-aligned rank column.
    static let rankWidth: CGFloat = 17
    /// The 13pt marks at the end of a roster line.
    static let rosterGlyph: CGFloat = 13
    /// The 16pt caret that closes a card's header row.
    static let caretGlyph: CGFloat = 16
    /// The roster's `line-height:1.65` restated as padding, so it grows with Dynamic Type
    /// instead of pinning a row height that larger text would spill out of.
    static let rosterRowPadding: CGFloat = 3
    /// The 30pt disc inside a coach pill.
    static let coachAvatar: CGFloat = 30
    /// The coach pill's `padding:4px 13px 4px 4px` — the disc sits tight against the leading
    /// edge and the name gets the room.
    static let coachPillInset: CGFloat = 4
    static let coachPillTrailing: CGFloat = 13
    /// A `Closed` badge — `padding:6px 12px`, `gap:7px`.
    static let badgeHorizontal: CGFloat = 12
    static let badgeVertical: CGFloat = 6
    static let badgeGap: CGFloat = 7
    /// The filled `Open` pill your own court carries — `padding:9px 15px`.
    static let statusPillHorizontal: CGFloat = 15
    static let statusPillVertical: CGFloat = 9
    /// The 14pt warning glyph on a `Closed` badge.
    static let badgeGlyph: CGFloat = 14
    /// The pinned note banner — `padding:10px 12px`, `gap:9px`, a 14pt pin.
    static let bannerHorizontal: CGFloat = 12
    static let bannerVertical: CGFloat = 10
    static let bannerGap: CGFloat = 9
    static let bannerGlyph: CGFloat = 14
}
