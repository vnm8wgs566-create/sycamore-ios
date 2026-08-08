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
//  Section 8 sets this screen considerably lighter than the transcription it replaces — names at
//  `400 14` rather than `700 15`, headings at `600` rather than `800`. That correction used to be
//  made here, privately; the shared type table makes it now, for the whole app.
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

    /// The lip round the greyed kid travelling to their landing — `8p` draws it `#D8DBE0`.
    ///
    /// Aliased rather than added to `Theme`, because `#D8DBE0` and `timelineDot`'s `#D9DBE0`
    /// are the same grey to a tenth of a step and a palette does not need both. The alias is
    /// what earns its keep: feature code says what the colour is *for*, and the day the design
    /// separates the two roles there is one line to change.
    ///
    /// This was `gapRule`, and it was a *dashed* border round an empty rectangle — the right
    /// drawing for the hole a kid leaves behind, which is what the screen used to show. The
    /// ghost is not a hole: it has the kid's name in it. A dashed border round something with
    /// content inside reads as a dropped image or a broken asset, so the same grey is drawn as
    /// a solid one-point lip round a filled plate instead.
    static let ghostRule = Theme.timelineDot

    /// The plate the greyed kid sits on while they travel.
    ///
    /// `Theme.tile` — the palette's existing "a plate a thing sits on" grey, the one an icon
    /// tile is drawn from. Aliased rather than spelled as a hex of its own: the ghost is
    /// exactly that relationship, a surface a row is resting on rather than standing in, and
    /// the design draws it at the same weight.
    static let ghostFill = Theme.tile
}

// MARK: - Type
//
// These were the rows the shared table had no equivalent for, because it was transcribed from the
// design's earlier, heavier screens. It carries section 8's weights itself now, so what is left is
// a set of aliases: the call sites keep saying `playerName` and `lockedHeading`, and the numbers
// behind them are the same ones every other screen draws from.

enum GroupsType {

    /// `600 17`, `-.03em` — "Group 1".
    static let groupTitle = TypeStyle.venueHeading

    /// `400 13` — "8 players · ranked 1–8", and the rank numeral beside a name. The design sets
    /// the band and the numeral in exactly the same face; only their colours differ.
    static let rowMeta = TypeStyle.sheetSubtitle

    /// `400 14` — a kid's name in a group card.
    static let playerName = TypeStyle.rowValue

    /// `400 12.5` — "Hold the handle to move a kid between groups".
    static let hint = TypeStyle.rowDetail

    /// `600 15.5`, `-.025em` — "Add a group".
    static let addGroup = TypeStyle.rowTitle.size(15.5)

    /// `600 14.5`, `-.02em` — the name on the card carrying a kid mid-move. Half a step bigger
    /// and a weight heavier than the row it came out of, which is what makes it read as lifted
    /// rather than as a duplicate.
    static let liftedName = TypeStyle.rowLabel

    /// `600 13.5` — `Cancel` / `Drop here`.
    static let moveBarButton = TypeStyle.tabLabel

    /// `600 13` — a venue chip.
    static let venueChip = TypeStyle.chip

    // MARK: `8g`

    /// `400 24/1.15 Newsreader`, `-.02em` — "Groups open at eight kids." The same heading `8f`
    /// and `8h` open their empty states with.
    static let lockedHeading = TypeStyle.profileName

    /// `400 13.5/1.6` — the locked card's paragraph.
    static let lockedBody = TypeStyle.emptyBody

    /// `600 15`, `-.02em` — "Add three more kids".
    static let lockedAction = TypeStyle.bodyStrong

    /// `600 10.5`, `+.15em`, uppercase — "ADDED SO FAR", a hair wider than the `+.14em` the
    /// overline carries.
    static let lockedSection = TypeStyle.overlineSmall.tracking(em: 0.15)

    /// `600 14`, `-.02em` — a kid's name under "Added so far". `8g` is a list of five people
    /// rather than a rank band, so the design does set these bolder.
    static let lockedName = TypeStyle.rowTitleSm

    /// `400 12` — "13 · F · returning".
    static let lockedMeta = TypeStyle.meta

    /// `600 11.5` — the initials in `8g`'s 32pt disc. Half a step under what
    /// `TypeStyle.initials(forAvatarSize:)` picks for that diameter.
    static let lockedInitials = TypeStyle.dividerLabel
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

    /// The dashed rule round "Add a group".
    ///
    /// Drawn once now, not twice. It used to outline the gap a lifted kid left behind as well,
    /// and the pair said the same thing about two different things: "there is nothing here yet,
    /// and something could be". That is true of the row under the last card and false of the
    /// place a kid is standing in mid-air — so the ghost is a filled plate with a solid lip
    /// (`ghostFill`, `ghostRule`) and the dashes belong to the one control that is genuinely an
    /// invitation.
    static let dash: [CGFloat] = [4, 3]

    /// Height of the plate under the travelling kid. The row they came out of is 44pt of touch
    /// target around a 30pt line of type, and it is the 30 that is drawn.
    ///
    /// **30 is what is drawn; `move.origin.height` is what is reserved.** The design's 30pt
    /// plate inside a 44pt row is unchanged, but the space the card opens is the *measured*
    /// height of the row that closed — which at accessibility type sizes is a good deal more
    /// than 44. Only a measurement can promise that exactly one row's worth leaves and exactly
    /// one arrives, which is what keeps a card's height unchanged to the point when a kid moves
    /// inside it. A literal here would be a promise this file cannot keep.
    static let ghostHeight: CGFloat = 30

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

    // Motion lives in `DesignSystem/Motion.swift` now. The fold curve was declared here while
    // this was the only screen that folded a list; Overview folds one too, and a shared curve
    // owned by one of the two features is how the other ends up depending on it by name.
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
