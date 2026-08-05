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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()

                ScreenHeader(title: "Overview", count: nowLine, initials: store.avatarInitials) {
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
                        card(for: myCourt, isMine: true)
                        otherCourtsHeading
                    }

                    ForEach(otherCourts) { court in
                        card(for: court, isMine: false)
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
        .background(Theme.grouped)
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

    /// The one card that lists its kids: yours if you have one, otherwise the highest court
    /// still in play. The design draws exactly one detailed card on each frame — "your court
    /// first, the rest quiet" on `8j`, and the first court on `8i`. A closed court is skipped
    /// because it has nobody to list, and skipping it moves the detail onto a court that has.
    private var detailedCourtID: Group.ID? {
        myCourt?.id ?? courts.first { !$0.isClosed }?.id
    }

    /// Five kids, or three when the card is carrying a note as well — the note takes the room
    /// the last two lines would have had. Both counts are the design's own.
    private var rosterLimit: Int { myCourt != nil && blockNote != nil ? 3 : 5 }

    // MARK: Pieces

    private func card(for court: CourtCard, isMine: Bool) -> some View {
        OverviewCourtCard(
            card: court,
            isMine: isMine,
            roster: roster(for: court),
            note: isMine ? blockNote : nil,
            onOpenCoach: openCoach(court)
        )
    }

    private var otherCourtsHeading: some View {
        Text("Other courts")
            .typeStyle(.sectionHeader, color: Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.tight)
            .padding(.horizontal, OverviewTheme.overlineInset)
    }

    /// A closed court lists nobody — there is nobody on it.
    private func roster(for court: CourtCard) -> CourtRoster {
        guard court.id == detailedCourtID, !court.isClosed, let camp = store.camp else {
            return .none
        }
        return TodayCourts.roster(
            forCourt: court.id, in: camp, day: store.today, limit: rosterLimit
        )
    }

    /// Only a coach the camp actually knows gets a tappable pill; a card carrying a name from
    /// a stale read has nothing to open.
    private func openCoach(_ court: CourtCard) -> (() -> Void)? {
        guard let coachID = court.coachID, store.staffMember(coachID) != nil else { return nil }
        return { store.present(.staff(coachID)) }
    }

    /// The note's own words, not the line about who pinned it.
    private func text(of item: InboxItem) -> String { item.detail ?? item.title }

    // MARK: Empty state

    /// Not in the design — every frame there is drawn on a camp in full swing. A venue with no
    /// courts is a real state all the same, and the answer to it is the screen that fixes it.
    private var emptyState: some View {
        VStack(spacing: Spacing.small) {
            Text("No courts yet")
                .typeStyle(.rowTitle, color: Theme.ink)

            Text("Shape the venue into courts in camp settings and they show up here.")
                .typeStyle(.body, color: Theme.inkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.hero)
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
