//
//  IntakePillButton.swift
//  Sycamore
//
//  `8c`'s two file buttons: `10/16` on a capsule, `600 13.5`.
//
//  Not `DesignSystem/Pill`, which draws its outline in `hairline` where the design uses `stroke`,
//  and sets its label in `700 12.5`.
//

import SwiftUI

struct IntakePillButton: View {

    let title: String
    /// The green one. The other is white with a grey border.
    var isProminent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .typeStyle(.intakePill, color: isProminent ? Theme.onAccent : Theme.inkSecondary)
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, 10)
                .background(isProminent ? Theme.accent : Theme.surface, in: Capsule(style: .continuous))
                .overlay {
                    if !isProminent {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: BorderWidth.hairline)
                    }
                }
                // Drawn 37pt tall; the capsule is already wide enough.
                .padding(.vertical, 3.5)
                .contentShape(.rect)
                .padding(.vertical, -3.5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("File pills") {
    HStack(spacing: Spacing.small) {
        IntakePillButton(title: "Choose a file", isProminent: true) {}
        IntakePillButton(title: "From email") {}
    }
    .padding(Spacing.gutter)
    .background(Theme.surface)
}
