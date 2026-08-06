//
//  InboxView.swift
//  Sycamore
//
//  `8r` — Inbox, and `8h` — its empty state. "Needs you first, then the morning."
//
//  Two things stacked: the items waiting on a decision, then a reverse-chronological feed of
//  what happened. The filter chips above them are All / Needs you / Notes.
//
//  `8h` is what draws in the shipped app today, because `inbox_items` was created empty. The
//  design's empty state is not a blank page either — it says "All clear." and then shows what
//  was cleared, which is the difference between an inbox that is empty because nothing happened
//  and one that is empty because you dealt with it.
//
//  The rows live on `AppStore`, not here. They were held in this view's `@State` while section
//  8's screens were being written in parallel — a store method added then was a merge conflict
//  for all of them — but a private copy meant a write on one tab could not be seen from another,
//  and resolving an item that reassigns a court has to change what Overview draws.
//

import SwiftUI

struct InboxView: View {

    @Environment(AppStore.self) private var store

    @State private var filter: InboxFilter
    /// Bumped by a successful resolve, so the haptic fires on the tap and not on a load that
    /// happens to arrive with cleared rows already in it.
    @State private var resolveCount = 0

    /// `filter` is a starting point rather than a binding — the chips own it from the first
    /// tap. Only previews pass anything but `.all`.
    init(filter: InboxFilter = .all) {
        _filter = State(initialValue: filter)
    }

    var body: some View {
        // Derived once per pass. Read as four separate computed properties this walked, grouped
        // and sorted the whole morning four times to draw it once.
        let contents = InboxContents(items: store.inboxItems, filter: filter)

        return VStack(spacing: 0) {
            // The design puts the title and the chips on white and the list on the warm grey
            // beneath it, which is what gives the cards an edge to sit against.
            VStack(spacing: 0) {
                StatusBarMock()

                ScreenHeader(
                    title: "Inbox",
                    count: contents.headerSubtitle,
                    initials: store.avatarInitials
                ) {
                    store.pushedScreen = .profile
                }

                InboxFilterChips(selection: $filter)
                    .padding(.horizontal, Spacing.bar)
                    .padding(.bottom, InboxMetrics.chipRowBottom)
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                InboxBody(contents: contents, filter: filter, onResolve: resolve)
                    .padding(.horizontal, Spacing.gutter)
                    // `padding:14px …` on the list plus the `padding-top:2px` its first heading
                    // carries.
                    .padding(.top, Spacing.large)
                    // The floating tab bar reserves no layout space of its own.
                    .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, which all twenty of section 8's screens are drawn on. A warmer grey than
        // `Theme.grouped`, the page colour the earlier sections use.
        .background(Theme.surfaceWarm)
        .task(id: store.readVenueID) { await load() }
        .sensoryFeedback(.success, trigger: resolveCount)
        // No banner of its own. Reads and writes now go through `AppStore.perform`, which owns
        // `errorMessage` and `isWorking` — and `MainTabView` already floats one banner for all
        // four tabs. A second here meant a failure on this tab looked like a different class of
        // problem from the same failure on the next, and set no in-flight state, so section 8's
        // writes had no spinner and no double-tap guard.
    }

    // MARK: Intents

    private func load() async {
        await store.loadInbox()
    }

    /// "Review" / "Assign".
    ///
    /// `resolveInboxItem` answers with the whole list rather than the one row, so the section
    /// counts, the header line and the all-clear state all move together — and a row the store
    /// declined to resolve simply comes back unresolved, instead of disappearing optimistically
    /// and reappearing a moment later.
    private func resolve(_ item: InboxItem) {
        Task {
            let before = store.inboxItems.count(where: { !$0.resolved })
            await store.resolveInboxItem(item.id)
            // Only when the store actually took it. A rejected write leaves the count where it
            // was, and a haptic for something that did not happen is worse than none.
            if store.inboxItems.count(where: { !$0.resolved }) < before { resolveCount += 1 }
        }
    }
}

// MARK: - Previews

#if DEBUG
/// Seeds the repository *before* the screen mounts.
///
/// `InboxView` reads in its own `.task`, so a preview that seeded alongside it would race it
/// and usually lose — the screen would draw `8h` and then never re-read.
private struct InboxPreviewHarness: View {

    var filter: InboxFilter = .all
    /// Resolves both `needsAction` rows first, which is the state `8h` is describing.
    var clearsEverything = false
    /// Seeds the two asks and nothing else, so a chip pointed at the feed lands on nothing
    /// while something is still waiting under another one.
    var asksOnly = false

    @State private var store: AppStore?

    var body: some View {
        // `SwiftUI.` qualified because `Models.swift` declares a domain `Group`.
        SwiftUI.Group {
            if let store {
                InboxView(filter: filter)
                    .environment(store)
            } else {
                Theme.surfaceWarm
            }
        }
        .task { store = await seededStore() }
    }

    private func seededStore() async -> AppStore {
        let store = AppStore.preview
        store.selectedTab = .inbox

        guard let campID = store.camp?.id, let venueID = store.readVenueID else { return store }
        let morning = InboxPreviewItems.morning(venueID: venueID)
        let items = asksOnly ? morning.filter { $0.kind == .needsAction } : morning
        for item in items {
            _ = try? await store.repository.addInboxItem(item, campID: campID)
        }
        if clearsEverything {
            for item in items where item.kind == .needsAction {
                _ = try? await store.repository.resolveInboxItem(item.id, campID: campID)
            }
        }
        return store
    }
}
#endif

#Preview("Inbox — 8r") {
    InboxPreviewHarness()
        .showsMockStatusBar()
}

#Preview("Inbox — needs you") {
    InboxPreviewHarness(filter: .needsYou)
        .showsMockStatusBar()
}

#Preview("Inbox — notes") {
    InboxPreviewHarness(filter: .notes)
        .showsMockStatusBar()
}

/// A chip narrowed to nothing while two things are still waiting under another one.
#Preview("Inbox — filtered to nothing") {
    InboxPreviewHarness(filter: .notes, asksOnly: true)
        .showsMockStatusBar()
}

/// What the shipped app draws: `inbox_items` is empty, so nothing has arrived and nothing has
/// been cleared.
#Preview("Inbox — all clear") {
    InboxView()
        .environment(AppStore.preview)
        .showsMockStatusBar()
}

/// The same screen after both asks have been answered — `8h` with a morning behind it.
#Preview("Inbox — all clear, with history") {
    InboxPreviewHarness(clearsEverything: true)
        .showsMockStatusBar()
}

/// The whole screen at the app's Dynamic Type cap, which is where fixed frames around text
/// give themselves away.
#Preview("Inbox — accessibility1") {
    InboxPreviewHarness()
        .showsMockStatusBar()
        .environment(\.dynamicTypeSize, .accessibility1)
}
