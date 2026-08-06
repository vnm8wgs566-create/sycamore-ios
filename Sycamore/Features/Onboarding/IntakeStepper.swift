//
//  IntakeStepper.swift
//  Sycamore
//
//  `8b`'s −/+ control: a `fill` track at radius 11 with 3pt of padding, two 28pt white radius-9
//  buttons either side of a centred `600 14` value.
//
//  Not `DesignSystem/StepperControl`, which is the 34×32 version from the design this app shipped
//  with, colours both glyphs in ink, and — because it reaches 44pt with `.frame(minWidth:)` —
//  stretches its own grey track 30pt past what is drawn. This should take its place once the
//  whole of section 8 has landed.
//

import SwiftUI

/// A real control rather than two buttons in a row: VoiceOver reads the label, speaks the number
/// as its value, and the rotor's swipe-up/down adjusts it, which is the only way this is usable
/// without sight.
struct IntakeStepper: View {

    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    /// What the number counts, spoken as the control's name — "courts at Venue 1".
    let label: String
    /// 28pt beside a venue, 34 in the per-court card, where the value reaches two digits.
    var valueWidth: CGFloat = 28

    /// The design's 28pt button. Scaled, so at the larger sizes the glyph is not pressed against
    /// the edges of a box that stayed still while it grew.
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 14

    var body: some View {
        HStack(spacing: Spacing.hairGap) {
            button("minus", tint: Theme.inkSecondary, enabled: value > range.lowerBound, action: decrease)

            Text("\(value)")
                .typeStyle(.intakeStepperValue, color: Theme.ink)
                .frame(minWidth: valueWidth)
                .multilineTextAlignment(.center)

            button("plus", tint: Theme.accent, enabled: value < range.upperBound, action: increase)
        }
        .padding(3)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increase()
            case .decrement: decrease()
            @unknown default: break
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func increase() {
        value = min(range.upperBound, value + step)
    }

    private func decrease() {
        value = max(range.lowerBound, value - step)
    }

    /// What a 28pt button has to grow by to take a 44pt touch, and nothing once Dynamic Type has
    /// already carried it past that.
    private var hitInset: CGFloat {
        max(0, (HitTarget.minimum - buttonSize) / 2)
    }

    private func button(
        _ symbol: String,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(enabled ? tint : Theme.glyphFaint)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Radius.stepperButton, style: .continuous)
                )
                .intakeTouchTarget(inset: hitInset)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Previews

#Preview("Stepper") {
    @Previewable @State var courts = 6
    @Previewable @State var kids = 8

    VStack(spacing: Spacing.large) {
        IntakeStepper(value: $courts, range: 1...12, label: "Courts at Sycamore")
        IntakeStepper(value: $kids, range: 1...24, label: "Kids per court", valueWidth: 34)
    }
    .padding(Spacing.gutter)
    .background(Theme.surface)
}
