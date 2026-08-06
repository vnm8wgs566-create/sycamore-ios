//
//  IntakeHeader.swift
//  Sycamore
//
//  The white block at the top of `8c`, `8d` and `8e`: an optional way back, a serif title, and
//  one grey line saying where the screen stands.
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

    /// The design's `font-size:20px` caret. Scaled so it keeps its place beside copy that grows.
    @ScaledMetric(relativeTo: .body) private var caretSize: CGFloat = 20

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
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                IntakeTitle(title, style: .intakeTitleSm)
                Spacer(minLength: Spacing.small)
                trailing
            }
            // `margin-top:14px` above the title on the two pushed screens; the root has no back
            // row for it to clear.
            .padding(.top, backLabel == nil ? 0 : Spacing.gutterWide)

            Text(subtitle)
                .typeStyle(.intakeSubtitle, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.header)
        // `padding:20px 22px 18px` on the root screen, `14px 22px 18px` on the pushed ones.
        .padding(.top, backLabel == nil ? 20 : Spacing.gutterWide)
        .padding(.bottom, 18)
        .background(Theme.surface)
    }

    private func backRow(_ label: String) -> some View {
        HStack(spacing: Spacing.medium) {
            Button { onBack?() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: caretSize, weight: .regular))
                    .foregroundStyle(Theme.inkSecondary)
                    // Drawn at 20; only what takes the touch grows to the 44pt minimum, so the
                    // row keeps the height the design gives it.
                    .intakeTouchTarget(inset: Spacing.medium)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to \(label)")

            Text(label)
                .typeStyle(.intakeSubtitleSm, color: Theme.inkMuted)

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
            Text("Open the camp")
                .typeStyle(.intakeChip, color: Theme.accent)
        }

        IntakeHeader(
            title: "42 players",
            subtitle: "From sign-ups.csv · 2 need a detail",
            backLabel: "Players",
            onBack: {}
        )

        Spacer()
    }
    .background(Theme.surfaceWarm)
}
