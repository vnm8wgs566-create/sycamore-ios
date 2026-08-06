//
//  GroupsMeter.swift
//  Sycamore
//
//  `▓▓▓▓▓░░░  5 of 8` — how far off eight kids the camp is, on `8g`.
//
//  The design draws the fill as its own `border-radius:99px` capsule at 62% of the track, which
//  means the bar genuinely has to be *sized* to a fraction of the width it is offered. Masking
//  would square off its trailing cap and a horizontal `scaleEffect` would squash both of them,
//  so the proportion is done in layout, by `ProportionalWidth` below.
//

import SwiftUI

struct GroupsMeter: View {

    let count: Int
    let target: Int

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(count) / Double(target))
    }

    var body: some View {
        HStack(spacing: Spacing.row) {
            Capsule(style: .continuous)
                .fill(Theme.hairline)
                .frame(height: Spacing.tight)
                .overlay(alignment: .leading) {
                    ProportionalWidth(fraction: progress) {
                        Capsule(style: .continuous)
                            .fill(Theme.accent)
                    }
                }

            Text("\(count) of \(target)")
                .typeStyle(.metaSmall, color: Theme.inkSecondary)
        }
        // One figure, spoken once. The bar and the label say the same thing, and a reader who
        // has just heard "5 of 8" does not need to hear it again as a percentage.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kids added")
        .accessibilityValue("\(count) of \(target)")
    }
}

/// Gives its subview a fraction of the width it is offered, and all of the height.
///
/// The `Layout` protocol rather than a `GeometryReader`: this is a proportional *layout*, not a
/// measurement, and the two modern alternatives do not fit. `onGeometryChange` would read the
/// width into state and set a frame from it, which is the same answer a frame later;
/// `containerRelativeFrame` measures the enclosing container, and this track is only part of a
/// row it shares with its own label.
private struct ProportionalWidth<Content: View>: View {

    let fraction: Double
    @ViewBuilder let content: Content

    var body: some View {
        Fraction(fraction: fraction) { content }
    }

    private struct Fraction: Layout {
        let fraction: Double

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            // The track proposes both dimensions, but a sizing pass can propose neither — so
            // fall back to what the subview would take on its own rather than to zero.
            let natural = subviews.first?.sizeThatFits(proposal) ?? .zero
            return CGSize(
                width: proposal.width ?? natural.width,
                height: proposal.height ?? natural.height
            )
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            subviews.first?.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width * fraction, height: bounds.height)
            )
        }
    }
}

// MARK: - Previews

#Preview("Meter") {
    VStack(spacing: Spacing.section) {
        GroupsMeter(count: 0, target: 8)
        GroupsMeter(count: 5, target: 8)
        GroupsMeter(count: 8, target: 8)
    }
    .padding(Spacing.section)
    .background(Theme.surface)
}
