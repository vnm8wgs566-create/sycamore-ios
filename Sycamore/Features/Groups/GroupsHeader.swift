//
//  GroupsHeader.swift
//  Sycamore
//
//  The white block at the top of `8o`: the screen's name and the avatar, a chip per venue, the
//  search field, and the one line of instruction the screen needs.
//
//  It has three states, and they are exclusive because the design draws them that way.
//  Ordinarily it is chips, field and hint. While a kid is in the air (`8p`) all of that goes and
//  the block says only who is being moved — nothing else on the screen is actionable until the
//  move lands, so offering a search field would be offering a dead end. Below eight kids (`8g`)
//  there is nothing to filter or search, so the header is the title and a count.
//
//  The bell that used to sit in the corner is gone. The design drew it with an unread dot and
//  gave it no destination, so it had to be rendered as decoration; `ScreenHeader`'s avatar
//  replaces it with a control that goes somewhere.
//

import SwiftUI

struct GroupsHeader: View {

    @Bindable var store: AppStore
    /// The venue whose chip is lit. Resolved by `GroupsView` rather than read from
    /// `store.venueFilter`, which can hold `.all` — a state this row cannot draw.
    var selectedVenueID: Venue.ID?
    /// The kid in the air, if any — `8p` gives the whole block over to them.
    var movingName: String?
    /// `8g`. The chips and the field are pointless below eight kids.
    var isLocked: Bool = false
    /// The grey line under the title — `8g` writes "5 kids added · Sycamore" there.
    ///
    /// Named `count` because `GroupsView` still calls it that, and that file is another pair of
    /// hands this week. It is a sentence, not a figure, and it goes to `ScreenHeader`'s
    /// `subtitle` slot accordingly; the name follows when the call site is next open.
    var count: String?

    /// What is in the field right now, which is not the same thing as what the list is filtered
    /// by — see `controls`.
    @State private var typed = ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Groups", subtitle: count, initials: store.avatarInitials) {
                store.pushedScreen = .campHome
            }

            if let movingName {
                movingLine(movingName)
            } else if !isLocked {
                controls
            }
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
        // Settle, then filter. `store.searchText` is part of the key `groupsSections` is
        // memoised against, so writing it per character was a guaranteed memo miss per
        // character — and a miss re-derives the whole camp: every venue sorted, every group
        // filtered and sorted, every kid's attendance scanned, for a hundred kids, on the main
        // actor, between the key landing and the list redrawing.
        //
        // The field stays instant because it is bound to local state; only the *filtering*
        // waits. 180ms is under the gap between two keystrokes of ordinary typing, so a run of
        // characters costs one derivation instead of one each, and a pause of the length
        // somebody makes when they have finished a name costs nothing extra.
        .task(id: typed) {
            guard typed != store.searchText else { return }
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            store.searchText = typed
        }
        // The store is still the source of truth, so the field follows it down: `initial: true`
        // seeds the field when the tab is rebuilt with a search already running, and the same
        // path carries `AppStore.reset`'s clear when somebody leaves the camp.
        .onChange(of: store.searchText, initial: true) { _, committed in
            if committed != typed { typed = committed }
        }
    }

    // MARK: Ordinary state

    /// Everything below the title is inset by `Spacing.header`, the design's 22 — and so is the
    /// title now.
    ///
    /// This used to read 16 with a note saying it could not be fixed alone: the design sets the
    /// whole white block at 22, but the title belongs to `ScreenHeader`, which drew all four tabs
    /// at 16, and moving only the half of the block this file owns would have left the chips
    /// hanging 6pt outside the heading above them. That was the right call and this is the other
    /// half of it — the two moved together.
    private var controls: some View {
        VStack(spacing: 0) {
            venueChips
                .padding(.bottom, Spacing.gutterWide)

            // Bound to `typed`, not to the store: a character has to reach the field on the
            // frame it was typed on, and the derivation it drives does not.
            SearchField(text: $typed, placeholder: "Find a player")
                .padding(.horizontal, Spacing.header)
                .padding(.bottom, Spacing.medium)

            hint
                .padding(.horizontal, Spacing.header)
                .padding(.bottom, Spacing.large)
        }
    }

    /// One chip per venue, and no "All".
    ///
    /// The design has no "All" chip and always draws one venue selected, which is why this row
    /// is exclusive rather than a toggle: a group is called "Group 1" in every venue, and a list
    /// showing two venues at once would have two of them.
    ///
    /// A horizontal scroller with the gutter on its *content* rather than on itself, so chips
    /// slide out under the screen edge instead of stopping short of it.
    private var venueChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.tight) {
                ForEach(store.camp?.orderedVenues ?? []) { venue in
                    let isSelected = venue.id == selectedVenueID

                    Chip(venue.name, isSelected: isSelected, selectedTone: .dark, metrics: .groupsVenue) {
                        store.venueFilter = .venue(venue.id)
                    }
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Spacing.header)
        }
        .scrollIndicators(.hidden)
    }

    private var hint: some View {
        HStack(spacing: GroupsMetrics.hintGap) {
            Image(systemName: "hand.draw")
                .font(.system(size: GroupsMetrics.hintGlyph, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .accessibilityHidden(true)

            Text("Hold the handle to move a kid between groups")
                .typeStyle(GroupsType.hint, color: Theme.inkMuted)

            Spacer(minLength: 0)
        }
        // One instruction, spoken once. Two elements here made VoiceOver read a hand.
        .accessibilityElement(children: .combine)
    }

    // MARK: Moving

    private func movingLine(_ name: String) -> some View {
        HStack(spacing: GroupsMetrics.hintGap) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: GroupsMetrics.hintGlyph, weight: .regular))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            Text("Moving \(name)")
                .typeStyle(.metaStrong, color: Theme.accent)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.header)
        .padding(.bottom, Spacing.large)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSummaryElement)
    }
}

// MARK: - Previews

#Preview("Groups header") {
    VStack(spacing: 0) {
        GroupsHeader(store: .preview, selectedVenueID: SampleData.sycamore.id)
        Spacer(minLength: 0)
    }
    .background(Theme.surfaceWarm)
    .showsMockStatusBar()
    .frame(width: 402, height: 420)
}

#Preview("Header — moving a kid") {
    VStack(spacing: 0) {
        GroupsHeader(store: .preview, movingName: "Austin Z")
        Spacer(minLength: 0)
    }
    .background(Theme.surfaceWarm)
    .frame(width: 402, height: 300)
}

#Preview("Header — locked") {
    VStack(spacing: 0) {
        GroupsHeader(store: .preview, isLocked: true, count: "5 kids added · Sycamore")
        Spacer(minLength: 0)
    }
    .background(Theme.surfaceWarm)
    .frame(width: 402, height: 300)
}
