//
//  TournamentScoreSheet.swift
//  Sycamore
//
//  "Who took it?" — two numbers, and the one rule about them.
//
//  ── THE TIE IS REFUSED HERE, ON PURPOSE, AND SAID OUT LOUD ────────────────────────────────────
//
//  Three layers all disallow an equal score and only one of them can explain itself.
//
//  * `tournament_matches_no_draw` is a CHECK on the table. It rejects the write, and what comes
//    back is a constraint violation — a string with a constraint name in it, which is not a
//    sentence anybody scoring a match on a Tuesday morning should ever be shown.
//  * `Tournament.winner(of:)` has to answer *something* for a 6–6, and it answers "B" — the
//    design's own rule (`state1.js:797`, `sc[0] > sc[1] ? A : B`), transcribed rather than
//    corrected. So a tie that reached the model would silently hand the match to whoever happened
//    to be on the right.
//  * The design's own sheet returns early (`:381`, `if (sa === sb) return;`) behind a button at
//    45% opacity. It stops the write and says nothing about why.
//
//  So this sheet refuses it *before* anything is called: the button is genuinely `.disabled`, its
//  label says what is wrong, and a line under it says why in words. That is the only one of the
//  three layers that can — the CHECK is a backstop for a client that got here another way, and the
//  model's rule is a total function's obligation, not a policy.
//
//  ── AND CLEARING IS A SEPARATE THING FROM SAVING ──────────────────────────────────────────────
//
//  `setScore(nil, …)` is how a score is taken back off a match — a mis-tap on a bracket, a set
//  replayed. It is drawn as the design draws it: a quiet destructive line under the button rather
//  than a third stepper state, because "no score" is not a score of nothing.
//

import SwiftUI

struct TournamentScoreSheet: View {

    /// Which fixture, in which draw. Carried as ids rather than as the match, because the sheet
    /// outlives a reload: the store re-reads the tournament after every write, and a copy of the
    /// match held here would be the one from before the last one.
    struct Target: Identifiable, Hashable, Sendable {
        var tournamentID: Tournament.ID
        var tournamentName: String
        var matchID: Tournament.Match.ID
        /// "M7" — what the card and the bracket both call it.
        var number: String
        var aName: String
        var bName: String
        var existing: Tournament.Score?

        var id: String { "\(tournamentID.uuidString)-\(matchID)" }
    }

    let target: Target
    let onSave: (Tournament.Score) -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    @State private var a: Int
    @State private var b: Int

    init(
        target: Target,
        onSave: @escaping (Tournament.Score) -> Void,
        onClear: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.target = target
        self.onSave = onSave
        self.onClear = onClear
        self.onClose = onClose
        // Seeded from whatever is already recorded, so re-opening a scored match shows the score
        // rather than 0–0 — which would read as the sheet having lost it.
        _a = State(initialValue: target.existing?.a ?? 0)
        _b = State(initialValue: target.existing?.b ?? 0)
    }

    private var isTie: Bool { a == b }
    private var leaderName: String { a > b ? target.aName : target.bName }

    /// "Save · Serene C takes it 6–4". An en dash, and the higher figure first however the two
    /// steppers happen to be set.
    private var saveTitle: String {
        isTie ? "Scores can't tie" : "Save · \(leaderName) takes it \(max(a, b))–\(min(a, b))"
    }

    var body: some View {
        SheetChrome(
            title: "Who took it?",
            subtitle: "\(target.tournamentName) · \(target.number)",
            detentFraction: 0.52,
            onClose: onClose
        ) {
            HStack(alignment: .top, spacing: TournamentMetrics.scorePlateGap) {
                plate(name: target.aName, value: $a, isLeading: a > b)
                plate(name: target.bName, value: $b, isLeading: b > a)
            }
            .padding(.top, Spacing.gutterWide)

            PrimaryButton(saveTitle) {
                guard !isTie else { return }
                onSave(Tournament.Score(a, b))
            }
            .disabled(isTie)
            .opacity(isTie ? TournamentMetrics.disabledOpacity : 1)
            .padding(.top, Spacing.medium)
            .accessibilityHint(isTie ? tieReason : "")

            if isTie {
                // The half the design leaves out. A greyed button says "not now"; this says why,
                // and it is on screen from the moment the sheet opens at 0–0 rather than appearing
                // as a reaction — so it reads as the rule it is rather than as an error somebody
                // just caused.
                Text(tieReason)
                    .typeStyle(TournamentType.hint, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.small)
            }

            if target.existing != nil {
                Button(role: .destructive, action: onClear) {
                    Text("Clear this score")
                        .typeStyle(.buttonCompact, color: Theme.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: HitTarget.minimum)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.tight)
                .accessibilityHint("Puts the match back to unplayed")
            }
        }
    }

    private var tieReason: String {
        "A match has to have a winner — the draw carries whoever won it into the next round."
    }

    /// One side: the name, and the games it took.
    ///
    /// The plate goes green while that side is ahead, which is the design's whole feedback for
    /// "who is this sheet about to record as the winner" — and it is why the button's own label
    /// names them too. Colour alone would leave a reader who cannot see it with two identical
    /// plates.
    private func plate(name: String, value: Binding<Int>, isLeading: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: TournamentMetrics.scorePlateRadius, style: .continuous)

        return VStack(alignment: .leading, spacing: TournamentMetrics.scoreStepperGap) {
            Text(name)
                .typeStyle(TournamentType.scoreName, color: isLeading ? Theme.accentDark : Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            TournamentStepper(
                value: value,
                range: TournamentRules.scoreRange,
                label: "Games to \(name)",
                buttonSize: TournamentMetrics.scoreStepperButton,
                buttonRadius: TournamentMetrics.scoreStepperRadius,
                glyphSize: TournamentMetrics.scoreStepperGlyph,
                valueStyle: TournamentType.scoreValue
            )
        }
        .padding(.horizontal, TournamentMetrics.scorePlatePaddingHorizontal)
        .padding(.vertical, TournamentMetrics.scorePlatePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isLeading {
                shape.fill(Theme.accentSurface)
            }
        }
        .overlay {
            shape.strokeBorder(
                isLeading ? Theme.accentBorder : Theme.stroke,
                lineWidth: BorderWidth.input
            )
        }
    }
}

// MARK: - Previews

#Preview("Score sheet") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()

        TournamentScoreSheet(
            target: .init(
                tournamentID: UUID(),
                tournamentName: "Tournament 1",
                matchID: "m3",
                number: "M3",
                aName: "Serene C + Liam P",
                bName: "Austin Z + Mia K",
                existing: Tournament.Score(6, 4)
            ),
            onSave: { _ in },
            onClear: {},
            onClose: {}
        )
        .frame(height: 380)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Score sheet — a tie is refused") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()

        TournamentScoreSheet(
            target: .init(
                tournamentID: UUID(),
                tournamentName: "Tournament 2",
                matchID: "m1",
                number: "M1",
                aName: "Noor H",
                bName: "Theo V",
                existing: nil
            ),
            onSave: { _ in },
            onClear: {},
            onClose: {}
        )
        .frame(height: 380)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Score sheet — accessibility1") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()

        TournamentScoreSheet(
            target: .init(
                tournamentID: UUID(),
                tournamentName: "Tournament 1",
                matchID: "m3",
                number: "M3",
                aName: "Serene C",
                bName: "Austin Z",
                existing: Tournament.Score(6, 4)
            ),
            onSave: { _ in },
            onClear: {},
            onClose: {}
        )
        .frame(height: 640)
    }
    .frame(height: 700)
    .background(Theme.canvas)
    .environment(\.dynamicTypeSize, .accessibility1)
}
