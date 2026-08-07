//
//  OverviewScreen.swift
//  Sycamore
//
//  `8i` / `8j` drawn. Everything this screen needs arrives as a value, so the two frames the
//  design draws are two sets of arguments rather than two views — and so a preview can put the
//  design's own morning on screen without a repository behind it. `OverviewView` is the half
//  that loads.
//
//  The order down the page is the design's: a pinned note if there is one, then your own court
//  under "Your court", then everything else under "Other courts". An admin has no court of
//  their own, so both headings fall away and the list is simply every court in rank order —
//  which is `8i`, exactly.
//
//  Every card lists its kids. The design draws exactly one detailed card per frame and this
//  screen took that literally: it named a single "detailed" court and handed every other card
//  `.none`, so on a twelve-court morning eleven of them said how many kids were there and not
//  one name. Which court a child is on is the question Overview exists to answer. Each card
//  carries its own list now, folded to `OverviewTheme.rosterPreview` names with a `+N more` that
//  opens it in place — the design's frames survive as the folded state of a screen that can now
//  also be opened.
//

import SwiftUI

struct OverviewScreen: View {

    let store: AppStore
    /// Every court at the venue, in rank order.
    let courts: [CourtCard]
    /// The note pinned above them. Nil draws no banner.
    var pinnedNote: InboxItem?
    /// The note hanging off the block running on your court.
    var blockNote: String?
    /// "Skills rotation · until 10:30" — the line under the screen's title.
    var nowLine: String?

    /// Courts the reader has opened past their first few kids.
    ///
    /// Local rather than on the store, and for the reason `GroupsView` gives for the same set:
    /// which cards are open is about this screen at this moment. Nothing else reads it, no write
    /// depends on it, and the default is the *folded* card — so an empty set means what it looks
    /// like it means.
    @State private var expandedCourtIDs: Set<Group.ID> = []

    /// A card opening is a change of position, which is precisely what Reduce Motion is about.
    /// The rows still arrive; they simply stop travelling.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Once per pass, for every court at the venue. See `TodayCourts.rosters(in:day:)` for
        // why this is built here and handed down rather than asked for inside each card.
        let rosters = store.camp.map { TodayCourts.rosters(in: $0, day: store.today) } ?? [:]

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()

                ScreenHeader(title: "Overview", subtitle: nowLine, initials: store.avatarInitials) {
                    store.pushedScreen = .profile
                }
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                LazyVStack(spacing: OverviewTheme.cardGap) {
                    if let pinnedNote {
                        PinnedNoteBanner(text: text(of: pinnedNote)) {
                            store.selectedTab = .inbox
                        }
                    }

                    if let myCourt {
                        card(for: myCourt, isMine: true, from: rosters)
                        otherCourtsHeading
                    }

                    ForEach(otherCourts) { court in
                        card(for: court, isMine: false, from: rosters)
                    }

                    if courts.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.gutterWide)
                // The floating tab bar reserves no layout space of its own.
                .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `surfaceWarm`, not `grouped`. Section 8 draws every screen on `#F8F9F8`, a shade
        // warmer than the `#F6F7F9` this app has been grouping on since before the redesign.
        .background(Theme.surfaceWarm)
        // One tick as a card opens or closes, which is what `BlockNotesCard` gives the only
        // other fold in the app. On the set rather than on a card, because the cards are drawn
        // in a loop and there is nothing per-card to hang it off.
        .sensoryFeedback(.selection, trigger: expandedCourtIDs)
    }

    // MARK: Which court is whose

    /// The court the person reading this is standing on. Nil for an admin, which is what turns
    /// `8j` back into `8i`.
    private var myCourtID: Group.ID? {
        store.myStaffRecord?.groupID ?? store.todayAssignment?.groupID
    }

    private var myCourt: CourtCard? {
        guard let myCourtID else { return nil }
        return courts.first { $0.id == myCourtID }
    }

    private var otherCourts: [CourtCard] {
        guard let myCourt else { return courts }
        return courts.filter { $0.id != myCourt.id }
    }

    // MARK: Pieces

    /// One card, with its court's list already cut to what the card should draw.
    ///
    /// **The note no longer takes the roster's room.** This screen used to fold your own court
    /// to three kids instead of five whenever a block note was hanging off it, on the argument
    /// that the note took the room the last two lines would have had. That argument was about a
    /// card with one chance to show its list: whatever it left out was gone. Now every card
    /// draws a preview and the rest is one tap away, so the note and the roster are no longer
    /// competing for the same room — and the old rule had the sign backwards besides. A note
    /// only ever hangs off *your* court, so it made the one card you care most about the one
    /// listing fewest kids.
    private func card(
        for court: CourtCard, isMine: Bool, from rosters: [Group.ID: CourtRoster]
    ) -> some View {
        let roster = TodayCourts.roster(
            for: court,
            from: rosters,
            preview: OverviewTheme.rosterPreview,
            isExpanded: expandedCourtIDs.contains(court.id)
        )

        return OverviewCourtCard(
            card: court,
            isMine: isMine,
            roster: roster,
            note: isMine ? blockNote : nil,
            onOpenCoach: openCoach(court),
            // A court small enough to draw whole gets no control. `isFoldable` asks
            // `GroupsRules.visibleCount` the same question the fold answers, so the row and the
            // list can never disagree about whether there is anything behind it.
            onToggleRoster: roster.isFoldable(to: OverviewTheme.rosterPreview)
                ? { toggle(court.id) }
                : nil
        )
    }

    private var otherCourtsHeading: some View {
        Text("Other courts")
            .typeStyle(OverviewTheme.overline, color: Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.tight)
            .padding(.horizontal, OverviewTheme.overlineInset)
            .accessibilityAddTraits(.isHeader)
    }

    /// Only a coach the camp actually knows gets a tappable pill; a card carrying a name from
    /// a stale read has nothing to open.
    private func openCoach(_ court: CourtCard) -> (() -> Void)? {
        guard let coachID = court.coachID, store.staffMember(coachID) != nil else { return nil }
        return { store.present(.staff(coachID)) }
    }

    /// The note's own words, not the line about who pinned it.
    private func text(of item: InboxItem) -> String { item.detail ?? item.title }

    // MARK: Intents

    private func toggle(_ courtID: Group.ID) {
        withAnimation(OverviewTheme.fold(reduceMotion: reduceMotion)) {
            if expandedCourtIDs.contains(courtID) {
                expandedCourtIDs.remove(courtID)
            } else {
                expandedCourtIDs.insert(courtID)
            }
        }
    }

    // MARK: Empty state

    /// Not in the design — every frame there is drawn on a camp in full swing. A venue with no
    /// courts is a real state all the same, and the answer to it is the screen that fixes it.
    ///
    /// The system's own empty state rather than a hand-set one, as everywhere else in the app:
    /// it is already announced as such to VoiceOver, and it is the one thing on this screen with
    /// no design to be exact to.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No courts yet", systemImage: "square.split.2x2")
        } description: {
            Text("Shape the venue into courts in camp settings and they show up here.")
        }
        .padding(.top, Spacing.section)
    }
}

// MARK: - Previews

#Preview("8i — Overview · admin") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        pinnedNote: OverviewFixtures.pinnedNote,
        nowLine: OverviewFixtures.nowLine
    )
    .showsMockStatusBar()
}

#Preview("8j — Overview · on a court") {
    OverviewScreen(
        store: OverviewFixtures.coachStore,
        courts: OverviewFixtures.courts,
        pinnedNote: OverviewFixtures.pinnedNote,
        blockNote: OverviewFixtures.blockNote,
        nowLine: OverviewFixtures.nowLine
    )
    .showsMockStatusBar()
}

#Preview("Overview — no courts") {
    OverviewScreen(store: OverviewFixtures.adminStore, courts: [])
        .showsMockStatusBar()
}

/// The two states the design does not draw but the app has to survive: the reader's largest
/// type size, and the dark scheme. Every fixed height on these screens is a `minHeight` or a
/// `@ScaledMetric` so that the first one only ever makes the cards taller.
#Preview("8j — accessibility1") {
    OverviewScreen(
        store: OverviewFixtures.coachStore,
        courts: OverviewFixtures.courts,
        pinnedNote: OverviewFixtures.pinnedNote,
        blockNote: OverviewFixtures.blockNote,
        nowLine: OverviewFixtures.nowLine
    )
    .showsMockStatusBar()
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("8i — dark") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        pinnedNote: OverviewFixtures.pinnedNote,
        nowLine: OverviewFixtures.nowLine
    )
    .showsMockStatusBar()
    .preferredColorScheme(.dark)
}
