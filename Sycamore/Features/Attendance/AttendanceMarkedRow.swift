//
//  AttendanceMarkedRow.swift
//  Sycamore
//
//  A kid who has been answered: quieter than the card above, with the answer on the right.
//
//  The design draws these as plain rows. They are buttons here, and tapping one flips the
//  answer. `Undo last` only reaches the most recent tap, and the mistake this screen actually
//  produces is a mis-tap noticed four kids later — at which point the only way back through the
//  design's affordance is to undo four correct answers to reach the wrong one.
//

import SwiftUI

struct AttendanceMarkedRow: View {

    let entry: AttendanceEntry
    /// Flips the answer: here becomes away, away becomes here.
    let onFlip: () -> Void

    var body: some View {
        Button(action: onFlip) {
            HStack(spacing: Spacing.row) {
                Text("\(entry.rank)")
                    .typeStyle(.rankNumeral.weight(.regular), color: Theme.chevron)
                    .frame(width: OnTheDayTokens.rankColumn, alignment: .trailing)

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    // `.bodyAlt` is the design's 14pt copy style; its 1.5 line height belongs to
                    // paragraphs and only pads a one-line row, so it is dropped here.
                    Text(entry.name)
                        .typeStyle(.bodyAlt.weight(.regular).lineHeight(nil), color: Theme.inkSecondary)
                        .lineLimit(1)

                    if let pickupLine = entry.pickupLine {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .regular))
                            Text(pickupLine)
                                .typeStyle(.rowSubtitleSmall)
                                .lineLimit(1)
                        }
                        .foregroundStyle(OnTheDayTokens.warning)
                    }
                }

                Spacer(minLength: 0)

                answer
            }
            .padding(.horizontal, OnTheDayTokens.cardInset)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.name)
        .accessibilityValue(entry.isAway ? "Away" : "Here")
        .accessibilityHint(entry.isAway ? "Marks them here instead" : "Marks them away instead")
    }

    @ViewBuilder
    private var answer: some View {
        if entry.isAway {
            Text("Away")
                .typeStyle(.metaSmall, color: Theme.inkFaint)
        } else {
            Circle()
                .fill(Theme.accent)
                .frame(width: OnTheDayTokens.markDiameter, height: OnTheDayTokens.markDiameter)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                }
        }
    }
}

// MARK: - Previews

#Preview("Marked rows") {
    Card(radius: OnTheDayTokens.card) {
        AttendanceMarkedRow(
            entry: AttendanceEntry(
                id: SampleData.sereneC.id, name: "Serene C", rank: 1,
                courtLabel: nil, isAway: false, leavesAt: TimeOfDay(14, 30)
            ),
            onFlip: {}
        )
        AttendanceMarkedRow(
            entry: AttendanceEntry(
                id: SampleData.austinZ.id, name: "Liam P", rank: 2,
                courtLabel: nil, isAway: false, leavesAt: nil
            ),
            onFlip: {}
        )
        AttendanceMarkedRow(
            entry: AttendanceEntry(
                id: SampleData.liamJ.id, name: "Mia K", rank: 4,
                courtLabel: nil, isAway: true, leavesAt: nil
            ),
            onFlip: {}
        )
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.grouped)
}
