//
//  TournamentStepper.swift
//  Sycamore
//
//  The −/+ control both of this tab's sheets are built around: a bordered track with a grey minus,
//  a centred figure, and a **black** plus.
//
//  ── WHY NOT `StepperControl` ──────────────────────────────────────────────────────────────────
//
//  Because they are different controls that happen to do the same arithmetic. `StepperControl` is
//  the design's earlier one — a `fill` track at radius 11 holding two identical white 34×32
//  buttons, drawn in the "Shape" card and the venue sheet. This is `sheet-shTourney.html:27` and
//  `sheet-shScore.html:6-8`: a 1.5pt `stroke` track at radius 15, 38pt buttons at radius 11, and
//  the two ends deliberately *unequal* — `#F1F2F5` under the minus, `#0B0B0C` under the plus.
//
//  That asymmetry is the whole point of transcribing it rather than substituting. These steppers
//  set the size of a thing that does not exist yet — how many days, how many teams, how many
//  tournaments — and the design weights the direction that makes it bigger. Redrawing them as two
//  identical grey buttons would flatten a deliberate emphasis into a shrug, on the control that is
//  the main thing on the sheet.
//
//  It is a `@Binding` rather than a pair of closures because both callers hold the value in their
//  own draft and every one of them clamps to the same range. A stepper that reported taps and left
//  the clamping to the caller would be four call sites each remembering to clamp.
//

import SwiftUI

struct TournamentStepper: View {

    @Binding var value: Int
    var range: ClosedRange<Int>
    /// What the control is for, spoken. There is no visible label inside the track — the field
    /// label above it is the name of the thing — so VoiceOver is told here.
    var label: String
    /// `38` on the create sheet, `32` on the score sheet, which draws two of them side by side.
    var buttonSize: CGFloat = TournamentMetrics.stepperButton
    var buttonRadius: CGFloat = TournamentMetrics.stepperButtonRadius
    var glyphSize: CGFloat = TournamentMetrics.stepperGlyph
    var valueStyle: TypeStyle = TournamentType.stepperValue

    /// The track and its buttons are drawn at the design's sizes, which grow with Dynamic Type so
    /// a 17pt figure at `.accessibility1` is not clipped by a 38pt box that stayed 38.
    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1

    private var side: CGFloat { buttonSize * scale }

    var body: some View {
        HStack(spacing: 0) {
            button("minus", tone: .quiet, enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }

            Text("\(value)")
                .typeStyle(valueStyle, color: Theme.ink)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            button("plus", tone: .loud, enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
        .padding(TournamentMetrics.stepperPadding)
        .overlay {
            RoundedRectangle(cornerRadius: TournamentMetrics.stepperRadius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: BorderWidth.input)
        }
        // One control, one value, two actions — rather than three separate elements, which reads
        // as "minus, 2, plus" and gives an adjustable-rotor user nothing to adjust.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    /// Which end of the track a button is. Named rather than passed as two colours, because the
    /// asymmetry is the design decision and a call site handing in a fill could quietly undo it.
    private enum ButtonTone { case quiet, loud }

    private func button(
        _ symbol: String, tone: ButtonTone, enabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .medium))
                .foregroundStyle(tone == .loud ? Theme.surface : Theme.inkSecondary)
                .frame(width: side, height: side)
                .background(
                    tone == .loud ? Theme.ink : Theme.fill,
                    in: RoundedRectangle(cornerRadius: buttonRadius, style: .continuous)
                )
                // The plate is drawn at the design's size; only the region a thumb has to find
                // grows to the minimum. The score sheet's 32pt buttons are the ones this matters
                // for, and there are four of them in a row.
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : TournamentMetrics.disabledOpacity)
        // Hidden because the enclosing element is adjustable and already carries both directions.
        // Left visible, VoiceOver would offer five ways to change one number.
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

/// Hoisted to file scope for the mangling reason `Components.swift:1473-1475` gives.
private struct TournamentStepperPreviewHarness: View {
    @State private var days = 2
    @State private var teams = 4
    @State private var score = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            SheetFieldLabel("Days", topPadding: 0)
            TournamentStepper(value: $days, range: TournamentRules.dayRange, label: "Days")

            SheetFieldLabel("Teams")
            TournamentStepper(value: $teams, range: TournamentRules.teamRange, label: "Teams")

            SheetFieldLabel("Games")
            TournamentStepper(
                value: $score,
                range: TournamentRules.scoreRange,
                label: "Games to Serene C",
                buttonSize: TournamentMetrics.scoreStepperButton,
                buttonRadius: TournamentMetrics.scoreStepperRadius,
                glyphSize: TournamentMetrics.scoreStepperGlyph,
                valueStyle: TournamentType.scoreValue
            )
        }
        .padding(Spacing.sheet)
        .background(Theme.surface)
    }
}

#Preview("Steppers") {
    TournamentStepperPreviewHarness()
        .frame(width: 402, height: 420)
}

#Preview("Steppers — accessibility1") {
    TournamentStepperPreviewHarness()
        .frame(width: 402, height: 560)
        .environment(\.dynamicTypeSize, .accessibility1)
}
