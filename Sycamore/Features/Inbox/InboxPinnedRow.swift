//
//  InboxPinnedRow.swift
//  Sycamore
//
//  A row in the pinned section at the top of the Inbox.
//
//  Shaped like a feed row — the same tile, the same two lines — because it is one: a pinned
//  message is an ordinary `inbox_items` row wearing `pinned`, not a separate kind of thing. What
//  differs is the ending. A feed row closes with a caret it does not yet use; this one closes
//  with the `⋯` an admin takes the pin back down from, and with nothing at all for everybody
//  else.
//

import SwiftUI

struct InboxPinnedRow: View {

    let item: InboxItem
    /// Admin-only, and courtesy only — see `InboxPinnedList`. A coach sees the row and no menu.
    var canUnpin: Bool
    let onUnpin: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// The `⋯` grows with the reader's text size, for the reason `InboxIconTile` gives about its
    /// own plate: an affordance that stays 17pt beside a title set at `.accessibility1` reads as
    /// punctuation rather than as a control. The 44pt frame around it does not move — that is a
    /// floor, not a size.
    @ScaledMetric(relativeTo: .body) private var menuGlyph: CGFloat = InboxMetrics.rowMenu

    var body: some View {
        CardRow(verticalPadding: InboxMetrics.rowPaddingV) {
            InboxIconTile(for: item)

            VStack(alignment: .leading, spacing: InboxMetrics.titleGap) {
                Text(item.title)
                    .typeStyle(InboxType.rowTitle, color: Theme.ink)
                    // A pinned message is a whole sentence rather than a headline — the composer
                    // writes the reader's words straight into `title` — so it wraps where a feed
                    // row's title does not. Two lines is the design's own banner shape on
                    // Overview given room to breathe; past that it is a note, not a pin.
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = item.detail {
                    Text(detail)
                        .typeStyle(InboxType.rowDetail, color: Theme.inkMuted)
                        // As the feed rows: one line, except at the accessibility sizes where one
                        // line is four words and truncating is the same as deleting.
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if canUnpin { unpinMenu }
        }
        // One element per row, as everywhere else on this screen. The menu is hidden from
        // VoiceOver and re-offered below as a named action instead: left visible it became a
        // second element called "Pinned message options", and with three pins on screen the rotor
        // offered three of them with no way to tell which was which — the same failure
        // `InboxNeedsActionRow` describes of its "Review" buttons.
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if canUnpin {
                Button("Unpin", action: onUnpin)
            }
        }
    }

    /// The design's `⋯`, as `BlockDetailView` already spells it.
    ///
    /// Deliberately not a swipe. `.swipeActions` exists only on a `List` row and the Inbox is a
    /// `ScrollView` of `Card`s — nothing in this app is a `List` — so a swipe here would be a
    /// hand-rolled drag gesture competing with the scroll view for the same finger, undiscoverable
    /// and unavailable to VoiceOver without the named action above anyway. The `⋯` is already this
    /// codebase's answer to "this row has a write on it", and it is visible rather than hidden.
    private var unpinMenu: some View {
        Menu {
            // Not `role: .destructive`. Unpinning takes the row out of this section and leaves it
            // in the feed exactly where it was — `setPinned` is separate from `resolveInboxItem`
            // precisely because the two say different things — and a red verb would promise a
            // deletion that does not happen.
            Button("Unpin", action: onUnpin)
        } label: {
            DisclosureChevron(
                systemName: "ellipsis",
                size: menuGlyph,
                color: Theme.inkSecondary
            )
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Pinned rows") {
    let venueID = UUID()

    return VStack(spacing: Spacing.large) {
        Card(radius: InboxMetrics.cardRadius) {
            InboxPinnedRow(
                item: InboxItem(
                    venueID: venueID, kind: .note,
                    title: "Court 4 net is loose — keep the little ones off it.",
                    actorID: UUID(), pinned: true
                ),
                canUnpin: true
            ) {}

            InboxPinnedRow(
                item: InboxItem(
                    venueID: venueID, kind: .note,
                    title: "Nass pinned a note",
                    detail: "Skills rotation · net on 4 is loose",
                    actorID: UUID(), pinned: true
                ),
                canUnpin: true
            ) {}
        }

        // What a coach sees: the same rows, no menu.
        Card(radius: InboxMetrics.cardRadius) {
            InboxPinnedRow(
                item: InboxItem(
                    venueID: venueID, kind: .note,
                    title: "Shade tent is up on the lawn.",
                    actorID: UUID(), pinned: true
                ),
                canUnpin: false
            ) {}
        }
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}
