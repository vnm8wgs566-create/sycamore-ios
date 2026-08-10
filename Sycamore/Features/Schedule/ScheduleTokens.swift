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
//  `blockTitle`, `courtBadge`, `emptyCopy` — while the numbers behind them live in one place.
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

    /// `28 × 3` — the grabber on a card's bottom edge.
    ///
    /// `SheetGrabber`'s 38×4 (`Components.swift:37-47`) at the scale of a card rather than of a
    /// screen: deliberately the same vocabulary for "this edge moves", one step quieter, because
    /// it is drawn on every upcoming block rather than once at the top of a sheet. It takes that
    /// component's `Theme.grabber` too, rather than a colour of its own.
    static let resizeGrab = CGSize(width: 28, height: 3)
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
    /// The grabber's lift off the bottom border and the readout's lift off the grabber are
    /// `Spacing.tight` and `Spacing.small`, taken from the shared scale rather than restated here.
    /// They landed on 6 and 8 by eye, which is exactly the case this file's header warns about: a
    /// chosen number that happens to equal a shared step is a second name for that step.
    static func resizeHitHeight(in blockHeight: CGFloat) -> CGFloat {
        min(HitTarget.minimum, blockHeight / 2)
    }

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
    /// `10` — the badge's vertical padding. Its horizontal is `Spacing.large`.
    static let badgePadding: CGFloat = 10
    /// `4` — `margin-top:4px` on "8 players · rotate at 10:30am".
    static let courtMetaGap: CGFloat = 4
    /// `6` — `padding:6px 4px 0` above "WHO IS WHERE".
    static let overlineTop: CGFloat = 6
    /// `30` — the avatar in "Who is where".
    static let assigneeAvatar: CGFloat = 30
    /// `52` — "Take attendance".
    static let ctaHeight: CGFloat = 52
    /// `20` — `bottom:20px`, which is two points tighter than the tab bar's own inset because
    /// `8l` draws no tab bar to sit above.
    static let ctaBottom: CGFloat = 20
    /// `17` — the tick beside a coach in the block editor's picker, and beside a note's `⋯`.
    /// A glyph rather than copy, so it is sized in points and not through the type table.
    static let pickerCheck: CGFloat = 17

    // MARK: The block editor

    /// The sheet's height over the 700pt frame the design draws its sheets in, the way
    /// `SheetChrome` takes every other one. Taller than the venue sheet's `0.87` because this one
    /// carries four sections and a list of people; `.large` is still one drag away.
    ///
    /// Here rather than on `ActiveSheet.detentFraction`, which is a property of a slot this sheet
    /// deliberately does not occupy — see `BlockEditorSheet`'s header.
    static let editorDetent: Double = 0.92
    /// `18` — between the editor's sections, matching the gap `VenueSheet` leaves between its own.
    static let editorSectionGap: CGFloat = 18
    /// `9` — between two fields inside one section.
    static let editorFieldGap: CGFloat = 9
    /// `52` — the editor's commit bar, and the delete below it.
    ///
    /// The same number as `ctaHeight` and stated separately rather than borrowed: that one is
    /// `8l`'s pinned "Take attendance", and the day the design moves one it will not have moved
    /// the other.
    static let editorButtonHeight: CGFloat = 52

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

    /// `0 8px 22px rgba(26,127,85,.08)` — the lift under `8l`'s court card.
    ///
    /// Only that card. `8k`'s running block wears the same green border at a point thinner and
    /// no shadow at all, which is what keeps the day reading as one plane with one card marked
    /// on it rather than as a card that has come loose. That is worth more on a canvas than it was
    /// on a list: cards there sit *beside* each other as well as under, and a lifted one would read
    /// as being in front of its neighbour rather than at the same hour as it.
    ///
    /// Built from `Theme.accent` rather than from the design's literal `rgba(26,127,85,…)` so
    /// the glow follows the accent into the dark scheme. It is a *tint*, not a cast shadow —
    /// see `Shadows.cast` for why the ordinary ones are pinned to black instead.
    static let courtCard = ShadowToken(color: Theme.accent.opacity(0.08), radius: 11, y: 8)

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
    /// `600 19`, `-.035em` — "Court 1 – Drills". The one size on these three screens the design
    /// draws once and nowhere else, so it stays a style of its own.
    static let courtTitle = TypeStyle(size: 19, weight: .semibold, trackingEm: -0.035)
    /// `400 13` — "8 players · rotate at 10:30am".
    static let courtMeta = TypeStyle.sheetSubtitle
    /// `600 13.5` — the "Open" badge on the court card.
    static let courtBadge = TypeStyle.timelineTitle
    /// `500 12.5` — a pinned note, which is written a shade heavier on `8l`'s plate than it is
    /// on `8k`'s card.
    static let pinnedNote = TypeStyle.rowSubtitle
    /// `400 12` — the `+2` beside it, a half-point smaller than `8k`'s.
    static let noteCount = TypeStyle.meta
    /// `600 14`, `-.02em` — a person's name in "Who is where". The " · you" after it is this
    /// style at `400`, which is why the qualifier asks for `.weight(.regular)` rather than for a
    /// style of its own.
    static let assigneeName = TypeStyle.rowTitleSm
    /// `400 12.5` — their role, and the court they are on.
    static let assigneeMeta = TypeStyle.rowDetail
    /// `500 13.5` — "3 notes on this block". The design's single use of 500 at this size.
    static let notesRow = TypeStyle(size: 13.5, weight: .medium)
    /// `600 16`, `-.015em` — "Take attendance", and the editor's commit bar.
    static let cta = TypeStyle.button

    // MARK: The block editor

    /// `500 14` — what somebody has typed into one of the editor's fields, and what its two time
    /// menus read back.
    ///
    /// `bodyAlt` without its 1.5 line-height multiple, which is `VenueSheet`'s expression and its
    /// reasoning: that multiple is for wrapped copy, and on a one-line field it only adds 7pt of
    /// leading under a single line. The description field *does* wrap, and takes its leading from
    /// the same place every other paragraph in the app does rather than from a field style.
    static let editorValue = TypeStyle.bodyAlt.lineHeight(nil)
    /// `400 14` — the prompt in those fields. A placeholder is one weight lighter than a value in
    /// this design, so the two read apart before the colour difference lands.
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
}
