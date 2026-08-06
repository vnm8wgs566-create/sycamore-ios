//
//  PlayerMoveBar.swift
//  Sycamore
//
//  `8q`'s pinned bar: 52pt at radius 16, white on a `stroke` hairline rather than a fill, the label
//  in `ink` and the glyph a step back in `inkSecondary`.
//
//  Not `PrimaryButton(tone: .outline)`, which is the same shape but a different set of colours —
//  that tone borders in `hairline` and sets its whole label, glyph included, in `inkSecondary`.
//  This is the design's louder outlined button: a darker border and full-strength copy, with only
//  the glyph held back. And not a `Label` either, for that last reason: one `LabelStyle` cannot
//  tint the icon and the title apart without being written from scratch.
//

import SwiftUI

struct PlayerMoveBar: View {

    /// False for a kid already on the top court, which is a real state rather than a failure —
    /// see `PlayerScreen.canMoveUp`.
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.button, style: .continuous)

        return Button(action: action) {
            HStack(spacing: OnTheDayTokens.barGap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityHidden(true)

                Text("Move up a court")
                    .typeStyle(.onTheDayBarLight, color: Theme.ink)
            }
            .padding(.vertical, Spacing.small)
            .frame(maxWidth: .infinity)
            // Floored rather than fixed: the design's 52pt is what this stands at, but the label
            // scales with Dynamic Type and a hard height would clip it at the accessibility sizes.
            .frame(minHeight: OnTheDayTokens.barHeight)
            .background(Theme.surface, in: shape)
            .overlay { shape.strokeBorder(Theme.stroke, lineWidth: BorderWidth.hairline) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .shadow(OnTheDayTokens.barShadowLight)
        .opacity(isEnabled ? 1 : OnTheDayTokens.inactiveOpacity)
        .disabled(!isEnabled)
        // `.disabled` alone tells VoiceOver the button is unavailable but not why, and dimmed ink
        // says nothing at all to somebody who cannot see it. An empty hint is not announced, so the
        // enabled bar reads as it looks.
        .accessibilityHint(isEnabled ? "" : "Already on the top court")
    }
}

// MARK: - Previews

#Preview("Move bar") {
    VStack(spacing: Spacing.large) {
        PlayerMoveBar(isEnabled: true) {}
        PlayerMoveBar(isEnabled: false) {}
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

#Preview("Move bar — accessibility1") {
    PlayerMoveBar(isEnabled: true) {}
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .dynamicTypeSize(.accessibility1)
}
