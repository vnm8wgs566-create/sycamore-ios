//
//  InboxActivityRow.swift
//  Sycamore
//
//  A row in the feed — "This morning", "Yesterday" — and, dimmed, a row on `8h`'s cleared list.
//
//  Read-only by design. Nothing here is waiting on anybody; it is what already happened, newest
//  first, so a coach walking in at 9:40 can catch up on the forty minutes they missed.
//
//  The two states are one view because they are one row, but the design does not merely fade
//  the live one: a cleared row is tighter (11pt of padding, not 12), its title is half a point
//  smaller, its detail line a full point, and the gap between them closes from 3 to 2. Fading
//  alone left it noticeably taller than the design draws it.
//

import SwiftUI

struct InboxActivityRow: View {

    let item: InboxItem
    /// `8h` draws its cleared rows at 62% with no caret. Dealt with, still legible.
    var isCleared: Bool = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        CardRow(verticalPadding: isCleared ? InboxMetrics.clearedRowPaddingV : InboxMetrics.rowPaddingV) {
            InboxIconTile(for: item, isCleared: isCleared)

            VStack(alignment: .leading, spacing: isCleared ? InboxMetrics.clearedTitleGap : InboxMetrics.titleGap) {
                Text(item.title)
                    .typeStyle(isCleared ? InboxType.clearedTitle : InboxType.rowTitle, color: Theme.ink)

                if let detail = item.detail {
                    Text(detail)
                        .typeStyle(
                            isCleared ? InboxType.clearedDetail : InboxType.rowDetail,
                            color: isCleared ? Theme.inkFaint : Theme.inkMuted
                        )
                        // `white-space:nowrap`, except at the accessibility sizes, where one
                        // line is four words and truncating is the same as deleting.
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isCleared {
                // Drawn, not wired. The design closes every feed row with a caret and the item
                // detail screen is not part of this unit, so the row is deliberately not a
                // button — a control that swallows a tap and does nothing is worse than a row
                // that never claimed to be one.
                DisclosureChevron(size: InboxMetrics.caret)
                    .accessibilityHidden(true)
            }
        }
        .opacity(isCleared ? InboxMetrics.clearedOpacity : 1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Feed rows") {
    let venueID = UUID()

    return VStack(spacing: Spacing.large) {
        Card(radius: InboxMetrics.cardRadius) {
            InboxActivityRow(
                item: InboxItem(
                    venueID: venueID, kind: .note,
                    title: "Nass pinned a note",
                    detail: "Skills rotation · net on 4 is loose",
                    actorID: UUID()
                )
            )
            InboxActivityRow(
                item: InboxItem(
                    venueID: venueID, kind: .activity,
                    title: "Serene Chu leaves at 2:30",
                    detail: "Mum collects at the gate · today",
                    playerID: UUID()
                )
            )
            InboxActivityRow(
                item: InboxItem(
                    venueID: venueID, kind: .note,
                    title: "Hubert · Court 2",
                    detail: "Two in sandals, benched until shoes turn up",
                    actorID: UUID(), groupID: UUID()
                )
            )
        }

        Card(radius: InboxMetrics.cardRadius) {
            InboxActivityRow(
                item: InboxItem(
                    venueID: venueID, kind: .activity,
                    title: "Austin Z moved to Court 2",
                    detail: "9:38 · you approved",
                    actorID: UUID(), playerID: UUID(), resolved: true
                ),
                isCleared: true
            )
        }
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}
