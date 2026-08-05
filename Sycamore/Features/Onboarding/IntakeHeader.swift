//
//  IntakeHeader.swift
//  Sycamore
//
//  The white block at the top of `8c`, `8d` and `8e`: an optional way back, a title, and one
//  grey line saying where the screen stands.
//
//  `ScreenHeader` is the tab version of this and cannot serve here — it ends in the avatar,
//  which is a tab's route to Profile, and these three screens are a stack rather than a tab.
//  What they need instead is the caret and the "Players" label the design draws above the title
//  on `8d` and `8e`. Fold the two together if a third caller ever wants both.
//

import SwiftUI

struct IntakeHeader<Trailing: View>: View {

    let title: String
    let subtitle: String
    /// The grey word beside the back caret — "Players". Nil draws no back row at all, which is
    /// what the root of the flow wants.
    var backLabel: String?
    var onBack: (() -> Void)?
    /// `8c`'s way out of the flow. Sits on the title's baseline, where a tab header puts the
    /// avatar.
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        subtitle: String,
        backLabel: String? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backLabel = backLabel
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let backLabel {
                backRow(backLabel)
                    // The caret's 44pt tap frame already carries 12pt below the 20pt glyph, so
                    // the gap the design draws is 2 here plus that. Same trick above the row.
                    .padding(.bottom, Spacing.hairGap)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(title)
                    .typeStyle(.tabTitle, color: Theme.ink)
                Spacer(minLength: Spacing.small)
                trailing
            }

            Text(subtitle)
                .typeStyle(.sheetSubtitle, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.header)
        // 20 above the title on the root screen, 14 above the back row on the two pushed ones —
        // less the 12 the caret's tap frame already contributes.
        .padding(.top, backLabel == nil ? 20 : Spacing.hairGap)
        .padding(.bottom, 18)
        .background(Theme.surface)
    }

    private func backRow(_ label: String) -> some View {
        HStack(spacing: Spacing.medium) {
            Button { onBack?() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.inkSecondary)
                    // The caret is drawn at 20 and the row is 20 tall; only the frame that
                    // takes the tap grows to the 44pt minimum.
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to \(label)")

            Text(label)
                .typeStyle(.sheetSubtitle, color: Theme.inkMuted)

            Spacer(minLength: 0)
        }
    }
}

extension IntakeHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, backLabel: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, backLabel: backLabel, onBack: onBack) {
            EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("Intake header") {
    VStack(spacing: Spacing.large) {
        IntakeHeader(title: "Players", subtitle: "Nobody added yet · Venue 1") {
            Button("Open the camp") {}
                .typeStyle(.chipMedium, color: Theme.accent)
        }

        IntakeHeader(
            title: "42 players",
            subtitle: "From sign-ups.csv · 2 need a detail",
            backLabel: "Players",
            onBack: {}
        )

        Spacer()
    }
    .background(Theme.grouped)
}
