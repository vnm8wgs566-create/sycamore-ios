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

import SwiftUI

struct ScheduleBlockCard: View {

    let block: ScheduleBlock
    /// The block the camp is in the middle of. See `ScheduleBlock.running(in:at:)`.
    let isCurrent: Bool
    let onOpen: () -> Void

    /// The design draws the gutter 52 wide against a 13pt time. At `.accessibility1` that time
    /// is half again as tall and a fixed column clips it, so the column grows with the type it
    /// is holding.
    @ScaledMetric(relativeTo: .callout) private var timeColumn = ScheduleMetrics.timeColumn
    /// …and so does the drop that lands it on the card's title rather than on its top edge.
    @ScaledMetric(relativeTo: .callout) private var timeBaseline = ScheduleMetrics.timeBaseline

    var body: some View {
        if block.status == .done {
            doneRow
        } else {
            Button(action: onOpen) { card }
                .buttonStyle(.plain)
                // A time, a title, a grey line, a rule, a glyph, a note and a count are seven
                // runs SwiftUI would otherwise read out in order. One sentence instead.
                .accessibilityLabel(block.accessibilityLine(isCurrent: isCurrent))
                .accessibilityHint("Opens the block")
        }
    }

    // MARK: Behind us

    /// No card and nothing to press: a finished block is history, and the design gives it no
    /// affordance at all. Its time goes grey with it so the gutter stops advertising it.
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

                Text(pinned)
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
}

// MARK: - Previews

#Preview("Blocks") {
    let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
    // The design's clock, so the preview marks the block `8k` marks rather than whichever one
    // the machine's afternoon happens to land in.
    let currentID = ScheduleBlock.running(in: blocks, at: TimeOfDay(9, 41))?.id

    return ScrollView {
        VStack(spacing: ScheduleMetrics.blockGap) {
            ForEach(blocks) { block in
                ScheduleBlockCard(block: block, isCurrent: block.id == currentID) {}
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, ScheduleMetrics.listTop)
    }
    .background(Theme.surfaceWarm)
}
