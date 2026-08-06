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
        .background(Theme.grouped)
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
            VStack(alignment: .leading, spacing: 9) {
                countsCard

                if !file.needsDetail.isEmpty {
                    SectionHeader("Needs a detail · \(file.needsDetail.count)")
                        .padding(.top, 4)
                    needsDetailCard
                }

                if !file.readCleanly.isEmpty {
                    SectionHeader(
                        "Read cleanly · \(file.readCleanly.count)",
                        actionTitle: seeAllTitle,
                        action: seeAllTitle == nil ? nil : { showsEveryCleanRow.toggle() }
                    )
                    .padding(.top, Spacing.tight)

                    cleanCard
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            // Clears the pinned button, which floats over this rather than sitting under it.
            .padding(.bottom, Spacing.tabBarClearance)
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
        Card(isDivided: false) {
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
                .typeStyle(.statLabel, color: Theme.inkFaint)
            Text("\(value)")
                .typeStyle(.venueHeading, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Gaps

    private var needsDetailCard: some View {
        Card(borderColor: OnboardingTheme.warningBorder) {
            ForEach(file.needsDetail) { player in
                Button { onFix(player) } label: {
                    CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.displayName)
                                .typeStyle(.bodyStrong, color: Theme.ink)
                            Text(player.issue?.label ?? "")
                                .typeStyle(.rowSubtitle, color: OnboardingTheme.warning)
                        }

                        Spacer(minLength: 0)

                        Text("Fix")
                            .typeStyle(.chipCompact, color: OnboardingTheme.warningStrong)
                            .padding(.horizontal, Spacing.row)
                            .padding(.vertical, Spacing.tight)
                            .background(OnboardingTheme.warningTint, in: Capsule(style: .continuous))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Fills in what the file left out")
            }
        }
    }

    // MARK: Clean

    private var cleanCard: some View {
        Card {
            ForEach(cleanRows) { player in
                CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 11) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.displayName)
                            .typeStyle(.bodyStrong, color: Theme.ink)
                        Text(player.detail)
                            .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)

                    // SF Symbols has no gender glyph to stand in for the design's, and the app
                    // already writes gender as the single letter `Player.metaLine` uses. Same
                    // letter, same grey.
                    if let gender = player.gender {
                        Text(gender.symbol)
                            .typeStyle(.metaSmall, color: Theme.inkGhost)
                            .accessibilityLabel(gender.intakeLabel)
                    }
                }
            }
        }
    }

    // MARK: Commit

    private var commitButton: some View {
        PrimaryButton("Import \(file.title)", height: 52, font: .button, action: onCommit)
            .opacity(isCommitting ? 0.45 : 1)
            .disabled(isCommitting)
            .shadow(OnboardingShadows.pinnedCTA)
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, 20)
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
