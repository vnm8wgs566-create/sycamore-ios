//
//  AttendanceOverline.swift
//  Sycamore
//
//  The design's `STILL TO MARK · 2`, with an optional trailing action.
//
//  Drawn here rather than with `SectionHeader` for one reason: that component's trailing action is
//  a bare `Text` in a plain button, about 15pt tall. Everywhere else in the app that is a
//  once-a-day tap; here it is `Undo last`, reached by somebody who has just mis-tapped, and on
//  this screen it has to clear 44pt like everything else.
//

import SwiftUI

struct AttendanceOverline: View {

    let title: String
    let count: Int
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        // Centred rather than baseline-aligned, which is what `SectionHeader` uses: the action's
        // 44pt frame is taller than the overline, and a shared baseline would hang the label off
        // the top of the row.
        HStack(spacing: Spacing.tight) {
            Text("\(title) · \(count)")
                .typeStyle(.sectionHeader, color: Theme.inkMuted)

            Spacer(minLength: Spacing.small)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .typeStyle(.metaStrong, color: Theme.accent)
                        .frame(minHeight: HitTarget.minimum)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, OnTheDayTokens.overlineInset)
        // The action button's 44pt frame already supplies the gap when there is one.
        .padding(.bottom, actionTitle == nil ? Spacing.small : 0)
    }
}

// MARK: - Previews

#Preview("Overline") {
    VStack(alignment: .leading, spacing: Spacing.large) {
        AttendanceOverline(title: "Still to mark", count: 2)
        AttendanceOverline(title: "Marked", count: 20, actionTitle: "Undo last") {}
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.grouped)
}
