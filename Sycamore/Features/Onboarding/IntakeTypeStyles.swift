//
//  IntakeType.swift
//  Sycamore
//
//  Section 8's type table, for the five getting-in screens.
//
//  `Typography.swift` is transcribed from the design this app shipped with, where headings ran
//  Manrope 800 and body copy 500. Section 8 is set differently — 600 where the old table says
//  800, 400 where it says 500, and its headings are a *serif* — so almost every style these
//  screens need is a row the shared table does not have. Rather than bend the nearest one and
//  call it close, each row here is the design's `font:` shorthand read off the CSS.
//
//  Hoist the lot into `Typography.swift` once section 8 lands across the app; they are named for
//  their role rather than for this feature so the move is a rename of nothing.
//
//  On the serif: the design asks for Newsreader, which is not bundled and cannot be without
//  touching the project file. `IntakeTitle` draws these headings in the platform's own serif —
//  New York — which is the same transitional shape at the same weight, ships on every device,
//  and carries Dynamic Type without a fallback path. See the PR body.
//

import SwiftUI

// MARK: - Headings

extension TypeStyle {

    /// `400 33/1.05`, `-.022em`, serif — "Shape the camp" (`8b`), "Your camps" (`8u`).
    static let intakeTitle = TypeStyle(size: 33, weight: .regular, trackingEm: -0.022, lineHeightMultiple: 1.05)
    /// `400 32/1.02`, `-.022em`, serif — "Players" (`8c`), "42 players" (`8d`), "New player" (`8e`).
    static let intakeTitleSm = TypeStyle(size: 32, weight: .regular, trackingEm: -0.022, lineHeightMultiple: 1.02)
}

// MARK: - Copy

extension TypeStyle {

    /// `400 13.5/1.55` — `8b`'s header explainer, which runs to two lines.
    static let intakeLead = TypeStyle(size: 13.5, weight: .regular, lineHeightMultiple: 1.55)
    /// `400 13.5` — the one grey line under a title on `8c`, `8d` and `8e`.
    static let intakeSubtitle = TypeStyle(size: 13.5, weight: .regular)
    /// `400 13` — `8u`'s header line, and the "Players" beside a back caret.
    static let intakeSubtitleSm = TypeStyle(size: 13, weight: .regular)
    /// `400 12.5/1.5` — the copy inside `8e`'s venue note.
    static let intakeNote = TypeStyle(size: 12.5, weight: .regular, lineHeightMultiple: 1.5)
    /// `400 13.5/1.55` — a row of `8c`'s "what a file needs" checklist.
    static let intakeChecklist = TypeStyle(size: 13.5, weight: .regular, lineHeightMultiple: 1.55)
    /// `400 12` — a venue's second line on `8b`, "You become its first admin" on `8u`.
    static let intakeRowMeta = TypeStyle(size: 12, weight: .regular)
    /// `400 12.5` — the grey or amber line under a name on `8c`, `8d` and `8u`.
    static let intakeRowDetail = TypeStyle(size: 12.5, weight: .regular)
    /// `400 12` — the centred line under `8b`'s call to action.
    static let intakeFootnote = TypeStyle(size: 12, weight: .regular)
}

// MARK: - Overlines

extension TypeStyle {

    /// `600 10.5`, `+.15em`, uppercase — a section header. `8c` and `8d` set the same style a
    /// hair tighter at `+.14em`; reach that with `.tracking(em: 0.14)`.
    static let intakeOverline = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.15, isUppercased: true)
    /// `600 10`, `+.14em`, uppercase — `8d`'s NEW / RETURNING / RANKED labels.
    static let intakeStatLabel = TypeStyle(size: 10, weight: .semibold, trackingEm: 0.14, isUppercased: true)
    /// `600 10`, `+.12em`, uppercase — the OPEN badge on `8u`.
    static let intakeBadge = TypeStyle(size: 10, weight: .semibold, trackingEm: 0.12, isUppercased: true)
}

// MARK: - Rows

extension TypeStyle {

    /// `600 17`, `-.03em` — `8d`'s counts and `8c`'s import heading.
    static let intakeStatValue = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.03)
    /// `600 15.5`, `-.025em` — the camp you are signed in to on `8u`.
    static let intakeCampName = TypeStyle(size: 15.5, weight: .semibold, trackingEm: -0.025)
    /// `600 15`, `-.025em` — the other camps on `8u`, and "Start a camp".
    static let intakeCampNameSm = TypeStyle(size: 15, weight: .semibold, trackingEm: -0.025)
    /// `600 14.5`, `-.025em` — a venue's name on `8b`, an action row's title on `8c`.
    static let intakeRowTitle = TypeStyle(size: 14.5, weight: .semibold, trackingEm: -0.025)
    /// `600 14`, `-.02em` — a per-court row on `8b`, a kid's name on `8d`.
    static let intakeRowTitleSm = TypeStyle(size: 14, weight: .semibold, trackingEm: -0.02)
    /// `500 14.5` — the value a field holds on `8e`.
    static let intakeFieldValue = TypeStyle(size: 14.5, weight: .medium)
    /// `400 13` — a field's label on `8e`.
    static let intakeFieldLabel = TypeStyle(size: 13, weight: .regular)
    /// `600 17`, `-.025em` — the camp-name field `8b` needs and the design does not draw. Set in
    /// section 8's weight rather than `fieldTitle`'s 800 so it sits with the rest of the screen.
    static let intakeFieldTitle = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.025)
    /// `600 13` — the letter standing in for the design's gender glyph on `8d`.
    static let intakeGlyphLetter = TypeStyle(size: 13, weight: .semibold)
}

// MARK: - Controls

extension TypeStyle {

    /// `600 15.5`, `-.02em` — "Save the shape" (`8b`).
    static let intakeButton = TypeStyle(size: 15.5, weight: .semibold, trackingEm: -0.02)
    /// `600 16`, `-.015em` — the pinned call to action on `8d` and `8e`.
    static let intakeButtonLg = TypeStyle(size: 16, weight: .semibold, trackingEm: -0.015)
    /// `600 15` — "Join" (`8u`).
    static let intakeJoin = TypeStyle(size: 15, weight: .semibold)
    /// `600 16`, `+.18em` — `8u`'s invite-code field.
    ///
    /// Monospaced, which the design is not: it sets the field in the body face. A code is read
    /// character by character off a flyer and typed with one thumb, and proportional digits make
    /// `SYC-1181` and `SYC-4821` different widths. Same size, weight and tracking as drawn.
    static let intakeJoinCode = TypeStyle(size: 16, weight: .semibold, trackingEm: 0.18, isMonospaced: true)
    /// `600 13.5` — `8c`'s two file pills.
    static let intakePill = TypeStyle(size: 13.5, weight: .semibold)
    /// `600 12.5` — `8e`'s answer chips, `8u`'s Switch, `8d`'s "See all".
    static let intakeChip = TypeStyle(size: 12.5, weight: .semibold)
    /// `600 11.5` — `8d`'s "Fix" chip.
    static let intakeChipSm = TypeStyle(size: 11.5, weight: .semibold)
    /// `600 14` — the number between a stepper's two buttons on `8b`.
    static let intakeStepperValue = TypeStyle(size: 14, weight: .semibold)
}

// MARK: - Previews

#Preview("Section 8 type") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            IntakeTitle("Shape the camp")
            IntakeTitle("42 players", style: .intakeTitleSm)

            Text("How many places you run, and how many courts inside each.")
                .typeStyle(.intakeLead, color: Theme.inkTertiary)
            Text("Venues")
                .typeStyle(.intakeOverline, color: Theme.inkMuted)
            Text("First name, last name")
                .typeStyle(.intakeChecklist, color: Theme.inkWarm)
            Text("Sycamore")
                .typeStyle(.intakeRowTitle, color: Theme.ink)
            Text("Higher level")
                .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
            Text("Save the shape")
                .typeStyle(.intakeButton, color: Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.header)
    }
    .background(Theme.surfaceWarm)
}
