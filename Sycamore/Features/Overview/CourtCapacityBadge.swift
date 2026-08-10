//
//  CourtCapacityBadge.swift
//  Sycamore
//
//  "6 of 8" and the dashed green pill beside it saying "2 spots".
//
//  `8i`'s header row, third and fourth cells:
//
//      <div style="font:400 12.5px 'Instrument Sans';color:#A2A6AE">6 of 8</div>
//      <div style="display:flex;align-items:center;gap:5px;background:#F6FAF7;
//                  border:1px dashed #C3DFCF;border-radius:99px;padding:3px 9px 3px 4px">
//        <div style="width:18px;height:18px;border-radius:99px;background:#fff;
//                    border:1px solid #E4EDE7;…"><i class="ph ph-plus" …></i></div>
//        <span style="font:600 11px 'Instrument Sans';color:#1A7F55">2 spots</span>
//      </div>
//
//  ── The `+` is drawn, and it is not a control ────────────────────────────────────────────────
//
//  It looks like one, and that is a genuine tension worth stating rather than resolving quietly.
//  The design gives this pill the same dashed-green-with-a-plus treatment it gives the empty coach
//  slot two rows down, which *is* the way to fill the court — so the vocabulary says "press me".
//
//  It stays inert because there is nothing on the other side of the press. Putting a kid on a court
//  is enrolment: it is `Camp.move(_:to:)` behind Groups' own drag-and-drop, on a screen built to
//  weigh one court against another, and a `+` here would have to guess *which* kid. Overview offers
//  two writes and their whole justification is that each fixes the exact state it is drawn beside
//  (`OverviewScreen.swift:23-31`); "there is room here" is not a defect to fix, it is a fact.
//
//  So the pill is one accessibility element with one label, carries no button trait, and cannot be
//  focused as a control — which is what stops it lying to a reader who cannot see that nothing
//  happens. `CourtStatusBadge` makes the same call about the `Closed` badge for the same reason.
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

    /// The disc rides the `+` inside it, and both ride `.caption` — the band the 11pt label sits
    /// in — so the pill keeps its proportions at every type size instead of the glyph outgrowing
    /// the circle around it.
    @ScaledMetric(relativeTo: .caption) private var discSize = OverviewTheme.capacityPillDisc
    @ScaledMetric(relativeTo: .caption) private var plusSize = OverviewTheme.capacityPillGlyph

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

    /// The design's own pill: a `+` in a disc, a count, and a dashed green plate around both.
    private func roomPill(_ label: String) -> some View {
        HStack(spacing: OverviewTheme.capacityPillGap) {
            // `surface` and a solid ring rather than the coach slot's tinted, dashed disc: this
            // one is inside a plate that is already `accentSurface` and dashed, so a second
            // dash within a dash reads as fraying. The design draws it `#fff` on a solid
            // `#E4EDE7` for the same reason.
            PlusDisc(
                size: discSize,
                glyphSize: plusSize,
                fill: Theme.surface,
                border: Theme.accentSurfaceBorder,
                isDashed: false
            )

            Text(label)
                .typeStyle(OverviewTheme.capacityPill, color: Theme.accent)
                .lineLimit(1)
        }
        .padding(.leading, OverviewTheme.capacityPillLeading)
        .padding(.trailing, OverviewTheme.capacityPillTrailing)
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
        // `8i`'s three readings, in the order it draws them — the first of which now wears the
        // amber the design leaves it without. See the file header for why.
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

/// The size the app caps Dynamic Type at. The disc and the `+` in it ride one ramp, so the pill
/// should grow without the glyph breaking out of the circle.
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
