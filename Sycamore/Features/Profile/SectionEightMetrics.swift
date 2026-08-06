//
//  SectionEightMetrics.swift
//  Sycamore
//
//  The geometry and type `8s` and `8t` draw that the shared tables have no name for yet.
//
//  They live in a feature folder rather than in `DesignSystem/` because that folder is being
//  reworked in parallel and two hands on `Theme.swift` is how a palette forks. Every value here
//  is transcribed from the same CSS as the rest of the app's tokens, and every one is a hoist
//  candidate the moment the folders settle — the PR body lists them.
//
//  Nothing here invents a value. Where section 8 agrees with the shared table the shared table
//  is used, which is why this file is as short as it is.
//

import SwiftUI

// MARK: - Geometry

extension Radius {
    /// `16` — a settings card in section 8.
    ///
    /// One point off `Radius.card`, which is 17 because that is what `Sycamore Flow.dc.html`
    /// drew. Section 8 redrew every card at 16 and the two are not interchangeable: the cards
    /// stack three-deep down these screens, so a point of radius reads as a wobble in the column
    /// rather than as nothing.
    static let settingsCard: CGFloat = 16
}

extension Spacing {
    /// `13` — the gap between the stacked cards on `8s` and `8t` (`flex-direction:column;gap:13px`).
    static let cardStack: CGFloat = 13
    /// `10` — what the scroll content keeps below the last card. Smaller than the gutter above it
    /// because these two screens are sheets: the swipe-down lives in the space underneath.
    static let sheetFoot: CGFloat = 10
    /// `9` — between "Sign out" and "Delete account".
    static let buttonPair: CGFloat = 9
    /// `7` — between a name and the badge that qualifies it.
    static let nameBadge: CGFloat = 7
}

// MARK: - Type

extension TypeStyle {

    // MARK: Display
    //
    // Section 8 sets its two display lines in `Newsreader, Georgia, serif` at weight 400 — a
    // light serif, where the rest of the app is Instrument Sans at 800. The family is the one
    // thing these styles cannot carry: `TypeStyle` has no serif flag and `Font.sycamore` resolves
    // only the bundled sans and the system fallback, both of which live in `DesignSystem/`.
    //
    // So size, weight, tracking and leading are the design's exactly, and the family is the
    // app's. That is four properties of five, and it keeps the *shape* of the design — large and
    // light rather than compact and heavy — which is the part a reader actually sees. The
    // remaining fifth is the first item in the PR body.

    /// `400 26/1.05`, `-.02em` — the name on `8s`.
    static let personName = TypeStyle.profileName
        .size(26).weight(.regular).tracking(em: -0.02).lineHeight(1.05)

    /// `400 33/1.05`, `-.022em` — "Camp settings" on `8t`.
    static let screenTitle = TypeStyle.tabTitle
        .size(33).weight(.regular).tracking(em: -0.022).lineHeight(1.05)

    // MARK: Rows

    /// `600 15`, `-.025em` — "Sycamore · Court 3" on `8s`'s "On today" card.
    static let cardTitle = TypeStyle.bodyStrong.weight(.semibold).tracking(em: -0.025)

    /// `600 14.5`, `-.025em` — a venue's name, "14 staff". Section 8 sets the titles inside a
    /// card half a step lighter than `bodyStrong` and a shade tighter.
    static let cardTitleSm = TypeStyle.rowLabel.weight(.semibold).tracking(em: -0.025)

    /// `400 12.5` — a value or a qualifier beside a title ("at UCLA Tennis Camp").
    /// The regular cut of `rowSubtitle`; section 8 sets its secondary copy in 400, not 500.
    static let detail = TypeStyle.rowSubtitle.weight(.regular)

    /// `400 12` — "50 kids · 6 coaches", "2 admins · 4 unassigned".
    static let detailSm = TypeStyle.meta.weight(.regular)

    /// `400 13` — the line under `8t`'s title.
    static let headerDetail = TypeStyle.sheetSubtitle.weight(.regular)

    // MARK: Badges and controls

    /// `600 10`, `+.13em`, uppercase — the role pill on `8s` and the admin pill on `8t`.
    /// Half a point larger and a step lighter than `badge`, and tracked considerably wider.
    static let pillLabel = TypeStyle.badge.size(10).weight(.semibold).tracking(em: 0.13)

    /// `600 10`, `+.1em`, uppercase — the amber "2 short" flag on a venue row. The same cut as
    /// `pillLabel` but tracked tighter, because it sits inline against a name rather than alone.
    static let flagLabel = TypeStyle.badge.size(10).weight(.semibold).tracking(em: 0.1)

    /// `600 21` — the initials in `8s`'s 64pt photo well. `initials(forAvatarSize:)` reads 20 at
    /// that diameter and sets it in 800, because the sizes it was built from are the 36–46pt
    /// discs in a list; the well is the only avatar on its screen and the design lightens it.
    static let wellInitials = TypeStyle(size: 21, weight: .semibold)

    /// `600 9.5` — the initials in `8t`'s overlapping staff discs.
    static let stackInitials = TypeStyle(size: 9.5, weight: .semibold)

    /// `600 14` — the court count between a stepper's two buttons.
    static let stepperCount = TypeStyle.stepperValue.size(14).weight(.semibold)

    /// `600 14` — "Sign out", "Delete account". A step lighter than `buttonCompact`.
    static let footerButton = TypeStyle.buttonCompact.weight(.semibold)
}
