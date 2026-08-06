//
//  InboxMoreRow.swift
//  Sycamore
//
//  "2 more" — the row that closes `8h`'s cleared card.
//
//  `background:#FAFBFA`, one step up from the card it sits in, so it reads as a control rather
//  than as a fifth cleared item.
//
//  The design draws only the collapsed half of this; there is no picture of the expanded list
//  and so none of the way back from it. "Show less" is invented, and deliberately the same row
//  with its caret turned over rather than a second control somewhere else.
//

import SwiftUI

struct InboxMoreRow: View {

    @Binding var isExpanded: Bool
    /// How many rows are still folded away. Zero while expanded.
    let hiddenCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: InboxMetrics.moreSpacing) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: InboxMetrics.moreCaret, weight: .medium))
                Text(isExpanded ? "Show less" : "\(hiddenCount) more")
                    .typeStyle(InboxType.moreLabel)
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, InboxMetrics.morePaddingV)
            .padding(.horizontal, InboxMetrics.rowPaddingH)
            .frame(minHeight: HitTarget.minimum)
            .background(Theme.surfaceRaised)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // "2 more" is a fragment. Spoken on its own, after two rows about children, it is not
        // obvious what there are two more of.
        .accessibilityLabel(
            isExpanded
                ? Text("Show fewer cleared items")
                : Text("Show ^[\(hiddenCount) more cleared item](inflect: true)")
        )
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { isExpanded.toggle() }
    }
}

// MARK: - Previews

#if DEBUG
private struct InboxMoreRowPreview: View {
    @State private var isExpanded = false

    var body: some View {
        Card(radius: InboxMetrics.cardRadius) {
            InboxMoreRow(isExpanded: $isExpanded, hiddenCount: isExpanded ? 0 : 2)
        }
        .padding(Spacing.gutter)
        .background(Theme.surfaceWarm)
    }
}
#endif

#Preview("More row") {
    InboxMoreRowPreview()
}
