//
//  ScheduleBlockCard.swift
//  Sycamore
//
//  One block on `8k` — a time in the left gutter and, beside it, either a card or a single
//  grey line.
//
//  The grey line is what a finished block becomes. That is the whole point of the screen's
//  shape: the morning you have already run collapses to "Drop-off · done" and stops competing
//  with the block you are standing in, which is the one drawn in green.
//
//  An upcoming card also carries a handle on its bottom edge, which the design does not draw and
//  which is the one thing here that is not transcribed. Its arithmetic is `ScheduleResizePlan`;
//  what is left in this file is the gesture that feeds it and the two things a person sees while
//  dragging. The card itself does **not** grow — see `resizeReadout`.
//

import SwiftUI

struct ScheduleBlockCard: View {

    let block: ScheduleBlock
    /// The block the camp is in the middle of. See `ScheduleBlock.running(in:at:)`.
    let isCurrent: Bool

    /// The block with a finger on its handle, shared with the screen so the list can stop
    /// scrolling out from under a drag. Nil when nothing is being resized.
    ///
    /// One value owned by the parent rather than a `@State` per card, for `SwipeRevealState`'s
    /// reason (`SwipeToDelete.swift:56-64`): it is read by the parent, in the parent's own body,
    /// to decide `.scrollDisabled`.
    @Binding var resizingID: ScheduleBlock.ID?

    /// The start of the block that follows this one, which is as far as this one's end may be
    /// dragged. Nil on the last block of the day. See `ScheduleResizePlan.nextStart(after:in:)`.
    var nextStart: TimeOfDay?

    let onOpen: () -> Void
    /// The block's new end, once. Called on release and never during the drag — `AppStore.perform`
    /// tracks in-flight work with a single `Bool`, so a write per frame would thrash it.
    let onResize: (TimeOfDay) -> Void

    /// The design draws the gutter 52 wide against a 13pt time. At `.accessibility1` that time
    /// is half again as tall and a fixed column clips it, so the column grows with the type it
    /// is holding.
    @ScaledMetric(relativeTo: .callout) private var timeColumn = ScheduleMetrics.timeColumn
    /// …and so does the drop that lands it on the card's title rather than on its top edge.
    @ScaledMetric(relativeTo: .callout) private var timeBaseline = ScheduleMetrics.timeBaseline

    /// The live drag, or nil when no finger is on this card's handle.
    @State private var resize: ScheduleResizePlan?

    /// True for exactly as long as the hold is live. A sequenced gesture that is *cancelled* never
    /// calls `onEnded`, and `@GestureState` is the one thing SwiftUI guarantees to reset either
    /// way — without it a flick off the handle leaves the screen believing a finger is still down
    /// and the whole day unscrollable. `GroupPlayerRow.isHolding` records the same trap.
    @GestureState private var isHolding = false

    var body: some View {
        if block.status == .done {
            doneRow
        } else {
            card
                // A time, a title, a grey line, a rule, a glyph, a note and a count are seven
                // runs SwiftUI would otherwise read out in order. One sentence instead.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(block.accessibilityLine(isCurrent: isCurrent))
                .accessibilityHint("Opens the block")
                .accessibilityAddTraits(.isButton)
                .contentShape(.rect)
                // A tap gesture rather than the `Button` this used to be, and the swap is not
                // stylistic. The handle below sits *over* this card and owns a long-press-then-
                // drag; inside a button's label that gesture loses every ambiguity contest with
                // the button's own and the resize simply never starts. `GroupPlayerRow` hit the
                // same wall and made the same trade (`GroupCard.swift:424-431`) — the button trait
                // above is what keeps VoiceOver told, and the drawn card is unchanged either way
                // because `.buttonStyle(.plain)` never gave it a press state to lose.
                .onTapGesture(perform: onOpen)
                // Applied *after* the accessibility element, so the handle stays an element of
                // its own rather than being swallowed by `children: .ignore`. That ordering is
                // the whole reason the adjustable action below is reachable at all.
                .overlay(alignment: .bottom) { resizeReadout }
                .overlay(alignment: .bottom) { resizeHandle }
                .sensoryFeedback(.selection, trigger: resize?.endsAt)
                .onChange(of: isHolding) { _, holding in
                    // The safety net for a cancelled hold, which never reaches `onEnded`. Inert
                    // after a real release, which clears `resize` first — so this can only ever
                    // tear tracking down, never commit a second time. `RankView.swift:117-124`
                    // draws the same line between the two.
                    guard !holding, resize != nil else { return }
                    endTracking()
                }
        }
    }

    // MARK: Behind us

    /// No card and nothing to press: a finished block is history, and the design gives it no
    /// affordance at all. Its time goes grey with it so the gutter stops advertising it.
    ///
    /// No handle either. A block that has already been run is not one whose length is still a
    /// question, and the row it collapses to has no edge to grab.
    private var doneRow: some View {
        HStack(spacing: Spacing.medium) {
            Text(block.gutterLabel)
                .typeStyle(ScheduleType.blockTime, color: Theme.chevron)
                .frame(minWidth: timeColumn, alignment: .leading)

            Text(block.doneLabel)
                .typeStyle(ScheduleType.doneLine, color: Theme.chevron)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ScheduleMetrics.rowInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.accessibilityLine(isCurrent: false))
    }

    // MARK: Still to come

    private var card: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Text(block.gutterLabel)
                .typeStyle(
                    isCurrent ? ScheduleType.blockTimeNow : ScheduleType.blockTime,
                    color: isCurrent ? Theme.accent : Theme.inkFaint
                )
                .frame(minWidth: timeColumn, alignment: .leading)
                .padding(.top, timeBaseline)

            plate
        }
    }

    /// `8k`'s running block wears a green border at the same weight as every other card's grey
    /// one, and no shadow. Only `8l`'s court card is lifted — see `ScheduleShadows.courtCard`.
    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: ScheduleMetrics.cardRadius, style: .continuous)
        // The card running now is a point roomier around its rule than the rest.
        let ruleGap = isCurrent ? ScheduleMetrics.noteRuleNow : ScheduleMetrics.noteRule

        return VStack(alignment: .leading, spacing: 0) {
            Text(block.title)
                .typeStyle(
                    isCurrent ? ScheduleType.blockTitleNow : ScheduleType.blockTitle,
                    color: Theme.ink
                )

            if let subtitle = block.subtitle {
                Text(subtitle)
                    .typeStyle(ScheduleType.blockDetail, color: block.status.tint)
                    .padding(.top, ScheduleMetrics.detailGap)
            }

            if !block.notes.isEmpty {
                Hairline(color: Theme.hairlineSoft)
                    .padding(.top, ruleGap)

                noteLine
                    .padding(.top, ruleGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ScheduleMetrics.cardPadding)
        .background(Theme.surface, in: shape)
        .overlay {
            shape.strokeBorder(
                isCurrent ? Theme.accentBorder : Theme.hairline,
                lineWidth: BorderWidth.hairline
            )
        }
        .contentShape(shape)
    }

    /// The current block pins its first note and counts the rest; every other block only says
    /// how many there are. The design being deliberate — the note you need mid-session is the
    /// one about the court you are standing on, and it should not cost a tap.
    @ViewBuilder
    private var noteLine: some View {
        if isCurrent, let pinned = block.notes.first {
            HStack(spacing: ScheduleMetrics.noteGap) {
                DisclosureChevron(systemName: "pin.fill", size: 13, color: Theme.accent)
                    .accessibilityHidden(true)

                Text(pinned.text)
                    .typeStyle(ScheduleType.noteLine, color: Theme.inkWarm)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: ScheduleMetrics.noteGap)

                if block.additionalNoteCount > 0 {
                    Text("+\(block.additionalNoteCount)")
                        .typeStyle(ScheduleType.noteLine, color: Theme.inkFaint)
                        // Without this the count is the run that gets truncated, and the note it
                        // is counting eats the whole line.
                        .layoutPriority(1)
                }
            }
        } else if let summary = block.noteSummary {
            HStack(spacing: ScheduleMetrics.noteGap) {
                DisclosureChevron(systemName: "note.text", size: 14, color: Theme.inkFaint)
                    .accessibilityHidden(true)

                Text(summary)
                    .typeStyle(ScheduleType.noteLine, color: Theme.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: The bottom edge

    /// The block as it stands, ready to be dragged or adjusted.
    ///
    /// Nil for a block that runs open-ended: `ScheduleBlock.endsAt` is optional, and one with no
    /// end has no bottom edge and no span to read out. Such a block is drawn without a handle
    /// rather than given one that would have to invent an end before it could move it.
    private var restingPlan: ScheduleResizePlan? {
        block.endsAt.map {
            ScheduleResizePlan(startsAt: block.startsAt, endsAt: $0, nextStart: nextStart)
        }
    }

    /// The grabber, and the column that catches a finger reaching for it.
    ///
    /// Drawn on every platform, unlike `SwipeToDelete`, which excludes the Mac because a
    /// two-finger horizontal swipe has no pointer equivalent (`SwipeToDelete.swift:268-274`).
    /// This gesture does: press, hold, drag is exactly what a mouse does, and the 0.2s hold that
    /// separates it from a scroll on a touchscreen costs a pointer nothing. There is no
    /// unreachable affordance to hide.
    @ViewBuilder
    private var resizeHandle: some View {
        // `block.endsAt != nil` said the short way; see `restingPlan`.
        if block.endsAt != nil {
            Capsule(style: .continuous)
                // `Theme.grabber`, which is what `SheetGrabber` draws. A second grabber in a
                // second grey is two answers to "what colour is a thing you can pull".
                .fill(resize == nil ? Theme.grabber : Theme.accent)
                .frame(width: ScheduleMetrics.resizeGrab.width,
                       height: ScheduleMetrics.resizeGrab.height)
                .padding(.bottom, Spacing.tight)
                // Grown, then shaped, and that order is load-bearing: `.contentShape` first would
                // pin the hit region to the 28×3 capsule and leave the added height inert, which
                // is the trap `Chip` records at `Components.swift:363-373`. Bottom-aligned so the
                // 44pt lives *inside* the card — hanging below it would put a dead strip over the
                // top of the next block.
                .frame(width: ScheduleMetrics.resizeHitWidth,
                       height: HitTarget.minimum,
                       alignment: .bottom)
                .contentShape(.rect)
                .gesture(
                    // `exclusively(before:)` rather than two independent gestures, for the reason
                    // `GroupCard.swift:494-499` sets out: `TapGesture` has no maximum duration, so
                    // attached separately it also fires on the *release* of a long press — and a
                    // completed resize would open the block's detail cover on the way out. Offered
                    // the touch only once the hold has definitively failed, the tap means what it
                    // says here, which is the same thing it means anywhere else on the card.
                    lift.exclusively(before: TapGesture().onEnded(onOpen))
                )
                // Centred on the plate rather than on the row. The overlay spans the gutter too,
                // so without this inset the grabber lands half a gutter to the left of the card
                // it belongs to.
                .padding(.leading, timeColumn + Spacing.medium)
                .accessibilityElement()
                .accessibilityLabel("Length of \(block.title)")
                .accessibilityValue(resize?.spanLabel ?? block.timeLabel)
                .accessibilityHint("Adjust to change when the block ends")
                // A hidden drag is an invisible feature. The rotor's swipe-up/down is the whole of
                // this control for somebody who cannot see the grabber, and `IntakeStepper` is the
                // pattern (`IntakeStepper.swift:48-57`) — a real adjustable control rather than
                // two named actions, so VoiceOver speaks the span as a value that changes.
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: adjust(by: 1)
                    case .decrement: adjust(by: -1)
                    @unknown default: break
                    }
                }
        }
    }

    /// The live span, while a finger is down.
    ///
    /// This is the *only* feedback a resize gets, and that is the settled shape rather than an
    /// omission: `8k` draws a fifteen-minute block and a two-hour block at the same height, so
    /// there is no card edge that could follow the finger without rebuilding the screen as a
    /// duration-proportional timeline — which is a different screen. The readout says what the
    /// list cannot.
    ///
    /// Deliberately unanimated, in both directions. The tracking phase of a drag must never be
    /// animated — `SwipeToDelete.swift:350-355` records what 0.24s between a finger and the thing
    /// it is moving feels like — and there is no settle here to animate instead, because nothing
    /// moves when the finger lifts.
    @ViewBuilder
    private var resizeReadout: some View {
        if let resize {
            Text(resize.spanLabel)
                .typeStyle(ScheduleType.blockTimeNow, color: Theme.surface)
                .lineLimit(1)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.tight)
                .background(Theme.accent, in: Capsule(style: .continuous))
                // Clear of the grabber's own lift, and then clear of the grabber.
                .padding(.bottom, Spacing.tight + Spacing.small)
                // Centred on the whole row rather than inset onto the plate the way the grabber
                // is, and deliberately: the gutter grows with Dynamic Type, so an inset readout is
                // squeezed into a narrower and narrower column exactly as its own type gets
                // bigger, and `12:00pm – 12:45pm` starts truncating — which is the one thing a
                // live readout may not do. It floats over the block rather than sitting in it, so
                // the full width is its to use.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Hold, then drag. The long press is what lets this win against the enclosing scroll view's
    /// pan, and it is also what makes an accidental brush of the handle harmless.
    ///
    /// A resize is a **vertical** drag, so it is in the second of the two camps
    /// `SwipeToDelete.swift:9-15` sets out: nothing about the movement separates it from a scroll
    /// and only time can. That is why this is `GroupCard`'s and `RankView`'s composition rather
    /// than `SwipeToDelete`'s bare `DragGesture`.
    ///
    /// Measured in the list's own named space rather than in `.local`. `.local` is relative to the
    /// handle, and the handle is inside a scroll view — so a `.local` translation is only
    /// trustworthy for as long as nothing moves the view it is measured against, which is the
    /// feedback loop `GroupCard.swift:516-521` describes from the other side. A space named on the
    /// list's content is a frame of reference neither the scroll's offset nor the card's own
    /// reflow can shift.
    private var lift: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(ScheduleResizePlan.listSpace)
                )
            )
            .updating($isHolding) { _, state, _ in state = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    beginTracking()
                case .second(true, let drag?):
                    track(drag.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in commit() }
    }

    /// One `onChanged`, written back only when it says something new.
    ///
    /// A touch stream arrives at up to 120Hz and the end time moves once every 22pt, so nine
    /// frames in ten carry a value identical to the one already held — and `@State` does not
    /// compare before it writes, so each of those still marks the card dirty and re-runs the whole
    /// plate, its note line and its accessibility sentence. `SwipeToDelete.swift:340-346` guards
    /// its own per-frame write for the same reason, one level up.
    private func track(_ height: CGFloat) {
        guard var moved = resize else { return }
        moved.drag(by: height)
        if moved != resize { resize = moved }
    }

    private func beginTracking() {
        // Guarded, because `.first(true)` arrives more than once while a press is held, and
        // because `resizingID` is a binding into the screen that owns the list: an unguarded
        // write re-runs that whole body — the scroll view, every sibling card — for a value that
        // changes once per gesture. `SwipeToDelete.swift:340-346` guards its own for this reason.
        guard resizingID != block.id else { return }
        resize = restingPlan
        resizingID = block.id
    }

    /// Tracking down, committing nothing.
    private func endTracking() {
        resize = nil
        // Only if it is still ours. A second finger landing on another card claims the id, and
        // clearing it blindly here would unlock the list underneath a drag that is still live.
        if resizingID == block.id { resizingID = nil }
    }

    private func commit() {
        let settled = resize
        endTracking()
        guard let settled, settled.hasMoved else { return }
        onResize(settled.endsAt)
    }

    /// One rotor step. Committed immediately, exactly as a tap on "Mark done" is: an adjustable
    /// action is user-paced and discrete, so there is no per-frame write here to batch.
    private func adjust(by steps: Int) {
        guard let restingPlan else { return }
        let end = restingPlan.adjusted(by: steps)
        guard end != restingPlan.restingEnd else { return }
        onResize(end)
    }
}

// MARK: - Previews

#Preview("Blocks") {
    ScheduleBlockCardPreviewHarness()
}

/// Hoisted to file scope for the reason `GroupCardPreviewHarness` was: a `View` declared inside a
/// `#Preview` closure that also returns it makes the compiler's symbol mangler recurse.
private struct ScheduleBlockCardPreviewHarness: View {

    @State private var blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
    @State private var resizingID: ScheduleBlock.ID?

    var body: some View {
        // The design's clock, so the preview marks the block `8k` marks rather than whichever one
        // the machine's afternoon happens to land in.
        let currentID = ScheduleBlock.running(in: blocks, at: TimeOfDay(9, 41))?.id

        return ScrollView {
            VStack(spacing: ScheduleMetrics.blockGap) {
                ForEach(blocks) { block in
                    ScheduleBlockCard(
                        block: block,
                        isCurrent: block.id == currentID,
                        resizingID: $resizingID,
                        nextStart: ScheduleResizePlan.nextStart(after: block, in: blocks),
                        onOpen: {},
                        // No store in a preview, so the resize lands in the array directly —
                        // enough to see the clamp at the next block bite.
                        onResize: { end in
                            guard let index = blocks.firstIndex(where: { $0.id == block.id })
                            else { return }
                            blocks[index].endsAt = end
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, ScheduleMetrics.listTop)
            .coordinateSpace(name: ScheduleResizePlan.listSpace)
        }
        .scrollDisabled(resizingID != nil)
        .background(Theme.surfaceWarm)
    }
}
