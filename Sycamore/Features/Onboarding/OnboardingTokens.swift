//
//  OnboardingTokens.swift
//  Sycamore
//
//  The two things the getting-in screens draw that the shared palette has no name for: the
//  amber a row wears when the file left a detail out (`8d`), and the coloured lift under a
//  pinned call to action (`8d`, `8e`).
//
//  They live beside the screens rather than in `Theme` on purpose. This branch owns four of
//  section 8's twenty-one screens; dropping tokens into the one file every feature reads makes
//  it the merge conflict for the whole section. Hoist them once section 8 lands — `warning` is
//  a fourth semantic family beside ink, accent and danger, and every pinned CTA in the section
//  casts the same shadow.
//
//  Light values are the design's, unchanged. Dark values are derived the way `Theme` derives
//  its own: the hue holds, the surface drops to something that sits on a near-black card, and
//  the text end brightens far enough to clear 4.5:1 on it.
//

import SwiftUI

enum OnboardingTheme {

    // MARK: Warning
    //
    // `8d`'s "needs a detail" family. Amber rather than `danger` because nothing is wrong —
    // the office left a column blank, and the row is waiting on one answer, not reporting a
    // failure. Red would send somebody looking for a problem that is not there.

    /// `#B67A16` — "No age in the file".
    static let warning = Theme.warning
    /// `#8A6416` — the label on a `warningTint` chip.
    static let warningStrong = Theme.warningDark
    /// `#FAF6EC` — the "Fix" chip's plate.
    static let warningTint = Theme.warningTint
    /// `#F0E3C6` — the border around the card of rows that need a detail.
    static let warningBorder = Theme.warningBorder
}

enum OnboardingShadows {

    /// `0 12px 30px rgba(26,127,85,.24)` — the lift under the pinned CTA on `8d` and `8e`.
    ///
    /// Tinted with the accent rather than cast in black, which is what the design draws: the
    /// button floats over scrolling content and the green halo is what separates it from the
    /// rows sliding underneath. CSS blur is roughly twice SwiftUI's, so 30 becomes 15.
    static let pinnedCTA = ShadowToken(color: Theme.accent.opacity(0.24), radius: 15, y: 12)
}
