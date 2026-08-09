//
//  InlineRowEditor.swift
//  Sycamore
//
//  The chrome a settings row wears while it is being changed: the same title, with the detail
//  line replaced by a field and the caret replaced by the two buttons that resolve it.
//
//  The design never draws this state — it draws a caret and stops — so it is built out of the
//  pieces the design does specify: the sheet field's 13pt radius over the `grouped` plate, and
//  the header pill for the actions.
//
//  Three rows in section 8 open like this. `8s` opens "Your name" and "Emergency phone", and
//  `8t` opens "Camp name & sport". Two of them shared a type; the third was written out longhand
//  and said so in its own doc comment — "`8s`'s in-place phone editor for the shape". A
//  transcription is not a shared decision, and this one had already drifted in both of the ways
//  a transcription does:
//
//  - Setup's field passed its placeholder as a bare literal, which is a `LocalizedStringKey`
//    that SwiftUI parses as Markdown. That is the bug `FormField.swift:189-195` was written
//    about, harmless here only because "Camp name" holds nothing address-shaped.
//  - It named no `textContentType` at all, so the field that *renames* a camp offered no
//    AutoFill while the field that *creates* one asks for `.organizationName`
//    (`CreateCampView.swift:281`).
//
//  Neither was a decision anybody took. So the box moves here, next to `SettingsRow` — the row
//  this is the open state of — rather than staying in whichever feature happened to need it
//  first, which is where `SettingsRow` itself came from.
//
//  **Deliberately not `FormField`**, which is the app's shared text input and would be the
//  obvious answer. Its `FormFieldMetrics` presets are the boxes the design draws, and none of
//  them is this one — a `grouped` plate with no rule at 12/8 — so reaching for it means either
//  adding a preset to the design system for a box only these three rows draw, or redrawing the
//  emergency number in a box the design does not put it in. Both are worse than the field below.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Row in edit mode

/// A settings row that has opened into a field.
///
/// One type for every row that has one. It was `EmergencyPhoneEditor`, privately, until the name
/// row needed the identical box; the first pass at sharing kept two thin wrappers around a common
/// chrome view, and the two wrappers were then the same fifty lines twice over — the same
/// `@State`, the same `@FocusState`, the same seeding init, the same body, and an `input`
/// differing in a prompt and three keyboard modifiers. This is the argument `FormField.swift`
/// makes at length about the five screens that had each hand-rolled a text input, applied one
/// file down.
struct InlineRowEditor<Beneath: View>: View {

    /// What is being typed.
    ///
    /// A closed set of three rather than a `@ViewBuilder` for the field, because the part that
    /// differs is the *keyboard* — and a keyboard cannot be handed over as a view:
    /// `keyboardType`, `textContentType` and `textInputAutocapitalization` are modifiers on the
    /// `TextField` itself and are iOS-only. Named here as presets, the way `FormFieldMetrics`
    /// names the design's boxes, rather than as five more arguments.
    ///
    /// Deliberately still an enum with a `switch` per property, rather than a struct of stored
    /// properties with static presets — which is the shape `FormFieldMetrics`, `ChipMetrics` and
    /// `MoreRowMetrics` all take, and which the third case was the moment to reconsider. Three of
    /// the four things a case answers are iOS-only types, so a struct would have to put its
    /// stored properties behind `#if os(iOS)` and then every preset behind one too: three presets
    /// spelled out twice, the macOS half of each naming only the prompt. A `switch` per property
    /// puts the platform conditional in one place instead of four.
    enum Field {
        case campName
        case emergencyPhone
        case name

        /// The example shown while the field is empty. Drawn with `Text(verbatim:)` for the same
        /// reason every other placeholder in the app is: a bare literal is a `LocalizedStringKey`,
        /// SwiftUI parses those as Markdown, and Markdown autolinks anything address-shaped
        /// (`FormField.swift:189-195`).
        ///
        /// `8t`'s rename row showed "Camp name" here, which is its own title said a second time
        /// rather than an example of what to type. The example is the one `8b` already offers
        /// under the same label when the camp is first created (`CreateCampView.swift:269`), so
        /// the two fields that ask what a camp is called now suggest the same answer.
        var prompt: String {
            switch self {
            case .campName: "UCLA Tennis Camp"
            case .emergencyPhone: "(310) 555-0106"
            case .name: "Priya Nandan"
            }
        }

        #if os(iOS)
        var keyboard: UIKeyboardType {
            switch self {
            case .campName, .name: .default
            case .emergencyPhone: .phonePad
            }
        }

        /// A camp is an organisation, and `.organizationName` is what `8b` fills its name from
        /// (`CreateCampView.swift:281`). Deliberately not `.name`, which is the person signed in
        /// — offering somebody their own name as a camp's is worse than offering nothing.
        var contentType: UITextContentType {
            switch self {
            case .campName: .organizationName
            case .emergencyPhone: .telephoneNumber
            case .name: .name
            }
        }

        /// A phone number has no capitals; a person's name and a camp's are each capitalised by
        /// word.
        var capitalisation: TextInputAutocapitalization {
            switch self {
            case .campName, .name: .words
            case .emergencyPhone: .never
            }
        }
        #endif
    }

    let title: String
    let field: Field

    /// What VoiceOver calls the field, where the row is named for more than the field holds:
    /// `8t`'s row is "Camp name & sport" and only the first half of that is typed into. `nil`
    /// takes the title, which is what both rows on `8s` want.
    var fieldLabel: String?

    /// Whether Save will do anything, asked of the draft as it stands.
    ///
    /// Deliberately a predicate over the text rather than a `Bool` the caller works out and hands
    /// in. The draft lives in here, for the reason `text` gives below, so a caller has nothing to
    /// compute a `Bool` *from*: `8t`'s gate is `CampName.isValid` against the characters being
    /// typed, and a `Bool` settled when this was initialised would answer for the seed value and
    /// then never change again — a Save button that dims once and stays that way. A flat `Bool`
    /// gate is still expressible as `{ _ in flag }` for a row whose answer genuinely comes from
    /// somewhere other than its own field.
    ///
    /// It gates the keyboard's Return as well as the button, which is the one thing the copy this
    /// replaces did not: there the button dimmed and Return did not, so an empty name still
    /// reached `renameCamp` and was turned away by a guard on the far side of it.
    var isSaveEnabled: (String) -> Bool

    let onCancel: () -> Void
    let onSave: (String) -> Void

    /// Whatever else the row edits, drawn under the field and above the buttons. `8t` puts the
    /// camp's sport chips here; the two rows on `8s` have nothing to put, and say so by leaving
    /// this off.
    @ViewBuilder let beneath: Beneath

    /// Held here rather than bound up to the screen. Both callers are one enormous body —
    /// `ProfileView` is eleven computed `some View` properties, `SetupView` seventeen — so a
    /// draft living up there meant every character of a phone number or a camp's name rebuilt the
    /// whole screen to redraw one field. This editor is the only thing that reads the value while
    /// it is being typed, so it is the only thing that needs to hear about it.
    ///
    /// Seeded from what it is handed, so the row it replaces has no draft to prime before opening
    /// it: this is rebuilt from the account or the camp each time it appears.
    @State private var text: String

    @FocusState private var isFocused: Bool

    init(
        title: String,
        field: Field,
        value: String,
        fieldLabel: String? = nil,
        isSaveEnabled: @escaping (String) -> Bool = { _ in true },
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        @ViewBuilder beneath: () -> Beneath
    ) {
        self.title = title
        self.field = field
        self.fieldLabel = fieldLabel
        self.isSaveEnabled = isSaveEnabled
        self.onCancel = onCancel
        self.onSave = onSave
        self.beneath = beneath()
        _text = State(initialValue: value)
    }

    var body: some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13, alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(title)
                    .typeStyle(.rowLabel, color: Theme.ink)

                input
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.grouped,
                        in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    )

                // An `EmptyView` here is not a row of nothing: it resolves to no subview at all,
                // so a row with nothing to put under its field gets no 8pt gap where the nothing
                // would have been.
                beneath

                HStack(spacing: Spacing.small) {
                    Spacer(minLength: 0)
                    Pill("Cancel", tone: .outline, horizontalPadding: 13, verticalPadding: 8, action: onCancel)
                    Pill("Save", tone: .accent, horizontalPadding: 13, verticalPadding: 8, action: save)
                        // Refusing before the tap rather than after it: the alternative is a
                        // banner saying "Give the camp a name first" over a field that is already
                        // open. Ungated by default, because both of `8s`'s values are optional —
                        // an emergency number and a display name can each be cleared — so
                        // emptying either field is a real edit, and a gate there would be a
                        // control that refuses without saying so.
                        .opacity(canSave ? 1 : 0.45)
                        .disabled(!canSave)
                }
            }
        }
        // The tap that opened this row *was* the request to type, so the keyboard comes up with
        // the field. Deliberately unlike `YourNameView`, which is a whole screen arriving on its
        // own and lets the reader read the question before the keyboard covers half of it.
        .onAppear { isFocused = true }
    }

    private var canSave: Bool {
        isSaveEnabled(text)
    }

    /// Save, if Save is live. The `.disabled` above already stops the button; this is what stops
    /// the keyboard's own Return doing what the dimmed button refuses to.
    private func save() {
        guard canSave else { return }
        onSave(text)
    }

    private var input: some View {
        let base = TextField(
            "",
            text: $text,
            prompt: Text(verbatim: field.prompt).foregroundStyle(Theme.inkFaint)
        )
        .textFieldStyle(.plain)
        .typeStyle(.fieldValue, color: Theme.ink)
        .focused($isFocused)
        // Off for all three. On the two that hold names it is the one that matters: a surname the
        // dictionary has never seen is a surname, not a typo, and having it quietly rewritten is
        // worse here than anywhere else in the app. A camp called after one is the same problem.
        .autocorrectionDisabled()
        // The row's own title, unless the row is named for more than this field holds. Once the
        // caret is gone the field carries no visible label of its own, and "text field" is not
        // the name of a control.
        .accessibilityLabel(fieldLabel ?? title)
        .onSubmit(save)

        // Every one of these travels down the environment to the `TextField`.
        #if os(iOS)
        return base
            .keyboardType(field.keyboard)
            .textContentType(field.contentType)
            .textInputAutocapitalization(field.capitalisation)
            .submitLabel(.done)
        #else
        return base
        #endif
    }
}

// MARK: - Rows with nothing under the field

extension InlineRowEditor where Beneath == EmptyView {

    /// A row that is only its field, which is both of `8s`'s. Spelled as a second initialiser
    /// rather than as a defaulted `beneath:` argument, because a default for a `@ViewBuilder`
    /// parameter cannot pin the generic — `Beneath` has to be fixed by the call, and a call that
    /// says nothing about it fixes it to `EmptyView` here.
    init(
        title: String,
        field: Field,
        value: String,
        fieldLabel: String? = nil,
        isSaveEnabled: @escaping (String) -> Bool = { _ in true },
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.init(
            title: title,
            field: field,
            value: value,
            fieldLabel: fieldLabel,
            isSaveEnabled: isSaveEnabled,
            onCancel: onCancel,
            onSave: onSave,
            beneath: { EmptyView() }
        )
    }
}

// MARK: - Previews

/// All three rows open at once, which no screen ever draws and which is the whole point of the
/// harness: the chrome is one decision, and this is where it can be watched being made once.
///
/// The gate is written out here rather than reached for from `CampName`, which is a model. The
/// design system draws the dimmed button; it has no opinion on what a camp may be called.
#Preview("Rows in edit mode") {
    VStack(spacing: Spacing.gutter) {
        Card {
            InlineRowEditor(
                title: "Your name",
                field: .name,
                value: "Priya Nandan",
                onCancel: {},
                onSave: { _ in }
            )

            InlineRowEditor(
                title: "Emergency phone",
                field: .emergencyPhone,
                value: "",
                onCancel: {},
                onSave: { _ in }
            )
        }

        // Empty on purpose: a gated row is only worth drawing in the state its gate exists for.
        Card {
            InlineRowEditor(
                title: "Camp name & sport",
                field: .campName,
                value: "",
                fieldLabel: "Camp name",
                isSaveEnabled: { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                onCancel: {},
                onSave: { _ in }
            ) {
                Text("— the sport chips go here —")
                    .typeStyle(.detail, color: Theme.inkMuted)
            }
        }
    }
    .padding(Spacing.gutter)
    .background(Theme.surfaceWarm)
}
