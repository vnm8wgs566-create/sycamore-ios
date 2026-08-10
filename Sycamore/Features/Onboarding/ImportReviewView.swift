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
    /// The venues this file's rows will be dealt across, each carrying the ages it takes.
    ///
    /// Empty at onboarding, which is every caller today: the camp is written at the *end* of that
    /// flow, so while this screen is up there are no venues — only `8b`'s sketch, which has no band
    /// to sketch (`Venue.ageBand` defaults to `.all` and `VenueShape` carries no control for it).
    /// Empty means nothing is asking, and `RosterAgeFit` then places every row.
    ///
    /// Carried anyway rather than left out, because the *screen's* promise does not depend on which
    /// flow reached it: "nothing is written until the button at the bottom" is only kept if what
    /// the button will do is visible before it is pressed. The day a venue can be narrowed before
    /// the first import, this draws without being reopened.
    var venues: [RosterVenue] = []
    /// Opens `8e` on one row, prefilled, to supply what the file was missing.
    let onFix: (IntakePlayer) -> Void
    let onCommit: () -> Void
    /// Nil while the camp is being written, which is also what greys the button.
    var isCommitting: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
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
        .hidesNavigationBar()
    }

    // MARK: Content

    private var content: some View {
        // Both partitions bound once. Each is a computed `filter` whose predicate walks
        // `IntakePlayer.issue` — which counts a surname's unicode scalars — and between them they
        // were read seven times per pass through this body, over forty rows.
        let gaps = file.needsDetail
        let clean = file.readCleanly
        // Every row in the file, because this screen imports all of them — there are no ticks here
        // (see the header). Bound once for the note and the row cautions both.
        let fit = RosterAgeFit(file.players, venues: venues)
        let cautions = Dictionary(
            fit.unplaced.map { ($0.id, fit.reason(for: $0)) }, uniquingKeysWith: { _, last in last }
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                countsCard

                // Above the rows, because it is a fact about the whole import and the button at the
                // foot is the thing it qualifies. Drawn only when a venue actually turned somebody
                // away — an explanation of a rule nobody has met is noise on a screen whose job is
                // to be scanned.
                if !fit.isEverybodyPlaced {
                    IntakeNote(fit.outcomeLine)
                }

                if !gaps.isEmpty {
                    NeedsDetailSection(rows: gaps, onFix: onFix)
                        .padding(.top, 4)
                }

                if !clean.isEmpty {
                    cleanSection(clean, cautions: cautions)
                        .padding(.top, Spacing.tight)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            // Clears the pinned button, which floats over this rather than sitting under it.
            .padding(.bottom, OnboardingMetrics.ctaClearance)
        }
    }

    // MARK: Counts

    /// Grey on RANKED, because zero there is the plan rather than a shortfall.
    private var countsCard: some View {
        IntakeCountsCard([
            .init("New", file.newCount),
            .init("Returning", file.returningCount),
            .init("Ranked", file.rankedCount, color: Theme.inkFaint),
        ])
    }

    // MARK: Clean

    /// The fold, the "See all" and the four-row default are `FoldedRosterSection`'s — the same
    /// rule `RosterReviewView` folds "Already here" by. Only the row is this screen's.
    private func cleanSection(
        _ rows: [IntakePlayer], cautions: [IntakePlayer.ID: String]
    ) -> some View {
        FoldedRosterSection(title: "Read cleanly · \(rows.count)", rows: rows) { player in
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.displayName)
                        .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                    Text(player.detail)
                        .typeStyle(.intakeRowDetail, color: Theme.inkMuted)

                    // A row that read cleanly can still be one no venue will take — a perfectly
                    // legible 14-year-old at an 11-and-under camp. Drawn in the amber the review
                    // screens already use for "something about this row you should know", and
                    // allowed to wrap: the reason is the whole content of the line.
                    if let caution = cautions[player.id] {
                        Text(caution)
                            .typeStyle(.intakeRowDetail, color: Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                // The design's own glyph, drawn rather than lettered. SF Symbols still has no
                // gender set — that has not changed — but the letter that stood in for it read as
                // a redaction on the one row it mattered most on, `X` beside a name the file
                // already failed to describe. `GenderMark` draws all three, `.x` included, and
                // takes `glyph` — the grey the design gives its icons, a step lighter than its
                // text.
                //
                // `alongside: .intakeGlyphLetter` so the mark grows at the rate the letter did:
                // this row sets it at 13, not the 12 the rest of the app draws marks at.
                if let gender = player.gender {
                    GenderMark(gender, alongside: .intakeGlyphLetter)
                }
            }
            // Name, age and gender are one kid, not three announcements.
            .accessibilityElement(children: .combine)
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
