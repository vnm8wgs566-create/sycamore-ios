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
//  The rows are held here in `@State` and read straight off the repository. `AppStore` has no
//  inbox surface yet, and every screen in section 8 is being written at once — a store method
//  added now is a merge conflict for all of them. What it should eventually expose is in the
//  pull request.
//

import SwiftUI

struct InboxView: View {

    @Environment(AppStore.self) private var store

    @State private var items: [InboxItem] = []
    @State private var filter: InboxFilter
    /// Read and write failures. Local rather than `store.errorMessage`: this screen reads a
    /// relation nothing else on the tab bar is waiting on, and the store's banner is shared by
    /// all four tabs.
    @State private var failure: String?
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
        let contents = InboxContents(items: items, filter: filter)

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
        .task(id: store.inboxVenueID) { await load() }
        .sensoryFeedback(.success, trigger: resolveCount)
        .storeErrorBanner(message: failure) { failure = nil }
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
        guard let venueID = store.inboxVenueID, let campID = store.camp?.id else {
            items = []
            return
        }
        do {
            items = try await store.repository.inboxItems(forVenue: venueID, campID: campID)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// "Review" / "Assign".
    ///
    /// `resolveInboxItem` answers with the whole list rather than the one row, so the section
    /// counts, the header line and the all-clear state all move together — and a row the store
    /// declined to resolve simply comes back unresolved, instead of disappearing optimistically
    /// and reappearing a moment later.
    private func resolve(_ item: InboxItem) {
        guard let campID = store.camp?.id else { return }
        Task {
            do {
                let updated = try await store.repository.resolveInboxItem(item.id, campID: campID)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    items = updated
                }
                resolveCount += 1
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

// MARK: - Which venue

extension AppStore {
    /// The venue the Inbox is about.
    ///
    /// A person's own posting first — the design's rows are the morning on the court they are
    /// standing on — falling back to the camp's first venue for an admin who is not posted
    /// anywhere today. `inboxItems(forVenue:campID:)` takes one venue, so somebody has to
    /// choose, and this is the only screen choosing.
    var inboxVenueID: Venue.ID? {
        todayAssignment?.venueID ?? camp?.venues.first?.id
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

        guard let campID = store.camp?.id, let venueID = store.inboxVenueID else { return store }
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
