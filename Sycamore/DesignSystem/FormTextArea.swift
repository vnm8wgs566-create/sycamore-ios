//
//  FormTextArea.swift
//  Sycamore
//
//  The app's one *multi-line* text input, in the same four boxes `FormField` draws.
//
//  A sibling of `FormField` rather than a parameter on it, and it differs from that file in
//  exactly one expression — `axis: .vertical` plus a `lineLimit` range. Everything else is the
//  same three lines: `prompt:`, `.typeStyle`, `.focused`, then `formFieldChrome`. That modifier is
//  exposed rather than private to `FormField` precisely so a second caller can reuse the box; this
//  is the second caller.
//
//  Deliberately not `TextEditor`. Three reasons, in the order they bite:
//
//  1. It has no `prompt:` API, so a placeholder means going back to a grey `Text` overlaid behind
//     an empty control — the exact mechanism `FormField.swift:9-15` exists to record as removed.
//     An overlaid `Text` is a *sibling* of the field rather than part of its text layout, so it
//     sits on its own baseline and takes no part in selection or the clear button.
//  2. It brings its own background and text-container insets, which match no `FormFieldMetrics`
//     preset — so the box would be drawn twice, once by the chrome and once by AppKit/UIKit
//     underneath it, and the two would disagree by a few points at every size.
//  3. It behaves differently on macOS, and everything under `Sycamore/` has to typecheck and draw
//     there as well.
//
//  `axis: .vertical` keeps the control a `TextField`, so `prompt:`, `.typeStyle`, `.focused` and
//  `formFieldChrome` all carry over unchanged.
//
//  Deliberately a new type rather than an `axis:` parameter on `FormField`. Return means something
//  different here — a vertical field inserts a newline rather than submitting — so `FormField`'s
//  documented contract that "each screen keeps stating its own `submitLabel` / `onSubmit`" would
//  become conditional on a parameter, and a caller reading that comment would have to check which
//  axis it was talking about.
//

import SwiftUI

/// A wrapping text input in one of the design's four boxes.
///
/// The prompt is a `String` drawn with `Text(verbatim:)`, for the reason `FormField` states: a
/// bare literal becomes a `LocalizedStringKey`, SwiftUI parses those as Markdown, and Markdown
/// autolinks anything URL-ish into a tinted link that ignores the foreground colour set on it.
struct FormTextArea: View {
    @Binding var text: String
    /// The example value shown while the field is empty.
    let prompt: String
    /// What VoiceOver calls the field.
    let label: String
    var metrics: FormFieldMetrics
    var type: TypeStyle
    /// The prompt's own style, where the design draws it a step off the value. `nil` follows the
    /// value, which is what SwiftUI does unaided.
    var promptType: TypeStyle?
    /// How tall the box is allowed to get, in lines. It opens at the lower bound and grows to the
    /// upper one before the text starts scrolling inside it — a range rather than a single number
    /// because a description field that is one line tall reads as a single-line field, and one
    /// that is six lines tall before anything is typed reads as a hole in the sheet.
    var lineLimit: ClosedRange<Int>
    /// Focus lives with the caller, for the reason `FormField` gives: a screen that puts the
    /// keyboard down before it acts cannot reach a `@FocusState` owned by this struct.
    var focus: FocusState<Bool>.Binding

    init(
        _ prompt: String,
        text: Binding<String>,
        label: String,
        metrics: FormFieldMetrics = .sheetBox,
        type: TypeStyle = .fieldValue,
        promptType: TypeStyle? = nil,
        lineLimit: ClosedRange<Int> = 3...6,
        focus: FocusState<Bool>.Binding
    ) {
        self.prompt = prompt
        self._text = text
        self.label = label
        self.metrics = metrics
        self.type = type
        self.promptType = promptType
        self.lineLimit = lineLimit
        self.focus = focus
    }

    var body: some View {
        input
            // No `icon:`. A leading glyph is centred against a one-line box by `formFieldChrome`'s
            // `HStack`, and against a six-line one it would float in the middle of the paragraph.
            .formFieldChrome(metrics)
            .onTapGesture { focus.wrappedValue = true }
    }

    /// A property rather than inline in `body` because `prompt:` wants a `Text` built two steps
    /// back — the same shape `FormField.input` takes.
    private var input: some View {
        TextField("", text: $text, prompt: promptText, axis: .vertical)
            .lineLimit(lineLimit)
            .textFieldStyle(.plain)
            .typeStyle(type, color: Theme.ink)
            .focused(focus)
            .accessibilityLabel(label)
    }

    /// `typeStyleRun` rather than a bare `.foregroundStyle`: the prompt is drawn inside the
    /// field's own text layout, so it needs the face and the tracking as well as the colour.
    private var promptText: Text {
        Text(verbatim: prompt)
            .typeStyleRun(promptType ?? type, color: metrics.promptColor)
    }
}

// MARK: - Previews

/// Empty and filled, side by side. Each field needs its own `@FocusState`, which a `#Preview` body
/// cannot declare two of, so the gallery is a view — the same accommodation `FormFieldGallery`
/// makes.
private struct FormTextAreaGallery: View {
    @State private var empty = ""
    @State private var filled = """
        Cones on the service line, cart stays north. Volley ladder after the forehand feeds, then \
        swap the two outside courts.
        """

    @FocusState private var emptyFocus: Bool
    @FocusState private var filledFocus: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                labelled("sheetBox — empty") {
                    FormTextArea(
                        "What happens in this block",
                        text: $empty,
                        label: "Description",
                        type: .rowTitleSm,
                        promptType: .rowValue,
                        focus: $emptyFocus
                    )
                }

                labelled("sheetBox — grown to its upper bound") {
                    FormTextArea(
                        "What happens in this block",
                        text: $filled,
                        label: "Description",
                        type: .rowTitleSm,
                        promptType: .rowValue,
                        focus: $filledFocus
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

#Preview("Form text areas") {
    FormTextAreaGallery()
}

#Preview("Form text areas — accessibility sizes") {
    FormTextAreaGallery()
        .environment(\.dynamicTypeSize, .accessibility2)
}
