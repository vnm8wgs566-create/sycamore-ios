//
//  InboxContents.swift
//  Sycamore
//
//  Everything `8r` draws, worked out from the loaded rows in one pass.
//
//  A value rather than four computed properties on the view. `body` runs on every state change,
//  and each of those properties walked the whole list again — the screen filtered, grouped and
//  sorted the morning four times over to draw it once. This is also the only part of the Inbox
//  with any logic in it, which makes it the only part worth exercising on its own.
//

import Foundation

/// `Equatable` so the body below it can animate on the whole derivation at once. Resolving an
/// item and changing a chip move the same pieces, and two separate `.animation(_:value:)` passes
/// over the same layout is how one of them ends up half a frame behind the other.
struct InboxContents: Equatable, Sendable {

    /// Still waiting on a decision, *whatever the chips say*.
    ///
    /// The all-clear state keys off this rather than off the filtered list: narrowing to Notes
    /// must not let the screen announce that nothing is waiting on you while two things are.
    let openNeedsAction: [InboxItem]

    /// The rows under "Needs you · N" — `openNeedsAction` as the current chip allows.
    let needsYou: [InboxItem]

    /// Notes and activity, bucketed by day.
    let feed: [InboxSection]

    /// `8h`'s cleared list.
    ///
    /// Ordered by `createdAt`, which is when the item arrived rather than when it was dealt
    /// with — `inbox_items` carries no `resolved_at`, and inventing one on the device would put
    /// a time on the row that no two phones would agree about.
    let cleared: [InboxItem]

    init(
        items: [InboxItem],
        filter: InboxFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        var open: [InboxItem] = []
        var feedItems: [InboxItem] = []
        var clearedItems: [InboxItem] = []

        // One walk, three destinations. A resolved row leaves the screen it was on entirely and
        // reappears under "Cleared today" — `8r` has no cleared section, and `8h` is nothing but.
        for item in items {
            if item.resolved {
                clearedItems.append(item)
            } else if item.kind == .needsAction {
                open.append(item)
            } else if filter.matches(item) {
                feedItems.append(item)
            }
        }

        openNeedsAction = open.newestFirst
        needsYou = openNeedsAction.filter(filter.matches)
        feed = InboxSection.feed(feedItems, now: now, calendar: calendar)
        cleared = clearedItems.newestFirst
    }

    /// Nothing is waiting on you. Note that the morning may still be full — see `InboxView`.
    var isAllClear: Bool { openNeedsAction.isEmpty }

    /// A chip has narrowed the screen to nothing while something is still waiting under
    /// another one.
    var isNarrowedToNothing: Bool {
        needsYou.isEmpty && feed.isEmpty && !openNeedsAction.isEmpty
    }

    /// The grey line beside the title.
    ///
    /// `8h` writes "Nothing waiting on you". `8r` writes nothing at all — the "Needs you · 2"
    /// heading a few points below is already the count, and the design does not say it twice.
    var headerSubtitle: String? {
        openNeedsAction.isEmpty ? "Nothing waiting on you" : nil
    }
}
