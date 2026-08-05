//
//  InboxList.swift
//  Sycamore
//
//  `8r`'s body — "Needs you first, then the morning."
//
//  Two kinds of section stacked in that order, and the order is the argument the screen is
//  making: the things that are still somebody's problem sit above the things that are already
//  history, however recent the history is.
//

import SwiftUI

struct InboxList: View {

    /// Unresolved `needsAction` rows. Empty hides the section outright — an empty
    /// "Needs you · 0" heading is the sort of thing that makes a person check twice.
    let needsYou: [InboxItem]
    /// Everything else, already bucketed by day.
    let feed: [InboxSection]
    let onResolve: (InboxItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !needsYou.isEmpty {
                SectionHeader("Needs you · \(needsYou.count)")
                Card {
                    ForEach(needsYou) { item in
                        InboxNeedsActionRow(item: item) { onResolve(item) }
                    }
                }
                .padding(.bottom, Spacing.large)
            }

            ForEach(feed) { section in
                SectionHeader(section.title)
                Card {
                    ForEach(section.items) { item in
                        InboxActivityRow(item: item)
                    }
                }
                .padding(.bottom, Spacing.large)
            }
        }
    }
}

// MARK: - Previews

#Preview("Inbox list") {
    let items = InboxPreviewItems.morning(venueID: UUID())
    let contents = InboxContents(items: items, filter: .all)

    return ScrollView {
        InboxList(needsYou: contents.needsYou, feed: contents.feed) { _ in }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.grouped)
}
