//
//  OnTheDayTokens.swift
//  Sycamore
//
//  The values `8m Attendance`, `8n Leaving early` and `8q A kid` draw that `Theme`, `Radius`,
//  `Spacing` and `TypeStyle` do not carry yet.
//
//  The geometry lives here rather than in the design system because section 8 is being built one
//  unit at a time and a shared file is a shared merge conflict. Every one of these numbers is
//  transcribed from the design's inline CSS; none is invented.
//
//  The type no longer does. Section 8 sets its type a half-step lighter than the screens this app
//  shipped with — 600 where they used 700, 400 where they used 500 — and this file used to carry
//  its own copy of that correction. `Typography.swift` now makes it once, for every screen.
//

import SwiftUI

enum OnTheDayTokens {

    // MARK: Colour

    /// The amber a pick-up is written in — `#B67A16`, "Leaves 2:30 today".
    ///
    /// The standalone amber rather than the `warningTint`/`warningDark` pill the design uses for
    /// most of its warnings: `8m` and `8q` draw this one as bare coloured text beside a bare
    /// coloured glyph, with no plate under either.
    static let warning = Theme.warning

    // MARK: Geometry

    /// Section 8 draws its cards at 16 where the earlier sections drew 17 (`Radius.card`).
    /// Spelled out rather than borrowing `Radius.button`, which is 16 by coincidence.
    static let card: CGFloat = 16

    /// The `Here` / `Away` pair — 42pt drawn. Under the 44pt minimum, so the button keeps this
    /// height and grows only its hit region.
    static let answerHeight: CGFloat = 42

    /// `Add pick-up` on `8n` — the one button in this unit the design already draws at 44.
    static let compactButtonHeight: CGFloat = 44

    /// The pinned `Finish · 2 left` / `Done` bar.
    static let barHeight: CGFloat = 52

    /// Its inset from the bottom edge.
    static let barInset: CGFloat = 20

    /// The gap between the glyph and the label inside `8q`'s outlined bar — `gap:9px`.
    static let barGap: CGFloat = 9

    /// How far back a control drops when there is nothing for it to do. `8q`'s bar is the case:
    /// it is the screen's one action and hiding it would leave an unexplained 88pt of air under
    /// the list, so it stays drawn and stands down instead.
    static let inactiveOpacity: Double = 0.45

    /// The attendance progress track.
    static let progressHeight: CGFloat = 4

    /// The green disc with the tick, on a kid who has been marked here.
    static let markDiameter: CGFloat = 22

    /// The right-aligned ladder numeral ahead of every name.
    static let rankColumn: CGFloat = 20

    /// Horizontal padding inside a section-8 card — `padding:12px 13px`.
    static let cardInset: CGFloat = 13

    /// The wider gutter `8n` gives its pick-up cards — `padding:13px 14px`.
    static let cardInsetWide: CGFloat = 14

    /// A row inside a divided card — `padding:10px 13px`.
    static let rowInset: CGFloat = 10

    /// The inset an overline carries so it lines up with the copy inside the card beneath it.
    static let overlineInset: CGFloat = 4

    /// `gap:9px` on every section-8 content column. One value between an overline and its card,
    /// between two cards, and between a card and the next overline.
    static let contentGap: CGFloat = 9

    /// The air an overline opening a screen carries above it — `padding:2px 4px 0`.
    static let overlineLead: CGFloat = 2

    /// And the air a *second* overline carries, which is a touch more — `padding:6px 4px 0`.
    static let overlineBreak: CGFloat = 6

    /// `margin-top:10px` — the gap between blocks stacked inside one card on `8n`.
    static let blockGap: CGFloat = 10

    /// The white header block's own padding — `padding:14px 22px 18px`.
    static let headerTop: CGFloat = 14
    static let headerBottom: CGFloat = 18

    /// `padding:14px 12px 88px` — the clearance the content keeps under the pinned bar. Less
    /// than `Spacing.tabBarClearance`, which is sized for the floating tab bar and its shadow;
    /// this screen has no tab bar, only a 52pt bar 20 off the bottom edge.
    static let contentBottomInset: CGFloat = 88

    /// The serif title's drawn size, tracking and line height — `400 30px/1.05`, `-.022em`.
    /// Assembled into `TypeStyle.onTheDayTitle`.
    static let titleSize: CGFloat = 30
    static let titleTrackingEm: CGFloat = -0.022
    static let titleLineHeight: CGFloat = 1.05

    /// How much of the frame `8n` opens over.
    ///
    /// 0.67 was right when this sheet asked two questions, and is what `ActiveSheet` declared for
    /// it while the root still presented it. The design now draws it as a full screen — a week of
    /// pick-ups, then a card to add another — and at 0.67 the "New pick-up" card opens below the
    /// fold, which is the one thing on the sheet somebody came to use.
    static let pickupDetent: Double = 0.88

    // MARK: Shadow

    /// `0 12px 30px rgba(11,11,12,.2)` — the pinned bar on `8m` and `8n`.
    ///
    /// `Shadows.tabBar` was standing in for this and is both wider and half again as heavy
    /// (`36px` blur at 30%), which put a visible bloom under a bar the design lifts only
    /// slightly. CSS blur is roughly twice SwiftUI's, so `30` becomes `15`.
    ///
    /// Cast in black rather than built from `Theme.ink` for the reason `Shadows` gives: `ink`
    /// inverts with the scheme, and a shadow only ever darkens what is under it.
    static let barShadow = ShadowToken(color: .black.opacity(0.22), radius: 15, y: 12)

    /// `0 10px 26px rgba(11,11,12,.08)` — the same bar on `8q`, where it is white rather than
    /// near-black and so is lifted by about a third as much. Blur halved for SwiftUI, and the
    /// alpha carried up the same fraction as `barShadow`'s, which a dark surface needs to show
    /// any lift at all.
    static let barShadowLight = ShadowToken(color: .black.opacity(0.09), radius: 13, y: 10)
}

// MARK: - Type

/// What `8m`, `8n` and `8q` need beyond the shared table.
///
/// Almost nothing, now. These were fourteen spelled-out `font:` shorthands written while the
/// shared table was still a step or two heavier than section 8; the table carries those weights
/// itself, so all but two of the names below are one-line aliases kept so no call site moves.
extension TypeStyle {

    /// `600 10.5`, `+.14em`, uppercase — "STILL TO MARK · 2", "THIS WEEK · 2", "NEW PICK-UP".
    static let onTheDayOverline = TypeStyle.overlineSmall

    /// `400 13` — the breadcrumb above a screen title ("Skills rotation · 9:00–10:30").
    static let onTheDayCrumb = TypeStyle.sheetSubtitle

    /// `400 13.5` — the explainer under a screen title.
    static let onTheDayLede = TypeStyle.subtitle

    /// `600 15`, `-.025em` — a name at the head of a card still asking something.
    static let onTheDayName = TypeStyle.bodyStrong.tracking(em: -0.025)

    /// `400 14` — a name that has been answered, and every value in a quiet row.
    static let onTheDayRowName = TypeStyle.rowValue

    /// `500 14` — a field's value, and a row the design wants a shade firmer. One of the two
    /// dozen places section 8 still reaches for 500, so it stays spelled out.
    static let onTheDayValue = TypeStyle(size: 14, weight: .medium)

    /// `400 14` — a field's placeholder.
    static let onTheDayPlaceholder = TypeStyle.rowValue

    /// `500 14.5`, `-.01em` — the title of a row in a settings-shaped card: the three on `8q`'s
    /// first block (`showApp.html:432-434`), where the design sets every one of them at 14.5.
    ///
    /// The same numbers as `onTheDayDestructive` below, and deliberately its own token rather than
    /// a second caller of that one: they coincide because the design draws one row size, not
    /// because a destructive row and a stat row are the same thing. Naming the ordinary case after
    /// the destructive one would make the next person moving either of them move both.
    static let onTheDayRowTitle = TypeStyle(size: 14.5, weight: .medium, trackingEm: -0.01)

    /// `500 14.5`, `-.01em` — the destructive row at the foot of a kid's page
    /// (`showApp.html:489`). Half a point above `onTheDayValue` and the design does set it there,
    /// which is the one place on this screen a half-point earns its own row: it is the only
    /// sentence drawn in `danger`, and it is the last thing anybody reads before deleting a child
    /// from a camp.
    static let onTheDayDestructive = TypeStyle(size: 14.5, weight: .medium, trackingEm: -0.01)

    /// `400 12.5` — a subtitle under a name, and the note under a pick-up.
    static let onTheDaySubtitle = TypeStyle.rowDetail

    /// `400 11.5` — the amber pick-up line on a marked row.
    static let onTheDayFootnote = TypeStyle.rowSubtitleSmall

    /// `600 14` — `Here` / `Away`.
    static let onTheDayAnswer = TypeStyle.buttonCompact

    /// `600 14.5` — `Add pick-up`. The one button in section 8 the design sets untracked, which
    /// is why it is not `rowLabel`.
    static let onTheDayAdd = TypeStyle(size: 14.5, weight: .semibold)

    /// `600 16`, `-.015em` — the pinned `Finish · 2 left` / `Done` bar.
    static let onTheDayBar = TypeStyle.button

    /// `600 15.5` — the pinned bar in its outlined form ("Move to another group").
    static let onTheDayBarLight = TypeStyle(size: 15.5, weight: .semibold)

    /// `600 10`, `+.14em`, uppercase — a stat cell's label. Half a point under
    /// `onTheDayOverline`, which is the design's own distinction between a section and a stat.
    static let onTheDayStatLabel = TypeStyle.statLabel.tracking(em: 0.14)

    /// `600 17`, `-.03em` — a stat cell's value.
    static let onTheDayStatValue = TypeStyle.venueHeading
}
