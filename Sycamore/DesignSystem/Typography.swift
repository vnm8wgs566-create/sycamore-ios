//
//  Typography.swift
//  Sycamore
//
//  Every type style in the design, and the one place that decides whether we draw them in
//  Instrument Sans or in the system font.
//
//  The design authors letter-spacing in `em`, so `TypeStyle` stores it that way and converts
//  to points on demand — that keeps the numbers here identical to the CSS they came from.
//

import CoreText
import SwiftUI

// MARK: - Weight

/// The raw value is the CSS weight so the styles below read like the design's `font:` shorthand.
///
/// There is no `extraBold`. 800 was left over from when this app was set in Manrope, and the
/// design does not draw it anywhere: across section 8's 486 app-content declarations the weights
/// are 400 (212 uses), 500 (24) and 600 (250) — no 700 either. Instrument Sans' axis runs 400–700
/// and the design asks Google Fonts for exactly `wght@400..700`, so 800 never had a face of its
/// own; it resolved to the 700 one and simply drew every heading a step heavier than the design.
///
/// `bold` stays because the mono styles and a run of sign-in copy still name it. Nothing in the
/// type table below does.
enum TypeWeight: Int, CaseIterable, Sendable {
    case regular = 400
    case medium = 500
    case semibold = 600
    case bold = 700

    var fontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    /// PostScript name of the matching Instrument Sans instance.
    ///
    /// The `_`-suffixed spelling is not a typo. Core Text exposes a variable font's named
    /// instances as separate descriptors, but Instrument Sans' `fvar` table carries no
    /// PostScript name IDs for them, so Core Text synthesises the names as
    /// `<default PostScript name>_<subfamily>`. Verified by enumerating the file with
    /// `CTFontManagerCreateFontDescriptorsFromURL` rather than assumed — Manrope, which *does*
    /// carry those IDs, comes back with clean `Manrope-Bold`-style names instead, and guessing
    /// that pattern here would have silently dropped every weight to the system font.
    var faceName: String {
        switch self {
        case .regular: "InstrumentSans-Regular"
        case .medium: "InstrumentSans-Regular_Medium"
        case .semibold: "InstrumentSans-Regular_SemiBold"
        case .bold: "InstrumentSans-Regular_Bold"
        }
    }
}

// MARK: - Font family resolution

/// The single decision point for Instrument Sans-versus-system. Resolved once, on first use.
enum FontFamily {

    /// Faces that actually registered, keyed by CSS weight. Empty when the TTF is not bundled —
    /// in which case every style falls back to the system font at the same weight.
    static let availableFaces: [Int: String] = {
        var faces: [Int: String] = [:]
        for weight in TypeWeight.allCases where faceIsRegistered(weight.faceName) {
            faces[weight.rawValue] = weight.faceName
        }
        return faces
    }()

    static var usesInstrumentSans: Bool { !availableFaces.isEmpty }

    /// Newsreader's regular, and only its regular — the design sets every serif heading at 400.
    ///
    /// The name is read off the file, not guessed, and it is the second time that has mattered:
    /// Newsreader's optical-size axis means Core Text synthesises the default instance as
    /// `Newsreader16pt-Regular` while its siblings come back `NewsreaderRoman-Light`,
    /// `-Medium`, `-Bold`. Neither pattern is inferable from the family name, and asking for the
    /// wrong one drops silently to the system serif.
    static let serifFace: String? = {
        let name = "Newsreader16pt-Regular"
        return faceIsRegistered(name) ? name : nil
    }()

    /// `CTFontCreateWithName` never fails — it substitutes. So ask for the face and check that
    /// what came back is actually the face we asked for.
    private static func faceIsRegistered(_ name: String) -> Bool {
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        let resolved = CTFontCopyPostScriptName(font) as String
        return resolved.caseInsensitiveCompare(name) == .orderedSame
    }
}

// MARK: - TypeStyle

/// One row of the design's type table: size, weight, tracking and line height, plus the two
/// per-style flags the design encodes in CSS (`text-transform` and the mono family).
struct TypeStyle: Sendable, Equatable {
    var size: CGFloat
    var weight: TypeWeight
    /// Letter-spacing exactly as authored, in `em`. Negative tightens.
    var trackingEm: CGFloat = 0
    /// CSS `line-height` multiple. `nil` leaves the font's natural leading alone.
    var lineHeightMultiple: CGFloat?
    var isUppercased: Bool = false
    var isMonospaced: Bool = false
    /// Draws in Newsreader rather than Instrument Sans.
    ///
    /// The design loads three families and this app had bundled one. Newsreader sets **every
    /// screen title in section 8** — "Sycamore", "Shape the camp", "Players", "Schedule",
    /// "Groups", "Friday is empty." — 44 times, always at weight 400 and 22–40px. Every one of
    /// them was rendering in a sans, which is not a near-miss: it is the difference between a
    /// masthead and a label, and it is the first thing on every screen.
    ///
    /// (The document's third family, Manrope, is the spec's own annotation chrome — "Final — the
    /// app in order", "8a" — not app content. Dropping it was right.)
    var isSerif: Bool = false

    /// Letter-spacing in points, which is what SwiftUI's `tracking(_:)` wants.
    var tracking: CGFloat { size * trackingEm }

    /// The Dynamic Type ramp this style scales along.
    ///
    /// Derived from the point size rather than spelled out on each of the fifty-odd styles
    /// below: a hand-written table would have to be edited every time a style is added, and
    /// the one that got forgotten would be the one that silently stopped scaling. The bands
    /// mirror Apple's own sizes, so `.body` (14.5) rides the body ramp and `.badge` (9.5)
    /// rides the caption2 ramp.
    ///
    /// This picks the *rate* of growth, not the rendered size — at the default setting every
    /// style still draws at exactly the `size` the design specifies.
    var textStyle: Font.TextStyle {
        switch size {
        case 28...: .largeTitle
        case 22..<28: .title
        case 20..<22: .title2
        case 17..<20: .title3
        case 15.5..<17: .headline
        case 14..<15.5: .body
        case 13..<14: .callout
        case 12.5..<13: .subheadline
        case 11.5..<12.5: .footnote
        case 10.5..<11.5: .caption
        default: .caption2
        }
    }

    /// SwiftUI's `lineSpacing` is *extra* space between lines rather than a line box height,
    /// so a `1.5` multiple on a 14.5pt face becomes 7.25pt of added leading. That slightly
    /// over-states the gap (the font's own leading is already in there) but it is the closest
    /// single-number approximation, and it is what the design's airy body copy needs.
    var lineSpacing: CGFloat {
        guard let multiple = lineHeightMultiple, multiple > 1 else { return 0 }
        return (multiple - 1) * size
    }

    func weight(_ weight: TypeWeight) -> TypeStyle {
        var copy = self
        copy.weight = weight
        return copy
    }

    func size(_ size: CGFloat) -> TypeStyle {
        var copy = self
        copy.size = size
        return copy
    }

    /// Nudges letter-spacing, still in `em`, for the handful of places the design varies it
    /// within one role (badges run `+.07em` to `+.09em`).
    func tracking(em: CGFloat) -> TypeStyle {
        var copy = self
        copy.trackingEm = em
        return copy
    }

    func lineHeight(_ multiple: CGFloat?) -> TypeStyle {
        var copy = self
        copy.lineHeightMultiple = multiple
        return copy
    }

    func uppercased(_ flag: Bool = true) -> TypeStyle {
        var copy = self
        copy.isUppercased = flag
        return copy
    }

    /// Draws this style in Newsreader. For the section 8 headings a feature declares itself
    /// rather than taking from the shared table.
    func serif(_ flag: Bool = true) -> TypeStyle {
        var copy = self
        copy.isSerif = flag
        return copy
    }
}

// MARK: - The type table
//
// This table used to be a step or two heavier than the design. It was transcribed from the
// screens this app shipped with, and section 8 — the final design, the app in order — sets the
// same roles lighter throughout. Eight feature folders each noticed and each compensated
// privately, which is the wrong altitude: a dozen local overrides of a shared table is how the
// table stops being shared. They are gone; this is what they were compensating for.
//
// Counted over the 486 app-content declarations in section 8's own CSS (`8a`–`8u`, excluding the
// Manrope the document sets its *own* annotation chrome in), the design uses three weights:
//
//     400   212 uses          600   250 uses
//     500    24 uses          700     0        800     0
//
// So the ceiling is 600, and every `bold` and `extraBold` heading in this table sat above the
// heaviest thing the design draws. Per size, where the table had a row:
//
//     17px    600, 22 of 22       16.5px  600,  2 of  2
//     16px    600,  9 of  9       15px    600, 11 of 11
//     14.5px  600, 19 of 34       14px    600, 50 of 71
//     13.5px  400, 38 of 44       13px    400, 61 of 77
//     12.5px  600, 41 / 400, 44   12px    400, 21 of 37
//     11.5px  400,  7 of 11       10.5px  600, 36 of 36      10px  600, 10 of 10
//
// Two rows are deliberately left heavy. `badge` (9.5) has no section-8 equivalent to measure
// against — the design's badges are all at 10px — and the three mono styles have none either,
// because section 8 sets no monospace at all. Guessing at those would be the same mistake in the
// other direction.
//
// A table drawn in three weights instead of five has rows that coincide: `chip` and `countdown`
// are both `600 13` now, `sheetSubtitle` and `rankNumeral` both `400 13`, `bodyStrong` and
// `venueRow` both `600 15/-.02em`. They are kept as separate rows rather than aliased to each
// other because they are separate *roles*, and roles that agree today are not thereby the same
// thing — the day a chip changes, a countdown should not follow it. Feature files alias onto
// these rows precisely because those names are the same role under a screen's local vocabulary.
//
// Everything in SPEC.md section 1 "Type", in the order it appears there.

extension TypeStyle {

    /// `800 35/1.05`, `-.042em` — sign-in wordmark.
    static let display = TypeStyle(size: 35, weight: .regular, trackingEm: -0.022, lineHeightMultiple: 1.05, isSerif: true)
    /// `800 31/1.08`, `-.038em` — "Check your email".
    static let title1 = TypeStyle(size: 31, weight: .regular, trackingEm: -0.022, lineHeightMultiple: 1.08, isSerif: true)
    /// `800 29/1.1`, `-.038em` — "Which camp?", "New camp".
    static let title2 = TypeStyle(size: 29, weight: .regular, trackingEm: -0.022, lineHeightMultiple: 1.1, isSerif: true)
    /// `800 28/1`, `-.038em` — Groups / Rank / Setup.
    static let tabTitle = TypeStyle(size: 28, weight: .regular, trackingEm: -0.022, lineHeightMultiple: 1.02, isSerif: true)
    /// `800 24/1.1`, `-.035em`.
    static let profileName = TypeStyle(size: 24, weight: .regular, trackingEm: -0.02, lineHeightMultiple: 1.15, isSerif: true)
    /// `800 22`, `-.03em`.
    static let sheetTitle = TypeStyle(size: 22, weight: .regular, trackingEm: -0.02, isSerif: true)
    /// `600 17`, `-.03em` — venue heading in Rank, a court card's big line, a group's name.
    static let venueHeading = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.03)
    /// `600 16.5`, `-.028em` — coach name, camp name.
    static let rowTitleLg = TypeStyle(size: 16.5, weight: .semibold, trackingEm: -0.028)
    /// `600 16`, `-.025em`.
    static let rowTitle = TypeStyle(size: 16, weight: .semibold, trackingEm: -0.025)
    /// `600 15`, `-.02em` — player name, setting label.
    static let bodyStrong = TypeStyle(size: 15, weight: .semibold, trackingEm: -0.02)
    /// `500 14.5/1.5` — descriptive copy. One of the two sizes the design still sets at 500.
    static let body = TypeStyle(size: 14.5, weight: .medium, lineHeightMultiple: 1.5)
    /// `400 12` — "13 · F · returning".
    static let meta = TypeStyle(size: 12, weight: .regular)
    /// `600 13` — sport chips, time pills, venue chips.
    static let chip = TypeStyle(size: 13, weight: .semibold)
    /// `700 11`, `+.1em`, uppercase — "YOUR CAMPS".
    static let sectionHeader = TypeStyle(size: 11, weight: .bold, trackingEm: 0.1, isUppercased: true)
    /// `700 9.5`, uppercase — "Away", "In range", "Worker".
    ///
    /// The one weight in this table left above the design's 600 ceiling, because there is nothing
    /// to measure it against: section 8 sets every badge it draws at 10px (`statLabel`), and its
    /// only 9.5 is a set of initials. Lightening a badge on that evidence would be a guess.
    ///
    /// Tracking is the one thing the design varies here: `+.07em` on Groups' `Away`, `+.08em`
    /// on the venue status badges, `+.09em` on Profile's role badge. `+.08em` is the value
    /// carried by the style because it is the most common; `Badge(_:trackingEm:)` takes the
    /// other two, and `tracking(em:)` reaches them anywhere else.
    static let badge = TypeStyle(size: 9.5, weight: .bold, trackingEm: 0.08, isUppercased: true)
    /// `ui-monospace/Menlo 700 12` — court chips.
    static let mono = TypeStyle(size: 12, weight: .bold, isMonospaced: true)
}

// MARK: - Working styles
//
// The rest of the design's `font:` shorthands, so no feature file has to spell one out.

extension TypeStyle {

    // Chrome
    /// `600 15`, `-.01em` — the 9:41 in the mock status bar. The design draws its own at `600 14`;
    /// the size is left alone because this is a drawing of iOS, not a screen of the app.
    static let statusTime = TypeStyle(size: 15, weight: .semibold, trackingEm: -0.01)
    /// `600 13.5` — selected tab label. Section 8 draws no tab bar, so the weight follows its
    /// 13.5 rule rather than a declaration: 400 is the size's majority but a *selected* tab is
    /// emphasis, and 600 is the only other weight the design sets 13.5 in.
    static let tabLabel = TypeStyle(size: 13.5, weight: .semibold)

    // Buttons
    /// `600 16.5`, `-.015em` — "Continue with Apple", "Email me a code".
    static let buttonLarge = TypeStyle(size: 16.5, weight: .semibold, trackingEm: -0.015)
    /// `600 16`, `-.015em` — "Create camp", "Take attendance", the pinned call to action.
    static let button = TypeStyle(size: 16, weight: .semibold, trackingEm: -0.015)
    /// `600 15` — "Join", the early-pick-up confirm bar.
    static let buttonSmall = TypeStyle(size: 15, weight: .semibold)
    /// `600 14` — "Sign out", "Delete account", "Remove from camp".
    static let buttonCompact = TypeStyle(size: 14, weight: .semibold)

    // Fields
    /// `600 17`, `-.025em` — the camp-name field's value.
    static let fieldTitle = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.025)
    /// `500 15.5` — the email field's value / placeholder.
    static let fieldValue = TypeStyle(size: 15.5, weight: .medium)
    /// `500 15` — the search field's placeholder.
    static let searchValue = TypeStyle(size: 15, weight: .medium)
    /// `600 26`, `-.03em` — a filled OTP cell. Section 8 draws no OTP; 26 is a serif display line
    /// there (`8s`'s name), which is a different role, so only the weight follows the ceiling.
    static let otpDigit = TypeStyle(size: 26, weight: .semibold, trackingEm: -0.03)

    // Copy
    /// `500 14/1.5` — "Signed in as …". The other size the design still sets at 500.
    static let bodyAlt = TypeStyle(size: 14, weight: .medium, lineHeightMultiple: 1.5)
    /// `400 13/1.55` — the Rank header's explainer.
    static let bodySmall = TypeStyle(size: 13, weight: .regular, lineHeightMultiple: 1.55)
    /// `400 13` — sheet subtitles, a breadcrumb, a field's label, a card's grey second line, a
    /// rank numeral read as an index. The design's single most-declared style: 61 of section 8's
    /// 77 uses of 13px are this.
    static let sheetSubtitle = TypeStyle(size: 13, weight: .regular)
    /// `400 13.5` — the grey line under a screen title, "+3 more", a name in a court's list.
    static let subtitle = TypeStyle(size: 13.5, weight: .regular)
    /// `400 12.5` — a subtitle under a name, a row's grey second line, a note, a hint.
    static let rowDetail = TypeStyle(size: 12.5, weight: .regular)
    /// `400 12.5/1.5` — centred footnotes under a CTA.
    static let footnote = TypeStyle(size: 12.5, weight: .regular, lineHeightMultiple: 1.5)
    /// `400 13.5/1.6` — the paragraph inside an empty-state card. `8f`, `8g` and `8h` set the
    /// same sentence under the same serif heading, and each had spelled this out privately.
    static let emptyBody = TypeStyle(size: 13.5, weight: .regular, lineHeightMultiple: 1.6)
    /// `500 12.5/1.55` — copy inside an info banner. Section 8 draws no info banner; left at 500
    /// because 12.5 is the one size where the design genuinely still uses it.
    static let caption = TypeStyle(size: 12.5, weight: .medium, lineHeightMultiple: 1.55)
    /// `600 11.5` — the "or" divider label, and the initials in a small disc.
    static let dividerLabel = TypeStyle(size: 11.5, weight: .semibold)
    /// `600 13` — "Resend in 0:42", the time beside the block running now.
    static let countdown = TypeStyle(size: 13, weight: .semibold)

    // Rows
    /// `600 15`, `-.02em` — venue name in a Groups section header.
    static let venueRow = TypeStyle(size: 15, weight: .semibold, trackingEm: -0.02)
    /// `600 14.5`, `-.02em` — account row title, sheet action row title.
    ///
    /// Section 8 tracks this size `-.025em` in 17 of its 19 uses. The difference is 0.07pt, so
    /// the row keeps `-.02em` and the four callers that want the design's own figure ask for it
    /// with `tracking(em: -0.025)` rather than each respelling the style.
    static let rowLabel = TypeStyle(size: 14.5, weight: .semibold, trackingEm: -0.02)
    /// `600 14`, `-.02em` — a name in a list that is people rather than a rank band: "Who is
    /// where", a cleared Inbox row, `8g`'s "Added so far".
    static let rowTitleSm = TypeStyle(size: 14, weight: .semibold, trackingEm: -0.02)
    /// `400 14` — a name that has been answered, a kid's name in a group card, a field's
    /// placeholder. Regular, not bold: eight of these in a card is a list to scan, and the design
    /// lets the numerals and the marks carry the emphasis.
    static let rowValue = TypeStyle(size: 14, weight: .regular)
    /// `500 12.5` — account row value, a pinned note. 12.5 splits almost evenly between 400 and
    /// 600 in section 8 and keeps three uses of 500; this is one of them. The 400 cut is
    /// `rowDetail`, the 600 cut is `metaStrong`.
    static let rowSubtitle = TypeStyle(size: 12.5, weight: .medium)
    /// `400 11.5` — the venue sheet's limits sub-copy, the amber line on a marked row.
    static let rowSubtitleSmall = TypeStyle(size: 11.5, weight: .regular)
    /// `600 12.5` — "Court 1 · 8 here", "50 kids", "Coach · Sycamore, Court 3".
    static let metaStrong = TypeStyle(size: 12.5, weight: .semibold)
    /// `600 12` — "1–50", inline banner copy.
    static let metaSmall = TypeStyle(size: 12, weight: .semibold)
    /// `400 13` — rank numerals. The design sets the numeral and the band it labels in exactly
    /// the same face; only their colours differ.
    static let rankNumeral = TypeStyle(size: 13, weight: .regular)

    // Overlines
    /// `600 11`, `+.08em`, uppercase — "HIGHER LEVEL", a venue's subtitle in the earlier design.
    ///
    /// **No caller draws it in this role.** Kept rather than deleted because the data behind it
    /// exists — `VenueSheet` collects the subtitle, prompting "Subtitle, e.g. Higher level" — and
    /// nothing has drawn it since section 8 re-cut the venue row. It is the row to reach for when
    /// something does, rather than a style to invent then. Delete it if the subtitle goes — but
    /// note that `TypeStyle.intakeFormatChip` now derives from it, so the derivation moves too.
    static let venueLabel = TypeStyle(size: 11, weight: .semibold, trackingEm: 0.08, isUppercased: true)
    /// `600 11.5`, `+.06em`, uppercase — a staff row's role, "45 MORE IN SYCAMORE".
    static let overline = TypeStyle(size: 11.5, weight: .semibold, trackingEm: 0.06, isUppercased: true)
    /// `600 10.5`, `+.14em`, uppercase — every section heading in section 8: "STILL TO MARK · 2",
    /// "YOUR COURT", "NEEDS YOU · 2", "ADDED SO FAR", "VENUES".
    ///
    /// The row this table was missing, and seven feature files had each declared it. Neither
    /// `venueLabel` (11 / `+.08em`) nor `overline` (11.5 / `+.06em`) is within a rounding of it,
    /// and section 8 sets nothing at all at 11 or 11.5 uppercase — those two are the earlier
    /// design's, kept for the screens still drawn from it.
    ///
    /// Tracking is the one thing the design varies: `+.14em` on `8c`/`8d`/`8j`/`8l`/`8m`/`8n`/
    /// `8q`/`8r` and `+.15em` on `8a`/`8b`/`8f`/`8g`/`8h`/`8s`/`8t`/`8u`, which is 16 against 17
    /// and as near a tie as makes no difference. `+.14em` is carried because it is the value four
    /// of the seven callers already treated as the base; `tracking(em: 0.15)` reaches the other.
    static let overlineSmall = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.14, isUppercased: true)

    // Sheets
    /// `800 21`, `-.03em` — the staff sheet's title, which sits beside an avatar.
    static let sheetTitleSm = TypeStyle(size: 21, weight: .regular, trackingEm: -0.02, isSerif: true)
    /// `600 10`, `+.09em`, uppercase — stat tile label, a role pill, a venue's amber flag.
    ///
    /// The design tracks 10px five different ways (`+.1em` to `+.14em`) with no majority, so the
    /// `+.09em` this was transcribed at stays and each caller nudges it. Only the weight moved.
    static let statLabel = TypeStyle(size: 10, weight: .semibold, trackingEm: 0.09, isUppercased: true)
    /// `600 20`, `-.03em` — stat tile value.
    static let statValue = TypeStyle(size: 20, weight: .semibold, trackingEm: -0.03)
    /// `600 15` — the stepper's value, the venue sheet's `4 – 7`.
    static let stepperValue = TypeStyle(size: 15, weight: .semibold)
    /// `600 13.5` — a history entry's title, a court card's "Open" badge.
    static let timelineTitle = TypeStyle(size: 13.5, weight: .semibold)
    /// `400 11.5` — a history entry's byline.
    static let timelineMeta = TypeStyle(size: 11.5, weight: .regular)

    // Chips
    /// `600 12.5` — venue filter chips, "Even out", "Add" / "Invite".
    static let chipMedium = TypeStyle(size: 12.5, weight: .semibold)
    /// `600 12` — staff filter chips.
    static let chipCompact = TypeStyle(size: 12, weight: .semibold)
    /// `600 12` — attribute chips ("Everyone", "Boys").
    static let chipSmall = TypeStyle(size: 12, weight: .semibold)
    /// `600 12.5` — court chips in the staff sheet.
    static let chipSoft = TypeStyle(size: 12.5, weight: .semibold)

    // Mono
    /// `700 12.5`, `+.06em` — the invite code inline in Setup's subtitle.
    static let monoInline = TypeStyle(size: 12.5, weight: .bold, trackingEm: 0.06, isMonospaced: true)
    /// `700 17`, `+.18em` — the join-with-a-code input.
    static let monoInput = TypeStyle(size: 17, weight: .bold, trackingEm: 0.18, isMonospaced: true)

    /// Initials sized for an avatar of `diameter`. The design does not use a constant ratio, so
    /// this is a lookup with a proportional tail for anything larger.
    ///
    /// One weight now, where there were two. The 36/44pt discs were 700 and the 46/72pt ones 800
    /// — a split read off the earlier screens, and section 8 sets every set of initials it draws
    /// at 600 regardless of the disc (`8g` at 32pt, `8s` at 64, `8t`'s overlapping stack at 24).
    static func initials(forAvatarSize diameter: CGFloat) -> TypeStyle {
        switch diameter {
        case ..<40: TypeStyle(size: 12, weight: .semibold)
        case ..<46: TypeStyle(size: 13.5, weight: .semibold)
        case ..<60: TypeStyle(size: 15, weight: .semibold)
        default: TypeStyle(size: (diameter * 0.305).rounded(), weight: .semibold)
        }
    }
}

// MARK: - Font

extension Font {

    /// The design's font for a style — Instrument Sans when it is bundled, otherwise the system
    /// face at the matching weight.
    ///
    /// `size` is passed in already scaled for Dynamic Type by `TypeStyleModifier`, so every
    /// face here is built at a literal point size. Scaling in one place keeps the bundled and
    /// system paths growing at the same rate; letting each build its own relative font made
    /// them diverge as soon as one weight failed to register.
    static func sycamore(_ style: TypeStyle, size: CGFloat? = nil) -> Font {
        sycamore(size: size ?? style.size, weight: style.weight, monospaced: style.isMonospaced)
    }

    static func sycamore(
        size: CGFloat, weight: TypeWeight, monospaced: Bool = false, serif: Bool = false
    ) -> Font {
        // The design's mono is `ui-monospace, Menlo` — i.e. the platform mono, never a bundled
        // face.
        if monospaced {
            return .system(size: size, weight: weight.fontWeight, design: .monospaced)
        }
        // The design writes `Newsreader, Georgia, serif`, so the fallback is the platform serif
        // rather than the sans — a heading that loses Newsreader should still read as a heading.
        if serif {
            guard let face = FontFamily.serifFace else {
                return .system(size: size, weight: .regular, design: .serif)
            }
            return .custom(face, fixedSize: size)
        }
        if let face = FontFamily.availableFaces[weight.rawValue] {
            return .custom(face, fixedSize: size)
        }
        return .system(size: size, weight: weight.fontWeight)
    }

    /// Variant for `Text`, which cannot host the `@ScaledMetric` the view modifier uses.
    /// `relativeTo:` gets the same growth out of SwiftUI directly.
    static func sycamore(_ style: TypeStyle, scaledRelativeTo textStyle: Font.TextStyle) -> Font {
        if style.isMonospaced {
            return .system(style.textStyle, design: .monospaced).weight(style.weight.fontWeight)
        }
        if style.isSerif {
            guard let face = FontFamily.serifFace else {
                return .system(textStyle, design: .serif)
            }
            return .custom(face, size: style.size, relativeTo: textStyle)
        }
        if let face = FontFamily.availableFaces[style.weight.rawValue] {
            return .custom(face, size: style.size, relativeTo: textStyle)
        }
        return .system(textStyle).weight(style.weight.fontWeight)
    }
}

// MARK: - Applying a style

private struct TypeStyleModifier: ViewModifier {
    let style: TypeStyle
    let color: Color?

    /// The design's point size, grown by whatever the reader has asked for. Every text style
    /// in the app arrives here, so this one property is what makes the app respect Dynamic
    /// Type at all — before it, `Font.custom(_:fixedSize:)` and `Font.system(size:)` both
    /// pinned the size and the UI rendered identically at every setting.
    ///
    /// Tracking and line spacing are derived from the *unscaled* size on purpose: they are
    /// proportions of the design's drawn size, and scaling them again would compound.
    @ScaledMetric private var scaledSize: CGFloat

    init(style: TypeStyle, color: Color?) {
        self.style = style
        self.color = color
        self._scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.textStyle)
    }

    func body(content: Content) -> some View {
        let styled = content
            .font(.sycamore(size: scaledSize, weight: style.weight, monospaced: style.isMonospaced, serif: style.isSerif))
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .textCase(style.isUppercased ? .uppercase : nil)

        // Branching rather than `.foregroundStyle(color ?? .primary)`: passing no colour has
        // to leave the inherited style alone, and defaulting to `.primary` would quietly
        // repaint every call site that inherits its colour from an ancestor.
        if let color {
            styled.foregroundStyle(color)
        } else {
            styled
        }
    }
}

extension View {
    /// Applies size, weight, tracking, line spacing and casing in one go.
    ///
    /// The way to set type in this app, `Text` receivers included. `Text.typeStyleRun(_:color:)`
    /// below is the narrow exception, and it says why.
    func typeStyle(_ style: TypeStyle, color: Color? = nil) -> some View {
        modifier(TypeStyleModifier(style: style, color: color))
    }
}

extension Text {
    /// Size, weight and tracking on a single *run*, for the few places that need a `Text` back
    /// rather than a view — a field `prompt:`, or a styled fragment interpolated into a longer
    /// string:
    ///
    ///     let code = Text(camp.inviteCode).typeStyleRun(.monoInline)
    ///     Text("Share \(code) with your staff")
    ///
    /// Interpolate them like that rather than joining runs with `+`.
    ///
    /// **Deliberately not called `typeStyle`.** It was, and sharing the name was the bug. Swift
    /// resolves a member on the concrete type ahead of one reached through a protocol extension,
    /// so on a `Text` receiver — which is what nearly every call site in this app is — this
    /// overload won and `View.typeStyle(_:color:)` never ran. That quietly dropped the two
    /// modifiers `Text` has no equivalent for: `.lineSpacing` and `.textCase`.
    ///
    /// Casing was the visible loss. All 29 call sites on an `isUppercased` style sit on a
    /// `Text(…)` and not one uppercases its own string, so `.textCase(.uppercase)` in
    /// `TypeStyleModifier` was unreachable and every eyebrow in the app — `sectionHeader`,
    /// `badge`, `overline`, `overlineSmall`, `statLabel` — drew in sentence case. The design is
    /// unambiguous the other way: all 39 of its `text-transform` declarations are `uppercase`,
    /// each wrapping a sentence-case literal (`letter-spacing:.1em;text-transform:uppercase`
    /// around "Your camps"). The Swift literals were already right; only the plumbing was wrong.
    ///
    /// A distinct spelling cannot shadow anything, so taking the `Text` flavour is now a choice
    /// at the call site rather than an accident of resolution. Reach for it only when the result
    /// has to be a `Text` — `View.typeStyle(_:color:)` is the default everywhere else.
    ///
    /// **It still cannot case, and it now says so out loud.** `Text` has no `.textCase`, so an
    /// `isUppercased` style handed to this method draws in sentence case — which is exactly the
    /// bug the rename was written to kill, and `FormField` reopened the door by piping a
    /// caller-supplied `TypeStyle` straight through to a `prompt:`. Nothing passes an uppercase
    /// style today; the assertion is there so that the first thing that does finds out in a
    /// debug run rather than in a screenshot months later.
    ///
    /// Deliberately not `string.uppercased()` at this layer, which would have made the two paths
    /// structurally identical and was the obvious deeper fix. VoiceOver reads `.textCase` output
    /// from the *original* sentence-case string and reads a literal run of capitals letter by
    /// letter, so uppercasing here would trade a visible bug for an audible one at all 29 of the
    /// sites the `View` path serves correctly. Loud beats silent; both beat a regression.
    func typeStyleRun(_ style: TypeStyle, color: Color? = nil) -> Text {
        assert(
            !style.isUppercased,
            """
            typeStyleRun cannot apply .textCase, so this style will draw in sentence case. \
            Use View.typeStyle(_:color:) if the result can be a View, or uppercase the string \
            at the call site if it genuinely has to be a Text.
            """
        )
        var text = self
            .font(.sycamore(style, scaledRelativeTo: style.textStyle))
            .tracking(style.tracking)
        if let color {
            text = text.foregroundStyle(color)
        }
        return text
    }
}

// MARK: - Previews

#Preview("Type table") {
    let rows: [(String, TypeStyle)] = [
        ("display", .display), ("title1", .title1), ("title2", .title2),
        ("tabTitle", .tabTitle), ("profileName", .profileName), ("sheetTitle", .sheetTitle),
        ("venueHeading", .venueHeading), ("rowTitleLg", .rowTitleLg), ("rowTitle", .rowTitle),
        ("bodyStrong", .bodyStrong), ("body", .body), ("meta", .meta), ("chip", .chip),
        ("sectionHeader", .sectionHeader), ("badge", .badge), ("mono", .mono),
    ]

    return ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text(FontFamily.usesInstrumentSans ? "Instrument Sans is registered" : "System-font fallback")
                .typeStyle(.overline, color: Theme.inkMuted)

            ForEach(rows, id: \.0) { name, style in
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .typeStyle(.overline, color: Theme.inkFaint)
                    Text("Sign in, pick your camp")
                        .typeStyle(style, color: Theme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.hero)
    }
    .background(Theme.surface)
}
