//
//  CourtRosterButton.swift
//  Sycamore
//
//  One name on a court, and the way to the kid behind it.
//
//  `CourtRosterRow` draws the line and deliberately takes no gestures of its own — a list you can
//  open is a property of the screen, not of the row, and a card that only reads has to keep drawing
//  the same kid identically. This is the other half: the button that wraps it where the screen does
//  want the tap.
//
//  It arrived a wave after both of its callers. `CourtScreen` had the button, Overview's court
//  cards did not, and the change that gave Overview one wrote the same twenty lines a second time —
//  correctly, because landing a shared view with a single consumer would have left the original
//  standing beside a view calling itself shared, which is three spellings of one control where
//  there were two. Both consumers exist now, so this is the third view neither could write alone.
//
//  Here rather than in `DesignSystem/`: it knows what a `PlayerRow` is and what
//  `CourtRosterRow.spokenLabel(for:)` says, which are facts about this feature and not about
//  buttons. If a third screen outside Overview and Court ever wants it, that is when it moves.
//

import SwiftUI

/// A kid's line, grown to a tappable target and given the words VoiceOver needs.
struct CourtRosterButton: View {

    let row: PlayerRow
    /// Horizontal padding inside the tap target, for a screen whose column is not already inset.
    ///
    /// The court screen's rows sit against the frame and pay `OnTheDayTokens.cardInset` here;
    /// Overview's already sit inside the card's own padding and pass nothing. It is the one thing
    /// the two callers disagreed about, so it is the one thing this takes.
    var inset: CGFloat = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CourtRosterRow(row: row)
                .padding(.horizontal, inset)
                // The drawn line keeps the height the design gives it and the touch grows around
                // it. Grown first, shaped second — the reverse pins the target back onto the drawn
                // line and hands out a column of ~20pt targets. It is the order `CourtCoachLine`
                // and `MoreRow` in the same column are already written in.
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Set outright rather than left to be lifted off the row inside the label.
        // `spokenLabel(for:)` is `static` for exactly this — see its doc for what a column of
        // buttons all announced as "Button" costs a reader who cannot see which kid is which.
        .accessibilityLabel(CourtRosterRow.spokenLabel(for: row))
        // One sentence for the act, in one place. Two copies of this string were the thing most
        // likely to drift while the two screens were written apart — a kid reached from Overview
        // and the same kid reached from their court would have started describing the same tap
        // differently, and nothing would have failed.
        .accessibilityHint("Opens their screen")
    }
}

// MARK: - Previews

#Preview("Roster button") {
    let store = OverviewFixtures.courtStore

    return VStack(spacing: 0) {
        ForEach(OverviewFixtures.fullRoster(for: OverviewFixtures.drills).rows) { row in
            CourtRosterButton(row: row) {}
        }
    }
    .padding(.horizontal, OverviewTheme.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
    .environment(store)
}

#Preview("Roster button — accessibility1") {
    let store = OverviewFixtures.courtStore

    return VStack(spacing: 0) {
        ForEach(OverviewFixtures.fullRoster(for: OverviewFixtures.drills).rows) { row in
            CourtRosterButton(row: row, inset: OnTheDayTokens.cardInset) {}
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
    .environment(store)
    .dynamicTypeSize(.accessibility1)
}
