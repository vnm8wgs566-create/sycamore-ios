//
//  BlockNotesCard.swift
//  Sycamore
//
//  The last row on `8l` — "3 notes on this block".
//
//  The design puts a caret on that row, so the notes are behind a tap. They expand in place
//  rather than pushing a screen: three lines of text do not need one, and section 8 draws no
//  notes screen to push to.
//

import SwiftUI

struct BlockNotesCard: View {

    let notes: [String]
    /// "3 notes on this block" — spelled by the block, so the card and the block agree on the
    /// plural.
    let label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                Button(action: toggle) {
                    CardRow(spacing: ScheduleMetrics.rowGap,
                            horizontalPadding: ScheduleMetrics.cardPadding) {
                        DisclosureChevron(systemName: "note.text", size: 16, color: Theme.inkFaint)
                            .accessibilityHidden(true)

                        Text(label)
                            .typeStyle(ScheduleType.notesRow, color: Theme.inkWarm)

                        Spacer(minLength: Spacing.small)

                        DisclosureChevron(size: 15)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: HitTarget.minimum)
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Hides the notes" : "Shows the notes")

                if isExpanded {
                    // Indices, not the notes themselves: two coaches can write the same line,
                    // and identical strings would collapse into one row.
                    ForEach(notes.indices, id: \.self) { index in
                        Hairline(color: Theme.hairlineSoft)

                        CardRow(spacing: Spacing.row,
                                horizontalPadding: ScheduleMetrics.cardPadding,
                                verticalPadding: Spacing.medium,
                                alignment: .top) {
                            Text(notes[index])
                                .typeStyle(ScheduleType.noteLine, color: Theme.inkTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { isExpanded.toggle() }
    }
}

// MARK: - Previews

#Preview("Notes") {
    let block = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)[1]

    return BlockNotesCard(notes: block.notes, label: block.notesRowLabel)
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}
