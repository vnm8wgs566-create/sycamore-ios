//
//  PlayerCourtPicker.swift
//  Sycamore
//
//  Where this kid goes — every court in the camp, venue by venue, behind `8q`'s pinned bar.
//
//  ── What this overturns ──────────────────────────────────────────────────────────────────────
//
//  The design writes `8q`'s bar "Move to another group". The bar shipped as "Move up a court",
//  and `PlayerScreen`'s header recorded why: an arbitrary move "needs the whole ladder on screen
//  to aim at, which this screen does not have".
//
//  That is the wrong reading of what aiming needs. A ladder is how you decide *whether* a kid
//  should move — it is one long comparison, and `8p` is the screen for it. Deciding *where* they
//  go once that is settled needs three facts per court and nothing else: which court it is, how
//  full it is, and who has it. That is a list, and this sheet is that list. One court up remains
//  the common case; it is now one tap in here rather than the only sentence the screen can say.
//
//  ── What this file is not ────────────────────────────────────────────────────────────────────
//
//  The list itself — sections, fills, coaches, which court is theirs — is `PlayerCourtChoices`,
//  next door and with no view in it, so it can be tested. This file draws what that decides and
//  commits the write. `PlayerCourtChoices.swift` argues why it lives apart.
//
//  ── A full court is flagged, not blocked ─────────────────────────────────────────────────────
//
//  A court at or over its ceiling wears a `WarningPill` and is still tappable. This is the app's
//  standing answer, argued at length for the schedule's overlaps in `ScheduleResize.swift:19-42`
//  and `BlockEditorDraft.swift:96-125`: the camp may legitimately go over, somebody wants to *see*
//  it rather than be stopped at seven in the morning with a car park filling up, and a refusal
//  here would be a second opinion about a rule `Group.isOverCapacity` already holds. Overview
//  draws the same amber for the same court and does not disable anything either.
//
//  ── They land at the bottom ──────────────────────────────────────────────────────────────────
//
//  Said out loud in the sheet's subtitle, and again over `move(to:)`, because it is the part of
//  this write nobody expects and the part somebody will one day try to "fix".
//
//  ── Presented by its caller ──────────────────────────────────────────────────────────────────
//
//  No case is added to `ActiveSheet`; `PlayerScreen` holds its own `@State` and its own
//  `.sheet(item:)`, as it already does for `8n`. `PickupTarget.swift:7-10` states the reason —
//  `8q` is itself presented and the root that owns `activeSheet` is underneath it — and
//  `CourtCoachPicker.swift:20-25` states the general rule.
//
//  ── `rowBody` and `emptyCard` are drawings this app now has too many of ──────────────────────
//
//  Said out loud rather than left to be rediscovered, because `CourtCoachPicker.swift:27-38` said
//  it first and this is the copy it warned about. `rowBody` is that file's `row` minus the avatar
//  plus a pill; `emptyCard` is its `emptyCard` with a different sentence in it; and `BlockPickRow`
//  is a fourth drawing of the same shape.
//
//  `BlockPickRow` is *not* the fix as it stands. Its own header defends drawing an empty circle on
//  every unpicked row — a checklist's vocabulary — where this sheet and `CourtCoachPicker` commit
//  on the first tap and deliberately mark only the row that is already true. It has no slot for
//  the amber pill either. The fix is a shared pick row with an accessory slot, in the design
//  system or beside `SheetChrome`, plus a `SheetEmptyCard` next to `SheetSectionHeader` — both
//  folders another unit owns this wave. Four drawings is well past coincidence.
//

import SwiftUI

// MARK: - The kid a picker is open for

/// A one-field wrapper because `.sheet(item:)` wants `Identifiable` and `Player.ID` is a bare
/// `UUID` — the same shape, and the same reason, as `PickupTarget` and `CourtCoachRequest`.
///
/// The id and not the `Player`: a copy of the kid parked in presentation state would draw a name
/// and a placement from whenever the bar happened to be tapped, and the sheet re-reads both.
struct PlayerCourtRequest: Identifiable, Hashable, Sendable {
    let id: Player.ID
}

// MARK: - The sheet

struct PlayerCourtPicker: View {

    let store: AppStore
    let playerID: Player.ID
    /// How the sheet gets out of the way: it clears the state the caller is holding. The shape
    /// `EarlyPickupSheet` and `CourtCoachPicker` take, and for the same reason — the caller owns
    /// the state, so the caller is the only one who can put it down.
    let onClose: () -> Void

    /// The tick on their own court, at `CourtCoachPicker`'s size rather than a second opinion
    /// about how big a tick in a picker is.
    @ScaledMetric(relativeTo: .body) private var markSize = OverviewTheme.pickerMark

    /// How much of the frame this opens over.
    ///
    /// `OnTheDayTokens.pickupDetent`'s 0.88 rather than `OverviewTheme.coachPickerDetent`'s 0.73,
    /// and for that constant's own reason: this sheet is a *long* list — `SampleData` alone is
    /// twelve courts over two venues — and the thing somebody came here to do is find one of them.
    /// At 0.73 the second venue opens below the fold. `.large` is in the detent set as well,
    /// through `SheetChrome`, so the list can be pulled the rest of the way up.
    ///
    /// A `static` here rather than in a token set. `OverviewTheme` would be its natural home,
    /// beside `pickerMark` and `pickerMeta` which this file already reads, and `coachPickerDetent`
    /// which it is the sibling of — but that file belongs to another unit this wave, and a
    /// one-value enum of its own would be a token table nothing else ever enters. `static`, not
    /// `private let`, because a private stored property makes the synthesised memberwise
    /// initialiser private too, and `PlayerScreen` calls it.
    private static let detent: Double = 0.88

    var body: some View {
        // Resolved once and read from there. `SheetChrome` builds its content eagerly, so a
        // computed property would walk every venue, every court and every coach lookup twice in
        // one pass — which is the note `CourtCoachPicker.body` leaves about its own pool.
        let choices = PlayerCourtChoices(for: playerID, in: store.camp)
        let firstSection = choices.sections.first?.id

        return SheetChrome(
            title: title,
            // The part nobody expects, said where it cannot be missed. See `move(to:)`.
            subtitle: "They join the bottom of whichever court you pick.",
            detentFraction: Self.detent,
            onClose: onClose
        ) {
            if choices.sections.isEmpty {
                emptyCard
            } else {
                ForEach(choices.sections) { section in
                    SheetSectionHeader(
                        section.title,
                        topPadding: section.id == firstSection ? 0 : Spacing.medium
                    )

                    Card(radius: OnTheDayTokens.card) {
                        ForEach(section.courts) { court in
                            row(court)
                        }
                    }
                }
            }
        }
    }

    /// `Move Austin Z`. Read from the graph per pass rather than handed in, so a sheet left open
    /// while the kid's name is corrected on another device retitles instead of lying.
    private var title: String {
        guard let name = store.player(playerID)?.displayName, !name.isEmpty else {
            return "Move this kid"
        }
        return "Move \(name)"
    }

    // MARK: A court

    /// Their own court is drawn, ticked, and is not a button.
    ///
    /// Deliberately not a disabled button. `CourtCoachPicker` keeps its already-on row tappable
    /// because re-assigning the coach who is already there is a harmless no-op; picking the court
    /// a kid is already on is not — `movePlayer` would sink them to the bottom of their own court
    /// and write an Inbox row saying they had moved. And a `.disabled` button announces itself as
    /// dimmed, which describes a control that is temporarily unavailable rather than a statement
    /// of where they are.
    @ViewBuilder
    private func row(_ court: PlayerCourtOption) -> some View {
        if court.isCurrent {
            rowBody(court)
                .accessibilityAddTraits(.isSelected)
                .accessibilityHint("Where they are now")
        } else {
            // The label the button announces is `rowBody`'s, which it inherits: the sentence is
            // written once, on the drawing both branches share, rather than restated on each.
            Button {
                move(to: court)
            } label: {
                rowBody(court)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Moves them here")
        }
    }

    private func rowBody(_ court: PlayerCourtOption) -> some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(court.label)
                    .typeStyle(.rowTitleSm, color: Theme.ink)

                // Allowed to wrap. "6 of 8 · Needs a coach" truncated at an accessibility size
                // loses the coach, which is half of what the row is here to say — the same call
                // `CourtCoachPicker` makes about its own detail line.
                Text(court.meta)
                    .typeStyle(OverviewTheme.pickerMeta, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.small)

            // The flag a full court wears. `WarningPill` rather than a drawing of one: it is the
            // plate Overview's `1 over` and `Closed` badges already wear, and this is the same
            // amber about the same court.
            if let flag = court.flag {
                WarningPill(label: flag)
            }

            if court.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        // Grown first, shaped second. `CardRow` sets a `contentShape` of its own, pinned to the
        // plate it draws; restating it out here after the frame is what carries the target out to
        // the grown region rather than leaving it on the drawn one.
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
        // `.ignore` and one written sentence, not `.combine`. The row is drawn as three runs — a
        // court, a fraction and a name — which combine into "Court 3, 6 of 8 · Nass", and a
        // fraction read out that way is a score or a date. That is the whole argument behind
        // `CourtCapacity.spokenLabel`, and this is where it is honoured. Written on the drawing
        // rather than on the button so the tapping row and the inert one cannot drift apart.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(court.spokenLabel)
    }

    /// A camp with no courts in it yet. Drawn rather than left blank, because an empty sheet is
    /// indistinguishable from one that has not loaded — `CourtCoachPicker.emptyCard`'s argument,
    /// and `BlockCoachPicker.emptyRow`'s before it.
    private var emptyCard: some View {
        Card(radius: OnTheDayTokens.card, isDivided: false) {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                Text("This camp has no courts yet. Shape a venue in camp settings and they show up here.")
                    .typeStyle(OverviewTheme.cardSubtitle, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: The write

    /// Close, then move.
    ///
    /// `store.movePlayer(_:toVenue:group:)` — the intent Groups and Rank already commit through,
    /// which writes the Inbox activity row on the way. Nothing new was added to the store for
    /// this sheet, and nothing needed to be: an arbitrary move has always been expressible, it
    /// just had no way in from here.
    ///
    /// **The kid lands at the bottom of the court they arrive on, and that is correct.**
    /// `Camp.movePlayer` (`Models.swift:1203-1213`) sets `courtRank = Int.max / 2` and lets
    /// `reindex()` close the gap, so a mover sinks to the back of their new court rather than
    /// keeping a rank that meant something on the court they left. Position on a court is the
    /// coach's ordering of the kids *on that court*; carrying it across would drop a newcomer into
    /// the middle of somebody else's ladder. `applyRankOrder` does the identical thing for the
    /// same reason (`Models.swift:1196`). **Do not "fix" this into a rank-preserving move** — the
    /// sheet's subtitle promises this behaviour, and re-ordering afterwards is what `8p` is for.
    ///
    /// Closed before the write rather than after it. A sheet that sits open through a round trip
    /// with nothing moving on it reads as a tap that missed; and if the write is refused, the
    /// banner belongs over the screen — `perform` owns `errorMessage` and `RootView` floats it
    /// over every pushed screen — not inside a sheet that would then be the only thing left
    /// claiming a court was being picked.
    private func move(to court: PlayerCourtOption) {
        onClose()
        Task { await store.movePlayer(playerID, toVenue: court.venueID, group: court.id) }
    }
}

// MARK: - Previews

/// The scrim, the plate and the frame all four previews stand in, written once.
///
/// The design draws its sheets over a 700pt frame and this one opens 0.88 of it; four copies of
/// that arithmetic would be four places to edit the day the detent moves.
///
/// `@MainActor` because `AppStore.preview` is, and a default argument is evaluated wherever the
/// function is declared — the shape `pickupPreviewStore` and `lockedPreviewStore` already take.
@MainActor
private func courtPickerPreview(_ store: AppStore = .preview) -> some View {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        PlayerCourtPicker(store: store, playerID: SampleData.austinZ.id, onClose: {})
            .frame(height: 616)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

/// Austin Z is on Court 1 at Sycamore, and Court 2 there is the nine-kid court `SampleData` seeds
/// to make "1 over" real — so one frame carries the tick, the amber and ten plain rows across two
/// venues, which is every state a row has.
#Preview("Where does this kid go") {
    courtPickerPreview()
}

/// Every colour here is a `Theme` token, so the dark scheme is a check rather than a second
/// design — but the amber pill is the palette's one warm value on this sheet, and the one a
/// derived dark column is most likely to get wrong.
#Preview("Where does this kid go — dark") {
    courtPickerPreview()
        .preferredColorScheme(.dark)
}

/// A court's name over a wrapping detail line, with a pill and a tick beside it — the arrangement
/// that breaks first when the type ramp is pushed.
#Preview("Where does this kid go — accessibility1") {
    courtPickerPreview()
        .dynamicTypeSize(.accessibility1)
}

/// A store with no camp on it — the state the sheet cannot reach from `8q` today, and the one it
/// would draw as a blank plate if the empty card were not there.
#Preview("Where does this kid go — nothing to list") {
    courtPickerPreview(.previewCampPicker)
}
