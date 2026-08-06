//
//  GroupCard.swift
//  Sycamore
//
//  `8o` — one group, drawn as a band of the camp's ladder: `Group 1 · 8 players · ranked 1–8`
//  over its kids in rank order.
//
//  Section 8 retitles this screen "Kids in ranking order" and folds the old Rank tab into it,
//  which is why the numeral beside a kid is their place in the *camp* and not their place on the
//  court. A group is a slice of one list rather than a court with its own private order, so the
//  numbers have to run 1–8, 9–17, 18–25 down the screen.
//
//  Folded by default: three kids and "+N more". The card is a summary you scan, and eight names
//  in each of twelve cards is not a thing anyone scans.
//
//  The card owns no move state. Where the kid is, what they are aimed at and whether the drop is
//  live all belong to `GroupsView`, because a kid picked up in one card lands in another and no
//  card can see its neighbours.
//

import SwiftUI

// MARK: - Card

struct GroupCard: View {

    let card: GroupsCoachCard
    /// `8 players · ranked 1–8`.
    let summary: String
    /// The rows to draw — folded, that is the first three of them. The screen decides, not the
    /// card: the drop slots are numbered against exactly this list, and two places working it
    /// out separately is two places to get it wrong.
    let visibleRows: [PlayerRow]
    /// The kid in the air, if any — nil on the ordinary screen.
    let move: GroupsMove?

    let onToggle: () -> Void
    let onOpenPlayer: (PlayerRow) -> Void
    /// Tapping a card while a kid is in the air aims at it.
    let onAim: () -> Void
    let onMoveBegan: (PlayerRow) -> Void
    let onMoveChanged: (CGFloat) -> Void
    let onMoveEnded: () -> Void
    /// VoiceOver's equivalent of the drag: one place up or down inside this group.
    let onNudge: (PlayerRow, Int) -> Void
    /// Every drawn row's rectangle, in the list's coordinate space. This is what the drop slots
    /// are built from, so it includes the dashed gap left by the kid in the air.
    let onRowFrame: (Player.ID, CGRect) -> Void

    /// The design writes a court's rank band as "Group 1" and keeps "Court 1" for the place it
    /// is played on — `8q` heads a kid with "Group 1 · Court 1". `Group.label` is the court.
    private var title: String { "Group \(card.group.number)" }

    private var isTarget: Bool { move?.target?.groupID == card.id }
    private var isSource: Bool { move?.sourceGroupID == card.id }
    /// Faded while a kid is in the air: neither where they came from nor where they are going.
    /// The design leaves the source card at full strength — the gap in it is the point.
    private var isBystander: Bool { move != nil && !isTarget && !isSource }

    private var hiddenCount: Int { card.rows.count - visibleRows.count }
    /// A group small enough to draw whole never folds, so it gets no caret either — a chevron
    /// that changes nothing when it is pressed is worse than no chevron.
    private var isFoldable: Bool { card.rows.count > GroupsRules.previewRows + 1 }
    private var isExpanded: Bool { hiddenCount == 0 }

    /// `Drops in at #9` while this card is the target, the head-count band otherwise.
    private var subtitle: String {
        guard isTarget, let slot = move?.target else { return summary }
        return slot.dropLine
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)

        return Card(
            borderColor: isTarget ? Theme.accent : Theme.hairline,
            borderWidth: isTarget ? BorderWidth.input : BorderWidth.hairline,
            isDivided: false
        ) {
            VStack(spacing: 0) {
                header

                if !visibleRows.isEmpty {
                    Hairline(color: Theme.hairlineSoft)
                        .padding(.horizontal, Spacing.medium)

                    VStack(spacing: 0) {
                        ForEach(visibleRows) { row in
                            rowView(row)
                                .onGeometryChange(for: CGRect.self) {
                                    $0.frame(in: .named(GroupsSpace.list))
                                } action: {
                                    onRowFrame(row.id, $0)
                                }
                        }

                        if hiddenCount > 0 {
                            moreRow
                        }
                    }
                    .padding(.bottom, Spacing.tight)
                }
            }
        }
        .overlay {
            if isTarget {
                shape
                    .strokeBorder(GroupsPalette.dropHalo, lineWidth: GroupsMetrics.dropHaloWidth)
                    .padding(-GroupsMetrics.dropHaloWidth)
            }
        }
        .opacity(isBystander ? GroupsMetrics.bystanderOpacity : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typeStyle(.venueHeading, color: Theme.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .typeStyle(.metaStrong, color: isTarget ? Theme.accent : Theme.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isTarget {
                Image(systemName: "arrow.down.square.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.accent)
            } else if move == nil, isFoldable {
                DisclosureChevron(systemName: isExpanded ? "chevron.up" : "chevron.right", size: 16)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.medium)
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
        .onTapGesture {
            // Aiming wins while a kid is in the air: folding a card away underneath a move
            // would take its drop slots with it.
            if move != nil {
                onAim()
            } else if isFoldable {
                onToggle()
            }
        }
        .accessibilityAddTraits(move != nil || isFoldable ? .isButton : [])
        .accessibilityHint(headerHint)
    }

    private var headerHint: String {
        if move != nil { return "Aim the kid at this group" }
        guard isFoldable else { return "" }
        return isExpanded ? "Fold this group" : "Show every kid"
    }

    // MARK: Rows

    private func rowView(_ row: PlayerRow) -> some View {
        let isHeld = move?.row.id == row.id

        return GroupPlayerRow(
            row: row,
            isAiming: move != nil,
            onOpen: { onOpenPlayer(row) },
            onMoveBegan: { onMoveBegan(row) },
            onMoveChanged: onMoveChanged,
            onMoveEnded: onMoveEnded,
            onNudge: { onNudge(row, $0) }
        )
        // Hidden rather than replaced. The row owns the gesture that is carrying the kid, so
        // swapping it for the gap would destroy the drag halfway through it; and it is what
        // holds the space open, which is what keeps every slot below it where it was measured.
        // `.opacity(0)` leaves a view in the accessibility tree, hence the explicit hide — the
        // gap over it is the thing that should speak.
        .opacity(isHeld ? 0 : 1)
        .accessibilityHidden(isHeld)
        .overlay { if isHeld { gap(for: row) } }
    }

    /// The design leaves a dashed gap where the kid was standing rather than closing the list
    /// up: the space is being held for them, and closing it would say they had already gone.
    private func gap(for row: PlayerRow) -> some View {
        RoundedRectangle(cornerRadius: Radius.stepperButton, style: .continuous)
            .strokeBorder(
                Theme.stroke,
                style: StrokeStyle(lineWidth: BorderWidth.hairline, dash: GroupsMetrics.dash)
            )
            .frame(height: GroupsMetrics.gapHeight)
            .padding(.horizontal, Spacing.medium)
            // Decoration over a live row: the handle underneath is still being held.
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Where \(row.player.displayName) was")
    }

    /// `+3 more` — the folded rows, and the way into them.
    private var moreRow: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.row) {
                Color.clear.frame(width: GroupsMetrics.numeralWidth)
                Text("+\(hiddenCount) more")
                    .typeStyle(.rowSubtitle, color: Theme.inkFaint)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // A card that unfolded under a move would move every slot beneath it.
        .disabled(move != nil)
    }
}

// MARK: - Player row

/// `1   Serene Chu                    ♀ ⏱   ≡`
///
/// Rank, name, whatever is true about the kid today, and the handle. The meta line the old card
/// carried ("13 · F · returning") is gone: section 8 puts those facts on `8q`, and a rank band
/// wants one line per kid so that eight of them fit in a card.
private struct GroupPlayerRow: View {

    let row: PlayerRow
    /// True while a kid is in the air. The row stops opening the player then — that tap belongs
    /// to the card, which is being aimed at.
    let isAiming: Bool
    let onOpen: () -> Void
    let onMoveBegan: () -> Void
    let onMoveChanged: (CGFloat) -> Void
    let onMoveEnded: () -> Void
    let onNudge: (Int) -> Void

    /// True for exactly as long as the lift gesture is live. A sequenced gesture that is
    /// *cancelled* never calls `onEnded`, and `@GestureState` is the one thing SwiftUI
    /// guarantees to reset either way — without it a flick off the handle leaves the screen
    /// believing a finger is still down and the list unscrollable.
    @GestureState private var isHolding = false

    var body: some View {
        HStack(spacing: Spacing.row) {
            Text("\(row.player.overallRank)")
                .typeStyle(.rankNumeral, color: Theme.inkGhost)
                .frame(width: GroupsMetrics.numeralWidth, alignment: .trailing)

            Text(row.player.displayName)
                .typeStyle(.bodyStrong, color: row.isAway ? Theme.inkFaint : Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            marks
        }
        .padding(.leading, Spacing.medium)
        // The handle's own 44pt hit region, reserved in the flow and then filled by the overlay
        // below — so a finger reaching for the handle can never open the kid instead.
        .padding(.trailing, HitTarget.minimum)
        // The design draws a 30pt row. Eight of them in a column is eight adjacent taps, so the
        // drawn type stays where it is and the row grows to the minimum around it.
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
        .onTapGesture { if !isAiming { onOpen() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        // The drag is a pointer affordance, so restate it as rotor actions.
        .accessibilityAction(named: "Move up") { onNudge(-1) }
        .accessibilityAction(named: "Move down") { onNudge(1) }
        .overlay(alignment: .trailing) { handle }
        .onChange(of: isHolding) { _, holding in
            // The safety net for a cancelled lift, which never reaches `onEnded`. Ending the
            // tracking twice costs nothing — it does not commit anything.
            if !holding { onMoveEnded() }
        }
    }

    /// Gender first, then whatever else is true today. The design draws all three at 13pt before
    /// the handle; a kid with nothing unusual about them shows only the first.
    private var marks: some View {
        HStack(spacing: Spacing.tight) {
            Image(systemName: row.player.gender == .f ? "figure.stand.dress" : "figure.stand")
                .foregroundStyle(Theme.inkGhost)
                .accessibilityLabel(row.player.gender.symbol)

            if row.isAway {
                Image(systemName: "person.badge.minus")
                    .foregroundStyle(Theme.inkFaint)
                    .accessibilityLabel("Away")
            }

            if let leavesAt = row.leavesAt {
                Image(systemName: "timer")
                    .foregroundStyle(GroupsPalette.pickup)
                    .accessibilityLabel("Leaves at \(leavesAt.formatted)")
            }
        }
        .font(.system(size: 13, weight: .regular))
    }

    private var handle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(Theme.chevron)
            .frame(width: 22, height: 38)
            // Drawn size unchanged; the outer frame only carries the touch.
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .contentShape(.rect)
            .gesture(lift)
            .accessibilityLabel("Move \(row.player.displayName)")
            .accessibilityHint("Picks the kid up. Aim at a group, then drop.")
    }

    /// Hold, then drag. The long press is what lets this win against the enclosing scroll view's
    /// pan, and it is also what makes an accidental brush of the handle harmless.
    private var lift: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($isHolding) { _, state, _ in state = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    onMoveBegan()
                case .second(true, let drag?):
                    onMoveChanged(drag.translation.height)
                default:
                    break
                }
            }
            // The kid stays in the air when the finger leaves; this only stops the tracking.
            .onEnded { _ in onMoveEnded() }
    }
}

// MARK: - Previews

/// Hoisted to file scope on purpose. A `View` type declared *inside* a `#Preview` closure that
/// also returns it makes the compiler's symbol mangler recurse without bound.
private struct GroupCardPreviewHarness: View {

    let store = AppStore.preview
    @State private var expanded: Set<Group.ID> = []

    var body: some View {
        let cards = store.groupsSections.first?.cards.prefix(3).map { $0 } ?? []

        return ScrollView {
            VStack(spacing: Spacing.small) {
                ForEach(cards) { card in
                    let isExpanded = expanded.contains(card.id)
                    let visible = GroupsRules.visibleCount(
                        of: card.rows.count,
                        preview: GroupsRules.previewRows,
                        isExpanded: isExpanded
                    )

                    GroupCard(
                        card: card,
                        summary: "\(card.rows.count) players",
                        visibleRows: Array(card.rows.prefix(visible)),
                        move: nil,
                        onToggle: {
                            if isExpanded {
                                expanded.remove(card.id)
                            } else {
                                expanded.insert(card.id)
                            }
                        },
                        onOpenPlayer: { _ in },
                        onAim: {},
                        onMoveBegan: { _ in },
                        onMoveChanged: { _ in },
                        onMoveEnded: {},
                        onNudge: { _, _ in },
                        onRowFrame: { _, _ in }
                    )
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.large)
        }
        .background(Theme.grouped)
    }
}

#Preview("Group cards") {
    GroupCardPreviewHarness()
        .frame(width: 402, height: 760)
}
