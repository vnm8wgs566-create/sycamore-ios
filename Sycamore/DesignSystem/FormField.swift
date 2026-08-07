//
//  FormField.swift
//  Sycamore
//
//  The app's one text input, and the four boxes the design draws around it.
//
//  Five screens had hand-rolled the same thing: a `ZStack` holding a grey `Text` behind an empty
//  `TextField`, plus a `.contentShape` and an `.onTapGesture` so the box would take a tap. Three
//  others — the venue sheet, Setup's rename row, Profile's emergency number — reached for
//  SwiftUI's own `prompt:` instead. Eight fields, two mechanisms, and they do not draw the same
//  thing: an overlaid `Text` is a *sibling* of the field rather than part of its text layout, so
//  it sits on its own baseline and takes no part in selection or the clear button.
//
//  `prompt:` is the one that survives. What is left over — plate, rule, radius, gutters and the
//  optional leading glyph — is chrome, and chrome is the only thing that genuinely differs
//  between the five sites. So it lives in `FormFieldMetrics` as a preset per box, the way
//  `ChipMetrics` already holds the design's chips, rather than as a parameter list fifteen long.
//  What is left for a caller to say is the type style, the glyph and the keyboard.
//
//  Deliberately not a wrapper that also owns the keyboard. `.keyboardType`, `.textContentType`,
//  `.textInputAutocapitalization`, `.submitLabel`, `.autocorrectionDisabled` and `.onSubmit` all
//  travel down the environment to the field inside, so each screen keeps stating its own — which
//  matters, because they are not the same: sign-in wants `.emailAddress` and no capitals, the
//  join code wants `.oneTimeCode` and all of them, and the pick-up sheet's "who collects" is the
//  one field in the app that wants autocorrect left switched on.
//

import SwiftUI

// MARK: - Metrics

/// The box around the input. The design draws four of them, and each is a preset here rather
/// than eight arguments at the call site.
struct FormFieldMetrics: Sendable {
    /// Plate behind the field. `nil` where the design lets the screen's own background show
    /// through, which is only sign-in — it is already standing on white.
    var fill: Color?
    /// The rule around it. `nil` for search, which is a filled plate with no border at all.
    var border: Color?
    var borderWidth: CGFloat
    var radius: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    /// Gap between the leading glyph and the input.
    var glyphGap: CGFloat
    /// Point size of the leading SF Symbol. Stated per box rather than derived from the type
    /// style, because the design has no ratio in it: sign-in runs a 19pt envelope over a 15.5pt
    /// value, the pick-up sheet a 16pt person over a 14pt one, and search a 17pt glass over 15.
    var glyphSize: CGFloat
    /// Worn by the prompt *and* the glyph. The design has never drawn those two apart — all
    /// three glyph-bearing fields set them to the same grey — so they are one value here.
    var promptColor: Color
    /// `nil` where the gutters already carry the box past 44pt on their own.
    var minimumHeight: CGFloat?

    /// Sign in's email row — no plate, `1.5px #E4E5E9` at radius 15, `15/16` gutters, a 19pt
    /// envelope 11pt off the text.
    static let outlined = FormFieldMetrics(
        fill: nil, border: Theme.stroke, borderWidth: BorderWidth.input, radius: Radius.input,
        horizontalPadding: 15, verticalPadding: Spacing.large,
        glyphGap: Spacing.row, glyphSize: 19,
        promptColor: Theme.inkFaint, minimumHeight: nil
    )

    /// The stage-1 intake card — white on `#F8F9F8`, the same rule and radius as sign-in, and
    /// `14` all four sides. Shared by "Shape the camp"'s name and the join-with-a-code row.
    static let intakeCard = FormFieldMetrics(
        fill: Theme.surface, border: Theme.stroke, borderWidth: BorderWidth.input,
        radius: Radius.input,
        horizontalPadding: Spacing.gutterWide, verticalPadding: Spacing.gutterWide,
        glyphGap: Spacing.row, glyphSize: 17,
        promptColor: Theme.inkFaint, minimumHeight: nil
    )

    /// A field inside a sheet — white, a 1px rule at radius 13, `13/11`, a 16pt glyph 9pt off
    /// the text. Grown to 44: 11pt of gutter over a 14pt line lands short of it, and this is the
    /// one preset whose own padding does not get there. The pick-up sheet already did this by
    /// hand; the number moves here rather than being dropped.
    static let sheetBox = FormFieldMetrics(
        fill: Theme.surface, border: Theme.stroke, borderWidth: BorderWidth.hairline,
        radius: Radius.tile,
        horizontalPadding: 13, verticalPadding: Spacing.row,
        glyphGap: 9, glyphSize: 16,
        promptColor: Theme.inkFaint, minimumHeight: HitTarget.minimum
    )

    /// Search — the `#F1F2F5` plate at radius 13, no rule, `12/11`, a 17pt glass.
    ///
    /// The one preset that stays under 44pt (roughly 40 at the default text size), because the
    /// design draws it that way and it is the header of two screens this change does not own.
    /// Flagged in the PR rather than quietly grown here.
    static let plate = FormFieldMetrics(
        fill: Theme.fill, border: nil, borderWidth: 0, radius: Radius.tile,
        horizontalPadding: 12, verticalPadding: Spacing.row,
        glyphGap: 9, glyphSize: 17,
        promptColor: Theme.searchPlaceholder, minimumHeight: nil
    )
}

// MARK: - Chrome

extension View {
    /// Wraps the receiver in `metrics`' plate, rule, gutters and optional leading glyph.
    ///
    /// Exposed rather than kept private to `FormField` because `EarlyPickupSheet` puts a time
    /// menu next to a text field and the two have to be the same box. Drawing that box twice is
    /// how they drifted the first time.
    func formFieldChrome(_ metrics: FormFieldMetrics, icon: String? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)

        return HStack(spacing: metrics.glyphGap) {
            if let icon {
                // `.font(.system(size:))` rather than a `TypeStyle`: this is a symbol, not copy,
                // and the type table is for copy.
                Image(systemName: icon)
                    .font(.system(size: metrics.glyphSize, weight: .regular))
                    .foregroundStyle(metrics.promptColor)
                    .accessibilityHidden(true)
            }

            // The width belongs to the input rather than to a trailing `Spacer`. A `TextField`
            // takes a tap only inside its own frame, so every point of the row it is not given
            // is a point of the box that does nothing when you put a finger on it.
            self.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.verticalPadding)
        .background(metrics.fill ?? .clear, in: shape)
        .overlay {
            if let border = metrics.border {
                shape.strokeBorder(border, lineWidth: metrics.borderWidth)
            }
        }
        .frame(minHeight: metrics.minimumHeight)
    }
}

// MARK: - Field

/// A single-line text input in one of the design's four boxes.
///
/// The prompt is a `String`, and it is drawn with `Text(verbatim:)`. Both halves of that are
/// deliberate. A bare literal becomes a `LocalizedStringKey`, SwiftUI parses those as Markdown,
/// and Markdown autolinks a bare email address: `you@yourcamp.org` shipped once as a tinted link
/// (`#1568F0`) that ignored every foreground colour set on it. `verbatim:` is the fix; typing the
/// parameter as `String` is the belt to its braces, because a literal handed to a `String`
/// parameter can never reach the `LocalizedStringKey` overload even if the `verbatim:` below were
/// ever dropped. Anything holding an `@` or a URL-ish token is at risk, so both stay.
///
/// The value colour is not a parameter. All five sites draw it in `Theme.ink` and there is no
/// design in which a field's own text is anything else.
struct FormField: View {
    @Binding var text: String
    /// The example value shown while the field is empty.
    let prompt: String
    /// What VoiceOver calls the field. Required rather than optional: with an empty `TextField`
    /// title the fallback is the prompt, and "you at yourcamp dot org" is not the name of a
    /// control.
    let label: String
    var metrics: FormFieldMetrics
    var type: TypeStyle
    /// The prompt's own style, where the design draws it a step off the value — the pick-up
    /// sheet sets its placeholder at `400` against the field's `500`. `nil` follows the value,
    /// which is what SwiftUI does unaided.
    var promptType: TypeStyle?
    /// Leading SF Symbol.
    var icon: String?
    /// Focus lives with the caller, not in here. Two screens put the keyboard down before they
    /// act — `SignInView` before it posts the code, `CreateCampView` before it hands the shape on
    /// — and a `@FocusState` owned by this struct is not reachable from either.
    var focus: FocusState<Bool>.Binding

    init(
        _ prompt: String,
        text: Binding<String>,
        label: String,
        metrics: FormFieldMetrics = .outlined,
        type: TypeStyle = .fieldValue,
        promptType: TypeStyle? = nil,
        icon: String? = nil,
        focus: FocusState<Bool>.Binding
    ) {
        self.prompt = prompt
        self._text = text
        self.label = label
        self.metrics = metrics
        self.type = type
        self.promptType = promptType
        self.icon = icon
        self.focus = focus
    }

    var body: some View {
        input
            .formFieldChrome(metrics, icon: icon)
            // The tap survives the move to `prompt:`, but there is one of it now rather than
            // three. `padding` wraps a `TextField`; it does not grow the field's own frame, and
            // the responder's rect is that frame — so the gutters either side of the text are
            // not part of what takes a tap however the placeholder is drawn. The pick-up sheet's
            // box is 44pt tall around a 17pt line; without this, most of it is dead.
            //
            // Deliberately no `.accessibilityAddTraits(.isButton)` over the top of it. The
            // `TextField` is already the element VoiceOver lands on, and a button trait here
            // would announce a second, imaginary control in front of it.
            .contentShape(.rect)
            .onTapGesture { focus.wrappedValue = true }
    }

    /// A property rather than inline in `body` because `prompt:` wants a `Text` built two steps
    /// back, and the field itself is one expression.
    private var input: some View {
        TextField("", text: $text, prompt: promptText)
            .textFieldStyle(.plain)
            .typeStyle(type, color: Theme.ink)
            .focused(focus)
            .accessibilityLabel(label)
    }

    /// `Text.typeStyle` rather than a bare `.foregroundStyle`: the prompt is drawn inside the
    /// field's own text layout, so it needs the face and the tracking as well as the colour —
    /// the join code's `+.18em` mono is unreadable without them.
    private var promptText: Text {
        Text(verbatim: prompt)
            .typeStyle(promptType ?? type, color: metrics.promptColor)
    }
}

// MARK: - Previews

/// Every preset side by side, empty and filled. Each field needs its own `@FocusState`, which a
/// `#Preview` body cannot declare five of, so the gallery is a view.
///
/// Drawn in shared type rows rather than in the feature aliases the real screens pass
/// (`.intakeFieldTitle`, `.onTheDayValue`, `.intakeJoinCode`). Those are one-line aliases onto
/// rows that live here anyway, and a design-system file reaching up into `Features/` for a
/// preview is a dependency pointing the wrong way.
private struct FormFieldGallery: View {
    @State private var email = ""
    @State private var campName = ""
    @State private var code = ""
    @State private var collector = ""
    @State private var search = "Austin"

    @FocusState private var emailFocus: Bool
    @FocusState private var campNameFocus: Bool
    @FocusState private var codeFocus: Bool
    @FocusState private var collectorFocus: Bool
    @FocusState private var searchFocus: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                labelled("outlined — sign in") {
                    FormField(
                        "you@yourcamp.org",
                        text: $email,
                        label: "Email address",
                        icon: "envelope",
                        focus: $emailFocus
                    )
                }

                labelled("intakeCard — shape the camp") {
                    FormField(
                        "UCLA Tennis Camp",
                        text: $campName,
                        label: "Camp name",
                        metrics: .intakeCard,
                        type: .fieldTitle,
                        focus: $campNameFocus
                    )
                }

                labelled("intakeCard — join code") {
                    FormField(
                        "SYC-••••",
                        text: $code,
                        label: "Invite code",
                        metrics: .intakeCard,
                        type: .monoInput,
                        focus: $codeFocus
                    )
                }

                labelled("sheetBox — who collects") {
                    FormField(
                        "Who collects",
                        text: $collector,
                        label: "Who collects",
                        metrics: .sheetBox,
                        type: .rowTitleSm,
                        promptType: .rowValue,
                        icon: "person",
                        focus: $collectorFocus
                    )
                }

                labelled("plate — search, with a value in it") {
                    FormField(
                        "Find a player",
                        text: $search,
                        label: "Find a player",
                        metrics: .plate,
                        type: .searchValue,
                        icon: "magnifyingglass",
                        focus: $searchFocus
                    )
                }
            }
            .padding(Spacing.hero)
        }
        .background(Theme.surfaceWarm)
    }

    private func labelled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .typeStyle(.overline, color: Theme.inkFaint)
            content()
        }
    }
}

#Preview("Form fields") {
    FormFieldGallery()
}

#Preview("Form fields — accessibility sizes") {
    FormFieldGallery()
        .environment(\.dynamicTypeSize, .accessibility2)
}
