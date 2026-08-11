//
//  TournamentView.swift
//  Sycamore
//
//  The Tournament tab — the fourth slot in the bar, and the one screen in the app that makes
//  something out of the ladder rather than editing it.
//
//  ── FIVE STATES, ONE OF WHICH THE DESIGN DOES NOT HAVE ────────────────────────────────────────
//
//  The design names four (`state1.js:751-755`) and they are exclusive: no venue, no kids, no
//  draws, or the list. `TournamentState` adds a fifth — *loading* — because this app has a network
//  and the prototype does not. An empty `store.tournaments` means two different things, "this venue
//  has no draws" and "nobody has asked yet", and `AppStore.loadedTournamentVenueID` exists to tell
//  them apart. Drawing "No draws yet." over a venue whose draws are in flight is how a screen
//  invites somebody to build a second copy of one that already exists.
//
//  ── THE VENUE IS THE KEY TO EVERYTHING ────────────────────────────────────────────────────────
//
//  A draw is struck from one venue's ladder, so the whole screen is scoped to `store.readVenueID`
//  and `.task(id:)` on it is the **sole** owner of reloading. Nothing here calls `loadTournaments`
//  from a button, a chip or the back of a write — a rule this codebase learned the hard way, and
//  `AppStore.selectVenue(_:)`'s own doc records what the second caller cost when it had one.
//
//  ── WHY THE FOLD AND DAY STATE LIVES HERE ─────────────────────────────────────────────────────
//
//  Because a card is a value redrawn from the store on every write, and the day somebody is looking
//  at is not a fact about the draw. Held on the card it would reset every time a score landed —
//  score a match on day two, and the card snaps back to day one under your finger. Keyed by
//  `Tournament.ID` so two cards keep separate answers, which is what the design does with
//  `tDaySel[t.id]` (`state1.js:828`).
//

import SwiftUI

struct TournamentView: View {

    @Environment(AppStore.self) private var store

    /// Which day of each draw is being shown, keyed by draw. Absent means day one.
    @State private var selectedDays: [Tournament.ID: Int] = [:]
    /// Which orders of play are unfolded past their first ten, and which tables past their first
    /// three. Two sets, because they are two folds.
    @State private var expandedOrders: Set<Tournament.ID> = []
    @State private var expandedTables: Set<Tournament.ID> = []

    @State private var isCreating = false
    @State private var scoring: TournamentScoreSheet.Target?
    /// The draw a destructive dialog is asking about, and nil when none is up.
    /// Which draw the confirmation is about, and — separately — whether it is up.
    ///
    /// **Two properties rather than one optional.** A `Binding` derived from `removing != nil`
    /// has its setter run *before* the button action that answered it, so by the time "Remove"
    /// reads `removing` it is already nil and the guard returns: the draw stays, no error appears,
    /// and the only destructive control on the screen silently does nothing. `GroupsView.swift:72`
    /// carries the same pair for the same reason, learned here first; the `presenting:` overload
    /// below then hands the plan to the action rather than making it re-read state.
    @State private var removing: TournamentPlan?
    @State private var isConfirmingRemoval = false
    /// `8c` and everything past it, for the "Bring in the kids" state.
    @State private var isEnrolling = false

    // MARK: Reads

    private var venue: Venue? {
        guard let id = store.readVenueID else { return nil }
        return store.camp?.venue(id)
    }

    private var hasLoaded: Bool {
        store.loadedTournamentVenueID != nil && store.loadedTournamentVenueID == store.readVenueID
    }

    private var state: TournamentState {
        TournamentState.resolve(
            venue: venue,
            ladderCount: store.tournamentLadder.count,
            tournamentCount: store.tournaments.count,
            hasLoaded: hasLoaded
        )
    }

    /// `Sycamore · 50 kids on the ladder` — the design's `tMeta` with the venue in front of it.
    private var subtitle: String? {
        guard let venue else { return nil }
        let count = store.tournamentLadder.count
        return "\(venue.name) · \(count) kid\(count == 1 ? "" : "s") on the ladder"
    }

    /// Every draw at this venue, resolved.
    ///
    /// Derived in `body` rather than held in `@State` and rebuilt on change, which is the shape
    /// `ScheduleView.conflicts` takes and the shape `AppStore.groupsSections` memoises into. Both
    /// of those walk the entire camp — every venue, every court, every kid's attendance — and are
    /// re-entered per frame of a drag. This walks one draw: a dozen entrants, a hundred-odd
    /// fixtures at the very outside, with attendance indexed once inside the initialiser. Holding
    /// it would buy a fraction of a millisecond and cost the thing staleness always costs — a card
    /// drawn from the plan before the score that has just landed.
    private var plans: [TournamentPlan] {
        guard let camp = store.camp else { return [] }
        return store.tournaments.map { TournamentPlan($0, in: camp, today: store.today) }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()
                TournamentHeader(
                    store: store,
                    selectedVenueID: store.readVenueID,
                    subtitle: subtitle
                )
            }
            .background(Theme.surface)

            ScrollView {
                content
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, TournamentMetrics.listTop)
                    // The tab bar floats over the content, so the scroller has to clear it.
                    .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        // The one place a reload starts. See the file header.
        .task(id: store.readVenueID) {
            guard let venueID = store.readVenueID else { return }
            await store.loadTournaments(at: venueID)
        }
        .sheet(isPresented: $isCreating) { createSheet }
        .sheet(item: $scoring) { target in
            TournamentScoreSheet(
                target: target,
                onSave: { score in save(score, for: target) },
                onClear: { save(nil, for: target) },
                onClose: { scoring = nil }
            )
        }
        // The design confirms a removal by turning "Remove" into "Tap again" for 2.6 seconds. See
        // `TournamentCard.header` for why that is replaced by the system's own dialog.
        .confirmationDialog(
            removing.map { "Remove \($0.title)?" } ?? "",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible,
            presenting: removing
        ) { plan in
            Button("Remove", role: .destructive) {
                Task { await store.removeTournament(plan.id) }
            }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("The draw and every score on it go. The ladder is untouched.")
        }
        .fullScreenPresentation(isPresented: $isEnrolling) {
            enrolmentFlow
        }
    }

    // MARK: What is on screen

    @ViewBuilder
    private var content: some View {
        switch state {
        case .noVenue:
            TournamentEmptyCard(
                heading: "Nowhere to seed a draw yet.",
                message: "Tournaments draw from a venue's ladder — start with the place you run.",
                actionTitle: "Add a venue"
            ) {
                // Venues are shaped in Camp settings, which is where the venue sheet is presented
                // from. There is no "add a venue" screen of its own to send anybody to.
                store.push(.campSettings)
            }

        case .noKids(let venueName):
            TournamentEmptyCard(
                heading: "No one to seed yet.",
                message: "Tournaments draw from \(venueName)'s ladder. Bring in the kids first.",
                actionTitle: "Bring in the kids"
            ) {
                isEnrolling = true
            }

        case .loading:
            // Deliberately nothing. The list is a handful of rows behind one request, so a
            // spinner would appear and leave inside the same breath — and an empty screen that
            // fills in is a great deal quieter than a spinner that flashes. What matters is that
            // this is *not* the "No draws yet." card, which is the claim that would be wrong.
            Color.clear.frame(height: 0)

        case .empty:
            TournamentEmptyCard(
                heading: "No draws yet.",
                message: "Pick the groups, a format and the days — the order of play draws itself and plans around who's away.",
                actionTitle: "New tournament"
            ) {
                isCreating = true
            }

        case .hasList:
            list
        }
    }

    private var list: some View {
        // Not a `LazyVStack`. A venue has a handful of draws, not a feed, and the horizontal
        // bracket strips inside them measure themselves — laziness would buy nothing and cost the
        // measurement on first appearance.
        VStack(spacing: TournamentMetrics.cardGap) {
            ForEach(plans) { plan in
                card(plan)
            }

            addRow
        }
    }

    private func card(_ plan: TournamentPlan) -> some View {
        TournamentCard(
            plan: plan,
            coaches: store.camp?.staff ?? [],
            selectedDay: selectedDays[plan.id] ?? 1,
            onSelectDay: { selectedDays[plan.id] = $0 },
            isOrderExpanded: expandedOrders.contains(plan.id),
            isTableExpanded: expandedTables.contains(plan.id),
            onToggleOrder: { expandedOrders.toggle(plan.id) },
            onToggleTable: { expandedTables.toggle(plan.id) },
            onScore: { match in
                scoring = TournamentScoreSheet.Target(
                    tournamentID: plan.id,
                    tournamentName: plan.title,
                    matchID: match.id,
                    number: match.number,
                    aName: match.aName,
                    bName: match.bName,
                    existing: match.score
                )
            },
            onToggleCoach: { team, coachID in
                var ids = team.coachIDs
                if let index = ids.firstIndex(of: coachID) {
                    ids.remove(at: index)
                } else {
                    ids.append(coachID)
                }
                Task { await store.setTeamCoaches(ids, forTeam: team.id, in: plan.id) }
            },
            onRemove: {
                removing = plan
                isConfirmingRemoval = true
            }
        )
    }

    /// The dashed invitation at the foot of the list.
    private var addRow: some View {
        Button {
            isCreating = true
        } label: {
            HStack(spacing: TournamentMetrics.addGap) {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .fill(Theme.accentSurface)
                    .frame(width: TournamentMetrics.addTile, height: TournamentMetrics.addTile)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: TournamentMetrics.addGlyph, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TournamentMetrics.addSubtitleGap) {
                    Text("Add a tournament")
                        .typeStyle(.rowTitle.size(15), color: Theme.accentDark)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Groups, format and days — one sheet.")
                        .typeStyle(.rowDetail, color: Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, TournamentMetrics.addPaddingHorizontal)
            .padding(.vertical, TournamentMetrics.addPaddingVertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: shape)
            .overlay {
                shape.strokeBorder(
                    Theme.accentBorder,
                    style: StrokeStyle(lineWidth: BorderWidth.input, dash: TournamentMetrics.addDash)
                )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TournamentMetrics.cardRadius, style: .continuous)
    }

    // MARK: The sheets

    @ViewBuilder
    private var createSheet: some View {
        if let camp = store.camp, let venue {
            TournamentSheet(
                camp: camp,
                venue: venue,
                onCreate: { request in
                    isCreating = false
                    create(request, at: venue.id)
                },
                onClose: { isCreating = false }
            )
        }
    }

    /// `8c` and everything past it, over the whole frame.
    ///
    /// Presented from this view rather than through `store.activeSheet`, for the reason
    /// `GroupsView.enrolmentFlow` states: that slot is presented by `MainTabView`, which is *above*
    /// this screen, so asking it to present would open the flow behind the screen that asked.
    @ViewBuilder
    private var enrolmentFlow: some View {
        if let venue {
            EnrolmentFlowView(venueID: venue.id) { isEnrolling = false }
                .environment(store)
        }
    }

    // MARK: Writes

    /// One draw, or several bands of one.
    ///
    /// The fork the sheet's "Split by rank" stepper decides, taken here rather than inside the
    /// sheet because the store is the thing that knows how to number a venue's list — and because
    /// a sheet that could call either intent would be a sheet that has to know which.
    private func create(_ request: TournamentSheet.Request, at venueID: Venue.ID) {
        Task {
            if request.splitInto > 1 {
                await store.createBandedTournaments(
                    request.seeding,
                    into: request.splitInto,
                    courtIndices: request.courtIndices,
                    days: request.days,
                    at: venueID
                )
            } else {
                await store.createTournament(
                    request.seeding,
                    name: nil,
                    courtIndices: request.courtIndices,
                    days: request.days,
                    at: venueID
                )
            }
        }
    }

    /// A score, or nil to take one back off a match.
    ///
    /// The sheet is dismissed *before* the write rather than after it. The write re-reads the
    /// draw, the card behind the sheet redraws with the new figure, and a sheet still sitting over
    /// it for the length of a round trip would be showing the reader the two steppers they have
    /// just finished with. Nothing here can fail on a tie — `TournamentScoreSheet` refuses one
    /// outright, which is what keeps the `tournament_matches_no_draw` CHECK a backstop rather than
    /// an error message.
    private func save(_ score: Tournament.Score?, for target: TournamentScoreSheet.Target) {
        scoring = nil
        Task {
            await store.setScore(score, forMatch: target.matchID, in: target.tournamentID)
        }
    }
}

// MARK: - Previews

/// A store standing on the Tournament tab, at a camp of `shape`.
///
/// File-private rather than beside `AppStore.preview`, because it is three lines of preview data
/// for one tab and `AppStore.swift` belongs to everybody.
private extension AppStore {

    enum PreviewShape {
        /// The sample camp, untouched.
        case whole
        /// A venue with nobody on its ladder.
        case noKids
        /// A camp with nowhere to run anything.
        case noVenue
    }

    static func previewTournament(_ shape: PreviewShape) -> AppStore {
        let store = AppStore()
        store.auth = .signedIn(SampleData.account)
        store.memberships = SampleData.memberships
        store.selectedMembership = SampleData.uclaMembership
        store.selectedTab = .tournament

        var camp = SampleData.uclaTennisCamp
        switch shape {
        case .whole:
            break
        case .noKids:
            camp.players = []
        case .noVenue:
            camp.venues = []
            camp.groups = []
            camp.players = []
        }
        store.camp = camp
        store.chosenVenueID = camp.orderedVenues.first?.id
        return store
    }
}

/// Hoisted to file scope for the mangling reason `Components.swift:1473-1475` gives, and a view
/// rather than a static store for a reason of its own: the draws have to be *written* through the
/// store to exist, because `loadTournaments` reads them back out of `OfflineDraws` and would
/// otherwise overwrite anything assigned to `store.tournaments` by hand.
///
/// So the preview seeds the way the app does — through `createTournament` — and the screen's own
/// `.task(id:)` picks them up. What it shows is therefore the real path, including the moment
/// before the first read lands.
private struct TournamentPreviewHarness: View {

    var shape: AppStore.PreviewShape = .whole
    /// Draws to strike before the screen is looked at. Empty leaves the tab on "No draws yet."
    var seeds: [(Tournament.Seeding, Int)] = []

    @State private var store = AppStore.previewTournament(.whole)
    @State private var isSeeded = false

    var body: some View {
        TournamentView()
            .environment(store)
            .task {
                guard !isSeeded else { return }
                isSeeded = true
                store = AppStore.previewTournament(shape)
                guard let venueID = store.readVenueID else { return }
                for (seeding, days) in seeds {
                    await store.createTournament(
                        seeding, name: nil, courtIndices: [0], days: days, at: venueID
                    )
                }
            }
    }
}

#Preview("Tournament — no draws yet") {
    TournamentPreviewHarness()
        .showsMockStatusBar()
        .frame(width: 402, height: 760)
}

#Preview("Tournament — the list") {
    TournamentPreviewHarness(
        seeds: [
            (.singles(.roundRobin), 2),
            (.doubles(.knockout), 2),
            (.team(count: 3), 1),
        ]
    )
    .showsMockStatusBar()
    .frame(width: 402, height: 900)
}

#Preview("Tournament — no kids on the ladder") {
    TournamentPreviewHarness(shape: .noKids)
        .showsMockStatusBar()
        .frame(width: 402, height: 760)
}

#Preview("Tournament — no venue") {
    TournamentPreviewHarness(shape: .noVenue)
        .showsMockStatusBar()
        .frame(width: 402, height: 760)
}

#Preview("Tournament — accessibility1") {
    TournamentPreviewHarness(seeds: [(.singles(.roundRobin), 2)])
        .frame(width: 402, height: 900)
        .environment(\.dynamicTypeSize, .accessibility1)
}
