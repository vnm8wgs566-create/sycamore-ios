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

import SwiftUI

// MARK: - Colour

enum GroupsPalette {

    /// `#B67A16` — the countdown clock beside a kid who is going home early.
    ///
    /// The one warm colour on the screen, and deliberately not `Theme.danger`: leaving at 2:30
    /// is a plan, not a problem. Hoist it when Schedule draws its "needs a coach" amber, which
    /// is the same value in the design document.
    static let pickup = Color(light: "B67A16", dark: "E0A03C")

    /// `0 0 0 4px rgba(26,127,85,.09)` — the halo the design puts around the card a kid is
    /// about to land in. Derived from the accent rather than spelled, so it follows it.
    static let dropHalo = Theme.accent.opacity(0.09)
}

// MARK: - Geometry

enum GroupsMetrics {

    /// Width of the `dropHalo` ring, drawn outside the card's own border.
    static let dropHaloWidth: CGFloat = 4

    /// How far a card that is *not* the drop target fades while a kid is in the air. The design
    /// draws `opacity:.55` on the cards either side of the target.
    static let bystanderOpacity: Double = 0.55

    /// The rank column. Wide enough for the two-digit ranks that are most of a hundred-kid camp,
    /// and shared with the card the kid is carried in so the two line up mid-move.
    static let numeralWidth: CGFloat = 20

    /// The dashed rule the design draws twice: around "Add a group", and around the gap a kid
    /// leaves behind while they are in the air.
    static let dash: [CGFloat] = [4, 3]

    /// Height of that gap. The row that left is 44pt of touch target around a 30pt line of type,
    /// and it is the 30 the dashes stand in for.
    static let gapHeight: CGFloat = 30

    /// Every fold, unfold and aim on the screen. One curve, so a card opening and a kid sliding
    /// to a new target are recognisably the same motion.
    static let fold: Animation = .snappy(duration: 0.24)
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
