//
//  IntakeTitle.swift
//  Sycamore
//
//  A section 8 heading, in the serif the design sets them in.
//
//  Newsreader *is* bundled now — it landed while this screen was being written, so the platform
//  serif this originally drew was correct at the time and stale by the time it merged. Left New
//  York in place, Onboarding would have been the one corner of the app in a different serif from
//  every other screen, which is worse than being in no serif at all.
//
//  The heading now goes through `.typeStyle(_:color:)` like everything else; `TypeStyle.isSerif`
//  is the third case this file's original comment said did not exist.
//

import SwiftUI

/// Still its own view rather than a bare `Text`, for the `.isHeader` trait — a title is what the
/// screen *is*, and it is what VoiceOver should reach first.
struct IntakeTitle: View {

    let text: String
    var style: TypeStyle = .intakeTitle
    var color: Color = Theme.ink

    init(_ text: String, style: TypeStyle = .intakeTitle, color: Color = Theme.ink) {
        self.text = text
        self.style = style
        self.color = color
    }

    var body: some View {
        Text(text)
            // `serif: true` on the style, so the Dynamic Type scaling, tracking and line spacing
            // are the same code path every other line of type in the app runs through.
            .typeStyle(style.serif(), color: color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Previews

#Preview("Serif headings") {
    VStack(alignment: .leading, spacing: Spacing.large) {
        IntakeTitle("Shape the camp")
        IntakeTitle("42 players", style: .intakeTitleSm)
        IntakeTitle("Your camps")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.header)
    .background(Theme.surface)
}
