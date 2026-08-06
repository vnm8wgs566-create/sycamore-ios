//
//  InboxActivityRow.swift
//  Sycamore
//
//  A row in the feed — "This morning", "Yesterday" — and, dimmed, a row on `8h`'s cleared list.
//
//  Read-only by design. Nothing here is waiting on anybody; it is what already happened, newest
//  first, so a coach walking in at 9:40 can catch up on the forty minutes they missed.
//

import SwiftUI

struct InboxActivityRow: View {

    let item: InboxItem
    /// `8h` draws its cleared rows at 62% with no caret. Dealt with, still legible.
    var isCleared: Bool = false

    var body: some View {
        CardRow(verticalPadding: Spacing.medium) {
            InboxIconTile(for: item, isCleared: isCleared)

            VStack(alignment: .leading, spacing: InboxMetrics.titleGap) {
                Text(item.title)
                    .typeStyle(.rowLabel, color: Theme.ink)

                if let detail = item.detail {
                    Text(detail)
                        .typeStyle(.rowSubtitle, color: isCleared ? Theme.inkFaint : Theme.inkMuted)
                        .lineLimit(1)
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
        Card {
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

        Card {
            InboxActivityRow(
                item: InboxItem(
                    venueID: venueID, kind: .activity,
                    title: "Austin Z moved to Court 2",
                    detail: "Nass asked",
                    actorID: UUID(), playerID: UUID(), resolved: true
                ),
                isCleared: true
            )
        }
    }
    .padding(Spacing.gutter)
    .background(Theme.grouped)
}
