//
//  TournamentTeamRow.swift
//  Sycamore
//
//  One team-tennis roster: its name, how many kids are in it, who is on it, and a chip per coach.
//
//  ── WHY THE COACH CHIPS ARE HERE AND NOT IN A SHEET ───────────────────────────────────────────
//
//  Because assigning coaches to teams is the *whole* of what there is to do with a team draw. The
//  fixtures come later — `Tournament.seeded` seeds rosters and stops, exactly as the design does —
//  so the card is not a summary you tap into, it is the screen. Putting the one live control
//  behind a disclosure would be hiding the only thing on it.
//
//  ── WHY IDS RATHER THAN NAMES ─────────────────────────────────────────────────────────────────
//
//  `state1.js:783` stores `tm.coaches` as a list of names picked out of `camp.staff`. That works in
//  a prototype where staff *are* strings and fails here in two ways the model's own header spells
//  out: a coach who corrects the spelling of their name silently leaves every team they were
//  running, and two coaches called Sam become one. So `Tournament.Team.coachIDs` holds ids, this
//  row draws the name it resolves them to, and `setTeamCoaches(_:forTeam:in:)` writes ids back.
//

import SwiftUI

struct TournamentTeamRow: View {

    let team: TournamentPlan.TeamRoster
    /// The camp's staff. Empty draws no chip row at all — see the card.
    let coaches: [StaffMember]
    let onToggleCoach: (StaffMember.ID) -> Void

    private var assigned: Set<StaffMember.ID> { Set(team.coachIDs) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: TournamentMetrics.sectionLabelGap) {
                Text(team.name)
                    .typeStyle(TournamentType.sectionLabel, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                Text(team.count)
                    .typeStyle(TournamentType.sectionMeta, color: Theme.inkTertiary)
                    .monospacedDigit()
            }

            if !coaches.isEmpty {
                FlowLayout(
                    horizontalSpacing: TournamentMetrics.coachChipGap,
                    verticalSpacing: TournamentMetrics.coachChipGap
                ) {
                    ForEach(coaches) { coach in
                        let isOn = assigned.contains(coach.id)

                        Chip(
                            coach.name,
                            isSelected: isOn,
                            // Green rather than the black `.dark` the venue chips take. A coach on
                            // a team is a *state of the roster*, not a filter over a list, and the
                            // design draws it in the accent for exactly that reason
                            // (`state1.js:783`, `bg: on ? '#1A7F55' : '#fff'`).
                            selectedTone: .accent,
                            metrics: .tournamentPick
                        ) {
                            onToggleCoach(coach.id)
                        }
                        .accessibilityLabel("\(coach.name), \(team.name)")
                        .accessibilityAddTraits(isOn ? [.isSelected] : [])
                        .accessibilityHint(isOn ? "Takes them off this team" : "Puts them on this team")
                    }
                }
                .padding(.top, TournamentMetrics.coachChipRowGap)
            }

            Text(team.roster)
                // `inkWarm` — the design's `#3F4A44`, and this is the body-and-detail role that
                // token is documented for: a run of names at 13pt, not a title.
                .typeStyle(TournamentType.teamRoster, color: Theme.inkWarm)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, TournamentMetrics.teamRosterGap)
        }
        .padding(.vertical, TournamentMetrics.teamPaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#Preview("Team rosters") {
    let camp = SampleData.uclaTennisCamp
    let courts = camp.orderedVenues.first.map { camp.groups(in: $0.id) } ?? []
    var draw = Tournament.seeded(
        .team(count: 3),
        name: "Tournament 1",
        pool: Tournament.pool(camp.players, across: courts, courtIndices: [0]),
        courtIndices: [0],
        days: 1
    )
    if let first = camp.staff.first { draw.teams[0].coachIDs = [first.id] }
    let plan = TournamentPlan(draw, in: camp, today: .today)

    return ScrollView {
        Card(radius: TournamentMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                ForEach(Array(plan.teams.enumerated()), id: \.element.id) { offset, team in
                    if offset > 0 { Hairline(color: Theme.hairlineSoft) }
                    TournamentTeamRow(team: team, coaches: camp.staff, onToggleCoach: { _ in })
                }
            }
            .padding(TournamentMetrics.cardPadding)
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, TournamentMetrics.listTop)
    }
    .background(Theme.surfaceWarm)
    .frame(width: 402, height: 620)
}

#Preview("Team rosters — accessibility1") {
    let camp = SampleData.uclaTennisCamp
    let courts = camp.orderedVenues.first.map { camp.groups(in: $0.id) } ?? []
    let draw = Tournament.seeded(
        .team(count: 2),
        name: "Tournament 1",
        pool: Tournament.pool(camp.players, across: courts, courtIndices: [0]),
        courtIndices: [0],
        days: 1
    )
    let plan = TournamentPlan(draw, in: camp, today: .today)

    return ScrollView {
        Card(radius: TournamentMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                ForEach(plan.teams) { team in
                    TournamentTeamRow(team: team, coaches: camp.staff, onToggleCoach: { _ in })
                }
            }
            .padding(TournamentMetrics.cardPadding)
        }
        .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
    .frame(width: 402, height: 760)
    .environment(\.dynamicTypeSize, .accessibility1)
}
