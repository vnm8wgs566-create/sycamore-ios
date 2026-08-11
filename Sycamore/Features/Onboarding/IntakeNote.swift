//
//  IntakeNote.swift
//  Sycamore
//
//  The green-tinted explanation inside `8e`'s venue card.
//
//  Not `InfoBanner(tone: .accent)`, which plates on `accentTint` with no border and sets its copy
//  in `accentDark`. The design plates this one on `accentSurface` inside an `accentSurfaceBorder`
//  and sets the copy in warm ink — a note about a default rather than a coloured status.
//

import SwiftUI

struct IntakeNote: View {

    let text: String

    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 15

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chipSquare, style: .continuous)

        HStack(alignment: .top, spacing: Spacing.cardGap) {
            Image(systemName: "info.circle")
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(Theme.accent)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text(text)
                .typeStyle(.intakeNote, color: Theme.inkWarm)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.row)
        .padding(.vertical, 10)
        .background(Theme.accentSurface, in: shape)
        .overlay {
            shape.strokeBorder(Theme.accentSurfaceBorder, lineWidth: BorderWidth.hairline)
        }
    }
}

// MARK: - Previews

#Preview("Venue note") {
    IntakeNote("Under 11, so Sycamore by default. Coaches can still move her once she is ranked.")
        .padding(Spacing.gutterWide)
        .background(Theme.surface)
}
