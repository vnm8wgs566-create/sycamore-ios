//
//  TournamentCard.swift
//  Sycamore
//
//  One draw, drawn. `tCard`'s output (`design/app/state1.js:761-892`) as a view over the plan
//  `TournamentPlan` works out from it.
//
//  Four shapes come out of one card, and which one is not a mode the reader picks — it is what the
//  draw is:
//
//  * **Team tennis** is rosters and coach chips and nothing else, because the design seeds teams
//    and stops. The card says so out loud rather than drawing an empty order of play.
//  * **A knockout** gets the bracket columns above its order of play, so the shape of the draw and
//    the list of what to play next are both on the card.
//  * **A round robin** gets the standings table below it instead.
//  * **Doubles**, whatever its shape, gets a line naming any kid the pairing left over. See
//    `TournamentPlan.soloNames` — that line is the whole reason this screen does not repeat the
//    design's one real defect.
//
//  Everything below is drawing. Every decision about *what* to draw was taken in `TournamentPlan`,
//  which is a value and can be read without running the app.
//

import SwiftUI

struct TournamentCard: View {

    let plan: TournamentPlan
    /// The camp's coaches, for the chips on a team. Empty hides the chip rows entirely — the
    /// design guards its own on `staff.length > 0` (`state1.js:783`), and a heading over no chips
    /// is a control that has gone missing rather than one that was never there.
    let coaches: [StaffMember]

    /// Which day of the draw the order of play is showing. The card does not own it: two cards on
    /// one screen keep separate days, and the screen holds both.
    let selectedDay: Int
    let onSelectDay: (Int) -> Void

    /// Whether the order of play is unfolded past its first ten, and whether the table is unfolded
    /// past its first three. Two separate folds, as the design has them — a long day's play and a
    /// long table are different things to want more of.
    let isOrderExpanded: Bool
    let isTableExpanded: Bool
    let onToggleOrder: () -> Void
    let onToggleTable: () -> Void

    /// Opening the score sheet on a fixture. Only ever called for a match with somebody real on
    /// both sides — see `TournamentPlan.OrderedMatch.isReady`.
    let onScore: (TournamentPlan.OrderedMatch) -> Void
    /// Toggling one coach on one team.
    let onToggleCoach: (TournamentPlan.TeamRoster, StaffMember.ID) -> Void
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The bracket's column width, grown with the type inside it.
    ///
    /// The design's 150 holds two 12.5pt names and a rule. At `.accessibility1` those names are
    /// half again as tall and, more to the point, half again as *long* before they ellipsise — so a
    /// fixed column would clip every name in the draw at exactly the setting where clipping costs
    /// most. `@ScaledMetric` is what `ScheduleView` does with its time gutter for the same reason.
    @ScaledMetric(relativeTo: .subheadline) private var bracketColumn = TournamentMetrics.bracketColumn

    private var dayMatches: [TournamentPlan.OrderedMatch] { plan.matches(onDay: selectedDay) }

    private var visibleMatches: [TournamentPlan.OrderedMatch] {
        Array(dayMatches.prefix(TournamentRules.visibleCount(
            of: dayMatches.count,
            preview: TournamentRules.orderPreviewRows,
            isExpanded: isOrderExpanded
        )))
    }

    private var visibleStandings: [TournamentPlan.StandingRow] {
        Array(plan.standings.prefix(TournamentRules.visibleCount(
            of: plan.standings.count,
            preview: TournamentRules.standingsPreviewRows,
            isExpanded: isTableExpanded
        )))
    }

    var body: some View {
        Card(radius: TournamentMetrics.cardRadius, isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                tags

                if !plan.soloNames.isEmpty {
                    soloNotice
                }

                if plan.isTeam {
                    teamSection
                } else {
                    if plan.isKnockout {
                        bracket
                    }
                    orderOfPlay
                    if plan.isRoundRobin {
                        standings
                    }
                }
            }
            .padding(TournamentMetrics.cardPadding)
        }
        .animation(Motion.fold(reduceMotion: reduceMotion), value: isOrderExpanded)
        .animation(Motion.fold(reduceMotion: reduceMotion), value: isTableExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(plan.title), \(plan.tags.joined(separator: ", "))")
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: TournamentMetrics.sectionLabelGap) {
            Text(plan.title)
                .typeStyle(TournamentType.cardTitle, color: Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            // The design confirms a removal by turning the word into "Tap again" for 2.6 seconds
            // (`state1.js:769-773`). That is not a confirmation anybody can use: it is invisible to
            // VoiceOver, it expires while a reader is still deciding, and a reader with a tremor
            // gets the second tap for free. The system's own destructive dialog says what will be
            // deleted, waits as long as it is looked at, and cancels by default — the same call
            // `GroupsMove` made when it dropped its own timed latch.
            Button(role: .destructive, action: onRemove) {
                Text("Remove")
                    .typeStyle(.chipMedium, color: Theme.danger)
                    .padding(.horizontal, Spacing.small)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
                    .padding(.horizontal, -Spacing.small)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(plan.title)")
        }
    }

    /// "Singles · Round robin · 2 days · Groups 1+2", as a wrapping row of grey pills.
    private var tags: some View {
        FlowLayout(
            horizontalSpacing: TournamentMetrics.tagGap,
            verticalSpacing: TournamentMetrics.tagGap
        ) {
            ForEach(plan.tags, id: \.self) { tag in
                TournamentTag(tag)
            }
        }
        .padding(.top, TournamentMetrics.tagRowGap)
        // One phrase, spoken once. Four separate pills made VoiceOver read four fragments between
        // the draw's name and the first thing anybody can do on the card.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plan.tags.joined(separator: ", "))
    }

    // MARK: The kid with nobody to play with

    /// The line the design never draws, and the reason this screen exists rather than transcribing.
    ///
    /// `state1.js:915` pairs the unrequested kids two at a time with `i + 1 < rest.length`, which
    /// walks straight past the last kid of an odd list — no entrant, no match, no mention. The
    /// model keeps them (`Tournament.unpairedEntrants`) and this says their name.
    ///
    /// Amber and not red, and drawn as the design's warning pill: nothing is broken and nothing is
    /// being deleted, but somebody has to decide whether this kid sits out, plays with a coach or
    /// makes a three — and they cannot decide it if they are never told. `Theme.warningTint` /
    /// `warningDark` is the pair `Theme.swift:204-233` measures at 4.93:1, which is what lets this
    /// be read at the 12pt the card sets it in. It is a fifth screen using that pair; the token's
    /// own note says to reach for it only where the design draws it, and the argument for
    /// stretching that here is that the design draws nothing at all in this place.
    private var soloNotice: some View {
        let names = plan.soloNames.joined(separator: ", ")
        let message = plan.soloNames.count == 1
            ? "\(names) has no partner — pair them with a coach or sit them out."
            : "\(names) have no partner — pair them with a coach or sit them out."

        return HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: TournamentMetrics.matchCaret + 2, weight: .regular))
                .foregroundStyle(Theme.warningDark)
                .accessibilityHidden(true)

            Text(message)
                .typeStyle(.metaSmall, color: Theme.warningDark)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TournamentMetrics.tagPaddingHorizontal)
        .padding(.vertical, Spacing.small)
        .background(Theme.warningTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .padding(.top, TournamentMetrics.sectionGap)
        .accessibilityElement(children: .combine)
    }

    // MARK: Teams

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline(color: Theme.hairlineSoft)
                .padding(.top, TournamentMetrics.sectionGap)

            ForEach(Array(plan.teams.enumerated()), id: \.element.id) { offset, team in
                if offset > 0 {
                    Hairline(color: Theme.hairlineSoft)
                }
                TournamentTeamRow(
                    team: team,
                    coaches: coaches,
                    onToggleCoach: { onToggleCoach(team, $0) }
                )
            }

            Text(TournamentPlan.teamNote)
                .typeStyle(TournamentType.sectionMeta, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.tight)
        }
    }

    // MARK: The bracket

    private var bracket: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: TournamentMetrics.bracketColumnGap) {
                    ForEach(plan.bracket) { column in
                        TournamentBracketColumn(
                            column: column,
                            width: bracketColumn,
                            onScore: { box in
                                guard let match = plan.order.first(where: { $0.id == box.id }) else { return }
                                onScore(match)
                            }
                        )
                    }
                }
                // The columns bleed to the card's own edges rather than stopping at its gutter, so
                // a bracket wider than the card slides out under the corner instead of ending in a
                // 14pt margin of white. `GroupsHeader.venueChips` does the same with the gutter on
                // the content rather than on the scroller.
                .padding(.horizontal, TournamentMetrics.cardPadding)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -TournamentMetrics.cardPadding)
            .padding(.top, TournamentMetrics.sectionGap)
        }
    }

    // MARK: The order of play

    private var orderOfPlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionRule

            HStack(alignment: .firstTextBaseline, spacing: TournamentMetrics.sectionLabelGap) {
                Text("Order of play")
                    .typeStyle(TournamentType.sectionLabel, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                Text(plan.playedLine)
                    .typeStyle(TournamentType.sectionMeta, color: Theme.inkTertiary)
                    .monospacedDigit()
            }

            if plan.days.count > 1 {
                dayPills
            }

            if dayMatches.isEmpty {
                // A day with nothing on it is a real answer — an away-day move can empty one — and
                // it needs a sentence rather than a gap between two headings.
                Text("Nothing to play on this day.")
                    .typeStyle(TournamentType.sectionMeta, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, TournamentMetrics.sectionGap)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleMatches) { match in
                        matchRow(match)
                    }

                    if TournamentRules.showsMoreRow(
                        of: dayMatches.count,
                        preview: TournamentRules.orderPreviewRows,
                        isExpanded: isOrderExpanded
                    ) {
                        MoreRow(
                            hiddenCount: dayMatches.count - visibleMatches.count,
                            isExpanded: isOrderExpanded,
                            noun: "match",
                            nounPlural: "matches",
                            qualifier: "on this day",
                            metrics: .inline(indent: TournamentMetrics.numberColumn),
                            action: onToggleOrder
                        )
                    }
                }
                .padding(.top, Spacing.tight)
            }
        }
    }

    private var dayPills: some View {
        HStack(spacing: TournamentMetrics.dayPillGap) {
            ForEach(plan.days) { day in
                let isSelected = day.index == selectedDay

                Chip(day.label, isSelected: isSelected, selectedTone: .dark, metrics: .tournamentDay) {
                    onSelectDay(day.index)
                }
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.top, TournamentMetrics.dayPillRowGap)
    }

    /// One fixture. A row, a rule above it, and — for the next one to be played — a ring around it.
    private func matchRow(_ match: TournamentPlan.OrderedMatch) -> some View {
        let isUpNext = plan.upNext(onDay: selectedDay)?.id == match.id
        let shape = RoundedRectangle(cornerRadius: TournamentMetrics.upNextRadius, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: TournamentMetrics.matchGap) {
                Text(match.number)
                    .typeStyle(TournamentType.matchNumber, color: Theme.inkTertiary)
                    .monospacedDigit()
                    .frame(width: TournamentMetrics.numberColumn, alignment: .trailing)

                Text(match.label)
                    .typeStyle(
                        TournamentType.matchLabel,
                        // A played match steps back: the score is the news on that row, not the
                        // names. `inkTertiary` rather than the design's `#71757E` — which is the
                        // same value; this one is simply the token for it.
                        color: match.score == nil ? Theme.ink : Theme.inkTertiary
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let scoreLabel = match.scoreLabel {
                    Text(scoreLabel)
                        .typeStyle(TournamentType.matchScore, color: Theme.accentDark)
                        .monospacedDigit()
                } else if match.isReady {
                    Text("Score")
                        .typeStyle(TournamentType.matchAction, color: Theme.accent)
                }

                DisclosureChevron(size: TournamentMetrics.matchCaret)
                    .accessibilityHidden(true)
                    .opacity(match.isReady ? 1 : 0)
            }

            if let flag = match.flag {
                Text(flag)
                    // `warningDark` and not the design's `#B67A16` (`Theme.warning`), which is
                    // 3.7:1 on white with nothing behind it. See the header of `TournamentTokens`.
                    .typeStyle(TournamentType.matchFlag, color: Theme.warningDark)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, TournamentMetrics.flagGap)
                    .padding(.leading, TournamentMetrics.numberColumn + TournamentMetrics.matchGap)
            }
        }
        .padding(.vertical, TournamentMetrics.matchPaddingVertical)
        .padding(.horizontal, isUpNext ? TournamentMetrics.matchPaddingHorizontal : 0)
        .background {
            if isUpNext {
                shape.fill(Theme.accentSurface)
                    .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.input) }
            }
        }
        .padding(.horizontal, isUpNext ? -TournamentMetrics.upNextInset : 0)
        .padding(.vertical, isUpNext ? TournamentMetrics.upNextGap : 0)
        .overlay(alignment: .top) {
            // Between rows, never above the first, and never over the up-next ring — which is what
            // `DividedStack` does for a card and cannot do here, because the ring bleeds past the
            // gutter the rules are drawn inside.
            if !isUpNext, visibleMatches.first?.id != match.id {
                Hairline(color: Theme.hairlineSoft)
            }
        }
        // The whole row is the target, the same 44pt every other list row in this app grows to.
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
        .onTapGesture { if match.isReady { onScore(match) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: match))
        .accessibilityAddTraits(match.isReady ? [.isButton] : [])
        .accessibilityHint(match.isReady ? (match.score == nil ? "Enters a score" : "Changes the score") : "")
    }

    /// Everything about a fixture, in the order somebody would want to hear it.
    ///
    /// Assembled rather than left to `children: .combine`, which would read the match number as a
    /// bare "M7" and then say "Score" — a word that is a control on one row and absent on the next,
    /// with nothing to say which.
    private func accessibilityLabel(for match: TournamentPlan.OrderedMatch) -> String {
        var parts = ["Match \(match.number.dropFirst())", match.label]
        if let score = match.score {
            parts.append("\(score.a) to \(score.b)")
        } else if !match.isReady {
            parts.append("Waiting on an earlier match")
        } else {
            parts.append("Not played")
        }
        if let flag = match.flag { parts.append(flag) }
        return parts.joined(separator: ", ")
    }

    // MARK: The table

    private var standings: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionRule

            HStack(alignment: .firstTextBaseline, spacing: TournamentMetrics.sectionLabelGap) {
                Text(plan.standingsTitle)
                    .typeStyle(TournamentType.sectionLabel, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                ForEach(visibleStandings) { row in
                    standingRow(row)
                }

                if TournamentRules.showsMoreRow(
                    of: plan.standings.count,
                    preview: TournamentRules.standingsPreviewRows,
                    isExpanded: isTableExpanded
                ) {
                    MoreRow(
                        hiddenCount: plan.standings.count - visibleStandings.count,
                        isExpanded: isTableExpanded,
                        noun: "place",
                        nounPlural: "places",
                        qualifier: "in this table",
                        metrics: .inline(indent: TournamentMetrics.numberColumn),
                        action: onToggleTable
                    )
                }
            }
            .padding(.top, Spacing.tight)
        }
    }

    private func standingRow(_ row: TournamentPlan.StandingRow) -> some View {
        HStack(spacing: TournamentMetrics.matchGap) {
            Text("\(row.position)")
                .typeStyle(TournamentType.matchNumber, color: Theme.inkTertiary)
                .monospacedDigit()
                .frame(width: TournamentMetrics.numberColumn, alignment: .trailing)

            Text(row.label)
                .typeStyle(
                    row.isChampion
                        ? TournamentType.matchLabel.weight(.semibold)
                        : TournamentType.matchLabel,
                    color: Theme.ink
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if row.isChampion {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: TournamentMetrics.matchCaret + 3, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }

            Text(row.record)
                .typeStyle(.chipMedium, color: Theme.inkWarm)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.hairGap)
        .frame(minHeight: HitTarget.minimum)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(row.position). \(row.label), won \(row.record.split(separator: "–").first ?? "0"), "
            + "lost \(row.record.split(separator: "–").last ?? "0")"
            + (row.isChampion ? ", winner" : "")
        )
    }

    /// `margin-top:11px;padding-top:11px;border-top:1px solid #F2F3F6` — the rule over every
    /// section inside a card.
    private var sectionRule: some View {
        Hairline(color: Theme.hairlineSoft)
            .padding(.top, TournamentMetrics.sectionGap)
            .padding(.bottom, TournamentMetrics.sectionGap)
    }
}

// MARK: - A tag

/// One of the grey pills under a card's title.
///
/// Deliberately not `Chip` in its `.outline` tone, which is a white plate with a border — this is a
/// filled `Theme.fill` plate with no border, and it is not selectable. Deliberately not `Badge`
/// either, which is 9.5pt tracked uppercase: the house rule for new screens is sentence case and no
/// tracked caps, and the design writes these in sentence case at 11.5.
private struct TournamentTag: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .typeStyle(TournamentType.tag, color: Theme.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, TournamentMetrics.tagPaddingHorizontal)
            .padding(.vertical, TournamentMetrics.tagPaddingVertical)
            .background(Theme.fill, in: Capsule(style: .continuous))
    }
}

// MARK: - Previews

/// Hoisted to file scope on purpose. A `View` type declared *inside* a `#Preview` closure that also
/// returns it makes the compiler's symbol mangler recurse without bound.
private struct TournamentCardPreviewHarness: View {

    let seeding: Tournament.Seeding
    var scoreEvery: Bool = false

    @State private var day = 1
    @State private var order = false
    @State private var table = false

    var body: some View {
        let camp = SampleData.uclaTennisCamp
        let plan = TournamentPlan(tournament(in: camp), in: camp, today: .today)

        return ScrollView {
            TournamentCard(
                plan: plan,
                coaches: camp.staff,
                selectedDay: day,
                onSelectDay: { day = $0 },
                isOrderExpanded: order,
                isTableExpanded: table,
                onToggleOrder: { order.toggle() },
                onToggleTable: { table.toggle() },
                onScore: { _ in },
                onToggleCoach: { _, _ in },
                onRemove: {}
            )
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, TournamentMetrics.listTop)
        }
        .background(Theme.surfaceWarm)
    }

    /// A draw over the sample camp's first court, optionally with every fixture scored — which is
    /// the only way to see "Final standings" and the winner's tick.
    private func tournament(in camp: Camp) -> Tournament {
        guard let venue = camp.orderedVenues.first else {
            return Tournament(name: "Tournament 1", kind: .singles, mode: .roundRobin, courtIndices: [], days: 1)
        }
        let courts = camp.groups(in: venue.id)
        var draw = Tournament.seeded(
            seeding,
            name: "Tournament 1",
            pool: Tournament.pool(camp.players, across: courts, courtIndices: [0]),
            courtIndices: [0],
            days: 2
        )
        if scoreEvery {
            for match in draw.playableMatches {
                draw.scores[match.id] = Tournament.Score(6, match.round.isMultiple(of: 2) ? 4 : 3)
            }
        }
        return draw
    }
}

#Preview("Card — round robin") {
    TournamentCardPreviewHarness(seeding: .singles(.roundRobin))
        .frame(width: 402, height: 860)
}

#Preview("Card — knockout draw") {
    TournamentCardPreviewHarness(seeding: .singles(.knockout))
        .frame(width: 402, height: 860)
}

#Preview("Card — doubles, and the kid with no partner") {
    TournamentCardPreviewHarness(seeding: .doubles(.roundRobin))
        .frame(width: 402, height: 860)
}

#Preview("Card — team tennis") {
    TournamentCardPreviewHarness(seeding: .team(count: 3))
        .frame(width: 402, height: 700)
}

#Preview("Card — everything played") {
    TournamentCardPreviewHarness(seeding: .singles(.roundRobin), scoreEvery: true)
        .frame(width: 402, height: 860)
}

#Preview("Card — accessibility1") {
    TournamentCardPreviewHarness(seeding: .singles(.knockout))
        .frame(width: 402, height: 1000)
        .environment(\.dynamicTypeSize, .accessibility1)
}
