//
//  CoachGroupCard.swift
//  Sycamore
//
//  One coach, one court, and the kids on it. Collapsed it is just the header (plus the
//  over-capacity banner, if the court is carrying one); expanded it lists the court's
//  ladder as numbered rows.
//
//  Each player row swipes left to reveal a 130pt "Mark away" action. It is drawn and
//  driven by hand rather than with `.swipeActions` because the design fixes the reveal
//  width, the fill and the type, none of which `.swipeActions` lets you set.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Card

struct CoachGroupCard: View {
    let store: AppStore
    let card: GroupsCoachCard

    /// At most one row is open at a time, so opening a second closes the first.
    @State private var openRowID: Player.ID?
    /// Row rectangles in `rowSpace`, the raw material for the reorder's drop slots.
    @State private var rowFrames: [Player.ID: CGRect] = [:]
    @State private var reorder: CourtReorder?

    /// The rows' own coordinate space, so a slot survives the page scrolling underneath.
    private var rowSpace: String { "groups.card.\(card.id)" }

    private var isCollapsed: Bool { store.isCollapsed(card.id) }

    var body: some View {
        Card(isDivided: false) {
            VStack(spacing: 0) {
                header

                if let banner = card.group.capacityBanner {
                    InfoBanner(
                        banner,
                        systemImage: "exclamationmark.circle",
                        tone: .accent,
                        font: .metaSmall,
                        radius: Radius.banner,
                        horizontalPadding: 11,
                        verticalPadding: 9
                    )
                    .padding(.horizontal, 13)
                    .padding(.bottom, 12)
                }

                if !isCollapsed {
                    VStack(spacing: 0) {
                        ForEach(card.rows) { row in
                            Hairline(color: Theme.hairlineSoft)
                            PlayerSwipeRow(
                                row: row,
                                openRowID: $openRowID,
                                isLifted: reorder?.row.id == row.id,
                                onOpenPlayer: { store.present(.player(row.id)) },
                                onMarkAway: { Task { await store.setAway(row.id, true) } },
                                onReorderBegan: { beginReorder(row) },
                                onReorderChanged: { updateReorder(to: $0) },
                                onReorderEnded: { endReorder() },
                                onAccessibilityMove: { move(row, by: $0) },
                                showsLeavingEarlyBadge: store.playerFilter == .leavingEarly
                            )
                            .background(frameReader(for: row.id))
                        }
                    }
                    .coordinateSpace(name: rowSpace)
                    .overlay(alignment: .top) { dropIndicator }
                    .overlay(alignment: .top) { liftedRow }
                    .onPreferenceChange(CourtRowFrames.self) { frames in
                        Task { @MainActor in rowFrames = frames }
                    }
                }
            }
        }
        // A row left open under a card that then folds away would reappear mid-swipe.
        .onChange(of: isCollapsed) {
            openRowID = nil
            reorder = nil
        }
    }

    // MARK: Reorder

    /// The 2.5pt accent bar marking where the row will land — the same treatment the Rank
    /// tab uses, because it is the same gesture doing the same thing at a smaller scale.
    @ViewBuilder
    private var dropIndicator: some View {
        if let slot = reorder?.slot {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.accent)
                .frame(height: BorderWidth.insertion)
                .padding(.horizontal, 13)
                .offset(y: slot.y - BorderWidth.insertion / 2)
        }
    }

    @ViewBuilder
    private var liftedRow: some View {
        if let reorder {
            let shape = RoundedRectangle(cornerRadius: Radius.chipSquare, style: .continuous)

            PlayerSwipeRow.staticContent(reorder.row, isLifted: true)
                .background {
                    shape
                        .fill(Theme.surface)
                        .shadow(Shadows.liftedRow)
                }
                .overlay(shape.strokeBorder(Theme.accent, lineWidth: BorderWidth.input))
                .padding(.horizontal, 8)
                .offset(y: reorder.origin.minY + reorder.translation)
                .allowsHitTesting(false)
        }
    }

    private func frameReader(for id: Player.ID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CourtRowFrames.self,
                value: [id: proxy.frame(in: .named(rowSpace))]
            )
        }
    }

    private func beginReorder(_ row: PlayerRow) {
        guard let origin = rowFrames[row.id],
              let index = card.rows.firstIndex(where: { $0.id == row.id })
        else { return }

        // A row mid-swipe and a row mid-lift are two different answers to the same touch.
        openRowID = nil
        reorder = CourtReorder(row: row, sourceIndex: index, origin: origin, slots: dropSlots())
        hapticTick(strong: true)
    }

    private func updateReorder(to translation: CGFloat) {
        guard var state = reorder else { return }
        state.translation = translation

        let centre = state.origin.midY + translation
        let nearest = state.slots.min { abs($0.y - centre) < abs($1.y - centre) }
        if nearest != state.slot { hapticTick() }
        state.slot = nearest

        reorder = state
    }

    private func endReorder() {
        let finished = reorder
        reorder = nil
        guard let finished, let slot = finished.slot else { return }

        // Landing either side of where the kid already stands is not a move.
        guard slot.index != finished.sourceIndex, slot.index != finished.sourceIndex + 1 else { return }

        var ids = card.rows.map(\.id)
        ids.removeAll { $0 == finished.row.id }
        // Pulling the kid out first shifts every later index down one.
        var insertion = slot.index
        if finished.sourceIndex < slot.index { insertion -= 1 }
        insertion = min(max(0, insertion), ids.count)
        ids.insert(finished.row.id, at: insertion)

        Task { await store.reorder(group: card.id, playerIDs: ids) }
    }

    /// The rotor equivalent of the drag, so the ladder is reorderable without one.
    private func move(_ row: PlayerRow, by offset: Int) {
        guard let index = card.rows.firstIndex(where: { $0.id == row.id }) else { return }
        let destination = index + offset
        guard card.rows.indices.contains(destination) else { return }

        var ids = card.rows.map(\.id)
        ids.swapAt(index, destination)
        Task { await store.reorder(group: card.id, playerIDs: ids) }
    }

    /// A boundary above and below every row.
    private func dropSlots() -> [CourtDropSlot] {
        card.rows.enumerated().reduce(into: [CourtDropSlot]()) { slots, pair in
            guard let frame = rowFrames[pair.element.id] else { return }
            slots.append(CourtDropSlot(index: pair.offset, y: frame.minY))
            slots.append(CourtDropSlot(index: pair.offset + 1, y: frame.maxY))
        }
    }

    // `UIFeedbackGenerator` is main-actor-isolated, so this cannot be nonisolated even
    // though every caller already runs on the main actor.
    @MainActor
    private func hapticTick(strong: Bool = false) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: strong ? .medium : .light).impactOccurred()
        #endif
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            InitialsAvatar(card.coach?.initials ?? "—", size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.coach?.name ?? "No coach")
                    .typeStyle(.rowTitleLg, color: card.coach == nil ? Theme.inkFaint : Theme.ink)
                    .lineLimit(1)
                Text(card.group.headcountLine)
                    .typeStyle(.metaStrong, color: Theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let phone = card.coach?.phone {
                CircleIconButton(
                    systemName: "phone",
                    size: 32,
                    tone: .bordered,
                    foreground: Theme.accent,
                    borderColor: Theme.hairline
                ) {
                    call(phone)
                }
                .accessibilityLabel("Call \(card.coach?.name ?? "coach")")
            }

            DisclosureChevron(systemName: isCollapsed ? "chevron.down" : "chevron.up", size: 17)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.24)) { store.toggleCollapsed(card.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isCollapsed ? "Show the court" : "Hide the court")
    }

    /// The design's phone glyph is a call button, not a link to the staff sheet.
    @MainActor
    private func call(_ phone: String) {
        let dialable = phone.filter { $0.isNumber || $0 == "+" }
        guard !dialable.isEmpty, let url = URL(string: "tel://\(dialable)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Reorder state

/// Where a row will land: an insertion index inside this court's ladder.
private struct CourtDropSlot: Equatable {
    let index: Int
    let y: CGFloat
}

private struct CourtReorder {
    let row: PlayerRow
    let sourceIndex: Int
    /// The row's rectangle at lift time, in the card's row coordinate space.
    let origin: CGRect
    let slots: [CourtDropSlot]
    var translation: CGFloat = 0
    var slot: CourtDropSlot?
}

private struct CourtRowFrames: PreferenceKey {
    static let defaultValue: [Player.ID: CGRect] = [:]

    static func reduce(value: inout [Player.ID: CGRect], nextValue: () -> [Player.ID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Player row

/// A numbered player row that slides left to uncover the "Mark away" action.
private struct PlayerSwipeRow: View {
    let row: PlayerRow
    @Binding var openRowID: Player.ID?
    /// True while this row is the one being dragged: the original stays in the flow so the
    /// measured geometry holds still, but goes invisible under the lifted copy.
    var isLifted: Bool = false
    let onOpenPlayer: () -> Void
    let onMarkAway: () -> Void
    var onReorderBegan: () -> Void = {}
    var onReorderChanged: (CGFloat) -> Void = { _ in }
    var onReorderEnded: () -> Void = {}
    /// VoiceOver equivalent of the drag: move this row one place up or down.
    var onAccessibilityMove: (Int) -> Void = { _ in }
    /// The design draws no pick-up badge; it earns its place only under that filter.
    var showsLeavingEarlyBadge: Bool = false

    /// Live finger travel, added to the resting offset. Zeroed when the drag settles.
    @State private var dragTranslation: CGFloat = 0
    /// Decided on the first change of a drag and held for its duration, so a swipe that
    /// starts sideways is not handed back to the scroll view halfway through.
    @State private var isHorizontalDrag: Bool?

    /// The design's reveal is exactly 130pt wide.
    private static let actionWidth: CGFloat = 130

    private var isOpen: Bool { openRowID == row.id }
    private var restingOffset: CGFloat { isOpen ? -Self.actionWidth : 0 }

    private var offset: CGFloat {
        min(0, max(-Self.actionWidth, restingOffset + dragTranslation))
    }

    var body: some View {
        content
            .background(Theme.surface)
            .offset(x: offset)
            // Attached to the sliding content so the revealed strip belongs to the action
            // button behind it. `simultaneousGesture` lets the enclosing ScrollView keep
            // its vertical pan; the axis lock below is what stops the two fighting.
            .simultaneousGesture(swipe)
            .background(alignment: .trailing) { markAwayAction }
            .clipped()
            // Last, so it hides the revealed action strip too — the row goes invisible under
            // its lifted copy, and a black 130pt strip showing through would be worse than
            // the row itself doing so.
            .opacity(isLifted ? 0 : 1)
    }

    // MARK: Row body

    private var content: some View {
        Self.layout(row, isLifted: false, showsLeavingEarlyBadge: showsLeavingEarlyBadge) {
            Self.handleGlyph(isLifted: false)
                .frame(width: 22, height: 38)
                .contentShape(Rectangle())
                .gesture(reorderGesture)
                .accessibilityLabel("Reorder \(row.player.displayName)")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isOpen {
                withAnimation(.snappy(duration: 0.22)) { openRowID = nil }
            } else {
                onOpenPlayer()
            }
        }
        // Swipe and drag are both pointer affordances, so restate both as rotor actions.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Mark away", onMarkAway)
        .accessibilityAction(named: "Move up") { onAccessibilityMove(-1) }
        .accessibilityAction(named: "Move down") { onAccessibilityMove(1) }
    }

    /// The lifted copy the card draws over the list. Gesture-free by construction.
    static func staticContent(_ row: PlayerRow, isLifted: Bool) -> some View {
        layout(row, isLifted: isLifted, showsLeavingEarlyBadge: false) {
            handleGlyph(isLifted: isLifted)
        }
    }

    /// The one description of a row's layout, shared by the in-flow row and the lifted card
    /// so the two cannot drift apart.
    private static func layout(
        _ row: PlayerRow,
        isLifted: Bool,
        showsLeavingEarlyBadge: Bool,
        @ViewBuilder handle: () -> some View
    ) -> some View {
        HStack(spacing: 11) {
            Text("\(row.rank)")
                .typeStyle(.rankNumeral, color: isLifted ? Theme.accent : Theme.inkGhost)
                .frame(width: 19, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.player.displayName)
                        .typeStyle(.bodyStrong, color: row.isAway ? Theme.inkFaint : Theme.ink)
                        .lineLimit(1)

                    if row.isAway {
                        Badge("Away", tone: .muted)
                    } else if showsLeavingEarlyBadge, let leavesAt = row.leavesAt {
                        // The design never draws this, so it appears only while the
                        // "Leaving early" filter is on — which is the one view of the court
                        // where a pick-up time is the thing you came to read. The default
                        // Groups screen stays exactly as designed.
                        Badge(leavesAt.formatted, tone: .accent)
                    }
                }

                Text(row.player.metaLine)
                    .typeStyle(.meta, color: Theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            handle()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func handleGlyph(isLifted: Bool) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(isLifted ? Theme.accent : Theme.chevron)
    }

    // MARK: Reveal

    private var markAwayAction: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { openRowID = nil }
            onMarkAway()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.minus")
                    .font(.system(size: 18, weight: .regular))
                Text("Mark away")
                    .typeStyle(.chipMedium)
            }
            .foregroundStyle(Theme.surface)
            .padding(.leading, 16)
            .frame(width: Self.actionWidth, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Theme.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // VoiceOver reaches this through the row's custom action instead.
        .accessibilityHidden(true)
    }

    // MARK: Gesture

    /// Vertical reorder, scoped to the handle. The swipe below is attached to the whole row
    /// and locks to horizontal on its first movement, so the two never arbitrate for the
    /// same touch: a finger on the handle is reordering, a finger anywhere else is swiping.
    /// The long press is also what lets this win against the enclosing ScrollView's pan.
    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    onReorderBegan()
                case .second(true, let gesture?):
                    onReorderChanged(gesture.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in onReorderEnded() }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if isHorizontalDrag == nil {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag == true else { return }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                defer { isHorizontalDrag = nil }
                guard isHorizontalDrag == true else {
                    dragTranslation = 0
                    return
                }

                // Fold a fifth of the flick's projected travel into the decision so a
                // fast short swipe still snaps open.
                let projected = restingOffset
                    + value.translation.width
                    + value.predictedEndTranslation.width * 0.2
                let shouldOpen = projected < -Self.actionWidth / 2

                withAnimation(.snappy(duration: 0.24)) {
                    if shouldOpen {
                        openRowID = row.id
                    } else if isOpen {
                        openRowID = nil
                    }
                    dragTranslation = 0
                }
            }
    }
}

// MARK: - Previews

#Preview("Coach cards") {
    let store = AppStore.preview
    store.collapsedGroupIDs = [SampleData.hubertsCourt.id]

    let sycamore = store.groupsSections.first
    return ScrollView {
        VStack(spacing: 10) {
            ForEach(sycamore?.cards.prefix(3).map { $0 } ?? []) { card in
                CoachGroupCard(store: store, card: card)
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.large)
    }
    .background(Theme.grouped)
    .frame(width: 402, height: 760)
}

#Preview("Over capacity, collapsed") {
    let store = AppStore.preview
    store.collapsedGroupIDs = [SampleData.hubertsCourt.id]

    let card = store.groupsSections
        .first?
        .cards
        .first { $0.id == SampleData.hubertsCourt.id }

    return VStack {
        if let card {
            CoachGroupCard(store: store, card: card)
        }
    }
    .padding(Spacing.gutter)
    .frame(width: 402)
    .background(Theme.grouped)
}
