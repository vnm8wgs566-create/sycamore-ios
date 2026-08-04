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

    // MARK: Accent

    /// Primary blue — CTAs, selection, links.
    static let accent = Color(light: "1568F0", dark: "4C93FF")
    /// Pressed links, text on blue tint.
    static let accentDark = Color(light: "0F4FC0", dark: "7FB0FF")
    /// Blue-tinted fills, info banners.
    static let accentTint = Color(light: "EDF3FE", dark: "16243A")
    /// Dashed / solid blue borders.
    static let accentBorder = Color(light: "C9DDFB", dark: "27425F")
    /// App-mark glyph only.
    static let lime = Color(light: "CBFF3C", dark: "CBFF3C")
    /// The tile the app mark sits on. Fixed, unlike `ink`: a logo that flips from black to
    /// white with the scheme is a different logo, and the lime ball is drawn to sit on dark.
    static let markTile = Color(hex: "0B0B0C")
    /// Label on a filled `accent` button. Fixed white rather than `surface`, which inverts to
    /// near-black in the dark and put dark text on a blue fill. Button copy is 16.5pt bold —
    /// large text — so white over either accent clears the 3:1 the guidelines ask for there.
    static let onAccent = Color(hex: "FFFFFF")

    // MARK: Destructive

    /// Destructive text.
    static let danger = Color(light: "C0492A", dark: "FF7A5C")
    /// Destructive button border.
    static let dangerBorder = Color(light: "F0D9CE", dark: "5C3025")

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
    /// Subtitle under a blue call-to-action ("You become its first admin").
    static let accentSubtle = Color(light: "7FA3E0", dark: "6E8FC8")
    /// Subtitle inside the blue call card ("Tap to call in an emergency").
    static let accentMuted = Color(light: "5B7FC0", dark: "8FB0E8")
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
    /// - `sky` `#EDF3FE` — Westside's 🏊 tile. The same value as `accentTint`; the design
    ///   reuses it here, and it is spelled out rather than aliased because the two roles are
    ///   free to drift.
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
        ("accentBorder", Theme.accentBorder), ("lime", Theme.lime),
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
