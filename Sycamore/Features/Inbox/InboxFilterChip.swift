//
//  InboxFilterChip.swift
//  Sycamore
//
//  One of All / Needs you / Notes.
//
//  Not the shared `Chip`. Its nearest preset (`.attribute`) is drawn from a different screen
//  and disagrees with `8r` on every property that matters: `600 12` against the design's
//  `600 13`, `6/12` padding against `8/15`, `strokeChip` against `strokeAlt`, and an
//  `inkSecondary` label where the design writes `inkMuted`. The last two live inside `Chip`
//  itself rather than in its metrics, so there was nothing to pass. A `ChipTone` whose
//  unselected label is `inkMuted` is the hoist candidate — see the pull request.
//

import SwiftUI

struct InboxFilterChip: View {

    let option: InboxFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.title)
                .typeStyle(InboxType.filterChip, color: isSelected ? Theme.surface : Theme.inkMuted)
                .lineLimit(1)
                .padding(.horizontal, InboxMetrics.chipPaddingH)
                .padding(.vertical, InboxMetrics.chipPaddingV)
                // `ink` and `surface` invert together, so a selected chip stays legible in the
                // dark. The unselected one draws no fill at all in the design — the white of
                // the header block is its background.
                .background(isSelected ? Theme.ink : .clear, in: .capsule(style: .continuous))
                .overlay {
                    if !isSelected {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.strokeAlt, lineWidth: BorderWidth.hairline)
                    }
                }
                // The chip keeps the ~29pt the design draws it at; only the region that takes
                // the tap reaches the 44pt minimum.
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Without `.isSelected` the three read identically to VoiceOver and the reader has no
        // way to tell which filter the list is already under.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Previews

#Preview("Filter chip") {
    HStack(spacing: InboxMetrics.chipGap) {
        InboxFilterChip(option: .all, isSelected: true) {}
        InboxFilterChip(option: .needsYou, isSelected: false) {}
        InboxFilterChip(option: .notes, isSelected: false) {}
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
