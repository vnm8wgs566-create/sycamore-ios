//
//  BlockCourtCard.swift
//  Sycamore
//
//  The green card at the top of `8l` — what this block means for the court you are standing on.
//
//  Takes plain values rather than the store, so the card redraws when the block or the head-count
//  changes and not because something unrelated in the camp graph did.
//

import SwiftUI

struct BlockCourtCard: View {

    let block: ScheduleBlock
    /// "Court 1" — the court the signed-in person is posted to.
    let courtLabel: String
    let playersHere: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ScheduleMetrics.cardRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your court")
                        .typeStyle(ScheduleType.cardOverline, color: Theme.accent)

                    Text("\(courtLabel) – \(block.title)")
                        .typeStyle(ScheduleType.courtTitle, color: Theme.ink)
                        .padding(.top, Spacing.tight)

                    Text(block.courtMetaLine(playersHere: playersHere))
                        .typeStyle(ScheduleType.courtMeta, color: Theme.inkMuted)
                        .padding(.top, Spacing.hairGap)
                }

                Spacer(minLength: Spacing.small)

                openBadge
            }

            if let pinned = block.notes.first {
                pinnedNote(pinned)
                    .padding(.top, Spacing.row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ScheduleMetrics.cardPadding)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.input) }
        .shadow(ScheduleShadows.currentBlock)
    }

    /// A badge, not a button. The design draws it as a filled green pill, but closing a court is
    /// Overview's write (`setCourtStatus`) and nothing on this screen owns it — so it reports
    /// rather than pretending to act.
    private var openBadge: some View {
        Text(CourtStatus.open.badge)
            .typeStyle(ScheduleType.courtBadge, color: Theme.onAccent)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .background(Theme.accent, in: Capsule(style: .continuous))
            .accessibilityLabel("This court is open")
    }

    /// The block's first note, kept on the card so the thing you need mid-session does not cost
    /// a tap. The rest are counted, and live in the notes row further down.
    private func pinnedNote(_ text: String) -> some View {
        let plate = RoundedRectangle(cornerRadius: Radius.chipSquare, style: .continuous)

        return HStack(spacing: ScheduleMetrics.blockGap) {
            DisclosureChevron(systemName: "pin.fill", size: 13, color: Theme.accent)

            Text(text)
                .typeStyle(ScheduleType.pinnedNote, color: ScheduleTheme.noteInk)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Spacing.tight)

            if block.additionalNoteCount > 0 {
                Text("+\(block.additionalNoteCount)")
                    .typeStyle(ScheduleType.noteLine, color: Theme.inkFaint)
                    // Without this the count is the run that gets truncated, and the note it is
                    // counting eats the whole line.
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, Spacing.row)
        .padding(.vertical, ScheduleMetrics.blockGap)
        .background(ScheduleTheme.noteTint, in: plate)
        .overlay {
            plate.strokeBorder(ScheduleTheme.noteTintBorder, lineWidth: BorderWidth.hairline)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Your court") {
    let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)

    return VStack(spacing: ScheduleMetrics.blockGap) {
        BlockCourtCard(block: blocks[1], courtLabel: "Court 1", playersHere: 8)
        BlockCourtCard(block: blocks[4], courtLabel: "Court 1", playersHere: 8)
    }
    .padding(Spacing.gutter)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.grouped)
}
