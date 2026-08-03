//
//  GroupsFilterBar.swift
//  Sycamore
//
//  The sticky white block at the top of the Groups tab: title and bell, the search field,
//  and the two chip rows that narrow the list below.
//
//  The design draws both chip rows inside the header's 16pt gutter with `overflow:hidden`,
//  so each row is its own horizontal scroller with the gutter applied to the *content*
//  rather than to the scroller — chips slide out under the edge instead of stopping short
//  of it.
//

import SwiftUI

/// Gap between chips in either filter row. Not a `Spacing` token: 7 appears nowhere else.
private let chipGap: CGFloat = 7

// MARK: - Header

/// Everything above the scrolling list. Sits in a `VStack` above the body rather than
/// inside the `ScrollView`, which is what makes it stick.
struct GroupsHeader: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Text("Groups")
                        .typeStyle(.tabTitle, color: Theme.ink)

                    Spacer(minLength: 0)

                    // The design draws the bell with an unread dot but gives it no
                    // destination, and there is no notification store behind it to open one
                    // onto. So it stays as the design's indicator and is not a control:
                    // an inert tap target reads as a broken feature and misreports itself
                    // to VoiceOver as a button. Same call the Profile card makes for
                    // "Help & feedback".
                    CircleIconButton(systemName: "bell", showsUnreadDot: true)
                        .accessibilityLabel("Notifications, unread")
                }
                .padding(.top, 14)
                .padding(.bottom, 12)

                SearchField(text: $store.searchText, placeholder: "Search a kid or a coach")
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, Spacing.bar)

            GroupsFilterBar(store: store)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }
}

// MARK: - Filter rows

/// Venue chips on top (`All 100` / `🌳 Sycamore 50` / `🎾 LATC 50`), then a hairline, then
/// the attribute chips (`Everyone` / `Boys` / `Girls` / `Leaving early` / `Away`).
struct GroupsFilterBar: View {
    let store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            venueRow
                .padding(.bottom, 11)

            Hairline(color: Theme.hairlineFaint)
                .padding(.horizontal, Spacing.bar)

            attributeRow
                .padding(.top, 11)
                .padding(.bottom, 12)
        }
    }

    private var venueRow: some View {
        chipScroller {
            ForEach(store.venueChips) { chip in
                Chip(
                    chip.title,
                    emoji: chip.icon,
                    count: chip.count,
                    isSelected: store.venueFilter == chip.filter,
                    selectedTone: .dark,
                    metrics: .venue
                ) {
                    store.venueFilter = chip.filter
                }
                .accessibilityAddTraits(store.venueFilter == chip.filter ? [.isSelected] : [])
            }
        }
    }

    private var attributeRow: some View {
        chipScroller {
            ForEach(PlayerFilter.allCases) { filter in
                Chip(
                    filter.title,
                    isSelected: store.playerFilter == filter,
                    selectedTone: .tinted,
                    metrics: .attribute
                ) {
                    store.playerFilter = filter
                }
                .accessibilityAddTraits(store.playerFilter == filter ? [.isSelected] : [])
            }
        }
    }

    private func chipScroller<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: chipGap) {
                content()
            }
            .padding(.horizontal, Spacing.bar)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Previews

#Preview("Groups header") {
    let store = AppStore.preview
    return VStack(spacing: 0) {
        GroupsHeader(store: store)
        Spacer(minLength: 0)
    }
    .background(Theme.grouped)
    .showsMockStatusBar()
    .frame(width: 402, height: 420)
}

#Preview("Filter bar — narrowed") {
    let store = AppStore.preview
    store.venueFilter = .venue(SampleData.sycamore.id)
    store.playerFilter = .away
    store.searchText = "Liam"
    return VStack(spacing: 0) {
        GroupsHeader(store: store)
        Spacer(minLength: 0)
    }
    .background(Theme.grouped)
    .frame(width: 402, height: 300)
}
