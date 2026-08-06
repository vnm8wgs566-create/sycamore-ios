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
    /// The block the day is on. See `ScheduleDay.currentBlockID`.
    let isCurrent: Bool
    let onOpen: () -> Void

    var body: some View {
        if block.status == .done {
            doneRow
        } else {
            Button(action: onOpen) { card }
                .buttonStyle(.plain)
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
                // `minWidth`, not `width`: the column is 52 in the design, but the time inside
                // it grows with Dynamic Type and a fixed box wraps "10:45" onto two lines.
                .frame(minWidth: ScheduleMetrics.timeColumn, alignment: .leading)

            Text(block.doneLabel)
                .typeStyle(.body, color: Theme.chevron)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ScheduleMetrics.rowInset)
        .accessibilityElement(children: .combine)
    }

    // MARK: Still to come

    private var card: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Text(block.gutterLabel)
                .typeStyle(
                    isCurrent ? ScheduleType.blockTimeNow : ScheduleType.blockTime,
                    color: isCurrent ? Theme.accent : Theme.inkFaint
                )
                // `minWidth`, not `width`: the column is 52 in the design, but the time inside
                // it grows with Dynamic Type and a fixed box wraps "10:45" onto two lines.
                .frame(minWidth: ScheduleMetrics.timeColumn, alignment: .leading)
                // The gutter time lines up with the card's title, not with its top edge.
                .padding(.top, ScheduleMetrics.timeBaseline)

            plate
        }
    }

    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: ScheduleMetrics.cardRadius, style: .continuous)
        let lift = ScheduleShadows.currentBlock

        return VStack(alignment: .leading, spacing: 0) {
            Text(block.title)
                .typeStyle(
                    isCurrent ? ScheduleType.blockTitleNow : ScheduleType.blockTitle,
                    color: Theme.ink
                )

            if let subtitle = block.subtitle {
                Text(subtitle)
                    .typeStyle(ScheduleType.blockDetail, color: block.status.tint)
                    .padding(.top, Spacing.tight)
            }

            if !block.notes.isEmpty {
                Hairline(color: Theme.hairlineSoft)
                    .padding(.top, Spacing.row)

                noteLine
                    .padding(.top, Spacing.row)
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
        // Spelled out rather than branched, so the card keeps one identity when the day moves on
        // and this block stops being the current one.
        .shadow(color: isCurrent ? lift.color : .clear, radius: lift.radius, y: lift.y)
        .contentShape(shape)
    }

    /// The current block pins its first note and counts the rest; every other block only says
    /// how many there are. The design being deliberate — the note you need mid-session is the
    /// one about the court you are standing on, and it should not cost a tap.
    @ViewBuilder
    private var noteLine: some View {
        if isCurrent, let pinned = block.notes.first {
            HStack(spacing: Spacing.tight) {
                DisclosureChevron(systemName: "pin.fill", size: 13, color: Theme.accent)

                Text(pinned)
                    .typeStyle(ScheduleType.noteLine, color: ScheduleTheme.noteInk)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: Spacing.tight)

                if block.additionalNoteCount > 0 {
                    Text("+\(block.additionalNoteCount)")
                        .typeStyle(ScheduleType.noteLine, color: Theme.inkFaint)
                        // Without this the count is the run that gets truncated, and the note it
                        // is counting eats the whole line.
                        .layoutPriority(1)
                }
            }
        } else if let summary = block.noteSummary {
            HStack(spacing: Spacing.tight) {
                DisclosureChevron(systemName: "note.text", size: 14, color: Theme.inkFaint)

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
    let currentID = ScheduleDay.currentBlockID(in: blocks)

    return ScrollView {
        VStack(spacing: ScheduleMetrics.blockGap) {
            ForEach(blocks) { block in
                ScheduleBlockCard(block: block, isCurrent: block.id == currentID) {}
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, ScheduleMetrics.listTop)
    }
    .background(Theme.grouped)
}
