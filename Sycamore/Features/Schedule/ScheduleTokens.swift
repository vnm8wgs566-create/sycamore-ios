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

    // MARK: The day list

    /// `14` — `8k`'s drop from the header's rule to the first block.
    static let listTop: CGFloat = 14
    /// `16` — `8f` starts its content two points lower than `8k` does.
    static let emptyListTop: CGFloat = 16
    /// `9` — `gap:9px` between two blocks, and between `8l`'s cards.
    static let blockGap: CGFloat = 9
    /// `14` — `8f`'s outer `gap:14px`, between the hero card and the shapes below it.
    static let sectionGap: CGFloat = 14

    // MARK: The time gutter

    /// `52` — the column running down the left of `8k`.
    static let timeColumn: CGFloat = 52
    /// `15` — `padding-top` on the gutter time, so it sits on the card's title rather than on
    /// the card's top edge.
    static let timeBaseline: CGFloat = 15
    /// `4` — `padding:0 4px` on the rows that carry no card of their own.
    static let rowInset: CGFloat = 4

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
    /// no shadow at all, which is what keeps the list reading as one plane with one card marked
    /// on it rather than as a card that has come loose.
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
    /// `600 16`, `-.015em` — "Take attendance".
    static let cta = TypeStyle.button

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
