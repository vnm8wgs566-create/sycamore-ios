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
    /// `IconSize.caret` — 15, which is what the design draws and what **eight of this view's
    /// fourteen callers were already passing by hand**. The default was 16, so the six that did
    /// not override it drew a caret a point larger than every other row in the app, and the
    /// component was being corrected rather than used. Now nobody passes it.
    var size: CGFloat = IconSize.caret
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
                    // "Add" and "Invite" on Camp settings were a bare `Text` — about 30 × 15pt,
                    // the smallest target in the app, and both of them the only way to do the
                    // thing they name. The negative horizontal padding keeps the word itself
                    // sitting exactly where the design puts it, on the trailing edge, while the
                    // region a thumb has to find is the full 44.
                    Text(actionTitle)
                        .typeStyle(.chipMedium, color: Theme.accent)
                        .padding(.horizontal, Spacing.small)
                        .frame(minHeight: HitTarget.minimum)
                        .contentShape(.rect)
                        .padding(.horizontal, -Spacing.small)
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
                                   radius: Radius.pill, spacing: Spacing.markGap, unselectedBorder: Theme.strokeChip,
                                   emojiSize: 15)
    /// Groups' attribute filter — `600 12`, `6/12`, pill.
    static let attribute = ChipMetrics(font: .chipSmall, horizontalPadding: 12, verticalPadding: 6,
                                       radius: Radius.pill, spacing: 6, unselectedBorder: Theme.strokeChip,
                                       emojiSize: 12)
    /// New camp's sport picker — `700 13`, `9/15`, pill.
    static let sport = ChipMetrics(font: .chip, horizontalPadding: 15, verticalPadding: 9,
                                   radius: Radius.pill, spacing: Spacing.markGap, unselectedBorder: Theme.strokeChip,
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
    /// The block editor's Mon–Fri row — `600 13.5`, `10` vertical, **pill**, equal widths.
    ///
    /// A second day preset rather than a retune of `day` above, which `ScheduleView` and
    /// `EarlyPickupSheet` both take: section 5a redraws this one row as pills
    /// (`border-radius:999`, `padding:10px 0`, `gap:7px`, unselected `#E6E7EB` on `#3F4A44`)
    /// and says nothing about the other two. Retuning `day` would have moved a day picker on
    /// two screens this section does not draw, which is the failure the whole label pass is
    /// trying to avoid — one screen's answer imposed on screens nobody looked at.
    ///
    /// `strokeChip` rather than `strokeAlt` for the same reason `venue` and `attribute` take it:
    /// a pill's border is the one that has to hold its own against a fully round edge.
    static let dayPill = ChipMetrics(font: .timelineTitle, horizontalPadding: 0, verticalPadding: 10,
                                     radius: Radius.pill, spacing: Spacing.markGap, unselectedBorder: Theme.strokeChip,
                                     emojiSize: 13.5)
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

        if let action {
            Button(action: action) {
                // The plate is drawn at the size the design draws it — 28pt for a staff filter,
                // 32 for a venue, 34 for a sport — and then the *target* is grown to 44 around
                // it. The two are different jobs and were the same expression until a finger
                // found out: the venue chips on Groups are the most-tapped control in the app,
                // they sit in a horizontal `ScrollView` that claims any touch with travel in it,
                // and they were twelve points short of what a thumb is allowed to miss by.
                //
                // Order matters and is the whole fix. `.contentShape` before `.frame` pins the
                // hit region to the drawn plate and the added height is inert — which is what
                // three call sites had already worked around by hand
                // (`ScheduleView.swift:336`, `EarlyPickupSheet.swift:182`) and five had not.
                // Growing here rather than at the call site is what makes those workarounds
                // unnecessary rather than merely redundant.
                //
                // A third was `GroupsMove.swift`'s move bar, which has been deleted along with the
                // latch it served — see that file's header.
                label
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            // Nothing to hit when there is no action: a chip used as a read-only badge keeps the
            // drawn shape, so it does not claim 44pt of a row it is only labelling.
            label.contentShape(shape)
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
///
/// Three of the six are outlines, and they are three because the design draws three. What varies
/// between them is not decoration: it is how loudly the button asks. `.outline` is the way out of
/// a screen, `.quietOutline` is a third answer beside two louder ones, `.accentOutline` is the
/// second-choice version of something you can also do outright.
enum ButtonTone: Sendable {
    case dark
    case accent
    /// White fill, `hairline` border, `inkSecondary` label — "Sign out".
    case outline
    /// White fill, the heavier `stroke` rule, `inkWarm` label — `4c`'s "About even"
    /// (`design/rebuild/section-t4.html:198`).
    ///
    /// A sibling of `.outline` rather than a retune of it. `.outline` is a `hairline` box holding
    /// a grey word and it is right where it is used, at the foot of Profile; this is a firmer rule
    /// (`#E4E5E9`, drawn at 1.5) around the design's warm ink, and it has to be, because it sits
    /// between two full-height cards that are themselves buttons. A `hairline` box there reads as
    /// a caption rather than as the third thing you may press.
    case quietOutline
    /// White fill, `accentBorder` rule, `accent` label — `4d`'s second-choice "Assign", for a
    /// coach who is free later rather than free now.
    ///
    /// Deliberately the same word in the same place as the filled `.accent` Assign, one step back.
    /// The two tiers of that row differ by *when*, not by what pressing them does, so they must
    /// read as one control at two strengths and not as two controls.
    case accentOutline
    /// White fill, `dangerBorder` border, `danger` label — "Delete account".
    case danger
}

private extension ButtonTone {
    var background: Color {
        switch self {
        case .dark: Theme.ink
        case .accent: Theme.accent
        case .outline, .quietOutline, .accentOutline, .danger: Theme.surface
        }
    }

    var foreground: Color {
        switch self {
        // `.dark` fills with `ink`, which inverts, so `surface` inverts with it and the pair
        // stays legible. `.accent` fills with a green that does *not* invert, so its label has
        // to be pinned or it turns dark-on-green in the dark scheme.
        case .dark: Theme.surface
        case .accent: Theme.onAccent
        case .outline: Theme.inkSecondary
        case .quietOutline: Theme.inkWarm
        case .accentOutline: Theme.accent
        case .danger: Theme.danger
        }
    }

    var border: Color? {
        switch self {
        case .dark, .accent: nil
        case .outline: Theme.hairline
        case .quietOutline: Theme.stroke
        case .accentOutline: Theme.accentBorder
        case .danger: Theme.dangerBorder
        }
    }

    /// How thick that rule is drawn, where the tone draws one at all.
    ///
    /// **Beside the colour, because the two are one decision.** `.quietOutline` is `#E4E5E9` *at
    /// 1.5* and `.accentOutline` is `accentBorder` *at 1.5*; drawn at a hairline they are not
    /// quieter versions of themselves, they are a different control — a caption-weight box round a
    /// 13.5pt label, which is what both of them exist not to be. The width lived on `Pill` as an
    /// argument the caller had to remember, and the two tones that need it are exactly the two a
    /// caller has no reason to suspect: forgetting it produced a hairline silently, on the quieter
    /// half of a pair the reader is choosing between.
    ///
    /// The old comment argued the width could not live here because `PrimaryButton` shares this
    /// enum and draws every border at a hairline, so a tone-carried width would be honoured by one
    /// consumer and not the other. That is true and is not an argument against the property — it is
    /// an argument for the override being written down, which it now is
    /// (`PrimaryButton.body`, `:650-663`). A default a consumer overrides deliberately is a
    /// contract; a value every caller must supply from memory is not.
    var borderWidth: CGFloat {
        switch self {
        case .dark, .accent, .outline, .danger: BorderWidth.hairline
        case .quietOutline, .accentOutline: BorderWidth.input
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
    /// An override for the rule's thickness. Nil — the usual case — takes the tone's own
    /// (`ButtonTone.borderWidth`, `:502-524`).
    ///
    /// This was a plain `CGFloat` defaulting to `hairline`, and the two tones that are drawn at
    /// `1.5` — `4c`'s "About even" and `4d`'s outlined "Assign" — had to be told so at every call
    /// site. That is a contract nothing enforced: forget the argument and the pill still compiles,
    /// still draws, and is silently the wrong control. The tone carries its own width now and the
    /// two call sites that state it are stating what they would get anyway.
    ///
    /// Kept as a parameter rather than removed, because a width is a fair thing for one caller to
    /// want — the shape it was added for is a pill that is *not* one of the design's tones — and
    /// because removing it would break call sites this change does not own. Nil rather than a
    /// defaulted `hairline`, so "said nothing" and "asked for a hairline" stay different requests:
    /// under the old default, a tone's own width could never win.
    var borderWidth: CGFloat?
    let action: () -> Void

    init(
        _ title: String,
        tone: ButtonTone = .dark,
        systemImage: String? = nil,
        font: TypeStyle = .chipMedium,
        horizontalPadding: CGFloat = 15,
        verticalPadding: CGFloat = 9,
        borderWidth: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
        self.font = font
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.borderWidth = borderWidth
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
                    Capsule(style: .continuous)
                        .strokeBorder(border, lineWidth: borderWidth ?? tone.borderWidth)
                }
            }
            // Same order, same reason as `Chip`: the capsule is drawn at ~33pt and the target is
            // grown to 44 around it. Groups' move bar had already tried to grow "Drop here" from
            // the outside and could not, because the shape was pinned in here — that bar is gone
            // now, dropped along with the latch it existed to release, but it is the case that
            // proved the growing belongs on this side of the boundary rather than at the caller.
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
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
                // Pinned, and it overrides `tone.borderWidth` (`:502-524`) on purpose. A tone's
                // width is drawn for a capsule about 33pt tall holding a 13.5pt label, where 1.5
                // is what stops the rule reading as a caption; this button is 56pt tall at radius
                // 16 under a 17pt label, and the design draws every bordered one of those —
                // "Sign out", "Delete account" — at a hairline. Two shapes, two answers, and the
                // one that disagrees with the tone says so here rather than leaving the enum
                // holding a width that means something different depending on who read it.
                //
                // Nothing is currently drawn as a `PrimaryButton` in either of the 1.5 tones, so
                // this changes no pixel today. It is the statement that keeps it that way.
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

// MARK: - Progress

/// The design's 4pt track with its figure alongside — `20 of 22` on `8m Attendance`,
/// `30 of 42 placed` on `4c`'s first sort (`design/rebuild/section-t4.html:182`).
///
/// Lifted out of `AttendanceHeader.swift` unchanged the day a second screen asked for it. Two
/// arguments came with it, and they are why this is a component rather than eight lines copied:
///
/// The fill is **scaled rather than measured**. At 4pt tall the capsule's 2pt ends distort by well
/// under a point, and that keeps the bar free of a `GeometryReader` — which matters more here than
/// it did in one file, because both screens redraw this on every single answer.
///
/// And the curve is **gated on Reduce Motion**. Both callers pin this bar in a header that stays
/// on screen while the list under it churns, so it is the one piece of motion a reader cannot look
/// away from.
///
/// That is also why it is no longer a spring. What came over from `AttendanceHeader` was
/// `.snappy(duration: 0.25)`, and `.snappy` is `bounce: 0.15` — so the fill ran *past* the fraction
/// and settled back to it. On a 4pt track that is not a bounce anybody reads as one; it is a
/// wobble, and it is a bar overshooting the very number written beside it. The hoist is what
/// promoted the curve to shared code and put it on `4c`, where it is driven on every single answer
/// rather than on a mark here and there, and the design system's rule for this app is no bounce and
/// no spring overshoot. `.easeOut` at 0.24 instead — the app's one fold duration (`Motion.fold`),
/// so the bar moves for as long as everything else does and stops where it says it stopped.
///
/// `labelStyle` and `labelColor` carry no defaults on purpose. The two screens that draw this
/// disagree — `8m` sets its figure `.metaSmall`/`inkSecondary`, `4c` sets it `.metaStrong`/`inkWarm`
/// — so any default here would be one screen's answer quietly imposed on the other's.
struct ProgressTrack: View {
    let value: Int
    let total: Int
    /// The figure beside the bar, composed by the caller: `8m` writes `20 of 22` and `4c`
    /// `30 of 42 placed`. Not derived from `value`/`total`, because those two spellings are the
    /// only thing the design varies between the screens.
    let label: String
    let labelStyle: TypeStyle
    let labelColor: Color
    /// What VoiceOver calls the bar — `Marked` on `8m`, `Placed` on `4c`. Required rather than
    /// derived from `label`, which is the *value* ("20 of 22") and not the name of anything.
    let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `height:4px`. `OnTheDayTokens.progressHeight` is the same number arrived at from the same
    /// CSS; it is restated rather than borrowed because a design-system primitive reaching up into
    /// `Features/` is a dependency pointing the wrong way.
    private let trackHeight: CGFloat = 4

    /// Guarded rather than trusted: an empty roll and an empty ladder both reach this view before
    /// anything has been loaded into them, and `0/0` is a bar of width NaN.
    private var fraction: Double {
        total == 0 ? 0 : Double(value) / Double(total)
    }

    var body: some View {
        HStack(spacing: Spacing.row) {
            Capsule()
                .fill(Theme.hairline)
                .frame(height: trackHeight)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.accent)
                        .scaleEffect(x: fraction, y: 1, anchor: .leading)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: fraction)

            Text(label)
                .typeStyle(labelStyle, color: labelColor)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(value) of \(total)")
        // Read out as the count moves rather than only when the header is swiped to, so a coach
        // running VoiceOver hears the list shrink without leaving the row they are on.
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Avatar

enum AvatarTone: Sendable {
    /// `fillAlt` disc, `inkMuted` initials — the default.
    case neutral
    /// The same `fillAlt` disc one step firmer: `inkSecondary` initials.
    ///
    /// `#EFF0F3` / `#5C6068` is what the design draws wherever a set of initials is *large* — 52pt
    /// on `4c`'s player cards (`design/rebuild/section-t4.html:187`) and 34pt on `4d`'s coach rows
    /// (`:229`). `.neutral`'s `inkMuted` is a step lighter and was read off the 36–46pt discs,
    /// where there is less of it on screen to carry. Two sizes asking for the firmer ink is what
    /// makes this a tone rather than a colour argued at one call site.
    case neutralStrong
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
        case .neutral, .neutralStrong: Theme.fillAlt
        case .dark: Theme.ink
        case .tinted: Theme.accentTint
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Theme.inkMuted
        case .neutralStrong: Theme.inkSecondary
        case .dark: Theme.surface
        case .tinted: Theme.accent
        }
    }
}

// MARK: - Venue letter tile

/// The 44pt tile a venue wears in a list — its initial, not its emoji.
///
/// `44 × 44; border-radius:14px; background:#EDF6F1; font:600 17px; color:#14684A`
/// (`design/rebuild/section-t4.html:149`).
///
/// **This is now how a venue is drawn everywhere**, not just in a list. The 52pt emoji tile it
/// used to sit beside is gone: the design system retired the three pastels and the six emoji
/// together, and the ruling to cut the icon picker arrived at the same place independently.
/// `InitialsAvatar` is a circle, and circles belong to people. This is the other thing: a place.
///
/// A venue drew its letter here even when it had an emoji, which was always the point — the tile
/// was
/// decoration a venue *chose*, and three tennis venues choose the same 🎾. A column of distinct
/// letters is what makes the list scannable at the speed somebody opens it: once, at 8am, to say
/// where they are.
///
/// The tint does not vary by venue either, where `Theme.color(for:)` varies it on the emoji tile.
/// One accent family down the column leaves the selected row's green border and tick as the only
/// colour on screen that means anything.
struct VenueLetterTile: View {
    /// The venue's name. Only its first character is drawn.
    let name: String
    var size: CGFloat = 44
    /// The design draws this tile at 44 with `--radius-tile` (14). A caller drawing it smaller
    /// has to bring the radius down with it or the plate reads as a circle — at 26pt a 14 is
    /// more than half the width, and a venue's letter starts looking like a person's avatar.
    var radius: CGFloat = Radius.row
    /// `600 17`, untracked. `.venueHeading` is the same size and weight and carries `-.03em`,
    /// which is right for a run of words and wrong for one glyph: SwiftUI's tracking trails the
    /// last character as well as sitting between them, so a tracked single letter sits fractionally
    /// off the centre of its own tile. The design authors this one with no `letter-spacing` at all.
    var font: TypeStyle = .venueHeading.tracking(em: 0)

    init(
        _ name: String,
        size: CGFloat = 44,
        radius: CGFloat = Radius.row,
        font: TypeStyle = .venueHeading.tracking(em: 0)
    ) {
        self.name = name
        self.size = size
        self.radius = radius
        self.font = font
    }

    /// Uppercased, so a venue somebody typed in lower case still draws a capital.
    private var letter: String {
        name.first.map { String($0).uppercased() } ?? ""
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.accentTint)
            .frame(width: size, height: size)
            .overlay {
                Text(letter)
                    .typeStyle(font, color: Theme.accentDark)
            }
            // The venue's full name is always the next thing in the row, so the letter is an
            // initial of something already being read out. Hidden rather than left to announce
            // "S" ahead of "Sycamore".
            .accessibilityHidden(true)
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

extension View {
    /// Floats an `ErrorBanner` over the receiver whenever `message` is non-nil. An overlay, so
    /// nothing underneath moves when a failure arrives.
    ///
    /// Pass `store.errorMessage` and `store.clearError`; the banner animates in and out with the
    /// message and is dismissed by its own close button.
    ///
    /// Deliberately without an in-flight counterpart, and this is the one place that reasoning is
    /// written down. There was one: a "Working…" capsule that `storeWorkingIndicator` floated from
    /// these same call sites, over every write in the app. It went because these writes land in
    /// well under the time it takes to read a capsule, so what it drew was a label flashing at the
    /// top of the screen on every tap. A failure is news and gets a banner; a write that is merely
    /// happening is not, and the row that changes under your finger already reports it.
    ///
    /// `AppStore.isWorking` stays, but the capsule was the only consumer that wanted its general
    /// "some intent is running" meaning. The seed fall over the camp picker used to be listed here
    /// as a third consumer and is gone too, for the same reason and then some: raised by
    /// `isWorking`, it also fell for the write behind "That's me" and for switching camps, so a
    /// full-screen animation played over writes far too short to read it. What is left are two
    /// camp-specific readers — camp creation's double-tap guard and Import's dim — so `perform`
    /// sets a flag on every intent that only those two consult. The split into
    /// `isCreatingCamp` / `isImporting` this wants is smaller now than when it was three.
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
}

// MARK: - Search field

/// `fill` plate at radius 13 with a magnifying glass and the design's grey placeholder.
///
/// A named wrapper over `FormField(.plate)` rather than the raw component at each call site: two
/// screens use this and both want the same glyph, the same type and the same keyboard, and
/// "search" is the thing they mean. It keeps its own `@FocusState` because nothing outside it
/// has ever needed to put the keyboard down on its behalf.
struct SearchField: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var isFocused: Bool

    init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        let field = FormField(
            placeholder,
            text: $text,
            // The placeholder *is* the label here — "Find a player" names the control as well as
            // any separate string would, and the two screens draw no header above it.
            label: placeholder,
            metrics: .plate,
            type: .searchValue,
            icon: "magnifyingglass",
            focus: $isFocused
        )
        .autocorrectionDisabled()

        // Both travel down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
        #else
        return field
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
                    DisclosureChevron()
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
            HStack(spacing: Spacing.markGap) {
                Chip("Tennis", isSelected: true, metrics: .sport)
                Chip("Soccer", metrics: .sport)
                Chip("Swim", metrics: .sport)
            }
            .padding(.bottom, 12)

            HStack(spacing: Spacing.markGap) {
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

                // The three outlines together, which is the only way to see that they are three
                // different answers and not one drawn three ways. Both of the new pair draw the
                // design's 1.5pt rule and neither is told to: `ButtonTone.borderWidth` (`:502-524`)
                // carries it, and this preview asks for nothing but the tone precisely so that a
                // width that failed to arrive would show up here as a hairline.
                HStack(spacing: 8) {
                    Pill("Sign out", tone: .outline) {}
                    Pill("Assign", tone: .accentOutline, font: .chip,
                         horizontalPadding: Spacing.large) {}
                    Pill("Assign", tone: .accent, font: .chip,
                         horizontalPadding: Spacing.large) {}
                }
                Pill("About even", tone: .quietOutline, font: .timelineTitle,
                     horizontalPadding: 24, verticalPadding: 11) {}
                    .frame(maxWidth: .infinity)

                // Both callers' labels, so a change to either style shows up as a difference here
                // rather than on one screen.
                ProgressTrack(value: 20, total: 22, label: "20 of 22",
                              labelStyle: .metaSmall, labelColor: Theme.inkSecondary,
                              accessibilityLabel: "Marked")
                ProgressTrack(value: 30, total: 42, label: "30 of 42 placed",
                              labelStyle: .metaStrong, labelColor: Theme.inkWarm,
                              accessibilityLabel: "Placed")

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

                // `.neutralStrong` at both sizes the design draws it, next to the `.neutral` it is
                // a step firmer than. The 52pt disc also takes the design's `600 16`, one point over
                // what `.initials(forAvatarSize:)` returns for that diameter.
                HStack(spacing: 12) {
                    InitialsAvatar("SC", size: 52, tone: .neutralStrong,
                                   font: .initials(forAvatarSize: 52).size(16))
                    InitialsAvatar("SC", size: 52)
                    InitialsAvatar("HU", size: 34, tone: .neutralStrong)
                    InitialsAvatar("HU", size: 34)
                }

                HStack(spacing: 12) {
                    VenueLetterTile("Sycamore")
                    VenueLetterTile("LATC")
                    VenueLetterTile("Westside")
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
        }
        .padding(Spacing.bar)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.grouped)
        .storeErrorBanner(message: message) { message = nil }
    }
}

#Preview("Error banner") {
    StatusPreviewHarness()
}
