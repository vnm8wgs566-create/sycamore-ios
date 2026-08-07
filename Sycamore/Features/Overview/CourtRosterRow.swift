//
//  CourtRosterRow.swift
//  Sycamore
//
//  One kid in a court card's list: their place on the court, their name, and the two marks the
//  design puts at the end of the line — which they are, and whether they go home early.
//
//  Lighter than the same kid on Groups. That row is a control you swipe, tap and drag; this one
//  is a line of a list you read, so it is set at the design's 13.5/400 rather than at Groups'
//  bold 15, and it takes no gestures at all.
//

import SwiftUI

struct CourtRosterRow: View {

    let row: PlayerRow

    /// The rank column grows with the reader's type size, or a two-digit place lands in a
    /// 17pt box and truncates. `.callout` is the ramp the 13pt numeral rides, so the column and
    /// the numeral in it grow at exactly the same rate.
    @ScaledMetric(relativeTo: .callout) private var rankWidth = OverviewTheme.rankWidth
    /// 13 sits in the callout band, the same one the name beside it rides.
    @ScaledMetric(relativeTo: .callout) private var glyphSize = OverviewTheme.rosterGlyph

    var body: some View {
        HStack(spacing: OverviewTheme.rosterGap) {
            Text("\(row.rank)")
                .typeStyle(OverviewTheme.rosterRank, color: Theme.chevron)
                .frame(width: rankWidth, alignment: .trailing)

            // Deliberately unclipped. The design's own CSS wraps this cell rather than
            // ellipsing it, and at the reader's larger sizes a truncated child's name is the
            // one thing on the row that cannot be guessed from context.
            Text(row.player.displayName)
                .typeStyle(OverviewTheme.rosterName, color: Theme.inkWarm)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.tight) {
                // The design's gender glyph, drawn — see `GenderMark`, which sizes and scales
                // itself, so nothing here has to match it to the clock beside it by hand.
                GenderMark(row.player.gender)

                if row.leavesAt != nil {
                    Image(systemName: "clock.fill")
                        .font(.system(size: glyphSize, weight: .regular))
                        .foregroundStyle(Theme.warning)
                }
            }
        }
        .padding(.vertical, OverviewTheme.rosterRowPadding)
        // One element, said in words. `GenderMark` carries its own label and the clock carries
        // none, so combining reads this row out as "1, Serene Chu, Girl" and then stops short of
        // the one fact a coach came to the row for. `spokenRow` says all of it, in order.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenRow)
    }

    /// "1. Serene Chu. Girl. Leaves at 12:30."
    ///
    /// `Gender.label`, not the `Female` / `Male` / `Unspecified` this row used to say on its own.
    /// Three screens each had a private spelling of the same three cases and the third one
    /// disagreed with itself everywhere — "Unspecified" here, "Gender not recorded" on Groups,
    /// and a chip on `8e` that had just accepted the answer as a choice.
    private var spokenRow: String {
        var parts = ["\(row.rank). \(row.player.displayName)", row.player.gender.label]
        if let leavesAt = row.leavesAt {
            parts.append("Leaves at \(leavesAt.formatted)")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("Roster rows") {
    let camp = SampleData.uclaTennisCamp
    let roster = TodayCourts.roster(forCourt: SampleData.nassCourt.id, in: camp, day: .wed, limit: 5)

    return VStack(spacing: OverviewTheme.rosterRowGap) {
        ForEach(roster.rows) { row in
            CourtRosterRow(row: row)
        }
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
