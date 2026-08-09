//
//  OverviewCourtCard.swift
//  Sycamore
//
//  One court: what is happening on it, how full it is, who has it, and the kids standing on it.
//
//  Four rows, and they are `8i`'s exactly:
//
//      COURT 1                          8 of 8   ⌄     an overline, a reading, a caret
//      Drills                                          600 19 / -.035em
//      ● Nass                                          a 26pt disc and a first name
//      ───────────────────────────────────────
//      1  Serene Chu                        ♀
//      …                                               folded to `rosterPreview`, +N more
//
//  ── This card used to be two of those rows in one ────────────────────────────────────────────
//
//  It drew a title with a grey subtitle under it ("Drills" over "Court 1 – 8 players") and wedged
//  the coach into the header beside them as a capsule. That was a reading of frames nobody in the
//  repository could open, and holding it against `8i` and `8j` — which are in the repository now —
//  it is wrong in three ways that matter:
//
//    - the court's own label is an **overline above** the activity, not a phrase below it. The
//      activity is the subject of the card; the court is which card it is.
//    - the head-count has a **denominator**. "8 players" cannot answer "where is there room", which
//      is the question an admin has on a camp morning. See `CourtCapacity`.
//    - the coach is a **line of their own** under the title, not a pill in the header. See
//      `CourtCoachLine`, which also carries the design's own "Add a coach".
//
//  ── The card still lists every court's kids ──────────────────────────────────────────────────
//
//  `8i` draws four cards and puts a roster under exactly one of them, and this screen used to take
//  that literally: it named a single "detailed" court and handed every other card `.none`, so on a
//  twelve-court morning eleven of them said how many kids were there and not one name. Which court
//  a child is on is the question Overview exists to answer. Each card carries its own list, folded
//  to `OverviewTheme.rosterPreview` names with a `+N more` that opens it in place — the design's
//  frame survives as the folded state of a screen that can now also be opened.
//
//  ── And every name on it opens the kid ───────────────────────────────────────────────────────
//
//  Overview was the last list of kids in the app you could not tap. The court screen opens `8q`
//  from a row (`CourtScreen.swift:286-301`), both of Groups' lists do, Rank does; this card drew
//  the same names and did nothing with them, so a coach who found a child here had to go and find
//  them again somewhere else to read anything about them. Each row is a button now, wrapping the
//  same `CourtRosterRow` the same way the court screen wraps it, because it is the same act on
//  the same line.
//
//  The row itself is untouched and stays gesture-free — a list you can open is a property of the
//  screen drawing it, which is the arrangement that row's own header records. What it costs is
//  height: a tap in a column of adjacent taps has to be `HitTarget.minimum` tall or a finger
//  reaching for one kid lands on the one above, which is what `GroupCard` says about its own 27pt
//  row and settles here too. So a folded card's three names stand 44pt apart rather than the
//  design's 7. The coach line above them and the `+N more` below them have both been that tall
//  since they became controls, so this is the card's own rhythm rather than a new one — but it
//  does mean `OverviewTheme.rosterRowGap`'s note about adding up to `gap:7px` now describes only
//  the space between two rows that are already at their minimum.
//
//  ── The header caret is navigation, and the frames draw a fold ───────────────────────────────
//
//  Stated because it is the one place this card knowingly diverges. `8i` closes Court 1's header
//  with `ph-caret-up` in the accent and Courts 2 and 3 with a grey `ph-caret-down` — a fold, over a
//  roster the collapsed cards do not draw at all — and only the closed court gets `ph-caret-right`.
//  This card's roster is never hidden, so a fold in that slot would be a control with nothing to
//  do; the caret keeps the `ph-caret-right` reading that `8i`'s Court 4 and every row of `8j`'s
//  "Other courts" give it, and points at the court's own screen. The fold is the `+N more` row at
//  the foot of the list, where there is something to fold.
//
//  ── The block's note is not drawn here ───────────────────────────────────────────────────────
//
//  `8j` does draw one, under your own court's coach: "Cross-court forehand feeds, then a volley
//  ladder." That is the running block's `detail`, and it is on `RunningBlockCard` instead, two
//  cards up. A block runs across the venue, so what it says to do is not a fact about one court —
//  pinning it to yours meant a coach on Court 3 could not see it — and with that card on screen,
//  drawing it again here would be the same sentence twice on one scroll.
//

import SwiftUI

struct OverviewCourtCard: View {

    let card: CourtCard
    /// The court the person reading this is standing on.
    var isMine: Bool = false
    /// How full it is. Nil draws no reading: a closed court, or one the camp graph has no group
    /// for. `CourtCapacity.reading(for:capacity:)` decides, and `OverviewScreen` resolves it once
    /// per pass rather than per card.
    var capacity: CourtCapacity?
    /// The kids on the court, already folded to what this card should draw. Empty for a closed
    /// court, and for one with nobody on it today.
    var roster: CourtRoster = .none
    /// Whether `roster` is the whole court or a preview of it. Handed in beside the rows rather
    /// than inferred from them: the screen owns the answer, and `folded(to:)` *adds* to whatever
    /// overflow a roster already carried, so `overflow == 0` stops meaning "open" the moment a
    /// roster arrives that was short of the court to begin with.
    var isRosterExpanded: Bool = false
    /// What the coach line does: opens their staff card, or — on a court nobody has — opens the
    /// picker that puts somebody on it, which the line draws as a dashed `+` and "Add a coach".
    /// Nil leaves it inert, for a card carrying a coach the camp cannot resolve.
    /// `OverviewScreen.coachAction(for:)` decides.
    var onOpenCoach: (() -> Void)?
    /// Opens and folds the court's list. Nil on a court small enough to draw whole, which is
    /// what keeps the card from offering a control that would change nothing.
    var onToggleRoster: (() -> Void)?
    /// Opens the court's own screen — the header caret's destination. Nil draws no caret at all;
    /// see `header`.
    var onOpenCourt: (() -> Void)?
    /// Opens one of the kids in the list — `8q`, for the name tapped.
    ///
    /// **Required, where the three above are optional**, and the difference is not an oversight.
    /// Each of those has a nil that *draws* something: no caret, an inert coach line, no fold
    /// control. There is no such state here — every row this card draws is a child with a screen
    /// behind them, and a closed court draws no rows at all — so an optional would encode a card
    /// whose names are dead, which is precisely the defect this closure exists to remove. The
    /// compiler asking every caller where a name goes is the point.
    ///
    /// Two precedents, and the second is the closer one: `CondensedCourtRow.swift:42-44` makes the
    /// same call about its own `onOpen` on the same grounds, and `GroupCard.swift:38` — the app's
    /// other card with a roster on it — already declares this exact closure under this exact name,
    /// non-optional.
    let onOpenPlayer: (Player.ID) -> Void

    /// Kept in step with `CourtRosterRow`'s own scaled column so "+3 more" stays lined up
    /// with the names above it at every type size.
    @ScaledMetric(relativeTo: .callout) private var rankWidth = OverviewTheme.rankWidth
    /// 15 sits in the headline band, the one the 19pt title beside it rides.
    @ScaledMetric(relativeTo: .headline) private var caretSize = OverviewTheme.caretGlyph

    var body: some View {
        // The card's two heading slots, decided once. `overviewCourtLabel` is nil when there is no
        // activity, and the two halves of that answer have to stay exactly inverse — the overline
        // is drawn only when there is a title under it, and the title is promoted into the header
        // row only when there is not. Read as two separate conditionals they were free to drift.
        let courtLabel = card.overviewCourtLabel

        return Card(
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

                header(courtLabel)

                if courtLabel != nil {
                    styledTitle
                        .padding(.top, OverviewTheme.titleGap)
                }

                // A closed court shows no coach. The line above already names whoever is on it,
                // and a court out of play is not being run by anybody.
                if !card.isClosed {
                    CourtCoachLine(name: card.coachName, isMine: isMine, action: onOpenCoach)
                        .padding(.top, OverviewTheme.coachRowGap)
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

    /// `COURT 1`, the head-count, the badge and the caret — the design's `gap:10px` row.
    ///
    /// Four separate accessibility elements, in reading order, rather than one combined phrase.
    /// The card used to combine its title and subtitle and that was right while they were one
    /// sentence; these are four different facts, one of them a control, and a combined label would
    /// swallow the `Open` button into a run of prose.
    private func header(_ courtLabel: String?) -> some View {
        HStack(spacing: OverviewTheme.headerGap) {
            heading(courtLabel)

            Spacer(minLength: 0)

            if let capacity {
                CourtCapacityBadge(capacity: capacity)
            }

            if card.isClosed || isMine {
                CourtStatusBadge(status: card.status, isProminent: isMine)
            }

            // Wired at last. The caret's destination is the court's own screen — roster, coach,
            // status and the notes written against it — which `PushedScreen.court` presents, so
            // the glyph is a real control with a real label instead of a drawn one hidden from
            // VoiceOver. The rule that put it here has not changed: no destination, no caret,
            // because a control that goes nowhere is worse than a glyph that never claimed to.
            //
            // Your own court still has no caret. You are already standing on it, and the screen
            // behind the caret would tell you what is in front of you.
            //
            // Deliberately the caret alone and not the whole card, and the argument has only got
            // stronger. The card holds a control on nearly every line of it now — the coach line,
            // a button per kid, the `+N more` row, and on `8j` the pinned banner sits directly
            // above it — and a tap target wrapped round all of them has to win an ambiguity
            // contest with each on every tap. It is also the wrong shape for VoiceOver: a card
            // that is one button reads its title, its head-count, its coach and five children's
            // names as a single label, and swiping through the kids — let alone opening one —
            // stops being possible at all.
            //
            // What keeps them apart is that none of them overlaps another. Each is a sibling in
            // one column, grown to `HitTarget.minimum` and then shaped to exactly the region it
            // was grown to, so every point on the card belongs to at most one of them and
            // hit-testing has nothing to arbitrate. That is why none of them bleeds its target
            // past its own row, and why adding a control per kid did not have to move the three
            // that were already here.
            //
            // Gated on the closure alone. Your own court has no caret in the design — but that is
            // `OverviewScreen`'s rule to state, and it states it by passing nothing. Re-testing
            // `isMine` here said it twice, so a caller that passed a closure for its own court got
            // no caret and no diagnostic.
            if let onOpenCourt {
                openCourtButton(onOpenCourt)
            }
        }
    }

    /// The smallest heading this card has: `COURT 1` over an activity, or the court's own name
    /// when there is no activity to put under it.
    ///
    /// The design draws the first and has no picture of the second, because every court in `8i` is
    /// running something. The app reaches it on any day with no blocks on it — `CourtCard.activity`
    /// is `groups.activity` or the running block's title, and an unscheduled day has neither — and
    /// the obvious reading of the frame, an empty overline with the name below, leaves the card's
    /// first row holding nothing but a head-count floating off to the right. Promoting the name
    /// into the slot the overline vacates keeps the card's rhythm in both states and never says the
    /// court twice.
    ///
    /// `flex:1` on the design's own cell: whichever line this is takes the row, and the reading,
    /// the badge and the caret close it.
    ///
    /// The rotor's entry for this card, either way. A screen of twelve courts is otherwise a flat
    /// run of a hundred elements with nothing to jump between.
    @ViewBuilder
    private func heading(_ courtLabel: String?) -> some View {
        if let courtLabel {
            Text(courtLabel)
                .typeStyle(
                    OverviewTheme.courtLabel,
                    color: OverviewTheme.courtLabelColour(isClosed: card.isClosed)
                )
                .accessibilityAddTraits(.isHeader)
        } else {
            styledTitle
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// The caret, at 44pt of finger around the 15pt it draws.
    ///
    /// Labelled with the court rather than "Open" alone: a screen of these is a screen of
    /// identical buttons, and the rotor would offer eight of them with no way to tell which court
    /// each one opens — the failure `InboxNeedsActionRow` records from its two "Review" buttons.
    private func openCourtButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DisclosureChevron(size: caretSize)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(card.courtLabel ?? card.groupName)")
        .accessibilityHint("Shows its list, its coach and its notes")
    }

    // MARK: Title

    /// `Drills`, and on a closed court `Net down · Tom is on it`.
    ///
    /// One line of two runs, which is how the design writes it — a `<span>` inside the title that
    /// resets the weight to 400, the size to 13 and the tracking to 0:
    ///
    ///     <div style="font:600 19px;…;color:#8A6416">Net down<span style="font:400 13px;
    ///       letter-spacing:0;color:#B67A16"> · Tom is on it</span></div>
    ///
    /// One `Text` and not two, deliberately. Stacked, the reason reads as a subtitle and wraps onto
    /// its own line under a title that has room to spare; interpolated, it flows after the activity
    /// exactly as drawn and only wraps when the pair genuinely runs out of card.
    ///
    /// Allowed to wrap, both runs. A court's activity is what tells the cards apart, and "Skills
    /// rotation and serve ladder" truncated to "Skills rotation and…" is the half that says least.
    ///
    /// One styled run, drawn in either of two places — under the overline when there is one, and
    /// in the header row itself when there is not (see `heading`). It was written out twice, and
    /// the copies had already stopped agreeing about `frame(maxWidth:)`.
    private var styledTitle: some View {
        titleText
            .typeStyle(
                OverviewTheme.cardTitle,
                color: OverviewTheme.courtTitleColour(isClosed: card.isClosed)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: Text {
        guard let reason = card.status.closureReason else { return Text(card.overviewTitle) }
        // Interpolated rather than joined with `+`, which is what `Text.typeStyleRun` asks for.
        // The outer `.typeStyle` above sets the run this one does not override.
        let clause = Text(" · \(reason)")
            .typeStyleRun(OverviewTheme.closureReason, color: Theme.warning)
        return Text("\(card.overviewTitle)\(clause)")
    }

    // MARK: Roster

    private var rosterList: some View {
        VStack(spacing: OverviewTheme.rosterRowGap) {
            ForEach(roster.rows) { row in
                kidRow(row)
            }

            // Drawn whenever the court can fold at all, rather than whenever something *is*
            // folded away — an open card with no way back is the half of this control the
            // design never had to draw.
            if let onToggleRoster {
                overflowRow(onToggleRoster)
            }
        }
    }

    /// One name, and the way to the kid behind it.
    ///
    /// `CourtScreen.kidRow` exactly, which is the point: it wraps this same `CourtRosterRow` in
    /// this same button to reach this same screen, so a child tapped on a card and a child tapped
    /// on the court behind it are one gesture and not two that can drift. The row is left as a
    /// line that takes no gestures of its own — see its own header, which the court screen already
    /// depends on.
    ///
    /// **No horizontal inset inside the label, where the court screen's copy has
    /// `OnTheDayTokens.cardInset`.** There the rows sit in an unpadded `Card` and each supplies its
    /// own gutter, so the button spans the card and the drawn line is inset within it. Here the
    /// whole column already sits inside `OverviewTheme.cardPadding`, so repeating an inset would
    /// push the names off the rank numerals they are lined up with. Bleeding the target back out
    /// over that padding was the other way to match the court screen and is refused: neither
    /// `CourtCoachLine` nor `overflowRow` reaches into it, and a card where a tap in the margin
    /// beside a name opens a kid while the same tap beside the coach does nothing is a card whose
    /// edges mean two different things.
    private func kidRow(_ row: PlayerRow) -> some View {
        Button {
            onOpenPlayer(row.id)
        } label: {
            CourtRosterRow(row: row)
                // The drawn line keeps the height the design gives it and the touch grows around
                // it. Grown first, shaped second — the reverse pins the target back onto the drawn
                // line and hands out a column of ~20pt targets. It is the order `CourtCoachLine`
                // and `MoreRow` in this same column are already written in.
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Set outright rather than lifted off the row inside the label. `spokenLabel(for:)` is
        // `static` for exactly this — see its doc for what a column of buttons all announced as
        // "Button" costs a reader who cannot see which kid is which.
        .accessibilityLabel(CourtRosterRow.spokenLabel(for: row))
        // The court screen's own words for the same act (`CourtScreen.swift:300`), spelled out a
        // second time rather than shared.
        //
        // **Not because it could not be shared.** The label directly above already reaches into
        // `CourtRosterRow` for `spokenLabel(for:)`, which is `static` for exactly that reason, and
        // a hint constant beside it would be the same move. It is that one string is not what is
        // duplicated here: the whole of this method is `CourtScreen.kidRow` with a different
        // inset, so the honest fix is a `CourtRosterButton` over `row`, `inset` and `action` that
        // both screens consume.
        //
        // That view would live here, beside the row, in this folder — the boundary is narrower
        // than "another feature". It is `CourtScreen.swift` itself, which is the one line that
        // would have to change to adopt it and is under a screen this unit does not own. Landing
        // the shared view with a single consumer would leave the court screen's copy standing
        // *and* a view calling itself shared, which is three spellings where there are now two.
        //
        // So: two copies, watched. If they ever start saying different things about the same tap,
        // that is the signal to write the third view rather than to reconcile the strings.
        .accessibilityHint("Opens their screen")
    }

    /// `+3 more`, indented into the rank column so it starts where the names do — and
    /// `Show less`, in the same place, once the card is open.
    ///
    /// The design sets this line in the accent with a caret beside it, which is what `MoreRow`
    /// draws (`8i`: `font:500 13.5px;color:#1A7F55` over `ph-caret-down` at 13). It reads `400`
    /// rather than the frame's `500` because that weight is `MoreRowMetrics.inline`'s, shared with
    /// Groups' own cards, and half a weight on one row is not worth two screens disagreeing about
    /// what a fold looks like.
    ///
    /// Deliberately not the header's caret. That one points at the court's own screen; making it
    /// fold the list would answer a question it has never asked.
    private func overflowRow(_ toggle: @escaping () -> Void) -> some View {
        MoreRow(
            hiddenCount: roster.overflow,
            isExpanded: isRosterExpanded,
            noun: "kid",
            nounPlural: "kids",
            qualifier: "on this court",
            // Indented to the rank column so the label starts under the names, not their numbers.
            metrics: .inline(indent: rankWidth),
            action: toggle
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
    /// The last name tapped. A preview cannot push `8q`, so the closure's argument is drawn
    /// instead — which is also the only way to check by hand that the controls stacked down a card
    /// each win their own taps: the header caret, the coach line and `+N more` all have to leave
    /// this line alone, and every name has to change it to itself and not to its neighbour.
    @State private var opened: String?

    private let cards = [
        OverviewFixtures.drills,
        OverviewFixtures.matchPlay,
        OverviewFixtures.skillsRotation,
        OverviewFixtures.netDown,
        OverviewFixtures.unassigned,
    ]

    var body: some View {
        let rosters = TodayCourts.rosters(in: OverviewFixtures.camp, day: OverviewFixtures.day)
        let capacities = TodayCourts.capacities(in: OverviewFixtures.camp)

        return ScrollView {
            VStack(spacing: OverviewTheme.cardGap) {
                Text(opened.map { "Opened \($0)" } ?? "Tap a name")
                    .typeStyle(.meta, color: Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(cards) { card in
                    let isExpanded = expanded.contains(card.id)
                    let roster = TodayCourts.roster(
                        for: card,
                        from: rosters,
                        preview: OverviewTheme.rosterPreview,
                        isExpanded: isExpanded
                    )

                    OverviewCourtCard(
                        card: card,
                        capacity: CourtCapacity.reading(for: card, capacity: capacities[card.id]),
                        roster: roster,
                        isRosterExpanded: isExpanded,
                        onOpenCoach: {},
                        onToggleRoster: roster.isFoldable(to: OverviewTheme.rosterPreview)
                            ? { expanded.toggle(card.id) }
                            : nil,
                        onOpenCourt: {},
                        onOpenPlayer: { id in
                            opened = roster.rows.first { $0.id == id }?.player.displayName
                        }
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
        capacity: OverviewFixtures.capacity(for: OverviewFixtures.drills),
        roster: OverviewFixtures.fullRoster(for: OverviewFixtures.drills),
        onOpenCoach: {},
        onToggleRoster: {},
        onOpenCourt: {},
        onOpenPlayer: { _ in }
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

/// The same card at the size the app caps Dynamic Type at, which is where the rows being controls
/// shows: each was already at least `HitTarget.minimum` tall, so a longer name should make the
/// card taller without the rank column or the marks at the end of a line leaving it.
#Preview("A court, open — accessibility1") {
    OverviewCourtCard(
        card: OverviewFixtures.drills,
        capacity: OverviewFixtures.capacity(for: OverviewFixtures.drills),
        roster: OverviewFixtures.fullRoster(for: OverviewFixtures.drills),
        onOpenCoach: {},
        onToggleRoster: {},
        onOpenCourt: {},
        onOpenPlayer: { _ in }
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
    .dynamicTypeSize(.accessibility1)
}

#Preview("Your court") {
    OverviewCourtCard(
        card: OverviewFixtures.drills,
        isMine: true,
        capacity: OverviewFixtures.capacity(for: OverviewFixtures.drills),
        roster: OverviewFixtures.roster(
            for: OverviewFixtures.drills, limit: OverviewTheme.rosterPreview
        ),
        onOpenCoach: {},
        onToggleRoster: {},
        onOpenPlayer: { _ in }
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

/// The reading the design never draws: a court past its ceiling. `Group.capacityBanner` writes the
/// same fact on Groups, so the state is real even though `8i` has no picture of it.
#Preview("A court over its ceiling") {
    OverviewCourtCard(
        card: OverviewFixtures.drills,
        capacity: CourtCapacity(here: OverviewFixtures.drills.playersHere, capacity: 6),
        roster: OverviewFixtures.roster(
            for: OverviewFixtures.drills, limit: OverviewTheme.rosterPreview
        ),
        onOpenCoach: {},
        onToggleRoster: {},
        onOpenCourt: {},
        onOpenPlayer: { _ in }
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
