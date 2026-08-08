//
//  InboxPinnedComposer.swift
//  Sycamore
//
//  The last row of the pinned card: where an admin writes a message the whole camp will see.
//
//  Single-line, and that is the right shape rather than a limitation. A pinned message is read on
//  Overview as a one-line banner clipped at the edge of the screen — `PinnedNoteBanner` sets
//  `lineLimit(1)` — so anything past a sentence is written to be truncated. The column agrees:
//  `char_length(title) between 1 and 120`.
//
//  The "Pin" button appears with the first character and goes again when the field empties,
//  rather than sitting there greyed out. A control that is present but inert asks the reader to
//  work out why; a control that arrives when there is something to do does not.
//

import SwiftUI

struct InboxPinnedComposer: View {

    /// Owned by `InboxPinnedList`, which is the half that can tell whether the write landed and
    /// therefore the half entitled to clear it.
    @Binding var draft: String
    let onPin: () -> Void

    /// Focus lives with the caller of `FormField` by design, and this is that caller: the field
    /// itself holds no `@FocusState`, so the keyboard can be put down by whatever acts on the
    /// text. Here that is the "Pin" button and the return key.
    @FocusState private var isFocused: Bool

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmed: String { PinnedMessage.trimmed(draft) }
    private var isValid: Bool { PinnedMessage.isValid(trimmed) }
    private var overrun: Int { PinnedMessage.overrun(trimmed) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            layout {
                field
                if isValid {
                    InboxActionButton("Pin", action: pin)
                }
            }

            if overrun > 0 { overrunHint }
        }
        .padding(.horizontal, InboxMetrics.rowPaddingH)
        .padding(.vertical, InboxMetrics.rowPaddingV)
        // The button arriving beside the field narrows the field, which is position — so it rides
        // the app's one fold curve rather than a duration invented here, and stops outright for a
        // reader who has asked for less motion.
        .animation(Motion.fold(reduceMotion: reduceMotion), value: isValid)
        .animation(Motion.fold(reduceMotion: reduceMotion), value: overrun > 0)
    }

    /// At the accessibility sizes the button goes under the field instead of beside it. Side by
    /// side, a 44pt "Pin" against a field whose text has doubled leaves the field about four
    /// characters wide — and the field is the point of the row.
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.row))
    }

    private var field: some View {
        let input = FormField(
            "Pin a message for the camp",
            text: $draft,
            label: "Pinned message",
            metrics: .sheetBox,
            type: .rowTitleSm,
            // A placeholder is a weight lighter than a value in this design, as the pick-up
            // sheet's is, so the two read apart before the colour difference lands.
            promptType: .rowValue,
            icon: "pin",
            focus: $isFocused
        )

        // Both travel down the environment to the `TextField` inside `FormField`, and both are
        // iOS-only — everything under `Sycamore/` also compiles for macOS.
        #if os(iOS)
        return input
            // Sentences, not words: this is a sentence about the camp, not a name. Autocorrect
            // stays on for the same reason — the dictionary can help with "loose".
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .onSubmit(pin)
        #else
        return input.onSubmit(pin)
        #endif
    }

    /// Said in characters because that is the unit the limit is in, and counted the way
    /// `PinnedMessage` counts — so the number on screen is the number being measured.
    private var overrunHint: some View {
        Text("^[\(overrun) character](inflect: true) too many · \(PinnedMessage.lengthLimits.upperBound) is the limit")
            .typeStyle(InboxType.rowDetail, color: Theme.danger)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Guarded as well as gated by the button's presence: the return key reaches this too, and it
    /// is available whether or not the button is drawn.
    private func pin() {
        guard isValid else { return }
        isFocused = false
        onPin()
    }
}

// MARK: - Previews

/// A `#Preview` body cannot hold the `@State` the composer writes into, so the gallery is a view.
///
/// Unguarded, for the reason `InboxPreviewItems` sets out: the two `#Preview` blocks under it
/// compile in release whether or not the gallery does.
private struct InboxPinnedComposerGallery: View {
    @State private var empty = ""
    @State private var typed = "Court 4 net is loose — keep the little ones off it."
    @State private var tooLong = String(repeating: "net is loose. ", count: 12)

    var body: some View {
        VStack(spacing: Spacing.large) {
            Card(radius: InboxMetrics.cardRadius) {
                InboxPinnedComposer(draft: $empty) {}
            }
            Card(radius: InboxMetrics.cardRadius) {
                InboxPinnedComposer(draft: $typed) {}
            }
            Card(radius: InboxMetrics.cardRadius) {
                InboxPinnedComposer(draft: $tooLong) {}
            }
        }
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
    }
}

#Preview("Pinned composer") {
    InboxPinnedComposerGallery()
}

/// Where the button has to move under the field.
#Preview("Pinned composer — accessibility1") {
    InboxPinnedComposerGallery()
        .environment(\.dynamicTypeSize, .accessibility1)
}
