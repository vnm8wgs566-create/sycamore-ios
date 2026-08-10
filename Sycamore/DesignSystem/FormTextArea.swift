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
//  ── Which is also why it needs a way out, and every caller must give it one ────────────────────
//
//  That last paragraph names the trap it walks into. A horizontal field's Return key is its way out
//  — `submitLabel(.done)` and an `onSubmit` that drops focus. Return here types a newline, so a
//  field on a screen with no bar, no drag-to-dismiss and no tap-outside is a keyboard that cannot
//  be put down: the block editor's description had exactly that, with the Save button underneath it
//  and out of reach. **A screen that draws one of these owes it a way out**, and there is no way
//  for this file to enforce that — so it is written down here instead.
//
//  `keyboardDoneBar` below is that way out, one per screen. It is measured working in a sheet and,
//  since this was written, measured working inside a `fullScreenCover` too — so how the screen is
//  presented is no longer the fork it used to be described as. Its own doc says what was run where.
//
//  The caveat that survives is about *checking*, not about covers: the bar installs silently or not
//  at all, and a dead one is indistinguishable from a live one in the source. A screen whose only
//  way out this is should be walked once by hand. Where that is awkward, drawing the control in the
//  view is still right — `BlockNotesCard.doneButton` is the worked example.
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
    /// The ink the typed value is drawn in.
    ///
    /// `Theme.ink` was hard-coded here until section 5a, which sets the block editor's
    /// description in the warm ink (`#3F4A44` — `Theme.inkWarm`) the design system reserves for
    /// body copy, keeping `ink` for titles and names. Both are right for their own field: a
    /// pick-up note is a fact about one kid and reads as a title, a block description is a
    /// paragraph. So it is a parameter defaulted to what every existing caller already drew.
    var valueColor: Color
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
        valueColor: Color = Theme.ink,
        lineLimit: ClosedRange<Int> = 3...6,
        focus: FocusState<Bool>.Binding
    ) {
        self.prompt = prompt
        self._text = text
        self.label = label
        self.metrics = metrics
        self.type = type
        self.promptType = promptType
        self.valueColor = valueColor
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
            .typeStyle(type, color: valueColor)
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

// MARK: - The way out

extension View {

    /// The "Done" bar over the keyboard, and the app's only spelling of it.
    ///
    /// It was the second for a while. `AddPlayerView` hand-rolled the same `ToolbarItemGroup`, and
    /// its comment gives the reason a screen needs one at all: the number pad has no return key,
    /// and the pinned "Add" sits under the keyboard while it is up, so this is the way out that
    /// does not need a free hand for a drag. A `FormTextArea` is the same problem arrived at from
    /// the other side — its Return key exists and types a newline — which is why one control
    /// covers both. That screen now calls this, so the two copies are one.
    ///
    /// ── Applied by the screen, not by the field ───────────────────────────────────────────────
    ///
    /// This is the decision worth writing down, because the obvious arrangement is the other one:
    /// put the `.toolbar` inside `FormTextArea` and every caller is fixed at once, which is this
    /// codebase's usual instinct about altitude. It was rejected on two counts.
    ///
    /// `ToolbarItemPlacement.keyboard` is a property of the *presentation context*, not of a field.
    /// Declared on one field and the bar appears over a *sibling* field's keyboard — measured on a
    /// simulator, two fields on one sheet, the bar declared on the first and the second focused.
    /// So a bar declared inside the component would come up over a sibling's keyboard with its only
    /// action being `focus.wrappedValue = false` on a field that is not the focused one. On the
    /// block editor that sibling is the title, and a Done button that does nothing is worse than no
    /// Done button: the reader has been told there is a way out and there is not.
    ///
    /// And two of these on one screen would declare the bar twice. It does not happen today — the
    /// editor draws one (`BlockEditorSheet.swift:164`) and the notes composer draws one
    /// (`BlockNotesCard.swift:169`), on different screens — but `FormTextAreaGallery` below puts
    /// two side by side, which is what a screen doing the same would look like.
    ///
    /// So the closure is the caller's, and it clears every focus that screen owns. The cost is that
    /// a new caller can forget; the header above says so in as many words, which is the trade.
    ///
    /// ── It does install inside a `fullScreenCover`, and this used to say it did not ───────────
    ///
    /// That unresolved case has been run. `AddPlayerView` was walked to by hand on a simulator —
    /// iPhone 17 Pro Max, iOS 26.5 — through the cover it actually ships behind: enrolment, opened
    /// from `CreateCampView:111` via `fullScreenPresentation`, with `EnrolmentFlowView`'s own
    /// `NavigationStack` in between. Focusing the age field raised the bar over the number pad, and
    /// tapping Done put both away. So a cover does not block `.keyboard` placement, and
    /// `AddPlayerView`'s bar was never dead.
    ///
    /// What the earlier measurement found is therefore narrower than the rule written from it. It
    /// reported the bar missing inside `8l`'s block-detail cover at three depths, one of them with
    /// a `NavigationStack` in between — which is the arrangement that demonstrably works above. The
    /// two do not agree and the block-detail one has not been re-run, so what is left is a single
    /// unreproduced negative, not a fact about covers. Anyone touching `8l`'s keyboard handling
    /// should re-measure rather than trust either result.
    ///
    /// The part worth keeping is the failure *mode*, which is real whatever the cause: this
    /// installs silently or not at all. It compiles either way and a dead bar reads exactly like a
    /// live one, so a screen whose only way out this is deserves one pass by hand. Where that is
    /// awkward — or where the way out belongs inline with the screen's own buttons rather than
    /// floating over the keyboard — drawing it in the view is still right.
    /// `BlockNotesCard.doneButton` is that, and stays that.
    ///
    /// Nothing for the Mac: `.keyboard` placement is iOS-only, and a Mac has an Escape key.
    func keyboardDoneBar(_ dismiss: @escaping () -> Void) -> some View {
        #if os(iOS)
        return toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: dismiss)
            }
        }
        #else
        return self
        #endif
    }
}

// MARK: - Previews

/// Empty and filled, side by side. Each field needs its own `@FocusState`, which a `#Preview` body
/// cannot declare two of, so the gallery is a view — the same accommodation `FormFieldGallery`
/// makes.
///
/// One `keyboardDoneBar` for the pair, which is the arrangement `keyboardDoneBar`'s own comment
/// argues for: two fields on a screen still get one bar, and it clears whichever of them has the
/// keyboard.
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
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar {
            emptyFocus = false
            filledFocus = false
        }
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
