//
//  InboxMoreRow.swift
//  Sycamore
//
//  "2 more" — the row that closes `8h`'s cleared card.
//
//  A binding over `MoreRow(metrics: .plate)`, which is where the drawing and the spoken label
//  live now. This screen is the only one of the three folded lists whose state is a `@Binding`
//  rather than a closure, and that is the whole of what is left here: `InboxClearedList` owns
//  `isExpanded` and hands it down, where Groups and Overview pass an action instead.
//
//  `background:#FAFBFA`, one step up from the card it sits in, so it reads as a control rather
//  than as a fifth cleared item — see `MoreRowMetrics.plate`.
//

import SwiftUI

struct InboxMoreRow: View {

    @Binding var isExpanded: Bool
    /// How many rows are still folded away. Zero while expanded.
    let hiddenCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MoreRow(
            hiddenCount: hiddenCount,
            isExpanded: isExpanded,
            noun: "cleared item",
            nounPlural: "cleared items",
            metrics: .plate,
            action: toggle
        )
    }

    private func toggle() {
        withAnimation(MoreRow.animation(reduceMotion: reduceMotion)) { isExpanded.toggle() }
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
