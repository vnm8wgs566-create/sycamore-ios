//
//  FoldedRosterSection.swift
//  Sycamore
//
//  A section header and a card of rows, folded to four behind "See all".
//
//  The design's rule, and it is a good one: forty names is not a list anybody reads — it is a
//  number, and the number is already at the top of the screen. So the rows that need nothing from
//  the reader are shown four at a time and the rest are one tap away.
//
//  Both review screens want it. `8d` folds the rows that read cleanly; `RosterReviewView` folds
//  the kids the file agrees with the camp about, which is the same idea a week later — the section
//  that exists to be *not* read.
//
//  The pieces that had to travel together are why this is one view rather than a modifier: the
//  fold state, the count in the header, the word on the action ("See all" / "See fewer"), the
//  animation, and the decision to draw no action at all when everything already fits. Splitting
//  them leaves four things at each call site that have to agree.
//
//  What is deliberately *not* here is the row. Each screen draws its own — `8d` puts a gender mark
//  on the trailing edge, the re-import screen puts the kid's meta line under their name — so the
//  content is a builder. What is shared is the fold, not the layout.
//

import SwiftUI

struct FoldedRosterSection<Row: Identifiable, RowContent: View>: View {

    /// Including the count, because the two callers count different things: `8d` counts rows in
    /// the file and the re-import screen counts kids at the camp. Composing it here would mean
    /// naming one of those.
    let title: String
    let rows: [Row]
    @ViewBuilder let row: (Row) -> RowContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsEverything = false

    /// The design's fold. Four is the number `8d` draws.
    private static var foldedCount: Int { 4 }

    private var shown: ArraySlice<Row> {
        showsEverything ? rows[...] : rows.prefix(Self.foldedCount)
    }

    /// Nil when the whole list already fits — a control that does nothing is worse than no
    /// control.
    private var actionTitle: String? {
        guard rows.count > Self.foldedCount else { return nil }
        return showsEverything ? "See fewer" : "See all"
    }

    var body: some View {
        // `IntakeSectionHeader` draws the action only when it has both a title and a closure, so
        // the two are supplied or withheld together. Bound out of the ternary rather than written
        // inline: the expression is `String?` and `(() -> Void)?` decided by the same condition,
        // which the type checker has to solve twice.
        let onToggle: (() -> Void)? = actionTitle == nil ? nil : { toggle() }

        return VStack(alignment: .leading, spacing: 0) {
            IntakeSectionHeader(
                title,
                trackingEm: 0.14,
                actionTitle: actionTitle,
                horizontalPadding: 4,
                bottomPadding: 0,
                action: onToggle
            )

            Card(radius: OnboardingMetrics.cardRadius) {
                ForEach(shown) { entry in
                    row(entry)
                }
            }
            // The 9pt this column runs on. Inside the section rather than at the call site so the
            // header and its card arrive as one block wherever they are dropped.
            .padding(.top, OnboardingMetrics.cardGap)
        }
    }

    /// Thirty-six rows arriving at once is a jump wherever it happens; the fade is what says they
    /// were already there. Through `Motion.fold(reduceMotion:)` like every other animation in the
    /// app, which returns nil when the reader has asked for less movement.
    private func toggle() {
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) { showsEverything.toggle() }
    }
}
