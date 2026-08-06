//
//  InboxOverline.swift
//  Sycamore
//
//  "NEEDS YOU · 2", "THIS MORNING", "YESTERDAY".
//
//  Not the shared `SectionHeader`, which is drawn from `Sycamore Flow`'s `700 11 / +.1em`.
//  Section 8 sets its headings a half-point smaller, a weight lighter and appreciably wider
//  (`600 10.5 / +.14em`), and the difference is legible when the two sit on the same screen.
//  A `SectionHeader(style:)` parameter is the hoist candidate — see the pull request.
//

import SwiftUI

struct InboxOverline: View {

    let title: String
    /// `8h`'s "CLEARED TODAY" is tracked a hair wider than `8r`'s three and inset a point more.
    var isCleared = false

    init(_ title: String, isCleared: Bool = false) {
        self.title = title
        self.isCleared = isCleared
    }

    var body: some View {
        Text(title)
            .typeStyle(isCleared ? InboxType.clearedOverline : InboxType.overline, color: Theme.inkMuted)
            .padding(.horizontal, isCleared ? InboxMetrics.clearedOverlineInset : InboxMetrics.overlineInset)
            .padding(.bottom, isCleared ? InboxMetrics.clearedOverlineBottom : InboxMetrics.overlineBottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            // So the rotor can jump between "Needs you" and the morning rather than walking
            // every row to find where one section ends.
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Previews

#Preview("Overlines") {
    VStack(alignment: .leading, spacing: 0) {
        InboxOverline("Needs you · 2")
        InboxOverline("This morning")
        InboxOverline("Cleared today · 4", isCleared: true)
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}
