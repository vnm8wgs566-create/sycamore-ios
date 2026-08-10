//
//  CourtCapacityBadge.swift
//  Sycamore
//
//  "6 of 8" and the dashed green pill beside it saying "2 spots".
//
//  4a's header row, third and fourth cells:
//
//      <div style="font:400 12.5px 'Instrument Sans';color:#A2A6AE">6 of 8</div>
//      <div style="display:flex;align-items:center;gap:5px;background:#F6FAF7;
//                  border:1px dashed #C3DFCF;border-radius:999px;padding:3px 10px">
//        <span style="font:600 11px 'Instrument Sans';color:#1A7F55">2 spots</span>
//      </div>
//
//  ── The `+` was drawn, was not a control, and is now not drawn ───────────────────────────────
//
//  `8i` put an 18pt white disc with an 11pt `+` inside this pill, and this file argued at length
//  that it had to stay inert: the vocabulary said "press me" — it is the same dashed-green-with-a-
//  plus the empty coach slot wears two rows down, and *that* one fills the court — but there was
//  nothing on the other side of the press. Putting a kid on a court is enrolment, which is
//  `Camp.move(_:to:)` behind Groups' drag-and-drop, and a `+` here would have to guess which kid.
//
//  4a removes the glyph, which is a better answer than the paragraph. The pill is one child now:
//  the count, in a dashed green capsule with symmetric padding. Nothing on it looks like a button,
//  so nothing has to be explained away — "there is room here" is a reading, and it now looks like
//  one. The dashed rule stays, because a dash is still this screen's way of drawing a space with
//  nothing in it yet.
//
//  It remains one accessibility element with one label and no button trait, which is what stopped
//  it lying to a reader who could not see that nothing happened. `CourtStatusBadge` makes the same
//  call about the `Closed` badge for the same reason.
//
//  ── And the amber half is not in the design at all ───────────────────────────────────────────
//
//  `8i` never draws a court over its ceiling, and draws the one at exactly 8 of 8 with no pill.
//  `CourtCapacity` explains why both states are named anyway; what they look like is settled by
//  `WarningPill`, which is the plate the `Closed` badge on this very row already wears. Full,
//  over-full and out-of-play are the things on this screen somebody has to do something about, and
//  on a court that is more than one of them they appear an inch apart — so they are one component
//  and not three drawings that agree today.
//
//  ── The treatment table is one switch ────────────────────────────────────────────────────────
//
//  `pill(_:)` is the whole of what this screen decides, and it decides it over `CourtCapacity.Flag`
//  rather than over an `isOver` test with a nil `pillLabel` underneath. That is what stops the pill
//  and the accessibility label below it disagreeing: they read the same state, and the sentence
//  VoiceOver hears is `spokenLabel`'s fold of that same flag. `PlayerCourtChoices` has the matching
//  switch on the other side, and `CourtCapacity`'s header argues why the two are allowed to differ
//  on `.room` and not on anything amber.
//

import SwiftUI

struct CourtCapacityBadge: View {

    let capacity: CourtCapacity

    var body: some View {
        HStack(spacing: OverviewTheme.capacityReadingGap) {
            Text(capacity.reading)
                .typeStyle(OverviewTheme.capacityReading, color: Theme.inkFaint)
                // Tabular, so a card reading "10 of 12" does not shove the pill beside it a
                // pixel further left than the card above it reading "8 of 8".
                .monospacedDigit()
                .lineLimit(1)

            pill(capacity.flag)
        }
        // One element, one sentence. Drawn as three runs — a figure, a mark and a count — which
        // VoiceOver would otherwise read as "6 of 8", "2 spots" with no thread between them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(capacity.spokenLabel)
    }

    // MARK: The pill

    /// This screen's whole treatment table, in one place. See the file header.
    @ViewBuilder
    private func pill(_ flag: CourtCapacity.Flag) -> some View {
        switch flag {
        case .room:
            roomPill(flag.label)
        // No disc and no `+`: there is nothing to add to a court that is full, past full, or out
        // of play. `.closed` cannot arrive here — `CourtCapacity.reading(for:capacity:)` answers
        // nil for a shut court and this badge is not drawn — but it is listed rather than defaulted
        // away, because if closure ever did reach this slot the amber plate is the right answer and
        // a `default` would have silently made it the wrong one.
        case .full, .over, .closed:
            WarningPill(label: flag.label)
        }
    }

    /// The design's own pill: a count, in a dashed green plate. See the file header for the disc
    /// that used to sit in front of it.
    ///
    /// Deliberately not `Badge` — which is `700 9.5` uppercase and tracked (`Components.swift:1001`)
    /// where this is `600 11` sentence case — and deliberately not `Chip`, which is a control with a
    /// selected state this pill has no version of. But the reason neither could take it even retuned
    /// is the `dash:`. `Badge` draws its plate with `.background(_:in:)` and no stroke at all
    /// (`Components.swift:1005`); `Chip` strokes a solid hairline whose only variable is a colour
    /// picked from its tone (`Components.swift:376`). Neither exposes a `StrokeStyle`, and a dashed
    /// border is not a colour or a metric — it is a different way of drawing the edge, so there is no
    /// parameter either could grow short of one for this caller. Its exact counterpart
    /// `VenuePickerSheet.shortfallBadge` (`VenuePickerSheet.swift:314-318`) carries the same note,
    /// and carried it alone until now.
    private func roomPill(_ label: String) -> some View {
        Text(label)
            .typeStyle(OverviewTheme.capacityPill, color: Theme.accent)
            .lineLimit(1)
            .padding(.horizontal, OverviewTheme.capacityPillHorizontal)
            .padding(.vertical, OverviewTheme.capacityPillVertical)
        .background(Theme.accentSurface, in: capsule)
        // `dash:` on the stroke, which is the design's `border:1px dashed`. The same
        // vocabulary as the empty coach slot below it — a dashed outline is this screen's
        // way of drawing a space with nothing in it yet.
        .overlay {
            capsule.strokeBorder(
                Theme.accentBorder,
                style: StrokeStyle(lineWidth: BorderWidth.hairline, dash: OverviewTheme.dash)
            )
        }
    }

    private var capsule: Capsule { Capsule(style: .continuous) }
}

// MARK: - Previews

#Preview("Room on a court") {
    VStack(alignment: .trailing, spacing: Spacing.medium) {
        // 4a's three readings, in the order it draws them — the first of which now wears the
        // amber the design leaves it without. See `CourtCapacity`'s header for why.
        CourtCapacityBadge(capacity: CourtCapacity(here: 8, capacity: 8))
        CourtCapacityBadge(capacity: CourtCapacity(here: 6, capacity: 8))
        CourtCapacityBadge(capacity: CourtCapacity(here: 7, capacity: 8))
        // The two the design does not draw: a court that is over, and one nobody has arrived at.
        CourtCapacityBadge(capacity: CourtCapacity(here: 9, capacity: 8))
        CourtCapacityBadge(capacity: CourtCapacity(here: 0, capacity: 8))
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .background(Theme.surface)
}

/// The size the app caps Dynamic Type at. The pill is one label in a capsule now, so it should
/// simply get longer.
#Preview("Room on a court — accessibility1") {
    VStack(alignment: .trailing, spacing: Spacing.medium) {
        CourtCapacityBadge(capacity: CourtCapacity(here: 6, capacity: 8))
        CourtCapacityBadge(capacity: CourtCapacity(here: 9, capacity: 8))
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .background(Theme.surface)
    .environment(\.dynamicTypeSize, .accessibility1)
}
