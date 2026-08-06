//
//  InboxAllClearCard.swift
//  Sycamore
//
//  `8h`'s answer to an empty inbox: a green tick, "All clear.", and a sentence saying what
//  would have been here.
//
//  The sentence is the point. An empty screen that says only "nothing here" leaves the reader
//  unsure whether the app is quiet or broken; this one names the four things that land in the
//  Inbox, so silence reads as silence.
//
//  Not `ContentUnavailableView`. This state is drawn — a bordered card, a 56pt disc with its own
//  ring, three exact type sizes and a 250pt measure on the copy — and the system view offers no
//  way to reach any of it. The filtered-empty state, which the design does *not* draw, is the
//  one that uses it.
//

import SwiftUI

struct InboxAllClearCard: View {

    /// The disc and its tick grow with the reader's text size; a 56pt mark above copy set at
    /// `.accessibility1` reads as a bullet rather than as the subject of the card.
    @ScaledMetric(relativeTo: .largeTitle) private var mark: CGFloat = InboxMetrics.allClearMark
    @ScaledMetric(relativeTo: .largeTitle) private var markGlyph: CGFloat = InboxMetrics.allClearMarkGlyph
    /// The measure grows with the copy it holds. Left at a flat 250 it stopped being a line
    /// length and became a column three words wide.
    @ScaledMetric(relativeTo: .body) private var bodyWidth: CGFloat = InboxMetrics.allClearBodyWidth

    var body: some View {
        Card(radius: InboxMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Theme.accentSurface)
                    .frame(width: mark, height: mark)
                    .overlay {
                        Circle().strokeBorder(Theme.accentSurfaceBorder, lineWidth: BorderWidth.hairline)
                    }
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: markGlyph, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityHidden(true)

                Text("All clear.")
                    .typeStyle(InboxType.allClearTitle, color: Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, InboxMetrics.allClearTitleTop)

                Text("Court moves, early pick-ups, staff joining and pinned notes all land here.")
                    .typeStyle(InboxType.allClearBody, color: Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    // `max-width:250px`, so the copy wraps as a paragraph rather than running
                    // the width of the card.
                    .frame(maxWidth: bodyWidth)
                    .padding(.top, InboxMetrics.allClearBodyTop)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, InboxMetrics.allClearPaddingV)
            .padding(.horizontal, InboxMetrics.allClearPaddingH)
        }
        // One announcement rather than three. The tick carries no information the headline does
        // not, and the sentence is a continuation of it.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("All clear") {
    VStack {
        InboxAllClearCard()
        Spacer()
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.surfaceWarm)
}
