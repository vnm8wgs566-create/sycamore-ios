//
//  InboxClearedList.swift
//  Sycamore
//
//  "CLEARED TODAY · 4" and the rows under it — the second half of `8h`.
//
//  This is what stops an empty inbox reading as a broken one: a morning you have worked through
//  should be able to show its work. The design draws four cleared items as two rows and a
//  "2 more", which is the right default — the list is reassurance, not reading.
//

import SwiftUI

struct InboxClearedList: View {

    /// Newest first. The caller has already ordered them.
    let items: [InboxItem]

    @State private var isExpanded = false

    private var shown: ArraySlice<InboxItem> {
        isExpanded ? items[...] : items.prefix(InboxMetrics.clearedCollapsedCount)
    }

    private var hiddenCount: Int { items.count - shown.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InboxOverline("Cleared today · \(items.count)", isCleared: true)

            Card(radius: InboxMetrics.cardRadius) {
                ForEach(shown) { item in
                    InboxActivityRow(item: item, isCleared: true)
                }

                if hiddenCount > 0 || isExpanded {
                    InboxMoreRow(isExpanded: $isExpanded, hiddenCount: hiddenCount)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Cleared today") {
    let venueID = UUID()
    let titles = ["Austin Z moved to Court 2", "Liam J marked away",
                  "Nass pinned a note", "Rank order published"]
    let details = ["9:38 · you approved", "8:52 · by you",
                   "8:40 · by Nass", "8:05 · by Nass"]
    let items = titles.indices.map { index in
        InboxItem(
            venueID: venueID, kind: .activity,
            title: titles[index], detail: details[index],
            actorID: UUID(), playerID: index < 2 ? UUID() : nil,
            resolved: true,
            createdAt: .now.addingTimeInterval(Double(-index) * 900)
        )
    }

    return ScrollView {
        InboxClearedList(items: items)
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
}
