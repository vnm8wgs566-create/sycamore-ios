//
//  ScheduleTokens.swift
//  Sycamore
//
//  The numbers `8k`, `8l` and `8f` are drawn from, transcribed out of their inline CSS the way
//  `Theme.swift` transcribes the rest of the design. Nothing here is rounded to a nicer value.
//
//  It declares no colours any more. Every hex in the three screens now has a name in `Theme` —
//  `#3F4A44` is `inkWarm`, `#F6FAF7`/`#E4EDE7` are `accentSurface`/`accentSurfaceBorder`,
//  `#FAFBFA` is `surfaceRaised`, `#F8F9F8` is `surfaceWarm` — so the private `noteInk`,
//  `noteTint` and `noteTintBorder` that used to live here are gone rather than aliased. A local
//  alias for a shared token is how two names for one colour start.
//
//  It declares no type of its own any more either, for the same reason. `ScheduleType` survives as
//  a set of aliases onto `TypeStyle` so the call sites keep reading in this screen's vocabulary —
//  `blockTitle`, `pickRowTitle`, `emptyCopy` — while the numbers behind them live in one place.
//
//  The geometry below is still local, and every value is a hoist candidate the moment a second
//  feature draws the same thing.
//
//  Some of it is **not** transcribed, and the header should say so rather than let the paragraph
//  above cover it. The resize handle is an affordance the design never drew, and the day canvas is
//  a screen the design never drew — `8k` was transcribed as a list of equal cards and is a
//  duration-proportional timeline now (`ScheduleTimeline.swift`). Those numbers were chosen against
//  the screen instead of read off it, and every one of them says so where it stands.
//
//  They live here anyway, beside the geometry they sit in, rather than in `ScheduleResize.swift`
//  the way `SwipeMetrics` lives beside `SwipeRevealPlan`. The split is by *kind* and not by
//  provenance: what a drag is measured **by** is in that file and in `ScheduleTimeline`, because
//  the arithmetic is what depends on it; what is actually **drawn** is here, chosen or transcribed.
//

import SwiftUI

// MARK: - Geometry

enum ScheduleMetrics {

    // MARK: Cards

    /// `16` — section 8 draws its cards a point tighter than `Radius.card`. Every card on these
    /// three screens: the block, the court, the assignee list, the notes row, the empty-day hero.
    static let cardRadius: CGFloat = 16
    /// `14` — `padding:14px` inside a block card and inside `8l`'s court card.
    static let cardPadding: CGFloat = 14
    /// `5` — `margin-top:5px` on a card's grey second line.
    static let detailGap: CGFloat = 5

    // MARK: The day canvas

    /// `14` — `8k`'s drop from the header's rule to the first block, which is now the drop to the
    /// canvas's first hour rule. The same gap doing the same job on a screen that changed shape.
    static let listTop: CGFloat = 14
    /// Where the block columns begin: after the gutter, and clear of it by the gap the block card
    /// used to keep between its own time and its own plate.
    ///
    /// A function of the gutter rather than a number, because the gutter is `@ScaledMetric` and
    /// grows with the type in it. Three things have to agree on this line — the columns start at
    /// it, their available width is what is left after it, and the now-line's dot straddles it —
    /// and written out three times they agree only until somebody retunes the gutter.
    ///
    /// `emptyListTop` used to sit here: `16`, the two points lower than `8k` that `8f` began its
    /// content at. `8f`'s hero is centred over the day's own grid now rather than starting under
    /// the header, so there is no top for it to start at.
    static func laneOrigin(after timeColumn: CGFloat) -> CGFloat {
        timeColumn + Spacing.medium
    }
    /// `9` — `gap:9px` between two blocks, and between `8l`'s cards.
    ///
    /// It is also the gap between two blocks drawn *side by side*, which is the arrangement the
    /// canvas added: two blocks running at once are still two blocks with a gap between them, and
    /// a second number for the same relationship turned ninety degrees is a second number to keep
    /// in step. `ScheduleTimeline.Placement.width(in:gap:)` is what it is handed to.
    static let blockGap: CGFloat = 9
    /// `14` — `8f`'s outer `gap:14px`, between the hero card and the shapes below it.
    static let sectionGap: CGFloat = 14

    /// `130` / `90` / `60` — the heights a block card changes layout at.
    ///
    /// Not transcribed; there was nothing to transcribe. On a proportional canvas a card is handed
    /// its height rather than growing to fit its contents, so it has to decide what it can say.
    /// Each number is measured against what the type actually occupies at the default size, inside
    /// `cardPadding` either side:
    ///
    ///   - **130** (`blockLayoutRich`, an hour and five minutes) — everything the old list drew: a
    ///     title, the span, a grey line, and the rule and note row under them. The note block alone
    ///     costs 10 + 1 + 10 + 15.
    ///   - **90** (`blockLayoutFull`, three quarters of an hour) — 28 of padding and 62 of copy: a
    ///     20pt title, a 16pt span and one 16pt grey line with `detailGap` between them. Exactly
    ///     one grey line, which is why `ScheduleBlockCard` has to choose between the clash and the
    ///     subtitle rather than drawing both.
    ///   - **60** (`blockLayoutCompact`, half an hour) — a title and a start.
    ///   - under that, one line, and it is the title: a block whose time you cannot read is still
    ///     findable by eye, because it is *drawn* at that time, and one whose name you cannot read
    ///     is not.
    ///
    /// A block's height is `ScheduleTimeline.pointsPerMinute` times its length. They are
    /// `@ScaledMetric` at the call site rather than fixed here, so a half-hour block at
    /// `.accessibility1` drops to its one line instead of clipping two.
    static let blockLayoutRich: CGFloat = 130
    static let blockLayoutFull: CGFloat = 90
    static let blockLayoutCompact: CGFloat = 60

    // MARK: The time gutter

    /// `52` — the column running down the left of `8k`.
    ///
    /// It held one time per block when the day was a list. It holds one label per *hour* now, and
    /// the blocks are placed after it rather than beside it — same column, same width, different
    /// thing in it.
    ///
    /// `timeBaseline` used to sit here: `15`, the `padding-top` that dropped a gutter time onto its
    /// card's title rather than onto the card's top edge. There is no such alignment left to make.
    /// A gutter label now belongs to a rule and sits directly under it (`Spacing.hairGap`), and the
    /// block beside it may start anywhere in that hour — so a fixed drop would align it to nothing.
    static let timeColumn: CGFloat = 52
    /// `4` — `padding:0 4px` on the rows that carry no card of their own.
    static let rowInset: CGFloat = 4

    // MARK: The resize handle

    /// `26 × 4` — the grabber on a card's bottom edge
    /// (`design/rebuild/section-t5.html:170`).
    ///
    /// `SheetGrabber`'s 38×4 (`Components.swift:37-47`) at the scale of a card rather than of a
    /// screen: deliberately the same vocabulary for "this edge moves", narrower because it is drawn
    /// on every upcoming block rather than once at the top of a sheet. It takes that component's
    /// `Theme.grabber` too, rather than a colour of its own.
    ///
    /// It was `28 × 3`, chosen by eye before the design drew one. 5c draws one, and the two points
    /// it moves are both in the same direction: shorter across and a full point thicker, which is
    /// the sheet's own bar at the sheet's own weight rather than a fainter cousin of it. A 3pt
    /// capsule in `Theme.grabber` on white is at the edge of visible; the whole affordance is that
    /// somebody notices it.
    static let resizeGrab = CGSize(width: 26, height: 4)
    /// `12` — how far the grabber sits above the card's bottom border.
    ///
    /// `Spacing.medium`, and the design's arithmetic rather than a coincidence: `bottom:6px` on a
    /// row with `padding:6px 18px` around the capsule puts 12 between the capsule and the border.
    /// It was `Spacing.tight` (6), which put the grabber inside the descenders of the last line a
    /// `.compact` card has room for.
    static let grabberLift: CGFloat = Spacing.medium
    /// How much of a block's bottom edge takes a resize drag rather than a move.
    ///
    /// A rule rather than a number, and it replaces the `76`-point column this used to be. That
    /// column was drawn against a full-width card in a list; a lane on a three-deep morning is a
    /// third of the screen, and a fixed 76 would have been most of a narrow card — so the bottom
    /// edge would have swallowed the body the move gesture now needs.
    ///
    /// The bottom half of the card, capped at the platform's minimum target. The cap is what stops
    /// a two-hour block being 44pt of edge and 196pt of nothing in particular; the half is what
    /// keeps a fifteen-minute block's title tappable, which no fixed height could — 44pt does not
    /// fit inside 30pt, and a handle taller than its card would sit over the block below it.
    ///
    /// The grabber's lift off the bottom border is `grabberLift` above. The readout no longer sits
    /// off the grabber at all — 5c centres it *on* the moving edge, out at the card's trailing
    /// corner, so the two are no longer stacked and no longer have a gap between them to name.
    static func resizeHitHeight(in blockHeight: CGFloat) -> CGFloat {
        min(HitTarget.minimum, blockHeight / 2)
    }

    // MARK: The live drag

    /// `34` — how far above the card's bottom border the amber line is pinned while a block is
    /// being dragged (`design/rebuild/section-t5.html:169`).
    ///
    /// The design's own stack read upwards: `grabberLift` (12) + the grabber (4) + 18 of air. Out
    /// of the card's flow and against its bottom edge, because a dragged card is 358pt of white
    /// with two lines at the top of it and the fact somebody needs is at the edge they are moving.
    static let dragClashBottom: CGFloat = 34

    /// `0.6` — how far the block being run into recedes while a finger is over it
    /// (`opacity:.6`, `design/rebuild/section-t5.html:162`).
    ///
    /// **One neighbour, not the rest of the day.** The design's frame dims the block being dragged
    /// onto and leaves the other resting card at full strength, which is the difference between
    /// "this is the one you are about to run into" and "everything recedes while you drag" — the
    /// second says nothing, and on a canvas whose whole subject is what else is on the morning it
    /// says it by hiding the morning.
    static let runIntoDim: Double = 0.6

    /// `10` — the live readout's inset from the card's trailing edge
    /// (`right:10px`, `design/rebuild/section-t5.html:172`).
    ///
    /// Measured off the card rather than off the lane. The design draws them in the same place
    /// because its dragged card is the full width of the lane area; on a morning with two blocks
    /// running at once a card is half of that, and a readout pinned to the lane would float away
    /// from the edge it is reporting on.
    static let readoutInset: CGFloat = 10
    /// `15` — the readout capsule's horizontal padding, against `Spacing.small` (8) vertical
    /// (`padding:8px 15px`).
    ///
    /// Not on the shared scale, and it is a capsule rather than a box: the horizontal padding has
    /// to clear the curve before the first glyph starts, which is why every pill in this design is
    /// drawn wider than it is tall by more than its type needs.
    static let readoutPadding: CGFloat = 15

    // MARK: A card's note line

    /// `10` — the rule above a note line, above and below.
    static let noteRule: CGFloat = 10
    /// `11` — …and a point more on the block running now, whose card is a point roomier
    /// throughout.
    static let noteRuleNow: CGFloat = 11
    /// `7` — `gap:7px` between the note glyph and the note.
    static let noteGap: CGFloat = 7

    // MARK: `8l`

    /// `14` / `18` — a white header block's own padding, above its first line and below its
    /// last. `ScreenHeader` carries the top one for `8k` and `8f`; `8l` draws its own header
    /// because it opens with a back caret rather than with a title.
    static let headerTop: CGFloat = 14
    static let headerBottom: CGFloat = 18
    /// `4` — the rest of the `margin-top:16px` above `8k`'s day chips. `ScreenHeader` already
    /// hangs 12 under its title, which is the number the other tabs want; this is the difference,
    /// and it goes away the day that component takes the gap as a parameter.
    static let chipRowTop: CGFloat = 4
    /// `7` — `margin-top:7px` on the header's `9:00am – 10:30am · Courts 1–3`.
    static let headerSubtitleGap: CGFloat = 7
    /// `7` — the dot beside "On now".
    static let statusDot: CGFloat = 7
    /// `10` — `gap:10px` between the court card's copy and its badge, and between the notes
    /// row's glyph and its label.
    static let rowGap: CGFloat = 10
    /// `4` — `margin-top:4px` under the header's times, which is where `5d` hangs the amber clash
    /// line. It was transcribed off "8 players · rotate at 10:30am" on the old court card and kept
    /// its name when that card was redrawn.
    static let courtMetaGap: CGFloat = 4

    // `badgePadding` (`10`, the "Open" badge's vertical padding) and `overlineTop` (`6`, the
    // `padding:6px 4px 0` above "WHO IS WHERE") used to sit in this run. Both were transcribed off
    // drawings `5d` deleted — the badge went with `BlockCourtCard`'s "Your court" body, because
    // court status is Overview's write and `5d` draws no badge; the overline went with
    // `BlockAssigneeList`'s, because `5d` distils five section headers into flat labels and no new
    // screen introduces tracked caps. A number nothing draws is not a token, it is a measurement
    // of something that is gone.

    /// `30` — the avatar in "Who is where".
    static let assigneeAvatar: CGFloat = 30
    /// `52` — "Take attendance".
    static let ctaHeight: CGFloat = 52
    /// `20` — `bottom:20px`, which is two points tighter than the tab bar's own inset because
    /// `8l` draws no tab bar to sit above.
    static let ctaBottom: CGFloat = 20
    /// `17` — the `⋯` beside a pinned note.
    /// A glyph rather than copy, so it is sized in points and not through the type table.
    ///
    /// It used to be the block editor's tick as well, and the two are no longer one number:
    /// `5a`/`5b` draw every pick row's tick and empty ring at `21`
    /// (`design/rebuild/section-t5.html:70-77`) against this 17. Two glyphs on two screens that
    /// happened to agree, rather than one glyph — so the editor's is `pickTick` below and this
    /// keeps the size it was transcribed at.
    static let pickerCheck: CGFloat = 17
    /// `21` — the tick, and the empty ring beside it, on every row of a card you choose from.
    ///
    /// `font-size:21px` on the filled `check-circle` and `21×21` on the unpicked `border-radius:99px`
    /// (`design/rebuild/section-t5.html:70-77`), which is the design saying the two are one control
    /// in two states rather than a glyph and a hole the same size by luck.
    static let pickTick: CGFloat = 21

    // MARK: The block editor

    /// The sheet's height over the 700pt frame the design draws its sheets in, the way
    /// `SheetChrome` takes every other one. Taller than the venue sheet's `0.87` because this one
    /// carries four sections and a list of people; `.large` is still one drag away.
    ///
    /// Here rather than on `ActiveSheet.detentFraction`, which is a property of a slot this sheet
    /// deliberately does not occupy — see `BlockEditorSheet`'s header.
    static let editorDetent: Double = 0.92
    /// `9` — between the Starts and Ends columns, and from a field to the amber line under it
    /// (`design/rebuild/section-t5.html:82, 89`).
    ///
    /// `editorSectionGap` used to sit beside it: `18`, "matching the gap `VenueSheet` leaves
    /// between its own". There are no sections left to space. `5a` labels each *field* rather than
    /// heading a group of them, and `SheetFieldLabel` carries its own `14` above and `7` below
    /// (`SheetChrome.swift:220-238`) — so the gap between one field and the next is now a property
    /// of the label that opens it, and a token restating it from outside would be a second number
    /// for one distance.
    static let editorFieldGap: CGFloat = 9
    /// `10` — `margin-top:10px` from "Save changes" down to "Delete block"
    /// (`design/rebuild/section-t5.html:126`).
    ///
    /// A point off `editorFieldGap` and stated separately rather than rounded onto it. Two fields
    /// side by side are one control split in half; two full-width bars stacked are a commit and an
    /// irreversible write, and the design keeps the second pair a point further apart.
    static let editorDeleteGap: CGFloat = 10
    /// `7` — `gap:7px` between the Mon–Fri pills (`design/rebuild/section-t5.html`, 5a's Day row).
    ///
    /// A point off `Spacing.tight` (6), which is what this row used while the chips were squared.
    /// Not snapped back onto it: a pill's round ends already read as a gap, so the design opens
    /// the real one slightly to stop five of them reading as one bar. `ChipMetrics.dayPill`
    /// carries the *inside* of a chip; this is the space between them, and `Chip` spends
    /// `metrics.spacing` on its own emoji-to-label gap (`Components.swift:358`), so the two
    /// cannot be the same number.
    static let editorDayGap: CGFloat = 7
    /// `13` — `padding:0 13px` on the two lines that explain a card rather than sit inside one.
    ///
    /// `CardRow`'s own horizontal gutter (`Components.swift:216`), which is the point: the hint
    /// under the Kids card starts where the copy in the row above it starts, so it reads as a
    /// footnote to that card rather than as a line of the sheet.
    static let editorHintInset: CGFloat = 13
    /// `56` — the editor's commit bar, and the delete below it.
    ///
    /// Stated separately from `ctaHeight` rather than borrowed: that one is `8l`'s pinned "Take
    /// attendance", and the day the design moves one it will not have moved the other. They were
    /// both `52` and this is `56` now — `height:56px` on both bars of `4e` and `5b` — which is the
    /// day arriving.
    ///
    /// It is also `PrimaryButton`'s own default (`Components.swift:606-610`), and is passed explicitly
    /// anyway. The button is drawn at four heights across the app; a call site that says which one
    /// it wants cannot be moved by a change made for somebody else's screen.
    static let editorButtonHeight: CGFloat = 56

    // MARK: `8f`

    /// `26` / `20` — `padding:26px 20px` inside the empty-day hero.
    static let emptyPaddingVertical: CGFloat = 26
    static let emptyPaddingHorizontal: CGFloat = 20
    /// `52` / `24` — the disc on an empty day, and the glyph inside it.
    ///
    /// Only the 52 is transcribed. The design drew a logo in that space rather than a glyph, so
    /// there is no second number in the CSS to take; the 24 is `8g`'s padlock, which the design
    /// does draw, and draws in a disc of this same 52.
    static let emptyMark: CGFloat = 52
    static let emptyMarkGlyph: CGFloat = 24
    /// `16` — the drop from the disc to "Friday is empty."
    static let emptyTitleGap: CGFloat = 16
    /// `250` — how wide the sentence under it may run before it wraps. The design caps it well
    /// short of the card so the copy stays a paragraph rather than a banner.
    static let emptyCopyWidth: CGFloat = 250
    /// `20` — the drop from that sentence to "Add the first block".
    static let emptyCtaGap: CGFloat = 20
    /// `50` — that button is two points shorter than `8l`'s.
    static let emptyCtaHeight: CGFloat = 50
    /// `5` / `8` — `padding:0 5px 8px` around "OR START FROM A SHAPE".
    static let shapeOverlineInset: CGFloat = 5
    static let shapeOverlineBottom: CGFloat = 8
    /// `34` — the tinted tile behind a day shape's glyph.
    static let shapeTile: CGFloat = 34
    /// `17` — the glyph on it.
    static let shapeGlyph: CGFloat = 17
}

// MARK: - Shadow

enum ScheduleShadows {

    // `courtCard` used to open this enum: `0 8px 22px rgba(26,127,85,.08)`, the lift under `8l`'s
    // court card. `5d` redrew that card without it and `BlockCourtCard` draws a flat `Card`, so
    // nothing was reading it. The argument it carried is not lost with it — the day's rule about
    // what is allowed to lift is restated on `draggedBlock` below, which is the one case that rule
    // was ever making an exception for.

    /// `0 14px 34px rgba(26,127,85,.16)` — the card with a finger on it
    /// (`design/rebuild/section-t5.html:166`).
    ///
    /// **The day's only shadow.** A resting `8k` block gets none: the running block wears the same
    /// green border a point thinner and nothing else, so the day reads as one plane with one card
    /// marked on it rather than as a card that has come loose — which is worth more on a canvas
    /// than it was on a list, because cards here sit *beside* each other as well as under, and a
    /// lifted one reads as being in front of its neighbour rather than at the same hour as it.
    ///
    /// 5c is the case that rule was never about. A card under a finger genuinely *is* in front of
    /// its neighbours — it already draws over them (`ScheduleView.swift:733-736`), it already overhangs
    /// its own slot, and on a three-deep morning it is about to be carried across a column. So the
    /// rule the day keeps is "nothing is lifted for a state it is merely *in*", and a hand on a
    /// block is not a state.
    ///
    /// Built from `Theme.accent` rather than from the design's literal `rgba(26,127,85,…)`, so the
    /// glow follows the accent into the dark scheme. It is a *tint*, not a cast shadow — see
    /// `Shadows.cast` for why the ordinary ones are pinned to black instead. Halved from the CSS
    /// blur per `ShadowToken`'s note (`Theme.swift:434-435`), so `34px` is `radius: 17`.
    ///
    /// Green rather than `Shadows.cast`'s near-black, and that is the design's choice rather than
    /// this file's convenience: the readout capsule three lines away *is* cast in near-black
    /// (`Shadows.liftedRow`), so the two are deliberately different marks — one says "this thing is
    /// live", the other says "this thing is floating over the day".
    static let draggedBlock = ShadowToken(color: Theme.accent.opacity(0.16), radius: 17, y: 14)

    /// `0 12px 30px rgba(26,127,85,.24)` — under `8l`'s "Take attendance".
    static let cta = ShadowToken(color: Theme.accent.opacity(0.24), radius: 15, y: 12)
}

// MARK: - Type

/// What `8k`, `8l` and `8f` need beyond the shared table.
///
/// This used to be a parallel type scale. It ran lighter than `Typography.swift` because section
/// 8 does — 600 where the earlier screens used 700 or 800, 400 where they used 500 — and it drew
/// the two serif headings in the sans, because Newsreader was not bundled when it was written.
/// Both of those are fixed at the source now: the shared table carries section 8's weights, and
/// `TypeStyle.isSerif` carries its family. So every name here is a one-line alias, kept only so
/// no call site has to move.
enum ScheduleType {

    // MARK: `8k`

    /// `400 13` — the time beside a block.
    static let blockTime = TypeStyle.sheetSubtitle
    /// `400 12` — the hour down the gutter (`design/rebuild/section-t5.html:144-149`).
    ///
    /// A point under `blockTime`, which is what this used to be and what section 8's list drew:
    /// there, every entry in the column was a *block's* start and belonged to the card beside it.
    /// The column labels the grid now — thirteen fixed hours the blocks are placed against — so it
    /// is scenery, and the design sets scenery a size down.
    static let gutterHour = TypeStyle.meta
    /// `600 13` — the time beside the block running now.
    static let blockTimeNow = TypeStyle.countdown
    /// `500 14.5` — "Drop-off · done", the one line a finished block gets. `body` without its
    /// paragraph leading: one line never has a second to be spaced from.
    static let doneLine = TypeStyle.body.lineHeight(nil)
    /// `600 16`, `-.03em` — a block's title.
    static let blockTitle = TypeStyle.rowTitle.tracking(em: -0.03)
    /// `600 17`, `-.03em` — the title of the block running now, a point larger.
    static let blockTitleNow = TypeStyle.venueHeading
    /// `400 13.5` — a block's grey second line, and `8l`'s "9:00am – 10:30am · Courts 1–3".
    static let blockDetail = TypeStyle.subtitle
    /// `400 12.5` — the note line under a block's rule, and `8k`'s `+2` beside it.
    static let noteLine = TypeStyle.rowDetail

    // MARK: `8l`

    /// `400 30/1.05 Newsreader`, `-.022em` — the opened block's name. The same heading `8m`,
    /// `8n` and `8q` open with, which is why it takes that style rather than restating it.
    static let blockHeading = TypeStyle.onTheDayTitle
    /// `600 10.5`, `+.14em`, uppercase — "YOUR COURT", "WHO IS WHERE". `8f`'s "OR START FROM A
    /// SHAPE" is the same style a hair wider, which it asks for with `.tracking(em: 0.15)`.
    static let overline = TypeStyle.overlineSmall
    // `courtTitle` (`600 19`, "Court 1 – Drills"), `courtMeta` (`400 13`, "8 players · rotate at
    // 10:30am") and `courtBadge` (`600 13.5`, the "Open" badge) used to sit here. All three were
    // `8l`'s green "Your court" plate, and `5d` deleted that plate — the card is drawn once per
    // court now, headed by a flat label, and its status badge went because court status is
    // Overview's write and this screen owns none of it. `courtTitle` was the only one of the three
    // that was a style rather than an alias, which is worth noting because it means nothing is
    // left in this enum that the shared table does not already carry.

    /// `500 12.5` — a pinned note, which is written a shade heavier on `8l`'s plate than it is
    /// on `8k`'s card.
    static let pinnedNote = TypeStyle.rowSubtitle
    /// `400 12` — the `+2` beside it, a half-point smaller than `8k`'s.
    static let noteCount = TypeStyle.meta
    // `assigneeName` (`600 14`, `-.02em`) used to sit here: a person's name in `8l`'s "Who is
    // where" list. That list is gone — `5d` asks "is Court 2 covered" and answers it per court, so
    // the names moved into `BlockCourtCard`'s coach rows and `CourtCoachLine` sets them. Its only
    // remaining readers were two doc comments comparing themselves to it, which is how a deleted
    // style goes on looking alive.

    /// `600 14.5`, `-.02em` — the title of a row you can pick: a kind, a court, a kid spread, a
    /// coach (`design/rebuild/section-t5.html:70, 104, 113, 118`).
    ///
    /// Half a point over `TypeStyle.rowTitleSm`, which is what `8l` set a *reported* name at, and
    /// the half point is the whole distinction: every row on the editor's four cards is a control.
    /// The design sets them at the size it sets `8f`'s day-shape tiles, which are the other thing
    /// on these screens you tap to choose.
    static let pickRowTitle = TypeStyle.rowLabel
    /// `400 12.5` — their role, and the court they are on.
    static let assigneeMeta = TypeStyle.rowDetail
    /// `500 13.5` — "3 notes on this block". The design's single use of 500 at this size.
    static let notesRow = TypeStyle(size: 13.5, weight: .medium)
    /// `600 16`, `-.015em` — "Take attendance", and the editor's commit bar.
    static let cta = TypeStyle.button

    // MARK: The block editor

    /// `400 26/1.05 Newsreader`, `-.02em` — "New block" and "Edit block" at the head of the sheet
    /// (`design/rebuild/section-t4.html:274`, `design/rebuild/section-t5.html:62`).
    ///
    /// `sheetTitle` at four points larger, asked for by name rather than transcribed again, so the
    /// family, the weight and the tracking stay the shared table's and only the size is this
    /// sheet's. The block editor is the one sheet in the app the design draws over 22, and it
    /// earns it: `VenueSheet` and `StaffSheet` open onto three fields, and this one opens onto
    /// nine controls and a delete.
    static let editorTitle = TypeStyle.sheetTitle.size(26).lineHeight(1.05)

    /// `600 16`, `-.02em` — what somebody has typed into one of the block editor's fields, and what
    /// its two time menus read back (`design/rebuild/section-t5.html:66, 82`).
    ///
    /// A value at the weight of a row title rather than at `editorValue`'s `500 14`, and the box
    /// around it grew with it — see `FormFieldMetrics.sheetBoxLarge`. The design draws the name and
    /// the two times as the *answers* on this sheet, at the size the block's own card will draw
    /// them, so what you type reads back as what will be on the timetable.
    static let editorFieldValue = TypeStyle.rowTitle.tracking(em: -0.02)
    /// `400 16` — the prompt in those fields. A placeholder is one weight lighter than a value in
    /// this design, so the two read apart before the colour difference lands.
    static let editorFieldPlaceholder = editorFieldValue.weight(.regular)
    /// `400 14.5/1.5` — the description, which is prose and takes a paragraph's leading rather than
    /// a field's (`design/rebuild/section-t5.html:68`).
    static let editorDescription = TypeStyle.body.weight(.regular)

    /// `500 14` — a value in a *sheet-sized* field on these screens.
    ///
    /// `bodyAlt` without its 1.5 line-height multiple, which is `VenueSheet`'s expression and its
    /// reasoning: that multiple is for wrapped copy, and on a one-line field it only adds 7pt of
    /// leading under a single line.
    ///
    /// It used to be the block editor's too, and the header of that sheet said so. `5a` draws it a
    /// size up in `.sheetBoxLarge`, so the editor takes `editorFieldValue` above and this is left
    /// to its other reader — `BlockNotesCard`'s composer (`:136-137`), which `8l` still draws at
    /// 14 in the smaller box. One name, one remaining screen, rather than a rename that would move
    /// a file this change has no other reason to touch.
    static let editorValue = TypeStyle.bodyAlt.lineHeight(nil)
    /// `400 14` — the prompt in that field.
    static let editorPlaceholder = TypeStyle.rowValue

    // MARK: `8f`

    /// `400 24/1.15 Newsreader`, `-.02em` — "Friday is empty."
    static let emptyHeading = TypeStyle.profileName
    /// `400 13.5/1.6` — the sentence under it.
    static let emptyCopy = TypeStyle.emptyBody
    /// `600 15`, `-.02em` — "Add the first block".
    static let emptyCta = TypeStyle.bodyStrong
    /// `600 14.5`, `-.025em` — "Half day", "Full day", "Tournament".
    static let shapeTitle = TypeStyle.rowLabel.tracking(em: -0.025)
    /// `400 12` — "5 blocks · 8:30 to 12:45".
    static let shapeDetail = TypeStyle.meta
    /// `600 12.5` — "Reassign", "Copy Monday instead".
    static let inlineAction = TypeStyle.chipSoft
    /// `600 13` — "All courts", "No courts", and the caret row that opens a card
    /// (`design/rebuild/section-t5.html:102`).
    ///
    /// Half a point over `inlineAction`, which is `8f`'s word-as-a-button sitting *beside* copy.
    /// These two are a row of their own inside a card and have nothing next to them to be quieter
    /// than, so the design sets them at the size of the copy they act on.
    static let cardAction = TypeStyle.countdown
}
