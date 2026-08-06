//
//  InboxBody.swift
//  Sycamore
//
//  Everything below the Inbox's header rule, in the order `8r` and `8h` stack it.
//
//  The two screens are one view because they are one screen in two states, and the state can
//  change under the reader's thumb: answering the second ask turns `8r` into `8h` without a
//  navigation of any kind.
//

import SwiftUI

struct InboxBody: View {

    let contents: InboxContents
    /// Only so the filtered-empty state can name the chip it is empty under.
    let filter: InboxFilter
    let onResolve: (InboxItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "All clear." is a statement about what is waiting on *you*, so it appears the
            // moment the last `needsAction` row is dealt with rather than only when the whole
            // relation empties. The morning stays underneath it: approving a court move does
            // not un-happen the rest of the day.
            if contents.isAllClear {
                InboxAllClearCard()
                    .padding(.bottom, InboxMetrics.allClearGap)

                if !contents.cleared.isEmpty {
                    InboxClearedList(items: contents.cleared)
                        .padding(.bottom, InboxMetrics.sectionGap)
                }
            }

            InboxList(needsYou: contents.needsYou, feed: contents.feed, onResolve: onResolve)

            if contents.isNarrowedToNothing {
                InboxNarrowedState(filter: filter, waitingCount: contents.openNeedsAction.count)
                    .padding(.vertical, Spacing.section)
            }
        }
        // Resolving an item moves it out of "Needs you" and into "Cleared today", and the
        // sections above and below it close up. Animated, that reads as one motion; unanimated
        // the whole screen jumps. A chip change moves the same pieces, so both ride the one
        // value. `reduceMotion` turns it off rather than shortening it — a reader who asked for
        // less motion is not asking for faster motion.
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: contents)
    }
}

// MARK: - Previews

#Preview("Inbox body") {
    let contents = InboxContents(items: InboxPreviewItems.morning(venueID: UUID()), filter: .all)

    return ScrollView {
        InboxBody(contents: contents, filter: .all) { _ in }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
}
