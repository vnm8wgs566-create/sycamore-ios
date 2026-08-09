//
//  CondensedCourtRow.swift
//  Sycamore
//
//  One court that is not yours: "Court 2 · Match play · Alina", on one line, with no roster.
//
//  `8j`'s second half, transcribed:
//
//      <div style="display:flex;align-items:center;gap:11px;padding:12px 14px">
//        <div style="flex:none;white-space:nowrap;font:600 10px;letter-spacing:.14em;
//                    text-transform:uppercase;color:#A2A6AE">Court 2</div>
//        <div style="flex:1;min-width:0;font:600 15px;letter-spacing:-.025em">Match play</div>
//        <image-slot style="width:26px;height:26px" shape="circle" …>
//        <div style="font:500 12.5px;color:#5C6068">Alina</div>
//        <i class="ph ph-caret-right" style="font-size:15px;color:#C7CBD2"></i>
//      </div>
//
//  ── Why the same court is drawn two ways ─────────────────────────────────────────────────────
//
//  Because the frame's own caption says so: "Your court first, the rest quiet." A coach standing on
//  Court 1 needs their own court's kids, their coach and their fold; what they need from Courts 2
//  and 3 is that somebody has them and something is happening on them. `8j` draws that as three
//  rows in one card, in the space the admin frame spends on a single card.
//
//  An admin has no court of their own, so `8i` never reaches this: every court is a full
//  `OverviewCourtCard`, which is what makes the two frames one screen with a branch rather than two
//  screens. `OverviewScreen.body` is where the branch is.
//
//  ── The closed row ───────────────────────────────────────────────────────────────────────────
//
//  `8j` gives Court 4 the same row on a `#FDFBF5` wash, its label in `#C09A4A`, its reason in
//  `#8A6416`, and the word `Closed` where the coach's name would be. No coach disc: a court out of
//  play is not being run by anybody, which is the rule `OverviewCourtCard` already states about the
//  full card.
//

import SwiftUI

struct CondensedCourtRow: View {

    let card: CourtCard
    /// Opens the court's own screen. Required rather than optional: every row in this card is a
    /// court that is not yours, and every one of them has somewhere to go.
    let onOpen: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var avatarSize = OverviewTheme.courtCoachAvatar
    /// 15 sits in the headline band, the one the 15pt activity beside it rides.
    @ScaledMetric(relativeTo: .headline) private var caretSize = OverviewTheme.caretGlyph

    var body: some View {
        // Resolved once and read by the drawing *and* by the spoken label. These were two
        // three-way branches in the same order over the same three states, which is how a row
        // ends up saying one thing to the eye and another to VoiceOver with nothing to catch it.
        let trailing = Trailing(card)

        return Button(action: onOpen) {
            row(trailing)
                // `CardRow` sets a `contentShape` of its own pinned to the plate it draws, so the
                // shape is restated *after* the frame — that is what carries the target out to the
                // grown region rather than leaving it on the drawn one.
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Read as one sentence. Four runs of text and a disc, swiped through separately, is four
        // stops to learn one court — and the rotor would offer a screen of buttons all announced
        // as "Court".
        //
        // On the **button**, not on the row inside it. A button whose label happens to contain an
        // accessibility element is relying on SwiftUI to lift the child's label onto the control;
        // it usually does, and when it does not the result is a card of rows all announced as
        // "Button" with no way to tell which court each one opens. `CourtRosterRow.spokenLabel`
        // records the same failure from the other side.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel(trailing))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Shows its list, its coach and its notes")
    }

    private func row(_ trailing: Trailing) -> some View {
        CardRow(
            spacing: OverviewTheme.condensedRowGap,
            horizontalPadding: OverviewTheme.condensedRowHorizontal,
            verticalPadding: OverviewTheme.condensedRowVertical
        ) {
            // `flex:none;white-space:nowrap` — the label never wraps and never gives ground to
            // the activity beside it. A "Court 12" broken across two lines stops being a label.
            //
            // The one `fixedSize` on this row, and it is the identity: everything else here can be
            // read off the card above or guessed from context, and which court this is cannot.
            if let label = card.overviewCourtLabel {
                Text(label)
                    .typeStyle(
                        OverviewTheme.condensedCourtLabel,
                        color: OverviewTheme.courtLabelColour(isClosed: card.isClosed)
                    )
                    .fixedSize()
            }

            // `flex:1;min-width:0` — the activity takes the room and yields it first. Clipped
            // rather than wrapped, which is the one place this row differs from the full card:
            // the card's title is the subject of a card and is allowed two lines, a row in a list
            // of three has to stay one line high or the list stops scanning.
            Text(card.overviewTitle)
                .typeStyle(
                    OverviewTheme.condensedTitle,
                    color: OverviewTheme.courtTitleColour(isClosed: card.isClosed)
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailingCells(trailing)

            DisclosureChevron(size: caretSize)
        }
        .background(card.isClosed ? OverviewTheme.closedRowFill : Theme.surface)
    }

    /// Who has the court — or, on a closed one, the word that replaces them.
    ///
    /// Everything here is `lineLimit(1)` and nothing is `fixedSize`, deliberately. Five cells on
    /// one line is already tight, and at the reader's largest size the disc doubles and the caret's
    /// target is 44pt on its own — so these are the cells that give ground first. A truncated
    /// "Alin…" beside a court's activity still says somebody has it, which is what the row is for;
    /// a row that cannot fit and overflows its card says nothing at all.
    @ViewBuilder
    private func trailingCells(_ trailing: Trailing) -> some View {
        switch trailing {
        case .closed(let badge):
            Text(badge)
                .typeStyle(OverviewTheme.condensedMeta, color: Theme.warning)
                .lineLimit(1)

        case .coach(let name):
            InitialsAvatar(
                Initials.make(from: name),
                size: avatarSize,
                font: .initials(forAvatarSize: OverviewTheme.courtCoachAvatar)
            )

            Text(name)
                .typeStyle(OverviewTheme.condensedMeta, color: Theme.inkSecondary)
                .lineLimit(1)

        case .nobody:
            // Not in `8j`, which gives all three of its other courts a coach. A court with nobody
            // is drawn here as the absence it is rather than as a control: filling a court is a
            // decision about the court you are looking at, and this row's whole point is that you
            // are not. The caret opens the court screen, where that write lives.
            Text(CoachPill.needsACoach)
                .typeStyle(OverviewTheme.condensedMeta, color: Theme.warning)
                .lineLimit(1)
        }
    }

    /// "Court 2. Match play. Coach Alina." — and "Court 4. Net down. Closed." for one out of play.
    ///
    /// The label comes from `overviewCourtLabel` and not from `courtLabel`, so that a court with no
    /// activity is announced once. `overviewTitle` falls back to the court's own name when there is
    /// nothing happening on it, and reading both would say "Court 2. Court 2. Coach Alina."
    private func spokenLabel(_ trailing: Trailing) -> String {
        let parts = [card.overviewCourtLabel, card.overviewTitle, trailing.spoken]
        return parts.compactMap { $0 }.joined(separator: ". ")
    }

    /// The three things the end of this row can be. One value, drawn once and said once.
    ///
    /// A private nested type rather than a file of its own: it is not a shape the app has, it is
    /// this row's own last cell, and nothing outside this file can construct or read one.
    private enum Trailing {
        case closed(String)
        case coach(String)
        case nobody

        init(_ card: CourtCard) {
            if card.isClosed {
                self = .closed(card.status.badge)
            } else if let coachName = card.coachName {
                self = .coach(coachName)
            } else {
                self = .nobody
            }
        }

        var spoken: String {
            switch self {
            case .closed(let badge): badge
            case .coach(let name): "Coach \(name)"
            case .nobody: CoachPill.needsACoach
            }
        }
    }
}

// MARK: - Previews

#Preview("Other courts") {
    Card(radius: OverviewTheme.cardRadius) {
        // `8j`'s own three, in the order it draws them.
        CondensedCourtRow(card: OverviewFixtures.matchPlay, onOpen: {})
        CondensedCourtRow(card: OverviewFixtures.skillsRotation, onOpen: {})
        CondensedCourtRow(card: OverviewFixtures.netDown, onOpen: {})
        // The one it does not draw: a court nobody has.
        CondensedCourtRow(card: OverviewFixtures.unassigned, onOpen: {})
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}

#Preview("Other courts — accessibility1") {
    Card(radius: OverviewTheme.cardRadius) {
        CondensedCourtRow(card: OverviewFixtures.matchPlay, onOpen: {})
        CondensedCourtRow(card: OverviewFixtures.netDown, onOpen: {})
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
    .environment(\.dynamicTypeSize, .accessibility1)
}
