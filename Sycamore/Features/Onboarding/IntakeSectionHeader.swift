//
//  IntakeSectionHeader.swift
//  Sycamore
//
//  `600 10.5 / +.15em / uppercase`, with the design's optional trailing action.
//
//  Not `DesignSystem/SectionHeader`, which is `700 11 / +.1em` from the design this app shipped
//  with. Editing that one to match would restyle every screen in the app from a branch that owns
//  five of them; this is a replacement for it, not a sibling, and should take its place once the
//  whole of section 8 has landed.
//

import SwiftUI

struct IntakeSectionHeader: View {

    let title: String
    var trackingEm: CGFloat = 0.15
    var actionTitle: String?
    var action: (() -> Void)?
    var horizontalPadding: CGFloat = 5
    /// 8 inside a block that owns its own card (`8b`, `8u`); 0 where the header is a direct child
    /// of a stack that already spaces its children (`8c`, `8d`).
    var bottomPadding: CGFloat = Spacing.small

    init(
        _ title: String,
        trackingEm: CGFloat = 0.15,
        actionTitle: String? = nil,
        horizontalPadding: CGFloat = 5,
        bottomPadding: CGFloat = Spacing.small,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.trackingEm = trackingEm
        self.actionTitle = actionTitle
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            Text(title)
                .typeStyle(.intakeOverline.tracking(em: trackingEm), color: Theme.inkMuted)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .typeStyle(.intakeChip, color: Theme.accent)
                        // A 12.5pt line draws about 15pt tall; 16 either side of it clears 44.
                        .intakeTouchTarget(inset: Spacing.large)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
    }
}

// MARK: - Previews

#Preview("Section header") {
    VStack(alignment: .leading, spacing: Spacing.large) {
        IntakeSectionHeader("Venues")
        IntakeSectionHeader("Read cleanly · 40", trackingEm: 0.14, actionTitle: "See all") {}
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}
