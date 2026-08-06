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
                // The design's gender glyph, in the app's own vocabulary — `M` / `F` / `X` is
                // what every other screen writes it as, down to the meta line under a name.
                Text(row.player.gender.symbol)
                    .typeStyle(.metaSmall, color: Theme.glyph)

                if row.leavesAt != nil {
                    Image(systemName: "clock.fill")
                        .font(.system(size: glyphSize, weight: .regular))
                        .foregroundStyle(Theme.warning)
                }
            }
        }
        .padding(.vertical, OverviewTheme.rosterRowPadding)
        // One element, said in words. Combining the children reads the row out as "1, Serene
        // Chu, F" and then a clock with no meaning attached; the marks are only shorthand for
        // a reader who can see them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenRow)
    }

    /// "1. Serene Chu. Female. Leaves at 12:30."
    private var spokenRow: String {
        var parts = ["\(row.rank). \(row.player.displayName)", spokenGender]
        if let leavesAt = row.leavesAt {
            parts.append("Leaves at \(leavesAt.formatted)")
        }
        return parts.joined(separator: ". ")
    }

    private var spokenGender: String {
        switch row.player.gender {
        case .m: "Male"
        case .f: "Female"
        case .x: "Unspecified"
        }
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
