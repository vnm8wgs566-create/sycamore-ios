//
//  IntakeIconTile.swift
//  Sycamore
//
//  The rounded plate an icon sits on — 40pt beside a venue on `8b`, 52 above `8c`'s "Drop the
//  sign-up list", 34 beside its two action rows, 42 under `8u`'s "Start a camp".
//
//  What sits on it is either an SF Symbol or an emoji. The design draws both: a `plus` on the
//  dashed "Add a venue" plate, and a venue's own emoji on a venue's plate everywhere a venue is
//  drawn. Two initialisers rather than a `String` that might be either, so a caller cannot ask
//  for a `glyphColor` on a glyph that has its own colours.
//

import SwiftUI

/// Scaled rather than fixed: at `.accessibility1` the row's copy is half again as tall, and a
/// plate pinned to 40 next to it reads as a stamp rather than as part of the row.
///
/// Decorative in every use, but for two different reasons. An SF Symbol here is a picture of
/// something the row already says in words — "Add a venue", "Upload a file". An emoji here
/// identifies a venue, which is not decoration; it is hidden anyway because the row names that
/// venue on the very next line, and whatever wraps the tile to make it choosable carries the
/// label. Hiding the tile and labelling the control is what keeps VoiceOver from reading the
/// venue twice.
struct IntakeIconTile: View {

    /// What sits on the plate. Kept as one property rather than two optional ones so there is no
    /// way to ask for a symbol and an emoji at once.
    private enum Glyph: Equatable {
        case symbol(String)
        /// Already coloured by the font, so `glyphColor` does not reach it.
        case emoji(String)
    }

    private let glyph: Glyph
    var radius: CGFloat = Radius.tile
    var fill: Color = Theme.fill
    var border: Color?
    var isDashed: Bool = false
    var glyphColor: Color = Theme.inkSecondary

    @ScaledMetric private var size: CGFloat
    @ScaledMetric private var glyphSize: CGFloat

    init(
        _ systemName: String,
        size: CGFloat,
        glyphSize: CGFloat,
        radius: CGFloat = Radius.tile,
        fill: Color = Theme.fill,
        border: Color? = nil,
        isDashed: Bool = false,
        glyphColor: Color = Theme.inkSecondary
    ) {
        self.glyph = .symbol(systemName)
        self.radius = radius
        self.fill = fill
        self.border = border
        self.isDashed = isDashed
        self.glyphColor = glyphColor
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self._glyphSize = ScaledMetric(wrappedValue: glyphSize, relativeTo: .body)
    }

    /// The venue's own emoji on the venue's own tint, which is how the design draws a venue
    /// wherever it draws one — `width:44px;height:44px;border-radius:14px;background:#F1F5EC;
    /// font-size:21px` with 🌳 on it (`design/Sycamore Flow.dc.html:276`).
    ///
    /// No `glyphColor` and no `border`: the design's emoji tiles carry neither, and an emoji is
    /// coloured by its own font in any case.
    init(
        emoji: String,
        size: CGFloat,
        glyphSize: CGFloat,
        radius: CGFloat = Radius.tile,
        fill: Color = Theme.fill
    ) {
        self.glyph = .emoji(emoji)
        self.radius = radius
        self.fill = fill
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self._glyphSize = ScaledMetric(wrappedValue: glyphSize, relativeTo: .body)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        shape
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                if let border {
                    // CSS draws a dashed border at roughly three times its width per dash and gap.
                    shape.strokeBorder(
                        border,
                        style: isDashed
                            ? StrokeStyle(lineWidth: BorderWidth.hairline, dash: [3, 3])
                            : StrokeStyle(lineWidth: BorderWidth.hairline)
                    )
                }
            }
            .overlay { glyphView }
            .accessibilityHidden(true)
    }

    /// `.font(.system(size:))` on both branches: this is a glyph, not copy, so there is no
    /// `TypeStyle` for it — the same call `VenueSheet`'s icon grid and the camp picker's tile
    /// already make.
    @ViewBuilder
    private var glyphView: some View {
        switch glyph {
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(glyphColor)
        case let .emoji(emoji):
            Text(emoji)
                .font(.system(size: glyphSize))
        }
    }
}

// MARK: - Previews

#Preview("Icon tiles") {
    HStack(spacing: Spacing.medium) {
        // 19 rather than 17: an emoji is measured against the plate, and 21-on-44 is the ratio
        // the design draws (`:276`), which on this 40pt plate is 19.
        IntakeIconTile(emoji: "🌳", size: 40, glyphSize: 19, fill: Theme.color(for: .moss))
        IntakeIconTile(
            "plus", size: 40, glyphSize: 17,
            fill: Theme.accentSurface, border: Theme.accentBorder, isDashed: true,
            glyphColor: Theme.accent
        )
        IntakeIconTile(
            "arrow.up.doc", size: OnboardingMetrics.emptyMark,
            glyphSize: OnboardingMetrics.emptyMarkGlyph,
            radius: OnboardingMetrics.emptyMarkRadius,
            fill: Theme.accentSurface, border: Theme.accentSurfaceBorder,
            glyphColor: Theme.accent
        )
        IntakeIconTile(
            "person.badge.plus", size: 34, glyphSize: 16,
            radius: Radius.control, fill: OnboardingTheme.iconPlate
        )
    }
    .padding(Spacing.gutter)
    .background(Theme.surface)
}
