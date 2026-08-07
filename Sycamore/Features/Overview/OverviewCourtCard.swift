//
//  OverviewCourtCard.swift
//  Sycamore
//
//  One court: what is happening on it, who has it, whether it is in play, and the kids standing
//  on it.
//
//  The design draws the same card three ways. Quiet: a title, a line of detail, a coach and a
//  caret. Detailed: the same, plus the court's list under a rule. Yours: bordered in the
//  accent with a lift under it, headed "YOUR COURT", the coach reading "You", and its status
//  said outright instead of implied.
//
//  "Detailed" is now every card that has anybody on it, rather than the single one the screen
//  used to pick out — a court whose kids you cannot see is a court you have to leave Overview to
//  learn anything about. The list arrives folded to a few names and `+N more` opens it in place.
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
    /// The kids on the court, already folded to what this card should draw. Empty for a closed
    /// court, and for one with nobody on it today.
    var roster: CourtRoster = .none
    /// The note hanging off the block running here — "Cross-court forehand feeds, then a
    /// volley ladder." Nil is the ordinary case.
    var note: String?
    /// Opens the coach's staff card. Nil leaves the pill inert, for a court nobody has.
    var onOpenCoach: (() -> Void)?
    /// Opens and folds the court's list. Nil on a court small enough to draw whole, which is
    /// what keeps the card from offering a control that would change nothing.
    var onToggleRoster: (() -> Void)?

    /// Kept in step with `CourtRosterRow`'s own scaled column so "+3 more" stays lined up
    /// with the names above it at every type size.
    @ScaledMetric(relativeTo: .callout) private var rankWidth = OverviewTheme.rankWidth
    /// 16 sits in the headline band, the one the 17pt title beside it rides.
    @ScaledMetric(relativeTo: .headline) private var caretSize = OverviewTheme.caretGlyph
    /// 13 sits in the callout band, alongside the marks at the end of a roster line.
    @ScaledMetric(relativeTo: .callout) private var moreCaret = OverviewTheme.rosterGlyph

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

            // Drawn whenever the court can fold at all, rather than whenever something *is*
            // folded away — an open card with no way back is the half of this control the
            // design never had to draw.
            if let onToggleRoster {
                overflowRow(onToggleRoster)
            }
        }
    }

    /// True once every kid on the court is drawn.
    ///
    /// Read off the roster rather than handed in beside it. The screen owns which cards are
    /// open, and a card keeping its own copy of that answer is a second place for the two to
    /// disagree — `GroupCard` derives the same fact the same way.
    private var isRosterExpanded: Bool { roster.overflow == 0 }

    /// `+3 more`, indented into the rank column so it starts where the names do — and
    /// `Show less`, in the same place, once the card is open.
    ///
    /// The design sets this line in `inkFaint`, which was right while it was a label: nothing
    /// on the card was tappable and the last kids simply had no room. It is a control now, and
    /// faint grey on a control reads as disabled — so it takes the accent every other more/less
    /// row in the app wears, `InboxMoreRow` included, and a caret to say which way it goes.
    ///
    /// Deliberately not the header's caret. That one is drawn and not wired, and pointing at
    /// the court's own screen; making it fold the list would answer a question it has never
    /// asked.
    private func overflowRow(_ toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: OverviewTheme.rosterGap) {
                Color.clear
                    .frame(width: rankWidth, height: 0)
                Text(isRosterExpanded ? "Show less" : "+\(roster.overflow) more")
                    .typeStyle(OverviewTheme.rosterName, color: Theme.accent)
                DisclosureChevron(
                    systemName: isRosterExpanded ? "chevron.up" : "chevron.down",
                    size: moreCaret,
                    color: Theme.accent
                )
                .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, OverviewTheme.rosterRowPadding)
            // The design's row is 19pt of type and a finger needs 44. The drawn line stays
            // exactly where it was and the touch grows around it, as every Groups row does.
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // "+3 more" is a fragment. Read out on its own after three children's names it is not
        // obvious what there are three more of, and the count has to inflect.
        .accessibilityLabel(
            isRosterExpanded
                ? Text("Show fewer kids on this court")
                : Text("Show ^[\(roster.overflow) more kid](inflect: true) on this court")
        )
    }

    private var rule: some View {
        Hairline(color: Theme.hairlineSoft)
            .padding(.vertical, OverviewTheme.ruleGap)
    }
}

// MARK: - Previews

/// Hoisted to file scope rather than declared inside the `#Preview` closure that returns it —
/// `GroupCardPreviewHarness` records what the compiler's symbol mangler does with the other
/// arrangement.
private struct OverviewCourtCardPreviewHarness: View {

    @State private var expanded: Set<Group.ID> = []

    private let cards = [
        OverviewFixtures.drills,
        OverviewFixtures.matchPlay,
        OverviewFixtures.netDown,
        OverviewFixtures.unassigned,
    ]

    var body: some View {
        let rosters = TodayCourts.rosters(in: OverviewFixtures.camp, day: OverviewFixtures.day)

        return ScrollView {
            VStack(spacing: OverviewTheme.cardGap) {
                ForEach(cards) { card in
                    let roster = TodayCourts.roster(
                        for: card,
                        from: rosters,
                        preview: OverviewTheme.rosterPreview,
                        isExpanded: expanded.contains(card.id)
                    )

                    OverviewCourtCard(
                        card: card,
                        roster: roster,
                        onOpenCoach: {},
                        onToggleRoster: roster.isFoldable(to: OverviewTheme.rosterPreview)
                            ? {
                                if expanded.contains(card.id) {
                                    expanded.remove(card.id)
                                } else {
                                    expanded.insert(card.id)
                                }
                            }
                            : nil
                    )
                }
            }
            .padding(Spacing.gutter)
        }
        .background(Theme.surfaceWarm)
    }
}

#Preview("Court cards") {
    OverviewCourtCardPreviewHarness()
}

/// The state the fold exists for: one court with every kid on it drawn, `Show less` at the foot.
#Preview("A court, open") {
    OverviewCourtCard(
        card: OverviewFixtures.drills,
        roster: OverviewFixtures.fullRoster(for: OverviewFixtures.drills),
        onOpenCoach: {},
        onToggleRoster: {}
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

#Preview("Your court") {
    OverviewCourtCard(
        card: OverviewFixtures.drills,
        isMine: true,
        roster: OverviewFixtures.roster(
            for: OverviewFixtures.drills, limit: OverviewTheme.rosterPreview
        ),
        note: OverviewFixtures.blockNote,
        onOpenCoach: {},
        onToggleRoster: {}
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
