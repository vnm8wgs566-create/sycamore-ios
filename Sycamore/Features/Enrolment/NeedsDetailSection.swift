//
//  NeedsDetailSection.swift
//  Sycamore
//
//  The amber-bordered card of rows the file left something out of, with a Fix beside each.
//
//  Both review screens draw it, unchanged and for the same reason: a re-imported file has the same
//  gaps a first one did, and a row missing an age is the row `importPlayers` and `updatePlayers`
//  would fail the *whole batch* on — one array, one insert, one CHECK. Routing them into a section
//  with a button beside them is what turns a raw PostgREST error into something a person standing
//  on a court can do something about.
//
//  Extracted alongside `IntakeCountsCard` and `FoldedRosterSection`. The three of them are what
//  the two review screens genuinely share; where they stop sharing — ticks, buckets, the sentence
//  under the button — is where they became separate screens.
//
//  The row is **not** a builder here, unlike `FoldedRosterSection`'s. There is nothing per-screen
//  about it: the name, the issue's own label and the Fix chip are the same three things in both,
//  and a builder would be a seam offered to nobody.
//

import SwiftUI

struct NeedsDetailSection: View {

    let rows: [IntakePlayer]
    /// Opens `8e` on that row, prefilled, to supply what the file was missing.
    let onFix: (IntakePlayer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
            IntakeSectionHeader(
                "Needs a detail · \(rows.count)",
                trackingEm: 0.14,
                horizontalPadding: 4,
                bottomPadding: 0
            )

            Card(radius: OnboardingMetrics.cardRadius, borderColor: Theme.warningBorder) {
                ForEach(rows) { player in
                    row(player)
                }
            }
        }
    }

    private func row(_ player: IntakePlayer) -> some View {
        Button { onFix(player) } label: {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.displayName)
                        .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                    Text(player.issue?.label ?? "")
                        .typeStyle(.intakeRowDetail, color: Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // The chip is the affordance the design draws, but the whole row is what takes the
                // tap — a 24pt chip is not something to aim at on a court.
                Text("Fix")
                    .typeStyle(.intakeChipSm, color: Theme.warningDark)
                    .padding(.horizontal, Spacing.row)
                    .padding(.vertical, Spacing.tight)
                    .background(Theme.warningTint, in: Capsule(style: .continuous))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Fills in what the file left out")
    }
}

// MARK: - Previews

#Preview("Needs a detail") {
    let rows = [
        IntakePlayer(firstName: "Priya", lastName: "Nandan", age: nil, gender: .f),
        IntakePlayer(firstName: "Sam", lastName: "Okafor", age: 12, gender: nil),
        IntakePlayer(firstName: "Rafe", lastName: "Osei", age: 25, gender: .m),
    ]

    return ScrollView {
        NeedsDetailSection(rows: rows, onFix: { _ in })
            .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
}
