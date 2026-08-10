//
//  CourtRosterRow.swift
//  Sycamore
//
//  One kid in a court card's list: their place on the court, their name, and the two marks the
//  design puts at the end of the line — which they are, and whether they go home early.
//
//  Lighter than the same kid on Groups. That row is a control you swipe, tap and drag; this one
//  is a line of a list you read, so it is set at the design's 13.5/400 rather than at Groups'
//  bold 15, and it takes no gestures of its own. `CourtRosterButton` wraps it where a screen
//  wants the tap — the court screen and Overview's cards both do now — and the row stays a line
//  either way, so every screen that lists a kid draws them identically whether or not it opens
//  them. The gesture belongs to the screen; the line belongs here.
//
//  It draws `PlayerRow.isAway` now, which it used to carry and ignore. Overview never produces
//  an away row — `TodayCourts.rosters` drops those kids before a card ever sees them — so the
//  flag arrived here permanently false and the row was free to assume it. `CourtDetailRoster`
//  keeps them, deliberately, so the assumption had to go: the treatment below is Groups' own
//  (`GroupCard`) rather than a third spelling of "not in today".
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
            // An away kid shows no numeral: the numbers in this column run 1…n over the kids who
            // turned up, and their `courtRank` belongs to the other scheme. The column is still
            // spent — an empty run of the same type keeps its width *and* its line height, so the
            // names stay in one line and the rows stay one height.
            Text(row.isAway ? "" : "\(row.rank)")
                .typeStyle(OverviewTheme.rosterRank, color: Theme.chevron)
                .frame(width: rankWidth, alignment: .trailing)

            // Deliberately unclipped. The design's own CSS wraps this cell rather than
            // ellipsing it, and at the reader's larger sizes a truncated child's name is the
            // one thing on the row that cannot be guessed from context.
            Text(row.name)
                // `inkFaint` for a kid who is not in, which is the grey `GroupCard` fades an away
                // name to. Colour alone is never the whole answer — the mark below says it in a
                // glyph and `spokenRow` says it in a word.
                .typeStyle(OverviewTheme.rosterName, color: row.isAway ? Theme.inkFaint : Theme.inkWarm)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.tight) {
                // The design's gender glyph, drawn — see `GenderMark`, which sizes and scales
                // itself, so nothing here has to match it to the clock beside it by hand.
                GenderMark(row.player.gender)

                if row.isAway {
                    // The same mark Groups puts at the end of an away row, so a kid who is out
                    // looks the same on both screens.
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: glyphSize, weight: .regular))
                        .foregroundStyle(Theme.inkFaint)
                }

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
        // the one fact a coach came to the row for. `spokenLabel` says all of it, in order.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenLabel(for: row))
    }

    /// "1. Serene Chu. Girl. Leaves at 12:30." — and "Liam Jones. Boy. Away." for a kid who is
    /// not in, where the numeral would be a place they are not standing in.
    ///
    /// `Gender.label`, not the `Female` / `Male` / `Unspecified` this row used to say on its own.
    /// Three screens each had a private spelling of the same three cases and the third one
    /// disagreed with itself everywhere — "Unspecified" here, "Gender not recorded" on Groups,
    /// and a chip on `8e` that had just accepted the answer as a choice.
    ///
    /// `static` and reachable rather than private, for the court screen. There the row sits inside
    /// a button, and a button whose label happens to contain an accessibility element is relying
    /// on SwiftUI to lift the child's label onto the control. It usually does; when it does not,
    /// the result is a column of buttons all announced as "Button" and no way to tell one kid from
    /// another. The screen sets the label outright instead, and this is what it sets it to — so
    /// there is still one spelling of a spoken roster line and not a second one that drifts.
    static func spokenLabel(for row: PlayerRow) -> String {
        let name = row.isAway ? row.name : "\(row.rank). \(row.name)"
        var parts = [name, row.player.gender.label]
        if row.isAway {
            parts.append("Away")
        }
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

/// The half Overview never draws: the court screen's list, where the kids who are not in today
/// follow the ones who are. Wednesday is the day `SampleData` marks somebody away on.
#Preview("Roster rows — somebody away") {
    let roster = CourtDetailRoster.build(
        forCourt: SampleData.nassCourt.id, in: SampleData.uclaTennisCamp, day: .wed
    )

    return VStack(spacing: OverviewTheme.rosterRowGap) {
        ForEach(roster.here.rows) { row in
            CourtRosterRow(row: row)
        }
        ForEach(roster.away) { row in
            CourtRosterRow(row: row)
        }
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
