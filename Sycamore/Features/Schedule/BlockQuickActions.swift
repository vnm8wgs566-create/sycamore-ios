//
//  BlockQuickActions.swift
//  Sycamore
//
//  "All courts · None", "All coaches · None" — the two shortcuts over a multi-select card.
//
//  One type for two pickers, because they are the same control drawn twice. A camp with eight
//  courts and eleven coaches is sixteen taps away from "the whole venue is on this block", which
//  is the single commonest thing anybody wants to say about a warm-up; and clearing a selection
//  by hand is the same count again.
//
//  ── A row of the card, not a header ───────────────────────────────────────────────────────────
//
//  It sits *inside* the `Card`, as its first row, so `Card`'s own divider draws the rule under it
//  (`Components.swift:118-120` — "between rows, never above the first"). The alternative was a
//  pair of buttons alongside the `SheetSectionHeader` above, which would have made two of the
//  editor's five section headings 44pt tall and the other three not, for no reason a reader could
//  see. Inside the card it also reads as what it is: a row that acts on the rows beneath it.
//
//  Deliberately never disabled. "All courts" on a block that already has all of them is a no-op
//  rather than a mistake, and a control that greys out as you approach it is a control that
//  answers a question nobody asked — the ticks below already say what is selected.
//

import SwiftUI

struct BlockQuickActions: View {

    /// "All courts", "All coaches" — the whole pool.
    let allTitle: String
    /// "No courts", "No coaches". Spelled in full rather than as "None", because the two buttons
    /// are read as a pair and "All coaches · None" leaves the second one to be worked out from
    /// the first — and because VoiceOver reads them one at a time, where "None" says nothing.
    let noneTitle: String
    let onAll: () -> Void
    let onNone: () -> Void

    var body: some View {
        CardRow(spacing: Spacing.large, verticalPadding: Spacing.small) {
            action(allTitle, hint: "Selects every one of them", run: onAll)
            action(noneTitle, hint: "Clears the selection", run: onNone)
            Spacer(minLength: 0)
        }
    }

    /// `inlineAction` is the design's own word-as-a-button — "Reassign", "Copy Monday instead" —
    /// so these read as the same kind of thing rather than as a third button style.
    ///
    /// The frame reaches 44 and the `contentShape` follows it, in that order: reversed, the added
    /// height would be inert and the target would stay the height of a 12.5pt word. `Chip` states
    /// the same rule at `Components.swift:374-379`, where it was learned the hard way.
    private func action(_ title: String, hint: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .typeStyle(ScheduleType.inlineAction, color: Theme.accent)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

// MARK: - Previews

#Preview("Quick actions") {
    Card(radius: ScheduleMetrics.cardRadius) {
        BlockQuickActions(allTitle: "All courts", noneTitle: "No courts", onAll: {}, onNone: {})
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            Text("Court 1")
                .typeStyle(ScheduleType.assigneeName, color: Theme.ink)
        }
    }
    .padding(Spacing.gutter)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
