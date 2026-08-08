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

    /// The rows an admin has pinned, held at the top of the screen until one takes them down.
    ///
    /// Read off `InboxItem.pinned` — the stored flag — rather than guessed from the shape of the
    /// row. Two places used to guess, and they disagreed with each other: Overview bannered "the
    /// newest unresolved note", and the Inbox drew its green pin for "a note against no court",
    /// which meant attaching a note to a court silently un-pinned it.
    ///
    /// Filtered by the chips like everything else. A pinned message is a `note`, so it shows
    /// under All and under Notes and hides under Needs you — which is what a reader asking for
    /// "only the things waiting on me" means. The alternative, exempting the section as a
    /// masthead the chips cannot touch, was rejected: the chips sit directly above it, and a chip
    /// that visibly does nothing to the first thing under it is worse than one that hides a pin.
    let pinned: [InboxItem]

    /// Still waiting on a decision, *whatever the chips say and whether or not it is pinned*.
    ///
    /// The all-clear state keys off this rather than off either filtered list: narrowing to Notes
    /// must not let the screen announce that nothing is waiting on you while two things are, and
    /// neither must lifting an ask to the top of the screen. `setPinned` will pin any row it is
    /// given, so a pinned `needsAction` is a state the data layer can reach even though this
    /// screen never offers it.
    let openNeedsAction: [InboxItem]

    /// The rows under "Needs you · N" — `openNeedsAction` as the current chip allows, less
    /// anything the pinned section has already drawn.
    ///
    /// The heading counts what is under it, so the count and the rows cannot disagree. The
    /// honest total of what is waiting on you is `openNeedsAction`, and that is what the header
    /// line and the all-clear state read.
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
        var pinnedItems: [InboxItem] = []
        var open: [InboxItem] = []
        var feedItems: [InboxItem] = []
        var clearedItems: [InboxItem] = []

        // One walk, four destinations. A resolved row leaves the screen it was on entirely and
        // reappears under "Cleared today" — `8r` has no cleared section, and `8h` is nothing but.
        //
        // Pinned is tested before kind, so a pinned row is drawn once and at the top whatever it
        // is. `open` is filled from the same pass regardless, because "is anything waiting on
        // you" is a question about the row and not about where the screen has chosen to put it.
        for item in items {
            if item.resolved {
                clearedItems.append(item)
                continue
            }
            if item.kind == .needsAction { open.append(item) }

            if item.pinned {
                if filter.matches(item) { pinnedItems.append(item) }
            } else if item.kind != .needsAction, filter.matches(item) {
                feedItems.append(item)
            }
        }

        pinned = pinnedItems.newestFirst
        openNeedsAction = open.newestFirst
        needsYou = openNeedsAction.filter { filter.matches($0) && !$0.pinned }
        feed = InboxSection.feed(feedItems, now: now, calendar: calendar)
        cleared = clearedItems.newestFirst
    }

    /// Nothing is waiting on you. Note that the morning may still be full — see `InboxView` —
    /// and so may the pinned section: a standing notice is not a thing waiting on a decision,
    /// which is why the all-clear card and a pin can honestly share a screen. The card's own
    /// sentence already promises "pinned notes all land here".
    var isAllClear: Bool { openNeedsAction.isEmpty }

    /// A chip has narrowed the screen to nothing while something is still waiting under
    /// another one.
    ///
    /// `pinned` counts towards "not nothing". A screen showing one pinned row and no other is
    /// not empty, and telling its reader it is would be the plainest kind of wrong.
    var isNarrowedToNothing: Bool {
        pinned.isEmpty && needsYou.isEmpty && feed.isEmpty && !openNeedsAction.isEmpty
    }

    /// The grey line beside the title.
    ///
    /// `8h` writes "Nothing waiting on you". `8r` writes nothing at all — the "Needs you · 2"
    /// heading a few points below is already the count, and the design does not say it twice.
    var headerSubtitle: String? {
        openNeedsAction.isEmpty ? "Nothing waiting on you" : nil
    }
}
