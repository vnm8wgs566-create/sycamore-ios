//
//  GroupsView.swift
//  Sycamore
//
//  `8o` Groups — "Kids in ranking order", and with it `8p` moving a kid and `8g` the locked
//  state below eight kids.
//
//  Section 8 folds the old Rank tab into this screen. Before it there were two lists of the same
//  hundred kids — a court-by-court one here and a camp-wide ladder on its own tab — and they
//  disagreed with each other by design: a kid could be third on their court and fortieth in the
//  camp, and no screen showed both numbers. There is one list now. A group is a band of it, and
//  the numeral beside a kid is their place in the camp.
//
//  Which is why `commit(_:to:)` writes the camp ladder and not just the group. See it for the
//  whole argument; it is the one thing on this screen that is easy to get subtly wrong.
//
//  The screen coordinates the move rather than the cards, because a kid picked up in one card
//  lands in another. It owns the lifted card, every card's rectangle and every drawn row's, the
//  fold each card is in, how far the list has walked itself, and it is the only thing that
//  writes to the store.
//
//  `8p` is a single continuous gesture now: hold, drag, let go. The bar that used to land a
//  latched kid — `Cancel` / `Drop here` — has gone, and with it the tap-to-aim it was the other
//  half of. What replaces the reach that latch bought is here: the lift opens every card in the
//  venue so no seat is hidden behind "+3 more", and `GroupsAutoscroll` walks the list towards
//  the finger when the carried card nears an edge. `GroupsMove.swift`'s header carries the
//  argument; `beginMove` and `endTracking` are where it is played.
//

import SwiftUI

struct GroupsView: View {

    @Environment(AppStore.self) private var store
    /// The lift, the drop and the fold are all changes of *position*, which is the one thing
    /// Reduce Motion is actually about. Every animation on the screen goes through
    /// `Motion.fold(reduceMotion:)`, so the state still changes — it arrives rather than
    /// travels.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Groups the reader has opened past their first three kids. Local rather than
    /// `store.collapsedGroupIDs`, because the design's default is the *folded* card and an empty
    /// set of collapsed ids means the opposite.
    @State private var expandedGroupIDs: Set<Group.ID> = []
    @State private var move: GroupsMove?
    /// Set for the one state change on this screen that must *not* animate: a move ending by
    /// being committed. Cleared at the start of the next lift rather than on a timer, which is
    /// the only moment it could matter again. See `commit(_:to:)`.
    @State private var isDropping = false
    /// Card and row rectangles in `GroupsSpace.list` — the raw material for every drop slot.
    @State private var cardFrames: [Group.ID: CGRect] = [:]
    @State private var rowFrames: [Player.ID: CGRect] = [:]
    /// A rebuild of the slots is already queued for the end of this layout pass. See
    /// `scheduleGeometryRefresh()`.
    @State private var isRefreshScheduled = false
    /// The venue's cards, held rather than rebuilt in `body` — see `entries(in:)` for what
    /// building one costs and `rebuildEntries()` for what re-derives it.
    ///
    /// Nil until the first rebuild lands, which is the one thing the `??` in `body` is for: a
    /// `.onChange(initial: true)` fires *after* the first pass, and an empty array on that pass is
    /// not a screen with no groups in it drawn one frame early — it is the wrong screen.
    @State private var listEntries: [GroupsEntry]?
    /// The venue's kids with no group, held beside `listEntries` and rebuilt by the same triggers.
    ///
    /// A plain array rather than an optional, because the empty case is not ambiguous the way
    /// `listEntries`' is: no cards on the first pass could mean "not built yet", where nobody
    /// waiting simply draws no card at all — which is also the state a healthy venue is in.
    @State private var unassignedRows: [PlayerRow] = []
    /// Which group card is swiped open, and which has a finger on it. One value for the whole
    /// list, so only one card can be open — see `SwipeRevealState`.
    @State private var swipe = SwipeRevealState<Group.ID>()
    /// The group whose removal is being asked about, or nil. Carries the sentence's numbers with
    /// it for `PlayerScreen`'s reason: the dialog has to survive the card underneath it going away,
    /// and a message assembled from a group that no longer exists reads as "0 kids".
    @State private var deleteTarget: GroupDeletion?
    /// What the scroll view is showing, which is what the autoscroll measures the carried card
    /// against. Held by reference; `GroupsViewportBox` says why.
    @State private var viewport = GroupsViewportBox()
    @State private var listScroll = GroupsListScroll()
    /// The loop that walks the list towards the finger. Held so it can be cancelled the instant
    /// the finger leaves, rather than left to notice on its next tick.
    @State private var autoscroll: Task<Void, Never>?
    /// Whether the enrolment flow is up. Presented **here** rather than through
    /// `store.activeSheet` or a `PushedScreen` case — see `enrolmentFlow`.
    @State private var isEnrolling = false

    /// The venue whose even-out sheet is up, or nil. Carries the venue rather than sitting beside
    /// a `Bool`, so "which venue is this asking about" cannot come apart from "is it showing" —
    /// the venue chips are still live behind the sheet.
    @State private var evenOutTarget: EvenOutTarget?

    var body: some View {
        @Bindable var store = store
        let venue = selectedVenue
        let entries = listEntries ?? entries(in: venue)

        return VStack(spacing: 0) {
            StatusBarMock()

            GroupsHeader(
                store: store,
                selectedVenueID: venue?.id,
                movingName: move?.row.name,
                isLocked: isLocked,
                count: headerCount
            )

            content(entries, venue: venue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, which is a touch warmer than the `grouped` every other tab draws. Section 8
        // gives this screen its own page colour; see the PR for why it is not `Theme.grouped`.
        .background(Theme.surfaceWarm)
        .fullScreenPresentation(isPresented: $isEnrolling) { enrolmentFlow }
        // A sheet rather than a cover: it is a question with two answers and it draws its own
        // ✕, which is exactly what `SheetChrome` is for. `item:` and not `isPresented:` so the
        // venue it is asking about arrives with the presentation instead of being read out of a
        // second property that a chip tap behind the sheet could change underneath it.
        .sheet(item: $evenOutTarget) { target in
            EvenOutSheet(store: store, venueID: target.id) { evenOutTarget = nil }
                .environment(store)
        }
        // The unfold at the start of a lift must land in one pass rather than slide in over a
        // quarter of a second, because the frames measured during it are what every drop slot is
        // rebuilt from — see `refreshDragGeometry()`. `.animation(_:value:)` is a scoped override
        // that beats the ambient transaction, so this is the only place that decision can be
        // made: the lift changes `move == nil`, which would otherwise animate the whole subtree,
        // opened rows included.
        .animation(
            move?.awaitingGeometry == true ? nil : Motion.fold(reduceMotion: reduceMotion),
            value: move == nil
        )
        // What the venue's cards are derived from, watched rather than re-derived, the way
        // `ScheduleView` holds `conflicts` (`:73`, `:241-246`) and for the same reason: `body`
        // runs at display rate for the whole of a drag and not one of these can move while a
        // finger is down. `entries(in:)` is what it costs to be wrong about that.
        //
        // `store.groupsSections` stands in for the graph and the filters together — it is keyed
        // on the camp's revision as well as on the search field and the chips — and it is
        // memoised, so a pass that changed none of them compares two references to one array and
        // stops there.
        //
        // One input it does not stand in for: `rankRanges` walks the *whole* roster, including
        // the kids a search is hiding, and a section holding only the matches cannot say when one
        // of those was renumbered. Every drop made here moves somebody who is on screen, so the
        // gap needs a write from another screen to reach at all, and it costs a band reading
        // `ranked 1–8` until the next thing changes. Left open deliberately: closing it means a
        // fourth trigger that fires on every write to the camp, which is most of what holding
        // this was for.
        .onChange(of: store.groupsSections, initial: true) { rebuildEntries() }
        .onChange(of: expandedGroupIDs) { rebuildEntries() }
        .onChange(of: movingFromGroup) { rebuildEntries() }
        // A filter that changes under a kid in the air can take their group off the screen.
        // Through `cancelMove()` rather than `move = nil`, which would strand the unfolded cards,
        // the missing tab bar and the autoscroll loop behind it.
        .onChange(of: store.searchText) { cancelMove() }
        .onChange(of: store.venueFilter) { cancelMove() }
        // The autoscroll loop outlives the view otherwise. Every ordinary way a move ends stops
        // it, but a screen torn down from underneath one is not one of them, and a loop ticking
        // against state nobody is drawing is a leak that never notices.
        .onDisappear { stopAutoscroll() }
        // The lift itself — one firmer tap as the kid leaves the ladder.
        .sensoryFeedback(trigger: move?.row.id) { previous, current in
            previous == nil && current != nil ? .impact(weight: .medium) : nil
        }
        // And a lighter one each time they cross a boundary on the way to somewhere else.
        .sensoryFeedback(trigger: move?.target ?? nil) { _, current in
            current != nil ? .impact(weight: .light) : nil
        }
        // The landing. New, and it is the release that earned it: the gesture used to end on a
        // button press, which a reader gets a system tap for anyway, and now it ends on nothing
        // at all — a finger leaving glass has no feedback of its own. `isDropping` is set only by
        // a commit, so a cancel and a no-op stay silent, which is the distinction worth feeling.
        .sensoryFeedback(trigger: isDropping) { _, current in
            current ? .impact(weight: .medium) : nil
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func content(_ entries: [GroupsEntry], venue: Venue?) -> some View {
        if isLocked {
            GroupsLockedState(store: store, onAddKids: beginEnrolment)
        } else {
            list(entries, venue: venue)
                .removalConfirmation(
                    target: deleteTarget,
                    isPresented: isConfirmingRemoval,
                    onConfirm: { id in Task { await remove(id) } }
                )
        }
    }

    // MARK: - Enrolment

    /// `8c` and everything past it, over the whole frame.
    ///
    /// Presented from this view rather than through the store, and there are two rejected
    /// alternatives worth naming.
    ///
    /// **Not `ActiveSheet`.** That slot is presented by `MainTabView` (`RootView.swift:138`), and
    /// Camp settings — the other entry point — is itself presented by `MainTabView`. Asking it to
    /// present would open the flow *behind* the screen that asked for it. `BlockEditorSheet`
    /// (`:26-33`) reached the same conclusion for the same reason.
    ///
    /// **Not a new `PushedScreen` case.** `pushedScreen` is a single slot (`AppStore.swift:79`)
    /// that Camp settings already occupies, and evicting it is survivable — but with two entry
    /// points the *return address* varies, and carrying it in the payload would make
    /// `PushedScreen.id` encode a destination as well as a screen, which is not what the comment
    /// at `AppStore.swift:120-124` says `id` is for.
    ///
    /// The venue is the selected chip's, which is what makes "add kids" mean "add kids *here*".
    @ViewBuilder
    private var enrolmentFlow: some View {
        if let venueID = selectedVenue?.id {
            EnrolmentFlowView(venueID: venueID) { isEnrolling = false }
                .environment(store)
        }
    }

    /// Guarded on there being a venue, so the cover above can never come up with nothing in it and
    /// no way out. A camp always has at least one (`CampDraft.venueRange` starts at 1), so this is
    /// a guard against the impossible rather than a state anybody reaches.
    private func beginEnrolment() {
        guard selectedVenue != nil else { return }
        isEnrolling = true
    }

    private func list(_ entries: [GroupsEntry], venue: Venue?) -> some View {
        ScrollView {
            // Not a `LazyVStack`: a card that has not been created has no rectangle, and a group
            // with no rectangle is a group a kid cannot be dropped into. A camp has a dozen of
            // them, not a thousand.
            VStack(spacing: GroupsMetrics.cardGap) {
                // **Above the groups, not below them.** Everything under it is a place these kids
                // could go, so the card and its answers read down the screen in the direction the
                // drag travels. It is also the exception on a screen of routine — a venue in a
                // normal state draws nothing here at all — and an exception at the foot of twelve
                // cards is an exception nobody scrolls to.
                unassignedCard

                ForEach(entries) { entry in
                    cardView(entry)
                }

                // Inside the list rather than instead of it, so a venue that has been searched
                // down to nothing still offers the one thing you can do about that.
                if entries.isEmpty && unassignedRows.isEmpty {
                    nothingHere
                }

                evenOutRow(venue)
                firstSortRow
                addGroupRow(venue)
                addKidsRow
            }
            // The shift: rows sliding aside to open a space, the card the kid left closing up
            // by one row, the card they are aimed at opening by one. Keyed on the *target*
            // alone, so a finger travelling within one slot moves nothing.
            //
            // Placement is load-bearing. Applied here it wraps the cards and nothing else;
            // applied after `.overlay` it would also catch `liftedRow`, whose offset changes on
            // every frame of a finger drag — and animating that makes the card the reader is
            // carrying lag their finger by a quarter of a second. Reduce Motion falls out for
            // free: `Motion.fold(reduceMotion:)` returns nil, which is the real "do not animate
            // this", and the rows simply arrive already shifted.
            //
            // The curve is read from the body that is running when the value changes, which is
            // what lets `drop()` opt one single change out of it — `.animation(_:value:)` is a
            // scoped override and beats the ambient transaction, so `withTransaction` cannot do
            // that job from the call site.
            .animation(
                isDropping ? nil : Motion.fold(reduceMotion: reduceMotion),
                value: move?.target
            )
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, GroupsMetrics.listTop)
            .padding(.bottom, Spacing.tabBarClearance)
            .coordinateSpace(.named(GroupsSpace.list))
            .overlay(alignment: .top) { liftedRow }
        }
        .scrollIndicators(.hidden)
        // **Deliberately not `.scrollDisabled(move != nil)`.**
        //
        // It was, and the comment sitting here said the autoscroll would still drive the list
        // "through `scrollPosition` below" because disabling only takes the pan away from the
        // finger. That is wrong, and wrong in the way that hides: `.scrollDisabled(true)` puts
        // `isScrollEnabled = false` on the scroll view underneath, and a disabled scroll view
        // ignores a programmatic position as thoroughly as it ignores a thumb. So for the whole
        // life of a move the autoscroll computed a correct step, asked the list to travel, and
        // was not listened to — carry a kid to the bottom of the screen and the groups below
        // simply never came. The arithmetic was right and tested the entire time, which is
        // exactly why it survived: every test exercised the part that worked.
        //
        // Nothing takes its place, because nothing needs to. The worry it was defending against
        // was two things scrolling one list at once, and the finger carrying the kid is not one
        // of them: the lift is a `LongPressGesture.sequenced(before: DragGesture)` on the handle
        // (`GroupCard.lift`), so by the time a kid is in the air the scroll view's pan has
        // already failed for that touch and cannot claim it back. A *second* finger can still
        // pan, and that is fine — `creditListTravel(_:)` credits the carried card with whatever
        // the list actually did, whoever asked for it.
        // The list moving is the only travel the drag itself cannot report, so it is credited
        // where it is *observed* rather than where it is asked for — see `creditListTravel(_:)`.
        // Straight off the scroll geometry rather than through an `.onChange` on the viewport,
        // because the viewport is no longer state anybody can watch: see `GroupsViewportBox`.
        .groupsListScroll($listScroll, viewport: viewport, onTravel: creditListTravel)
        // The one `.scrollDisabled` this screen is allowed, and it is a different question from the
        // one the long comment above answers. That one was about a *vertical* drag fighting the
        // pan and taking the autoscroll down with it; this is a card sliding **sideways** under a
        // finger, where the list scrolling at the same time is the thing that makes a swipe
        // impossible to finish. `swipe.isTracking` is only true between a horizontal axis lock and
        // the release that ends it, which is a window no move can be live in — the two gestures
        // start on different views and neither can begin while the other is running.
        .scrollDisabled(swipe.isTracking)
    }

    /// The kids at this venue with no group, drawn only when there are some.
    ///
    /// A card rather than a section header and loose rows, so it sits in the same stack as the
    /// groups, wears the same plate, and can be reached by the same drag. `UnassignedCard` carries
    /// the whole argument for what it says and why it is a source and not a target.
    ///
    /// Hidden by nothing mid-move: unlike the three dashed rows at the foot of the list, this is
    /// not something *new* appearing under a kid in the air — it is already on screen when the lift
    /// starts, and taking it away would move every slot below it. Its rows do give up nothing and
    /// gain nothing during a move, so the boundaries the slots were measured against hold.
    @ViewBuilder
    private var unassignedCard: some View {
        if !unassignedRows.isEmpty, let venue = selectedVenue {
            UnassignedCard(
                rows: unassignedRows,
                band: venue.ageBand,
                isMoving: move != nil,
                isSource: move != nil && move?.sourceGroupID == nil,
                addsTo: oneTapDestination(at: venue),
                onOpenPlayer: { store.pushedScreen = .player($0.id) },
                onAdd: { row in
                    Task { await store.movePlayer(row.id, toVenue: venue.id) }
                },
                onMoveBegan: { beginMove($0, from: nil, among: unassignedRows) },
                onMoveChanged: updateMove(to:),
                onMoveEnded: endTracking,
                onMoveCancelled: cancelTracking,
                onRowFrame: { id, frame in
                    guard isMeasuring else { return }
                    rowFrames[id] = frame
                    scheduleGeometryRefresh()
                },
                heldRowID: move?.sourceGroupID == nil ? move?.row.id : nil
            )
        }
    }

    /// What the `Add` pill on an unassigned row promises: `Group 2`, or nothing at a venue that has
    /// no groups to add to.
    ///
    /// Asked of the *model*, through the same call the write will make. `Camp.movePlayer` answers a
    /// nil group with `smallestGroupID(in:)`, so this names the group that tap will actually land
    /// in rather than a number this screen picked — and the pill cannot come to promise one court
    /// while the store writes another. It is a render behind the graph, which costs nothing: the
    /// toast after the write reports where the kid genuinely went.
    private func oneTapDestination(at venue: Venue) -> String? {
        guard let camp = store.camp,
              let groupID = camp.smallestGroupID(in: venue.id)
        else { return nil }
        // `Group.label`, not `"Group \(number)"`: a camp whose sport calls them lanes says lanes,
        // and `reindex()` is what keeps that word right after a removal renumbers the rest.
        return camp.group(groupID)?.label
    }

    private func cardView(_ entry: GroupsEntry) -> some View {
        // The house's one destructive idiom for a `ScrollView` of cards, rather than a second
        // spelling of it. `SwipeToDelete`'s header argues why a horizontal swipe is the gesture
        // this app can actually build — direction separates it from the scroll, where every other
        // drag on this screen is vertical and has to be separated by *time* — and it brings the
        // named accessibility action with it, which is the whole non-pointer route to a delete.
        //
        // `onDelete: nil` mid-move switches the swipe off entirely rather than leaving it live and
        // hoping: a card sliding out from under a kid in the air would take its drop slots
        // sideways, and the reader is holding the screen with the other hand.
        SwipeToDelete(
            id: entry.id,
            state: $swipe,
            actionLabel: "Remove group \(entry.card.group.number)",
            // `SwipeToDelete` paints this behind the sliding row because its other caller wraps a
            // bare `CardRow`, which has no background of its own. A `Card` has one, at a radius —
            // so a second opaque rectangle behind it would show as square white shoulders on every
            // card in the list.
            background: .clear,
            // Not offered on a venue's **only** group, and the reason is a column rather than a
            // scruple: `sites_group_count_range` is `check (group_count between 1 and 40)`, so the
            // decrement `Camp.removeGroup` makes would take it to 0 and Postgres would refuse the
            // write. An affordance that is always going to fail is worse than one that is not
            // there. `SycamoreRepository.deleteGroup(_:campID:)` is where the choice between this
            // and a migration is argued, and both repositories now refuse the same call by name —
            // so this gate is the reader's answer, not the only one.
            //
            // Nor is it a loss. A venue with no groups has nowhere to put anybody; emptying the
            // last one is what the age band and the drag already do, and those leave the kids
            // somewhere the screen can name.
            //
            // The venue comes off the group rather than off `selectedVenue`. They agree — the list
            // draws one venue — and taking it off the row is what the repositories do, which is
            // one fewer way for the two answers to drift.
            onDelete: (move == nil && !isOnlyGroup(at: entry.card.group.venueID))
                ? { requestRemoval(of: entry) }
                : nil
        ) {
            groupCard(entry)
        }
        // And this is the other half of `background: .clear`. The action plate is in the stack at
        // rest as well as when it is open — covered by the row rather than absent — so with a
        // transparent background it would show through the card's own rounded corners as two red
        // wedges on a screen where nothing has been swiped. Clipping the pair to the card's shape
        // hides it exactly where the card does and gives the revealed plate the same trailing
        // radius, which is what it should have had anyway.
        .clipShape(RoundedRectangle(cornerRadius: GroupsMetrics.cardRadius, style: .continuous))
    }

    private func groupCard(_ entry: GroupsEntry) -> some View {
        GroupCard(
            card: entry.card,
            summary: entry.summary,
            visibleRows: entry.visibleRows,
            // Not the move itself. `GroupsCardMove` carries the argument and `GroupCard.==` is
            // what cashes it in: the digest is what one card draws, so a finger travelling inside
            // one slot produces the same digest it did last frame for every card in the venue.
            move: GroupsCardMove(move, card: entry.id, drawnRows: entry.visibleRows),
            onToggle: { toggle(entry.id) },
            onOpenPlayer: { store.pushedScreen = .player($0.id) },
            onMoveBegan: { beginMove($0, from: entry.id, among: entry.card.rows) },
            onMoveChanged: updateMove(to:),
            onMoveEnded: endTracking,
            onMoveCancelled: cancelTracking,
            onNudge: { nudge($0, in: entry, by: $1) },
            // Both frame stores describe the list **at rest**, which is the only state a drop
            // slot can be measured from. A slot is a promise about where a boundary was when
            // the kid was picked up; the moment the rows start shifting, what is on screen is a
            // *consequence* of the target and so cannot be used to choose one. See
            // `GroupsMove.slots`.
            //
            // `awaitingGeometry` is the one exception, and it is not one really: the lift
            // unfolds every card in the venue, and while that flag is set the cards draw
            // themselves *at rest* — no ghost, and the lifted row keeps its space. So the frames
            // arriving in that pass describe the same list these dictionaries always hold, with
            // the unfold and nothing else applied. Every other frame of the move is ignored,
            // which is also what stops `body` re-evaluating on each frame of a shift animation.
            onRowFrame: { id, frame in
                guard isMeasuring else { return }
                rowFrames[id] = frame
                scheduleGeometryRefresh()
            }
        )
        // The comparison the digest above exists for. `body` runs on every frame of a drag —
        // the carried card has to follow the finger — and rebuilds all twelve cards each time;
        // without this every one of them redraws, which since the lift unfolds the venue is
        // fifty rows at display rate. See `GroupCard`'s `Equatable` conformance for why the
        // eight closures are excluded from it and why that is sound.
        .equatable()
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(GroupsSpace.list))
        } action: { frame in
            guard isMeasuring else { return }
            cardFrames[entry.id] = frame
            scheduleGeometryRefresh()
        }
    }

    /// Whether a rectangle arriving now describes the list a drop slot can be measured from.
    private var isMeasuring: Bool { move == nil || move?.awaitingGeometry == true }

    /// The group the kid in the air came out of: nil when nobody is being carried, and *also* nil
    /// when the kid came out of no group at all.
    ///
    /// The two nils are deliberately not distinguished, because nothing that reads this needs them
    /// to be. It watches for the source card changing which rows it draws, and neither of those
    /// states has a source card. Spelled here rather than as `move?.sourceGroupID ?? nil` inline:
    /// that flattening is what tipped `body`'s modifier chain past what the type checker will
    /// attempt in one expression, and a `Group.ID??` at a call site is a value with two spellings
    /// of "nobody" in it.
    private var movingFromGroup: Group.ID? { move?.sourceGroupID ?? nil }

    /// Ask for the slots to be rebuilt once this layout pass has finished arriving.
    ///
    /// Deferred by one turn of the main actor, and that is the whole of it. `onGeometryChange`
    /// reports one rectangle at a time, so a rebuild run from the first of them would read a
    /// dictionary the rest of the pass has not written yet — and the entries it would find there
    /// are *last* move's, measured against a list the drop that ended it has since renumbered.
    /// Every geometry action for one layout pass runs in the same turn, so the next one has all
    /// of them.
    ///
    /// `RankView` gets this for free by measuring through a `PreferenceKey`, which arrives as one
    /// dictionary, and pays for it with exactly this hop (`RankView.swift:110-113`).
    ///
    /// One hop per pass rather than one per row: a venue of a hundred kids reports a hundred
    /// rectangles, and ninety-nine no-op tasks is ninety-nine allocations at the one moment the
    /// screen is busiest.
    private func scheduleGeometryRefresh() {
        guard move?.awaitingGeometry == true, !isRefreshScheduled else { return }
        isRefreshScheduled = true
        Task { @MainActor in
            isRefreshScheduled = false
            refreshDragGeometry()
        }
    }

    // MARK: - The first sort

    /// The way into `4c`, and the only one.
    ///
    /// **Why Groups.** `4c`'s crumb reads "Groups" and its scope is one venue, which is this
    /// screen's scope exactly — the chip row is exclusive and always has one venue lit
    /// (`GroupsHeader.swift:110-118`). It is also the screen the sort is *for*: what a first sort
    /// produces is the ladder the bands under these card headings are cut from, so the control
    /// belongs at the foot of the list it will rearrange. `PushedScreen.rank`
    /// (`AppStore.swift:84-90`) used to say ranking had no home in the new navigation until Groups
    /// absorbed it; this is that home, and the drag ladder stays beside it rather than under it —
    /// one edits an order that exists, this builds the first one there has ever been.
    ///
    /// **Why not one of the dashed rows.** It sits with them and is deliberately not one of them.
    /// A dashed accent border in this design means an empty slot to fill — "Add a group", "Add
    /// kids" — and the first sort adds nothing; it is a pass over children who are already here.
    /// So it takes the solid hairline card every other row on this screen wears, and it sits
    /// *above* the two add rows, next to the courts it is about.
    ///
    /// **Why it can resume.** `4c` holds its session in `store.firstSort` and nothing writes it
    /// down (`AppStore.swift:148-152`), so the back arrow on that screen leaves the value standing
    /// rather than spending forty answers on one tap — see `FirstSortView.leave()`. This is the
    /// other half of that: a sort of *this* venue still in flight is reopened, and only a venue
    /// with no sort behind it seeds a new one. Asking `beginFirstSort` unconditionally would
    /// re-seed on every entry and make the back arrow destructive after all.
    ///
    /// Reading `store.firstSort` here does mean this `body` re-runs on every answer given on a
    /// screen that is covering it, and that is accepted rather than overlooked: a sort is forty
    /// taps spread over minutes, where a single drag on this screen runs `body` sixty times a
    /// second — the thing all the memoisation above exists for. The row is worth it, because
    /// "30 of 42 placed" on the way back in is what tells somebody the sort they left is still
    /// there to be picked up.
    ///
    /// Hidden mid-move for the reason the two rows below it are: nothing new appears under a kid
    /// in the air.
    @ViewBuilder
    private var firstSortRow: some View {
        if move == nil, let venue = selectedVenue, let offer = firstSortOffer(for: venue) {
            firstSortButton(venue, offer: offer)
        }
    }

    /// What the row says, or nil when there is nothing to sort.
    ///
    /// Two kids is the floor. `FirstSort.seeded` (`Models/FirstSort.swift:117`) settles
    /// immediately on a venue of one — a single kid *is* a ladder — so below two the row would
    /// open a screen with no question on it.
    ///
    /// The count is the venue's roll and not the camp's, which is the same scope the sort itself
    /// takes: `beginFirstSort(in:)` seeds from `camp.players(in:)`.
    ///
    /// Counted rather than asked of `camp.players(in:)`. That call allocates the venue's roll and
    /// *sorts* it (`Models.swift:1094-1096`) to answer a question about how many there are, and
    /// this runs on every pass of `body` — which is the same cost `rankRanges(in:)` was hoisted out
    /// of `body` to stop paying.
    ///
    /// `count(where:)` rather than `lazy.filter { … }.count`, which is what this said before and is
    /// the same walk written the long way round: one call, no `LazySequence` in between, and the
    /// spelling four other counts in the app already use (`AttendanceView.swift:59`,
    /// `InboxView.swift:107`, `SetupView.swift:436`, `OverviewNow.swift:214`).
    private func firstSortOffer(for venue: Venue) -> (title: String, detail: String)? {
        guard let camp = store.camp else { return nil }
        let roll = camp.players.count { $0.venueID == venue.id }
        guard roll >= 2 else { return nil }

        // A settled-but-uncommitted sort is offered as a resume too. It is one tap from being
        // written and re-seeding would throw it away, which is the one thing this branch exists
        // to stop.
        if let sort = store.firstSort, sort.venueID == venue.id {
            return ("Resume the first sort", "\(sort.placed) of \(sort.total) placed")
        }
        return ("Start the first sort", "\(roll) kids in \(venue.name)")
    }

    /// `Card`, and not `dashedRow`'s chrome copied a second time.
    ///
    /// This row was written by copying `dashedRow` below (`:516-518`), whose own comment says "the
    /// chrome is written once so they cannot drift a point apart" — and then the copy did the one
    /// thing that comment was written to prevent, in the one place it could not reach. `dashedRow`
    /// itself genuinely cannot use `Card`:
    /// it needs a `StrokeStyle(dash:)`, which `Card` has no parameter for and should not grow one
    /// for a single caller. This row draws a **solid** `Theme.hairline` rule, which is `Card`'s
    /// default border, over `Theme.surface`, which is its default background, at
    /// `BorderWidth.hairline`, which is its default width (`Components.swift:130-163`). Every
    /// default already matches; the radius is the one thing worth saying out loud.
    ///
    /// `isDivided: false` for `NeedsYouRow`'s reason — one block of content, nothing to rule
    /// between. `Card` supplies the `.frame(maxWidth: .infinity, alignment: .leading)` this used to
    /// state for itself, so only the 44pt floor and the padding stay on the content.
    private func firstSortButton(_ venue: Venue, offer: (title: String, detail: String)) -> some View {
        Button {
            if store.firstSort?.venueID == venue.id {
                store.pushedScreen = .firstSort(venue.id)
            } else {
                store.beginFirstSort(in: venue.id)
            }
        } label: {
            Card(radius: GroupsMetrics.cardRadius, isDivided: false) {
                HStack(spacing: GroupsMetrics.addGroupGap) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: GroupsMetrics.addGroupGlyph, weight: .regular))
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.hairGap) {
                        Text(offer.title)
                            .typeStyle(GroupsType.addGroup, color: Theme.ink)
                        Text(offer.detail)
                            .typeStyle(.rowDetail, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)

                    // Decorative, like the glyph at the head of this same row and every other
                    // caret in the app. Left visible it is not silent: this button composes its
                    // label from its descendants, so VoiceOver would read the two lines and then
                    // announce the chevron's image on the end of them.
                    DisclosureChevron()
                        .accessibilityHidden(true)
                }
                .padding(GroupsMetrics.cardPadding)
                .frame(minHeight: HitTarget.minimum)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ranks the kids in \(venue.name) two at a time")
    }

    // MARK: Even out

    /// "Uneven after moves · 9 · 7 · 8 · 6", and the button that fixes it.
    ///
    /// **It appears only when it has something to say.** The design's own condition is
    /// `max(counts) - min(counts) > 1` (`design/app/state1.js:85`) — one kid of difference is
    /// what an even split of an odd roll *looks* like, so flagging it would be flagging
    /// arithmetic. `EvenOutPlan.isNoOp` is the same test arrived at from the other end: it counts
    /// the kids who would actually move, and a venue already within one has none.
    ///
    /// **Hidden while a search is running**, which is the design's other clause and the one worth
    /// explaining. The cards on screen during a search are a *filtered* view, so their visible
    /// counts are not the counts this plan is about — offering "even out" beside them would be
    /// offering to fix numbers the reader cannot see. The plan itself is computed from the camp
    /// and is right either way; it is the juxtaposition that would lie.
    ///
    /// Hidden mid-move for the reason the three rows below it are: nothing new appears under a
    /// kid in the air.
    ///
    /// The plan is rebuilt on each pass rather than held in `@State`. It is a walk over one
    /// venue's roll — the same order of work as `firstSortOffer` above — and holding it would mean
    /// keeping it in step with every drop, every rename and every court added, which is three more
    /// places for the preview to disagree with what the button then does.
    @ViewBuilder
    private func evenOutRow(_ venue: Venue?) -> some View {
        if move == nil, store.searchText.trimmingCharacters(in: .whitespaces).isEmpty,
           let venue, let camp = store.camp,
           let plan = EvenOutPlan(camp: camp, venueID: venue.id), !plan.isNoOp {
            evenOutButton(venue, plan: plan)
        }
    }

    /// Takes the plan the row above already built rather than building a second one. Two calls to
    /// the same initialiser would agree today and are still two walks over the venue's roll on
    /// every pass of `body`, on the screen whose whole memoisation exists to stop exactly that.
    private func evenOutButton(_ venue: Venue, plan: EvenOutPlan) -> some View {
        Button { evenOutTarget = EvenOutTarget(id: venue.id) } label: {
            Card(radius: GroupsMetrics.cardRadius, isDivided: false) {
                HStack(spacing: GroupsMetrics.addGroupGap) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: GroupsMetrics.addGroupGlyph, weight: .regular))
                        .foregroundStyle(Theme.warningDark)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.hairGap) {
                        Text("Uneven after moves")
                            .typeStyle(GroupsType.addGroup, color: Theme.ink)
                        Text(plan.contextLine)
                            .typeStyle(.rowDetail, color: Theme.inkTertiary)
                    }

                    Spacer(minLength: 0)

                    Text("Even out")
                        .typeStyle(.buttonSmall, color: Theme.accent)
                }
                .padding(GroupsMetrics.cardPadding)
                .frame(minHeight: HitTarget.minimum)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Spreads \(venue.name)'s kids evenly across its groups by ladder order")
    }

    /// The dashed row under the last group. Not offered mid-move: a card appearing under a kid
    /// in the air would move every slot below it.
    @ViewBuilder
    private func addGroupRow(_ venue: Venue?) -> some View {
        if move == nil, let venue {
            dashedRow("plus", title: "Add a group", hint: "Adds a group to \(venue.name)") {
                Task { await addGroup(to: venue) }
            }
        }
    }

    /// The way to add a kid **above** eight, which is most of the season.
    ///
    /// `GroupsLockedState`'s call to action is the only other route in, and the locked state only
    /// draws below eight kids (`GroupsTokens.swift:276`) — so without this row the answer to "how
    /// do I add a kid?" is "delete seven of them first". A permanent row at the foot of the list,
    /// beside the one that adds a group, because both are "add something to this venue" and the
    /// foot of the list is where the design already puts that.
    ///
    /// Hidden mid-move for the same reason `addGroupRow` is: nothing new appears under a kid in
    /// the air.
    @ViewBuilder
    private var addKidsRow: some View {
        if move == nil, let venue = selectedVenue {
            dashedRow(
                "person.badge.plus",
                title: "Add kids",
                hint: "Imports a roster or adds a kid to \(venue.name)",
                action: beginEnrolment
            )
        }
    }

    /// The design's white-filled, dashed-bordered call to action at the foot of the list. Two rows
    /// draw it; the chrome is written once so they cannot drift a point apart.
    private func dashedRow(
        _ systemImage: String,
        title: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: GroupsMetrics.cardRadius, style: .continuous)

        return Button(action: action) {
            HStack(spacing: GroupsMetrics.addGroupGap) {
                Image(systemName: systemImage)
                    .font(.system(size: GroupsMetrics.addGroupGlyph, weight: .regular))
                    .accessibilityHidden(true)
                Text(title)
                    .typeStyle(GroupsType.addGroup)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.accent)
            .padding(GroupsMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: HitTarget.minimum)
            // The design fills this white and then dashes the border. Without the fill it reads
            // as a hole in the list rather than as the next card along.
            .background(Theme.surface, in: shape)
            .overlay {
                shape.strokeBorder(
                    Theme.accentBorder,
                    style: StrokeStyle(lineWidth: BorderWidth.hairline, dash: GroupsMetrics.dash)
                )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    /// The search can be narrowed to nothing and a venue can have no groups in it yet, and a
    /// blank grey page is not an answer to "where is Liam".
    @ViewBuilder
    private var nothingHere: some View {
        if store.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView {
                Label("No groups here yet", systemImage: "person.2.slash")
            } description: {
                Text("Partition the camp in Setup, or add the first group below.")
            }
            .padding(.top, Spacing.section)
        } else {
            ContentUnavailableView.search(text: store.searchText)
                .padding(.top, Spacing.section)
        }
    }

    // MARK: - Move overlays

    /// The kid, out of the list and under the finger.
    ///
    /// There is no insertion bar under this any more. A dot and a rule between two rows was the
    /// screen's answer to "where will they land", drawn at `slot.y` over a list that was being
    /// held rigid so that `slot.y` stayed true. The list is not held rigid now: the rows shift,
    /// the card the kid left closes by one row and the card they are aimed at opens by one, and
    /// the greyed row sitting in that space answers the question by *being* the answer. See
    /// `GroupsGhost` for the arithmetic that keeps this card parked over it.
    ///
    /// The original row is still in the flow — it owns the live gesture — but it has given up
    /// its space; see `GroupCard.rowView(_:)`. What keeps every drop slot valid is that the
    /// slots were captured at lift, not that the geometry stopped moving.
    ///
    /// Drawn from the same `GroupsRow` as the row it came out of, and that matters: this card is
    /// positioned directly over that row at the moment of pick-up, so a numeral column or a
    /// name inset that disagreed by even a point would read as the kid jumping sideways as they
    /// leave the ladder. The design changes weight and colour between the two, nothing else.
    @ViewBuilder
    private var liftedRow: some View {
        if let move {
            let shape = RoundedRectangle(
                cornerRadius: GroupsMetrics.ghostCardRadius, style: .continuous
            )

            HStack(spacing: Spacing.small) {
                Text(move.row.name)
                    .typeStyle(GroupsType.liftedName, color: Theme.accentDark)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                // Phosphor's `ph-fill ph-hand-grabbing`. `hand.raised.fill` is the closest SF
                // Symbol with a fill axis; the closed grip has no filled variant.
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: GroupsMetrics.ghostGlyph))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, GroupsMetrics.ghostCardHorizontal)
            .padding(.vertical, GroupsMetrics.ghostCardVertical)
            .background { shape.fill(Theme.accentSurface).shadow(Shadows.liftedKid) }
            .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.input) }
            // 70% of the row it came out of, left-aligned — the design's own width. Narrower than
            // that row on purpose: this card has left the list, and one that still spanned it
            // would read as the list itself moving.
            //
            // A real width off the measured row, **not** `.scaleEffect(x: 0.7)`. A scale squashes
            // the name and the glyph with the plate, so the kid's name would come out condensed —
            // the one piece of text on screen the reader is tracking.
            .frame(width: move.origin.width * GroupsMetrics.ghostCardWidth, alignment: .leading)
            // Pinned to the left of the overlay, which is centred by default.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Spacing.gutter + GroupsMetrics.cardPadding)
            .offset(y: move.origin.minY + move.translation)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - The confirmation

    /// A drop that takes a kid off the court they are on, held while the reader answers for it.
    ///
    /// Only a court change asks. Reordering inside one court commits the moment the finger
    /// leaves the handle, because the whole row is on screen, the change is one place in a list
    /// the reader is looking at, and a dialog in front of it would make the common gesture the
    /// expensive one. Changing court is different: it moves the kid's band in the camp ladder as
    /// well as their card, and it is the drop a slip of the thumb near a card boundary actually
    /// produces.
    ///
    /// It carries its own copy of everything the dialog says, rather than reaching back through
    /// `move` — the sentence has to survive the move being torn down by the answer that dismisses
    /// it, and a title assembled from state that is already nil reads as "Move  to ?".
    // MARK: - Derived

    /// Below eight kids there is nothing to rank, and `8g` is the whole screen.
    private var isLocked: Bool { (store.camp?.playerCount ?? 0) < GroupsRules.opensAt }

    /// `5 kids added`. Only `8g` carries one — `8o`'s header is the title alone.
    ///
    /// Camp-wide, with no venue named, because `GroupsRules.opensAt` is a statement about the
    /// camp: a venue's name beside a camp's number would be a claim the list underneath does
    /// not make.
    private var headerCount: String? {
        guard isLocked, let camp = store.camp else { return nil }
        return "\(camp.playerCount) kid\(camp.playerCount == 1 ? "" : "s") added"
    }

    /// The venue whose groups the screen is showing.
    ///
    /// `8o` always draws one venue selected and gives the chip row no "All", because a group is
    /// called "Group 1" in every venue and a list of two venues at once would have two of them.
    /// `VenueFilter.all` is still the store's default and where `resetFilters()` leaves it, so
    /// it is resolved here rather than written back to the store on appearance — a screen that
    /// corrects the model one frame after drawing the state it cannot draw has already drawn it.
    private var selectedVenue: Venue? {
        guard let camp = store.camp else { return nil }
        if case .venue(let id) = store.venueFilter, let venue = camp.venue(id) { return venue }
        return camp.orderedVenues.first
    }

    /// One card, plus everything the screen derives from the camp graph rather than from the
    /// rows a filter left behind.
    private struct GroupsEntry: Identifiable {
        let card: GroupsCoachCard
        /// `8 players · ranked 1–8`, counted from the group's whole roster — a search that
        /// leaves one kid visible has not made the group one player big.
        let summary: String
        let visibleRows: [PlayerRow]
        /// The rank a kid takes when they land at the very end of this group.
        let tailRank: Int

        var id: Group.ID { card.id }
    }

    /// Re-derive the venue's cards into `listEntries`.
    ///
    /// The three `.onChange`s in `body` are the only callers, and that is the invariant: anything
    /// else that changed what a card says would have to say so here as well, and would be a fourth
    /// trigger rather than a fourth call site.
    ///
    /// The two places that read a *fresher* answer than this holds — `beginMove`, which needs the
    /// venue before the unfold it is about to do, and `refreshDragGeometry`, which needs it after
    /// — call `entries(in:)` directly on purpose. Both run inside the pass that changes the fold,
    /// which is before the `.onChange` that would rebuild this.
    private func rebuildEntries() {
        listEntries = entries(in: selectedVenue)
        // Off the same memoised sections the cards come from, in the same pass, so the two halves
        // of the list can never describe different writes to the camp.
        unassignedRows = selectedVenue
            .flatMap { venue in store.groupsSections.first { $0.id == venue.id } }?
            .unassigned ?? []
    }

    private func entries(in venue: Venue?) -> [GroupsEntry] {
        guard let camp = store.camp, let venue else { return [] }
        let ranges = rankRanges(in: camp)

        return store.groupsSections
            .first { $0.id == venue.id }?
            .cards
            .map { card in
                let range = ranges[card.id]
                let visible = GroupsRules.visibleCount(
                    of: card.rows.count,
                    preview: GroupsRules.previewRows,
                    isExpanded: expandedGroupIDs.contains(card.id)
                )

                return GroupsEntry(
                    card: card,
                    summary: summary(
                        of: card.group,
                        over: range,
                        lifted: move?.sourceGroupID == card.id
                    ),
                    // The card's own array when nothing is hidden, rather than a copy of it.
                    // It costs nothing — the copy was for an array that already existed — and it
                    // is now load-bearing twice over: `GroupCard.==` compares this on every frame
                    // of a drag, and two references to one buffer answer that in O(1) where two
                    // equal copies would walk fifty rows. The folded case, where a prefix is
                    // genuinely needed, is exactly the case that is *not* mid-drag: a lift opens
                    // every card in the venue.
                    visibleRows: visible == card.rows.count
                        ? card.rows
                        : Array(card.rows.prefix(visible)),
                    tailRank: (range?.upperBound ?? 0) + 1
                )
            } ?? []
    }

    /// Every group's rank range, in one pass over the roster.
    ///
    /// `Camp.players(inGroup:)` filters and sorts the whole player array, so asking it once per
    /// card is O(cards × players). This is the same answer in O(players), once.
    ///
    /// It ran on every frame of a drag until `listEntries` held the result — a hundred players
    /// walked and a dictionary built sixty times a second for an answer that cannot change while
    /// a finger is down. The pass itself is unchanged; what changed is how often it is asked for.
    ///
    /// The head-count is deliberately not in here: `Group.playerCount` is denormalised by
    /// `Camp.reindex()` and already holds it, so counting again would be a second answer to a
    /// question the model has settled.
    private func rankRanges(in camp: Camp) -> [Group.ID: ClosedRange<Int>] {
        var ranges: [Group.ID: ClosedRange<Int>] = [:]
        for player in camp.players {
            guard let groupID = player.groupID else { continue }
            guard let range = ranges[groupID] else {
                ranges[groupID] = player.overallRank...player.overallRank
                continue
            }
            ranges[groupID] = min(range.lowerBound, player.overallRank)...max(range.upperBound, player.overallRank)
        }
        return ranges
    }

    /// `8 players · ranked 1–8`, and one short of it while this group's kid is in the air —
    /// `8p` draws the card Austin came out of as "7 players · ranked 1–8".
    ///
    /// The band is deliberately left alone: the group really does hold seven at that moment, but
    /// the kid has not landed anywhere yet, so the span of ranks it covers is still 1–8.
    private func summary(of group: Group, over range: ClosedRange<Int>?, lifted: Bool) -> String {
        let count = group.playerCount - (lifted ? 1 : 0)
        guard let range, count > 0 else { return "No kids yet" }
        return "\(count) player\(count == 1 ? "" : "s") · ranked \(range.lowerBound)–\(range.upperBound)"
    }

    /// A boundary above every drawn row, one below the last of them, and one at the foot of
    /// every card.
    ///
    /// Only the leading edge inside the loop: the rows stack with no spacing, so a row's bottom
    /// and its neighbour's top are the same line and emitting both would double the array.
    ///
    /// The foot is what makes a group with nothing drawn in it — searched down to nothing, or
    /// simply empty — somewhere a kid can still be put. It carries the *unfiltered* row count,
    /// which is a different index from the last drawn row's whenever the two disagree.
    ///
    /// **Folding no longer makes them disagree while a kid is in the air.** A lift opens every
    /// card in the venue (`beginMove`), so from the moment there is anybody to drop, "every drawn
    /// row" is every row — which is what makes the whole of a group reachable rather than its
    /// first three. This is still written in terms of the drawn rows, because it is also what
    /// measures the list at rest, where cards are folded and most rows are not drawn at all.
    ///
    /// That foot slot's y is the card's own bottom edge, which is `Spacing.tight` below the row
    /// boundary the space actually opens at — so the card carrying the kid parks about six
    /// points low when it comes to rest there. Left alone on purpose: this y is what the kid
    /// *aims* with, and moving it would move where they land. Six points is a third of the
    /// distance to the next boundary, and the boundary either side of it says the same thing
    /// about where the kid goes. The ghost itself is unaffected — it is placed by layout, at the
    /// back of the card's real stack, not by this number.
    private func slots(for entries: [GroupsEntry]) -> [GroupsDropSlot] {
        entries.flatMap { entry -> [GroupsDropSlot] in
            let venueID = entry.card.group.venueID
            var slots: [GroupsDropSlot] = []

            // Landing on a drawn row's leading edge means "directly above this kid", which is
            // what the anchor says — so the slot needs no index at all.
            for row in entry.visibleRows {
                guard let frame = rowFrames[row.id] else { continue }
                slots.append(GroupsDropSlot(
                    landing: GroupsLanding(groupID: entry.id, venueID: venueID, anchor: row.id),
                    y: frame.minY,
                    rank: row.player.overallRank
                ))
            }

            // The line below the last drawn row. Its anchor is whoever the group holds *next* —
            // which a fold or a search can hide, so it is looked up in the card's full rows and
            // not in the drawn ones — and nil when the drawn rows run to the end of the group.
            if let last = entry.visibleRows.last, let frame = rowFrames[last.id] {
                let following = entry.card.rows
                    .firstIndex { $0.id == last.id }
                    .map { $0 + 1 }
                    .flatMap { entry.card.rows.indices.contains($0) ? entry.card.rows[$0] : nil }
                slots.append(GroupsDropSlot(
                    landing: GroupsLanding(groupID: entry.id, venueID: venueID, anchor: following?.id),
                    y: frame.maxY,
                    rank: following?.player.overallRank ?? entry.tailRank
                ))
            }

            if let frame = cardFrames[entry.id] {
                slots.append(GroupsDropSlot(
                    landing: GroupsLanding(groupID: entry.id, venueID: venueID, anchor: nil),
                    y: slots.isEmpty ? frame.midY : frame.maxY,
                    rank: entry.tailRank
                ))
            }

            return slots
        }
    }

    private func card(_ groupID: Group.ID) -> GroupsCoachCard? {
        store.groupsSections.lazy.flatMap(\.cards).first { $0.id == groupID }
    }

    // MARK: - Intents

    private func toggle(_ groupID: Group.ID) {
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) {
            expandedGroupIDs.toggle(groupID)
        }
    }

    private func addGroup(to venue: Venue) async {
        // There is no "add a group" intent: a venue owns its group count, and `updateVenue`
        // syncs the courts to it. One write, and the new group arrives empty at the bottom.
        var updated = venue
        updated.groupCount += 1
        await store.updateVenue(updated)
    }

    // MARK: Removing a group

    /// Whether this venue is down to one group, which is the group that cannot go.
    ///
    /// **Off the camp, not off the drawn entries**, and that is a correction rather than a
    /// preference. `computeGroupsSections` drops a card whose rows a search filtered away
    /// (`AppStore.swift:847`), so counting what is on screen answered "how many groups match the
    /// search" — and a search matching one kid at an eight-group venue took Remove off every card
    /// in it. The camp is also the number the repositories check, so the screen and the seam
    /// cannot disagree about which group is the last one.
    ///
    /// Takes the venue off the row rather than reading `selectedVenue`, for the reason the call
    /// site gives: one fewer place for the screen's answer and the repositories' to drift.
    ///
    /// `count(where:)` over `groups` rather than `groups(in:)`, which filters *and* sorts to
    /// answer how many there are — the cost `rankRanges(in:)` was hoisted out of `body` to stop
    /// paying, and this runs once per card per pass.
    private func isOnlyGroup(at venueID: Venue.ID) -> Bool {
        (store.camp?.groups.count { $0.venueID == venueID } ?? 0) <= 1
    }

    /// A swipe reached its Remove. Ask, or just do it.
    ///
    /// **The count is the group's own `playerCount`, not its drawn rows.** A search leaves three of
    /// eight kids on screen, and a dialog that said "3 kids" while five more were about to lose
    /// their group would be the most expensive kind of true-looking sentence. `Camp.reindex()`
    /// denormalises that field on every write, so it is the roster's number rather than the
    /// screen's.
    ///
    /// Nothing is asked about an empty group. There is no cost to undo — the dashed "Add a group"
    /// row directly below puts one back — and a dialog guarding a reversible nothing is what makes
    /// readers stop reading dialogs.
    private func requestRemoval(of entry: GroupsEntry) {
        let kids = entry.card.group.playerCount
        guard kids > 0 else {
            Task { await remove(entry.id) }
            return
        }
        deleteTarget = GroupDeletion(id: entry.id, number: entry.card.group.number, kids: kids)
    }

    /// Whether the dialog is up, as a binding the modifier will take.
    ///
    /// Written this way round — derived from the optional, and only ever *clearing* it — so that
    /// `deleteTarget` stays the one place the answer lives. A separate `Bool` beside it would be a
    /// second fact that has to agree with the first, and the dialog outlives the card it is asking
    /// about.
    private var isConfirmingRemoval: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    /// The write. Scoped to the venue on screen, which is the only venue this list draws.
    ///
    /// `AppStore.removeGroup` carries what does and does not survive the round trip, written down
    /// there rather than discovered here. It is good news now: all of it does. The named group
    /// goes and stays gone, the survivors renumber, the kids it stood down are still unassigned
    /// when the camp comes back, and the venue's count agrees with the cards on screen.
    ///
    /// The repository grew a `deleteGroup` for that. Deletion is a thing the store can say
    /// outright, rather than a court count left for something else to reconcile, so a reload
    /// shows the reader what they just did instead of a different group missing.
    private func remove(_ groupID: Group.ID) async {
        guard let venueID = selectedVenue?.id else { return }
        deleteTarget = nil
        await store.removeGroup(groupID, from: venueID)
    }

    // MARK: - The move

    /// Picking a kid up: the venue opens, the tab bar goes, and the list starts watching its own
    /// edges.
    ///
    /// Takes the source group and the rows the kid was sitting among rather than a `GroupsEntry`,
    /// because there is a second card a lift can start from and it is not a group: the kids with no
    /// group at all. Everything below is the same for both — `sourceGroupID` is simply nil for one
    /// of them, which is the honest answer to "which group did they come out of" and the one every
    /// reader of it already handles. See `GroupsMove.sourceGroupID`.
    private func beginMove(_ row: PlayerRow, from sourceGroupID: Group.ID?, among siblings: [PlayerRow]) {
        // The venue off the screen rather than off the source card's group, because one of the two
        // cards a lift can start from has no group to read it from. They are the same venue either
        // way: this list is one venue's, and the chip row is exclusive.
        guard let venueID = selectedVenue?.id,
              let origin = rowFrames[row.id],
              let index = siblings.firstIndex(where: { $0.id == row.id })
        else { return }

        // The last drop's "do not animate this" instruction, spent. Cleared here rather than on
        // a hop off the main actor because this is the next moment `move` changes at all, so it
        // is the first moment the flag could affect anything again — and it is cleared in the
        // same pass that sets the move, so the body that reads the animation sees a live lift
        // and a false flag.
        isDropping = false

        // **Every card in the venue opens, for the length of the move.** A folded card draws
        // three kids and "+N more", and "+N more" was disabled mid-move — so in an eight-kid
        // group, positions five to seven could not be reached by drag at all. That is most of
        // "the ordering of the kids in the groups still sucks ... should be able to change the
        // list in any order": not a gesture that missed, a gesture with nowhere to land.
        //
        // Only the cards this opened are noted, and only those fold again when the move ends —
        // a card the reader opened themselves stays open, because they opened it.
        //
        // The alternative was `RankView`'s: unfold the card being dragged *from*, and unfold a
        // card as the kid is aimed at it. Rejected because a fold changing mid-move is a fold
        // changing under the frozen slots — the target decides the unfold, the unfold moves
        // every boundary below it, and the boundaries are what the target is picked from. Doing
        // all of it at the lift keeps that to one re-measurement, at the one moment the list can
        // be drawn at rest to be measured: see `awaitingGeometry` and `refreshDragGeometry()`.
        let venueEntries = entries(in: selectedVenue)
        let opening = Set(
            venueEntries.filter { $0.visibleRows.count < $0.card.rows.count }.map(\.id)
        )

        // The rectangles this screen still holds for the rows about to be revealed are from the
        // *last* move, measured against a list the drop that ended it has since renumbered.
        // Dropped rather than trusted, so that `refreshDragGeometry()`'s "every drawn row has
        // been measured" is a question about this lift and not one the previous one already
        // answered. The rows that are on screen keep theirs, which are current.
        for entry in venueEntries where opening.contains(entry.id) {
            for row in entry.card.rows.dropFirst(entry.visibleRows.count) {
                rowFrames.removeValue(forKey: row.id)
            }
        }

        expandedGroupIDs.formUnion(opening)

        // Deliberately not guarded on `move == nil`: a gesture cancelled rather than ended can
        // leave state behind, and overwriting it beats stranding a kid in the air.
        move = GroupsMove(
            row: row,
            sourceGroupID: sourceGroupID,
            nextRowID: siblings.indices.contains(index + 1) ? siblings[index + 1].id : nil,
            origin: origin,
            // The folded layout's slots, which are the ones on screen for the frame or two
            // before the opened rows are measured. A provisional array rather than an empty one
            // so a lift released immediately still knows where the kid was.
            slots: slots(for: venueEntries),
            // Whatever a move that was overwritten rather than finished left open, carried over
            // — this lift is what will fold them again. The guard above deliberately allows that
            // overwrite; without the union, a cancelled gesture's cards would stay open for the
            // rest of the session.
            unfolded: opening.union(move?.unfolded ?? []),
            isDragging: true,
            awaitingGeometry: !opening.isEmpty,
            // Aimed at where they already stand, so the first frame of a lift is not a screen
            // with a lifted card and nothing under it.
            //
            // Nil for a kid lifted out of no group, and that is the honest value rather than a
            // missing feature: there is no place they already stand for the screen to point at, so
            // until the finger moves they are aimed nowhere — and a release that never moved them
            // falls through `endTracking`'s "nothing aimed at" guard and cancels, which is exactly
            // right. The first `retarget` gives them the nearest real slot.
            target: sourceGroupID.map { groupID in
                GroupsDropSlot(
                    landing: GroupsLanding(
                        groupID: groupID,
                        venueID: venueID,
                        anchor: row.id
                    ),
                    y: origin.minY,
                    rank: row.player.overallRank
                )
            }
        )

        // The tab bar is a trapdoor: dragging a kid down a card ends the drag over the one
        // control that leaves the screen entirely. `MainTabView` takes the pill away while this
        // is set, animated — see `AppStore.isFocused`.
        store.isFocused = true
        startAutoscroll()
    }

    /// Re-measure after the unfold, and re-anchor the move to what was measured.
    ///
    /// Copied from `RankView.refreshDragGeometry()` (`:409-425`), which solves the same problem
    /// for the same reason. Three things happen here and they have to happen together: the
    /// lifted card's `origin` moves, because opening the cards above the mover pushes their row
    /// down the list; `translation` is shifted by exactly as much in the other direction, so the
    /// card stays under the finger instead of jumping to wherever the row now sits; and the
    /// slots are rebuilt, because every boundary below an opened card has moved.
    ///
    /// The guard is the subtle part, and `RankView` names it too: waiting for the *mover's* own
    /// rectangle to change is not the signal, because opening cards *below* them leaves it
    /// exactly where it was. What is waited on is every drawn row and every card having a
    /// rectangle at all, which is only true once SwiftUI has laid the opened rows out.
    ///
    /// What makes the rectangles usable is that the cards draw themselves at rest while
    /// `awaitingGeometry` is set — no ghost, and the lifted row still holding its space. So this
    /// pass measures the list the frozen slots are stated against, with the unfold and nothing
    /// else applied to it. It runs once per move and then the flag is down for good.
    private func refreshDragGeometry() {
        guard var updated = move, updated.awaitingGeometry else { return }

        let venueEntries = entries(in: selectedVenue)
        guard venueEntries.allSatisfy({ entry in
            cardFrames[entry.id] != nil && entry.visibleRows.allSatisfy { rowFrames[$0.id] != nil }
        }), let origin = rowFrames[updated.row.id] else { return }

        // Through `listTravel` rather than straight into `translation`, and that is not
        // bookkeeping: `updateMove(to:)` rewrites `translation` from the gesture on every frame,
        // so a correction written only there would survive until the next twitch of a finger and
        // then vanish — the card jumping a card's worth of opened rows in one frame, at the exact
        // moment the reader started aiming.
        let shift = updated.origin.minY - origin.minY
        updated.listTravel += shift
        updated.translation += shift
        updated.origin = origin
        updated.slots = slots(for: venueEntries)
        updated.awaitingGeometry = false
        retarget(&updated)
        move = updated
    }

    private func updateMove(to travel: CGFloat) {
        guard var updated = move else { return }
        updated.isDragging = true
        // The gesture measures its travel from the lift in `.global`, which knows nothing about
        // the list having scrolled itself underneath in the meantime — so the two are added
        // rather than one replacing the other. See `GroupsMove.listTravel`.
        updated.translation = travel + updated.listTravel
        // Aiming waits for the geometry. A target chosen against the folded layout's slots would
        // move the ghost, and a ghost in the flow is precisely what stops this pass being a
        // measurement of the list at rest.
        if !updated.awaitingGeometry { retarget(&updated) }
        move = updated
    }

    /// Aim with the middle of the card being carried rather than with the fingertip — the
    /// fingertip is on the handle, an inch below what the reader thinks they are pointing at.
    private func retarget(_ move: inout GroupsMove) {
        move.target = move.nearestSlot() ?? move.target
    }

    // MARK: Letting go

    /// The finger left the handle, and that is the whole of "put them here".
    ///
    /// This used to only stop the tracking: the kid stayed in the air until "Drop here" was
    /// pressed. `GroupsMove.swift`'s header carries the argument for the change; what it costs
    /// is that a release now has three answers rather than one, and they are all here.
    ///
    /// A release over the boundary the kid already stands either side of asks for nothing, and
    /// is a cancel — the card travels home rather than spending a write to produce the ladder
    /// that is already on screen. A release inside their own court commits immediately. A
    /// release on another court parks the card on the space it has opened and asks.
    private func endTracking() {
        guard var updated = move, updated.isDragging else { return }
        updated.isDragging = false
        stopAutoscroll()

        // A release with nothing aimed at is a release over a list that measured nothing, which
        // is not something to write.
        guard let slot = updated.target, !updated.isNoop(slot) else {
            cancelMove()
            return
        }

        move = updated
        // Only on the path that is about to ask. A commit tears the move down in the same pass,
        // so parking the card first would animate it into a space that is about to close. Said
        // here rather than handed to `requestLanding` as a closure: this is the same comparison
        // it makes, and it is legible at the call site that lets go of the kid.
        if slot.landing.groupID != updated.sourceGroupID { park(on: slot) }
        requestLanding(updated.row, to: slot.landing)
    }

    /// Settling the carried card onto the space that has opened for it.
    ///
    /// The one place in the app where `GroupsGhost.top` is evaluated at runtime — everywhere
    /// else the same arithmetic is played by the layout itself. Top rather than middle because
    /// that is the relationship a lift already has: at the moment of pick-up `translation` is 0
    /// and the card sits exactly over the row's top edge.
    ///
    /// This was `aim(at:)`, which is what tapping a group's card did while a kid hung in the
    /// air. Nothing taps a card mid-move any more — a move only outlives the finger while a
    /// court change is being confirmed, and a dialog has the screen then — so the arithmetic has
    /// moved to the moment it is now worth playing. The card lands in the space it is going to
    /// and stays there while the question is read, which is what makes even the drop that asks
    /// first look like a row dropping into place.
    private func park(on slot: GroupsDropSlot) {
        guard var updated = move else { return }
        updated.translation = GroupsGhost.top(of: slot, lifted: updated.origin) - updated.origin.minY
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) { move = updated }
    }

    /// The gesture was taken away rather than finished.
    ///
    /// Only a move still being carried is torn down, and the guard is not defensive — it is the
    /// whole point. `@GestureState` resets *after* `onEnded` has run, so this fires on an
    /// ordinary release too, and by then the release has either committed (there is nothing left
    /// to cancel) or parked the kid over a question. Answering that question on the reader's
    /// behalf, one frame after they lifted their finger, would make the confirmation impossible
    /// to reach at all.
    private func cancelTracking() {
        guard move?.isDragging == true else { return }
        cancelMove()
    }

    /// Putting the kid back. Animated, unlike a commit: the rows closing over the space again
    /// and the card returning to the row it came out of is exactly the story a cancel is
    /// telling, and `body`'s `value: move == nil` animation is what plays it.
    ///
    /// Guarded, because two of its callers fire on every keystroke in the search field.
    private func cancelMove() {
        guard move != nil else { return }
        endMove()
    }

    /// Everything a move turns on, turned off. Shared by the commit and the cancel so that
    /// neither can forget one of them.
    private func endMove() {
        // Only the cards this move opened, and read before the move that knows them is cleared.
        if let unfolded = move?.unfolded { expandedGroupIDs.subtract(unfolded) }
        move = nil
        stopAutoscroll()
        // Guarded for the same reason `perform` guards `errorMessage`: `@Observable` does not
        // compare before it fires, and this is read by `MainTabView.body`.
        if store.isFocused { store.isFocused = false }
    }

    // MARK: The list coming to the finger

    /// The loop that walks the list while the carried card sits near an edge.
    ///
    /// A tick rather than one animated scroll to a computed destination, because there is no
    /// destination: how far the list should travel depends on where the finger is *now*, and the
    /// finger is still moving. Sixteen milliseconds is one frame, and the step is small enough at
    /// that rate to read as a scroll rather than as a series of jumps.
    private func startAutoscroll() {
        autoscroll?.cancel()
        autoscroll = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: GroupsAutoscroll.tick)
                guard !Task.isCancelled else { return }
                tickAutoscroll()
            }
        }
    }

    private func stopAutoscroll() {
        autoscroll?.cancel()
        autoscroll = nil
    }

    /// Ask the list for one more step towards the finger.
    ///
    /// The tick only *asks*. What the list actually did arrives through `creditListTravel(_:)`,
    /// and the split is the load-bearing part: crediting the carried card with the step that was
    /// requested would be a guess about a scroll view. At either end of the content it takes
    /// none, on macOS there is nothing driving it at all (`GroupsListScroll`), and a card
    /// credited with travel the list never made runs away from the finger a step per frame until
    /// it is aiming at a group nobody can see. Asking is cheap and idempotent — the destination
    /// is absolute, so requesting the same one twice while the geometry catches up costs nothing.
    private func tickAutoscroll() {
        guard let move, move.isDragging, !move.awaitingGeometry else { return }
        guard let destination = GroupsAutoscroll.destination(
            carrying: move.carried,
            in: viewport.value
        ) else { return }
        listScroll.scroll(to: destination)
    }

    /// The list moved under a finger that did not, so the card moved.
    ///
    /// Both numbers carry it: `translation` is where the card is drawn, and `listTravel` is what
    /// the gesture's next reading is re-based on — the drag measures in `.global` and has no idea
    /// the content slid underneath it.
    ///
    /// Only while the finger is down. A step still in flight when the finger leaves is left
    /// uncredited on purpose: `endTracking` has already read the target and settled the card on
    /// it, and moving the aim after the reader has let go would land the kid somewhere they never
    /// pointed at. The most that costs is one tick of list — `GroupsAutoscroll.maxStep`, a third
    /// of a row — and only when a release interrupts a scroll that is still running.
    private func creditListTravel(_ travelled: CGFloat) {
        guard travelled != 0, var updated = move, updated.isDragging, !updated.awaitingGeometry
        else { return }

        updated.translation += travelled
        updated.listTravel += travelled
        retarget(&updated)
        move = updated
    }

    // MARK: The rotor

    /// The rotor equivalent of the drag, so the ladder is reorderable without a pointer.
    ///
    /// Through the same landing as the drag rather than a `reorder` of its own: the old screen's
    /// version handed `store.reorder` the *filtered* rows, so nudging one of two search results
    /// hoisted both of them to the top of the group.
    ///
    /// **Widened past the card it starts in.** "Move up" on the kid at the top of Group 2 used to
    /// do nothing at all, which meant the only non-pointer route through this screen stopped at
    /// exactly the boundary the gesture exists to cross — a VoiceOver reader could reorder a
    /// court and never move anybody between two. At the head of a card it lands at the back of
    /// the card above; at the foot of one, at the front of the card below. The same step, said
    /// one card along.
    private func nudge(_ row: PlayerRow, in entry: GroupsEntry, by offset: Int) {
        guard let landing = landing(nudging: row, in: entry, by: offset) else { return }
        requestLanding(row, to: landing)
    }

    /// Where one step up or down puts a kid, inside their card or past the end of it.
    ///
    /// Split from `nudge` so that both answers reach the store through one call: a change to how
    /// a rotor nudge commits — the confirmation rule, what it counts as coming *from* — has one
    /// place to be made rather than the in-card one people find and the boundary one they do not.
    private func landing(nudging row: PlayerRow, in entry: GroupsEntry, by offset: Int) -> GroupsLanding? {
        guard let index = entry.card.rows.firstIndex(where: { $0.id == row.id }) else { return nil }
        let destination = index + offset

        guard entry.card.rows.indices.contains(destination) else {
            return landingInCardBeside(entry, by: offset)
        }

        // Moving up lands above the neighbour being passed. Moving down lands above whoever is
        // beyond them — or at the back of the group, when there is nobody.
        let anchor: Player.ID? = offset < 0
            ? entry.card.rows[destination].id
            : entry.card.rows.indices.contains(destination + 1)
                ? entry.card.rows[destination + 1].id
                : nil

        return GroupsLanding(groupID: entry.id, venueID: entry.card.group.venueID, anchor: anchor)
    }

    /// A nudge that has run out of card: the step carries on into the next one along.
    ///
    /// The venue's own card order is what "above" and "below" mean here, and it is the order the
    /// screen draws — so a reader hearing "Group 2" under "Group 1" gets the card they were told
    /// about. Up joins the back of the card above and down the front of the card below, which
    /// either way puts the kid beside the row they were already next to. An empty card below
    /// takes them at its back, which `GroupsLandingPlan` already reads as "the back of a group
    /// with nobody in it".
    private func landingInCardBeside(_ entry: GroupsEntry, by offset: Int) -> GroupsLanding? {
        let venueEntries = entries(in: selectedVenue)
        guard let here = venueEntries.firstIndex(where: { $0.id == entry.id }),
              venueEntries.indices.contains(here + offset)
        else { return nil }

        let neighbour = venueEntries[here + offset]
        return GroupsLanding(
            groupID: neighbour.id,
            venueID: neighbour.card.group.venueID,
            anchor: offset < 0 ? nil : neighbour.card.rows.first?.id
        )
    }

    // MARK: - Committing

    /// One drop's decision: write it, or ask about it first.
    ///
    /// **The confirmation is only for a change of court.** Reordering inside a court is a change
    /// of place in a list the reader is looking at, it is undone by dragging the row back, and a
    /// dialog in front of the common gesture would make the cheap thing the expensive one.
    /// Changing court is the drop a slip of the thumb near a card boundary actually produces,
    /// and it moves the kid's band in the camp ladder as well as their card — which is the one
    /// part of a landing the row itself does not say. So that is the one that asks.
    ///
    /// The `from:` group it used to take has gone. It was the second half of a comparison the
    /// confirmation dialog made — "is this a change of court?" — and nothing has asked since that
    /// dialog was removed; keeping it meant every caller naming a group the body never read, and
    /// one of those callers now has no group to name.
    private func requestLanding(_ row: PlayerRow, to landing: GroupsLanding) {
        // A landing in a group this venue does not have is not something to write.
        guard card(landing.groupID) != nil else {
            cancelMove()
            return
        }

        // Crossing to another court commits like any other drop — **no confirmation**.
        //
        // There used to be a "Move Ava R to Court 2?" dialog here, on the reasoning that a move
        // between courts is a bigger fact than a move within one. It is, and it is still not worth
        // a modal: crossing courts *is* the thing this gesture exists to do, so the dialog fired on
        // the ordinary case rather than the exceptional one. Sorting a venue means thirty of these
        // in a row, and thirty dialogs is not a sort, it is an interrogation.
        //
        // The design agrees and never draws one (`state1.js:449`, `applyMove` writes immediately).
        // What it offers instead is the thing a reader actually wants after a wrong drop, which is
        // to put the kid back — and that is one drag, in a list that has not moved, with the kid's
        // old neighbours still on screen. A drop is cheap to undo by hand precisely because this
        // screen keeps everything visible while you work.
        commit(row, to: landing)
    }

    /// The one place an order is written, whether a finger or the rotor asked for it.
    ///
    /// Section 8 folds ranking into this screen, so a move is a change to the **camp ladder**
    /// first and to the group second. Writing `courtRank` alone would land the kid in the right
    /// card wearing the wrong number, leave the band under the group's name reading a range with
    /// a hole in it, and make the "Drops in at #9" the target card promised a lie — every
    /// numeral on this screen is `overallRank`. `GroupsLandingPlan` produces both orders from one
    /// landing, and `AppStore.land` writes both as one intent.
    ///
    /// The two used to be awaited one after the other from here, and that is what "not
    /// intuitive/responsive" was: the row snapped home, the screen sat still for two serialised
    /// round trips, and the kid reappeared somewhere else a second later. `land` applies the plan
    /// to the graph before it writes anything, so the ladder the move is torn down into is
    /// already the one the drop asked for.
    private func commit(_ row: PlayerRow, to landing: GroupsLanding) {
        guard let camp = store.camp, card(landing.groupID) != nil else {
            cancelMove()
            return
        }

        // The arithmetic itself is in `GroupsLandingPlan`, which is where it can be tested — it
        // needs neither the store, the environment nor the main actor, and this is the one piece
        // of section 8 that can put a kid on the wrong court with nothing on screen looking wrong.
        guard let plan = GroupsLandingPlan(
            moving: row.id,
            to: landing,
            ladder: store.rankAssignments(),
            roster: camp.players(inGroup: landing.groupID)
        ) else {
            cancelMove()
            return
        }

        // The shift is not animated, and this is the one asymmetry with `cancelMove()`. The move
        // is being torn down into a graph that already holds the drop, so animating it would play
        // the *old* layout — the space closing, the source card growing its row back, the cards
        // folding again — over a list that has already renumbered itself. This flag is read by
        // the inner `.animation(_:value: move?.target)`, which is scoped to the cards and so wins
        // for them; the header swapping back out of "Moving Austin" is outside it and still
        // travels. Set in the same pass that clears the move; `beginMove` clears it again.
        isDropping = true
        endMove()

        Task { await store.land(plan, in: landing.groupID) }
    }
}

// MARK: - Previews

#Preview("Groups") {
    GroupsView()
        .environment(AppStore.preview)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Groups — second venue") {
    let store = AppStore.preview
    store.venueFilter = .venue(SampleData.latc.id)

    return GroupsView()
        .environment(store)
        .frame(width: 402, height: 874)
}

#Preview("Groups — searching") {
    let store = AppStore.preview
    store.searchText = "Liam"

    return GroupsView()
        .environment(store)
        .frame(width: 402, height: 874)
}

#Preview("Groups — no matches") {
    let store = AppStore.preview
    store.searchText = "Zzzz"

    return GroupsView()
        .environment(store)
        .frame(width: 402, height: 874)
}

/// The rank column and every 44pt row at the app's ceiling. A two-digit place that truncates
/// here is a two-digit place that truncates on a real reader's phone.
#Preview("Groups — large type") {
    GroupsView()
        .environment(AppStore.preview)
        .dynamicTypeSize(.accessibility1)
        .frame(width: 402, height: 874)
}

#Preview("Groups — dark") {
    GroupsView()
        .environment(AppStore.preview)
        .preferredColorScheme(.dark)
        .frame(width: 402, height: 874)
}

// MARK: - Which venue the even-out sheet is asking about

/// A `Venue.ID` that `.sheet(item:)` will accept.
///
/// `UUID` is not `Identifiable` and should not be made so app-wide: `id` would then mean "itself"
/// on every uuid in the project, which is true and useless, and would let any of them be handed to
/// a presentation modifier by accident. One named wrapper at the one call site that needs it says
/// what is being presented instead.
private struct EvenOutTarget: Identifiable {
    let id: Venue.ID
}

// MARK: - Which group the removal is asking about

/// The group a confirmation is standing over, and both numbers its sentence needs.
///
/// It carries its own copy of the group's number and head-count rather than reaching back through
/// the entry, for the reason the move's old confirmation carried its own: the sentence has to
/// survive the thing it is about. `store.removeGroup` is optimistic, so the moment the destructive
/// button is pressed the card is gone from `groupsSections` — and a message assembled from a group
/// that no longer exists reads "Removes  and leaves 0 kids".
extension View {

    /// "Remove Group 2?" — asked before a group with kids in it goes.
    ///
    /// A modifier of its own rather than four more lines on `GroupsView.body`, and the reason is
    /// mechanical rather than tidiness: that `body` is a twenty-modifier chain that the type
    /// checker already gives up on when anything is added to it. Extracting the presentation moves
    /// its inference out of that expression entirely.
    ///
    /// Only a group with kids in it ever gets here. An empty one is a slot somebody added and did
    /// not fill, undone by the "Add a group" row directly underneath — a dialog in front of that is
    /// a dialog in front of nothing. A group with kids is different: the kids do not go with it,
    /// they are left standing at the venue with no group, and how many of them is the one fact the
    /// swipe cannot show you. See `GroupsView.requestRemoval(of:)`.
    fileprivate func removalConfirmation(
        target: GroupDeletion?,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (Group.ID) -> Void
    ) -> some View {
        confirmationDialog(
            target.map { "Remove \($0.title)?" } ?? "",
            isPresented: isPresented,
            titleVisibility: .visible,
            presenting: target
        ) { target in
            Button("Remove group", role: .destructive) { onConfirm(target.id) }
        } message: { target in
            Text(target.message)
        }
    }
}

private struct GroupDeletion: Identifiable {
    let id: Group.ID
    let number: Int
    /// The group's whole roster, not the rows a search left on screen. See `requestRemoval(of:)`.
    let kids: Int

    var title: String { "Group \(number)" }

    /// What actually happens, said in the terms the reader is worried about. Not "this cannot be
    /// undone", which is the stock line and is also false — the kids are all still here, and
    /// dragging them into a new group puts everything back.
    var message: String {
        "\(kids) kid\(kids == 1 ? "" : "s") will stay at this venue with no group until you "
            + "place them. The other groups renumber."
    }
}
