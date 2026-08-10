//
//  ScheduleBlockCard.swift
//  Sycamore
//
//  One block on `8k`'s canvas — a card drawn at the height its own length earns.
//
//  It is handed a height rather than growing to fit what it has to say, which is the whole of what
//  changed when the day stopped being a list. A quarter-hour block is 30pt tall and a two-hour one
//  is 240 (`ScheduleTimeline.pointsPerMinute`), so the card picks a layout from the room it has —
//  see `Tier`, and `ScheduleMetrics.blockLayoutRich` for where its three thresholds came from.
//  Three notes no longer make a short block draw taller than a long one, because a block's height
//  is now a fact about the morning rather than about the card.
//
//  A finished block keeps its muted treatment and loses its card's white, but it now sits at its
//  **true** position and length rather than as a grey line in sequence. The morning you have
//  already run is still there, still not competing with the block you are standing in, and the
//  hour it occupied is no longer given away.
//
//  Two drags live here and both are the same composition: hold, then drag. The bottom edge changes
//  when the block *ends* (`ScheduleResizePlan`); the body changes when it *happens*
//  (`ScheduleMovePlan`). Neither is drawn by the design — `8k` was transcribed as a list — and both
//  now move the card itself, because there is finally a geometry for them to move it in.
//
//  The design does not draw the amber clash line either, and for a plainer reason: nothing in the
//  app could produce a clash to draw when `8k` was transcribed. It is drawn in the vocabulary the
//  screen already has for a problem rather than in one of its own — see `greyLines(_:)`, and
//  `border` for what carries it on a card too short to hold a line.
//

import SwiftUI

struct ScheduleBlockCard: View {

    let block: ScheduleBlock
    /// Whether the camp is in the middle of this block. See `ScheduleBlock.running(in:at:)` — a
    /// venue can be in the middle of several at once, on courts that do not overlap, so this is
    /// one card's share of that answer rather than a comparison against a single current block.
    let isCurrent: Bool

    /// The height the canvas has given this block, which is its length in points.
    ///
    /// Passed in rather than worked out here, because it is the canvas that owns the packing: the
    /// same `ScheduleTimeline.Placement` decides this card's width and column, and a card computing
    /// half of its own frame from the block while the parent computes the other half is two answers
    /// to one question.
    let height: CGFloat

    /// The block with a finger on it, shared with the screen so the canvas can stop scrolling out
    /// from under a drag. Nil when nothing is being dragged.
    ///
    /// One value owned by the parent rather than a `@State` per card, for `SwipeRevealState`'s
    /// reason (`SwipeToDelete.swift:56-64`): it is read by the parent, in the parent's own body,
    /// to decide `.scrollDisabled` — and now also to lift the dragged card above its neighbours.
    ///
    /// One id for *both* gestures. They cannot be live at once — a resize starts on the bottom
    /// edge, a move on the body, and the two surfaces do not overlap — so a second binding would
    /// be a second way to say the same thing and a second way for it to be left set.
    @Binding var draggingID: ScheduleBlock.ID?

    /// The block this one clashes with, or nil. Drawn as the amber line under the card's grey one,
    /// or as an amber border when the card is too short to hold a line.
    ///
    /// Handed down rather than worked out here, because working it out is a walk of the whole day
    /// and this view is drawn once per block: see `ScheduleConflicts`, which is where the walk
    /// happens and where its cost is argued.
    var conflict: ScheduleBlock?

    let onOpen: () -> Void
    /// The block's new end, once. Called on release and never during the drag — `AppStore.perform`
    /// tracks in-flight work with a single `Bool`, so a write per frame would thrash it.
    let onResize: (TimeOfDay) -> Void
    /// The block's new start and end, once, on the same terms.
    let onMove: (TimeOfDay, TimeOfDay?) -> Void

    /// The three heights the layout changes at, on the text's own ramp.
    ///
    /// `@ScaledMetric` rather than the bare tokens because the *content* is what these thresholds
    /// are about: at `.accessibility1` a title and a span no longer fit in 60pt, so the threshold
    /// has to rise with the type or the card clips instead of simplifying. `ScheduleMetrics`
    /// carries the numbers and shows the arithmetic each came from.
    @ScaledMetric(relativeTo: .callout) private var richFrom = ScheduleMetrics.blockLayoutRich
    @ScaledMetric(relativeTo: .callout) private var fullFrom = ScheduleMetrics.blockLayoutFull
    @ScaledMetric(relativeTo: .callout) private var compactFrom = ScheduleMetrics.blockLayoutCompact

    /// The live bottom-edge drag, or nil when no finger is on this card's handle.
    @State private var resize: ScheduleResizePlan?
    /// The live body drag, or nil when nobody is carrying this block.
    @State private var move: ScheduleMovePlan?

    /// The times the last committed drag wrote, held until the store answers.
    ///
    /// Without it the card **rubber-bands**: the plan is cleared on release, the card springs back
    /// to where the drag started, and a round trip later it jumps to where it was dropped.
    /// `AppStore.updateScheduleBlock` is not optimistic — `scheduleBlocks` is assigned after the
    /// `await` (`AppStore+SectionEight.swift:121-126`) — so that gap is the whole latency of the
    /// write, on the one gesture in the app where the finger and the thing it moved were supposed
    /// to be the same object. `RankView` and `GroupCard` snap back the same way and get away with
    /// it, because a row returning to a list it is about to be re-sorted into is a much smaller
    /// lie than a block jumping back an hour.
    ///
    /// It is cleared by the block itself changing, whatever it changed to — at that point the store
    /// has spoken and is the authority. Nothing double-jumps in between, because every reading
    /// below is expressed as a *difference* from `block`: the moment the store's block carries the
    /// pending times, the difference is zero and clearing it moves nothing.
    ///
    /// **If the write fails the card keeps the position the finger left it at.** That is the
    /// honest failure of every optimistic drag and it is not silent — `AppStore.perform` puts the
    /// error over all four tabs, and the next read of the day corrects the card.
    @State private var pending: PendingSpan?

    /// True for exactly as long as a hold is live. A sequenced gesture that is *cancelled* never
    /// calls `onEnded`, and `@GestureState` is the one thing SwiftUI guarantees to reset either
    /// way — without it a flick off the card leaves the screen believing a finger is still down
    /// and the whole day unscrollable. `GroupPlayerRow.isHolding` records the same trap.
    @GestureState private var isHoldingEdge = false
    @GestureState private var isHoldingBody = false

    /// One committed drag, waiting for the store.
    private struct PendingSpan: Equatable {
        let startsAt: TimeOfDay
        let endsAt: TimeOfDay?
    }

    var body: some View {
        SwiftUI.Group {
            if block.status == .done {
                finishedPlate
            } else {
                liveCard
            }
        }
        // The slot the canvas cut for this block. The plate inside it is drawn at `liveHeight` and
        // pinned to the top, so a drag can overflow the slot in either direction without the
        // canvas having to be told about it mid-gesture.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Behind us

    /// A finished block: its hour, hollow.
    ///
    /// No card and nothing to press — the design gives a finished block no affordance, and none of
    /// that changed when it moved onto the canvas. What did change is that it is no longer a grey
    /// line out of sequence: it keeps its place and its length, so a morning that has already run
    /// still reads as the shape it had.
    ///
    /// **No fill at all, and a fainter border than a live card's.** The first shape of this took
    /// `Theme.surfaceWarm` to be "the canvas colour" — which it is in the light scheme and is not
    /// the point. `Theme.surface` and `surfaceWarm` are a point apart in light and *inverted* in
    /// dark (`Theme.swift:138`, `:238`), so a fill can carry none of this distinction: what a
    /// reader actually sees of any card here is its border. So the done block gives up the fill
    /// entirely and drops to `hairlineSoft`, and the difference between "still to come" and
    /// "already run" is a line one step quieter — which reads the same way in both schemes.
    ///
    /// It still takes the touch, without doing anything with it. That is deliberate and it is the
    /// second thing the canvas changed: the grid underneath makes a block wherever it is tapped,
    /// so a plate that let touches through would turn every finished block into a trap that
    /// silently opens the composer on top of the morning you have just run.
    ///
    /// No handle, no move: a block that has already been run is not one whose times are still a
    /// question. No clash flag either, which is a decision and not an omission. A finished block
    /// still *causes* one — `BlockRules` reads status not at all, so a done drop-off still occupies
    /// its courts and still flags whatever was laid over it — but flagging the drop-off itself
    /// would be an amber line about a morning that has already happened. The block somebody can
    /// still move is the one that says so.
    private var finishedPlate: some View {
        plate(fill: .clear, border: Theme.hairlineSoft, drawnHeight: height) {
            Text(block.doneLabel)
                .typeStyle(ScheduleType.doneLine, color: Theme.chevron)
                .lineLimit(tier(for: height) >= .full ? 2 : 1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.accessibilityLine(isCurrent: false, conflict: nil))
    }

    // MARK: - Still to come

    /// The card, its two drag surfaces, and the state that tears them down.
    ///
    /// Split across four properties rather than written as one chain, and not for taste: the
    /// modifier stack that follows is long enough that the type-checker gives up on it whole.
    private var liveCard: some View {
        feedbackCard
            .onChange(of: isHoldingEdge) { _, holding in
                // The safety net for a cancelled hold, which never reaches `onEnded`. Inert after
                // a real release, which clears the plan first — so this can only ever tear
                // tracking down, never commit a second time. `RankView.swift:117-124` draws the
                // same line between the two.
                guard !holding, resize != nil else { return }
                endTracking()
            }
            .onChange(of: isHoldingBody) { _, holding in
                guard !holding, move != nil else { return }
                endTracking()
            }
            // The store has answered; whatever it says is now the card's position. See `pending`.
            .onChange(of: block) { _, _ in pending = nil }
    }

    private var feedbackCard: some View {
        draggableCard
            // Guarded on the *arrival* of a value rather than on any change of one. The bare
            // `trigger:` form fires on the way back to nil too, so every lift of a finger — even
            // one that moved nothing and wrote nothing — ended in a second tick.
            .sensoryFeedback(trigger: resize?.endsAt) { _, new -> SensoryFeedback? in
                new == nil ? nil : .selection
            }
            .sensoryFeedback(trigger: move?.startsAt) { _, new -> SensoryFeedback? in
                new == nil ? nil : .selection
            }
    }

    private var draggableCard: some View {
        labelledCard
            // Applied *after* the accessibility element, so the two drag surfaces stay outside it
            // rather than being swallowed by `children: .ignore`.
            .overlay(alignment: .top) { moveSurface }
            .overlay(alignment: .bottom) { resizeHandle }
            .overlay(alignment: .bottom) { edgeReadout }
            .overlay(alignment: .top) { moveReadout }
            // The plate is `liveHeight` tall and starts at the slot's top; a move slides the whole
            // thing, handles and readouts with it.
            .offset(y: liveOffset)
    }

    private var labelledCard: some View {
        card
            // A time, a title, a grey line, an amber one, a rule, a glyph, a note and a count
            // are eight runs SwiftUI would otherwise read out in order. One sentence instead.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(block.accessibilityLine(isCurrent: isCurrent, conflict: conflict))
            .accessibilityValue(block.timeLabel)
            .accessibilityHint("Opens the block. Adjust to move it earlier or later.")
            .accessibilityAddTraits(.isButton)
            // The trait promises an activation and this is what keeps the promise. Both taps that
            // open the block are on overlays *outside* this element — they have to be, or the
            // handle would be swallowed by `children: .ignore` — so without this a VoiceOver
            // double-tap on a block does nothing at all. `GroupCard.swift:429-434` makes the same
            // repair from the other side, by declaring its drag as a named action.
            .accessibilityAction { onOpen() }
            // The rotor's route to the move, so the new gesture is not pointer-only. The resize
            // has its own on the handle; this one is on the card because the card *is* the
            // control — a hold anywhere on its body picks the block up.
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: shift(by: 1)
                case .decrement: shift(by: -1)
                @unknown default: break
                }
            }
            // …and the length's route, for the blocks too short to be given a grabber. Named
            // actions rather than a second adjustable, there being only one adjustable value per
            // element and the move having claimed it.
            .accessibilityActions {
                if !showsHandle, block.endsAt != nil {
                    Button("Lengthen by 15 minutes") { stretch(by: 1) }
                    Button("Shorten by 15 minutes") { stretch(by: -1) }
                }
            }
    }

    /// `8k`'s running block wears a green border at the same weight as every other card's grey
    /// one, and no shadow. Only `8l`'s court card is lifted — see `ScheduleShadows.courtCard`.
    private var card: some View {
        plate(fill: Theme.surface, border: border, drawnHeight: liveHeight) {
            copy
        }
    }

    /// Green while it is running, amber while a clash has nowhere else to be drawn, grey otherwise.
    ///
    /// The amber case is what the canvas cost and what it pays back. `greyLines(_:)` needs a line's
    /// worth of card and a block under three quarters of an hour has none, so on short blocks the
    /// border carries the flag instead — the same ink, no vertical room at all. It outranks the
    /// running block's green for the reason `ScheduleBlock.subtitle` lets "Needs a coach" outrank
    /// `detail` (`ScheduleBlockPresentation.swift:29-33`): a problem outranks a state.
    ///
    /// It is *not* drawn on a card tall enough for the line, which would be the same fact twice in
    /// two places and would take the green off the block somebody is standing in to say something
    /// already written on it.
    private var border: Color {
        if conflict != nil, tier(for: liveHeight) < .full { return Theme.warning }
        return isCurrent ? Theme.accentBorder : Theme.hairline
    }

    /// The card's words, as much of them as the height allows.
    @ViewBuilder
    private var copy: some View {
        let tier = tier(for: liveHeight)
        // The card running now is a point roomier around its rule than the rest.
        let ruleGap = isCurrent ? ScheduleMetrics.noteRuleNow : ScheduleMetrics.noteRule

        if tier >= .full {
            VStack(alignment: .leading, spacing: 0) {
                title(tier)

                detailLine(block.timeLabel, color: Theme.inkFaint)

                greyLines(tier)

                if tier >= .rich, !block.notes.isEmpty {
                    Hairline(color: Theme.hairlineSoft)
                        .padding(.top, ruleGap)

                    noteLine
                        .padding(.top, ruleGap)
                }
            }
        } else if tier == .compact {
            VStack(alignment: .leading, spacing: 0) {
                title(tier)

                // `gutterLabel` — `9:00` — and not the full span, which is the choice this tier
                // exists to make. A card this short is also, on a morning with two blocks running
                // at once, a card half the width of the screen, and `9:00am – 10:30am` truncates
                // there to a sentence with its answer cut off. On a canvas the start is the part
                // that needs saying anyway: the block's *height* is its length, drawn to scale, so
                // the end is already on the screen. And the meridiem `gutterLabel` drops for the
                // gutter's sake is redundant here for a better reason than width — the card is
                // sitting under the hour rule that gives it.
                detailLine(block.gutterLabel, color: Theme.inkFaint)
            }
        } else {
            title(tier)
        }
    }

    /// The grey second line, the amber one, or — at `.full` — whichever of the two matters more.
    ///
    /// `.full` is 90pt, which is 28 of padding and room for a title, a span and **one** more line.
    /// Drawing both there is what the first shape of this card did, and the second was cut through
    /// the middle of its own glyphs by the clip. So the clash wins the line when there is one, on
    /// `subtitle`'s own precedent: "Needs a coach" already displaces `detail` for the same reason,
    /// and a block laid over another one is the more urgent of the two things again.
    ///
    /// At `.rich` there is room for both and both are drawn, in the order the list drew them.
    @ViewBuilder
    private func greyLines(_ tier: Tier) -> some View {
        // Bound rather than branched, so the subtitle is one `Text` and not the same one written
        // into two mutually exclusive arms of an `if`.
        let subtitle = (tier >= .rich || conflict == nil) ? block.subtitle : nil

        if let subtitle {
            detailLine(subtitle, color: block.status.tint)
        }

        if let conflict {
            detailLine(conflict.clashLine, color: Theme.warning)
        }
    }

    /// One of the card's lines under its title. The style, the single line and the gap above it are
    /// one visual rule and are stated once, rather than five times over four call sites.
    private func detailLine(_ text: String, color: Color) -> some View {
        Text(text)
            .typeStyle(ScheduleType.blockDetail, color: color)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.top, ScheduleMetrics.detailGap)
    }

    private func title(_ tier: Tier) -> some View {
        Text(block.title)
            .typeStyle(
                isCurrent ? ScheduleType.blockTitleNow : ScheduleType.blockTitle,
                color: Theme.ink
            )
            .lineLimit(tier >= .rich ? 2 : 1)
            .truncationMode(.tail)
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

    // MARK: - The drawn box

    /// The card, at whatever height it is being drawn at.
    ///
    /// **Clipped to its own shape**, which a card in a list never had to be. A block is now given
    /// its height by the clock rather than by its contents, so at the accessibility text sizes a
    /// half-hour block's title can be taller than the half hour it happened in. The tiers above
    /// are what keep that from happening at the default sizes; clipping is the honest failure past
    /// them: a truncated title inside the right half hour beats a whole one spilling over the
    /// block underneath, which would misdraw two blocks to fully draw one.
    private func plate<Content: View>(
        fill: Color,
        border: Color,
        drawnHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: ScheduleMetrics.cardRadius, style: .continuous)
        let layout = tier(for: drawnHeight)

        return content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ScheduleMetrics.cardPadding)
            .padding(.vertical, layout.verticalPadding)
            .frame(height: drawnHeight, alignment: .topLeading)
            .background(fill, in: shape)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: BorderWidth.hairline)
            }
            .contentShape(shape)
    }

    /// How much a card can say at the height it has been given.
    ///
    /// Ordered, and compared with `>=` at the call sites rather than switched on, because each tier
    /// is the one below it plus a line — so a `switch` would restate the shorter card inside the
    /// taller one and the two would drift.
    private enum Tier: Int, Comparable {
        /// A title, and the block's position on the canvas says the rest.
        case minimal
        /// A title and a start.
        case compact
        /// A title, the span, and one grey line — the clash if there is one.
        case full
        /// …and the subtitle beside it, and the rule and the notes: everything the list drew.
        case rich

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

        var verticalPadding: CGFloat {
            switch self {
            case .rich, .full: ScheduleMetrics.cardPadding
            case .compact: Spacing.small
            // Almost none. A quarter-hour block is 30pt and `cardPadding` either side is 28 of
            // them, so anything more here is the difference between one readable line and none.
            case .minimal: Spacing.hairGap
            }
        }
    }

    private func tier(for drawnHeight: CGFloat) -> Tier {
        if drawnHeight >= richFrom { return .rich }
        if drawnHeight >= fullFrom { return .full }
        if drawnHeight >= compactFrom { return .compact }
        return .minimal
    }

    // MARK: - Following the finger

    /// Where the card is drawn from: a live carry, then a carry the store has not confirmed, then
    /// the block itself.
    private var liveStart: TimeOfDay {
        move?.startsAt ?? pending?.startsAt ?? block.startsAt
    }

    /// …and where it ends, on the same ladder. Written out rather than chained with `??`, which
    /// cannot express it: the middle rung is itself an optional end, and a pending open-ended
    /// block must read as "no end" rather than falling through to the block's own.
    private var liveEnd: TimeOfDay? {
        if let resize { return resize.endsAt }
        if let pending { return pending.endsAt }
        return block.endsAt
    }

    /// How tall the plate is being drawn right now.
    ///
    /// This is the thing that could not exist before. A list drew a fifteen-minute block and a
    /// two-hour block at the same height, so a drag had nothing to move; the readout below was the
    /// whole of the feedback and said so. The edge follows the finger now because there is finally
    /// a height for it to follow it in.
    ///
    /// A *difference* from the height the canvas gave, exactly as `liveOffset` is a difference from
    /// the position it gave — and for a sharper reason than symmetry. Recomputing the height from
    /// the block's own two times is the card answering a question the parent has already answered,
    /// which `height` is documented as existing to prevent, and the two answers genuinely differ:
    /// a block outside the grid is *floored* to one grid step by
    /// `ScheduleTimeline.span(of:in:)` so that it has something to touch, and recomputing would
    /// hand it back the 0pt the floor exists to avoid.
    private var liveHeight: CGFloat {
        guard let end = liveEnd, let resting = block.endsAt else { return height }
        return max(0, height + ScheduleTimeline.y(for: end) - ScheduleTimeline.y(for: resting))
    }

    /// How far the plate has been carried from the slot the canvas cut for it.
    ///
    /// A *difference*, which is what makes `pending` safe to clear at any moment: once the store's
    /// block carries the times the drag wrote, this is zero and letting go of the pending span
    /// moves nothing.
    private var liveOffset: CGFloat {
        ScheduleTimeline.y(for: liveStart) - ScheduleTimeline.y(for: block.startsAt)
    }

    /// The exact span, while a finger is down.
    ///
    /// It used to be the *only* feedback a drag got, and this comment used to say why: `8k` drew a
    /// fifteen-minute block and a two-hour one at the same height, so there was no card edge that
    /// could follow a finger without rebuilding the screen as a duration-proportional timeline —
    /// "which is a different screen". This is that screen, the card moves, and the readout is no
    /// longer carrying the gesture on its own.
    ///
    /// It stays because the canvas answers a different question. A grid ruled by the hour shows
    /// *about* where an edge has got to; the block lands on a quarter-hour, and which quarter is
    /// not something anybody should be reading off a rule. So the geometry says roughly, and this
    /// says exactly.
    ///
    /// Deliberately unanimated, in both directions. The tracking phase of a drag must never be
    /// animated — `SwipeToDelete.swift:350-355` records what 0.24s between a finger and the thing
    /// it is moving feels like.
    private func readout(_ label: String) -> some View {
        Text(label)
            .typeStyle(ScheduleType.blockTimeNow, color: Theme.surface)
            .lineLimit(1)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.tight)
            .background(Theme.accent, in: Capsule(style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var edgeReadout: some View {
        if let resize {
            readout(resize.spanLabel)
                // Clear of the grabber's own lift, and then clear of the grabber.
                .padding(.bottom, Spacing.tight + Spacing.small)
        }
    }

    /// At the top of the card, over its title, because the top edge is what a move is aiming: the
    /// answer somebody is looking for while carrying a block is what time it now starts at, and
    /// that is the edge their eye is on.
    ///
    /// *Inside* the card rather than floating above it, which is where this started. Above, it is
    /// clipped by the scroll view for any block near the top of the day — and a block being carried
    /// to the top of the day is exactly when somebody is reading it. Covering a title for the
    /// length of a drag costs nothing by comparison; the title is not the question.
    @ViewBuilder
    private var moveReadout: some View {
        if let move {
            readout(move.spanLabel)
                .padding(.top, Spacing.tight)
        }
    }

    // MARK: - The bottom edge

    /// The block as it stands, ready to be dragged or adjusted.
    ///
    /// Nil for a block that runs open-ended: `ScheduleBlock.endsAt` is optional, and one with no
    /// end has no bottom edge and no span to read out. Such a block is drawn without a handle
    /// rather than given one that would have to invent an end before it could move it. Its *body*
    /// still moves — see `restingMove`, which takes the optional end as it finds it.
    ///
    /// Built from where the card is *drawn* rather than from the block, so a second drag started
    /// before the first has landed carries on from what is on the screen.
    private var restingResize: ScheduleResizePlan? {
        liveEnd.map {
            ScheduleResizePlan(
                startsAt: liveStart,
                endsAt: $0,
                travelPerStep: ScheduleTimeline.travelPerStep
            )
        }
    }

    /// Whether this card gives up part of its bottom edge to the resize.
    ///
    /// Not below `.compact`, and that is a change from "always". A quarter-hour block is 30pt: a
    /// grabber 6pt off its bottom border lands on the descenders of the one line it has room for,
    /// and the strip that catches a finger reaching for it would be 15pt, which is under half the
    /// platform's minimum target. So the shortest blocks are all body — one tap that opens them and
    /// one hold that carries them — and their length is changed in the editor, or through the two
    /// named actions `liveCard` offers a rotor in place of the handle's.
    private var showsHandle: Bool {
        block.endsAt != nil && tier(for: liveHeight) >= .compact
    }

    /// The grabber, and the strip of card that catches a finger reaching for it.
    ///
    /// Drawn on every platform, unlike `SwipeToDelete`, which excludes the Mac because a
    /// two-finger horizontal swipe has no pointer equivalent (`SwipeToDelete.swift:268-274`).
    /// This gesture does: press, hold, drag is exactly what a mouse does, and the 0.2s hold that
    /// separates it from a scroll on a touchscreen costs a pointer nothing. There is no
    /// unreachable affordance to hide.
    @ViewBuilder
    private var resizeHandle: some View {
        if showsHandle {
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
                // strip lives *inside* the card — hanging below it would put a dead band over the
                // top of whatever is drawn underneath.
                .frame(
                    maxWidth: .infinity,
                    maxHeight: ScheduleMetrics.resizeHitHeight(in: liveHeight),
                    alignment: .bottom
                )
                .contentShape(.rect)
                .gesture(
                    // `exclusively(before:)` rather than two independent gestures, for the reason
                    // `GroupCard.swift:494-499` sets out: `TapGesture` has no maximum duration, so
                    // attached separately it also fires on the *release* of a long press — and a
                    // completed resize would open the block's detail cover on the way out. Offered
                    // the touch only once the hold has definitively failed, the tap means what it
                    // says here, which is the same thing it means anywhere else on the card.
                    edgeLift.exclusively(before: TapGesture().onEnded(onOpen))
                )
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
                    case .increment: stretch(by: 1)
                    case .decrement: stretch(by: -1)
                    @unknown default: break
                    }
                }
        }
    }

    /// Hold, then drag. The long press is what lets this win against the enclosing scroll view's
    /// pan, and it is also what makes an accidental brush of a card harmless.
    ///
    /// **One composition for both drags.** The edge and the body do different arithmetic and share
    /// every part of how a finger reaches it, so this is the shape and the two callers below supply
    /// only where the state lives and what to do with the travel. That is not the trade
    /// `trackResize`/`trackMove` refuse a few lines down: those differ in their *types*, and the
    /// abstraction joining them would be longer than both.
    ///
    /// Both are **vertical** drags, so both are in the second of the two camps
    /// `SwipeToDelete.swift:9-15` sets out: nothing about the movement separates them from a scroll
    /// and only time can. That is why this is `GroupCard`'s and `RankView`'s composition rather
    /// than `SwipeToDelete`'s bare `DragGesture` — and it stays that composition now the card has
    /// a proportional height, because the axis did not change when the geometry did.
    ///
    /// Measured in the canvas's own named space rather than in `.local`. `.local` is relative to
    /// the surface, and the surface is inside a scroll view **and** inside a card these gestures
    /// move — so a `.local` translation would be measured against a view the drag itself is
    /// changing, which is the feedback loop `GroupCard.swift:516-521` describes from the other
    /// side. A space named on the canvas is a frame of reference neither the scroll's offset nor
    /// the card's own growth can shift.
    private func lift(
        holding: GestureState<Bool>,
        begin: @escaping () -> Void,
        track: @escaping (CGFloat) -> Void
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(ScheduleResizePlan.listSpace)
                )
            )
            .updating(holding) { _, state, _ in state = true }
            .onChanged { value in
                switch value {
                case .first(true):
                    begin()
                case .second(true, let drag?):
                    track(drag.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in commit() }
    }

    private var edgeLift: some Gesture {
        lift(holding: $isHoldingEdge, begin: beginResize, track: trackResize)
    }

    // MARK: - The body

    /// The block as it stands, ready to be carried — from where the card is drawn, for
    /// `restingResize`'s reason.
    ///
    /// Takes `endsAt` as it finds it, unlike `restingResize`. A block with no stated end has no
    /// bottom edge to pull, but it has a start, and a start is the whole of what a move changes.
    private var restingMove: ScheduleMovePlan {
        ScheduleMovePlan(
            startsAt: liveStart,
            endsAt: liveEnd,
            travelPerStep: ScheduleTimeline.travelPerStep
        )
    }

    /// The part of the card that takes a move, and a tap.
    ///
    /// A transparent surface rather than a gesture on the plate, and the two are not the same
    /// thing. The resize handle is an overlay *on* the plate, so a gesture attached to the plate
    /// would also be offered every touch that lands on the handle — two long-press-then-drags in
    /// one ambiguity contest, resolved by whichever SwiftUI happens to prefer. Two surfaces that
    /// do not overlap cannot have that argument: the bottom edge resizes, everything above it
    /// moves, and the boundary is `ScheduleMetrics.resizeHitHeight(in:)` for both. On a card with
    /// no handle at all this is the whole of it.
    private var moveSurface: some View {
        let edge = showsHandle ? ScheduleMetrics.resizeHitHeight(in: liveHeight) : 0

        return Color.clear
            .frame(maxWidth: .infinity, maxHeight: max(0, liveHeight - edge), alignment: .top)
            .contentShape(.rect)
            .gesture(bodyLift.exclusively(before: TapGesture().onEnded(onOpen)))
            // The card above already speaks for this region — it carries the sentence, the button
            // trait, the activation and the adjustable action. A second element here would be an
            // unlabelled rectangle sitting on top of it.
            .accessibilityHidden(true)
    }

    /// `lift`'s composition, moving both times instead of one.
    ///
    /// It reaches as far as the finger does and no further: the canvas stops scrolling for the
    /// length of the gesture (`ScheduleView`'s `.scrollDisabled`), so a block can be carried about
    /// a screen. Moving a nine o'clock block into the afternoon is two drags, or the editor's own
    /// two menus. Auto-scrolling at the edge is the standard answer and is not built: it needs the
    /// viewport's bounds inside a gesture measured in the canvas's space, which is a second
    /// geometry to keep in step for a case the editor already covers.
    private var bodyLift: some Gesture {
        lift(holding: $isHoldingBody, begin: beginMove, track: trackMove)
    }

    // MARK: - Tracking

    /// One `onChanged`, written back only when it says something new.
    ///
    /// A touch stream arrives at up to 120Hz and a time moves once every 30pt, so most frames
    /// carry a value identical to the one already held — and `@State` does not compare before it
    /// writes, so each of those still marks the card dirty and re-runs the whole plate, its note
    /// line and its accessibility sentence. `SwipeToDelete.swift:340-346` guards its own per-frame
    /// write for the same reason, one level up.
    ///
    /// Written twice rather than made generic over the two plans. The bodies are four lines each
    /// and the abstraction that would join them — a closure taking an `inout` existential — is
    /// longer than both and reads like neither.
    private func trackResize(_ height: CGFloat) {
        guard var moved = resize else { return }
        moved.drag(by: height)
        if moved != resize { resize = moved }
    }

    private func trackMove(_ height: CGFloat) {
        guard var carried = move else { return }
        carried.drag(by: height)
        if carried != move { move = carried }
    }

    private func beginResize() {
        // Guarded, because `.first(true)` arrives more than once while a press is held, and
        // because `draggingID` is a binding into the screen that owns the canvas: an unguarded
        // write re-runs that whole body — the scroll view, every sibling card — for a value that
        // changes once per gesture. `SwipeToDelete.swift:340-346` guards its own for this reason.
        guard draggingID != block.id else { return }
        resize = restingResize
        draggingID = block.id
    }

    private func beginMove() {
        guard draggingID != block.id else { return }
        move = restingMove
        draggingID = block.id
    }

    /// Tracking down, committing nothing. `pending` is deliberately untouched: a cancelled hold
    /// says nothing about a write that is still in flight.
    private func endTracking() {
        resize = nil
        move = nil
        // Only if it is still ours. A second finger landing on another card claims the id, and
        // clearing it blindly here would unlock the canvas underneath a drag that is still live.
        if draggingID == block.id { draggingID = nil }
    }

    private func commit() {
        let settledResize = resize
        let settledMove = move
        endTracking()

        if let settledResize, settledResize.hasMoved {
            pending = PendingSpan(startsAt: liveStart, endsAt: settledResize.endsAt)
            onResize(settledResize.endsAt)
        } else if let settledMove, settledMove.hasMoved {
            pending = PendingSpan(startsAt: settledMove.startsAt, endsAt: settledMove.endsAt)
            onMove(settledMove.startsAt, settledMove.endsAt)
        }
    }

    /// One rotor step on the handle. Committed immediately, exactly as a tap on "Mark done" is: an
    /// adjustable action is user-paced and discrete, so there is no per-frame write here to batch.
    private func stretch(by steps: Int) {
        guard let restingResize else { return }
        let end = restingResize.adjusted(by: steps)
        guard end != restingResize.restingEnd else { return }
        pending = PendingSpan(startsAt: liveStart, endsAt: end)
        onResize(end)
    }

    /// One rotor step on the card — the move's equivalent, on the same terms.
    private func shift(by steps: Int) {
        let plan = restingMove
        let moved = plan.adjusted(by: steps)
        guard moved.startsAt != plan.restingStart else { return }
        pending = PendingSpan(startsAt: moved.startsAt, endsAt: moved.endsAt)
        onMove(moved.startsAt, moved.endsAt)
    }
}

// MARK: - Previews

#Preview("Blocks") {
    ScheduleBlockCardPreviewHarness()
}

/// Hoisted to file scope for the reason `GroupCardPreviewHarness` was: a `View` declared inside a
/// `#Preview` closure that also returns it makes the compiler's symbol mangler recurse.
///
/// **Deliberately not the canvas.** This harness is about the *card* — the four things it draws at
/// the four heights it can be handed — so it stacks each block at its true height and stops there.
/// The lanes, the gutter and the hour rules are `ScheduleView`'s "Schedule — overlapping" preview,
/// and a second copy of that layout here would be a second place for the packing to be got wrong
/// in and the first place anybody would notice it had drifted.
private struct ScheduleBlockCardPreviewHarness: View {

    @State private var blocks = ScheduleSampleDay.overlappingBlocks(venueID: SampleData.sycamore.id)
    @State private var draggingID: ScheduleBlock.ID?

    var body: some View {
        // The design's clock, so the preview marks the block `8k` marks rather than whichever one
        // the machine's afternoon happens to land in.
        let currentIDs = Set(ScheduleBlock.running(in: blocks, at: TimeOfDay(9, 41)).map(\.id))
        // Rebuilt on every pass here, unlike on the screen, and that is the right trade in a
        // preview: there is no clock ticking behind it, and a flag that appeared only after a
        // reload would be the one thing this harness exists to show.
        let conflicts = ScheduleConflicts(day: blocks)
        let timeline = ScheduleTimeline(day: blocks)

        return ScrollView {
            VStack(spacing: ScheduleMetrics.blockGap) {
                ForEach(blocks) { block in
                    if let placement = timeline[block.id] {
                        ScheduleBlockCard(
                            block: block,
                            isCurrent: currentIDs.contains(block.id),
                            height: placement.height,
                            draggingID: $draggingID,
                            conflict: conflicts[block.id],
                            onOpen: {},
                            // No store in a preview, so the drags land in the array directly.
                            onResize: { end in write(block) { $0.endsAt = end } },
                            onMove: { start, end in
                                write(block) { $0.startsAt = start; $0.endsAt = end }
                            }
                        )
                        .frame(height: placement.height)
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, ScheduleMetrics.listTop)
            .coordinateSpace(.named(ScheduleResizePlan.listSpace))
        }
        .scrollDisabled(draggingID != nil)
        .background(Theme.surfaceWarm)
    }

    private func write(_ block: ScheduleBlock, _ change: (inout ScheduleBlock) -> Void) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        change(&blocks[index])
    }
}
