//
//  InboxNeedsActionRow.swift
//  Sycamore
//
//  A row under "Needs you · 2" — the two things on `8r` that are waiting on a decision.
//
//  The only row in the app that ends in a button rather than a caret. That is the whole point
//  of the section: everything below it is the morning as it happened, and these two are the
//  morning as it has not happened yet.
//

import SwiftUI

struct InboxNeedsActionRow: View {

    let item: InboxItem
    let onResolve: () -> Void

    var body: some View {
        CardRow(verticalPadding: Spacing.medium) {
            InboxIconTile(for: item)

            VStack(alignment: .leading, spacing: InboxMetrics.titleGap) {
                Text(item.title)
                    .typeStyle(.rowLabel, color: Theme.ink)

                if let detail {
                    Text(detail)
                        .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                        // `white-space:nowrap;text-overflow:ellipsis` — a long note must not
                        // push the button off the row.
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if let actionLabel = item.actionLabel {
                InboxActionButton(actionLabel, action: onResolve)
                    // Two rows, two buttons, both a single verb. Naming what is being reviewed
                    // is the difference between a usable rotor and a coin toss.
                    .accessibilityLabel("\(actionLabel): \(item.title)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The grey second line.
    ///
    /// The design writes one of these two rows as "Nass asked · 8 min ago" and the other as
    /// "10:45 match play · unassigned". The difference is whether a person is waiting: an ask
    /// names who asked, so it says how long they have been waiting for an answer; a court short
    /// of a coach has nobody's name on it and says what the gap is instead.
    ///
    /// The age is formatted from `createdAt` every time it is drawn, never stored. "8 min ago"
    /// written into a column is wrong a minute later.
    private var detail: String? {
        guard item.actorID != nil else { return item.detail }
        guard let stem = item.detail else { return age }
        return "\(stem) · \(age)"
    }

    private var age: String {
        item.createdAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}

// MARK: - Previews

#Preview("Needs-action rows") {
    let venueID = UUID()

    return VStack {
        Card {
            InboxNeedsActionRow(
                item: InboxItem(
                    venueID: venueID,
                    kind: .needsAction,
                    title: "Austin Zheng → Court 2",
                    detail: "Nass asked",
                    actionLabel: "Review",
                    actorID: UUID(),
                    playerID: UUID(),
                    createdAt: .now.addingTimeInterval(-8 * 60)
                )
            ) {}

            InboxNeedsActionRow(
                item: InboxItem(
                    venueID: venueID,
                    kind: .needsAction,
                    title: "LATC is 2 coaches short",
                    detail: "10:45 match play · unassigned",
                    actionLabel: "Assign",
                    createdAt: .now.addingTimeInterval(-40 * 60)
                )
            ) {}
        }
        .padding(Spacing.gutter)
    }
    .background(Theme.grouped)
}
