//
//  PinnedNoteBanner.swift
//  Sycamore
//
//  The pinned note above the courts — "Court 4 net is loose — keep the little ones off it."
//
//  One line, clipped rather than wrapped: it is a reminder of something already written down,
//  not the note itself. "Open" is the way to the whole thing, which lives in the Inbox.
//
//  Not `InfoBanner`. That component is a plate of copy with no border and nowhere to go; this
//  one is bordered, ends in an action and is a control end to end.
//

import SwiftUI

struct PinnedNoteBanner: View {

    let text: String
    /// The trailing verb. The design writes it "Open".
    var actionTitle: String = "Open"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The plate keeps the height the design draws; the frame around it only carries
            // the tap up to the 44pt minimum.
            banner
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pinned note. \(text)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens it in the inbox")
    }

    private var banner: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)

        return HStack(spacing: OverviewTheme.bannerGap) {
            Image(systemName: "pin.fill")
                .font(.system(size: OverviewTheme.bannerGlyph, weight: .regular))
                .foregroundStyle(Theme.accent)

            Text(text)
                .typeStyle(.caption, color: Theme.inkSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(actionTitle)
                .typeStyle(.metaSmall, color: Theme.accent)
        }
        .padding(.horizontal, OverviewTheme.bannerHorizontal)
        .padding(.vertical, OverviewTheme.bannerVertical)
        .background(Theme.accentTint, in: shape)
        .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline) }
    }
}

// MARK: - Previews

#Preview("Pinned note") {
    VStack(spacing: OverviewTheme.cardGap) {
        PinnedNoteBanner(text: "Court 4 net is loose — keep the little ones off it.") {}
        PinnedNoteBanner(text: "Shade tent is up on the lawn.") {}
    }
    .padding(Spacing.gutter)
    .background(Theme.grouped)
}
