//
//  TournamentBracketColumn.swift
//  Sycamore
//
//  One round of a knockout, as a column of two-line boxes.
//
//  The bracket is the one part of this tab that scrolls sideways, and it has to: a draw of sixteen
//  is four columns, and four columns of legible names do not fit the width of a phone. The design
//  makes the same call (`overflow-x:auto` on the strip, `flex:none;width:150px` on each column) and
//  the alternative — shrinking the type until it fits — would make the widest draw the least
//  readable one.
//
//  ── WHY A BOX MAY SAY "WINNER OF M7" ──────────────────────────────────────────────────────────
//
//  Because the whole bracket is struck at once. `Tournament.knockoutMatches` mints the later rounds
//  at the same moment as the first and points them at *matches* rather than at entrants, which is
//  what lets the draw be printed on Thursday night. So a box in the semis names what it is waiting
//  for until the quarters have been played, and the number it names is the same `M7` the order of
//  play prints — `TournamentPlan` numbers the matches once and both readings use that numbering.
//
//  ── AND WHY ONE MAY SAY "BYE" ─────────────────────────────────────────────────────────────────
//
//  A draw of eleven pads to sixteen, and the five top seeds get a first round with nobody in it.
//  That is the point of the seeding rather than a hole in it — 1-vs-16, 2-vs-15 — so the box says
//  "bye" and the side opposite is drawn as having won, because they have.
//

import SwiftUI

struct TournamentBracketColumn: View {

    let column: TournamentPlan.BracketColumn
    /// Grown with Dynamic Type by the card that owns the strip, so every column in it agrees.
    let width: CGFloat
    /// Only called for a box with somebody real on both sides.
    let onScore: (TournamentPlan.BracketBox) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(column.name)
                .typeStyle(TournamentType.bracketRound, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.hairGap)
                .padding(.bottom, TournamentMetrics.bracketHeadingGap)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: TournamentMetrics.bracketBoxGap) {
                ForEach(column.boxes) { box in
                    boxView(box)
                }
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func boxView(_ box: TournamentPlan.BracketBox) -> some View {
        Card(radius: TournamentMetrics.bracketBoxRadius, isDivided: false) {
            VStack(spacing: 0) {
                side(box.a)
                Hairline(color: Theme.hairlineSoft)
                side(box.b)
            }
        }
        // The design draws a 60pt box. Two 12.5pt lines and a rule come to about 46, so the target
        // grows to the minimum around it exactly as every other tappable thing in this app does.
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
        .onTapGesture { if box.isPlayable { onScore(box) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: box))
        .accessibilityAddTraits(box.isPlayable ? [.isButton] : [])
        .accessibilityHint(box.isPlayable ? "Enters a score" : "")
    }

    private func side(_ side: TournamentPlan.BracketSide) -> some View {
        HStack(spacing: TournamentMetrics.bracketSideGap) {
            Text(side.name)
                .typeStyle(
                    side.isWinner ? TournamentType.bracketName.weight(.semibold) : TournamentType.bracketName,
                    // A name that is not standing there yet — "Winner of M7", "bye" — steps back
                    // to `inkTertiary`. The design writes `#A2A6AE` there, which is 2.6:1 on
                    // white; see the header of `TournamentTokens` for why nothing on this tab is
                    // drawn in it.
                    color: side.isWinner ? Theme.accentDark : (side.isResolved ? Theme.ink : Theme.inkTertiary)
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let score = side.score {
                Text(score)
                    .typeStyle(TournamentType.bracketScore, color: Theme.accentDark)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, TournamentMetrics.bracketSidePaddingHorizontal)
        .padding(.vertical, TournamentMetrics.bracketSidePaddingVertical)
    }

    /// "Serene C beat Liam P, 6 to 3" — or what the box is still waiting on.
    ///
    /// Written out rather than combined, because a combined box reads as four fragments with no
    /// verb between them, and "6" then "3" gives a reader no way to tell which name each belongs
    /// to.
    private func label(for box: TournamentPlan.BracketBox) -> String {
        guard let a = box.a.score, let b = box.b.score else {
            return "\(box.a.name) versus \(box.b.name), not played"
        }
        let (winner, loser) = box.a.isWinner ? (box.a, box.b) : (box.b, box.a)
        let (high, low) = box.a.isWinner ? (a, b) : (b, a)
        return "\(winner.name) beat \(loser.name), \(high) to \(low)"
    }
}

// MARK: - Previews

#Preview("Bracket") {
    let camp = SampleData.uclaTennisCamp
    let courts = camp.orderedVenues.first.map { camp.groups(in: $0.id) } ?? []
    var draw = Tournament.seeded(
        .singles(.knockout),
        name: "Tournament 1",
        pool: Tournament.pool(camp.players, across: courts, courtIndices: [0]),
        courtIndices: [0],
        days: 1
    )
    // The first round played, so the preview shows all three states at once: a decided box, a box
    // still naming its feeder, and — on a pool that is not a power of two — a bye.
    for match in draw.playableMatches where match.round == 1 {
        draw.scores[match.id] = Tournament.Score(6, 3)
    }
    let plan = TournamentPlan(draw, in: camp, today: .today)

    return ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: TournamentMetrics.bracketColumnGap) {
            ForEach(plan.bracket) { column in
                TournamentBracketColumn(
                    column: column,
                    width: TournamentMetrics.bracketColumn,
                    onScore: { _ in }
                )
            }
        }
        .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
    .frame(width: 402, height: 460)
}
