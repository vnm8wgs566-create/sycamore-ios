//
//  GroupsTokens.swift
//  Sycamore
//
//  The handful of values `8o`–`8g` need that the design system does not carry yet.
//
//  They live inside the feature rather than in `Theme` on purpose: hoisting a token before a
//  second screen has asked for it is how a design system fills up with values only one caller
//  ever wanted. Each one below says what would earn it a place in `Theme`.
//
//  Every number here was read off the CSS in `Sycamore 3a System.dc.html`, not off the render.
//  Section 8 sets this screen considerably lighter than the transcription it replaces — names
//  at `400 14` rather than `700 15`, headings at `600` rather than `800` — so most of what
//  follows is a weight the shared type table has no row for.
//

import SwiftUI

// MARK: - Colour

enum GroupsPalette {

    /// `#B67A16` — the countdown clock beside a kid who is going home early.
    ///
    /// The one warm colour on the screen, and deliberately not `Theme.danger`: leaving at 2:30
    /// is a plan, not a problem. Hoist it when Schedule draws its "needs a coach" amber, which
    /// is the same value in the design document.
    static let pickup = Theme.warning

    /// `0 0 0 4px rgba(26,127,85,.09)` — the halo the design puts around the card a kid is
    /// about to land in. Derived from the accent rather than spelled, so it follows it.
    static let dropHalo = Theme.accent.opacity(0.09)

    /// The dashed outline of the gap a lifted kid leaves behind — `8p` draws it `#D8DBE0`.
    ///
    /// Aliased rather than added to `Theme`, because `#D8DBE0` and `timelineDot`'s `#D9DBE0`
    /// are the same grey to a tenth of a step and a palette does not need both. The alias is
    /// what earns its keep: feature code says what the colour is *for*, and the day the design
    /// separates the two roles there is one line to change.
    static let gapRule = Theme.timelineDot
}

// MARK: - Type
//
// Section 8's own weights. The shared table was transcribed from the design's earlier, heavier
// screens; these are the rows it has no equivalent for. Each is derived from the nearest table
// entry where one exists, so a change to the family still reaches them.

enum GroupsType {

    /// `600 17`, `-.03em` — "Group 1". Two steps lighter than `.venueHeading`'s 800.
    static let groupTitle = TypeStyle.venueHeading.weight(.semibold)

    /// `400 13` — "8 players · ranked 1–8", and the rank numeral beside a name. The design sets
    /// the band and the numeral in exactly the same face; only their colours differ.
    static let rowMeta = TypeStyle(size: 13, weight: .regular)

    /// `400 14` — a kid's name in a group card. Regular, not bold: eight of these in a card is
    /// a list to scan, and the design lets the numerals and the marks carry the emphasis.
    static let playerName = TypeStyle(size: 14, weight: .regular)

    /// `400 13.5` — "+3 more".
    static let moreRow = TypeStyle(size: 13.5, weight: .regular)

    /// `400 12.5` — "Hold the handle to move a kid between groups".
    static let hint = TypeStyle(size: 12.5, weight: .regular)

    /// `600 15.5`, `-.025em` — "Add a group".
    static let addGroup = TypeStyle.rowTitle.size(15.5).weight(.semibold)

    /// `600 14.5`, `-.02em` — the name on the card carrying a kid mid-move. Half a step bigger
    /// and two weights heavier than the row it came out of, which is what makes it read as
    /// lifted rather than as a duplicate.
    static let liftedName = TypeStyle.rowLabel.weight(.semibold)

    /// `600 13.5` — `Cancel` / `Drop here`.
    static let moveBarButton = TypeStyle.tabLabel.weight(.semibold)

    /// `600 13` — a venue chip.
    static let venueChip = TypeStyle.chip.weight(.semibold)

    // MARK: `8g`

    /// `400 24/1.15`, `-.02em`, Newsreader — "Groups open at eight kids."
    ///
    /// `.profileName` is already the right face, size and leading; only the tracking is the
    /// design's own here, so it is nudged at this one call site rather than pressed onto every
    /// other screen that sets a serif heading at 24.
    static let lockedHeading = TypeStyle.profileName.tracking(em: -0.02)

    /// `400 13.5/1.6` — the locked card's paragraph.
    static let lockedBody = TypeStyle(size: 13.5, weight: .regular, lineHeightMultiple: 1.6)

    /// `600 15`, `-.02em` — "Add three more kids".
    static let lockedAction = TypeStyle.buttonSmall.weight(.semibold).tracking(em: -0.02)

    /// `600 10.5`, `+.15em`, uppercase — "ADDED SO FAR". Half a step smaller and a step lighter
    /// than `.sectionHeader`, and tracked wider.
    static let lockedSection = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.15, isUppercased: true)

    /// `600 14`, `-.02em` — a kid's name under "Added so far". `8g` is a list of five people
    /// rather than a rank band, so the design does set these bolder.
    static let lockedName = TypeStyle.rowLabel.size(14).weight(.semibold)

    /// `400 12` — "13 · F · returning".
    static let lockedMeta = TypeStyle.meta.weight(.regular)

    /// `600 11.5` — the initials in `8g`'s 32pt disc. Half a step under what
    /// `TypeStyle.initials(forAvatarSize:)` picks for that diameter, and a weight lighter.
    static let lockedInitials = TypeStyle(size: 11.5, weight: .semibold)
}

// MARK: - Geometry

enum GroupsMetrics {

    // MARK: The list

    /// `padding:14px 12px 88px` — the inset above the first card. The gutter either side is
    /// `Spacing.gutter` and the foot is `Spacing.tabBarClearance`.
    static let listTop: CGFloat = 14
    /// `gap:9px` — between cards.
    static let cardGap: CGFloat = 9
    /// `gap:14px` — `8g` sets its two blocks further apart than `8o` sets its cards.
    static let lockedGap: CGFloat = 14

    // MARK: A card

    /// `border-radius:16px`. A point tighter than `Radius.card`, which was transcribed from the
    /// design's earlier screens; hoist when a second section-8 screen agrees.
    static let cardRadius: CGFloat = 16
    /// `padding:14px` — inside a group card, and inside the dashed "Add a group" row.
    static let cardPadding: CGFloat = 14
    /// `margin-top:4px` — between a group's name and its head-count band.
    static let titleGap: CGFloat = 4
    /// `margin-top:10px` above the rule that separates a card's header from its kids.
    static let rowsGap: CGFloat = 10
    /// `font-size:16px` — the caret closing a card header.
    static let caretGlyph: CGFloat = 16
    /// `font-size:18px` — the arrow that replaces it on the card a kid is aimed at.
    static let targetGlyph: CGFloat = 18
    /// `gap:10px` — the plus and its label in "Add a group".
    static let addGroupGap: CGFloat = 10
    /// `font-size:16px` — that plus.
    static let addGroupGlyph: CGFloat = 16

    // MARK: A row

    /// The rank column. Wide enough for the two-digit ranks that are most of a hundred-kid camp,
    /// and shared with the card the kid is carried in so the two line up mid-move.
    static let numeralWidth: CGFloat = 20
    /// `padding:5px 0` — the type the design draws a row at. The touch target around it is
    /// `HitTarget.minimum`, which is what the row actually measures.
    static let rowPadding: CGFloat = 5
    /// `gap:7px` — between the marks at the end of a row.
    static let markGap: CGFloat = 7
    /// `font-size:13px` — every mark.
    static let markGlyph: CGFloat = 13
    /// `font-size:17px` — the drag handle, held and lifted alike.
    static let handleGlyph: CGFloat = 17

    // MARK: The move

    /// Width of the `dropHalo` ring, drawn outside the card's own border.
    static let dropHaloWidth: CGFloat = 4

    /// How far a card that is *not* the drop target fades while a kid is in the air. The design
    /// draws `opacity:.55` on the cards either side of the target.
    static let bystanderOpacity: Double = 0.55

    /// The dashed rule the design draws twice: around "Add a group", and around the gap a kid
    /// leaves behind while they are in the air.
    static let dash: [CGFloat] = [4, 3]

    /// Height of that gap. The row that left is 44pt of touch target around a 30pt line of type,
    /// and it is the 30 the dashes stand in for.
    static let gapHeight: CGFloat = 30

    /// `width:7px;height:7px` — the dot on the leading end of the insertion bar. The design does
    /// not draw a bare rule: the dot is what makes the line read as a caret rather than as a
    /// divider that happens to be green.
    static let dropDot: CGFloat = 7
    /// `gap:10px` — between that dot and the rule.
    static let dropDotGap: CGFloat = 10

    /// `gap:10px;padding:8px 10px` — the plate `Cancel` and `Drop here` sit on.
    static let moveBarGap: CGFloat = 10
    static let moveBarPadding: CGFloat = 10
    static let moveBarPaddingVertical: CGFloat = 8
    /// `padding:10px 18px` / `padding:10px 20px` — the two buttons on it.
    static let moveBarButtonPadding: CGFloat = 10
    static let cancelPadding: CGFloat = 18
    static let dropPadding: CGFloat = 20

    // MARK: `8g`

    /// `padding:26px 20px` — the locked card is the only one on the screen with room to breathe.
    static let lockedPaddingVertical: CGFloat = 26
    static let lockedPaddingHorizontal: CGFloat = 20
    /// `width:52px;height:52px` — the disc the padlock sits in, and `font-size:24px` the padlock.
    static let lockDisc: CGFloat = 52
    static let lockGlyph: CGFloat = 24
    /// `margin-top:9px` — under the locked card's heading, and `max-width:260px` across it. The
    /// paragraph is measured rather than left to the card so it breaks where the design breaks
    /// it: three short centred lines, not two long ones.
    static let lockedBodyGap: CGFloat = 9
    static let lockedCopyWidth: CGFloat = 260
    /// `margin-top:20px` — above the meter.
    static let meterGap: CGFloat = 20
    /// `height:50px` — the call to action, and `gap:9px` / `font-size:18px` inside it.
    static let lockedActionHeight: CGFloat = 50
    static let lockedActionGlyph: CGFloat = 18
    /// `width:32px` — the initials disc beside a kid, and `font-size:15px` the caret after them.
    static let lockedAvatar: CGFloat = 32
    static let lockedCaret: CGFloat = 15
    /// `padding:0 5px 8px` — around "ADDED SO FAR".
    static let lockedSectionInset: CGFloat = 5
    static let lockedSectionGap: CGFloat = 8
    /// `gap:7px;padding:10px 13px` — the "3 more" foot of that card.
    static let lockedMoreGap: CGFloat = 7
    static let lockedMorePadding: CGFloat = 10
    /// `font-size:14px` — its caret.
    static let lockedMoreCaret: CGFloat = 14

    // MARK: The header

    /// `gap:7px` — the hand and its line of instruction, and `font-size:15px` the hand.
    static let hintGap: CGFloat = 7
    static let hintGlyph: CGFloat = 15

    // MARK: Motion

    /// Every fold, unfold and aim on the screen. One curve, so a card opening and a kid sliding
    /// to a new target are recognisably the same motion.
    static let fold: Animation = .snappy(duration: 0.24)

    /// `fold`, or nothing at all for a reader who has asked for less motion.
    ///
    /// The whole screen is position: a kid leaves the ladder, travels, and lands. That is
    /// precisely what Reduce Motion is about, so the state still changes — it simply arrives
    /// rather than slides. `nil` rather than a near-zero duration, because `withAnimation(nil)`
    /// and `.animation(nil, value:)` are both the real "do not animate this".
    static func fold(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : fold
    }
}

// MARK: - Chips

extension ChipMetrics {

    /// `8o`'s venue chips — `600 13`, `8/15`, pill, `#EAEBEE` border unselected.
    ///
    /// Not `ChipMetrics.venue`, which is the same chip as this screen drew before section 8:
    /// a step smaller, a weight heavier, tighter padding and the `strokeChip` border rather
    /// than `strokeAlt`. Hoist over `.venue` once the other tabs' chips are re-read.
    static let groupsVenue = ChipMetrics(
        font: GroupsType.venueChip,
        horizontalPadding: 15,
        verticalPadding: 8,
        radius: Radius.pill,
        spacing: Spacing.tight,
        unselectedBorder: Theme.strokeAlt,
        emojiSize: 15
    )
}

// MARK: - Rules

enum GroupsRules {

    /// "Groups open at eight kids." Below that a coach can hold the order in their head, and a
    /// list would just be in the way — so `8g` is the whole screen until the eighth kid arrives.
    static let opensAt = 8

    /// Rows a folded group card shows before "+N more". The design draws three.
    static let previewRows = 3

    /// Kids `8g` lists under "Added so far" before the "N more" row.
    static let addedPreviewRows = 2

    /// How many of `count` rows to draw.
    ///
    /// The `+ 1` is the whole rule: folding a single row away spends a "1 more" row to hide a
    /// row, which is not a saving. Stated once because both folded lists on this screen — a
    /// group's kids and `8g`'s "Added so far" — have to answer it the same way.
    static func visibleCount(of count: Int, preview: Int, isExpanded: Bool) -> Int {
        isExpanded || count <= preview + 1 ? count : preview
    }
}
