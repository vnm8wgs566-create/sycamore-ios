//
//  AccentDisc.swift
//  Sycamore
//
//  A glyph in a tinted disc with a hairline ring — the mark above every hand-drawn empty state.
//
//  `#F6FAF7` on `#E4EDE7`: a green-tinted *surface*, a step lighter than the `accentTint` that
//  sits under accent-coloured copy.
//
//  Three screens drew this and each wrote it out: the Inbox's "All clear", Groups' "opens at
//  eight kids", and Schedule's empty day. Written separately they drifted — two built it as a
//  `Circle` with the glyph in an overlay and one as an `Image` with the circle behind it, and
//  they carried three different Dynamic Type ramps.
//
//  One of them was wrong, which is the reason this file exists rather than a comment claiming
//  the three match. `GroupsLockedState` scaled its disc and left its padlock a bare constant, so
//  at the app's `.accessibility1` cap the disc grew and the glyph did not: a padlock rattling
//  around inside its own ring. A single `@ScaledMetric` ramp for both is not a tidiness argument
//  — it is the only arrangement in which that cannot happen again.
//
//  The sizes stay per-caller. They are transcribed from three different frames and the disc sits
//  above different copy on each, so they are a real difference; the composition is not.
//

import SwiftUI

struct AccentDisc: View {

    private let systemName: String
    private let weight: Font.Weight

    /// Disc and glyph, on one ramp. Both are `@ScaledMetric` against the *same* text style, which
    /// is what keeps the glyph's share of the disc fixed at every type size.
    @ScaledMetric private var size: CGFloat
    @ScaledMetric private var glyphSize: CGFloat

    /// - Parameters:
    ///   - systemName: The SF Symbol. Decorative — the card's own words carry the meaning, so
    ///     this is hidden from VoiceOver rather than labelled.
    ///   - size: The disc's drawn diameter, before scaling.
    ///   - glyph: The symbol's drawn point size, before scaling.
    ///   - weight: `.regular` everywhere except the Inbox tick, which the design draws bold.
    ///   - textStyle: The band the pair grows on. Per caller because each disc sits above
    ///     different copy, and a mark should grow with the words it introduces.
    init(
        _ systemName: String,
        size: CGFloat,
        glyph: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .title
    ) {
        self.systemName = systemName
        self.weight = weight
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self._glyphSize = ScaledMetric(wrappedValue: glyph, relativeTo: textStyle)
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: glyphSize, weight: weight))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(Theme.accentSurface, in: Circle())
            .overlay {
                Circle().strokeBorder(Theme.accentSurfaceBorder, lineWidth: BorderWidth.hairline)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Accent discs") {
    VStack(spacing: Spacing.hero) {
        HStack(spacing: Spacing.gutter) {
            AccentDisc("checkmark", size: 56, glyph: 26, weight: .bold, relativeTo: .largeTitle)
            AccentDisc("lock", size: 52, glyph: 24, relativeTo: .title2)
            AccentDisc("calendar.day.timeline.left", size: 52, glyph: 24)
        }

        // The size the app caps at. Every glyph should still sit the same way inside its ring.
        HStack(spacing: Spacing.gutter) {
            AccentDisc("checkmark", size: 56, glyph: 26, weight: .bold, relativeTo: .largeTitle)
            AccentDisc("lock", size: 52, glyph: 24, relativeTo: .title2)
            AccentDisc("calendar.day.timeline.left", size: 52, glyph: 24)
        }
        .environment(\.dynamicTypeSize, .accessibility1)
    }
    .padding(Spacing.hero)
    .background(Theme.surfaceWarm)
}
