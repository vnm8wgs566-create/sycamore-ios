//
//  GroupsView.swift
//  Sycamore
//
//  Screen 5 — the day, top to bottom. A sticky white header of filters over a grouped
//  list: one section per venue, one card per coached court.
//
//  The store arrives through the environment (`.environment(store)` on the app shell),
//  which is the iOS 17 `@Observable` convention and keeps `GroupsView()` callable with no
//  arguments.
//

import SwiftUI

struct GroupsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        // Filtering walks the whole roster, so resolve the sections once per pass.
        let sections = store.groupsSections

        return VStack(spacing: 0) {
            GroupsHeader(store: store)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sections) { section in
                        VenueSectionHeader(section: section) {
                            store.present(.venue(section.id))
                        }

                        ForEach(section.cards) { card in
                            CoachGroupCard(store: store, card: card)
                                .padding(.horizontal, Spacing.gutter)
                                .padding(.bottom, 10)
                        }

                        // A venue with no courts yet used to render its header and then
                        // nothing, which reads as a section that failed to load rather than
                        // one waiting for its first kid.
                        if section.cards.isEmpty {
                            emptyVenueNote
                        }
                    }

                    if sections.isEmpty {
                        emptyState
                    }
                }
                // The floating tab bar reserves no layout space of its own.
                .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.grouped)
    }

    // MARK: Empty state

    /// Not in the design — every frame there is drawn unfiltered — but the filters and the
    /// search field can all be narrowed to nothing, and a blank grey page is not an answer.
    /// Quiet by design — a full `ContentUnavailableView` per venue would shout over the
    /// venues that do have courts, which is the opposite of what an empty one deserves.
    private var emptyVenueNote: some View {
        Text("No courts here yet. Partition the camp in Setup to fill it.")
            .typeStyle(.body, color: Theme.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.hero)
            .padding(.vertical, Spacing.section)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Nobody here")
                .typeStyle(.rowTitle, color: Theme.ink)

            Text("No kid or coach matches these filters.")
                .typeStyle(.body, color: Theme.inkTertiary)
                .multilineTextAlignment(.center)

            Pill("Clear filters", tone: .outline) {
                store.resetFilters()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.hero)
        .padding(.top, 72)
    }
}

// MARK: - Venue section header

/// `🌳 Sycamore ⌄   HIGHER LEVEL                              50 kids`
///
/// The count is the venue's whole roster, not the filtered subset — a coach reading the
/// header wants to know how big the venue is, not how many rows survived a chip.
private struct VenueSectionHeader: View {
    let section: GroupsVenueSection
    let onOpenVenue: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Text(section.venue.icon)
                .font(.system(size: 19))

            Button(action: onOpenVenue) {
                HStack(spacing: 5) {
                    Text(section.venue.name)
                        .typeStyle(.venueRow, color: Theme.ink)
                    DisclosureChevron(systemName: "chevron.down", size: 12, color: Theme.inkGhost)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens venue settings")

            if let subtitle = section.venue.subtitle {
                Text(subtitle)
                    .typeStyle(.venueLabel, color: Theme.inkFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(section.playerCount) kids")
                .typeStyle(.metaStrong, color: Theme.inkFaint)
                .layoutPriority(1)
        }
        .padding(.horizontal, Spacing.bar)
        .padding(.top, Spacing.large)
        .padding(.bottom, 10)
    }
}

// MARK: - Previews

#Preview("Groups") {
    let store = AppStore.preview
    store.collapsedGroupIDs = Set(
        SampleData.uclaTennisCamp.groups.map(\.id)
    ).subtracting([SampleData.nassCourt.id])

    return GroupsView()
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 900)
}

#Preview("Groups — searching") {
    let store = AppStore.preview
    store.searchText = "Liam"

    return GroupsView()
        .environment(store)
        .frame(width: 402, height: 900)
}

#Preview("Groups — no matches") {
    let store = AppStore.preview
    store.searchText = "Zzzz"

    return GroupsView()
        .environment(store)
        .frame(width: 402, height: 900)
}
