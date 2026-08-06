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
                    // `#3F4A44`, not `ink` and not `inkSecondary`. An answered name steps down
                    // from the near-black of the card above, and the step the design takes is
                    // warm rather than merely lighter — the brand's green showing through the
                    // type. Rendering it in a neutral grey is the colder reading of the same
                    // value, and it is the single most repeated text on the screen.
                    Text(entry.name)
                        .typeStyle(.onTheDayRowName, color: Theme.inkWarm)
                        .lineLimit(1)

                    if let pickupLine = entry.pickupLine {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .regular))
                            Text(pickupLine)
                                .typeStyle(.onTheDayFootnote)
                                .lineLimit(1)
                        }
                        .foregroundStyle(OnTheDayTokens.warning)
                    }
                }

                Spacer(minLength: 0)

                answer
            }
            .padding(.horizontal, OnTheDayTokens.cardInset)
            .padding(.vertical, OnTheDayTokens.rowInset)
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.name)
        // The pick-up rides in the value rather than the label, so VoiceOver reads the kid, then
        // their answer, then the catch — which is the order the row is drawn in.
        .accessibilityValue(
            [entry.isAway ? "Away" : "Here", entry.pickupLine]
                .compactMap { $0 }
                .joined(separator: ". ")
        )
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
                        .font(.system(size: 13, weight: .bold))
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
    .background(Theme.surfaceWarm)
}
