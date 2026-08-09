//
//  PlayerMoveBar.swift
//  Sycamore
//
//  `8q`'s pinned bar: 52pt at radius 16, white on a `stroke` hairline rather than a fill, the label
//  in `ink` and the glyph a step back in `inkSecondary`.
//
//  It reads "Move to another court" and opens `PlayerCourtPicker`. It read "Move up a court" and
//  performed that one move; the picker's own header records why that was narrowed and why it is
//  not any more. The construction below is unchanged by it — a bar that opens a list and a bar
//  that committed a move are the same button.
//
//  Not `PrimaryButton(tone: .outline)`, which is the same shape but a different set of colours —
//  that tone borders in `hairline` and sets its whole label, glyph included, in `inkSecondary`.
//  This is the design's louder outlined button: a darker border and full-strength copy, with only
//  the glyph held back. And not a `Label` either, for that last reason: one `LabelStyle` cannot
//  tint the icon and the title apart without being written from scratch.
//

import SwiftUI

struct PlayerMoveBar: View {

    /// False when there is nowhere else in the camp to send them — a camp of one court, or one
    /// still being shaped — which is a real state rather than a failure. See
    /// `PlayerScreen.canMoveElsewhere`.
    ///
    /// It meant "there is a court above this one" for as long as the bar performed the move
    /// itself. The bar opens `PlayerCourtPicker` now, so the question it answers is whether that
    /// list would have anything in it worth tapping — and a kid on the top court, which used to
    /// stand this down, has eleven other courts to choose from.
    let isEnabled: Bool
    /// Opens the picker. Deliberately not a write any more: `8q` no longer decides where a kid
    /// goes, it asks.
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.button, style: .continuous)

        return Button(action: action) {
            HStack(spacing: OnTheDayTokens.barGap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityHidden(true)

                Text("Move to another court")
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
        //
        // "Already on the top court" is what this used to say, and it is no longer the reason —
        // the top court is a perfectly good place to be moved off. Written without naming a count,
        // because the disabled state covers a camp of one court, a camp with none built yet and a
        // store that has not finished loading, and the reader does not need those told apart.
        .accessibilityHint(isEnabled ? "" : "There is nowhere else to move them")
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
