//
//  InboxFilterChips.swift
//  Sycamore
//
//  All / Needs you / Notes — the row under the Inbox's title.
//

import SwiftUI

struct InboxFilterChips: View {

    @Binding var selection: InboxFilter

    var body: some View {
        HStack(spacing: InboxMetrics.chipGap) {
            ForEach(InboxFilter.allCases) { option in
                InboxFilterChip(option: option, isSelected: option == selection) {
                    selection = option
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#if DEBUG
private struct InboxFilterChipsPreview: View {
    @State private var selection: InboxFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            InboxFilterChips(selection: $selection)
            Text("Showing \(selection.title.lowercased())")
                .typeStyle(InboxType.rowDetail, color: Theme.inkMuted)
        }
        .padding(Spacing.bar)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }
}
#endif

#Preview("Filter chips") {
    InboxFilterChipsPreview()
}
