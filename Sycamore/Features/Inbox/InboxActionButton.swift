//
//  InboxActionButton.swift
//  Sycamore
//
//  "Review" / "Assign" — the only control on `8r`.
//
//  Not a `Pill`: the design fills this one with `accentTint` under an `accent` label and draws
//  no border at all, and `ButtonTone` has no such case. Adding one would mean editing the
//  shared component file every other section-8 screen is also editing.
//

import SwiftUI

struct InboxActionButton: View {

    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .typeStyle(.chipSmall, color: Theme.accent)
                .lineLimit(1)
                .padding(.horizontal, InboxMetrics.actionPaddingH)
                .padding(.vertical, InboxMetrics.actionPaddingV)
                .background(Theme.accentTint, in: Capsule(style: .continuous))
                // The capsule keeps the size the design draws it at — about 29pt tall — and
                // the frame outside it carries the tap.
                //
                // This does make a needs-action row taller than the design's 58pt, because a
                // 29pt target is not one. The alternative, stretching the hit region to the
                // row instead, tops out at the 34pt of the icon tile and is still short.
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Action button") {
    HStack(spacing: Spacing.small) {
        InboxActionButton("Review") {}
        InboxActionButton("Assign") {}
    }
    .padding(Spacing.section)
    .background(Theme.surface)
}
