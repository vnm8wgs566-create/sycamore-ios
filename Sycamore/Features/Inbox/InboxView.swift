//
//  InboxView.swift
//  Sycamore
//
//  `8r` — Inbox, and `8h` — its empty state. "Needs you first, then the morning."
//
//  Two things stacked: the items waiting on a decision, then a reverse-chronological feed of
//  what happened. The filter chips above them are All / Needs you / Notes.
//
//  `8h` is what draws today, because `inbox_items` was created empty. The design's empty state
//  is not a blank page either — it says "All clear." and then shows what was cleared, which is
//  the difference between an inbox that is empty because nothing happened and one that is empty
//  because you dealt with it.
//

import SwiftUI

struct InboxView: View {

    @Environment(AppStore.self) private var store
    @State private var filter: InboxFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            ScreenHeader(
                title: "Inbox",
                count: "Nothing waiting on you",
                initials: store.avatarInitials
            ) {
                store.pushedScreen = .profile
            }

            filterChips
                .padding(.bottom, 12)

            Hairline(color: Theme.hairline)

            ScrollView {
                allClear
                    .padding(.horizontal, Spacing.bar)
                    .padding(.top, Spacing.section)
                    .padding(.bottom, Spacing.tabBarClearance)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
    }

    // MARK: Filters

    private var filterChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(InboxFilter.allCases) { option in
                Chip(option.title, isSelected: option == filter, metrics: .attribute) {
                    filter = option
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.bar)
    }

    // MARK: Empty state

    private var allClear: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("All clear.")
                .typeStyle(.title2, color: Theme.ink)
                .padding(.bottom, Spacing.section)

            // The cleared list is what stops "empty" reading as "broken". It is drawn from
            // nothing today — `inbox_items` has no rows — so the section is omitted entirely
            // rather than shown with an invented history.
            Text("Cleared today · 0")
                .typeStyle(.sectionHeader, color: Theme.inkMuted)
                .padding(.bottom, Spacing.medium)

            Text("Approvals and notes you have dealt with show up here for the rest of the day.")
                .typeStyle(.body, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview("Inbox — all clear") {
    InboxView()
        .environment(AppStore.preview)
        .showsMockStatusBar()
}
