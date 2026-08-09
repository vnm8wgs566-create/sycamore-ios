//
//  RosterReviewView.swift
//  Sycamore
//
//  `8d`, a week later: the same file read against a camp that already has kids in it.
//
//  Five sections, in the order somebody scanning this needs them:
//
//      Needs a detail       the gaps, with the same Fix button — a re-imported file has them too
//      New                  rows nobody at the camp answers to
//      Changed              rows that found their kid and disagree, field by field
//      Already here         folded to four, because this is the section that exists to be skipped
//      Not in this file     kids the file left out, offered for removal and ticked by hand
//
//  ---------------------------------------------------------------------------------------------
//  WHY THIS IS NOT `ImportReviewView` WITH A FLAG
//  ---------------------------------------------------------------------------------------------
//
//  `8d`'s own header states its contract: *"Nothing is written until the button at the bottom,
//  which is why the number is in its label: you are agreeing to a count, not pressing Done"*
//  (`ImportReviewView.swift:10-11`). Per-row tick boxes contradict that sentence — the moment a
//  row can be excluded, the count in the button is a *result* of what you ticked rather than the
//  thing you are agreeing to.
//
//  And there is nothing for `8d` to reconcile against: at onboarding the camp does not exist yet,
//  so every row is New by definition and there is no Changed bucket, no Already here, and nobody
//  to be missing from the file. Four of the five sections below cannot occur there.
//
//  Bending one view to carry both contracts gives a screen whose chrome depends on a flag —
//  ticks on or off, four sections or one, two different sentences under the same button. The two
//  screens share what is genuinely the same (`IntakeCountsCard`, `FoldedRosterSection`, the
//  needs-a-detail card's shape) and part company where they mean different things.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT STARTS TICKED, AND WHY REMOVALS DO NOT
//  ---------------------------------------------------------------------------------------------
//
//  `RosterSelection.opening(for:)` decides it and this screen only draws it: arrivals and
//  unambiguous changes ticked, **removals empty**. That empty set is the feature's founding
//  decision written down — a file is a list of who signed up, not a list of who exists, and an
//  office exporting one week's sign-ups is not saying the other forty children have left. The only
//  thing that may take a child off a roster is a person ticking a box next to their name.
//
//  Ambiguity is drawn rather than merely unticked. Where the matcher could not tell two kids
//  apart, `isAmbiguous` is true and the row carries an amber line saying so — a pre-unticked row
//  with no explanation reads as an oversight, and the reader has no way to know the difference
//  between "we are not sure" and "you have not got to this one yet".
//

import SwiftUI

struct RosterReviewView: View {

    /// The file as parsed, for the gaps and the file's own name. Reconciliation is handed in
    /// rather than computed here — see `EnrolmentFlowView`, which memoises it: one pass costs
    /// roughly `4N + 3M` `String.folding` calls, which is not a thing to do inside a `body`.
    let file: IntakeImport
    let reconciliation: RosterReconciliation
    @Binding var selection: RosterSelection
    /// Opens `8e` on one row, prefilled, to supply what the file was missing.
    let onFix: (IntakePlayer) -> Void
    /// Writes everything ticked. The count in the button's label is what is being agreed to.
    let onApply: () -> Void
    /// Greys the button while the three writes are in flight.
    var isApplying: Bool = false

    @Environment(\.dismiss) private var dismiss

    /// The row glyph on a tick box. Scaled so the box keeps its proportion to the name beside it.
    @ScaledMetric(relativeTo: .body) private var tickSize: CGFloat = 19

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            // The file's own name as the title, not its player count. On a re-import "did I pick
            // last week's file?" is a real question and the only thing on the screen that answers
            // it; the counts are one line below and in the card under that.
            IntakeHeader(
                title: file.fileName,
                subtitle: reconciliation.summary,
                backLabel: "Players",
                onBack: { dismiss() }
            )

            Hairline(color: Theme.hairline)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { applyButton }
        .navigationBarBackButtonHidden(true)
        .hidesNavigationBar()
    }

    // MARK: - Content

    private var content: some View {
        // Bound once. `needsDetail` is a computed `filter` whose predicate walks
        // `IntakePlayer.issue`, which counts a surname's unicode scalars — and it was read three
        // times per pass through this body, over every row in the file.
        let gaps = file.needsDetail

        return ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                countsCard

                if !gaps.isEmpty {
                    NeedsDetailSection(rows: gaps, onFix: onFix)
                        .padding(.top, 4)
                }

                arrivingSection
                changedSection

                if !reconciliation.alreadyHere.isEmpty {
                    alreadyHereSection
                        .padding(.top, Spacing.tight)
                }

                absentSection
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            // Clears the pinned button, which floats over this rather than sitting under it.
            .padding(.bottom, OnboardingMetrics.ctaClearance)
        }
    }

    /// The three tickable buckets, which is what makes this card a different card from `8d`'s.
    /// "Already here" is deliberately absent: it is the one section nothing is decided about, and
    /// a figure for it in this row would invite the reader to look for a control that is not there.
    private var countsCard: some View {
        IntakeCountsCard([
            .init("New", reconciliation.arriving.count),
            .init("Changed", reconciliation.changed.count),
            .init("Not in this file", reconciliation.absent.count),
        ])
    }

    // MARK: - The three tickable sections

    /// One section of tickable rows: a header carrying its own count, an optional note, and a card
    /// of rows.
    ///
    /// Written once because the three of them differ in five values and nothing else. The
    /// alternative was three near-identical `VStack(header + Card(ForEach(tickRow)))` blocks, in
    /// which "what a tick in *this* section writes" is spread across a `contains`, a `toggle` and
    /// a `tone` sixty lines apart — three places for two of them to agree and the third not to.
    ///
    /// - Parameter ticks: which set in the selection this section writes. A `WritableKeyPath`
    ///   rather than a getter/setter pair, so the read and the write cannot name different sets.
    ///   All three id types erase to `UUID` — which `RosterSelection`'s own header warns about —
    ///   so the compiler will not catch a wrong keypath here; the three call sites are three lines
    ///   apart and each names its bucket and its keypath on adjacent lines, which is the mitigation.
    /// - Parameter note: shown between the header and the card. Only "Not in this file" has one,
    ///   and it is a `String?` rather than a builder because a section that wanted a *different*
    ///   kind of note would be a section that is not this shape.
    /// - Parameter line: the three strings a row draws, read off whatever the bucket holds.
    @ViewBuilder
    private func tickSection<Row: Identifiable>(
        _ title: String,
        rows: [Row],
        ticks: WritableKeyPath<RosterSelection, Set<Row.ID>>,
        tone: TickTone = .addition,
        note: String? = nil,
        hint: String,
        // `@escaping` because `ForEach`'s content closure is: the row builder outlives this call.
        line: @escaping (Row) -> (title: String, detail: String, caution: String?)
    ) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                IntakeSectionHeader(
                    "\(title) · \(rows.count)",
                    trackingEm: 0.14,
                    horizontalPadding: 4,
                    bottomPadding: 0
                )
                .padding(.top, 4)

                if let note { IntakeNote(note) }

                Card(radius: OnboardingMetrics.cardRadius) {
                    ForEach(rows) { entry in
                        let text = line(entry)
                        tickRow(
                            isTicked: selection[keyPath: ticks].contains(entry.id),
                            title: text.title,
                            detail: text.detail,
                            caution: text.caution,
                            tone: tone,
                            hint: hint
                        ) {
                            selection[keyPath: ticks].toggle(entry.id)
                        }
                    }
                }
            }
        }
    }

    private var arrivingSection: some View {
        tickSection(
            "New",
            rows: reconciliation.arriving,
            ticks: \.arriving,
            hint: "Adds this kid to the camp"
        ) { arrival in
            (arrival.row.displayName, arrival.row.detail, nil)
        }
    }

    private var changedSection: some View {
        tickSection(
            "Changed",
            rows: reconciliation.changed,
            ticks: \.changed,
            hint: "Writes the file's version over what the camp holds"
        ) { change in
            (
                change.player.displayName,
                Self.changeLine(change.fields),
                change.isAmbiguous ? Self.ambiguousNote : nil
            )
        }
    }

    /// Nothing here is ticked to start with, so the note has to say what ticking one *does* before
    /// the reader ticks it. The alternative — finding out at the button — is the one place on this
    /// screen where an undo does not exist.
    private var absentSection: some View {
        tickSection(
            "Not in this file",
            rows: reconciliation.absent,
            ticks: \.removing,
            tone: .removal,
            note: "These kids stay in the camp unless you tick them. Ticking takes them off the roster.",
            hint: "Takes this kid off the roster"
        ) { absence in
            (
                absence.player.displayName,
                absence.player.metaLine,
                absence.isAmbiguous ? Self.ambiguousNote : nil
            )
        }
    }

    /// `12 years → 13 years · F → M`. The words are `FieldChange`'s own, built beside the patch
    /// that a commit writes — so the line the reader agrees to and the value that lands cannot
    /// come apart.
    ///
    /// An arrow rather than "was/now": at a glance down a column of rows the arrow is the shape
    /// that reads as a change, and it survives being truncated in a way a sentence does not.
    private static func changeLine(_ fields: [RosterReconciliation.FieldChange]) -> String {
        fields.map { "\($0.before) → \($0.after)" }.joined(separator: " · ")
    }

    /// Why an entry starts unticked. Said out loud rather than left as an absence — a row that is
    /// simply not ticked reads as one the reader has not reached yet.
    private static let ambiguousNote = "Two kids here share a name — check this is the right one"

    // MARK: - Already here

    /// Folded to four through the same section `8d` folds its clean rows with. This is the bucket
    /// that exists to be *not* read: it is the answer to "did the rest come across?", which is a
    /// number rather than a list.
    private var alreadyHereSection: some View {
        FoldedRosterSection(
            title: "Already here · \(reconciliation.alreadyHere.count)",
            rows: reconciliation.alreadyHere
        ) { match in
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(match.player.displayName)
                        .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                    Text(match.player.metaLine)
                        .typeStyle(.intakeRowDetail, color: Theme.inkMuted)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - A tickable row

    /// What a tick in this row means, which is the only thing that changes between the three
    /// tickable sections. Additive rows tick accent-green; a removal ticks in the danger red the
    /// app already uses for "this takes something away".
    private enum TickTone {
        case addition
        case removal

        var color: Color {
            switch self {
            case .addition: Theme.accent
            case .removal: Theme.danger
            }
        }
    }

    /// A name, a grey line under it, an optional amber caution, and a box on the trailing edge.
    ///
    /// The **whole row** takes the tap rather than the box, which is the same call the Fix row
    /// makes above: a 19pt box is not something to aim at standing on a court, and there is
    /// nothing else on the row that could want the tap.
    ///
    /// Spoken as a toggle rather than as a button. VoiceOver reads "Serene Chu, 12 years, ticked,
    /// toggle" and the rotor's adjust gesture works on it, so the list is checkable without sight
    /// of the boxes.
    private func tickRow(
        isTicked: Bool,
        title: String,
        detail: String,
        caution: String? = nil,
        tone: TickTone = .addition,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                    Text(detail)
                        .typeStyle(.intakeRowDetail, color: Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let caution {
                        Text(caution)
                            .typeStyle(.intakeRowDetail, color: Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: tickSize, weight: .regular))
                    .foregroundStyle(isTicked ? tone.color : Theme.inkGhost)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isTicked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, detail, caution].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(isTicked ? "Ticked" : "Not ticked")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(hint)
    }

    // MARK: - Apply

    /// How many rows are actually going to be written.
    ///
    /// Counted off the reconciliation rather than off `selection.count`, for the reason
    /// `RosterReconciliation.commit(_:)` reads back off the buckets: an id in the selection that
    /// no bucket holds writes nothing, and a label that counted it would promise a write that is
    /// not going to happen. Three counted walks and no allocation, so it is cheap enough to sit in
    /// a `body`.
    private var tickedCount: Int {
        reconciliation.arriving.count { selection.arriving.contains($0.id) }
            + reconciliation.changed.count { selection.changed.contains($0.id) }
            + reconciliation.absent.count { selection.removing.contains($0.id) }
    }

    /// The number is in the label, exactly as `8d` puts it there: you are agreeing to a count.
    /// With nothing ticked the button says so rather than reading "Apply 0 changes", which is a
    /// sentence that invites a tap.
    private func applyTitle(_ ticked: Int) -> String {
        guard ticked > 0 else { return "Nothing ticked" }
        return "Apply \(ticked) change\(ticked == 1 ? "" : "s")"
    }

    private var applyButton: some View {
        // Counted once and spent three times — the guard, the label and the interpolation each
        // used to run all three walks again.
        let ticked = tickedCount
        let isDisabled = isApplying || ticked == 0

        return PrimaryButton(
            applyTitle(ticked),
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButtonLg,
            action: onApply
        )
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
        .shadow(OnboardingShadows.pinnedCTA)
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, OnboardingMetrics.ctaInset)
    }
}

// MARK: - Previews

/// A file read against a camp that already holds most of it: two arrivals, one corrected age, one
/// surname filled in, and two kids the file left out.
@MainActor
private struct RosterReviewPreview: View {

    @State private var selection: RosterSelection

    private let file: IntakeImport
    private let reconciliation: RosterReconciliation

    init() {
        let camp = Array(SampleData.uclaTennisCamp.orderedPlayers.prefix(6))
        // The first four come back, the middle one a year older; the last two do not.
        var rows = camp.prefix(4).map {
            IntakePlayer(
                firstName: $0.firstName,
                lastName: $0.lastName ?? "",
                age: $0.age,
                gender: $0.gender
            )
        }
        if !rows.isEmpty { rows[1].age = (rows[1].age ?? 11) + 1 }
        rows.append(IntakePlayer(firstName: "Nina", lastName: "Alvarez", age: 12, gender: .f))
        rows.append(IntakePlayer(firstName: "Rafe", lastName: "Osei", age: nil, gender: .m))

        let file = IntakeImport(fileName: "week-3-signups.csv", players: rows)
        let reconciliation = RosterReconciliation(file: rows, camp: camp)

        self.file = file
        self.reconciliation = reconciliation
        _selection = State(initialValue: .opening(for: reconciliation))
    }

    var body: some View {
        NavigationStack {
            RosterReviewView(
                file: file,
                reconciliation: reconciliation,
                selection: $selection,
                onFix: { _ in },
                onApply: {}
            )
        }
    }
}

#Preview("Check the changes") {
    RosterReviewPreview()
        .showsMockStatusBar()
}

#Preview("Check the changes — large type") {
    RosterReviewPreview()
        .dynamicTypeSize(.accessibility1)
}
