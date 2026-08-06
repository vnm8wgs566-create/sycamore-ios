//
//  OnTheDayTokens.swift
//  Sycamore
//
//  The handful of values `8m Attendance` and `8n Leaving early` draw that `Theme`, `Radius` and
//  `Spacing` do not carry yet.
//
//  They live here rather than in the design system because section 8 is being built one unit at
//  a time and a shared file is a shared merge conflict. Every one of them is a number or a
//  colour the design document actually spells; none is invented. When the rest of section 8
//  lands, these belong in `Theme.swift` — see the PR body.
//

import SwiftUI

enum OnTheDayTokens {

    // MARK: Colour

    /// The amber a pick-up is written in on a marked row — `#B67A16`, "Leaves 2:30 today".
    ///
    /// The only colour on either screen that is neither ink, accent nor a line, and the only one
    /// with no counterpart in `Theme`. It has to stay distinct from the green: green means
    /// "answered", amber means "answered, and there is a catch". The dark value is lifted and
    /// desaturated the way the rest of the palette is, so it clears 4.5:1 on `surface` in both
    /// schemes rather than turning to mud on near-black.
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

    /// The attendance progress track.
    static let progressHeight: CGFloat = 4

    /// The green disc with the tick, on a kid who has been marked here.
    static let markDiameter: CGFloat = 22

    /// The right-aligned ladder numeral ahead of every name.
    static let rankColumn: CGFloat = 20

    /// Horizontal padding inside a section-8 card.
    static let cardInset: CGFloat = 13

    /// The inset an overline carries so it lines up with the copy inside the card beneath it.
    static let overlineInset: CGFloat = 4

    /// How much of the frame `8n` opens over.
    ///
    /// `ActiveSheet.earlyPickup` still declares 0.67, which was right when this sheet asked two
    /// questions. The design now draws it as a full screen — a week of pick-ups, then a card to
    /// add another — and at 0.67 the "New pick-up" card opens below the fold, which is the one
    /// thing on the sheet somebody came to use.
    static let pickupDetent: Double = 0.88
}
