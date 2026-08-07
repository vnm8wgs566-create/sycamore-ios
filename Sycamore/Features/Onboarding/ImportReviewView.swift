//
//  ImportReviewView.swift
//  Sycamore
//
//  `8d` — Check the import. Everything lands unranked; only the gaps ask for you.
//
//  The screen is ordered by what needs a person: the counts, then the rows the file left a
//  detail out of, then — folded to four — the rows that read cleanly. Nothing is written until
//  the button at the bottom, which is why the number is in its label: you are agreeing to a
//  count, not pressing Done.
//
//  RANKED reads 0 and always will. An import ranks nobody; the first sort does. Saying so on
//  the review screen is what stops somebody hunting for the rank column in their spreadsheet.
//

import SwiftUI

struct ImportReviewView: View {

    let file: IntakeImport
    /// Opens `8e` on one row, prefilled, to supply what the file was missing.
    let onFix: (IntakePlayer) -> Void
    let onCommit: () -> Void
    /// Nil while the camp is being written, which is also what greys the button.
    var isCommitting: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The design folds the clean list to four rows behind "See all". Forty names is not a list
    /// anybody reads — it is a number, and the number is already at the top.
    @State private var showsEveryCleanRow = false

    private static let foldedRowCount = 4

    private var cleanRows: [IntakePlayer] {
        let clean = file.readCleanly
        guard !showsEveryCleanRow else { return clean }
        return Array(clean.prefix(Self.foldedRowCount))
    }

    var body: some View {
        let screen = VStack(spacing: 0) {
            StatusBarMock()

            IntakeHeader(
                title: file.title,
                subtitle: file.subtitle,
                backLabel: "Players",
                onBack: { dismiss() }
            )

            Hairline(color: Theme.hairline)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { commitButton }
        .navigationBarBackButtonHidden(true)

        #if os(iOS)
        return screen.toolbar(.hidden, for: .navigationBar)
        #else
        return screen
        #endif
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                countsCard

                if !file.needsDetail.isEmpty {
                    IntakeSectionHeader(
                        "Needs a detail · \(file.needsDetail.count)",
                        trackingEm: 0.14,
                        horizontalPadding: 4,
                        bottomPadding: 0
                    )
                    .padding(.top, 4)

                    needsDetailCard
                }

                if !file.readCleanly.isEmpty {
                    IntakeSectionHeader(
                        "Read cleanly · \(file.readCleanly.count)",
                        trackingEm: 0.14,
                        actionTitle: seeAllTitle,
                        horizontalPadding: 4,
                        bottomPadding: 0,
                        action: toggleCleanRows
                    )
                    .padding(.top, Spacing.tight)

                    cleanCard
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            // Clears the pinned button, which floats over this rather than sitting under it.
            .padding(.bottom, OnboardingMetrics.ctaClearance)
        }
    }

    /// Thirty-six rows arriving at once is a jump wherever it happens; the fade is what says they
    /// were already there. Off when the reader has asked for less movement.
    private func toggleCleanRows() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            showsEveryCleanRow.toggle()
        }
    }

    /// Nil when the whole clean list already fits — a control that does nothing is worse than
    /// no control.
    private var seeAllTitle: String? {
        guard file.readCleanly.count > Self.foldedRowCount else { return nil }
        return showsEveryCleanRow ? "See fewer" : "See all"
    }

    // MARK: Counts

    private var countsCard: some View {
        Card(radius: OnboardingMetrics.cardRadius, isDivided: false) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                count("New", file.newCount)
                count("Returning", file.returningCount)
                // Grey, because zero here is the plan rather than a shortfall.
                count("Ranked", file.rankedCount, color: Theme.inkFaint)
            }
            .padding(Spacing.gutterWide)
        }
    }

    private func count(_ label: String, _ value: Int, color: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .typeStyle(.intakeStatLabel, color: Theme.inkFaint)
            Text("\(value)")
                .typeStyle(.intakeStatValue, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
    }

    // MARK: Gaps

    private var needsDetailCard: some View {
        Card(radius: OnboardingMetrics.cardRadius, borderColor: Theme.warningBorder) {
            ForEach(file.needsDetail) { player in
                Button { onFix(player) } label: {
                    CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.displayName)
                                .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                            Text(player.issue?.label ?? "")
                                .typeStyle(.intakeRowDetail, color: Theme.warning)
                        }

                        Spacer(minLength: 0)

                        // The chip is the affordance the design draws, but the whole row is what
                        // takes the tap — a 24pt chip is not something to aim at on a court.
                        Text("Fix")
                            .typeStyle(.intakeChipSm, color: Theme.warningDark)
                            .padding(.horizontal, Spacing.row)
                            .padding(.vertical, Spacing.tight)
                            .background(Theme.warningTint, in: Capsule(style: .continuous))
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Fills in what the file left out")
            }
        }
    }

    // MARK: Clean

    private var cleanCard: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            ForEach(cleanRows) { player in
                CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.displayName)
                            .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                        Text(player.detail)
                            .typeStyle(.intakeRowDetail, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)

                    // The design's own glyph, drawn rather than lettered. SF Symbols still has no
                    // gender set — that has not changed — but the letter that stood in for it
                    // read as a redaction on the one row it mattered most on, `X` beside a name
                    // the file already failed to describe. `GenderMark` draws all three, `.x`
                    // included, and takes `glyph` — the grey the design gives its icons, a step
                    // lighter than its text.
                    //
                    // `alongside: .intakeGlyphLetter` so the mark grows at the rate the letter
                    // did: this row sets it at 13, not the 12 the rest of the app draws marks at.
                    if let gender = player.gender {
                        GenderMark(gender, alongside: .intakeGlyphLetter)
                    }
                }
                // Name, age and gender are one kid, not three announcements.
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Commit

    private var commitButton: some View {
        PrimaryButton(
            "Import \(file.title)",
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButtonLg,
            action: onCommit
        )
        .opacity(isCommitting ? 0.45 : 1)
        .disabled(isCommitting)
        .shadow(OnboardingShadows.pinnedCTA)
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, OnboardingMetrics.ctaInset)
    }
}

// MARK: - Previews

#Preview("Check the import") {
    NavigationStack {
        ImportReviewView(file: .preview, onFix: { _ in }, onCommit: {})
    }
    .showsMockStatusBar()
}

#Preview("Check the import — nothing missing") {
    var file = IntakeImport.preview
    file.players.removeAll { $0.issue != nil }

    return NavigationStack {
        ImportReviewView(file: file, onFix: { _ in }, onCommit: {})
    }
    .showsMockStatusBar()
}
