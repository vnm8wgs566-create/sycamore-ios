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
//  is used, which is why this file is as short as it is — and shorter again now that the table
//  itself has been corrected to section 8's weights.
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
    // Section 8 sets its display lines in `Newsreader, Georgia, serif` at weight 400. Both styles
    // below take that from the shared table rather than restating it: `profileName` and `tabTitle`
    // are already the design's serif at 400 and the design's tracking, so all these two vary is
    // the size and the leading, which is the only thing the design varies per screen.

    /// `400 26/1.05 Newsreader`, `-.02em` — the name on `8s`.
    static let personName = TypeStyle.profileName.size(26).lineHeight(1.05)

    /// `400 33/1.05 Newsreader`, `-.022em` — "Camp settings" on `8t`.
    static let screenTitle = TypeStyle.tabTitle.size(33).lineHeight(1.05)

    // MARK: Rows

    /// `600 15`, `-.025em` — "Sycamore · Court 3" on `8s`'s "On today" card.
    static let cardTitle = TypeStyle.bodyStrong.tracking(em: -0.025)

    /// `600 14.5`, `-.025em` — a venue's name, "14 staff". Section 8 sets the titles inside a
    /// card half a step smaller than `bodyStrong` and a shade tighter.
    static let cardTitleSm = TypeStyle.rowLabel.tracking(em: -0.025)

    /// `400 12.5` — a value or a qualifier beside a title ("at UCLA Tennis Camp").
    static let detail = TypeStyle.rowDetail

    /// `400 12` — "50 kids · 6 coaches", "2 admins · 4 unassigned".
    static let detailSm = TypeStyle.meta

    /// `400 13` — the line under `8t`'s title.
    static let headerDetail = TypeStyle.sheetSubtitle

    // MARK: Badges and controls

    /// `600 10`, `+.13em`, uppercase — the role pill on `8s` and the admin pill on `8t`.
    static let pillLabel = TypeStyle.statLabel.tracking(em: 0.13)

    /// `600 10`, `+.1em`, uppercase — the amber "2 short" flag on a venue row. The same cut as
    /// `pillLabel` but tracked tighter, because it sits inline against a name rather than alone.
    static let flagLabel = TypeStyle.statLabel.tracking(em: 0.1)

    /// `600 21` — the initials in `8s`'s 64pt photo well. `initials(forAvatarSize:)` reads 20 at
    /// that diameter, because the sizes it was built from are the 36–46pt discs in a list; the
    /// well is the only avatar on its screen and the design draws it a point larger.
    static let wellInitials = TypeStyle(size: 21, weight: .semibold)

    /// `600 9.5` — the initials in `8t`'s overlapping staff discs.
    static let stackInitials = TypeStyle(size: 9.5, weight: .semibold)

    /// `600 14` — the court count between a stepper's two buttons.
    static let stepperCount = TypeStyle.stepperValue.size(14)

    /// `600 14` — "Sign out", "Delete account".
    static let footerButton = TypeStyle.buttonCompact
}
