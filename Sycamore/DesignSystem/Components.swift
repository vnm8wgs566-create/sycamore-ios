//
//  Components.swift
//  Sycamore
//
//  The primitives every screen is built from. Metrics come straight out of the design's inline
//  CSS; where a component has more than one incarnation in the design (chips especially) the
//  variants are exposed as named metric presets rather than as magic numbers at the call site.
//

import SwiftUI

// MARK: - Touch target

/// The 44pt minimum touch target. Several of the design's controls are drawn smaller than
/// that — a 34×32 stepper button, a 32pt close disc — and shrinking them is not an option
/// without redrawing the design. Where that happens the drawn size is left exactly as the
/// design has it and only the frame that takes the tap is grown to this.
enum HitTarget {
    static let minimum: CGFloat = 44
}

// MARK: - Hairline

/// A one-device-pixel rule. `Divider()` is not used anywhere because the design's rules are
/// exact colours at exact thicknesses.
struct Hairline: View {
    var color: Color = Theme.hairlineSoft
    var thickness: CGFloat = BorderWidth.hairline

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
    }
}

/// The 38×4 grabber every sheet in the design draws above its title.
struct SheetGrabber: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Theme.grabber)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 9)
            .padding(.bottom, 2)
    }
}

/// The caret that closes almost every row in the design.
struct DisclosureChevron: View {
    var systemName: String = "chevron.right"
    var size: CGFloat = 16
    var color: Color = Theme.chevron

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
    }
}

// MARK: - Section header

/// `700 11 / +.1em / uppercase`, with the design's optional count and trailing action.
/// Carries its own `0 4px 9px` padding so callers only supply the surrounding gutter.
struct SectionHeader: View {
    let title: String
    var count: Int?
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, count: Int? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.count = count
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(spacing: 5) {
                Text(title)
                    .typeStyle(.sectionHeader, color: Theme.inkMuted)
                if let count {
                    Text("\(count)")
                        .typeStyle(.sectionHeader, color: Theme.chevron)
                }
            }

            Spacer(minLength: 0)

            if let actionTitle {
                Button(action: { action?() }) {
                    Text(actionTitle)
                        .typeStyle(.chipMedium, color: Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 9)
    }
}

// MARK: - Card

/// White surface, 1px `hairline` border, radius 17, contents clipped.
///
/// By default the card divides its children with the inner `hairlineSoft` rule the design uses
/// — between rows, never above the first. Pass `isDivided: false` for a card that holds a
/// single block of content.
struct Card<Content: View>: View {
    var radius: CGFloat
    var background: Color
    var borderColor: Color
    var borderWidth: CGFloat
    var dividerColor: Color
    var isDivided: Bool
    @ViewBuilder var content: Content

    init(
        radius: CGFloat = Radius.card,
        background: Color = Theme.surface,
        borderColor: Color = Theme.hairline,
        borderWidth: CGFloat = BorderWidth.hairline,
        dividerColor: Color = Theme.hairlineSoft,
        isDivided: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.background = background
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.dividerColor = dividerColor
        self.isDivided = isDivided
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        // `SwiftUI.` qualified because `Models.swift` declares a domain `Group`.
        return SwiftUI.Group {
            if isDivided {
                DividedStack(color: dividerColor) { content }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(shape)
        .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth) }
    }
}

/// Stacks its children vertically and slips a rule between each adjacent pair. Uses the
/// variadic-view tree so callers can keep writing plain `VStack`-style content and still get
/// "divider between rows, none above the first".
struct DividedStack<Content: View>: View {
    var color: Color = Theme.hairlineSoft
    var thickness: CGFloat = BorderWidth.hairline
    @ViewBuilder var content: Content

    init(color: Color = Theme.hairlineSoft, thickness: CGFloat = BorderWidth.hairline, @ViewBuilder content: () -> Content) {
        self.color = color
        self.thickness = thickness
        self.content = content()
    }

    var body: some View {
        _VariadicView.Tree(Layout(color: color, thickness: thickness)) {
            content
        }
    }

    private struct Layout: _VariadicView_UnaryViewRoot {
        let color: Color
        let thickness: CGFloat

        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            let first = children.first?.id
            VStack(spacing: 0) {
                ForEach(children) { child in
                    if child.id != first {
                        Hairline(color: color, thickness: thickness)
                    }
                    child
                }
            }
        }
    }
}

/// One row inside a `Card`. Supplies the design's default 13pt gutter and 11pt inter-element
/// spacing; the content builder holds whatever the row is made of.
struct CardRow<Content: View>: View {
    var spacing: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var alignment: VerticalAlignment
    @ViewBuilder var content: Content

    init(
        spacing: CGFloat = 11,
        horizontalPadding: CGFloat = 13,
        verticalPadding: CGFloat = 13,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

// MARK: - Chip

enum ChipTone: Sendable {
    /// Black fill, white label — the primary selected state (venue and sport filters).
    case dark
    /// Blue fill, white label — the selected day chip and court chip.
    case accent
    /// `accentTint` fill with the soft `accentBorder` — the "Everyone" attribute chip.
    case tinted
    /// `accentTint` fill with a full-strength `accent` border — the selected time pill.
    case tintedBold
    /// The unselected state: white fill, grey border, `inkSecondary` label.
    case outline
}

/// Padding, corner and font for a family of chips. The design uses six slightly different
/// chips; each is a preset here rather than a set of literals at the call site.
struct ChipMetrics: Sendable {
    var font: TypeStyle
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var radius: CGFloat
    var spacing: CGFloat
    /// Border drawn in the unselected state — `strokeChip` for round filter chips,
    /// `strokeAlt` for the chips that live inside sheets.
    var unselectedBorder: Color
    /// Point size of the leading emoji. The design sets this per chip rather than deriving it
    /// from the label: Groups' venue chip lifts the emoji to 15 on a 12.5 label, while Setup's
    /// staff chip runs the emoji inline in the label's own 12. Every preset therefore states
    /// the number the design draws.
    var emojiSize: CGFloat

    /// Groups' venue filter — `700 12.5`, `7/13`, pill, emoji 15.
    static let venue = ChipMetrics(font: .chipMedium, horizontalPadding: 13, verticalPadding: 7,
                                   radius: Radius.pill, spacing: 7, unselectedBorder: Theme.strokeChip,
                                   emojiSize: 15)
    /// Groups' attribute filter — `600 12`, `6/12`, pill.
    static let attribute = ChipMetrics(font: .chipSmall, horizontalPadding: 12, verticalPadding: 6,
                                       radius: Radius.pill, spacing: 6, unselectedBorder: Theme.strokeChip,
                                       emojiSize: 12)
    /// New camp's sport picker — `700 13`, `9/15`, pill.
    static let sport = ChipMetrics(font: .chip, horizontalPadding: 15, verticalPadding: 9,
                                   radius: Radius.pill, spacing: 7, unselectedBorder: Theme.strokeChip,
                                   emojiSize: 13)
    /// Setup's staff filter — `700 12`, `7/13`, pill, emoji at the label's own 12.
    static let staffFilter = ChipMetrics(font: .chipCompact, horizontalPadding: 13, verticalPadding: 7,
                                         radius: Radius.pill, spacing: 6, unselectedBorder: Theme.strokeChip,
                                         emojiSize: 12)
    /// Early pick-up's time pills — `700 13`, `9/14`, pill.
    static let time = ChipMetrics(font: .chip, horizontalPadding: 14, verticalPadding: 9,
                                  radius: Radius.pill, spacing: 6, unselectedBorder: Theme.strokeAlt,
                                  emojiSize: 13)
    /// The staff sheet's court chips — `600 12.5`, `8/12`, pill, emoji inline at 12.5.
    static let court = ChipMetrics(font: .chipSoft, horizontalPadding: 12, verticalPadding: 8,
                                   radius: Radius.pill, spacing: 6, unselectedBorder: Theme.strokeAlt,
                                   emojiSize: 12.5)
    /// Early pick-up's Mon–Fri chips — `700 13`, `12` vertical, radius 12, equal widths.
    static let day = ChipMetrics(font: .chip, horizontalPadding: 0, verticalPadding: 12,
                                 radius: Radius.chipSquare, spacing: 6, unselectedBorder: Theme.strokeAlt,
                                 emojiSize: 13)
    /// The staff sheet's role chips — `700 12.5`, `11` vertical, radius 12, equal widths.
    static let role = ChipMetrics(font: .chipMedium, horizontalPadding: 0, verticalPadding: 11,
                                  radius: Radius.chipSquare, spacing: 6, unselectedBorder: Theme.strokeAlt,
                                  emojiSize: 12.5)
}

/// A selectable chip: optional leading emoji, a label, and an optional trailing count drawn at
/// 55% opacity the way the design does it.
struct Chip: View {
    let title: String
    var emoji: String?
    var count: Int?
    var isSelected: Bool = false
    /// The tone the chip takes when selected. Unselected always renders as `.outline`.
    var selectedTone: ChipTone = .dark
    var metrics: ChipMetrics = .venue
    /// Set for chips laid out in an equal-width row (Mon–Fri, Admin/Worker/Trainer/Other).
    var fillsWidth: Bool = false
    var action: (() -> Void)?

    init(
        _ title: String,
        emoji: String? = nil,
        count: Int? = nil,
        isSelected: Bool = false,
        selectedTone: ChipTone = .dark,
        metrics: ChipMetrics = .venue,
        fillsWidth: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.emoji = emoji
        self.count = count
        self.isSelected = isSelected
        self.selectedTone = selectedTone
        self.metrics = metrics
        self.fillsWidth = fillsWidth
        self.action = action
    }

    private var tone: ChipTone { isSelected ? selectedTone : .outline }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)

        let label = HStack(spacing: metrics.spacing) {
            if let emoji {
                Text(emoji)
                    .font(.system(size: metrics.emojiSize))
            }
            Text(title)
                .typeStyle(metrics.font)
            if let count {
                Text("\(count)")
                    .typeStyle(metrics.font)
                    .opacity(0.55)
            }
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.verticalPadding)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .background(background, in: shape)
        .overlay { shape.strokeBorder(border, lineWidth: BorderWidth.hairline) }
        .contentShape(shape)

        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var foreground: Color {
        switch tone {
        case .dark, .accent: Theme.surface
        case .tinted, .tintedBold: Theme.accentDark
        case .outline: Theme.inkSecondary
        }
    }

    private var background: Color {
        switch tone {
        case .dark: Theme.ink
        case .accent: Theme.accent
        case .tinted, .tintedBold: Theme.accentTint
        case .outline: Theme.surface
        }
    }

    private var border: Color {
        switch tone {
        case .dark: Theme.ink
        case .accent, .tintedBold: Theme.accent
        case .tinted: Theme.accentBorder
        case .outline: metrics.unselectedBorder
        }
    }
}

// MARK: - Buttons

/// Fill and label tone shared by `Pill` and `PrimaryButton`.
enum ButtonTone: Sendable {
    case dark
    case accent
    /// White fill, `hairline` border, `inkSecondary` label — "Sign out".
    case outline
    /// White fill, `dangerBorder` border, `danger` label — "Delete account".
    case danger
}

private extension ButtonTone {
    var background: Color {
        switch self {
        case .dark: Theme.ink
        case .accent: Theme.accent
        case .outline, .danger: Theme.surface
        }
    }

    var foreground: Color {
        switch self {
        // `.dark` fills with `ink`, which inverts, so `surface` inverts with it and the pair
        // stays legible. `.accent` fills with a blue that does *not* invert, so its label has
        // to be pinned or it turns dark-on-blue in the dark scheme.
        case .dark: Theme.surface
        case .accent: Theme.onAccent
        case .outline: Theme.inkSecondary
        case .danger: Theme.danger
        }
    }

    var border: Color? {
        switch self {
        case .dark, .accent: nil
        case .outline: Theme.hairline
        case .danger: Theme.dangerBorder
        }
    }
}

/// The small capsule button in a header — "Even out", "Join".
struct Pill: View {
    let title: String
    var tone: ButtonTone = .dark
    var systemImage: String?
    var font: TypeStyle = .chipMedium
    var horizontalPadding: CGFloat = 15
    var verticalPadding: CGFloat = 9
    let action: () -> Void

    init(
        _ title: String,
        tone: ButtonTone = .dark,
        systemImage: String? = nil,
        font: TypeStyle = .chipMedium,
        horizontalPadding: CGFloat = 15,
        verticalPadding: CGFloat = 9,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
        self.font = font
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: font.size + 2, weight: .semibold))
                }
                Text(title)
                    .typeStyle(font)
            }
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(tone.background, in: Capsule(style: .continuous))
            .overlay {
                if let border = tone.border {
                    Capsule(style: .continuous).strokeBorder(border, lineWidth: BorderWidth.hairline)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The full-width call to action: 56pt tall, radius 16.
/// Pass `height: nil` for the shorter bordered buttons at the foot of Profile, which size to
/// their own padding instead.
struct PrimaryButton: View {
    let title: String
    var tone: ButtonTone = .accent
    var systemImage: String?
    var height: CGFloat? = 56
    var radius: CGFloat = Radius.button
    var font: TypeStyle = .buttonLarge
    let action: () -> Void

    init(
        _ title: String,
        tone: ButtonTone = .accent,
        systemImage: String? = nil,
        height: CGFloat? = 56,
        radius: CGFloat = Radius.button,
        font: TypeStyle = .buttonLarge,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
        self.height = height
        self.radius = radius
        self.font = font
        self.action = action
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: font.size + 5.5, weight: .medium))
                }
                Text(title)
                    .typeStyle(font)
            }
            .foregroundStyle(tone.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.vertical, height == nil ? 13 : 0)
            .background(tone.background, in: shape)
            .overlay {
                if let border = tone.border {
                    shape.strokeBorder(border, lineWidth: BorderWidth.hairline)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stepper

/// The −/+ control from "Shape" and the venue sheet's limits.
/// `fill` track at radius 11 with 3pt of padding, two 34×32 white radius-9 buttons either side
/// of a centred `800 15` value.
struct StepperControl: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99
    var step: Int = 1
    /// 30pt in the "Shape" card, 34pt in the venue sheet.
    var valueWidth: CGFloat = 30
    var glyphSize: CGFloat = 15

    var body: some View {
        HStack(spacing: 2) {
            button("minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }

            Text("\(value)")
                .typeStyle(.stepperValue, color: Theme.ink)
                .frame(minWidth: valueWidth)
                .multilineTextAlignment(.center)

            button("plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(3)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .medium))
                .foregroundStyle(enabled ? Theme.ink : Theme.inkGhost)
                .frame(width: 34, height: 32)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.stepperButton, style: .continuous))
                // The white button still draws 34×32; the frame outside it only carries the tap.
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Toggle

/// The switch on Profile's `Notifications` row.
///
/// The design hand-draws it — a 46×28 track at radius 99 with 3pt of padding and a 22pt white
/// knob — which is a different shape from UIKit's 51×31/27, so it is drawn here rather than
/// styled onto `Toggle`. It is still a real control: it owns a binding, it is tappable, and it
/// carries `.isToggle` with a value, so VoiceOver and the switch-control rotor treat it exactly
/// as they would the system one.
struct SycamoreToggle: View {
    @Binding var isOn: Bool
    /// Spoken label. There is no visible text inside the switch, so the row supplies it.
    var label: String

    /// `width:46px;height:28px;border-radius:99px;padding:3px` with a `22px` knob.
    private let trackWidth: CGFloat = 46
    private let trackHeight: CGFloat = 28
    private let knobSize: CGFloat = 22
    private let knobInset: CGFloat = 3

    init(isOn: Binding<Bool>, label: String) {
        self._isOn = isOn
        self.label = label
    }

    /// The knob travels the track minus its own width and both insets.
    private var travel: CGFloat { trackWidth - knobSize - knobInset * 2 }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule(style: .continuous)
                .fill(isOn ? Theme.accent : Theme.fill)
                .frame(width: trackWidth, height: trackHeight)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Theme.surface)
                        .frame(width: knobSize, height: knobSize)
                        .padding(knobInset)
                        .offset(x: isOn ? travel : 0)
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isOn)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

// MARK: - Avatar

enum AvatarTone: Sendable {
    /// `fillAlt` disc, `inkMuted` initials — the default.
    case neutral
    /// Black disc, white initials — admins in Setup's staff list.
    case dark
    /// `accentTint` disc, `accent` initials — the trainer.
    case tinted
}

/// The initials disc used for coaches, staff and the profile header.
struct InitialsAvatar: View {
    let initials: String
    var size: CGFloat = 44
    var tone: AvatarTone = .neutral
    /// Defaults to `TypeStyle.initials(forAvatarSize:)`, which follows the design's per-size
    /// weight changes rather than a fixed ratio.
    var font: TypeStyle?

    init(_ initials: String, size: CGFloat = 44, tone: AvatarTone = .neutral, font: TypeStyle? = nil) {
        self.initials = initials
        self.size = size
        self.tone = tone
        self.font = font
    }

    var body: some View {
        Circle()
            .fill(background)
            .frame(width: size, height: size)
            .overlay {
                Text(initials.uppercased())
                    .typeStyle(font ?? .initials(forAvatarSize: size), color: foreground)
            }
    }

    private var background: Color {
        switch tone {
        case .neutral: Theme.fillAlt
        case .dark: Theme.ink
        case .tinted: Theme.accentTint
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Theme.inkMuted
        case .dark: Theme.surface
        case .tinted: Theme.accent
        }
    }
}

// MARK: - Badge

enum BadgeTone: Sendable {
    /// `fill` chip, `inkTertiary` label — "In range", "Worker".
    case neutral
    /// `fill` chip, `inkMuted` label — "Away" on a greyed player row.
    case muted
    /// `accentTint` chip, `accentDark` label — "2 coaches short".
    case accent
    case danger
}

/// The uppercase `700 9.5` chip that sits beside a name.
///
/// The design tracks the three badges differently — `.07em` on Groups' `Away`, `.08em` on the
/// venue status badges, `.09em` on Profile's role badge — so tracking is a parameter rather
/// than a property of the type style. `.08em` is the default because it is the one the venue
/// badges use, and they are the most numerous.
struct Badge: View {
    let text: String
    var tone: BadgeTone = .neutral
    /// Letter-spacing in `em`, as the design authors it.
    var trackingEm: CGFloat = 0.08
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 3

    init(
        _ text: String,
        tone: BadgeTone = .neutral,
        trackingEm: CGFloat = 0.08,
        horizontalPadding: CGFloat = 6,
        verticalPadding: CGFloat = 3
    ) {
        self.text = text
        self.tone = tone
        self.trackingEm = trackingEm
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        Text(text)
            .typeStyle(.badge.tracking(em: trackingEm), color: foreground)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
    }

    private var background: Color {
        switch tone {
        case .neutral, .muted: Theme.fill
        case .accent: Theme.accentTint
        case .danger: Theme.dangerTint
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Theme.inkTertiary
        case .muted: Theme.inkMuted
        case .accent: Theme.accentDark
        case .danger: Theme.danger
        }
    }
}

// MARK: - Circular icon button

enum CircleIconButtonTone: Sendable {
    /// White disc with a 1px border — the bell and share buttons in a header.
    case bordered
    /// `fill` disc, no border — the back button and every sheet's close button.
    case filled
}

/// 34pt bordered by default; 32pt `.filled` is the sheet close button, 40pt `.filled` the back
/// button. `iconSize` follows the design's per-diameter glyph sizes unless overridden.
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 34
    var iconSize: CGFloat?
    var tone: CircleIconButtonTone = .bordered
    var foreground: Color = Theme.ink
    var borderColor: Color = Theme.strokeAlt
    /// The blue unread dot the design puts on the Groups bell.
    var showsUnreadDot: Bool = false
    /// `nil` renders the same circle as a plain indicator rather than a control — for the
    /// places the design draws this shape without giving it anywhere to go. A button that
    /// does nothing is worse than no button, and it lies to VoiceOver besides.
    let action: (() -> Void)?

    init(
        systemName: String,
        size: CGFloat = 34,
        iconSize: CGFloat? = nil,
        tone: CircleIconButtonTone = .bordered,
        foreground: Color = Theme.ink,
        borderColor: Color = Theme.strokeAlt,
        showsUnreadDot: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
        self.tone = tone
        self.foreground = foreground
        self.borderColor = borderColor
        self.showsUnreadDot = showsUnreadDot
        self.action = action
    }

    private var resolvedIconSize: CGFloat {
        if let iconSize { return iconSize }
        return switch size {
        case 40...: 19
        case 34..<40: 18
        default: 15
        }
    }

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                // The design draws these discs at 32–40pt, so several of them sat under the
                // 44pt minimum and `contentShape(Circle())` clipped the tap to exactly what
                // was drawn. The outer frame carries the touch without moving the circle.
                //
                // Only the tappable variant gets it: the decorative one has no touch to
                // widen, and padding it out to 44pt would push its neighbours around.
                circle
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            circle.accessibilityAddTraits(.isImage)
        }
    }

    private var circle: some View {
        Circle()
                .fill(tone == .filled ? Theme.fill : Theme.surface)
                .frame(width: size, height: size)
                .overlay {
                    if tone == .bordered {
                        Circle().strokeBorder(borderColor, lineWidth: BorderWidth.hairline)
                    }
                }
                .overlay {
                    Image(systemName: systemName)
                        .font(.system(size: resolvedIconSize, weight: .medium))
                        .foregroundStyle(foreground)
                }
                .overlay(alignment: .topTrailing) {
                    if showsUnreadDot {
                        // `top:5px; right:5px` — the dot sits 5pt in from both edges.
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                            .overlay { Circle().strokeBorder(Theme.surface, lineWidth: BorderWidth.input) }
                            .offset(x: -5, y: 5)
                    }
                }
    }
}

// MARK: - Mock status bar

extension EnvironmentValues {
    /// Off in the real app, where the system draws the status bar. Previews turn it on so the
    /// frame lines up with the design.
    @Entry var showsMockStatusBar = false
}

extension View {
    func showsMockStatusBar(_ enabled: Bool = true) -> some View {
        environment(\.showsMockStatusBar, enabled)
    }
}

/// The `9:41` + cell/wifi/battery row the design draws at the top of every frame.
/// Collapses to nothing unless `showsMockStatusBar` is on.
struct StatusBarMock: View {
    @Environment(\.showsMockStatusBar) private var isEnabled

    var body: some View {
        if isEnabled {
            HStack(spacing: 0) {
                Text("9:41")
                    .typeStyle(.statusTime, color: Theme.ink)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "cellularbars").font(.system(size: 15))
                    Image(systemName: "wifi").font(.system(size: 15))
                    Image(systemName: "battery.100percent").font(.system(size: 17))
                }
                .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, Spacing.hero)
            .padding(.top, 15)
        }
    }
}

// MARK: - Info banner

enum InfoBannerTone: Sendable {
    /// `fill` plate — the venue sheet's "Within range".
    case neutral
    /// `grouped` plate — the verify screen's permissions note.
    case grouped
    /// `accentTint` plate — "1 over — move one kid down".
    case accent
}

/// Icon plus a line or two of copy on a tinted plate.
struct InfoBanner: View {
    let text: String
    var systemImage: String
    var tone: InfoBannerTone = .neutral
    var font: TypeStyle = .chipMedium
    var radius: CGFloat = Radius.control
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 10
    var spacing: CGFloat = 8
    var iconSize: CGFloat = 16
    /// `.top` for the multi-line variant on the verify screen.
    var alignment: VerticalAlignment = .center

    init(
        _ text: String,
        systemImage: String = "info.circle",
        tone: InfoBannerTone = .neutral,
        font: TypeStyle = .chipMedium,
        radius: CGFloat = Radius.control,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 10,
        spacing: CGFloat = 8,
        iconSize: CGFloat = 16,
        alignment: VerticalAlignment = .center
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
        self.font = font
        self.radius = radius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.spacing = spacing
        self.iconSize = iconSize
        self.alignment = alignment
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(foreground)
            Text(text)
                .typeStyle(font, color: foreground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var background: Color {
        switch tone {
        case .neutral: Theme.fill
        case .grouped: Theme.grouped
        case .accent: Theme.accentTint
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral, .grouped: Theme.inkTertiary
        case .accent: Theme.accentDark
        }
    }
}

// MARK: - Error banner

/// How a failure is shown once the user is past the stage-1 screens.
///
/// The design never draws an error, so this is assembled entirely from tokens the design does
/// draw: the `danger`/`dangerBorder` pair off the "Delete account" button, the standard card
/// radius, and `dangerTint` laid over `surface` so the plate is opaque enough to sit above
/// scrolling content.
///
/// It announces itself to VoiceOver on appearance and always carries a close button — a banner
/// that can only be waited out is not dismissible.
struct ErrorBanner: View {
    let message: String
    /// Omit for a banner the caller retires some other way; the close button disappears with it.
    var onDismiss: (() -> Void)?

    init(_ message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.danger)

            Text(message)
                .typeStyle(.caption, color: Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 22, height: 22)
                        // The glyph stays 22pt; only the tap area reaches the minimum.
                        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background {
            // Two tokens rather than a new hex: 10% danger over white is opaque and reads as
            // the light danger surface the pairing wants.
            ZStack {
                shape.fill(Theme.surface)
                shape.fill(Theme.dangerTint)
            }
        }
        .overlay { shape.strokeBorder(Theme.dangerBorder, lineWidth: BorderWidth.hairline) }
        .shadow(Shadows.tabItem)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isSummaryElement)
        .onAppear { announce() }
    }

    private func announce() {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// The in-flight affordance for `AppStore.isWorking`: a small capsule that floats over the
/// screen while an intent is running. Inert by design — it reports, it does not block.
struct WorkingIndicator: View {
    var label: String = "Working…"

    init(label: String = "Working…") {
        self.label = label
    }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(Theme.inkMuted)
            Text(label)
                .typeStyle(.chipMedium, color: Theme.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.surface, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).strokeBorder(Theme.hairline, lineWidth: BorderWidth.hairline) }
        .shadow(Shadows.tabItem)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

extension View {
    /// Floats an `ErrorBanner` over the receiver whenever `message` is non-nil. An overlay, so
    /// nothing underneath moves when a failure arrives.
    ///
    /// Pass `store.errorMessage` and `store.clearError`; the banner animates in and out with the
    /// message and is dismissed by its own close button.
    func storeErrorBanner(
        message: String?,
        alignment: Alignment = .top,
        horizontalPadding: CGFloat = Spacing.gutter,
        edgePadding: CGFloat = Spacing.small,
        onDismiss: @escaping () -> Void
    ) -> some View {
        overlay(alignment: alignment) {
            if let message {
                ErrorBanner(message, onDismiss: onDismiss)
                    .padding(.horizontal, horizontalPadding)
                    .padding(alignment == .bottom ? .bottom : .top, edgePadding)
                    .transition(.move(edge: alignment == .bottom ? .bottom : .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: message)
    }

    /// Floats a `WorkingIndicator` over the receiver while `isWorking` is true. Hit testing
    /// passes straight through it.
    func storeWorkingIndicator(
        _ isWorking: Bool,
        label: String = "Working…",
        alignment: Alignment = .top,
        edgePadding: CGFloat = Spacing.small
    ) -> some View {
        overlay(alignment: alignment) {
            if isWorking {
                WorkingIndicator(label: label)
                    .padding(alignment == .bottom ? .bottom : .top, edgePadding)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isWorking)
    }
}

// MARK: - Search field

/// `fill` plate at radius 13 with a magnifying glass and the design's grey placeholder.
struct SearchField: View {
    @Binding var text: String
    var placeholder: String

    init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.searchPlaceholder)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .typeStyle(.searchValue, color: Theme.searchPlaceholder)
                }
                field
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    private var field: some View {
        let base = TextField("", text: $text)
            .textFieldStyle(.plain)
            .typeStyle(.searchValue, color: Theme.ink)
            .autocorrectionDisabled()

        #if os(iOS)
        return base
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
        #else
        return base
        #endif
    }
}

// MARK: - Previews

#Preview("Cards, rows, chips") {
    return ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Your camps", count: 2, actionTitle: "Add") {}

            Card {
                CardRow {
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                        .fill(Theme.color(for: .moss))
                        .frame(width: 46, height: 46)
                        .overlay { Text("🌳").font(.system(size: 23)) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UCLA Tennis Camp").typeStyle(.rowTitleLg, color: Theme.ink)
                        Text("Coach · Sycamore, Court 3").typeStyle(.metaStrong, color: Theme.inkMuted)
                    }
                    Spacer(minLength: 0)
                    DisclosureChevron(size: 17)
                }
                CardRow {
                    InitialsAvatar("NA", size: 36, tone: .dark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nass").typeStyle(.bodyStrong, color: Theme.ink)
                        Text("Admin").typeStyle(.overline, color: Theme.inkMuted)
                    }
                    Spacer(minLength: 0)
                    Badge("In range")
                }
                CardRow {
                    Text("Liam J").typeStyle(.bodyStrong, color: Theme.inkFaint)
                    Badge("Away", tone: .muted, trackingEm: 0.07)
                    Spacer(minLength: 0)
                    Badge("2 coaches short", tone: .accent)
                }
            }
            .padding(.bottom, Spacing.section)

            SectionHeader("Sport")
            HStack(spacing: 7) {
                Chip("Tennis", isSelected: true, metrics: .sport)
                Chip("Soccer", metrics: .sport)
                Chip("Swim", metrics: .sport)
            }
            .padding(.bottom, 12)

            HStack(spacing: 7) {
                Chip("All", count: 100, isSelected: true)
                Chip("Sycamore", emoji: "🌳", count: 50)
                Chip("Everyone", isSelected: true, selectedTone: .tinted, metrics: .attribute)
            }
            .padding(.bottom, Spacing.section)

            SectionHeader("Which day")
            HStack(spacing: 6) {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri"], id: \.self) { day in
                    Chip(day, isSelected: day == "Wed", selectedTone: .accent, metrics: .day, fillsWidth: true)
                }
            }
        }
        .padding(Spacing.gutter)
    }
    .background(Theme.grouped)
}

/// Hoisted to file scope on purpose. A `View` type declared *inside* a `#Preview`
/// closure that also returns it makes the compiler's symbol mangler recurse without
/// bound (the type's mangling names the closure, whose type names the type).
private struct ControlsPreviewHarness: View {
    @State private var venues = 2
    @State private var query = ""
    @State private var notifications = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatusBarMock()

                SearchField(text: $query, placeholder: "Search a kid or a coach")

                HStack(spacing: 10) {
                    CircleIconButton(systemName: "bell", showsUnreadDot: true) {}
                    CircleIconButton(systemName: "square.and.arrow.up", foreground: Theme.accent) {}
                    CircleIconButton(systemName: "chevron.left", size: 40, tone: .filled) {}
                    CircleIconButton(systemName: "xmark", size: 32, tone: .filled, foreground: Theme.inkTertiary) {}
                    Spacer(minLength: 0)
                    Pill("Even out") {}
                }

                Card {
                    CardRow(horizontalPadding: 14, verticalPadding: 14) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Venues").typeStyle(.bodyStrong, color: Theme.ink)
                            Text("Sites or skill levels").typeStyle(.meta, color: Theme.inkMuted)
                        }
                        Spacer(minLength: 0)
                        StepperControl(value: $venues, range: 1...12)
                    }
                    CardRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Notifications").typeStyle(.rowLabel, color: Theme.ink)
                            Text("Court assignment, approved moves")
                                .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                        }
                        Spacer(minLength: 0)
                        SycamoreToggle(isOn: $notifications, label: "Notifications")
                    }
                }

                InfoBanner("1 over — move one kid down", systemImage: "exclamationmark.circle",
                           tone: .accent, font: .metaSmall, radius: Radius.banner,
                           horizontalPadding: 11, verticalPadding: 9)

                InfoBanner("Your permissions come from the camp, not the login.",
                           systemImage: "checkmark.shield", tone: .grouped, font: .caption,
                           radius: Radius.input, horizontalPadding: 15, verticalPadding: 15,
                           spacing: 12, iconSize: 21, alignment: .top)

                HStack(spacing: 12) {
                    InitialsAvatar("AL", size: 72)
                    InitialsAvatar("DA", size: 46, tone: .tinted)
                    InitialsAvatar("HU", size: 44)
                    InitialsAvatar("MA", size: 36, tone: .dark)
                }

                PrimaryButton("Continue with Apple", tone: .dark, systemImage: "apple.logo") {}
                PrimaryButton("Email me a code") {}
                HStack(spacing: 8) {
                    PrimaryButton("Sign out", tone: .outline, height: nil,
                                  radius: Radius.input, font: .buttonCompact) {}
                    PrimaryButton("Delete account", tone: .danger, height: nil,
                                  radius: Radius.input, font: .buttonCompact) {}
                }
            }
            .padding(Spacing.bar)
        }
        .background(Theme.grouped)
        .showsMockStatusBar()
    }
}

#Preview("Controls") {
    ControlsPreviewHarness()
}

/// Hoisted to file scope for the same mangling reason as `ControlsPreviewHarness`.
private struct StatusPreviewHarness: View {
    @State private var message: String? = "That court is full. Move a kid down first."
    @State private var isWorking = true

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            PrimaryButton("Bring the banner back", tone: .outline, height: nil,
                          radius: Radius.input, font: .buttonCompact) {
                message = "That court is full. Move a kid down first."
            }
            Text("Tap the ✕ to dismiss. The row underneath does not move.")
                .typeStyle(.footnote, color: Theme.inkFaint)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            ErrorBanner("A banner with no close button, for a caller that retires it itself.")
            WorkingIndicator()
        }
        .padding(Spacing.bar)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.grouped)
        .storeErrorBanner(message: message) { message = nil }
        .storeWorkingIndicator(isWorking, alignment: .bottom)
        .onTapGesture { isWorking.toggle() }
    }
}

#Preview("Error banner & in-flight") {
    StatusPreviewHarness()
}
