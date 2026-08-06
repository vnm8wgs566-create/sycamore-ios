//
//  OverviewTheme.swift
//  Sycamore
//
//  The tokens `8i` / `8j` need that `Theme` and the type table do not carry: the accent-tinted
//  lift under your own court, the seven type styles the design sets Overview in, and the handful
//  of metrics it draws the screen with.
//
//  Local to this folder on purpose. `Theme` and `Typography` are the files every feature touches
//  and section 8 is being built by several hands at once, so a new token there is a merge
//  conflict for all of them. Several of these belong upstairs once the section lands — the PR
//  says which.
//
//  Nothing here is invented. Every number is transcribed from the design's own CSS and the
//  shorthand it came from is quoted beside it.
//

import SwiftUI

enum OverviewTheme {

    // MARK: Colour

    /// `#F4F5F7` — the plate under a coach pill.
    ///
    /// Names `hairlineFaint`'s value for a use that is not a line. The design draws this pill a
    /// shade lighter than `fill` (`#F1F2F5`), which is what the pill wore before the two were
    /// compared side by side. A rename upstairs, not a new colour.
    static let coachPillFill = Theme.hairlineFaint

    // MARK: Lift

    /// `0 8px 22px rgba(26,127,85,.08)` — the soft green lift under your own court's card.
    ///
    /// Green in the light scheme because the design casts it that way: the card is already
    /// bordered in `accentBorder`, and a neutral shadow under it read as grime rather than as
    /// the tint spreading. In the dark it reverts to the near-black every other shadow in the
    /// app uses — a green bloom on a near-black surface is a glow, not a lift.
    ///
    /// `.08` in CSS becomes `.14` here for the same reason `Shadows` carries every other cast
    /// heavier: SwiftUI spreads a shadow over half the radius CSS does, so matching the alpha
    /// would leave the card sitting flat. The ratio is the one `Shadows.tabBar` and
    /// `Shadows.liftedRow` already use.
    static let yourCourtLift = ShadowToken(
        color: Color(light: "1A7F55", dark: "000000").opacity(0.14), radius: 11, y: 8
    )

    // MARK: Type
    //
    // Seven styles the design sets Overview in that the type table has no row for. They are
    // written out rather than derived from a nearby style because deriving two properties off a
    // third style documents nothing — the CSS is the source, so the CSS is what is quoted.

    /// `600 10.5`, `+.14em`, uppercase — "YOUR COURT" and "OTHER COURTS".
    ///
    /// Lighter, smaller and wider than `.sectionHeader` (`700 11 / +.1em`), which is what these
    /// overlines were set in. All three differences are legible side by side at 10.5pt.
    static let overline = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.14, isUppercased: true)

    /// `600 17`, `-.03em` — a court card's big line.
    ///
    /// Semibold, not the 800 of `.venueHeading`. Overview's cards are a list to read down, and
    /// the design sets them two weights lighter than Rank's venue headings for that.
    static let cardTitle = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.03)

    /// `400 13` — "Court 1 – 8 players" under it.
    static let cardSubtitle = TypeStyle(size: 13, weight: .regular)

    /// `400 13.5/1.55` — the note hanging off the block on your own court.
    static let cardNote = TypeStyle(size: 13.5, weight: .regular, lineHeightMultiple: 1.55)

    /// `400 13.5` — a name in a court's list, and the `+3 more` under it.
    ///
    /// The design's `/1.65` is carried by `rosterRowPadding` instead: each name is its own
    /// single-line `Text`, and SwiftUI's `lineSpacing` only ever falls *between* lines, so a
    /// line-height here would be inert and misleading.
    static let rosterName = TypeStyle(size: 13.5, weight: .regular)

    /// `400 13` — the rank numeral beside it. Regular, not the 700 of `.rankNumeral`: Rank's
    /// numerals are a column you drag rows through, these are a quiet index.
    static let rosterRank = TypeStyle(size: 13, weight: .regular)

    /// `600 13` — the filled `Open` pill your own court carries.
    static let statusPill = TypeStyle(size: 13, weight: .semibold)

    // MARK: Metrics
    //
    // The design's own numbers, named rather than spelled at the call site.

    /// `gap:9px` between the cards down the page.
    static let cardGap: CGFloat = 9
    /// `border-radius:16px` on a court card. A point tighter than `Radius.card`, which the rest
    /// of the app draws at the older document's 17.
    static let cardRadius: CGFloat = 16
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
    /// The roster's `gap:1px`, line to line.
    static let rosterRowGap: CGFloat = 1
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
