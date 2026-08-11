//
//  EvenOutSheet.swift
//  Sycamore
//
//  "Even out the groups?" — the confirmation the button never had.
//
//  ---------------------------------------------------------------------------------------------
//  WHY A SHEET AND NOT A TAP
//  ---------------------------------------------------------------------------------------------
//
//  `RankView`'s "Even out" pill fires `store.evenOut()` on the tap. That is a re-deal of every
//  court in the camp with no preview, no count and no way back. On a
//  venue somebody has spent a morning arranging by hand, the tap is indistinguishable from the
//  tap that does nothing, right up until the screen redraws with forty children somewhere else.
//
//  The design does not ask it that way (`design/app/regions/sheet-shEvenOut.html`). It shows the
//  venue's sizes now, the sizes after, how many children walk, and puts that count in the button's
//  label — the same rule `8d` follows with "Import 42 players": *you are agreeing to a count, not
//  pressing Done*. The way out is "Keep as is", which is a decision rather than a dismissal.
//
//  ---------------------------------------------------------------------------------------------
//  ONE VENUE
//  ---------------------------------------------------------------------------------------------
//
//  Scoped to a venue, which is the design's scope — its context line is `Sycamore · 9 · 7 · 8 · 6`
//  and its rows are that venue's groups. `store.evenOut()` is the camp-wide verb and is the wrong
//  one behind a screen like this: a preview that showed one venue's courts and then rearranged the
//  venue next door would be a confirmation for something other than what it confirmed.
//  `store.spreadKids(.allKids, over:atVenue:)` is the venue-scoped write, and it is the very call
//  `EvenOutPlan` runs against a copy to draw these rows.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT IS MISSING, AND SAID SO RATHER THAN FAKED
//  ---------------------------------------------------------------------------------------------
//
//  The design snapshots the roster before the deal and offers **Undo** on a toast. Neither exists
//  here. The app has a toast now (`Toast.swift`), so half of that gap has closed and `evenOut`
//  simply has not been wired to it yet; what is still missing is the snapshot an Undo would
//  restore, and there is no undo stack to hang one from. Inventing both to serve one sheet would
//  be a transient surface and an undo vocabulary that nothing else in the app speaks, decided by
//  whoever happened to write this file. The preview is the mitigation the app can actually keep:
//  you see the whole move before it happens, which is the half of the design's safety net that
//  does not need infrastructure. The gap is real and belongs in a wave that owns the design system.
//

import SwiftUI

struct EvenOutSheet: View {

    let store: AppStore
    /// The venue whose groups are being levelled. An id rather than the `Venue`, so a sheet left
    /// open while the venue is renamed on another device retitles instead of lying — the same call
    /// `PlayerCourtPicker` makes about a kid's name.
    let venueID: Venue.ID
    /// How the sheet gets out of the way: it clears the state the caller is holding. The shape
    /// `PlayerCourtPicker`, `EarlyPickupSheet` and `CourtCoachPicker` all take, and for their
    /// reason — the caller owns the presentation, so the caller is the only one who can end it.
    let onClose: () -> Void

    init(store: AppStore, venueID: Venue.ID, onClose: @escaping () -> Void) {
        self.store = store
        self.venueID = venueID
        self.onClose = onClose
    }

    /// Four rows, a hint, a button and a way out. Well short of `PlayerCourtPicker`'s 0.88, which
    /// is a long list somebody is hunting through; this is a short statement somebody is reading.
    /// `.large` is in the detent set through `SheetChrome`, so a twelve-court venue at an
    /// accessibility type size can still be pulled the rest of the way up.
    private static let detent: Double = 0.72

    var body: some View {
        // Worked out once per pass and read from there. `SheetChrome` builds its content eagerly,
        // so a computed property would copy the camp and run the deal again for the header, the
        // rows, the hint and the button — four times over, for one answer that cannot differ
        // between them.
        let plan = EvenOutPlan(camp: store.camp, venueID: venueID)

        return SheetChrome(
            title: "Even out the groups?",
            subtitle: plan?.contextLine,
            subtitlePlacement: .eyebrow,
            detentFraction: Self.detent,
            onClose: onClose
        ) {
            if let plan {
                planRows(plan)
                hint(plan)
                cta(plan)
            }

            keepAsIs
        }
    }

    // MARK: - The rows

    /// One line per group: what it holds, and what it would hold.
    ///
    /// Every group is drawn, including the ones the deal would leave alone and the ones it would
    /// empty. A card that listed only what changes would not add up to the venue named two lines
    /// above it, and the reader's first check on a preview like this is whether the numbers sum to
    /// the roster they know.
    private func planRows(_ plan: EvenOutPlan) -> some View {
        Card(radius: Radius.card) {
            ForEach(plan.rows) { row in
                CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                    Text(row.title)
                        .typeStyle(.rowTitleSm, color: Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Text("\(row.from)")
                        .typeStyle(.rowValue, color: Theme.inkTertiary)
                        .monospacedDigit()

                    // Decorative: the sentence it stands for is in `accessibilityPhrase`, and an
                    // arrow announced as "right arrow" between two bare numerals is noise.
                    Image(systemName: "arrow.right")
                        .font(.system(size: arrowSize, weight: .regular))
                        .foregroundStyle(Theme.inkGhost)
                        .accessibilityHidden(true)

                    Text("\(row.to)")
                        .typeStyle(.rowTitleSm, color: Theme.accentDark)
                        .monospacedDigit()
                }
                // "Group 2, 9 kids, becomes 8" — one phrase, not four elements of which two are
                // unlabelled numerals. `EvenOutPlan.Row` writes the sentence, so the words and the
                // numbers cannot come apart.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityPhrase)
            }
        }
        .padding(.top, Spacing.large)
    }

    /// The design's `13px` arrow, scaled so it keeps its proportion to the numerals it sits
    /// between rather than staying put while they grow.
    @ScaledMetric(relativeTo: .body) private var arrowSize: CGFloat = 13

    // MARK: - What it will do

    /// The rule, then the count. The rule first because it is what makes the count make sense: a
    /// reader who does not know the deal follows the ladder cannot tell whether 22 is a lot.
    private func hint(_ plan: EvenOutPlan) -> some View {
        Text("Re-deals by ladder order — Group 1 takes the top band. \(plan.movesLine)")
            .typeStyle(.footnote, color: Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Spacing.medium)
    }

    // MARK: - The two ways out

    /// Disabled when there is nothing to do, rather than hidden.
    ///
    /// A venue that is already level opens this sheet to a card of unchanged rows and a greyed
    /// button reading "Even out · 0 moves", which is an answer — *nothing needs doing here* — and
    /// the reader came for exactly that. Hiding the button would leave a sheet with no primary
    /// action and no explanation of where it went.
    private func cta(_ plan: EvenOutPlan) -> some View {
        PrimaryButton(plan.ctaTitle) {
            apply(plan)
        }
        .opacity(plan.isNoOp || store.isWorking ? 0.45 : 1)
        .disabled(plan.isNoOp || store.isWorking)
        .padding(.top, Spacing.gutterWide)
    }

    /// "Keep as is" — the design's word, and a decision rather than a dismissal.
    ///
    /// A plain label rather than a bordered button: two bordered controls stacked read as a choice
    /// between two equal things, and these are not equal. The close cross in the header does the
    /// same job; this says out loud what backing out means, which is the whole difference between
    /// leaving a sheet and choosing to leave the groups alone.
    private var keepAsIs: some View {
        Button(action: onClose) {
            Text("Keep as is")
                .typeStyle(.buttonCompact, color: Theme.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.hairGap)
    }

    // MARK: - Applying

    /// Closes first, then writes — the call `PlayerCourtPicker.move(to:)` and `CourtCoachPicker`
    /// both make, for the reason `AppStore.finishFirstSort` records: a refusal belongs in the tab's
    /// banner, not inside a sheet still asking a question about a decision already taken.
    ///
    /// Closing first also settles what this sheet would otherwise do to itself. The plan is derived
    /// from `store.camp`, so a sheet left standing through its own write would redraw the instant
    /// the camp came back — every row levelled, the button reading `0 moves` — which looks like the
    /// press failed.
    ///
    /// `plan.courtIDs` rather than re-reading the venue's courts here: the write runs over the very
    /// courts the preview was drawn from, so a court added or closed between the sheet opening and
    /// the button being pressed cannot make the two disagree.
    private func apply(_ plan: EvenOutPlan) {
        onClose()
        Task { await store.spreadKids(.allKids, over: plan.courtIDs, atVenue: venueID) }
    }
}

// MARK: - Reading the camp

private extension EvenOutPlan {

    /// The plan for a camp that may not have loaded yet.
    ///
    /// The optional camp is unwrapped here rather than in the sheet's body so the view has one
    /// `if let` instead of two nested ones. Nil covers both "no camp" and "no such venue", which
    /// the sheet treats the same way: it has nothing to preview, so it draws the way out and
    /// nothing else.
    init?(camp: Camp?, venueID: Venue.ID) {
        guard let camp else { return nil }
        self.init(camp: camp, venueID: venueID)
    }
}

// MARK: - Previews

/// The scrim, the plate and the frame, written once — the shape `PlayerCourtPicker`'s previews
/// take, and for its reason: the design draws its sheets over a 700pt frame, and three copies of
/// that arithmetic would be three places to edit the day the detent moves.
@MainActor
private func evenOutPreview(_ store: AppStore = .preview) -> some View {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        EvenOutSheet(
            store: store,
            venueID: store.camp?.orderedVenues.first?.id ?? UUID(),
            onClose: {}
        )
        .frame(height: 504)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.surfaceWarm)
}

#Preview("Even out — a lopsided venue") {
    let store = AppStore.preview

    // Read out, edited, written back once. `AppStore.camp`'s setter bumps a revision and drops two
    // memos on every assignment, so mutating through the optional in a loop would rebuild the
    // section caches once per child.
    if var camp = store.camp,
       let venueID = camp.orderedVenues.first?.id,
       let court = camp.groups(in: venueID).first {
        // Everybody at the venue piled onto its first court, which is the state an import leaves
        // and the one this sheet exists for.
        for index in camp.players.indices where camp.players[index].venueID == venueID {
            camp.players[index].groupID = court.id
        }
        camp.reindex()
        store.camp = camp
    }

    return evenOutPreview(store)
}

#Preview("Even out — already level") {
    let store = AppStore.preview

    if var camp = store.camp {
        camp.evenOut()
        store.camp = camp
    }

    return evenOutPreview(store)
}

#Preview("Even out — large type") {
    evenOutPreview()
        .dynamicTypeSize(.accessibility1)
}
