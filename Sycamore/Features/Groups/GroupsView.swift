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
//  lands in another. It owns the lifted card, the insertion bar, every card's rectangle and
//  every drawn row's, and it is the only thing that writes to the store.
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
    /// the only moment it could matter again. See `drop()`.
    @State private var isDropping = false
    /// Card and row rectangles in `GroupsSpace.list` — the raw material for every drop slot.
    @State private var cardFrames: [Group.ID: CGRect] = [:]
    @State private var rowFrames: [Player.ID: CGRect] = [:]
    /// Whether the enrolment flow is up. Presented **here** rather than through
    /// `store.activeSheet` or a `PushedScreen` case — see `enrolmentFlow`.
    @State private var isEnrolling = false

    var body: some View {
        @Bindable var store = store
        let venue = selectedVenue
        let entries = entries(in: venue)

        return VStack(spacing: 0) {
            StatusBarMock()

            GroupsHeader(
                store: store,
                selectedVenueID: venue?.id,
                movingName: move?.row.player.displayName,
                isLocked: isLocked,
                count: headerCount
            )

            content(entries, venue: venue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, which is a touch warmer than the `grouped` every other tab draws. Section 8
        // gives this screen its own page colour; see the PR for why it is not `Theme.grouped`.
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { moveBar }
        .fullScreenPresentation(isPresented: $isEnrolling) { enrolmentFlow }
        .animation(Motion.fold(reduceMotion: reduceMotion), value: move == nil)
        // A filter that changes under a kid in the air can take their group off the screen.
        .onChange(of: store.searchText) { move = nil }
        .onChange(of: store.venueFilter) { move = nil }
        // The lift itself — one firmer tap as the kid leaves the ladder.
        .sensoryFeedback(trigger: move?.row.id) { previous, current in
            previous == nil && current != nil ? .impact(weight: .medium) : nil
        }
        // And a lighter one each time they cross a boundary on the way to somewhere else.
        .sensoryFeedback(trigger: move?.target ?? nil) { _, current in
            current != nil ? .impact(weight: .light) : nil
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func content(_ entries: [GroupsEntry], venue: Venue?) -> some View {
        if isLocked {
            GroupsLockedState(store: store, onAddKids: beginEnrolment)
        } else {
            list(entries, venue: venue)
        }
    }

    // MARK: - Enrolment

    /// `8c` and everything past it, over the whole frame.
    ///
    /// Presented from this view rather than through the store, and there are two rejected
    /// alternatives worth naming.
    ///
    /// **Not `ActiveSheet`.** That slot is presented by `MainTabView` (`RootView.swift:95`), and
    /// Camp settings — the other entry point — is itself presented by `MainTabView`. Asking it to
    /// present would open the flow *behind* the screen that asked for it. `BlockEditorSheet`
    /// (`:26-33`) reached the same conclusion for the same reason.
    ///
    /// **Not a new `PushedScreen` case.** `pushedScreen` is a single slot (`AppStore.swift:79`)
    /// that Camp settings already occupies, and evicting it is survivable — but with two entry
    /// points the *return address* varies, and carrying it in the payload would make
    /// `PushedScreen.id` encode a destination as well as a screen, which is not what the comment
    /// at `AppStore.swift:109-112` says `id` is for.
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
                ForEach(entries) { entry in
                    cardView(entry)
                }

                // Inside the list rather than instead of it, so a venue that has been searched
                // down to nothing still offers the one thing you can do about that.
                if entries.isEmpty {
                    nothingHere
                }

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
        // Only while a finger is actually on the handle. The rest of the time a kid in the air
        // stays there, and scrolling to the group they are going to is the whole point.
        .scrollDisabled(move?.isDragging == true)
    }

    private func cardView(_ entry: GroupsEntry) -> some View {
        GroupCard(
            card: entry.card,
            summary: entry.summary,
            visibleRows: entry.visibleRows,
            move: move,
            onToggle: { toggle(entry.id) },
            onOpenPlayer: { store.pushedScreen = .player($0.id) },
            onAim: { aim(at: entry.id) },
            onMoveBegan: { beginMove($0, in: entry) },
            onMoveChanged: updateMove(to:),
            onMoveEnded: endTracking,
            onNudge: { nudge($0, in: entry, by: $1) },
            // Both frame stores describe the list **at rest**, which is the only state a drop
            // slot can be measured from. A slot is a promise about where a boundary was when
            // the kid was picked up; the moment the rows start shifting, what is on screen is a
            // *consequence* of the target and so cannot be used to choose one. See
            // `GroupsMove.slots`.
            //
            // Nothing reads either dictionary mid-move today — `beginMove` reads both, once,
            // and is the only reader — so this is structure rather than a fix. It also stops
            // `body` re-evaluating on every frame of every shift animation, which is a great
            // many frames now that there is a shift at all.
            onRowFrame: { id, frame in if move == nil { rowFrames[id] = frame } }
        )
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(GroupsSpace.list))
        } action: { frame in
            if move == nil { cardFrames[entry.id] = frame }
        }
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
            let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)

            GroupsRow(
                rank: move.row.player.overallRank,
                rankColor: Theme.accent,
                name: move.row.player.displayName,
                nameStyle: GroupsType.liftedName,
                nameColor: Theme.ink
            ) {
                // Phosphor's filled grip. There is no fill axis on `line.3.horizontal`, so the
                // weight carries what the fill did.
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: GroupsMetrics.handleGlyph, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, GroupsMetrics.cardPadding)
            .padding(.vertical, Spacing.medium)
            .background { shape.fill(Theme.surface).shadow(Shadows.liftedRow) }
            .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline) }
            // Inset past the gutter as well, so the card carrying the kid sits proud of the
            // cards it is travelling over rather than covering one edge to edge.
            .padding(.horizontal, Spacing.gutter + GroupsMetrics.cardPadding)
            .offset(y: move.origin.minY + move.translation)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var moveBar: some View {
        if move != nil {
            GroupsMoveBar(canDrop: move?.target != nil, onCancel: cancelMove, onDrop: drop)
                // The design puts this *in place of* the tab bar, which `RootView` draws rather
                // than the tab that owns it. So it stacks above the pill instead of replacing
                // it — one bar over the other, neither hidden.
                .padding(.bottom, Spacing.tabBarClearance)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

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
                    visibleRows: Array(card.rows.prefix(visible)),
                    tailRank: (range?.upperBound ?? 0) + 1
                )
            } ?? []
    }

    /// Every group's rank range, in one pass over the roster.
    ///
    /// `Camp.players(inGroup:)` filters and sorts the whole player array, so asking it once per
    /// card is O(cards × players) — and `body` runs on every frame of a drag. This is the same
    /// answer in O(players), once.
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
    /// The foot is what makes a group with nothing drawn in it — folded to its header, or
    /// searched down to nothing — somewhere a kid can still be put. It carries the *unfiltered*
    /// row count, which is a different index from the last drawn row's when a card is folded.
    ///
    /// That foot slot's y is the card's own bottom edge, which is `Spacing.tight` below the row
    /// boundary the space actually opens at — so the card carrying the kid parks about six
    /// points low when it is aimed there. Left alone on purpose: this y is what the kid *aims*
    /// with, moving it would move where they land, and the foot slot is what **tapping a card**
    /// means. "Somewhere at the back of this one" is not a request in which six points of
    /// parking is the thing being asked about. The ghost itself is unaffected — it is placed by
    /// layout, at the back of the card's real stack, not by this number.
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

    // MARK: - The move

    private func beginMove(_ row: PlayerRow, in entry: GroupsEntry) {
        guard let origin = rowFrames[row.id],
              let index = entry.card.rows.firstIndex(where: { $0.id == row.id })
        else { return }

        // The last drop's "do not animate this" instruction, spent. Cleared here rather than on
        // a hop off the main actor because this is the next moment `move?.target` changes at
        // all, so it is the first moment the flag could affect anything again — and it is
        // cleared in the same pass that sets the move, so the body that reads the animation
        // sees a live lift and a false flag.
        isDropping = false

        // Deliberately not guarded on `move == nil`: a gesture cancelled rather than ended can
        // leave state behind, and overwriting it beats stranding a kid in the air.
        move = GroupsMove(
            row: row,
            sourceGroupID: entry.id,
            nextRowID: entry.card.rows.indices.contains(index + 1)
                ? entry.card.rows[index + 1].id
                : nil,
            origin: origin,
            slots: slots(for: entries(in: selectedVenue)),
            isDragging: true,
            // Aimed at where they already stand, so the first frame of a lift is not a screen
            // with a bar and no target on it.
            target: GroupsDropSlot(
                landing: GroupsLanding(
                    groupID: entry.id,
                    venueID: entry.card.group.venueID,
                    anchor: row.id
                ),
                y: origin.minY,
                rank: row.player.overallRank
            )
        )
    }

    private func updateMove(to translation: CGFloat) {
        guard var updated = move else { return }
        updated.translation = translation
        updated.isDragging = true
        // Aim with the middle of the card being carried rather than with the fingertip — the
        // fingertip is on the handle, an inch below what the reader thinks they are pointing at.
        updated.target = updated.nearestSlot() ?? updated.target
        move = updated
    }

    /// The finger left the handle. The kid stays in the air; only the tracking stops.
    private func endTracking() {
        guard var updated = move, updated.isDragging else { return }
        updated.isDragging = false
        move = updated
    }

    /// Tapping a group while a kid is in the air aims at the end of it, and carries the card
    /// over so "where is this kid going" has the same answer however it was asked.
    ///
    /// The card is parked with its **top** on the space that has opened, which is the one place
    /// in the app where `GroupsGhost.top` is evaluated at runtime — everywhere else the same
    /// arithmetic is played by the layout itself. Top rather than middle because that is the
    /// relationship a lift already has: at the moment of pick-up `translation` is 0 and the
    /// card sits exactly over the row's top edge. It also means this returns 0 for the target
    /// `beginMove` starts with, so the two agree on the first frame rather than nudging the
    /// card by half a row before the finger has moved.
    private func aim(at groupID: Group.ID) {
        guard let current = move, let slot = current.lastSlot(in: groupID) else { return }

        var updated = current
        updated.target = slot
        updated.translation = GroupsGhost.top(of: slot, lifted: current.origin) - current.origin.minY
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) { move = updated }
    }

    /// Putting the kid back. Animated, unlike `drop()`: the rows closing over the space again
    /// and the card returning to the row it came out of is exactly the story a cancel is
    /// telling.
    private func cancelMove() {
        move = nil
    }

    private func drop() {
        guard let move, let slot = move.target else { return }

        // Not animated, and this is the one asymmetry with `cancelMove()`. The write below is
        // asynchronous, so between clearing the move and the new ladder arriving there is a
        // window — a whole network round trip against the Supabase repository. Letting the
        // shift animate through it plays the move *backwards*: the space closing, the source
        // card growing its row back, and only then the kid appearing where they were asked to
        // go. Setting this in the same pass that clears the move is what the animation modifier
        // reads; `beginMove` clears it again.
        isDropping = true
        self.move = nil

        // Landing either side of where the kid already stands is not a move.
        guard !move.isNoop(slot) else { return }
        commit(move.row, to: slot.landing)
    }

    /// The rotor equivalent of the drag, so the ladder is reorderable without one.
    ///
    /// Through the same commit as the drag rather than a `reorder` of its own: the old screen's
    /// version handed `store.reorder` the *filtered* rows, so nudging one of two search results
    /// hoisted both of them to the top of the group.
    private func nudge(_ row: PlayerRow, in entry: GroupsEntry, by offset: Int) {
        guard let index = entry.card.rows.firstIndex(where: { $0.id == row.id }) else { return }
        let destination = index + offset
        guard entry.card.rows.indices.contains(destination) else { return }

        // Moving up lands above the neighbour being passed. Moving down lands above whoever is
        // beyond them — or at the back of the group, when there is nobody.
        let anchor: Player.ID? = offset < 0
            ? entry.card.rows[destination].id
            : entry.card.rows.indices.contains(destination + 1)
                ? entry.card.rows[destination + 1].id
                : nil

        commit(row, to: GroupsLanding(
            groupID: entry.id,
            venueID: entry.card.group.venueID,
            anchor: anchor
        ))
    }

    // MARK: - Committing

    /// The one place an order is written, whether a finger or the rotor asked for it.
    ///
    /// Section 8 folds ranking into this screen, so a move is a change to the **camp ladder**
    /// first and to the group second. `store.reorder` writes `courtRank` and leaves
    /// `overallRank` exactly where it was — and every numeral on this screen is `overallRank`.
    /// Committing the group alone would land the kid in the right card wearing the wrong number,
    /// leave the band under the group's name reading a range with a hole in it, and make the
    /// "Drops in at #9" the target card promised a lie. So the ladder goes first, through the
    /// intent the Rank tab used, and the group order follows it.
    private func commit(_ row: PlayerRow, to landing: GroupsLanding) {
        // The card is not read any more — anchoring on an id removed the last reason to — but a
        // landing in a group this venue does not have is still not something to write.
        guard let camp = store.camp, card(landing.groupID) != nil else { return }

        // The arithmetic itself is in `GroupsLandingPlan`, which is where it can be tested — it
        // needs neither the store, the environment nor the main actor, and this is the one piece
        // of section 8 that can put a kid on the wrong court with nothing on screen looking wrong.
        guard let plan = GroupsLandingPlan(
            moving: row.id,
            to: landing,
            ladder: store.rankAssignments(),
            roster: camp.players(inGroup: landing.groupID)
        ) else { return }

        Task {
            await store.commitRankOrder(plan.assignments)
            // `reorder` carries group *and* venue membership, so this is also what moves the kid
            // between cards; `commitRankOrder` only reassigns a group when the venue changed.
            await store.reorder(group: landing.groupID, playerIDs: plan.courtOrder)
        }
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
