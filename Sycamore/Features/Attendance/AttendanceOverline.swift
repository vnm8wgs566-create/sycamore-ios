//
//  AttendanceOverline.swift
//  Sycamore
//
//  The design's `STILL TO MARK · 2`, with an optional trailing action.
//
//  Drawn here rather than with `SectionHeader` for two reasons. That component sets its label in
//  `.sectionHeader` (`700 11`, `+.1em`), which is stage 1's overline; section 8 draws its own at
//  `600 10.5`, `+.14em` — lighter, smaller, wider. And its trailing action is a bare `Text` in a
//  plain button, about 15pt tall. Everywhere else in the app that is a once-a-day tap; here it is
//  `Undo last`, reached by somebody who has just mis-tapped, and on this screen it has to clear
//  44pt like everything else.
//

import SwiftUI

struct AttendanceOverline: View {

    let title: String
    /// Omitted where the design writes the label alone ("RESULTS", "NEW PICK-UP").
    var count: Int?
    var actionTitle: String?
    var action: (() -> Void)?
    /// `#8A8E96` for a section, `accent` for the green overline on `8n`'s new-pick-up card.
    var color: Color = Theme.inkMuted
    /// 4pt on a screen, where the overline labels a card that is itself inset; 0 inside a sheet,
    /// whose blocks sit flush against the 18pt gutter.
    var inset: CGFloat = OnTheDayTokens.overlineInset

    private var label: String {
        count.map { "\(title) · \($0)" } ?? title
    }

    var body: some View {
        // Centred rather than baseline-aligned, which is what `SectionHeader` uses: the action's
        // 44pt frame is taller than the overline, and a shared baseline would hang the label off
        // the top of the row.
        HStack(spacing: Spacing.tight) {
            Text(label)
                .typeStyle(.onTheDayOverline, color: color)
                // The count is part of the heading, so it is read with it rather than as a
                // second element — "still to mark, 2" and not "still to mark" then "· 2".
                .accessibilityAddTraits(.isHeader)

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
        .padding(.horizontal, inset)
        // The design's `gap:9px`. The action button's own 44pt frame already carries more than
        // that when there is one, so the padding steps aside rather than adding to it.
        .padding(.bottom, actionTitle == nil ? OnTheDayTokens.contentGap : 0)
    }
}

// MARK: - Previews

#Preview("Overline") {
    VStack(alignment: .leading, spacing: 0) {
        AttendanceOverline(title: "Still to mark", count: 2)
        AttendanceOverline(title: "Marked", count: 20, actionTitle: "Undo last") {}
        AttendanceOverline(title: "New pick-up", color: Theme.accent)
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
