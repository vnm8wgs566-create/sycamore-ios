//
//  RankView.swift
//  Sycamore
//
//  Screen 6 — one ladder for the whole camp, 1 to N, best at the top. Venue sections are
//  separated by a 1.5pt ink rule; a kid dragged across that rule changes venue, which is
//  the whole point of the screen.
//
//  The reorder is hand-rolled rather than `List`/`onMove` because the design is specific
//  about what a drag looks like: the row lifts into an inset accent-bordered card with a
//  shadow, and a 2.5pt accent bar marks where it will land. Both are drawn as overlays on
//  the list content so nothing in the flow shifts while a finger is down.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RankView: View {

    let store: AppStore

    /// Venues whose folded middle the user has opened. Sections start folded.
    @State private var expandedVenueIDs: Set<Venue.ID> = []
    /// Row rectangles in `listSpace`, the raw material for every drop calculation.
    @State private var rowFrames: [Player.ID: CGRect] = [:]
    @State private var drag: RankDrag?
    /// True for exactly as long as a lift is live. A sequenced gesture that is *cancelled*
    /// never calls `onEnded`, so this is what guarantees the lifted row is torn down —
    /// without it a flick off the handle leaves a row stuck in its lifted state.
    @GestureState private var isDragging = false

    /// The list content's own coordinate space. Frames measured here are independent of
    /// the scroll offset, so a drop slot computed at lift time stays valid.
    private static let listSpace = "rank.list"
    /// A folded section shows this many rows at the top and this many at the bottom.
    private static let headRows = 4
    private static let tailRows = 1

    init(store: AppStore) {
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()
            header
            ladder
        }
        .background(Theme.surface)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Rank")
                    .typeStyle(.tabTitle, color: Theme.ink)
                Spacer(minLength: 0)
                Pill("Even out") {
                    Task { await store.evenOut() }
                }
            }

            Text("One list for the whole camp, best at the top. Drag a kid across a venue line and they change venue.")
                .typeStyle(.bodySmall, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.small)
        }
        .padding(.horizontal, Spacing.bar)
        .padding(.top, 14)
        .padding(.bottom, 15)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    // MARK: - The ladder

    private var ladder: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.rankSections) { section in
                    heading(for: section)
                    rows(for: section)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Spacing.tabBarClearance)
            .coordinateSpace(name: Self.listSpace)
            .overlay(alignment: .top) { dropIndicator }
            .overlay(alignment: .top) { liftedRow }
            .onPreferenceChange(RankRowFrames.self) { frames in
                Task { @MainActor in
                    rowFrames = frames
                    refreshDragGeometry()
                }
            }
        }
        .scrollDisabled(drag != nil)
        // Safety net for a cancelled lift, which never reaches `onEnded`. Committing here
        // would double-commit, so this only tears the lift down; a real drop still goes
        // through `onEnded`.
        .onChange(of: isDragging) { _, active in
            guard !active, let stranded = drag else { return }
            drag = nil
            if stranded.refoldOnEnd { expandedVenueIDs.remove(stranded.sourceVenueID) }
        }
    }

    /// Emoji, venue name, the block's slice of the ladder, then the ink rule.
    private func heading(for section: RankSection) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Text(section.venue.icon)
                    .font(.system(size: 20))
                Text(section.venue.name)
                    .typeStyle(.venueHeading, color: Theme.ink)
                Spacer(minLength: 0)
                Text(section.rangeLabel)
                    .typeStyle(.metaSmall, color: Theme.inkFaint)

                // Only once a section is open. The design draws the folded state and gives
                // no way back out of the expanded one, so this appears in a state the design
                // does not draw and leaves the default screen exactly as designed.
                if isFoldable(section), expandedVenueIDs.contains(section.id) {
                    Button {
                        withAnimation(.snappy(duration: 0.24)) {
                            _ = expandedVenueIDs.remove(section.id)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.chevron)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fold \(section.venue.name)")
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 7)

            Hairline(color: Theme.ink, thickness: BorderWidth.rule)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, Spacing.bar)
    }

    @ViewBuilder
    private func rows(for section: RankSection) -> some View {
        let slices = slices(for: section)

        ForEach(slices.head) { entry in
            playerRow(entry.row)
        }

        if slices.hidden > 0 {
            collapsedRun(for: section, hidden: slices.hidden)
            ForEach(slices.tail) { entry in
                playerRow(entry.row)
            }
        }
    }

    private func playerRow(_ row: PlayerRow) -> some View {
        rowContent(row, isLifted: false)
            .overlay(alignment: .top) { Hairline(color: Theme.hairlineFaint) }
            // The lifted copy is drawn in an overlay; the original stays in the flow so the
            // measured geometry — and therefore every drop slot — holds still mid-drag.
            .opacity(drag?.row.id == row.id ? 0 : 1)
            .background(frameReader(for: row.id))
            .contentShape(Rectangle())
            .onTapGesture { store.present(.player(row.id)) }
    }

    /// Shared by the in-flow row and the lifted card, which differ only in tint.
    private func rowContent(_ row: PlayerRow, isLifted: Bool) -> some View {
        HStack(spacing: 11) {
            Text("\(row.rank)")
                .typeStyle(.rankNumeral, color: isLifted ? Theme.accent : Theme.inkGhost)
                .frame(width: 28, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.player.displayName)
                    .typeStyle(.bodyStrong, color: Theme.ink)
                Text(row.player.metaLine)
                    .typeStyle(.meta, color: Theme.inkMuted)
            }

            Spacer(minLength: 0)

            handle(for: row, isLifted: isLifted)
        }
        .padding(.leading, Spacing.bar)
        .padding(.trailing, 13)
        .padding(.vertical, 10)
    }

    private func handle(for row: PlayerRow, isLifted: Bool) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(isLifted ? Theme.accent : Theme.chevron)
            .frame(width: 22, height: 38)
            .contentShape(Rectangle())
            .gesture(dragGesture(for: row))
            .accessibilityLabel("Reorder \(row.player.displayName)")
    }

    /// `45 MORE IN SYCAMORE` — the strip that stands in for a folded run.
    private func collapsedRun(for section: RankSection, hidden: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) { _ = expandedVenueIDs.insert(section.id) }
        } label: {
            Text(store.camp?.collapsedRunLabel(for: section.id, hidden: hidden) ?? "")
                .typeStyle(.overline, color: Theme.inkGhost)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.bar)
                .padding(.vertical, 9)
                .background(Theme.runBackground)
                .overlay(alignment: .top) { Hairline(color: Theme.hairlineFaint) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drag overlays

    /// The 2.5pt accent bar marking where the row will land.
    @ViewBuilder
    private var dropIndicator: some View {
        if let slot = drag?.slot {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.accent)
                .frame(height: BorderWidth.insertion)
                .padding(.horizontal, Spacing.gutter)
                // The bar straddles the boundary rather than sitting under it.
                .offset(y: slot.y - BorderWidth.insertion / 2)
        }
    }

    /// The row itself, lifted out of the list: inset 12 either side, accent border, shadow.
    @ViewBuilder
    private var liftedRow: some View {
        if let drag {
            let shape = RoundedRectangle(cornerRadius: Radius.chipSquare, style: .continuous)

            rowContent(drag.row, isLifted: true)
                .background {
                    shape
                        .fill(Theme.surface)
                        .shadow(Shadows.liftedRow)
                }
                .overlay(shape.strokeBorder(Theme.accent, lineWidth: BorderWidth.input))
                .padding(.horizontal, Spacing.gutter)
                .offset(y: drag.origin.minY + drag.translation)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Measuring

    private func frameReader(for id: Player.ID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: RankRowFrames.self,
                value: [id: proxy.frame(in: .named(Self.listSpace))]
            )
        }
    }

    // MARK: - Folding

    private struct RankEntry: Identifiable {
        let row: PlayerRow
        /// Position in the section's *full* row list, which is what a drop index means.
        let index: Int
        var id: Player.ID { row.id }
    }

    private struct RankSlices {
        var head: [RankEntry]
        var hidden: Int
        var tail: [RankEntry]
    }

    /// Folding one row away would cost more space than it saves.
    private func isFoldable(_ section: RankSection) -> Bool {
        section.rows.count - Self.headRows - Self.tailRows > 1
    }

    private func slices(for section: RankSection) -> RankSlices {
        let entries = section.rows.enumerated().map { RankEntry(row: $1, index: $0) }
        let foldedCount = entries.count - Self.headRows - Self.tailRows

        guard !expandedVenueIDs.contains(section.id), foldedCount > 1 else {
            return RankSlices(head: entries, hidden: 0, tail: [])
        }
        return RankSlices(
            head: Array(entries.prefix(Self.headRows)),
            hidden: foldedCount,
            tail: Array(entries.suffix(Self.tailRows))
        )
    }

    // MARK: - Dragging

    private func dragGesture(for row: PlayerRow) -> some Gesture {
        // The long press is what lets the drag win against the enclosing scroll view.
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.listSpace)))
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    beginDrag(row)
                case .second(true, let gesture?):
                    updateDrag(to: gesture.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in
                let finished = drag
                drag = nil
                guard let finished else { return }
                if finished.refoldOnEnd { expandedVenueIDs.remove(finished.sourceVenueID) }
                Task { await commit(finished) }
            }
    }

    private func beginDrag(_ row: PlayerRow) {
        // Deliberately not guarded on `drag == nil`: a gesture that was cancelled rather
        // than ended leaves stale state behind, and overwriting it beats deadlocking the
        // list, which stays unscrollable for as long as a drag is live.
        guard let origin = rowFrames[row.id],
              let section = store.rankSections.first(where: { section in
                  section.rows.contains { $0.id == row.id }
              }),
              let index = section.rows.firstIndex(where: { $0.id == row.id })
        else { return }

        // A folded section only renders its first four rows and its last, so only those
        // produce drop slots — everything between rank 5 and rank 49 would be unreachable,
        // which is most of the ladder the header invites you to drag through. Unfold the
        // section being dragged for the duration of the lift, and fold it back after.
        let wasFolded = !expandedVenueIDs.contains(section.id) && isFoldable(section)
        if wasFolded { expandedVenueIDs.insert(section.id) }

        // With scrolling off, geometry only moves when *we* move it — which is exactly what
        // the unfold above does, hence `awaitingGeometry`. Otherwise the slots captured here
        // stay valid for the whole drag.
        drag = RankDrag(
            row: row,
            sourceVenueID: section.id,
            sourceIndex: index,
            origin: origin,
            slots: dropSlots(),
            refoldOnEnd: wasFolded,
            awaitingGeometry: wasFolded
        )
        hapticTick(strong: true)
    }

    /// Recapture the frames after an unfold, and shift `translation` by exactly as much as
    /// the row's origin moved, so the lifted card stays under the finger instead of jumping
    /// to wherever the row now sits in the flow.
    private func refreshDragGeometry() {
        guard var state = drag, state.awaitingGeometry,
              let origin = rowFrames[state.row.id],
              let section = store.rankSections.first(where: { $0.id == state.sourceVenueID })
        else { return }

        // Wait for the unfolded rows to actually be measured. Testing the dragged row's own
        // origin for movement is not the signal: unfolding a section adds rows *below* a
        // head row, which is the common case, and leaves its origin exactly where it was.
        guard section.rows.allSatisfy({ rowFrames[$0.id] != nil }) else { return }

        state.translation += state.origin.minY - origin.minY
        state.origin = origin
        state.slots = dropSlots()
        state.awaitingGeometry = false
        drag = state
    }

    private func updateDrag(to translation: CGFloat) {
        guard var state = drag else { return }
        state.translation = translation

        // Aim with the middle of the lifted card rather than the fingertip.
        let centre = state.origin.midY + translation
        let nearest = state.slots.min { abs($0.y - centre) < abs($1.y - centre) }
        if nearest != state.slot { hapticTick() }
        state.slot = nearest

        drag = state
    }

    /// A boundary above and below every visible row. Adjacent rows produce two slots at
    /// almost the same place with the same index, which a nearest-neighbour search does
    /// not mind, and it means a folded run is bracketed by the right two indices.
    private func dropSlots() -> [RankDropSlot] {
        var slots: [RankDropSlot] = []
        for section in store.rankSections {
            let visible = slices(for: section)
            for entry in visible.head + visible.tail {
                guard let frame = rowFrames[entry.row.id] else { continue }
                slots.append(RankDropSlot(venueID: section.id, index: entry.index, y: frame.minY))
                slots.append(RankDropSlot(venueID: section.id, index: entry.index + 1, y: frame.maxY))
            }
        }
        return slots
    }

    private func commit(_ state: RankDrag) async {
        guard let slot = state.slot else { return }

        // Landing either side of where the kid already stands is not a move.
        let isNoop = slot.venueID == state.sourceVenueID
            && (slot.index == state.sourceIndex || slot.index == state.sourceIndex + 1)
        guard !isNoop else { return }

        var assignments = store.rankAssignments()
        guard let target = assignments.firstIndex(where: { $0.venueID == slot.venueID }) else { return }

        for index in assignments.indices {
            assignments[index].playerIDs.removeAll { $0 == state.row.id }
        }

        // Pulling the kid out first shifts every later index in that same venue down one.
        var insertion = slot.index
        if slot.venueID == state.sourceVenueID, state.sourceIndex < slot.index { insertion -= 1 }
        insertion = min(max(0, insertion), assignments[target].playerIDs.count)
        assignments[target].playerIDs.insert(state.row.id, at: insertion)

        await store.commitRankOrder(assignments)
    }

    // `UIFeedbackGenerator` is main-actor-isolated, so this cannot be nonisolated even
    // though every caller already runs on the main actor.
    @MainActor
    private func hapticTick(strong: Bool = false) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: strong ? .medium : .light).impactOccurred()
        #endif
    }
}

// MARK: - Drag state

/// Where a row will land: a venue and an insertion index inside that venue's full ladder.
private struct RankDropSlot: Equatable {
    let venueID: Venue.ID
    let index: Int
    let y: CGFloat
}

private struct RankDrag {
    let row: PlayerRow
    let sourceVenueID: Venue.ID
    let sourceIndex: Int
    /// The row's rectangle, in the list's coordinate space. Re-anchored if the section
    /// unfolds under the finger, which moves every frame below the fold.
    var origin: CGRect
    var slots: [RankDropSlot]
    var translation: CGFloat = 0
    var slot: RankDropSlot?
    /// The section was folded when this drag began, so fold it back when the drag ends.
    var refoldOnEnd: Bool = false
    /// Set when the lift unfolded a section: the frames captured a moment ago describe the
    /// folded layout and must be recaptured once SwiftUI has laid the full ladder out.
    var awaitingGeometry: Bool = false
}

private struct RankRowFrames: PreferenceKey {
    static let defaultValue: [Player.ID: CGRect] = [:]

    static func reduce(value: inout [Player.ID: CGRect], nextValue: () -> [Player.ID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Previews

#Preview("Rank") {
    RankView(store: .preview)
        .showsMockStatusBar()
}

// Named for what it shows. A genuine mid-drag preview would need the drag state injected,
// which `RankView` keeps private; the lifted-row and insertion-bar treatment are exercised
// by running the app, not by this.
#Preview("Rank — no status bar") {
    RankView(store: .preview)
}
