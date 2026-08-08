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
        let shape = RoundedRectangle(cornerRadius: GroupsMetrics.cardRadius, style: .continuous)

        return Card(
            radius: GroupsMetrics.cardRadius,
            borderColor: isTarget ? Theme.accent : Theme.hairline,
            borderWidth: isTarget ? BorderWidth.input : BorderWidth.hairline,
            isDivided: false
        ) {
            VStack(spacing: 0) {
                header

                if !visibleRows.isEmpty {
                    Hairline(color: Theme.hairlineSoft)
                        .padding(.horizontal, GroupsMetrics.cardPadding)

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
                    // `padding-top:6px` under the rule, exactly as drawn. The foot is short of
                    // the card's own 14 because every row is already 44pt of touch target
                    // around 27pt of drawn row — the slack below the last one is most of it.
                    .padding(.top, Spacing.tight)
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

    /// A real `Button` rather than a tap gesture: it is a control with two jobs — fold the card,
    /// or aim a kid at it — and being one means it presses, and reaches Voice Control and the
    /// keyboard, for free. The rows below it cannot do the same; see `GroupPlayerRow`.
    private var header: some View {
        Button(action: headerTapped) {
            headerContent
        }
        .buttonStyle(.plain)
        .disabled(!isHeaderActive)
        .accessibilityHint(headerHint)
    }

    /// Only when there is something for it to do. A card small enough to draw whole has nothing
    /// to fold, and a chevron-less header that still presses is a control that lies.
    private var isHeaderActive: Bool { move != nil || isFoldable }

    private func headerTapped() {
        // Aiming wins while a kid is in the air: folding a card away underneath a move would
        // take its drop slots with it.
        if move != nil {
            onAim()
        } else if isFoldable {
            onToggle()
        }
    }

    private var headerContent: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: GroupsMetrics.titleGap) {
                Text(title)
                    .typeStyle(GroupsType.groupTitle, color: Theme.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .typeStyle(GroupsType.rowMeta, color: isTarget ? Theme.accent : Theme.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isTarget {
                Image(systemName: "arrow.down.square.fill")
                    .font(.system(size: GroupsMetrics.targetGlyph, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            } else if move == nil, isFoldable {
                DisclosureChevron(
                    systemName: isExpanded ? "chevron.up" : "chevron.right",
                    size: GroupsMetrics.caretGlyph
                )
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, GroupsMetrics.cardPadding)
        .padding(.top, GroupsMetrics.cardPadding)
        // `margin-top:10px` to the rule below, or the card's own 14 when there is no rule.
        .padding(.bottom, visibleRows.isEmpty ? GroupsMetrics.cardPadding : GroupsMetrics.rowsGap)
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
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
                GroupsPalette.gapRule,
                style: StrokeStyle(lineWidth: BorderWidth.hairline, dash: GroupsMetrics.dash)
            )
            .frame(height: GroupsMetrics.gapHeight)
            .padding(.horizontal, GroupsMetrics.cardPadding)
            // Decoration over a live row: the handle underneath is still being held.
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Where \(row.player.displayName) was")
    }

    /// `+3 more` — the folded rows, and the way back out of them.
    ///
    /// This used to be a `GroupsRow` in `inkFaint` with no caret, no "Show less" and nothing for
    /// VoiceOver but the fragment "+3 more" — which read as a disabled label rather than as the
    /// control it is, and gave a reader no way to know what there were three more *of*. It is
    /// `MoreRow` now, the same row Overview and the Inbox draw.
    private var moreRow: some View {
        MoreRow(
            hiddenCount: hiddenCount,
            isExpanded: isExpanded,
            noun: "kid",
            nounPlural: "kids",
            qualifier: "in \(card.group.label)",
            // Indented to where the names start: the numeral column plus the card's own gutter.
            metrics: .inline(indent: GroupsMetrics.numeralWidth + GroupsMetrics.cardPadding),
            action: onToggle
        )
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
        GroupsRow(
            rank: row.player.overallRank,
            name: row.player.displayName,
            nameColor: row.isAway ? Theme.inkFaint : Theme.inkWarm
        ) {
            marks
        }
        .padding(.leading, GroupsMetrics.cardPadding)
        // The handle's own 44pt hit region, reserved in the flow and then filled by the overlay
        // below — so a finger reaching for the handle can never open the kid instead.
        .padding(.trailing, HitTarget.minimum)
        // The design draws a 27pt row. Eight of them in a column is eight adjacent taps, so the
        // drawn type stays where it is and the row grows to the minimum around it.
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
        // A tap gesture rather than a `Button`, which the card header above is. The handle sits
        // *over* this row and owns a long-press-then-drag; inside a button's label that gesture
        // loses every ambiguity contest with the button's own, and the lift stops working. The
        // trait below is what keeps VoiceOver told, and the two rotor actions are the real
        // non-pointer route in either case.
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

    /// Gender first, then whatever else is true today. The design draws all three at 13 before
    /// the handle; a kid with nothing unusual about them shows only the first.
    ///
    /// Gender is the mark the design draws, Phosphor's Venus and Mars. SF Symbols has no
    /// equivalent — that is why this row carried a letter for so long, and why the
    /// `figure.stand.dress` before the letter was removed: it encoded the distinction as a dress
    /// and collapsed `.x` onto the male figure. `GenderMark` draws all three from scratch, so
    /// the third answer finally has a glyph of its own rather than somebody else's, and `8a`'s
    /// roster row draws exactly the same one.
    private var marks: some View {
        HStack(spacing: GroupsMetrics.markGap) {
            GenderMark(row.player.gender)

            if row.isAway {
                Image(systemName: "person.badge.minus")
                    .font(.system(size: GroupsMetrics.markGlyph, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .accessibilityLabel("Away")
            }

            if let leavesAt = row.leavesAt {
                // `ph-fill ph-clock-countdown` — a filled clock, which is why this is
                // `clock.fill` and not the `timer` ring it used to be. `8a`'s roster row draws
                // the same mark, and the two disagreeing was the whole of the confusion.
                Image(systemName: "clock.fill")
                    .font(.system(size: GroupsMetrics.markGlyph, weight: .regular))
                    .foregroundStyle(GroupsPalette.pickup)
                    .accessibilityLabel("Leaves at \(leavesAt.formatted)")
            }
        }
        // `margin-right:2px` — the marks stop just short of the handle.
        .padding(.trailing, Spacing.hairGap)
    }

    private var handle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: GroupsMetrics.handleGlyph, weight: .regular))
            .foregroundStyle(Theme.glyphFaint)
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
            VStack(spacing: GroupsMetrics.cardGap) {
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
        .background(Theme.surfaceWarm)
    }
}

#Preview("Group cards") {
    GroupCardPreviewHarness()
        .frame(width: 402, height: 760)
}
