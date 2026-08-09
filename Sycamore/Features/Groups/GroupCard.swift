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
    let onMoveBegan: (PlayerRow) -> Void
    let onMoveChanged: (CGFloat) -> Void
    /// The finger left the handle, which lands the kid. See `GroupsView.endTracking()`.
    let onMoveEnded: () -> Void
    /// The gesture was taken away rather than finished — a call arriving, a system gesture
    /// winning. Separate from `onMoveEnded` now that ending commits: a lift the reader never
    /// completed must not write a move, and a kid left in the air has nothing left to land them.
    let onMoveCancelled: () -> Void
    /// VoiceOver's equivalent of the drag: one place up or down. Past the ends of this card it
    /// carries on into the next one along — see `GroupsView.nudgeAcross`.
    let onNudge: (PlayerRow, Int) -> Void
    /// Every drawn row's rectangle, in the list's coordinate space — the raw material for every
    /// drop slot. The screen ignores these while a kid is in the air, because a slot is only
    /// meaningful measured off the list at rest; the one exception is the settling pass, which is
    /// drawn at rest for exactly that reason. See `GroupsView.cardView(_:)` and `isSettling`.
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

    /// The move is still being measured, so this card draws itself exactly as it does at rest:
    /// no ghost, and the lifted row keeping its space.
    ///
    /// That is not a cosmetic choice, it is what makes the pass measurable. The lift opens every
    /// folded card in the venue and the frames arriving afterwards are what every drop slot is
    /// rebuilt from — and a slot is only meaningful measured off the list at rest. A ghost of
    /// height `H` arriving while a row of height `H` leaves would put two corrections into
    /// numbers that are supposed to describe the layout without either. See
    /// `GroupsMove.awaitingGeometry`.
    private var isSettling: Bool { move?.awaitingGeometry == true }

    /// Where this card opens a space for the kid in the air, if it is the one they are aimed at.
    private var ghostSeat: GroupsGhost.Seat? {
        guard let move, !isSettling else { return nil }
        return GroupsGhost.seat(aimedAt: move.target, card: card.id, drawnRows: visibleRows)
    }

    /// Whether there is anything under the header at all: kids of the card's own, a "+N more"
    /// row, or the ghost of a kid aimed at a card that draws neither.
    ///
    /// The same answer as `!seats.isEmpty` and stated separately on purpose — `body` runs on
    /// every frame of a shift, the header asks this question too, and neither of them needs the
    /// array built to be told no.
    private var hasRowsSection: Bool {
        !visibleRows.isEmpty || hiddenCount > 0 || ghostSeat != nil
    }

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

                if hasRowsSection {
                    Hairline(color: Theme.hairlineSoft)
                        .padding(.horizontal, GroupsMetrics.cardPadding)

                    VStack(spacing: 0) {
                        // A `switch` in a `ForEach` builder is `_ConditionalContent`, not
                        // `AnyView` — it costs a branch in the view tree and nothing at
                        // runtime. The identity that matters is `CardSeat.id`, which is what
                        // keeps the ghost one view as it changes position rather than one
                        // fading out beside another fading in.
                        ForEach(seats) { seat in
                            switch seat {
                            case .row(let row):
                                rowView(row)
                                    .onGeometryChange(for: CGRect.self) {
                                        $0.frame(in: .named(GroupsSpace.list))
                                    } action: {
                                        onRowFrame(row.id, $0)
                                    }
                            case .ghost(let move):
                                ghost(move)
                            case .more:
                                moreRow
                            }
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

    /// A real `Button` rather than a tap gesture: it is a control that folds the card, and being
    /// one means it presses, and reaches Voice Control and the keyboard, for free. The rows below
    /// it cannot do the same; see `GroupPlayerRow`.
    ///
    /// It used to have a second job — tapping a card while a kid hung in the air aimed at it —
    /// and that job has gone with the latch. A move now lasts exactly as long as the finger
    /// carrying it (plus any confirmation, which has the screen), so there is no moment at which
    /// a second finger could tap a card to aim. The reach that bought is paid for by the lift
    /// opening every card and by `GroupsAutoscroll`.
    private var header: some View {
        Button(action: onToggle) {
            headerContent
        }
        .buttonStyle(.plain)
        .disabled(!isHeaderActive)
        .accessibilityHint(headerHint)
    }

    /// Only when there is something for it to do. A card small enough to draw whole has nothing
    /// to fold, and a chevron-less header that still presses is a control that lies.
    ///
    /// Dead while a kid is in the air, and deliberately: folding a card away underneath a move
    /// would take its drop slots with it, and every card is open at that point anyway.
    private var isHeaderActive: Bool { move == nil && isFoldable }

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
        // `hasRowsSection` rather than `visibleRows`, so a card that draws no kids of its own
        // still opens a rows section when a kid is aimed at the back of it.
        .padding(.bottom, hasRowsSection ? GroupsMetrics.rowsGap : GroupsMetrics.cardPadding)
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
    }

    private var headerHint: String {
        guard move == nil, isFoldable else { return "" }
        return isExpanded ? "Fold this group" : "Show every kid"
    }

    // MARK: Rows

    /// Everything this card stacks under its rule, in order: its drawn kids, the ghost of the
    /// one aimed at it, and "+N more".
    ///
    /// The ghost is a *seat in the flow* rather than an overlay, and that is the whole
    /// mechanism — `ghost(_:)` below says why an `.offset` cannot stand in for it. Exactly one
    /// row of height `H` gives its space up (`rowView`) and exactly one of height `H` arrives,
    /// so a kid moving inside one group leaves that group's card the height it already was.
    private var seats: [CardSeat] {
        let ghost = move.map(CardSeat.ghost)
        let seat = ghostSeat

        var seats: [CardSeat] = []
        for row in visibleRows {
            if seat == .above(row.id), let ghost { seats.append(ghost) }
            seats.append(.row(row))
        }
        if seat == .belowLastRow, let ghost { seats.append(ghost) }
        if hiddenCount > 0 { seats.append(.more) }
        // Below "+N more", not above it. See `GroupsGhost.Seat.backOfCard`.
        if seat == .backOfCard, let ghost { seats.append(ghost) }
        return seats
    }

    private func rowView(_ row: PlayerRow) -> some View {
        let isHeld = move?.row.id == row.id

        return GroupPlayerRow(
            row: row,
            isAiming: move != nil,
            onOpen: { onOpenPlayer(row) },
            onMoveBegan: { onMoveBegan(row) },
            onMoveChanged: onMoveChanged,
            onMoveEnded: onMoveEnded,
            onMoveCancelled: onMoveCancelled,
            onNudge: { onNudge(row, $0) }
        )
        // Hidden rather than replaced. The row owns the gesture that is carrying the kid, and a
        // view swapped out from under a live gesture takes the gesture with it — the drag would
        // die halfway through itself. `.opacity(0)` leaves a view in the accessibility tree,
        // hence the explicit hide as well: the ghost is the thing that should speak now.
        //
        // What has reversed is the space. This row used to *hold its space open*, and the
        // argument for that was that it kept every slot below it where it had been measured.
        // The slots hold still because they were captured at lift (`GroupsMove.slots`), not
        // because the layout did — so the row is free to give its space up, which is what lets
        // the rows below close over it and the card the kid came from shrink by one row.
        //
        // Negative padding rather than a frame. **Deliberately not**
        // `.frame(height: isHeld ? 0 : nil)`: `nil → 0` is not interpolable, so the row would
        // snap shut while its neighbours slid, and the two motions are meant to be one. A
        // `CGFloat` of padding animates.
        //
        // The space is given up only once there is a ghost to take it. For the frame or two a
        // lift spends re-measuring (`isSettling`) the row is invisible but still standing in the
        // flow, exactly as `RankView`'s lifted row does for the whole of its drag — which is what
        // lets the frames arriving in that pass describe the list at rest. Nothing shows through
        // the gap: the card carrying the kid is drawn directly over it at `translation` 0.
        .opacity(isHeld ? 0 : 1)
        .accessibilityHidden(isHeld)
        .padding(.bottom, isHeld && !isSettling ? -(move?.origin.height ?? 0) : 0)
    }

    /// The kid, greyed, in the space that has opened for them.
    ///
    /// This replaces a dashed empty rectangle drawn over the row the kid *left*. That drawing
    /// said "a space is being held here", which was true of where they came from and wrong
    /// about where they are going — and where they are going is the question the gesture is
    /// asking. So the plate is filled, its lip is solid, and the kid's name is in it.
    ///
    /// **Deliberately not an `.offset`,** and the reason is different in each of the three
    /// cases it would have to cover:
    ///
    /// * *Cross-group*: the source card has to close up by a row and the target card to open by
    ///   one. `.offset` is render-only by definition and cannot change a view's height. It
    ///   fails outright.
    /// * *Within-group*: the rows below the seat would be offset past the card's `.clipShape`,
    ///   and the space vacated at the source would show as a hole at the card's foot.
    /// * *Empty or folded card*: there is no row stack to offset in the first place.
    ///
    /// `rank: nil` deliberately. A numeral here either repeats the kid's old place — flatly
    /// contradicting the "Drops in at #9" this very card's header is saying at that moment — or
    /// asserts the new one beside rows that have not been renumbered yet, so two rows in one
    /// card read `#9`. The empty numeral column is what "+N more" already uses to line up with
    /// the names above it.
    private func ghost(_ move: GroupsMove) -> some View {
        let plate = RoundedRectangle(cornerRadius: Radius.stepperButton, style: .continuous)

        return GroupsRow(
            rank: nil,
            name: move.row.player.displayName,
            nameColor: Theme.inkFaint
        )
        .padding(.leading, GroupsMetrics.cardPadding)
        // The same trailing reservation a real row makes for the handle, so the greyed name
        // breaks where the live one does rather than a handle's width later.
        .padding(.trailing, HitTarget.minimum)
        // The measured height of the row that closed — see `GroupsMetrics.ghostHeight` for why
        // this is a measurement and the plate inside it is a token.
        .frame(height: move.origin.height)
        .background {
            plate
                .fill(GroupsPalette.ghostFill)
                .overlay {
                    plate.strokeBorder(GroupsPalette.ghostRule, lineWidth: BorderWidth.hairline)
                }
                .frame(height: GroupsMetrics.ghostHeight)
                .padding(.horizontal, GroupsMetrics.cardPadding)
        }
        // The card carrying the kid is drawn over this, and the handle being held is elsewhere.
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Where \(move.row.player.displayName) will land")
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
        // It used to carry `.disabled(move != nil)`, because a card that unfolded under a move
        // would move every slot beneath it. The rule still holds and the modifier is gone,
        // because it can no longer be reached: a lift opens every folded card in the venue, so
        // for the whole of a move `hiddenCount` is 0 and this row is not in `seats` at all. A
        // disabled state nothing can enter is a claim about the screen that the screen no longer
        // makes — and the reason it does not is worth more than the guard was. See
        // `GroupsView.beginMove`.
    }
}

// MARK: - Seats

/// One thing a card stacks under its rule.
///
/// Deliberately not `GroupsGhost.Seat`, which is the neighbouring idea and a different one:
/// that says *where* the space opens, in the model's terms, and is what the arithmetic and the
/// tests talk about. This is *what is drawn*, in order, and it is what `ForEach` walks.
///
/// It exists for its `id`. Without stable identity the ghost moving from one position to the
/// next is a view removed and a different view inserted — it fades out and another fades in,
/// which reads as two ghosts rather than one travelling. With it, `ForEach` recognises the same
/// row in a new place and slides it there.
private enum CardSeat: Identifiable {

    case row(PlayerRow)
    case ghost(GroupsMove)
    case more

    enum ID: Hashable {
        case row(Player.ID)
        /// One id however many places the ghost visits, which is the point.
        case ghost
        case more
    }

    var id: ID {
        switch self {
        case .row(let row): .row(row.id)
        case .ghost: .ghost
        case .more: .more
        }
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
    let onMoveCancelled: () -> Void
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
            // The safety net for a cancelled lift, which never reaches `onEnded`.
            //
            // It calls a *different* thing now, and the distinction is load-bearing: ending
            // commits. This fires for a real release too — `@GestureState` resets after
            // `onEnded` has run — so the screen answers it by cancelling only a move that is
            // still being dragged, which a released one is not. A gesture the reader never
            // finished must not write anybody to a new court, and with the move bar gone, a kid
            // left in the air by an interrupted lift has nothing left on screen to land them.
            if !holding { onMoveCancelled() }
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
            // A tap here opens the kid, exactly as a tap anywhere else on the row does.
            //
            // This reverses the reasoning above `.padding(.trailing, HitTarget.minimum)`, which
            // reserved this column so "a finger reaching for the handle can never open the kid
            // instead". True, and it cost more than it bought: the handle sits *over* the row
            // and claims the hit, so the reserved column did not merely fail to open the kid —
            // it swallowed the tap entirely. A quarter of the width of every row in every group
            // card did nothing at all, silently, which is most of what "unresponsive at times"
            // turned out to mean.
            //
            // `exclusively(before:)` rather than two independent gestures on one view, and the
            // difference is not stylistic. `TapGesture` has no maximum duration, so attached
            // separately it would still succeed on the release of a *long* press — lifting the
            // kid and then opening them, on one touch. Composed exclusively, the tap is only
            // offered the touch once the long press has definitively failed, which is precisely
            // "let go before 0.2s". Two outcomes, never both.
            //
            // The accidental-open the old comment worried about was really an accidental
            // *drag* — a brush of the handle — and `lift`'s 0.2s minimum still answers that,
            // unchanged.
            .gesture(
                lift.exclusively(
                    before: TapGesture().onEnded { if !isAiming { onOpen() } }
                )
            )
            .accessibilityLabel("Move \(row.player.displayName)")
            .accessibilityHint("Hold, then drag. Let go to drop them where they are.")
    }

    /// Hold, then drag. The long press is what lets this win against the enclosing scroll view's
    /// pan, and it is also what makes an accidental brush of the handle harmless.
    ///
    /// Measured in `.global`, and that is not optional. The lifted row now gives its space up,
    /// so when the kid is aimed *above* where they started, this handle's own row is pushed
    /// down by one row height — and a `.local` drag reports travel relative to a view the drag
    /// itself is moving. That is the classic SwiftUI feedback loop: the translation moves the
    /// row, the row changes the translation, and the target oscillates between two slots.
    ///
    /// Screen travel, not list travel, and those have come apart. `GroupsView` takes the pan away
    /// from the reader while a kid is in the air, but the list still moves itself when the
    /// carried card nears an edge (`GroupsAutoscroll`) — and a finger that has not moved reports
    /// no travel however far the content has slid underneath it. The screen adds the two: this
    /// number plus `GroupsMove.listTravel`. Measuring in the list's own space instead would fold
    /// the scroll in for free, and would report nothing at all while the finger was still, which
    /// is exactly when the autoscroll needs to be believed.
    private var lift: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
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
            // Letting go is the drop. See `GroupsView.endTracking()`.
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
                        onMoveBegan: { _ in },
                        onMoveChanged: { _ in },
                        onMoveEnded: {},
                        onMoveCancelled: {},
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

/// One folded card, posed at three of the seats `GroupsGhost` can pick.
///
/// `GroupCard` takes `move` as a parameter rather than reading it off the environment, which is
/// the whole reason this is previewable at all — the screen owns the move, so a card can be
/// handed one that no finger is holding. `RankView`'s drag lives in `@State` on the screen and
/// cannot be posed like this.
///
/// The three are the ones worth looking at together: the ghost between two drawn rows, the
/// ghost under the last drawn row (where a fold is hiding the kid it is anchored on), and the
/// ghost at the back of the card — which is the one that sits *below* "+N more", because "above
/// the fourth kid" and "at the back of the group" are different landings and drawing them in
/// the same place would lose the difference.
private struct GroupCardMovePreviewHarness: View {

    let store = AppStore.preview

    private struct Aim: Identifiable {
        let id: Int
        let title: String
        /// Nil is the back of the card.
        let anchor: Player.ID?
    }

    var body: some View {
        let card = store.groupsSections
            .flatMap(\.cards)
            .first { $0.rows.count > GroupsRules.previewRows + 1 }

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                if let card {
                    let visible = Array(card.rows.prefix(GroupsRules.previewRows))
                    let aims = [
                        Aim(id: 0, title: "Above a drawn row", anchor: visible[1].id),
                        Aim(
                            id: 1,
                            title: "Below the last drawn row — the kid the fold is hiding",
                            anchor: card.rows[GroupsRules.previewRows].id
                        ),
                        Aim(id: 2, title: "Back of the card, under “+N more”", anchor: nil),
                    ]

                    ForEach(aims) { aim in
                        VStack(alignment: .leading, spacing: Spacing.tight) {
                            Text(aim.title)
                                .typeStyle(GroupsType.hint, color: Theme.inkMuted)

                            GroupCard(
                                card: card,
                                summary: "\(card.rows.count) players",
                                visibleRows: visible,
                                move: move(in: card, mover: visible[0], anchor: aim.anchor),
                                onToggle: {},
                                onOpenPlayer: { _ in },
                                onMoveBegan: { _ in },
                                onMoveChanged: { _ in },
                                onMoveEnded: {},
                                onMoveCancelled: {},
                                onNudge: { _, _ in },
                                onRowFrame: { _, _ in }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.large)
        }
        .background(Theme.surfaceWarm)
    }

    /// The first drawn kid, in the air, aimed at `anchor`.
    ///
    /// `origin` is a 44pt box because that is what a row measures at the default type size, and
    /// the ghost reserves exactly `origin.height` — so all three cards below come out the same
    /// height as each other and as the card at rest. `slots` is empty: the card reads `target`,
    /// `row` and `origin`, and never the array a real move aims with.
    private func move(in card: GroupsCoachCard, mover: PlayerRow, anchor: Player.ID?) -> GroupsMove {
        GroupsMove(
            row: mover,
            sourceGroupID: card.id,
            nextRowID: nil,
            origin: CGRect(x: 0, y: 0, width: 320, height: HitTarget.minimum),
            slots: [],
            unfolded: [],
            target: GroupsDropSlot(
                landing: GroupsLanding(
                    groupID: card.id,
                    venueID: card.group.venueID,
                    anchor: anchor
                ),
                y: 0,
                rank: mover.player.overallRank
            )
        )
    }
}

#Preview("Group card — a kid in the air") {
    GroupCardMovePreviewHarness()
        .frame(width: 402, height: 900)
}
