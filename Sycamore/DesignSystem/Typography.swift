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
/// Instrument Sans' weight axis runs 400–700, and the design asks Google Fonts for exactly
/// `wght@400..700`. `extraBold` therefore has no face of its own and resolves to the 700 one.
/// That is a correction rather than a compromise: 800 is left over from when this app was set
/// in Manrope, and the design document does not use it anywhere — its weights are 400 (360
/// uses), 500 (91), 600 (419) and 700 (38).
///
/// The case is kept rather than folded into `bold` so the seventeen heading styles that name it
/// keep reading as "the heaviest weight there is", and so a family that does ship 800 would
/// light up by editing this one file. Both the bundled-face path and the system fallback map it
/// to bold, so the two never disagree about how heavy a heading is.
enum TypeWeight: Int, CaseIterable, Sendable {
    case regular = 400
    case medium = 500
    case semibold = 600
    case bold = 700
    case extraBold = 800

    var fontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        // Not `.heavy`: the bundled face tops out at 700, and a fallback heavier than the real
        // font would make the missing-font state look *bolder* than the shipped one.
        case .bold, .extraBold: .bold
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
        case .bold, .extraBold: "InstrumentSans-Regular_Bold"
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
}

// MARK: - The type table
//
// KNOWN, MEASURED, AND NOT YET FIXED: this table is a step or two too heavy for section 8.
//
// It was transcribed from the earlier design, and section 8 sets the same roles lighter
// throughout. Counted across section 8's own declarations:
//
//     17px    600, 22 of 22          here: extraBold / bold
//     16px    600,  9 of  9          here: extraBold / bold
//     15px    600, 11 of 11          here: extraBold ×3, bold ×2
//     14px    600, 50 of 71
//     13.5px  400, 38 of 44          here: medium
//     13px    400, 61 of 79
//     10.5px  600, 57 of 57          here: bold
//
// Four separate exactness passes reported this independently — "the nearest row of the table
// rather than the design's own shorthand", "section 8 sets its type a half-step lighter than
// stage 1", "recurs about a dozen times". Each compensated locally, in its own folder, which is
// the wrong altitude: a dozen private overrides of a shared table is how the table stops being
// shared.
//
// Deliberately not changed here yet. Seven exactness pull requests are open against these
// styles, and correcting the table underneath them would both conflict with all seven and
// double-correct the screens that already compensated. It is one focused pass once they land,
// where the local overrides come out in the same commit that fixes the table.
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
    /// `800 17`, `-.03em` — venue heading in Rank.
    static let venueHeading = TypeStyle(size: 17, weight: .extraBold, trackingEm: -0.03)
    /// `800 16.5`, `-.028em` — coach name, camp name.
    static let rowTitleLg = TypeStyle(size: 16.5, weight: .extraBold, trackingEm: -0.028)
    /// `800 16`, `-.025em`.
    static let rowTitle = TypeStyle(size: 16, weight: .extraBold, trackingEm: -0.025)
    /// `700 15`, `-.02em` — player name, setting label.
    static let bodyStrong = TypeStyle(size: 15, weight: .bold, trackingEm: -0.02)
    /// `500 14.5/1.5` — descriptive copy.
    static let body = TypeStyle(size: 14.5, weight: .medium, lineHeightMultiple: 1.5)
    /// `500 12` — "13 · F · returning".
    static let meta = TypeStyle(size: 12, weight: .medium)
    /// `700 13` — sport chips, time pills.
    static let chip = TypeStyle(size: 13, weight: .bold)
    /// `700 11`, `+.1em`, uppercase — "YOUR CAMPS".
    static let sectionHeader = TypeStyle(size: 11, weight: .bold, trackingEm: 0.1, isUppercased: true)
    /// `700 9.5`, uppercase — "Away", "In range", "Worker".
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
    /// `700 15`, `-.01em` — the 9:41 in the mock status bar.
    static let statusTime = TypeStyle(size: 15, weight: .bold, trackingEm: -0.01)
    /// `700 13.5` — selected tab label.
    static let tabLabel = TypeStyle(size: 13.5, weight: .bold)

    // Buttons
    /// `700 16.5`, `-.015em` — "Continue with Apple", "Email me a code".
    static let buttonLarge = TypeStyle(size: 16.5, weight: .bold, trackingEm: -0.015)
    /// `700 16`, `-.015em` — "Create camp".
    static let button = TypeStyle(size: 16, weight: .bold, trackingEm: -0.015)
    /// `700 15` — "Join", the early-pick-up confirm bar.
    static let buttonSmall = TypeStyle(size: 15, weight: .bold)
    /// `700 14` — "Sign out", "Delete account", "Remove from camp".
    static let buttonCompact = TypeStyle(size: 14, weight: .bold)

    // Fields
    /// `800 17`, `-.025em` — the camp-name field's value.
    static let fieldTitle = TypeStyle(size: 17, weight: .extraBold, trackingEm: -0.025)
    /// `500 15.5` — the email field's value / placeholder.
    static let fieldValue = TypeStyle(size: 15.5, weight: .medium)
    /// `500 15` — the search field's placeholder.
    static let searchValue = TypeStyle(size: 15, weight: .medium)
    /// `800 26`, `-.03em` — a filled OTP cell.
    static let otpDigit = TypeStyle(size: 26, weight: .extraBold, trackingEm: -0.03)

    // Copy
    /// `500 14/1.5` — "Signed in as …".
    static let bodyAlt = TypeStyle(size: 14, weight: .medium, lineHeightMultiple: 1.5)
    /// `500 13/1.55` — the Rank header's explainer.
    static let bodySmall = TypeStyle(size: 13, weight: .medium, lineHeightMultiple: 1.55)
    /// `500 13` — sheet subtitles.
    static let sheetSubtitle = TypeStyle(size: 13, weight: .medium)
    /// `500 12.5/1.5` — centred footnotes under a CTA.
    static let footnote = TypeStyle(size: 12.5, weight: .medium, lineHeightMultiple: 1.5)
    /// `500 12.5/1.55` — copy inside an info banner.
    static let caption = TypeStyle(size: 12.5, weight: .medium, lineHeightMultiple: 1.55)
    /// `600 11.5` — the "or" divider label.
    static let dividerLabel = TypeStyle(size: 11.5, weight: .semibold)
    /// `600 13` — "Resend in 0:42".
    static let countdown = TypeStyle(size: 13, weight: .semibold)

    // Rows
    /// `800 15`, `-.02em` — venue name in a Groups section header.
    static let venueRow = TypeStyle(size: 15, weight: .extraBold, trackingEm: -0.02)
    /// `700 14.5`, `-.02em` — account row title, sheet action row title.
    static let rowLabel = TypeStyle(size: 14.5, weight: .bold, trackingEm: -0.02)
    /// `500 12.5` — account row value.
    static let rowSubtitle = TypeStyle(size: 12.5, weight: .medium)
    /// `500 11.5` — the venue sheet's limits sub-copy.
    static let rowSubtitleSmall = TypeStyle(size: 11.5, weight: .medium)
    /// `600 12.5` — "Court 1 · 8 here", "50 kids", "Coach · Sycamore, Court 3".
    static let metaStrong = TypeStyle(size: 12.5, weight: .semibold)
    /// `600 12` — "1–50", inline banner copy.
    static let metaSmall = TypeStyle(size: 12, weight: .semibold)
    /// `700 13` — rank numerals.
    static let rankNumeral = TypeStyle(size: 13, weight: .bold)

    // Overlines
    /// `600 11`, `+.08em`, uppercase — "HIGHER LEVEL".
    static let venueLabel = TypeStyle(size: 11, weight: .semibold, trackingEm: 0.08, isUppercased: true)
    /// `600 11.5`, `+.06em`, uppercase — a staff row's role, "45 MORE IN SYCAMORE".
    static let overline = TypeStyle(size: 11.5, weight: .semibold, trackingEm: 0.06, isUppercased: true)

    // Sheets
    /// `800 21`, `-.03em` — the staff sheet's title, which sits beside an avatar.
    static let sheetTitleSm = TypeStyle(size: 21, weight: .regular, trackingEm: -0.02, isSerif: true)
    /// `700 10`, `+.09em`, uppercase — stat tile label.
    static let statLabel = TypeStyle(size: 10, weight: .bold, trackingEm: 0.09, isUppercased: true)
    /// `800 20`, `-.03em` — stat tile value.
    static let statValue = TypeStyle(size: 20, weight: .extraBold, trackingEm: -0.03)
    /// `800 15` — the stepper's value, the venue sheet's `4 – 7`.
    static let stepperValue = TypeStyle(size: 15, weight: .extraBold)
    /// `600 13.5` — a history entry's title.
    static let timelineTitle = TypeStyle(size: 13.5, weight: .semibold)
    /// `500 11.5` — a history entry's byline.
    static let timelineMeta = TypeStyle(size: 11.5, weight: .medium)

    // Chips
    /// `700 12.5` — venue filter chips, "Even out", "Add" / "Invite".
    static let chipMedium = TypeStyle(size: 12.5, weight: .bold)
    /// `700 12` — staff filter chips.
    static let chipCompact = TypeStyle(size: 12, weight: .bold)
    /// `600 12` — attribute chips ("Everyone", "Boys").
    static let chipSmall = TypeStyle(size: 12, weight: .semibold)
    /// `600 12.5` — court chips in the staff sheet.
    static let chipSoft = TypeStyle(size: 12.5, weight: .semibold)

    // Mono
    /// `700 12.5`, `+.06em` — the invite code inline in Setup's subtitle.
    static let monoInline = TypeStyle(size: 12.5, weight: .bold, trackingEm: 0.06, isMonospaced: true)
    /// `700 17`, `+.18em` — the join-with-a-code input.
    static let monoInput = TypeStyle(size: 17, weight: .bold, trackingEm: 0.18, isMonospaced: true)

    /// Initials sized for an avatar of `diameter`. The design does not use a constant ratio —
    /// the 36 and 44pt avatars are 700, the 46 and 72pt ones are 800 — so this is a lookup with
    /// a proportional tail for anything larger.
    static func initials(forAvatarSize diameter: CGFloat) -> TypeStyle {
        switch diameter {
        case ..<40: TypeStyle(size: 12, weight: .bold)
        case ..<46: TypeStyle(size: 13.5, weight: .bold)
        case ..<60: TypeStyle(size: 15, weight: .extraBold)
        default: TypeStyle(size: (diameter * 0.305).rounded(), weight: .extraBold)
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
    func typeStyle(_ style: TypeStyle, color: Color? = nil) -> some View {
        modifier(TypeStyleModifier(style: style, color: color))
    }
}

extension Text {
    /// `Text`-flavoured variant, for the places that need a `Text` rather than a `View` — a
    /// field `prompt:`, or a styled run interpolated into another string:
    ///
    ///     let code = Text(camp.inviteCode).typeStyle(.monoInline)
    ///     Text("Share \(code) with your staff")
    ///
    /// Interpolate them like that rather than joining runs with `+`.
    ///
    /// Line spacing and casing have no `Text` equivalent — reach for `View.typeStyle(_:)` when
    /// the copy is multi-line, and uppercase the string yourself for `.sectionHeader`/`.badge`.
    func typeStyle(_ style: TypeStyle, color: Color? = nil) -> Text {
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
