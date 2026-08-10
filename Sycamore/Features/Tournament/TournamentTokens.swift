//
//  TournamentTokens.swift
//  Sycamore
//
//  The numbers and type roles the Tournament tab is drawn from, transcribed out of the design's
//  inline CSS — `design/app/regions/showApp.html` under `<sc-if value="{{ tabIsTourn }}">`, plus
//  `sheet-shTourney.html` and `sheet-shScore.html`. Nothing here is rounded to a nicer value;
//  where a size reads 15.5 or 11.5 it is because the design draws it that way.
//
//  It declares no colours. Every hex in those three regions already has a name in `Theme` —
//  `#EDEEF1` is `hairline`, `#F2F3F6` is `hairlineSoft`, `#F1F2F5` is `fill`, `#F6FAF7`/`#C3DFCF`
//  are `accentSurface`/`accentBorder`, `#14684A` is `accentDark`, `#B67A16` is `warning` — so a
//  private palette here would be a second name for a colour that already has one. `ScheduleTokens`
//  makes the same argument from the same position and it is worth restating: a local alias for a
//  shared token is how two names for one colour start.
//
//  ── ONE DEPARTURE, MADE EVERYWHERE ────────────────────────────────────────────────────────────
//
//  **The design's two lightest greys are not used for copy anybody has to read.** This region sets
//  its quiet lines in `#A2A6AE` (`Theme.inkFaint`, ~2.6:1 on white) and `#8A8E96`
//  (`Theme.inkMuted`, ~3.5:1), and its match numerals in `#C7CBD2` (`Theme.chevron`, ~1.9:1).
//  None of the three clears the 4.5:1 this app holds itself to for body copy, and the lines
//  concerned are not decoration — "12 of 21 played", "Team matchups come later", the `M7` a
//  bracket box points back at with "Winner of M7". So every one of them is drawn in
//  `Theme.inkTertiary` (4.6:1), which is the next step up the same ramp and the only token in that
//  neighbourhood that passes.
//
//  It is stated once, here, rather than apologised for at thirty call sites. What is *not* moved
//  is anything genuinely decorative and hidden from VoiceOver — there is nothing of that kind on
//  this tab, which is rather the point.
//

import SwiftUI

// MARK: - Type

/// The design's `font:` shorthands for this tab, aliased onto the shared table so the call sites
/// keep reading in this screen's vocabulary while the numbers behind them live in one place.
///
/// Aliases and not declarations, following `GroupsType` and `ScheduleType`: every row below
/// resolves to something `Typography.swift` already carries, and the two that do not — a title at
/// 15.5 and a label tracked `-.01em` — are derivations of rows that do.
enum TournamentType {

    // MARK: A card

    /// `600 15.5`, `-.025em` — "Tournament 1" at the head of a card.
    static let cardTitle = TypeStyle.rowTitle.size(15.5)

    /// `600 12.5`, `-.01em` — "Order of play", "Standings", "Team 1". The design's own section
    /// label inside a card, and the same cut `SheetFieldLabel` draws inside a sheet.
    static let sectionLabel = TypeStyle.metaStrong.tracking(em: -0.01)

    /// `400 12` — "12 of 21 played", the count beside a team's name.
    static let sectionMeta = TypeStyle.meta

    /// `600 11.5` — a card's format chips ("Singles", "Round robin", "2 days", "Group 1+2").
    static let tag = TypeStyle.dividerLabel

    // MARK: The order of play

    /// `400 12` — the `M7` column. Tabular, because it is a column of figures.
    static let matchNumber = TypeStyle.meta

    /// `500 13.5`, `-.015em` — "Serene C + Liam P vs Austin Z + Mia K".
    static let matchLabel = TypeStyle.subtitle.weight(.medium).tracking(em: -0.015)

    /// `600 13` — the score beside a played match.
    static let matchScore = TypeStyle.countdown

    /// `600 12.5` — the "Score" affordance on a match nobody has entered yet.
    static let matchAction = TypeStyle.chipMedium

    /// `500 11.5/1.4` — "Moved — Serene C away Monday". The amber line under a match.
    static let matchFlag = TypeStyle.rowSubtitleSmall.weight(.medium).lineHeight(1.4)

    // MARK: The bracket

    /// `600 11.5`, `-.01em` — "Quarters", "Semis", "Final" over a bracket column.
    static let bracketRound = TypeStyle.dividerLabel.tracking(em: -0.01)

    /// `500 12.5`, `-.01em` — a name inside a bracket box. `600` once they have won it, which is
    /// `weight(.semibold)` at the call site rather than a second row here.
    static let bracketName = TypeStyle.rowSubtitle.tracking(em: -0.01)

    /// `600 11.5` — the figure beside that name.
    static let bracketScore = TypeStyle.dividerLabel

    // MARK: A team

    /// `400 13/1.6` — the roster line under a team's name, "Serene C · Liam P · Austin Z".
    static let teamRoster = TypeStyle.sheetSubtitle.lineHeight(1.6)

    // MARK: Empty states

    /// `400 24/1.15 Newsreader`, `-.02em` — "No draws yet."
    ///
    /// Serif, and that is the design: all three of this tab's empty states set their heading in
    /// Newsreader at 24, exactly as `8f`, `8g` and `8h` do — which is why `GroupsType.lockedHeading`
    /// and `ScheduleType.emptyHeading` are already this same row. The house rule is that serif is
    /// for titles and not for copy; an empty state's one line *is* the title of the card it heads.
    static let emptyHeading = TypeStyle.profileName

    /// `400 13.5/1.55` — the paragraph under it.
    static let emptyBody = TypeStyle.emptyBody

    // MARK: The sheets

    /// `500 14.5`, `-.01em` — "Doubles" on a format row.
    static let formatTitle = TypeStyle.rowLabel.weight(.medium).tracking(em: -0.01)

    /// `400 12` — "Pairs — requested first, then by skill".
    static let formatSubtitle = TypeStyle.meta

    /// `600 17` — the value between a stepper's two buttons.
    static let stepperValue = TypeStyle.fieldTitle.tracking(em: 0)

    /// `400 12/1.5` — the hint under a stepper, and the pairing hint.
    static let hint = TypeStyle.footnote.weight(.regular).size(12)

    /// `600 14`, `-.02em` — a side's name over the score stepper that belongs to it.
    static let scoreName = TypeStyle.rowTitleSm

    /// `600 20` — the score itself.
    static let scoreValue = TypeStyle.statValue
}

// MARK: - Geometry

enum TournamentMetrics {

    // MARK: The list

    /// `padding:14px 12px 120px` — the drop from the header's rule to the first card. The gutter
    /// either side is `Spacing.gutter` and the foot is `Spacing.tabBarClearance`.
    static let listTop: CGFloat = 14
    /// `gap:9px` — between cards, and between a card and the "Add a tournament" row.
    static let cardGap: CGFloat = 9

    // MARK: A card

    /// `border-radius:16px` — a point tighter than `Radius.card`, the same as every other
    /// section-8 card. Hoist when a third feature agrees; `GroupsMetrics.cardRadius` and
    /// `ScheduleMetrics.cardRadius` are already the same number arrived at the same way.
    static let cardRadius: CGFloat = 16
    /// `padding:14px` inside a card.
    static let cardPadding: CGFloat = 14
    /// `padding:22px 18px` inside an empty-state card, which is the only one with room to breathe.
    static let emptyPaddingVertical: CGFloat = 22
    static let emptyPaddingHorizontal: CGFloat = 18
    /// `max-width:280px` across an empty state's paragraph, so it breaks where the design breaks
    /// it rather than running the full width of the card.
    static let emptyCopyWidth: CGFloat = 280
    /// `margin-top:8px` under an empty state's heading, and `16` above its button.
    static let emptyCopyGap: CGFloat = 8
    static let emptyActionGap: CGFloat = 16
    /// `height:48px` — an empty state's call to action, which is shorter than the app's 56.
    static let emptyActionHeight: CGFloat = 48

    /// `gap:6px;margin-top:8px` — the row of format tags under a card's title.
    static let tagGap: CGFloat = 6
    static let tagRowGap: CGFloat = 8
    /// `padding:4px 10px` inside one tag.
    static let tagPaddingHorizontal: CGFloat = 10
    static let tagPaddingVertical: CGFloat = 4

    /// `margin-top:11px;padding-top:11px` — every section rule inside a card.
    static let sectionGap: CGFloat = 11
    /// `gap:10px` — between a section's label and the figure at the end of its line.
    static let sectionLabelGap: CGFloat = 10

    // MARK: The order of play

    /// `width:26px` — the `M7` column, and the indent "+3 more" lines up under.
    static let numberColumn: CGFloat = 26
    /// `gap:10px` — the numeral, the label, the score.
    static let matchGap: CGFloat = 10
    /// `padding:8px 0` on an ordinary row, `8px 10px` on the one that is up next.
    static let matchPaddingVertical: CGFloat = 8
    static let matchPaddingHorizontal: CGFloat = 10
    /// `margin:4px -8px` — the up-next row bleeds a little past the card's own gutter, so its ring
    /// reads as around the row rather than inside it.
    static let upNextInset: CGFloat = 8
    static let upNextGap: CGFloat = 4
    /// `border-radius:11px` on that ring.
    static let upNextRadius: CGFloat = Radius.control
    /// `margin:3px 0 0 36px` — the amber line, indented past the numeral column.
    static let flagGap: CGFloat = 3
    /// `font-size:12px` — the caret closing a match row.
    static let matchCaret: CGFloat = 12
    /// `gap:7px;margin-top:9px` — the day pills.
    static let dayPillGap: CGFloat = 7
    static let dayPillRowGap: CGFloat = 9

    // MARK: The bracket

    /// `width:150px` — one bracket column. Fixed, because the columns scroll horizontally and a
    /// column that sized to its widest name would make the round boundaries ragged.
    ///
    /// `@ScaledMetric` at the call site rather than here: at `.accessibility1` a 12.5pt name is
    /// half again as tall and two of them plus a rule do not fit 150 without clipping.
    static let bracketColumn: CGFloat = 150
    /// `gap:10px` between columns, `gap:8px` between boxes in one.
    static let bracketColumnGap: CGFloat = 10
    static let bracketBoxGap: CGFloat = 8
    /// `border-radius:11px;padding:7px 10px` — one box, and one side inside it.
    static let bracketBoxRadius: CGFloat = Radius.control
    static let bracketSidePaddingVertical: CGFloat = 7
    static let bracketSidePaddingHorizontal: CGFloat = 10
    static let bracketSideGap: CGFloat = 7
    /// `padding:0 2px 6px` under a column's heading.
    static let bracketHeadingGap: CGFloat = 6

    // MARK: A team

    /// `padding:9px 0` — one team's block inside a card.
    static let teamPaddingVertical: CGFloat = 9
    /// `gap:7px;margin-top:8px` — the coach chips under a team's name.
    static let coachChipGap: CGFloat = 7
    static let coachChipRowGap: CGFloat = 8
    /// `margin-top:7px` — the roster line under the chips.
    static let teamRosterGap: CGFloat = 7

    // MARK: The add row

    /// `padding:15px 13px;gap:12px` — the dashed "Add a tournament" row.
    static let addPaddingVertical: CGFloat = 15
    static let addPaddingHorizontal: CGFloat = 13
    static let addGap: CGFloat = 12
    /// `width:44px;height:44px;border-radius:14px` — its tile, and `font-size:18px` the plus.
    static let addTile: CGFloat = 44
    static let addGlyph: CGFloat = 18
    /// `margin-top:3px` — between its two lines.
    static let addSubtitleGap: CGFloat = 3
    /// `border:1.5px dashed #C3DFCF`, drawn `[4, 3]` the way `GroupsMetrics.dash` draws the only
    /// other dashed invitation in the app.
    static let addDash: [CGFloat] = [4, 3]

    // MARK: The sheets

    /// `width:34px;height:34px;border-radius:11px` — the tile on a format row, and `17` its glyph.
    static let formatTile: CGFloat = 34
    static let formatTileRadius: CGFloat = Radius.control
    static let formatGlyph: CGFloat = 17
    /// `gap:11px;padding:13px` — a format row.
    static let formatGap: CGFloat = 11
    static let formatPadding: CGFloat = 13
    /// `font-size:21px` — the tick, or the empty ring, at the end of it.
    static let formatMark: CGFloat = 21

    /// `border:1.5px;border-radius:15px;padding:6px` — a stepper's track.
    static let stepperPadding: CGFloat = 6
    static let stepperRadius: CGFloat = Radius.input
    /// `width:38px;height:38px;border-radius:11px` — its two buttons, and `15` their glyphs.
    static let stepperButton: CGFloat = 38
    static let stepperButtonRadius: CGFloat = Radius.control
    static let stepperGlyph: CGFloat = 15
    /// `gap:9px` — the teams stepper beside the days stepper.
    static let stepperPairGap: CGFloat = 9

    /// `border-radius:15px;padding:11px 13px` — one side's plate in the score sheet.
    static let scorePlateRadius: CGFloat = Radius.input
    static let scorePlatePaddingVertical: CGFloat = 11
    static let scorePlatePaddingHorizontal: CGFloat = 13
    /// `width:32px;height:32px;border-radius:10px` — its steppers, a size down from the sheet's.
    static let scoreStepperButton: CGFloat = 32
    static let scoreStepperRadius: CGFloat = Radius.banner
    static let scoreStepperGlyph: CGFloat = 13
    /// `gap:8px;margin-top:8px` — inside a plate, and `gap:9px` between the two of them.
    static let scoreStepperGap: CGFloat = 8
    static let scorePlateGap: CGFloat = 9

    /// `max-height:150px` on the sheet's scroller of unpaired kids, so the pairing picker cannot
    /// push the create button off the bottom of a long ladder.
    static let pairPickerHeight: CGFloat = 150

    /// `padding:8px 13px` — a requested-pair chip, which is a size up from the kid chips beneath it
    /// because it carries a glyph as well as a label.
    static let pairChipPaddingHorizontal: CGFloat = 13
    /// `font-size:11px` — its ✕, at 60% white. The one glyph on this tab drawn under 12.
    static let pairChipGlyph: CGFloat = 11
    /// `rgba(255,255,255,.6)` — that ✕ against the chip's black plate.
    static let pairChipGlyphOpacity: Double = 0.6

    /// `width:96px` — the app mark bled off the corner of an empty-state card, at `opacity:.18`.
    static let watermark: CGFloat = 96
    static let watermarkOpacity: Double = 0.18
    /// `right:-8px;bottom:-14px` — how far past the card's two edges it sits.
    static let watermarkInsetX: CGFloat = 8
    static let watermarkInsetY: CGFloat = 14

    /// `opacity:.45` — what the design draws a call to action at when it cannot be pressed.
    ///
    /// Paired with a real `.disabled(_:)` at every call site and never used alone: opacity is what
    /// a sighted reader sees, `.disabled` is what VoiceOver and Voice Control are told, and a
    /// button that only *looks* unavailable is one a switch-control user can still fire.
    static let disabledOpacity: Double = 0.45
}

// MARK: - Rules

enum TournamentRules {

    /// Matches one day of an order of play shows before "+N more". The design draws ten
    /// (`state1.js:830`).
    static let orderPreviewRows = 10

    /// Rows a folded standings table shows. The design draws three (`state1.js:889`).
    static let standingsPreviewRows = 3

    /// How many days a draw may be spread over. The design's sheet clamps 1…5 (`state1.js:359`).
    static let dayRange = 1...5

    /// How many teams a team-tennis draw may be cut into. The design clamps 2…8 (`:362`).
    static let teamRange = 2...8

    /// How many tournaments a ladder may be split into by rank.
    ///
    /// **This range has no counterpart in the live design.** `createTourney2` draws exactly one
    /// tournament per sheet; the band split is the earlier `createTournament(fm, cnt)`
    /// (`state1.js:670`), which clamped its count to 1…8 and was replaced by the court picker.
    /// `Tournament.banded(_:namePrefix:ladder:into:courtIndices:days:)` is the model half of that
    /// question and this is the screen half — see `TournamentSheet.splitSection`.
    static let splitRange = 1...8

    /// The highest score either side of a match may be given. The design's stepper stops at 12
    /// (`state1.js:377`), which is a long set and then some.
    static let scoreRange = 0...12

    /// How many of `count` rows to draw. The `+ 1` is `GroupsRules.visibleCount`'s rule and it is
    /// the same rule for the same reason: folding a single row away spends a "1 more" row to hide
    /// a row, which is not a saving.
    static func visibleCount(of count: Int, preview: Int, isExpanded: Bool) -> Int {
        isExpanded || count <= preview + 1 ? count : preview
    }

    /// Whether the fold control belongs under those rows.
    ///
    /// **This has to be asked of `visibleCount`, not of `preview`.** Both sections of a tournament
    /// card originally gated their `MoreRow` on `count > preview`, which is a *different* predicate
    /// from the one above and disagrees with it at exactly one value: `count == preview + 1`. A
    /// four-entrant round robin drew all four places — correctly, by the `+ 1` rule — and then put
    /// "+0 more" underneath them. A disclosure offering zero rows is a control that does nothing,
    /// and it was on screen for the most ordinary draw there is.
    ///
    /// Stated once, over the same function the rows come from, so the two cannot drift apart again.
    /// `InboxClearedList.swift:36` has always asked it this way (`hiddenCount > 0 || isExpanded`);
    /// this is that rule, named.
    ///
    /// The `isExpanded` half is not redundant: expanded, nothing is hidden, and the row still has
    /// to be there to fold the table back up.
    static func showsMoreRow(of count: Int, preview: Int, isExpanded: Bool) -> Bool {
        isExpanded || visibleCount(of: count, preview: preview, isExpanded: false) < count
    }
}

// MARK: - Chips

extension ChipMetrics {

    /// The day pills over an order of play — `600 12.5`, `6/13`, pill.
    ///
    /// Not `ChipMetrics.venue`, which is the same size at `7/13` with the `strokeChip` border:
    /// these sit *inside* a card rather than on a header block, and the design gives them
    /// `strokeAlt` accordingly — the same call `ChipMetrics.time` and `.court` make for the chips
    /// that live inside sheets.
    static let tournamentDay = ChipMetrics(
        font: TypeStyle.chipMedium,
        horizontalPadding: 13,
        verticalPadding: 6,
        radius: Radius.pill,
        spacing: Spacing.tight,
        unselectedBorder: Theme.strokeAlt,
        emojiSize: 12.5
    )

    /// A coach chip on a team, and a kid's chip in the pairing picker — `600 12`, `6/12`, pill.
    ///
    /// The design draws the coach chip `6/12` and the kid chip `6/11`, which is one point of
    /// horizontal padding between two chips that wrap in the same way at the same size in the same
    /// two sheets. One preset rather than two: the difference is under the width of the space
    /// either side of the label, and a second preset for it would be a token nobody could tell
    /// apart on screen.
    static let tournamentPick = ChipMetrics(
        font: TypeStyle.chipSmall,
        horizontalPadding: 12,
        verticalPadding: 6,
        radius: Radius.pill,
        spacing: Spacing.tight,
        unselectedBorder: Theme.strokeChip,
        emojiSize: 12
    )
}
