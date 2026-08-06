//
//  IntakeIconTile.swift
//  Sycamore
//
//  The rounded plate an icon sits on — 40pt beside a venue on `8b`, 48 above `8c`'s import copy,
//  34 beside its by-hand row, 42 under `8u`'s "Start a camp".
//

import SwiftUI

/// Scaled rather than fixed: at `.accessibility1` the row's copy is half again as tall, and a
/// plate pinned to 40 next to it reads as a stamp rather than as part of the row.
///
/// Always decorative — every row this appears in says in words what the glyph is a picture of.
struct IntakeIconTile: View {

    let systemName: String
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
        self.systemName = systemName
        self.radius = radius
        self.fill = fill
        self.border = border
        self.isDashed = isDashed
        self.glyphColor = glyphColor
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
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: glyphSize, weight: .regular))
                    .foregroundStyle(glyphColor)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Icon tiles") {
    HStack(spacing: Spacing.medium) {
        IntakeIconTile("mappin", size: 40, glyphSize: 17, fill: Theme.color(for: .moss))
        IntakeIconTile(
            "plus", size: 40, glyphSize: 17,
            fill: Theme.accentSurface, border: Theme.accentBorder, isDashed: true,
            glyphColor: Theme.accent
        )
        IntakeIconTile(
            "arrow.up.doc", size: 48, glyphSize: 22,
            radius: OnboardingMetrics.cardRadius,
            fill: Theme.accentSurface, border: Theme.accentSurfaceBorder,
            glyphColor: Theme.accent
        )
        IntakeIconTile(
            "person.badge.plus", size: 34, glyphSize: 17,
            radius: Radius.control, fill: OnboardingTheme.iconPlate
        )
    }
    .padding(Spacing.gutter)
    .background(Theme.surface)
}
