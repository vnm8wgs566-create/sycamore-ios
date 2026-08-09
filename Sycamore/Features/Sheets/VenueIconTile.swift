//
//  VenueIconTile.swift
//  Sycamore
//
//  Screen 11's icon grid, one tile of it: `width:52px;height:52px;border-radius:15px;font-size:23px`,
//  white with a `#EAEBEE` rule, and `#1568F0` on `#EDF3FE` when it is the chosen one
//  (`design/Sycamore Flow.dc.html:480-485`).
//
//  It lived as a `private struct IconTile` inside `VenueSheet` until "Shape the camp" grew a venue
//  editor of its own, which draws the same six tiles from the same drawing. `Motion.swift:12` sets
//  the condition for hoisting something into a shared file — two features needing the same thing —
//  and this is the second feature.
//
//  Renamed on the way out. `IconTile` is a name three features could each want for a different
//  thing; `VenueIconTile` says which grid it belongs to, and leaves the plain name free.
//
//  Deliberately not merged with `IntakeIconTile`, which looks similar and is not: that one is a
//  *decorative* plate that hides itself from VoiceOver because the row beside it names the venue.
//  This is a control — it is chosen, it carries `.isSelected`, and its emoji is the only thing
//  there is to read.
//

import SwiftUI

/// 52pt square, radius 15. Selected takes the blue border and tint; the rest are white.
struct VenueIconTile: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                .fill(isSelected ? Theme.accentTint : Theme.surface)
                .frame(width: 52, height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.strokeAlt,
                            lineWidth: BorderWidth.hairline
                        )
                }
                // `.font(.system(size:))` because this is a glyph rather than copy, which is the
                // one case the type table does not cover.
                .overlay { Text(icon).font(.system(size: 23)) }
                .contentShape(RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - The grid

/// All six of them, laid out as screen 11 draws them: `display:flex;flex-wrap:wrap;gap:7px`
/// (`design/Sycamore Flow.dc.html:479`).
///
/// Hoisted here a beat after the tile was, and for a sharper reason. The two venue editors each
/// drew this loop, and by the time they were put side by side they had already drifted: one had
/// the selection haptic and the other did not, so choosing an emoji felt different on two screens
/// showing the same six tiles. The tile being shared was not enough — what a reader actually meets
/// is the grid.
///
/// `onChoose` rather than a `Binding`, because the two callers do different amounts of work with
/// the answer: `VenueShape.tint` is computed from the emoji and needs nothing, while `Venue.tint`
/// is stored and has to be brought along. A binding would have put that difference back in the
/// call sites as a second write nobody could see from here.
struct VenueIconGrid: View {
    let selected: String
    let onChoose: (String) -> Void

    var body: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(Venue.iconOptions, id: \.self) { icon in
                VenueIconTile(icon: icon, isSelected: selected == icon) { onChoose(icon) }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Previews

#Preview("Venue icon tiles") {
    @Previewable @State var chosen = Venue.iconOptions[0]

    FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
        ForEach(Venue.iconOptions, id: \.self) { icon in
            VenueIconTile(icon: icon, isSelected: chosen == icon) { chosen = icon }
        }
    }
    .padding(Spacing.sheet)
    .background(Theme.surface)
}
