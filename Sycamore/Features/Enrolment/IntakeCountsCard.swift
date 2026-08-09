//
//  IntakeCountsCard.swift
//  Sycamore
//
//  The row of figures at the top of a review screen.
//
//  Two screens draw it now — `8d` reading a first import (New / Returning / Ranked) and
//  `RosterReviewView` reading a file against a camp that already exists (New / Changed / Not in
//  this file) — and they draw the *same card*: three left-aligned columns, a tracked grey label
//  over a large serif figure, evenly divided across one undivided card.
//
//  What differs is only which counts go in it, so the counts are the parameter and nothing else
//  is. The alternative was a flag on one view saying which set of three it was showing, which is
//  the shape this whole unit is avoiding: a screen whose chrome depends on a mode.
//
//  The colour is per-count rather than per-card because it carries meaning on exactly one figure.
//  `8d`'s RANKED is grey, and grey there means "zero is the plan, not a shortfall" — an import
//  ranks nobody and the first sort does. A card-wide tint could not say that about one column.
//

import SwiftUI

struct IntakeCountsCard: View {

    /// One column. `Identifiable` by its label, which is what makes a `ForEach` over three
    /// hand-written columns legal without inventing ids for them — no card has two columns headed
    /// the same word, and one that did would be a card with a bug in it.
    struct Count: Identifiable {
        let label: String
        let value: Int
        /// Grey for a figure whose zero is expected; the ink every other figure takes otherwise.
        let color: Color

        var id: String { label }

        init(_ label: String, _ value: Int, color: Color = Theme.ink) {
            self.label = label
            self.value = value
            self.color = color
        }
    }

    let counts: [Count]

    init(_ counts: [Count]) {
        self.counts = counts
    }

    var body: some View {
        Card(radius: OnboardingMetrics.cardRadius, isDivided: false) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                ForEach(counts) { count in
                    column(count)
                }
            }
            .padding(Spacing.gutterWide)
        }
    }

    private func column(_ count: Count) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(count.label)
                .typeStyle(.intakeStatLabel, color: Theme.inkFaint)
            Text("\(count.value)")
                .typeStyle(.intakeStatValue, color: count.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // "New, 8" rather than "New" and "8" as two stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.label)
        .accessibilityValue("\(count.value)")
    }
}

// MARK: - Previews

#Preview("Counts") {
    VStack(spacing: OnboardingMetrics.cardGap) {
        IntakeCountsCard([
            .init("New", 40),
            .init("Returning", 2),
            .init("Ranked", 0, color: Theme.inkFaint),
        ])

        IntakeCountsCard([
            .init("New", 8),
            .init("Changed", 3),
            .init("Not in this file", 2),
        ])
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}
