//
//  CourtNoteRow.swift
//  Sycamore
//
//  One note written against a court, on the court's own screen.
//
//  **Deliberately not `PinnedNoteBanner`.** That component is a one-line reminder that a note
//  exists, clipped rather than wrapped, ending in "Open" — because on Overview the note itself is
//  somewhere else. This screen *is* somewhere else. A row here that truncated the sentence and
//  offered to open it would be pointing at itself, so the words wrap and the row is a line of a
//  list rather than a control.
//
//  It is a row inside a `Card` rather than a plate of its own, which is how `8q` draws its
//  pick-ups: the card supplies the rule between two notes, and a court with one note then reads
//  as one card rather than as a lone floating banner.
//

import SwiftUI

struct CourtNoteRow: View {

    let item: InboxItem

    /// The glyph rides the ramp its own point size sits on, so it grows with the sentence beside
    /// it rather than staying pinned while the line around it doubles. 14 is the body band.
    @ScaledMetric(relativeTo: .body) private var glyphSize = OverviewTheme.bannerGlyph

    var body: some View {
        HStack(alignment: .top, spacing: OverviewTheme.bannerGap) {
            // A pin for a note somebody has held up, the writing mark for the rest. Two glyphs
            // rather than one shown-or-hidden, so the column stays the same width down the card
            // and the pinned note is marked out by what its glyph *is* rather than by the
            // paragraph having shifted sideways.
            Image(systemName: item.pinned ? "pin.fill" : "square.and.pencil")
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(item.pinned ? Theme.accent : Theme.glyph)
                // The word "Pinned" is in the spoken label below, where it reads as part of the
                // sentence instead of interrupting it.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(words)
                    .typeStyle(.caption, color: Theme.inkWarm)
                    // Unclipped, which is the whole reason this row exists. A note is the one
                    // thing on the screen that cannot be guessed from the half of it that fits.
                    .fixedSize(horizontal: false, vertical: true)

                Text(attribution)
                    .typeStyle(.metaSmall, color: Theme.inkFaint)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnTheDayTokens.cardInset)
        .padding(.vertical, Spacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        // One element: a note is a sentence and its byline, and swiping between the two says
        // nothing the pair does not say together.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// The note's own words.
    ///
    /// `detail` when there is one, because a court note is written `title: "Nass · Court 1"`,
    /// `detail: "Two in sandals…"` — the same reading `OverviewScreen` takes for the banner. A row
    /// that has only a title is the admin's camp-wide message, where the title *is* the message.
    private var words: String { item.detail ?? item.title }

    /// `Nass · Court 1 · 52 min ago`, or just the age when the words above were the title.
    ///
    /// The age is formatted from `createdAt` every time it is drawn, never stored — "8 min ago"
    /// written into a column is wrong a minute later. `InboxNeedsActionRow` says the same thing
    /// the same way.
    private var attribution: String {
        let age = item.createdAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
        guard item.detail != nil else { return age }
        return "\(item.title) · \(age)"
    }

    private var spoken: String {
        let lead = item.pinned ? "Pinned note. " : "Note. "
        return "\(lead)\(words). \(attribution)"
    }
}

// MARK: - Previews

#Preview("Court notes") {
    VStack(spacing: OnTheDayTokens.contentGap) {
        Card(radius: OnTheDayTokens.card) {
            ForEach(OverviewFixtures.courtNotes) { note in
                CourtNoteRow(item: note)
            }
        }

        // The ordinary case now that `pinned` is a column nobody backfilled: a court whose notes
        // are all unpinned.
        Card(radius: OnTheDayTokens.card) {
            ForEach(OverviewFixtures.courtNotes.filter { !$0.pinned }) { note in
                CourtNoteRow(item: note)
            }
        }
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
