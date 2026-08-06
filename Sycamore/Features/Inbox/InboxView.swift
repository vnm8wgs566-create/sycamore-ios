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
            // The design puts the title and the chips on white and the list on the grey
            // beneath it, which is what gives the cards an edge to sit against.
            VStack(spacing: 0) {
                StatusBarMock()

                ScreenHeader(
                    title: "Inbox",
                    count: contents.headerCount,
                    initials: store.avatarInitials
                ) {
                    store.pushedScreen = .profile
                }

                filterChips
                    .padding(.bottom, Spacing.medium)
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                content(contents)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.large)
                    // The floating tab bar reserves no layout space of its own.
                    .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.grouped)
        .task(id: store.readVenueID) { await load() }
        .sensoryFeedback(.success, trigger: resolveCount)
        // No banner of its own. Reads and writes now go through `AppStore.perform`, which owns
        // `errorMessage` and `isWorking` — and `MainTabView` already floats one banner for all
        // four tabs. A second here meant a failure on this tab looked like a different class of
        // problem from the same failure on the next, and set no in-flight state, so section 8's
        // writes had no spinner and no double-tap guard.
    }

    // MARK: Filters

    private var filterChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(InboxFilter.allCases) { option in
                Chip(option.title, isSelected: option == filter, metrics: .attribute) {
                    filter = option
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.bar)
    }

    // MARK: Body

    private func content(_ contents: InboxContents) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // "All clear." is a statement about what is waiting on *you*, so it appears the
            // moment the last `needsAction` row is dealt with rather than only when the whole
            // relation empties. The morning stays underneath it: approving a court move does
            // not un-happen the rest of the day.
            if contents.isAllClear {
                allClear(contents.cleared)
                    .padding(.bottom, Spacing.section)
            }

            InboxList(needsYou: contents.needsYou, feed: contents.feed, onResolve: resolve)

            if contents.isNarrowedToNothing {
                narrowedToNothing
            }
        }
    }

    // MARK: Empty state

    private func allClear(_ cleared: [InboxItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("All clear.")
                .typeStyle(.title2, color: Theme.ink)
                .padding(.bottom, Spacing.section)

            // The cleared list is what stops "empty" reading as "broken" — an inbox you have
            // worked through should be able to show its work.
            Text("Cleared today · \(cleared.count)")
                .typeStyle(.sectionHeader, color: Theme.inkMuted)
                .padding(.bottom, Spacing.medium)

            if cleared.isEmpty {
                Text("Approvals and notes you have dealt with show up here for the rest of the day.")
                    .typeStyle(.body, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Card {
                    ForEach(cleared) { item in
                        InboxActivityRow(item: item, isCleared: true)
                    }
                }
            }
        }
    }

    /// A chip can narrow the list to nothing while something is still waiting under another
    /// one. Quiet, because the honest answer is "not under this chip", not "nowhere".
    private var narrowedToNothing: some View {
        Text("Nothing under \(filter.title.lowercased()).")
            .typeStyle(.body, color: Theme.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.section)
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
            let before = store.inboxItems.count { !$0.resolved }
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

    @State private var store: AppStore?

    var body: some View {
        // `SwiftUI.` qualified because `Models.swift` declares a domain `Group`.
        SwiftUI.Group {
            if let store {
                InboxView(filter: filter)
                    .environment(store)
            } else {
                Theme.grouped
            }
        }
        .task { store = await seededStore() }
    }

    private func seededStore() async -> AppStore {
        let store = AppStore.preview
        store.selectedTab = .inbox

        guard let campID = store.camp?.id, let venueID = store.readVenueID else { return store }
        let items = InboxPreviewItems.morning(venueID: venueID)
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
