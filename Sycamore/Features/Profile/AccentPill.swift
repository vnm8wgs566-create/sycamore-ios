//
//  AccentPill.swift
//  Sycamore
//
//  The green capsule that states what you are: "Worker" beside the name on `8s`, "Admin" in the
//  corner of `8t`.
//
//  Not `Badge`, which is the other tinted chip in this app and a different object: `Badge` is a
//  radius-5 rectangle set in `700 9.5`, and this is a radius-99 capsule set in `600 10` and
//  tracked half again as wide. They read differently on purpose — a badge qualifies the thing
//  next to it ("2 short"), a pill states a standing.
//
//  The glyph is optional because `8t` leads with a shield and `8s` does not, and the two colours
//  are deliberately different: the design draws the shield in `accent` and its label in the
//  darker `accentDark`, so the icon carries the brand and the copy carries the contrast.
//

import SwiftUI

struct AccentPill: View {

    let title: String
    /// `8t`'s shield. `8s` has none.
    var systemImage: String?
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 5

    init(
        _ title: String,
        systemImage: String? = nil,
        horizontalPadding: CGFloat = 10,
        verticalPadding: CGFloat = 5
    ) {
        self.title = title
        self.systemImage = systemImage
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        HStack(spacing: Spacing.tight) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: IconSize.inline, weight: .regular))
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .typeStyle(.pillLabel, color: Theme.accentDark)
        }
        .lineLimit(1)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(Theme.accentTint, in: Capsule(style: .continuous))
        // The glyph restates the label, so the pair reads as one word rather than as
        // "checkmark shield, Admin".
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Accent pill") {
    VStack(spacing: Spacing.large) {
        AccentPill("Worker")
        AccentPill("Admin", systemImage: "checkmark.shield.fill", horizontalPadding: Spacing.row, verticalPadding: Spacing.tight)
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
