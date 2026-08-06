//
//  OverviewCourtCard.swift
//  Sycamore
//
//  One court: what is happening on it, who has it, whether it is in play, and — for the one
//  court that is being looked at — the kids standing on it.
//
//  The design draws the same card three ways. Quiet: a title, a line of detail, a coach and a
//  caret. Detailed: the same, plus the court's list under a rule. Yours: bordered in the
//  accent with a lift under it, headed "YOUR COURT", the coach reading "You", and its status
//  said outright instead of implied.
//
//  Everything below the header is optional and the card collapses to the quiet version when it
//  is all absent — which is what makes "your court first, the rest quiet" one card rather than
//  two.
//

import SwiftUI

struct OverviewCourtCard: View {

    let card: CourtCard
    /// The court the person reading this is standing on.
    var isMine: Bool = false
    /// The kids on the court. Empty on every card but the one being looked at.
    var roster: CourtRoster = .none
    /// The note hanging off the block running here — "Cross-court forehand feeds, then a
    /// volley ladder." Nil is the ordinary case.
    var note: String?
    /// Opens the coach's staff card. Nil leaves the pill inert, for a court nobody has.
    var onOpenCoach: (() -> Void)?

    /// Kept in step with `CourtRosterRow`'s own scaled column so "+3 more" stays lined up
    /// with the names above it at every type size.
    @ScaledMetric(relativeTo: .callout) private var rankWidth = OverviewTheme.rankWidth
    /// 16 sits in the headline band, the one the 17pt title beside it rides.
    @ScaledMetric(relativeTo: .headline) private var caretSize = OverviewTheme.caretGlyph

    var body: some View {
        Card(
            radius: OverviewTheme.cardRadius,
            borderColor: isMine ? Theme.accentBorder : Theme.hairline,
            borderWidth: isMine ? BorderWidth.input : BorderWidth.hairline,
            isDivided: false
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if isMine {
                    Text("Your court")
                        .typeStyle(OverviewTheme.overline, color: Theme.accent)
                        .padding(.bottom, OverviewTheme.overlineGap)
                }

                header

                if let note {
                    rule
                    Text(note)
                        .typeStyle(OverviewTheme.cardNote, color: Theme.inkWarm)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !roster.isEmpty {
                    rule
                    rosterList
                }
            }
            .padding(OverviewTheme.cardPadding)
        }
        // Cast as `.clear` rather than branched on, so the card keeps one view identity and
        // does not rebuild its whole subtree when it becomes yours.
        .shadow(
            color: isMine ? OverviewTheme.yourCourtLift.color : .clear,
            radius: OverviewTheme.yourCourtLift.radius,
            y: OverviewTheme.yourCourtLift.y
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: OverviewTheme.headerGap) {
            // Neither line is clipped: the design's cells wrap rather than ellipse, and an
            // activity name is what tells the courts apart.
            VStack(alignment: .leading, spacing: OverviewTheme.titleGap) {
                Text(card.overviewTitle)
                    .typeStyle(OverviewTheme.cardTitle, color: card.isClosed ? Theme.warningDark : Theme.ink)
                Text(card.overviewSubtitle)
                    .typeStyle(OverviewTheme.cardSubtitle, color: card.isClosed ? Theme.warning : Theme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Read as one phrase — "Drills. Court 1 – 8 players." — rather than as two
            // elements a reader has to swipe between to learn which court they landed on.
            .accessibilityElement(children: .combine)

            // A closed court shows no coach. The line above already names whoever is on it,
            // and a court out of play is not being run by anybody.
            if !card.isClosed {
                CoachPill(name: isMine ? "You" : card.coachName, action: onOpenCoach)
            }

            if card.isClosed || isMine {
                CourtStatusBadge(status: card.status, isProminent: isMine)
            }

            // Drawn, not wired. The caret's destination is the court's own screen, which
            // section 8 has not drawn yet; a control that goes nowhere is worse than a glyph
            // that never claimed to, and it lies to VoiceOver besides. Your own court has no
            // caret in the design — you are already standing on it.
            if !isMine {
                DisclosureChevron(size: caretSize)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Roster

    private var rosterList: some View {
        VStack(spacing: OverviewTheme.rosterRowGap) {
            ForEach(roster.rows) { row in
                CourtRosterRow(row: row)
            }

            if roster.overflow > 0 {
                overflowRow
            }
        }
    }

    /// `+3 more`, indented into the rank column so it starts where the names do.
    private var overflowRow: some View {
        HStack(spacing: OverviewTheme.rosterGap) {
            Color.clear
                .frame(width: rankWidth, height: 0)
            Text("+\(roster.overflow) more")
                .typeStyle(OverviewTheme.rosterName, color: Theme.inkFaint)
            Spacer(minLength: 0)
        }
        .padding(.vertical, OverviewTheme.rosterRowPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(roster.overflow) more on this court")
    }

    private var rule: some View {
        Hairline(color: Theme.hairlineSoft)
            .padding(.vertical, OverviewTheme.ruleGap)
    }
}

// MARK: - Previews

#Preview("Court cards") {
    ScrollView {
        VStack(spacing: OverviewTheme.cardGap) {
            OverviewCourtCard(
                card: OverviewFixtures.drills,
                roster: OverviewFixtures.roster(for: OverviewFixtures.drills, limit: 5),
                onOpenCoach: {}
            )
            OverviewCourtCard(card: OverviewFixtures.matchPlay, onOpenCoach: {})
            OverviewCourtCard(card: OverviewFixtures.netDown)
            OverviewCourtCard(card: OverviewFixtures.unassigned)
        }
        .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
}

#Preview("Your court") {
    OverviewCourtCard(
        card: OverviewFixtures.drills,
        isMine: true,
        roster: OverviewFixtures.roster(for: OverviewFixtures.drills, limit: 3),
        note: OverviewFixtures.blockNote,
        onOpenCoach: {}
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
