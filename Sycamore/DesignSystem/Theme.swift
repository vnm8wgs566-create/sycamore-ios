//
//  Theme.swift
//  Sycamore
//
//  Colour, geometry and shadow tokens transcribed verbatim from the design's inline CSS
//  (`design/Sycamore Flow.dc.html`). Nothing here is rounded to a "nicer" value — if a token
//  reads 16.5 or 1.5 it is because the design draws it that way.
//
//  Feature code must never spell a hex literal. Add the token here instead.
//
//  The light column is the design, unchanged. The dark column is derived from it — the design
//  does not draw a dark scheme, and pinning the app to light rather than respecting the
//  reader's choice is not a decision the design was making. Deriving keeps one source of
//  truth: change a light token and its dark counterpart is right there beside it.
//

import SwiftUI

// MARK: - Hex

extension Color {
    /// Builds a colour from a CSS-style hex string: `RGB`, `RRGGBB` or `RRGGBBAA`,
    /// with or without a leading `#`. Invalid input resolves to opaque black so a typo is
    /// visible on screen rather than silently transparent.
    init(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }

        // Expand the 3-digit shorthand (`#abc` -> `#aabbcc`).
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }

        var value: UInt64 = 0
        guard Scanner(string: digits).scanHexInt64(&value) else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }

        let r, g, b, a: Double
        switch digits.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// A token that resolves per colour scheme.
    ///
    /// The design ships one palette, drawn light. Rather than invent a second design, each
    /// dark value is derived from its light counterpart: surfaces climb Apple's dark
    /// elevation ladder instead of going flat black, the ink ramp inverts but keeps its
    /// *relative* steps so hierarchy survives, and the accent brightens because `#1568F0`
    /// on a dark surface falls under 4.5:1.
    ///
    /// Resolved through the platform's trait system rather than by reading
    /// `@Environment(\.colorScheme)` at each call site, so a token still works inside
    /// `.fill()`, `.background()` and every other place that wants a plain `Color`.
    init(light: String, dark: String) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        self.init(hex: light)
        #endif
    }
}

// MARK: - Colour tokens

enum Theme {

    // MARK: Ink

    /// Primary text, dark buttons, active pill.
    static let ink = Color(light: "0B0B0C", dark: "F5F5F7")
    /// Secondary text, chip labels.
    static let inkSecondary = Color(light: "5C6068", dark: "A8ADB5")
    /// Body copy on light surfaces.
    static let inkTertiary = Color(light: "71757E", dark: "9AA0A8")
    /// Metadata, section headers.
    static let inkMuted = Color(light: "8A8E96", dark: "8E939B")
    /// Placeholders, disabled.
    static let inkFaint = Color(light: "A2A6AE", dark: "70747C")
    /// Rank numerals, caret glyphs.
    static let inkGhost = Color(light: "B0B4BB", dark: "5F636B")
    /// Disclosure carets, drag handles.
    static let chevron = Color(light: "C7CBD2", dark: "4B4F57")

    // MARK: Section 8's own greys
    //
    // Nine values the design uses that this palette had no name for. They were found by diffing
    // every hex in `Sycamore 3a System.dc.html` against every hex declared here, which is the
    // only way to know: a screen transcribed by eye reaches for the nearest existing token and
    // the drift is invisible one screen at a time.

    /// `#3F4A44` — the design's warm ink. 73 uses against `ink`'s 144.
    ///
    /// **Body and detail copy, not titles or names.** Measured across the document it is set at
    /// `400 14px` (26×), `400 13.5px` (23×) and `600 12.5px` (12×) — never above 15pt. And it is
    /// absent from about half of section 8 entirely: `8a`, `8b`, `8d`, `8f`, `8g`, `8h`, `8n`,
    /// `8q`, `8r`, `8s` and `8t` set every line in the inherited `ink`.
    ///
    /// Spelled out because the first description of this token said "field labels and names",
    /// which was generalised from three samples and was wrong. Two screens were audited against
    /// it and correctly refused to apply it. Reach for it only where the screen's own CSS says
    /// so — substituting it is the same class of error as substituting `ink` for it.
    ///
    /// A step *between* `ink` and `inkSecondary` in weight but green-tinted rather than neutral,
    /// which is what makes it warm — the brand's green showing through the type rather than a
    /// second grey. Where the design does use it, `ink` is not merely darker but colder.
    static let inkWarm = Color(light: "3F4A44", dark: "C8D2CC")

    /// `#B3B7BE` — a glyph on a plate. The design's icons are a step lighter than its text.
    static let glyph = Color(light: "B3B7BE", dark: "6C7078")
    /// `#D3D7DD` — a glyph that is present but inactive.
    static let glyphFaint = Color(light: "D3D7DD", dark: "55585F")

    /// `#F8F9F8` — a card that carries its own `rgba(0,0,0,.11)` border. Warmer than `grouped`,
    /// which is the page behind it.
    static let surfaceWarm = Color(light: "F8F9F8", dark: "1E1F1E")
    /// `#FAFBFA` — a row inside `surfaceWarm`, one step up again.
    static let surfaceRaised = Color(light: "FAFBFA", dark: "222322")
    /// `#F0F1F3` — the 44pt tile an icon sits on.
    static let tile = Color(light: "F0F1F3", dark: "2B2B2E")
    /// `#F3F5F4` — a `999`-radius pill's fill.
    static let pillFill = Color(light: "F3F5F4", dark: "27282A")

    /// `#F6FAF7` — a green-tinted plate. Distinct from `accentTint`, which is the fill *under*
    /// accent-coloured copy; this is a surface that happens to be warm, and the design pairs it
    /// with `accentSurfaceBorder` or with the dashed `accentBorder`.
    static let accentSurface = Color(light: "F6FAF7", dark: "16201A")
    /// `#E4EDE7` — the solid border around `accentSurface`.
    static let accentSurfaceBorder = Color(light: "E4EDE7", dark: "24352B")

    // MARK: Accent
    //
    // Green, from `Sycamore 3a System.dc.html` — `#1A7F55` is the single most-used colour in
    // that document after the ink ramp. It replaces the blue this app shipped with.
    //
    // The blue was never the design's; it was a stand-in from before the samara existed, and it
    // put two unrelated hues on every screen — a green mark beside a blue CTA. One green family
    // means the button, the selected tab and the logo are finally the same brand.
    //
    // It is also a shade darker than the blue against white: white-on-`1A7F55` measures 5.0:1,
    // where white-on-`1568F0` was 4.0:1. The old pair only cleared AA because button copy is
    // 16.5pt bold and counts as large text; this one clears it outright.
    //
    // Deliberately *not* `markGreen` (`14603C`). The mark is darker and desaturated so it reads
    // as a printed logo; an accent at that value looks muddy on a fill. Sibling hues, not one.

    /// Primary green — CTAs, selection, links.
    static let accent = Color(light: "1A7F55", dark: "4FB585")
    /// Pressed links, text on green tint.
    static let accentDark = Color(light: "14684A", dark: "7FD0A8")
    /// Green-tinted fills, info banners.
    static let accentTint = Color(light: "EDF6F1", dark: "162A20")
    /// Dashed / solid green borders.
    static let accentBorder = Color(light: "C3DFCF", dark: "27503C")
    /// App-mark glyph only.
    static let lime = Color(light: "CBFF3C", dark: "CBFF3C")

    // MARK: App mark
    //
    // From `Sycamore Logo v2.dc.html`. The mark is a sycamore samara — the winged seed that
    // spins as it falls — drawn as a filled wing over a seed head. All three fixed: a logo
    // that changes colour with the scheme is a different logo.

    /// The seed head and the wing's leading half.
    static let markGreen = Color(hex: "14603C")
    /// The wing's trailing half, a shade up so the two halves read apart at 24pt.
    static let markGreenLight = Color(hex: "3F7D53")
    /// The tile the mark sits on.
    static let markTile = Color(hex: "F7F5EF")
    /// Label on a filled `accent` button. Fixed white rather than `surface`, which inverts to
    /// near-black in the dark and put dark text on a blue fill. Button copy is 16.5pt bold —
    /// large text — so white over either accent clears the 3:1 the guidelines ask for there.
    static let onAccent = Color(hex: "FFFFFF")

    // MARK: Destructive

    /// Destructive text.
    static let danger = Color(light: "C0492A", dark: "FF7A5C")
    /// Destructive button border.
    static let dangerBorder = Color(light: "F0D9CE", dark: "5C3025")

    // MARK: Warning
    //
    // The design's third severity step, between "fine" and "destructive": Schedule's "Needs a
    // coach", Camp settings' "2 short", Overview's unassigned court. Things that are somebody's
    // problem this morning but nothing is broken and nothing is being deleted.
    //
    // Hoisted here rather than left in a feature because three separate screens reached for it
    // independently — and three private ambers is how a palette stops being one.
    //
    // The design uses it as a pill: `FAF6EC` fill, `8A6416` label, radius 99. That pair measures
    // 4.93:1, so it clears AA for normal text at the 11.5pt the design sets it in — which is why
    // the label is the dark end and not `warning` itself (that would be 2.9:1).

    /// The amber itself — an icon, a rule, or **plain text with no fill behind it**.
    ///
    /// That last case is the common one and is easy to get wrong: `8k`'s "Needs a coach" is
    /// `color:#B67A16` on a 13.5px line with nothing behind it, not a pill. The pill below
    /// appears in exactly four screens — `8d`, `8i`, `8j`, `8r`. Reach for the pair only there.
    static let warning = Color(light: "B67A16", dark: "E0A845")
    /// Label on `warningTint`. The dark end of the family.
    static let warningDark = Color(light: "8A6416", dark: "F0C97A")
    /// The pill fill behind `warningDark`.
    ///
    /// The design also contains a single `#FBF2E2` / `#8A5E0F` pair, one use each, against these
    /// nine and eleven. Treated as a stray rather than a second amber — a palette with two
    /// warnings is a palette with none.
    static let warningTint = Color(light: "FAF6EC", dark: "2A2213")
    /// `#F0E3C6` — the border around a card of rows that still need a detail. Rarer than the
    /// other three, and here rather than in a feature so the family cannot be split up again.
    static let warningBorder = Color(light: "F0E3C6", dark: "4C3E24")

    // MARK: Surfaces

    /// Cards, sheets, bars.
    static let surface = Color(light: "FFFFFF", dark: "1C1C1E")
    /// Grouped screen background.
    static let grouped = Color(light: "F6F7F9", dark: "0F0F11")
    /// Design-canvas backdrop (not used in-app; kept so preview frames can match the design).
    static let canvas = Color(light: "EDEEF0", dark: "0A0A0B")
    /// Circular icon buttons, inert chips, steppers.
    static let fill = Color(light: "F1F2F5", dark: "2C2C2E")
    /// Avatar placeholder.
    static let fillAlt = Color(light: "EFF0F3", dark: "29292B")

    // MARK: Lines

    /// Card borders.
    static let hairline = Color(light: "EDEEF1", dark: "2F2F32")
    /// Inner row dividers.
    static let hairlineSoft = Color(light: "F2F3F6", dark: "2A2A2D")
    /// List row dividers.
    static let hairlineFaint = Color(light: "F4F5F7", dark: "242427")
    /// Input borders (1.5px).
    static let stroke = Color(light: "E4E5E9", dark: "3B3B3E")
    /// Button / row borders (1px).
    static let strokeAlt = Color(light: "EAEBEE", dark: "323235")
    /// Unselected chip borders.
    static let strokeChip = Color(light: "E6E7EB", dark: "38383B")

    // MARK: Incidentals
    //
    // Colours the design uses in exactly one or two places. They are tokens all the same so
    // feature files stay hex-free.

    /// Search glyph and its placeholder copy.
    static let searchPlaceholder = Color(light: "9DA1A9", dark: "7E828C")
    /// Unselected tab-bar glyph.
    static let tabInactive = Color(light: "6E7178", dark: "9095A0")
    /// Tab-bar plate behind the blur, at 82% opacity.
    static let tabBarPlate = Color(light: "FAFAFB", dark: "2A2A2E").opacity(0.82)
    /// Subtitle under a filled call-to-action ("You become its first admin"). Sits *on* the
    /// accent fill, so it moved to green with it — the old blue-grey on a green button read as
    /// a rendering fault rather than as a quieter line.
    static let accentSubtle = Color(light: "8FC2A5", dark: "6FA98C")
    /// Subtitle inside the tinted call card ("Tap to call in an emergency"). Sits on
    /// `accentTint`, so it is the dark end of the green rather than the light end.
    static let accentMuted = Color(light: "4A8A69", dark: "8FCFAF")
    /// `#5C7A68` — the meta line under the venue you are standing in ("6 courts · 50 kids ·
    /// you're on Court 1", `design/rebuild/section-t4.html:150`).
    ///
    /// The third of these green-tinted greys, and the quietest. The plate under it is white; only
    /// its border is green, and the line follows that border about a fifth of the way. Measured
    /// against the ramp it is `inkSecondary` with 26 points poured into the green channel and
    /// nothing else moved (`5C6068` → `5C7A68`) — which is the whole of what the design does here.
    ///
    /// Not `accentMuted` (`#4A8A69`), which is a real green: substituted in, the venue's subtitle
    /// stops being a subtitle and becomes a second accent under its name, competing with the tick
    /// that is the only thing on the row meant to say "this one". Two values four hex digits apart
    /// doing opposite jobs is exactly why the diff that found this palette's other nine greys was
    /// worth running.
    ///
    /// The dark counterpart carries the same +26 of green over `inkSecondary`'s *own* dark value,
    /// so the two stay one matched step apart rather than drifting the first time either moves.
    /// 4.7:1 on white and 9.5:1 on the dark surface — it is body copy at 12.5pt and has to clear
    /// AA on its own, with no fill behind it to help.
    static let accentMeta = Color(light: "5C7A68", dark: "A8C7B5")
    /// The 1pt lip along the top edge of the tab-bar pill — `inset 0 1px 0 rgba(255,255,255,.95)`.
    /// Carries its alpha in the hex because the two schemes need different amounts of it: a
    /// 95% white lip on a dark plate reads as a seam rather than as a catch of light.
    static let tabBarLip = Color(light: "FFFFFFF2", dark: "FFFFFF24")
    /// Sheet grabber.
    static let grabber = Color(light: "DCDEE3", dark: "494A4E")
    /// Inactive dot on the history timeline.
    static let timelineDot = Color(light: "D9DBE0", dark: "47484C")
    /// Background of a collapsed run in Rank ("45 MORE IN SYCAMORE").
    static let runBackground = Color(light: "FAFAFB", dark: "2A2A2E")
    /// Dimmed backdrop behind a presented sheet.
    ///
    /// Deliberately *not* scheme-adaptive. A scrim's job is to push the layer beneath it
    /// back; inverting it to near-white in the dark would lay a pale veil over dark content
    /// and read as a rendering fault rather than as depth.
    static let scrim = Color(hex: "0B0B0C").opacity(0.36)
    /// Destructive tint, used behind danger badges. Derived, not drawn in the design.
    static let dangerTint = Color(light: "C0492A", dark: "FF7A5C").opacity(0.10)
    /// Device bezel stroke used by the design's preview frames. Fixed for the same reason as
    /// `scrim` — it stands in for hardware, which does not change colour with the scheme.
    static let bezel = Color(hex: "0B0B0C").opacity(0.11)
}

// MARK: - Venue tints

extension Theme {
    /// The tile behind a venue's emoji, resolved from the venue's own `tint` — never from its
    /// emoji. `VenueTint` is a semantic case carrying no colour, so every venue hex the app
    /// draws is here, and every venue tile in the app (Setup, Profile, the camp picker) comes
    /// out of this one function.
    ///
    /// - `moss` `#F1F5EC` — Sycamore's 🌳 tile.
    /// - `sky` `#EDF3FE` — Westside's 🏊 tile. This *was* the same value as `accentTint`, kept
    ///   spelled out rather than aliased "because the two roles are free to drift". They have:
    ///   the accent is green now, and sky stayed blue because it means water, not brand.
    /// - `citron` `#F7F9E9` — LATC's 🎾 tile.
    ///
    /// The venue sheet's other icons (🏆 🔥 ⭐ 🌊) reach one of these three through
    /// `VenueTint.suggested(for:)`, so no venue ever falls back to neutral grey.
    static func color(for tint: VenueTint) -> Color {
        switch tint {
        case .moss:   Color(light: "F1F5EC", dark: "1B211A")
        case .sky:    Color(light: "EDF3FE", dark: "16243A")
        case .citron: Color(light: "F7F9E9", dark: "22241A")
        }
    }
}

// MARK: - Radii

enum Radius {
    /// Device bezel in the design frames.
    static let device: CGFloat = 36
    /// Sheet top corners.
    static let sheet: CGFloat = 24
    /// Large cards (`YOUR CAMPS`, `Create a camp`).
    static let cardLarge: CGFloat = 18
    /// Standard card.
    static let card: CGFloat = 17
    /// Full-width buttons.
    static let button: CGFloat = 16
    /// Inputs, OTP cells, single-row cards.
    static let input: CGFloat = 15
    /// Action rows in sheets, venue icon tiles.
    static let row: CGFloat = 14
    /// Stat tiles, search field, sheet fields.
    static let tile: CGFloat = 13
    /// Square-ish selectable chips (day, role).
    static let chipSquare: CGFloat = 12
    /// Stepper track, small status banner.
    static let control: CGFloat = 11
    /// Inline banner inside a card.
    static let banner: CGFloat = 10
    /// Stepper +/- buttons.
    static let stepperButton: CGFloat = 9
    /// Mono court chip (`🌳 C1`).
    static let monoChip: CGFloat = 7
    /// Badge.
    static let badge: CGFloat = 5
    /// Pills and circles.
    static let pill: CGFloat = 999
}

// MARK: - Spacing

enum Spacing {
    /// Horizontal padding for screen bars and headers.
    static let bar: CGFloat = 16
    /// Gutter either side of a grouped card.
    static let gutter: CGFloat = 12
    /// Wider grouped gutter used by the stage-1 screens.
    static let gutterWide: CGFloat = 14
    /// Horizontal padding inside a sheet.
    static let sheet: CGFloat = 18
    /// Horizontal padding on the full-bleed stage-1 screens (sign in, verify).
    static let hero: CGFloat = 24
    /// Horizontal padding inside a white header block.
    static let header: CGFloat = 22
    /// Distance from the bottom safe area to the floating tab bar.
    static let tabBarInset: CGFloat = 22
    /// Clearance a scroll view needs at the bottom so content clears the floating tab bar.
    static let tabBarClearance: CGFloat = 92

    // Generic scale, named for how the design uses each step.
    static let hairGap: CGFloat = 2
    static let tight: CGFloat = 6
    static let small: CGFloat = 8
    static let row: CGFloat = 11
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let section: CGFloat = 22
}

// MARK: - Border widths

enum BorderWidth {
    /// Card and row borders.
    static let hairline: CGFloat = 1
    /// Inputs and unselected states.
    static let input: CGFloat = 1.5
    /// Focused OTP cell.
    static let focus: CGFloat = 2
    /// Camera badge ring on the profile avatar.
    static let avatarRing: CGFloat = 2.5
    /// The 0.5px ring around the floating tab bar.
    static let ring: CGFloat = 0.5
    /// The 1.5pt black rule under a venue heading in Rank.
    static let rule: CGFloat = 1.5
    /// The 2.5pt blue drop-indicator bar in Rank.
    static let insertion: CGFloat = 2.5
}

// MARK: - Shadows

/// A CSS `box-shadow` restated for SwiftUI. CSS blur radius is roughly twice SwiftUI's, so
/// `blur: 36` in the design becomes `radius: 18` here.
struct ShadowToken: Sendable {
    var color: Color
    var radius: CGFloat
    var x: CGFloat = 0
    var y: CGFloat
}

enum Shadows {

    /// Shadows are cast, not drawn, so they are pinned to the design's near-black rather than
    /// built from `Theme.ink`. `ink` inverts with the scheme, which turned every shadow in the
    /// app into a pale bloom in the dark — the tab bar wore a visible white halo. A shadow
    /// only ever darkens what is under it.
    ///
    /// They are also carried a little heavier in the dark, where a 17% shadow over a near-black
    /// surface is invisible and the pill loses the lift the design gives it.
    private static let cast = Color(hex: "000000")

    /// `0 12px 36px rgba(11,11,12,.17)` — the floating tab bar.
    static let tabBar = ShadowToken(color: cast.opacity(0.30), radius: 18, y: 12)
    /// `0 2px 9px rgba(11,11,12,.11)` — the selected tab capsule.
    static let tabItem = ShadowToken(color: cast.opacity(0.18), radius: 4.5, y: 2)
    /// `0 12px 28px rgba(11,11,12,.16)` — a row lifted for dragging in Rank.
    static let liftedRow = ShadowToken(color: cast.opacity(0.28), radius: 14, y: 12)

    /// `0 -12px 40px rgba(11,11,12,.18)` — the cast a bottom sheet throws *up* the screen
    /// (`design/rebuild/section-t4.html:143`, and the same line on every sheet in sections 4 and 5).
    ///
    /// The only negative `y` in the file, because it is the only shadow whose caster is pinned to
    /// the bottom edge of the frame: everything below the plate is off-screen, so the whole of this
    /// shadow is the seam along the top of the sheet and none of it is wasted under one.
    ///
    /// Alpha left at the design's `.18` rather than carried up the way the three above are. Those
    /// are cast onto `grouped` — a near-white page, where the design's own alpha all but vanishes.
    /// This one lands on `Theme.scrim`, which is already `0B0B0C` at 36% and, being deliberately
    /// non-adaptive, is that in both schemes. There is no pale backdrop to lose it against, and
    /// doubling it would read as a thicker scrim rather than as a higher sheet.
    static let sheetLift = ShadowToken(color: cast.opacity(0.18), radius: 20, y: -12)
}

extension View {
    func shadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

// MARK: - Previews

#Preview("Colour tokens") {
    let swatches: [(String, Color)] = [
        ("ink", Theme.ink), ("inkSecondary", Theme.inkSecondary),
        ("inkTertiary", Theme.inkTertiary), ("inkMuted", Theme.inkMuted),
        ("inkFaint", Theme.inkFaint), ("inkGhost", Theme.inkGhost),
        ("chevron", Theme.chevron), ("accent", Theme.accent),
        ("accentDark", Theme.accentDark), ("accentTint", Theme.accentTint),
        ("accentBorder", Theme.accentBorder), ("accentMeta", Theme.accentMeta),
        ("lime", Theme.lime),
        ("danger", Theme.danger), ("dangerBorder", Theme.dangerBorder),
        ("surface", Theme.surface), ("grouped", Theme.grouped),
        ("canvas", Theme.canvas), ("fill", Theme.fill),
        ("fillAlt", Theme.fillAlt), ("hairline", Theme.hairline),
        ("hairlineSoft", Theme.hairlineSoft), ("hairlineFaint", Theme.hairlineFaint),
        ("stroke", Theme.stroke), ("strokeAlt", Theme.strokeAlt),
        ("strokeChip", Theme.strokeChip),
    ]

    let venueSwatches: [(String, Color)] = VenueTint.allCases.map {
        (String(describing: $0), Theme.color(for: $0))
    }

    return ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(swatches + venueSwatches, id: \.0) { name, color in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .fill(color)
                        .frame(height: 46)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                .stroke(Theme.strokeAlt, lineWidth: BorderWidth.hairline)
                        }
                    Text(name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
        }
        .padding(Spacing.bar)
    }
    .background(Theme.grouped)
}
