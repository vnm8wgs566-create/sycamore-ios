//
//  OverviewTheme.swift
//  Sycamore
//
//  The tokens `8i` / `8j` need that `Theme` and the type table do not carry: the accent-tinted
//  lift under your own court, the type styles the design sets Overview in, and the metrics it
//  draws the screen with.
//
//  The colour and the metrics are local to this folder on purpose. `Theme` is the file every
//  feature touches and section 8 is being built by several hands at once, so a new token there is
//  a merge conflict for all of them. Several belong upstairs once the section lands.
//
//  Most of the type went upstairs already: the shared table now draws section 8's weights, so the
//  styles below are aliases onto it wherever it has a row. Four are declared outright, because the
//  table has no row within a rounding of them and `Typography.swift` is another unit's file — each
//  says so where it is declared.
//
//  ── Every number below is now read off the frames themselves ─────────────────────────────────
//
//  This file used to say "nothing here is invented", and it was very nearly true: the numbers were
//  transcribed from a design nobody in the repository could open. `design/Sycamore 3a System.dc.html`
//  is here now, and holding the two side by side moved eleven of them — the card's title is 19 and
//  not 17, its coach disc 26 and not 30, the rank column 14 and not 17, both badges a size smaller.
//  The CSS each one came from is quoted beside it, so the next person can check rather than trust.
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

    /// `#C09A4A` — a closed court's own label, on the card and on `8j`'s condensed row.
    ///
    ///     8i:  color:#C09A4A   >Court 4<
    ///     8j:  color:#C09A4A   >Court 4<   (the row in "Other courts")
    ///
    /// Deliberately not `Theme.warning` (`#B67A16`), which is the amber the *reason* is set in two
    /// lines down. The design draws the two together and they are visibly different — the label is
    /// the quieter, sandier end, so the eyebrow tints without competing with the sentence under it.
    /// Substituting the one for the other would flatten a deliberate pair into one colour.
    ///
    /// The dark end is derived the way `Theme`'s amber family is: a desaturated step lighter than
    /// `warning`'s own dark value (`#E0A845`), keeping the same relation the light pair has.
    static let closedCourtLabel = Color(light: "C09A4A", dark: "D7B87A")

    /// `#FDFBF5` — the plate behind a closed court's row in `8j`'s "Other courts" card.
    ///
    ///     background:#FDFBF5
    ///
    /// A far paler wash than `Theme.warningTint` (`#FAF6EC`), and the difference is the point: the
    /// tint is a *pill* the eye lands on, this is a whole row inside a white card and has to stay
    /// under the copy on it. Dark is the same relation against `Theme.surface`'s `#1C1C1E` — warm,
    /// and barely there.
    static let closedRowFill = Color(light: "FDFBF5", dark: "232019")

    /// What colour a court's small label is, given whether it is in play.
    ///
    /// A function rather than the ternary written out, because it was written out three times —
    /// once on the full card, once on `8j`'s condensed row, and once more for the title below it.
    /// "A closed court's label goes sandy" is one rule about the design and it should be sayable
    /// once; three copies is three chances for a fourth court view to pick `Theme.warning` and for
    /// nobody to notice which of the two ambers it was meant to be.
    ///
    /// `Theme.color(for:)` is the precedent for a colour that is a decision rather than a constant.
    static func courtLabelColour(isClosed: Bool) -> Color {
        isClosed ? closedCourtLabel : Theme.inkFaint
    }

    /// And what colour its big line is. The pair above, for the title rather than the label.
    static func courtTitleColour(isClosed: Bool) -> Color {
        isClosed ? Theme.warningDark : Theme.ink
    }

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
    // The styles the type table had no row for when these screens were written, because it was
    // still transcribed from the design's earlier and heavier ones. It carries section 8's weights
    // now, so most of these are names onto it rather than a scale of their own.
    //
    // Four are declared outright — `cardTitle`, `coachName`, `rosterName` and `capacityPill` — and
    // `Typography.swift` belongs to another unit, so they are the rows to hoist first when section
    // 8's type pass lands. Three of the four have nothing upstairs within a rounding: there is no
    // 19, no `500 13` and no `600 11`.
    //
    // `rosterName` is the exception and is worth being honest about. `TypeStyle.bodyAlt` *is*
    // `500 14` — the same size and weight — differing only in a `1.5` line height, and
    // `lineHeight(nil)` would strip that, so `bodyAlt.lineHeight(nil).tracking(em: -.015)` is
    // expressible. It is declared anyway because that expression is not an alias, it is a
    // subtraction: `bodyAlt`'s role is "descriptive copy with air between its lines" and this is a
    // name in a ranked list, and a reader following the chain would arrive at a paragraph style
    // with its defining property removed. Two roles that agree on two numbers are not one row.

    /// `600 10.5`, `+.14em`, uppercase — "YOUR COURT" and "OTHER COURTS".
    ///
    ///     8j: font:600 10.5px;letter-spacing:.14em;text-transform:uppercase
    static let overline = TypeStyle.overlineSmall

    /// `600 10`, `+.16em`, uppercase — "COURT 1" at the head of a card.
    ///
    ///     8i: font:600 10px;letter-spacing:.16em;text-transform:uppercase;color:#A2A6AE
    ///
    /// Two points smaller and a shade wider than the section headings above, and the difference is
    /// meaningful: those head a *region* of the screen, this labels one card inside it.
    static let courtLabel = TypeStyle.statLabel.tracking(em: 0.16)

    /// `600 10`, `+.14em`, uppercase — the same label on `8j`'s condensed rows.
    ///
    ///     8j: font:600 10px;letter-spacing:.14em;text-transform:uppercase
    ///
    /// Its own constant rather than sharing `courtLabel`'s: the design genuinely tracks the two
    /// differently, and a row that sits in a list of three needs less air between its letters than
    /// one heading a card of its own.
    static let condensedCourtLabel = TypeStyle.statLabel.tracking(em: 0.14)

    /// `600 19`, `-.035em` — a court card's big line.
    ///
    ///     8i/8j: font:600 19px 'Instrument Sans';letter-spacing:-.035em
    ///
    /// **Two points larger than this used to be.** It was `venueHeading` (`600 17`, `-.03em`),
    /// which was the nearest row upstairs and was a guess at a frame nobody could open. The frames
    /// are in the repository now and both set 19: the activity is the subject of the card, and at
    /// 17 it sat level with a group's name on Groups rather than above it.
    static let cardTitle = TypeStyle(size: 19, weight: .semibold, trackingEm: -0.035)

    /// `400 13` — a sentence set at card scale. The coach picker's empty card is what is left
    /// reading this; the court card's own second line is `capacityReading` now.
    static let cardSubtitle = TypeStyle.sheetSubtitle

    /// `400 12.5` — "8 of 8" at the head of a card.
    ///
    ///     8i: font:400 12.5px 'Instrument Sans';color:#A2A6AE
    static let capacityReading = TypeStyle.rowDetail

    /// `600 11` — "2 spots" inside the dashed pill beside it.
    ///
    ///     8i: font:600 11px 'Instrument Sans';color:#1A7F55
    static let capacityPill = TypeStyle(size: 11, weight: .semibold)

    /// `400 13` — the trailing clause on a closed court, "· Tom is on it".
    ///
    ///     8i: font:400 13px 'Instrument Sans';letter-spacing:0;color:#B67A16
    ///
    /// The design runs this *inside* the title's own line as a `<span>` that resets the weight, the
    /// size and the tracking. `OverviewCourtCard.title` composes it the same way, with
    /// `typeStyleRun`, so a long reason wraps under the activity rather than being pushed onto a
    /// second element the eye reads as a subtitle.
    static let closureReason = TypeStyle.sheetSubtitle

    /// `500 13` — the coach's name under the title.
    ///
    ///     8i: font:500 13px 'Instrument Sans';color:#3F4A44
    static let coachName = TypeStyle(size: 13, weight: .medium)

    /// `600 13` — "Add a coach" in its place, on a court nobody has.
    ///
    ///     8i: font:600 13px 'Instrument Sans';color:#1A7F55
    static let addCoach = TypeStyle.chip

    /// `400 13.5/1.55` — the note hanging off the block on your own court.
    static let cardNote = TypeStyle.subtitle.lineHeight(1.55)

    /// `500 14`, `-.015em` — a name in a court's list.
    ///
    ///     8i/8j: font:500 14px 'Instrument Sans';letter-spacing:-.015em
    ///
    /// Half a point larger and a weight heavier than the `400 13.5` this used to be — which was
    /// `subtitle`, the row the table offers for "a name in a court's list", and which the frames
    /// disagree with. The names are the thing a coach scans the card for, and the design lets them
    /// sit above the numerals and the marks rather than level with them.
    ///
    /// No line-height: each name is its own single-line `Text`, and SwiftUI's `lineSpacing` only
    /// ever falls *between* lines, so one here would be inert and misleading. `rosterRowPadding`
    /// carries the design's row rhythm instead.
    static let rosterName = TypeStyle(size: 14, weight: .medium, trackingEm: -0.015)

    /// `400 12.5` — the rank numeral beside it.
    ///
    ///     8i: font:400 12.5px 'Instrument Sans';color:#C7CBD2;font-variant-numeric:tabular-nums
    ///
    /// The design's `tabular-nums` is drawn too — see `CourtRosterRow`. It is not decoration at
    /// this size: `rankWidth` is 14pt, which two proportional digits can overrun and two tabular
    /// ones cannot.
    static let rosterRank = TypeStyle.rowDetail

    /// `600 12.5` — the filled `Open` pill your own court carries.
    ///
    ///     8j: font:600 12.5px 'Instrument Sans';color:#fff
    static let statusPill = TypeStyle.chipMedium

    /// `600 11.5` — the `Closed` badge's label.
    ///
    ///     8i: font:600 11.5px 'Instrument Sans';color:#8A6416
    static let closedBadge = TypeStyle.dividerLabel

    // `8j`'s condensed rows — "Court 2 · Match play · Alina".

    /// `600 15`, `-.025em` — the activity on a condensed row.
    ///
    ///     8j: font:600 15px 'Instrument Sans';letter-spacing:-.025em
    ///
    /// `bodyStrong` re-tracked rather than restated. The table's row is `-.02em`, which is 0.075pt
    /// apart at this size; `rowLabel`'s own doc records the same 0.005em drift and the same fix.
    static let condensedTitle = TypeStyle.bodyStrong.tracking(em: -0.025)

    /// `500 12.5` — the coach's name on a condensed row, and the word `Closed` in its place.
    ///
    ///     8j: font:500 12.5px 'Instrument Sans';color:#5C6068
    static let condensedMeta = TypeStyle.rowSubtitle

    // The three the empty-blocks card is set in. Named against `8f`'s hero, which is the frame
    // this screen's version of that card is transcribed from — see `OverviewEmptyDayHero`.

    /// `24` serif — "No blocks on Wednesday."
    static let emptyHeading = TypeStyle.profileName

    /// `400 13.5/1.6` — the sentence under it.
    static let emptyCopy = TypeStyle.emptyBody

    /// `600 15` — "Add a block".
    static let emptyCta = TypeStyle.bodyStrong

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
    /// The card header's `gap:10px`, between the court's label and what closes the row.
    static let headerGap: CGFloat = 10
    /// `margin-top:7px` — the header row to the card's big line.
    ///
    /// Four, until the frames arrived. Four was right while the two were a title and a subtitle
    /// stacked together; they are a label *over* a title now, which is a wider step.
    static let titleGap: CGFloat = 7
    /// `margin-top:11px` — the title to the coach beneath it.
    static let coachRowGap: CGFloat = 11
    /// `gap:9px` — the coach's disc to their name.
    static let coachRowSpacing: CGFloat = 9
    /// `margin-bottom:9px` — the "Your court" overline to the header row.
    static let overlineGap: CGFloat = 9
    /// `padding:6px 4px 0` — the "Other courts" overline is inset a little from the cards it
    /// heads rather than sitting flush with their border.
    static let overlineInset: CGFloat = 4
    /// `margin-top:11px;padding-top:11px` — the 11pt either side of a card's inner rule.
    static let ruleGap: CGFloat = 11
    /// The roster's `gap:12px`, rank column to name.
    static let rosterGap: CGFloat = 12
    /// The roster's `gap:1px`, line to line. With `rosterRowPadding` either side of a row the
    /// three sum to the design's `gap:7px` between one name and the next.
    ///
    /// **That sum holds only where the row is drawn as a plain line.** `CourtRosterButton` grows
    /// the same row to `HitTarget.minimum` (`CourtRosterButton.swift:45`), and every screen that
    /// lists a court's kids wraps it that way now — the court screen had the button first
    /// (`CourtScreen.swift:287`) and a card's roster has one since its names became taps
    /// (`OverviewCourtCard.swift:324`). A 44pt floor swallows the ~23pt a 14pt name and 3pt either
    /// side come to at the default setting, so what stands between two of those names is 44 and
    /// this 1, and not 7. Only a bare `CourtRosterRow` still measures the sum, which today is that
    /// row's own previews and nothing shipping.
    ///
    /// Unchanged at 1 all the same. It is the design's own figure, it is the whole gap wherever
    /// the rows are lines, and where they are targets it is the sliver that keeps two of them from
    /// sitting flush. It is the arithmetic that stopped describing those two screens, not the value.
    static let rosterRowGap: CGFloat = 1
    /// `width:14px` — the right-aligned rank column.
    ///
    /// Seventeen, until the frames arrived, "or a two-digit place lands in a 17pt box and
    /// truncates". Fourteen is what the design draws, and what makes it safe is the other half of
    /// the same declaration: `font-variant-numeric:tabular-nums`, now drawn. Two tabular digits of
    /// `rosterRank` measure inside 14pt where two proportional ones need more, and the column
    /// scales with the numeral in it.
    static let rankWidth: CGFloat = 14
    /// The 13pt marks at the end of a roster line.
    ///
    /// The design sets the clock at 15 and the gender mark at 14. Left at 13, deliberately:
    /// `GenderMark` sizes itself and its own header cites this constant as the number the three
    /// marks in a roster line agree on, and that agreement across two folders is worth more than
    /// two points on a glyph. It is the one measurement on this screen knowingly left off the
    /// frame.
    static let rosterGlyph: CGFloat = 13
    /// The 15pt caret that closes a card's header row.
    static let caretGlyph: CGFloat = 15
    /// The roster's `gap:7px` restated as padding either side of a row rather than as a row
    /// height, so it grows with Dynamic Type instead of pinning a height larger text would spill
    /// out of.
    ///
    /// Both screens that draw the row do pin something now — `CourtRosterButton` grows it to
    /// `HitTarget.minimum` (`CourtRosterButton.swift:45`) — but what they pin is a *floor* and not
    /// a height, and at a larger setting the two are not the same thing. Under the floor the 44 is
    /// what a reader measures and this padding sets nothing they can see; at the type sizes where
    /// the drawn line outgrows 44pt the minimum stops binding and the padding is what carries the
    /// row past it. The second case is the one the note above was written for, and it is why this
    /// stays padding: a row pinned at a flat 44 would be precisely the height larger text spills
    /// out of.
    static let rosterRowPadding: CGFloat = 3
    /// The 30pt disc inside a coach pill.
    ///
    /// The pill's, not the court card's. `8i` draws the card's coach on a 26pt disc with no plate
    /// under it at all — that is `CourtCoachLine`, and it carries `courtCoachAvatar` below. This
    /// stays where it was because the two remaining readers of `CoachPill` are `RunningBlockCard`
    /// and the court screen's own header, neither of which is a frame this unit is drawing.
    static let coachAvatar: CGFloat = 30
    /// The coach pill's `padding:4px 13px 4px 4px` — the disc sits tight against the leading
    /// edge and the name gets the room.
    static let coachPillInset: CGFloat = 4
    static let coachPillTrailing: CGFloat = 13
    /// A `Closed` badge — `padding:4px 10px`, `gap:6px`, a 13pt warning glyph.
    static let badgeHorizontal: CGFloat = 10
    static let badgeVertical: CGFloat = 4
    static let badgeGap: CGFloat = 6
    static let badgeGlyph: CGFloat = 13
    /// The filled `Open` pill your own court carries — `padding:7px 13px`.
    static let statusPillHorizontal: CGFloat = 13
    static let statusPillVertical: CGFloat = 7

    // MARK: The coach under a court's title
    //
    // `8i`'s third row: a 26pt disc and a first name, with no plate. The court nobody has draws the
    // same silhouette in a dashed green circle with a `+` in it, and "Add a coach" beside it.

    /// `width:26px;height:26px` — the disc, filled or dashed.
    static let courtCoachAvatar: CGFloat = 26
    /// `font-size:13px` — the `+` a court with nobody on it draws in place of a face.
    static let addCoachGlyph: CGFloat = 13

    /// `border:1px dashed` — the outline this screen draws round a space with nothing in it yet:
    /// the empty coach disc, and the pill that counts spare places on a court.
    ///
    /// CSS gives no dash length, so the figure is this feature's own. It is tighter than
    /// `GroupsMetrics.dash` (`[4, 3]`) because it is drawn round an 18–26pt circle rather than a
    /// full-width card, and a 4pt dash on that circumference resolves to about five strokes —
    /// which reads as a broken ring, not a dashed one. Its own constant rather than Groups', for
    /// exactly that reason: the two agree on what a dash *means* and not on how long one is.
    static let dash: [CGFloat] = [3, 2.5]

    // MARK: Room on a court
    //
    // `8i`'s "6 of 8" and the dashed pill beside it — `padding:3px 9px 3px 4px`, `gap:5px`, with an
    // 18pt white disc carrying an 11pt `+`.

    /// `gap:10px` — the reading to the pill beside it.
    ///
    /// The design's own value here is the card header's `gap:10px`, because in CSS the two are
    /// siblings in that flex row. They are one component on this side of the wire, so the gap is
    /// theirs: reading `headerGap` would mean a change to the *card's* header spacing silently
    /// re-spacing the inside of a badge that no longer lives there.
    static let capacityReadingGap: CGFloat = 10
    static let capacityPillLeading: CGFloat = 4
    static let capacityPillTrailing: CGFloat = 9
    static let capacityPillVertical: CGFloat = 3
    static let capacityPillGap: CGFloat = 5
    /// `width:18px;height:18px;background:#fff;border:1px solid #E4EDE7` — the disc inside it.
    static let capacityPillDisc: CGFloat = 18
    /// `font-size:11px` — the `+` inside that disc.
    static let capacityPillGlyph: CGFloat = 11

    // MARK: A court that is not yours
    //
    // `8j`'s "Other courts" — one card, one row per court, no roster. `padding:12px 14px`,
    // `gap:11px`, a 26pt disc, a 15pt caret.

    static let condensedRowHorizontal: CGFloat = 14
    static let condensedRowVertical: CGFloat = 12
    static let condensedRowGap: CGFloat = 11
    /// The pinned note banner — `padding:10px 12px`, `gap:9px`, a 14pt pin.
    static let bannerHorizontal: CGFloat = 12
    static let bannerVertical: CGFloat = 10
    static let bannerGap: CGFloat = 9
    static let bannerGlyph: CGFloat = 14

    // MARK: The running block
    //
    // `RunningBlockCard` is not in the design — see its header for why the design's own header line
    // implies it — so these are composed from the numbers around them rather than transcribed. The
    // card is a court card's frame with different contents, and it says so by reusing that card's
    // radius, padding, rule gap and title metrics rather than picking new ones.

    /// One note on the block to the next.
    static let noteStackGap: CGFloat = 8
    /// The mark at the head of a note to the note itself — the banner's `gap:9px`, restated because
    /// a value shared by coincidence is a value that gets changed for one caller.
    static let noteGap: CGFloat = 9
    /// The 13pt mark itself, in the callout band alongside the marks at the end of a roster line.
    static let noteGlyph: CGFloat = 13

    // MARK: The coach picker

    /// The disc in a picker row — the same one as in the pill the sheet was opened from, and
    /// written as that rather than as a second 30. Two numbers that must agree and are only equal by
    /// coincidence of typing is how the sheet ends up drawing a face the pill does not.
    static let pickerAvatar = coachAvatar
    /// The tick against whoever already has the court.
    static let pickerMark: CGFloat = 15
    /// The line under a name in the picker — `Worker · Sycamore · Court 3`.
    ///
    /// `rowDetail`, which is what `ScheduleType.assigneeMeta` puts the same line at in
    /// `BlockCoachPicker`. It read at `sheetSubtitle` here until the two were held side by side: a
    /// person drawn at 12.5 on one picker and 13 on the other is a drift nothing would ever catch,
    /// both being lists of coaches.
    static let pickerMeta = TypeStyle.rowDetail
    /// The sheet's height over 700pt.
    ///
    /// `ActiveSheet.staff`'s 0.73, because it is very nearly the same sheet — a header and a card of
    /// people. Its own constant rather than a reference to that one, for the reason
    /// `BlockEditorSheet.swift:33-37` gives about its own detent: `ActiveSheet.detentFraction` is a
    /// property of a presentation slot this sheet does not occupy.
    static let coachPickerDetent: Double = 0.73

    // MARK: A day with no blocks on it
    //
    // `8f`'s hero, and every number below is `ScheduleMetrics`' — the same eight values, restated.
    //
    // **This is a stopgap, and should not survive.** `AccentDisc.swift:21-22` is not cover for it:
    // that argument keeps sizes per-caller because the three discs it serves are "transcribed from
    // three *different* frames … so they are a real difference", and this is the same frame twice.
    // What differs between Schedule's empty day and this one is three strings, which is a parameter
    // and not a second constant table.
    //
    // It is written out here because section 8 is being built by several hands at once and the
    // consolidation crosses two folders this unit does not own — `ScheduleEmptyDayHero` would have
    // to take its copy as arguments, or the pair would have to be lifted beside `AccentDisc` in the
    // design system. Either is right; both are somebody else's file. Until then these numbers and
    // Schedule's have to be changed together, and nothing but this paragraph says so.

    static let emptyMark: CGFloat = 52
    static let emptyMarkGlyph: CGFloat = 24
    /// Mark to headline.
    static let emptyTitleGap: CGFloat = 16
    /// Headline to sentence.
    static let emptyCopyGap: CGFloat = 9
    /// Sentence to button.
    static let emptyCtaGap: CGFloat = 20
    /// The sentence is capped well short of the card so it stays a paragraph rather than a banner.
    static let emptyCopyWidth: CGFloat = 250
    static let emptyCtaHeight: CGFloat = 50
    static let emptyPaddingHorizontal: CGFloat = 20
    static let emptyPaddingVertical: CGFloat = 26

    // MARK: The fold
    //
    // Three values borrowed from Groups rather than restated. Both screens now fold a court's
    // kids to a few names behind a "+N more", and a reader who learns that shape on one tab
    // should meet exactly the same shape — same count, same rule, same curve — on the other.
    // Restating any of the three here would be three chances for the two to drift apart.

    /// Kids a folded court card lists before `+N more`.
    ///
    /// Three, not the five the design draws. Five was the count for the *one* card that listed
    /// anybody; every card lists its court now, and five names across a twelve-court venue is
    /// sixty rows before the reader has scrolled once. Three keeps a card's list to about the
    /// height of its own header, so the screen still scans as a list of courts — and the kids
    /// it folds away are one tap behind the row that counts them.
    ///
    /// Deliberately its own number and not `GroupsRules.previewRows`, which is also three. The
    /// two agree today by coincidence of layout, not by rule: a group card is full width with
    /// nothing else in it, a court card carries a header, a coach pill and sometimes a note.
    /// Aliasing them would mean a Groups decision to show four silently changed this screen.
    static let rosterPreview = 3
}
