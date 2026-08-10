//
//  TournamentSheet.swift
//  Sycamore
//
//  "New tournament" — the one sheet that strikes a draw. `sheet-shTourney.html`, plus the format
//  rows the design drew in an earlier layout, plus one question the design asks nowhere.
//
//  ── THE SHEET IS TWO OF THE DESIGN'S SCREENS ──────────────────────────────────────────────────
//
//  The prototype has this in two places that never coexisted. `tSetup` (`showApp.html:288-315`)
//  was a block *on the tab* with three tall format rows — icon, name, and a line saying what the
//  format means — and a count of tournaments to split into. `shTourney` (`sheet-shTourney.html`)
//  replaced it with a bottom sheet whose format picker is three bare pills, and dropped the split.
//
//  What is below takes the sheet's shape and the block's format rows, because the rows carry the
//  three subtitles — "Everyone plays for themselves", "Pairs — requested first, then by skill",
//  "Balanced teams, a coach on each" — and a pill reading "Doubles" tells somebody who has not run
//  a doubles draw before precisely nothing. Three rows cost about 130pt of a sheet that scrolls.
//
//  ── AND ONE QUESTION NEITHER OF THEM ASKS ─────────────────────────────────────────────────────
//
//  "Split into N tournaments by rank." The live design answers "which kids" only by picking courts,
//  which works when the courts happen to be the bands and not otherwise — a venue that puts fifty
//  kids on six courts cannot ask for three even draws by standard. The superseded `createTournament`
//  (`state1.js:670`) could, `Tournament.banded(…)` is the model for it, and this is where it is
//  asked. It sits *beside* the group picker rather than replacing it: the two narrow different
//  ways, "which kids are eligible" and "how many draws to cut them into", and a camp routinely
//  wants both — Groups 1 and 2, split into two.
//

import SwiftUI

struct TournamentSheet: View {

    // MARK: What comes out of it

    /// A finished answer, ready for the store.
    ///
    /// The sheet builds the `Seeding` rather than handing back its own fields, because `Seeding` is
    /// the type that makes the impossible combinations unspellable — a team count on a singles
    /// draw, requested pairs on a team draw — and assembling it here is what keeps that guarantee
    /// on the near side of the store call.
    struct Request: Hashable, Sendable {
        var seeding: Tournament.Seeding
        var courtIndices: [Int]
        var days: Int
        /// 1 for one draw, more to cut the pool into contiguous rank bands. The screen half of
        /// `Tournament.banded(_:namePrefix:ladder:into:courtIndices:days:)`.
        var splitInto: Int
    }

    // MARK: The draft

    /// Everything the sheet is holding, in one value.
    ///
    /// One `@State` rather than eight, for the reason `BlockEditorDraft` gives: a draft with eight
    /// independent properties has eight chances to be half-updated, and the two rules below —
    /// clearing a pending pick when the format changes, pruning pairs when the courts change — are
    /// each about *two* of them at once.
    struct Draft: Hashable, Sendable {
        var kind: Tournament.Kind = .singles
        var mode: Tournament.Mode = .roundRobin
        /// 0-based positions in the venue's own court order. The design seeds `[0]`.
        var courtIndices: Set<Int> = [0]
        var days: Int = 2
        var teams: Int = 2
        var splitInto: Int = 1
        var requestedPairs: [Tournament.PairRequest] = []
        /// The first half of a pair somebody is in the middle of making.
        var pendingPairA: Player.ID?
    }

    let camp: Camp
    let venue: Venue
    let onCreate: (Request) -> Void
    let onClose: () -> Void

    @State private var draft = Draft()

    // MARK: Derived

    private var courts: [Group] { camp.groups(in: venue.id) }

    /// The kids this draw would be struck from: the venue's ladder narrowed to the chosen courts.
    ///
    /// Recomputed in `body` rather than held, and deliberately: it depends on the selection and on
    /// the camp, and a stored copy is a copy that can be one tap out of date on the very number the
    /// create button prints.
    private var pool: [Player] {
        Tournament.pool(camp.players, across: courts, courtIndices: Array(draft.courtIndices))
    }

    /// The pairs that would actually be honoured — both members still inside the chosen courts.
    ///
    /// `Tournament.doublesEntrants` drops a request whose halves are not both in the pool, and it
    /// is right to. The sheet has to agree with it or the chip row will keep showing a pair that
    /// the draw will not make.
    private var livePairs: [Tournament.PairRequest] {
        let inPool = Set(pool.map(\.id))
        return draft.requestedPairs.filter { inPool.contains($0.a) && inPool.contains($0.b) }
    }

    private var pairedIDs: Set<Player.ID> {
        Set(livePairs.flatMap { [$0.a, $0.b] })
    }

    private var unpaired: [Player] {
        pool.filter { !pairedIDs.contains($0.id) }
    }

    /// Whether the doubles pairing would leave somebody over.
    ///
    /// The sheet's half of the defect the design ships. `TournamentPlan.soloNames` names the kid
    /// once the draw exists; this says it is *about* to happen, while there is still a requested
    /// pair to add or a court to include that would fix it.
    private var hasOddKid: Bool {
        draft.kind == .doubles && !unpaired.count.isMultiple(of: 2)
    }

    private var seeding: Tournament.Seeding {
        switch draft.kind {
        case .singles: .singles(draft.mode)
        case .doubles: .doubles(draft.mode, requestedPairs: livePairs)
        case .team: .team(count: draft.teams)
        }
    }

    private var canCreate: Bool { !pool.isEmpty }

    private var createTitle: String {
        guard canCreate else { return "Pick at least one group" }
        guard draft.splitInto > 1 else { return "Create · \(pool.count) kids" }
        // How many draws actually come back, which is not always what was asked for: a ladder
        // shorter than the count leaves empty bands, and `Tournament.banded` refuses to make a
        // tournament with nobody in it. Saying "Draw 5" and producing 3 would be the button lying.
        let real = Tournament.bandSizes(pool.count, into: draft.splitInto).count { $0 > 0 }
        return "Draw \(real) tournament\(real == 1 ? "" : "s") · \(pool.count) kids"
    }

    var body: some View {
        SheetChrome(
            title: "New tournament",
            subtitle: "\(venue.name) · \(pool.count) kids in",
            detentFraction: 0.92,
            onClose: onClose
        ) {
            formatSection
            groupSection
            if draft.kind != .team {
                playSection
            }
            splitSection
            counterSection
            hintLine

            if draft.kind == .doubles {
                pairSection
            }

            PrimaryButton(createTitle) {
                guard canCreate else { return }
                onCreate(
                    Request(
                        seeding: seeding,
                        courtIndices: draft.courtIndices.sorted(),
                        days: draft.days,
                        splitInto: draft.splitInto
                    )
                )
            }
            .disabled(!canCreate)
            .opacity(canCreate ? 1 : TournamentMetrics.disabledOpacity)
            .padding(.top, Spacing.gutterWide)
            .accessibilityHint(canCreate ? "" : "Choose a group first")
        }
    }

    // MARK: Format

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetFieldLabel("Format", topPadding: Spacing.large)

            Card(radius: TournamentMetrics.cardRadius) {
                ForEach(Tournament.Kind.allCases, id: \.self) { kind in
                    formatRow(kind)
                }
            }
        }
    }

    private func formatRow(_ kind: Tournament.Kind) -> some View {
        let isOn = draft.kind == kind

        return Button {
            draft.kind = kind
            // A pending first pick belongs to the doubles picker, and the picker is gone the
            // moment the format is not doubles. Left behind, it would light a chip on a picker
            // nobody can see and then pair somebody unexpectedly on the way back.
            draft.pendingPairA = nil
        } label: {
            CardRow(
                spacing: TournamentMetrics.formatGap,
                horizontalPadding: TournamentMetrics.formatPadding,
                verticalPadding: TournamentMetrics.formatPadding
            ) {
                RoundedRectangle(cornerRadius: TournamentMetrics.formatTileRadius, style: .continuous)
                    .fill(isOn ? Theme.accentTint : Theme.fill)
                    .frame(width: TournamentMetrics.formatTile, height: TournamentMetrics.formatTile)
                    .overlay {
                        Image(systemName: TournamentSheet.glyph(for: kind))
                            .font(.system(size: TournamentMetrics.formatGlyph, weight: .regular))
                            .foregroundStyle(isOn ? Theme.accentDark : Theme.inkSecondary)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(TournamentPlan.kindLabel(kind))
                        .typeStyle(TournamentType.formatTitle, color: Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(TournamentSheet.subtitle(for: kind))
                        .typeStyle(TournamentType.formatSubtitle, color: Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: TournamentMetrics.formatMark, weight: .regular))
                        .foregroundStyle(Theme.accent)
                } else {
                    Circle()
                        .strokeBorder(Theme.stroke, lineWidth: BorderWidth.input)
                        .frame(width: TournamentMetrics.formatMark, height: TournamentMetrics.formatMark)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Which groups feed it

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetFieldLabel("Groups in")

            FlowLayout(horizontalSpacing: Spacing.tight, verticalSpacing: Spacing.tight) {
                ForEach(Array(courts.enumerated()), id: \.element.id) { index, court in
                    let isOn = draft.courtIndices.contains(index)
                    let count = camp.players(inGroup: court.id).count

                    Chip(
                        "Group \(index + 1) · \(count)",
                        isSelected: isOn,
                        selectedTone: .dark,
                        metrics: .tournamentPick
                    ) {
                        toggleCourt(index)
                    }
                    .accessibilityLabel("Group \(index + 1), \(count) kids")
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
        }
    }

    /// In or out — and, on the way out, drop any requested pair that has just lost a member.
    ///
    /// Left alone, a pair whose halves are now in different pools would sit in the chip row looking
    /// honoured while `doublesEntrants` quietly ignored it. `livePairs` already filters for
    /// drawing; this is the write that makes the draft itself agree, so the chip does not come back
    /// when the court is re-added and the reader is not asked to remember which of their pairs are
    /// real.
    private func toggleCourt(_ index: Int) {
        if draft.courtIndices.contains(index) {
            draft.courtIndices.remove(index)
            let remaining = Set(
                Tournament.pool(camp.players, across: courts, courtIndices: Array(draft.courtIndices))
                    .map(\.id)
            )
            draft.requestedPairs.removeAll { !remaining.contains($0.a) || !remaining.contains($0.b) }
            if let pending = draft.pendingPairA, !remaining.contains(pending) {
                draft.pendingPairA = nil
            }
        } else {
            draft.courtIndices.insert(index)
        }
    }

    // MARK: Round robin or draw

    private var playSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetFieldLabel("Play")

            HStack(spacing: Spacing.tight) {
                ForEach(Tournament.Mode.allCases, id: \.self) { mode in
                    let isOn = draft.mode == mode

                    Chip(
                        TournamentSheet.label(for: mode),
                        isSelected: isOn,
                        selectedTone: .dark,
                        metrics: .tournamentDay
                    ) {
                        draft.mode = mode
                    }
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: The split — beyond the design

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetFieldLabel("Split by rank")

            TournamentStepper(
                value: $draft.splitInto,
                range: TournamentRules.splitRange,
                label: "Tournaments to split into"
            )

            Text(splitHint)
                .typeStyle(TournamentType.hint, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.tight)
        }
    }

    /// What the split will actually do, in the numbers it will actually do it in.
    ///
    /// The design's `tPartitionHint` (`state1.js:610-612`) writes the band sizes out — "7 · 7 · 6
    /// kids per draw" — and that is the right thing to show, because the arithmetic has a rule
    /// nobody would guess: the remainder goes to the *stronger* bands. Seeing 7 · 7 · 6 rather than
    /// 6 · 7 · 7 is how somebody learns that without being told.
    private var splitHint: String {
        guard draft.splitInto > 1 else {
            return "One draw over all \(pool.count) of them. Turn this up to cut the ladder into bands by standard."
        }
        let sizes = Tournament.bandSizes(pool.count, into: draft.splitInto).filter { $0 > 0 }
        let figures = sizes.map(String.init).joined(separator: " · ")
        let tail = switch draft.kind {
        case .singles: "kids per draw — bands by rank, top band first."
        case .doubles: "kids per draw — bands by rank, then paired inside each band."
        case .team: "kids per draw — bands by rank, each dealt into \(draft.teams) teams."
        }
        return sizes.count < draft.splitInto
            ? "\(figures) \(tail) Only \(sizes.count) will have anybody in them."
            : "\(figures) \(tail)"
    }

    // MARK: Teams and days

    private var counterSection: some View {
        HStack(alignment: .bottom, spacing: TournamentMetrics.stepperPairGap) {
            if draft.kind == .team {
                VStack(alignment: .leading, spacing: 0) {
                    SheetFieldLabel("Teams")
                    TournamentStepper(
                        value: $draft.teams,
                        range: TournamentRules.teamRange,
                        label: "Teams"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SheetFieldLabel("Days")
                TournamentStepper(
                    value: $draft.days,
                    range: TournamentRules.dayRange,
                    label: "Days"
                )
            }
        }
    }

    private var hintLine: some View {
        Text(formatHint)
            .typeStyle(TournamentType.hint, color: Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.tight)
    }

    /// `state1.js:365`, with one clause moved: the design promises the order of play "front-loads
    /// early leavers and plans around away days" on every format including team tennis, which has
    /// no order of play at all. It is said only where it is true.
    private var formatHint: String {
        switch draft.kind {
        case .team:
            "Snake draft by rank — every team gets a full spread. Coaches are assigned on the team card."
        case .singles, .doubles:
            (draft.mode == .roundRobin
                ? "Everyone plays everyone. "
                : "Seeded bracket, byes to the top ranks. ")
            + "The order of play front-loads early leavers and moves a match when somebody in it is away."
        }
    }

    // MARK: Requested pairings

    private var pairSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: TournamentMetrics.sectionLabelGap) {
                SheetFieldLabel("Requested pairings")
                Spacer(minLength: 0)
                Text("optional")
                    .typeStyle(TournamentType.sectionMeta, color: Theme.inkTertiary)
            }

            if !livePairs.isEmpty {
                FlowLayout(horizontalSpacing: Spacing.tight, verticalSpacing: Spacing.tight) {
                    ForEach(Array(livePairs.enumerated()), id: \.offset) { _, pair in
                        RequestedPairChip(
                            label: "\(shortName(pair.a)) + \(shortName(pair.b))",
                            remove: { draft.requestedPairs.removeAll { $0 == pair } }
                        )
                    }
                }
                .padding(.bottom, Spacing.small)
            }

            if hasOddKid {
                oddKidNotice
            }

            Text(pairHint)
                .typeStyle(TournamentType.hint, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Spacing.small)

            // Capped and scrolled, so a fifty-kid ladder cannot push the create button past the
            // bottom of the sheet. The design caps it at the same 150.
            ScrollView {
                FlowLayout(horizontalSpacing: Spacing.tight, verticalSpacing: Spacing.tight) {
                    ForEach(unpaired) { player in
                        let isPending = draft.pendingPairA == player.id

                        Chip(
                            shortName(player.id),
                            isSelected: isPending,
                            selectedTone: .dark,
                            metrics: .tournamentPick
                        ) {
                            pick(player.id)
                        }
                        .accessibilityAddTraits(isPending ? [.isSelected] : [])
                        .accessibilityHint(
                            isPending ? "Tap again to cancel" : "Pairs them with the next kid you tap"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: TournamentMetrics.pairPickerHeight)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var pairHint: String {
        guard let pending = draft.pendingPairA else {
            return "Tap two kids to pair them — everyone else pairs by skill."
        }
        return "Now tap \(shortName(pending))'s partner."
    }

    /// The kid who would be left over, named before the draw exists.
    ///
    /// Same wording and same amber as the card's own notice, because it is the same fact at a
    /// different moment — and at *this* moment it is still fixable, by adding a court or making one
    /// more requested pair. `Theme.warningTint`/`warningDark` measures 4.93:1; see
    /// `TournamentCard.soloNotice`.
    private var oddKidNotice: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: TournamentMetrics.matchCaret + 2, weight: .regular))
                .foregroundStyle(Theme.warningDark)
                .accessibilityHidden(true)

            Text("One kid will be left without a partner. They stay in the draw and the card will name them.")
                .typeStyle(.metaSmall, color: Theme.warningDark)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TournamentMetrics.tagPaddingHorizontal)
        .padding(.vertical, Spacing.small)
        .background(Theme.warningTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .padding(.bottom, Spacing.small)
        .accessibilityElement(children: .combine)
    }

    /// First tap arms, second tap pairs, tapping the armed kid again disarms.
    ///
    /// The picker only ever lists *unpaired* kids, which is what enforces the model's one stated
    /// precondition: `doublesEntrants` will happily enter a kid named in two requested pairs twice,
    /// and says in as many words that "the caller's pair picker is what stops it from happening".
    /// This is that picker.
    private func pick(_ id: Player.ID) {
        guard let armed = draft.pendingPairA else {
            draft.pendingPairA = id
            return
        }
        if armed == id {
            draft.pendingPairA = nil
        } else {
            draft.requestedPairs.append(Tournament.PairRequest(armed, id))
            draft.pendingPairA = nil
        }
    }

    /// "Serene C" — the same short form the cards use. See `TournamentPlan`'s own `short`.
    private func shortName(_ id: Player.ID) -> String {
        guard let player = camp.player(id) else { return "?" }
        return player.lastInitial.isEmpty
            ? player.firstName
            : "\(player.firstName) \(player.lastInitial)"
    }

    // MARK: Words

    /// Phosphor's `ph-user`, `ph-users`, `ph-users-three`, in SF Symbols.
    static func glyph(for kind: Tournament.Kind) -> String {
        switch kind {
        case .singles: "person"
        case .doubles: "person.2"
        case .team: "person.3"
        }
    }

    /// The design's three subtitles, verbatim (`state1.js:600`).
    static func subtitle(for kind: Tournament.Kind) -> String {
        switch kind {
        case .singles: "Everyone plays for themselves"
        case .doubles: "Pairs — requested first, then by skill"
        case .team: "Balanced teams, a coach on each"
        }
    }

    static func label(for mode: Tournament.Mode) -> String {
        switch mode {
        case .roundRobin: "Round robin"
        case .knockout: "Draw"
        }
    }
}

// MARK: - A requested pair

/// "Serene C + Liam P ✕" — a pair somebody asked for, and the way to take it back.
///
/// Not `Chip`, which has no trailing control and whose whole plate would be the tap target. Here
/// the plate *is* the remove button, which is what the design does (`sheet-shTourney.html:41`) and
/// is legible because the ✕ says so — but a plate that reads as a label and deletes on touch needs
/// the label spelled out for VoiceOver, which is why it does not merely combine its children.
private struct RequestedPairChip: View {
    let label: String
    let remove: () -> Void

    var body: some View {
        Button(action: remove) {
            HStack(spacing: Spacing.tight) {
                Text(label)
                    .typeStyle(.chipMedium)
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .font(.system(size: TournamentMetrics.pairChipGlyph, weight: .semibold))
                    .opacity(TournamentMetrics.pairChipGlyphOpacity)
            }
            .foregroundStyle(Theme.surface)
            .padding(.horizontal, TournamentMetrics.pairChipPaddingHorizontal)
            .padding(.vertical, Spacing.small)
            .background(Theme.ink, in: Capsule(style: .continuous))
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), requested pair")
        .accessibilityHint("Removes this pairing")
    }
}

// MARK: - Previews

/// Hoisted to file scope for the mangling reason `Components.swift:1473-1475` gives.
private struct TournamentSheetPreviewHarness: View {

    var body: some View {
        let camp = SampleData.uclaTennisCamp

        return ZStack(alignment: .bottom) {
            Theme.scrim.ignoresSafeArea()

            if let venue = camp.orderedVenues.first {
                TournamentSheet(
                    camp: camp,
                    venue: venue,
                    onCreate: { _ in },
                    onClose: {}
                )
                .frame(height: 644)
            }
        }
        .frame(height: 700)
        .background(Theme.canvas)
    }
}

#Preview("New tournament") {
    TournamentSheetPreviewHarness()
}

#Preview("New tournament — accessibility1") {
    TournamentSheetPreviewHarness()
        .environment(\.dynamicTypeSize, .accessibility1)
}
