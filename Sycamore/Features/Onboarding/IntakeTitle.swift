//
//  IntakeTitle.swift
//  Sycamore
//
//  A section 8 heading, in the serif the design sets them in.
//
//  The design asks for Newsreader, which is not bundled and cannot be without touching the
//  project file. This draws the heading in the platform's own serif — New York — which is the
//  same transitional shape at the same weight, ships on every device, and carries Dynamic Type
//  without a fallback path. See the PR body.
//

import SwiftUI

/// Not `.typeStyle(_:color:)`: `TypeStyle` can pick the bundled face or the system one, but has
/// no third case for a serif, and teaching it one means editing the file every feature reads.
/// Everything else about the style is honoured the same way `TypeStyleModifier` honours it —
/// tracking and line spacing come from the design's unscaled size, and the size itself grows with
/// Dynamic Type along the ramp `TypeStyle` picks.
struct IntakeTitle: View {

    let text: String
    var style: TypeStyle = .intakeTitle
    var color: Color = Theme.ink

    /// The design's point size, grown by whatever the reader has asked for.
    @ScaledMetric private var scaledSize: CGFloat

    init(_ text: String, style: TypeStyle = .intakeTitle, color: Color = Theme.ink) {
        self.text = text
        self.style = style
        self.color = color
        self._scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.textStyle)
    }

    var body: some View {
        Text(text)
            .font(.system(size: scaledSize, weight: style.weight.fontWeight, design: .serif))
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            // A title is what the screen is, so it is what VoiceOver should reach first.
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Previews

#Preview("Serif headings") {
    VStack(alignment: .leading, spacing: Spacing.large) {
        IntakeTitle("Shape the camp")
        IntakeTitle("42 players", style: .intakeTitleSm)
        IntakeTitle("Your camps")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.header)
    .background(Theme.surface)
}
