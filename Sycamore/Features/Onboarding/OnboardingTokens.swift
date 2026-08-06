//
//  OnboardingTokens.swift
//  Sycamore
//
//  What the getting-in screens draw that the shared palette and geometry have no name for.
//
//  The amber family moved to `Theme` (it is section 8's third severity step and three screens
//  outside this branch reach for it), so what is left here is genuinely local: two green-greys
//  that appear once each on `8u`, one grey the palette only names as a rule, the corner radius
//  section 8 draws its cards at, and the two gaps its scroll views run on.
//
//  They live beside the screens rather than in `Theme`/`Radius`/`Spacing` on purpose. This branch
//  owns five of section 8's twenty-one screens; dropping tokens into the files every feature
//  reads makes them the merge conflict for the whole section. Hoist them once section 8 lands —
//  the radius especially, because *every* card in the section is 16 and the shared `Radius.card`
//  still reads 17 from the design this app shipped with.
//
//  Light values are the design's, unchanged. Dark values are derived the way `Theme` derives its
//  own: the hue holds and the text end brightens far enough to clear 4.5:1 on a near-black card.
//

import SwiftUI

enum OnboardingTheme {

    /// `#5C7A68` — the role line under the camp you are signed in to on `8u` ("Worker · Sycamore,
    /// Court 3"). A green-grey rather than `inkMuted`: it sits inside the accent-bordered card
    /// that marks the camp you are standing in, and the design tints the copy to match the border.
    static let currentCampRole = Color(light: "5C7A68", dark: "9CBCA9")

    /// `#7FA895` — "You become its first admin" under `8u`'s "Start a camp".
    ///
    /// Not `Theme.accentSubtle` (`#8FC2A5`), which is the same line drawn on a *filled* accent
    /// button. This one sits on white inside the dashed card, so the design takes it a step darker.
    static let startCampSubtitle = Color(light: "7FA895", dark: "6E9A87")

    /// `#F4F5F7` — the 34pt plate `8c` sits its "add a player by hand" glyph on.
    ///
    /// Aliased rather than spelled out: the palette already carries this value as `hairlineFaint`,
    /// where it means a list rule. Naming the role here keeps the feature hex-free and makes the
    /// collision visible — if the two ever need to move apart, this is the line that splits.
    static let iconPlate = Theme.hairlineFaint
}

enum OnboardingMetrics {

    /// `border-radius:16px` — every card in section 8. `Radius.card` is 17, from the design this
    /// app shipped with, and `Radius.button` is 16 by coincidence of role rather than of intent.
    static let cardRadius: CGFloat = 16

    /// The `gap:13px` between blocks in `8b`'s and `8u`'s scroll views.
    static let blockGap: CGFloat = 13

    /// The `gap:9px` between cards in `8c`'s, `8d`'s and `8e`'s.
    static let cardGap: CGFloat = 9

    /// The 10pt `8b` and `8u` leave under the last thing in the column, on top of whatever the
    /// safe area asks for.
    static let contentBottom: CGFloat = 10

    /// `height:52px` — every call to action in these five screens. Shorter than the 56 the
    /// stage-1 screens use, because these sit on a scrolling form rather than at the foot of a
    /// full-bleed page.
    static let ctaHeight: CGFloat = 52

    /// `bottom:20px` — the pinned call to action's clearance, measured from the safe area rather
    /// than from the glass so the home indicator never sits under it.
    static let ctaInset: CGFloat = 20

    /// `padding-bottom:88px` — what a scroll view leaves so its last row clears the call to
    /// action floating over it on `8d` and `8e`.
    static let ctaClearance: CGFloat = 88

    /// How far a 28pt control has to grow to reach the 44pt minimum touch target: `(44 - 28) / 2`.
    /// Spent as padding that is added and then taken away again, so nothing moves on screen.
    static let stepperHitInset: CGFloat = 8
}

enum OnboardingShadows {

    /// `0 12px 30px rgba(26,127,85,.24)` — the lift under the pinned CTA on `8d` and `8e`.
    ///
    /// Tinted with the accent rather than cast in black, which is what the design draws: the
    /// button floats over scrolling content and the green halo is what separates it from the
    /// rows sliding underneath. CSS blur is roughly twice SwiftUI's, so 30 becomes 15.
    static let pinnedCTA = ShadowToken(color: Theme.accent.opacity(0.24), radius: 15, y: 12)
}
