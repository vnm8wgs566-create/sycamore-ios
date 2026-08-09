//
//  IntakeType.swift
//  Sycamore
//
//  What the five getting-in screens need beyond the shared table.
//
//  `Typography.swift` used to be transcribed from the design this app shipped with, where headings
//  ran 800 and body copy 500, so almost every style these screens needed was a row it did not
//  have and each was spelled out here from the CSS. The table now carries section 8's weights, and
//  `TypeStyle.isSerif` carries its family, so nearly all of these are one-line aliases.
//
//  Three are not, and they are the three the design genuinely draws only here: the two serif
//  heading sizes, which fall between `display` (35) and `title1` (31), and `8u`'s invite-code
//  field. Those stay spelled out.
//

import SwiftUI

// MARK: - Headings

extension TypeStyle {

    /// `400 33/1.05 Newsreader`, `-.022em` — "Shape the camp" (`8b`), "Your camps" (`8u`).
    static let intakeTitle = TypeStyle(size: 33, weight: .regular, trackingEm: -0.022,
                                       lineHeightMultiple: 1.05, isSerif: true)
    /// `400 32/1.02 Newsreader`, `-.022em` — "Players" (`8c`), "42 players" (`8d`), "New player"
    /// (`8e`). Section 8's most-used heading: twelve of its twenty-one screens open with it.
    static let intakeTitleSm = TypeStyle(size: 32, weight: .regular, trackingEm: -0.022,
                                         lineHeightMultiple: 1.02, isSerif: true)
}

// MARK: - Copy

extension TypeStyle {

    /// `400 13.5/1.55` — `8b`'s header explainer, which runs to two lines.
    static let intakeLead = TypeStyle.subtitle.lineHeight(1.55)
    /// `400 13.5` — the one grey line under a title on `8c`, `8d` and `8e`.
    static let intakeSubtitle = TypeStyle.subtitle
    /// `400 13` — `8u`'s header line, and the "Players" beside a back caret.
    static let intakeSubtitleSm = TypeStyle.sheetSubtitle
    /// `400 12.5/1.5` — the copy inside `8e`'s venue note.
    static let intakeNote = TypeStyle.footnote
    /// `400 12.5/1.55` — the free-standing grey line between `8c`'s drop plate and its action
    /// card. Half a twentieth of leading more than `intakeNote`, which sounds like nothing and is
    /// the difference between a plated note and a line of page copy: this one has no card under it
    /// to hold it together, so the design opens it up.
    static let intakeFileNote = TypeStyle.footnote.lineHeight(1.55)
    /// `400 13.5/1.55` — a row of `8c`'s "what a file needs" checklist. The same shorthand as
    /// `intakeLead`; two names because they are two roles, one value because the design draws one.
    static let intakeChecklist = intakeLead
    /// `400 12` — a venue's second line on `8b`, an action row's second line on `8c`, "You become
    /// its first admin" on `8u`.
    static let intakeRowMeta = TypeStyle.meta
    /// `400 12.5` — the grey or amber line under a name on `8c`, `8d` and `8u`.
    static let intakeRowDetail = TypeStyle.rowDetail
    /// `400 12` — the centred line under `8b`'s call to action.
    static let intakeFootnote = TypeStyle.meta
}

// MARK: - Overlines

extension TypeStyle {

    /// `600 10.5`, `+.15em`, uppercase — a section header. `8c` and `8d` set the same style a
    /// hair tighter at `+.14em`, which is what `overlineSmall` itself carries.
    static let intakeOverline = TypeStyle.overlineSmall.tracking(em: 0.15)
    /// `600 11`, `+.06em`, uppercase — the XLSX / CSV plates on `8c`'s drop plate.
    ///
    /// `venueLabel` at a quarter less tracking. Both are a format-ish word set small and wide, and
    /// the design tightens this one because two of them sit side by side and want to read as a
    /// pair, where a venue's label stands alone above a card.
    static let intakeFormatChip = TypeStyle.venueLabel.tracking(em: 0.06)
    /// `600 10`, `+.14em`, uppercase — `8d`'s NEW / RETURNING / RANKED labels.
    static let intakeStatLabel = TypeStyle.statLabel.tracking(em: 0.14)
    /// `600 10`, `+.12em`, uppercase — the OPEN badge on `8u`.
    static let intakeBadge = TypeStyle.statLabel.tracking(em: 0.12)
}

// MARK: - Rows

extension TypeStyle {

    /// `600 17`, `-.03em` — `8d`'s counts. It typed `8c`'s "Import the sign-up list" until that
    /// heading became the serif "Drop the sign-up list" the frame draws, which is
    /// `intakeEmptyHeading`.
    static let intakeStatValue = TypeStyle.venueHeading
    /// `600 15.5`, `-.025em` — the camp you are signed in to on `8u`.
    static let intakeCampName = TypeStyle.rowTitle.size(15.5)
    /// `600 15`, `-.025em` — the other camps on `8u`, and "Start a camp".
    static let intakeCampNameSm = TypeStyle.bodyStrong.tracking(em: -0.025)
    /// `600 14.5`, `-.025em` — a venue's name on `8b`, an action row's title on `8c`.
    static let intakeRowTitle = TypeStyle.rowLabel.tracking(em: -0.025)
    /// `600 14`, `-.02em` — a per-court row on `8b`, a kid's name on `8d`.
    static let intakeRowTitleSm = TypeStyle.rowTitleSm
    /// `500 14.5` — the value a field holds on `8e`. `body` without its paragraph leading.
    static let intakeFieldValue = TypeStyle.body.lineHeight(nil)
    /// `400 13` — a field's label on `8e`.
    static let intakeFieldLabel = TypeStyle.sheetSubtitle
    /// `600 17`, `-.025em` — the camp-name field `8b` needs and the design does not draw.
    static let intakeFieldTitle = TypeStyle.fieldTitle
    /// `600 13` — the letter standing in for the design's gender glyph on `8d`.
    static let intakeGlyphLetter = TypeStyle.chip
}

// MARK: - Controls

extension TypeStyle {

    /// `600 15.5`, `-.02em` — "Save the shape" (`8b`). The design's one button at this size.
    static let intakeButton = TypeStyle(size: 15.5, weight: .semibold, trackingEm: -0.02)
    /// `600 16`, `-.015em` — the pinned call to action on `8d` and `8e`.
    static let intakeButtonLg = TypeStyle.button
    /// `600 15` — "Join" (`8u`).
    static let intakeJoin = TypeStyle.buttonSmall
    /// `600 16`, `+.18em` — `8u`'s invite-code field.
    ///
    /// Monospaced, which the design is not: it sets the field in the body face. A code is read
    /// character by character off a flyer and typed with one thumb, and proportional digits make
    /// `SYC-1181` and `SYC-4821` different widths. Same size, weight and tracking as drawn.
    static let intakeJoinCode = TypeStyle(size: 16, weight: .semibold, trackingEm: 0.18, isMonospaced: true)
    /// `600 13` — "Pull one from email", the bare accent line under `8c`'s call to action.
    ///
    /// It replaces `intakePill` (`600 13.5`), which typed the two capsules this screen used to
    /// draw side by side. The design gives the file one full-width button and demotes the second
    /// route to a text line under it, so there is no second capsule left to type.
    static let intakeInlineAction = TypeStyle.chip
    /// `600 12.5` — `8e`'s answer chips, `8u`'s Switch, `8d`'s "See all".
    static let intakeChip = TypeStyle.chipSoft
    /// `600 11.5` — `8d`'s "Fix" chip.
    static let intakeChipSm = TypeStyle.dividerLabel
    /// `600 14` — the number between a stepper's two buttons on `8b`.
    static let intakeStepperValue = TypeStyle.stepperValue.size(14)
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
