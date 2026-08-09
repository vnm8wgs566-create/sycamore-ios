//
//  YourNameView.swift
//  Sycamore
//
//  The first question after signing in: what the camp should call you.
//
//  Nothing had ever asked. `Account.displayName` is written on exactly one occasion — the first
//  authorisation an Apple ID ever gives the app, which releases the name once and never again
//  (`AppStore.swift:766-772`) — so everybody who signed in with an email address arrived with an
//  empty one. They showed up in the staff list as a blank, their court's assignment line named
//  nobody, and the avatar in every header drew two initials of nothing. Profile can edit it now,
//  and Profile is behind a camp you may not have yet, so it is asked here as well.
//
//  Asked *before* the camp question rather than after, because it is the shorter of the two and
//  because the next screen's copy is about what the camp will call you.
//
//  Drawn as screen 3 is drawn — the mark, a serif heading, the page in `surfaceWarm` — so that
//  the two screens between signing in and a camp are one moment rather than two designs.
//

import SwiftUI

struct YourNameView: View {

    let email: String
    let onSave: (String) -> Void
    /// "Not now". The question is derived from the account rather than from a cursor
    /// (`FirstRunStep`), so without a way past it a person who will not type a name cannot reach
    /// the app at all.
    let onSkip: () -> Void

    /// Held here, in the view that draws the field, rather than lifted to whatever presents this.
    /// The rule this follows is `ProfileView`'s emergency-number editor's and
    /// `CreateCampView.swift:43-54`'s: a draft one level up means every character re-renders a
    /// screen that has nothing else to say. Here it also keeps the store out of the loop until
    /// there is something worth writing.
    ///
    /// Seeded from the account, which is nearly always empty here — this screen is only reached
    /// while it is. Handed in rather than read from the store, the same shape the two Profile
    /// editors take, so the seed is a value this view is given rather than a lookup it performs.
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(
        currentName: String,
        email: String,
        onSave: @escaping (String) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.email = email
        self.onSave = onSave
        self.onSkip = onSkip
        _name = State(initialValue: currentName)
    }

    var body: some View {
        VStack(spacing: 0) {
            FirstRunHeader(title: "What should we call you?", email: email)
            Hairline(color: Theme.hairline)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, the page colour behind every section 8 screen.
        .background(Theme.surfaceWarm)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
                VStack(alignment: .leading, spacing: 0) {
                    IntakeSectionHeader("Your name")
                    nameField
                }

                Text("This is what the camp sees — on the staff list, beside your court, and on the day's sheet.")
                    .typeStyle(.intakeRowDetail, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 5)

                PrimaryButton(
                    "That's me",
                    height: OnboardingMetrics.ctaHeight,
                    radius: OnboardingMetrics.cardRadius,
                    font: .intakeButton,
                    action: save
                )
                // Gated on what is in the field. Empty is not a name, and saving one would put
                // the person straight back on this screen — the step is derived from the account
                // (`FirstRunStep`), so an empty write is a no-op with a round trip in it.
                .opacity(isNameUsable ? 1 : 0.45)
                .disabled(!isNameUsable)
                // `margin:2px 2px 0` — the button is inset a touch from the card above it.
                .padding(.horizontal, Spacing.hairGap)
                .padding(.top, Spacing.hairGap)

                skip
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, OnboardingMetrics.contentBottom)
        }
        // A thumb already on the page is the faster way to put the keyboard down.
        .scrollDismissesKeyboard(.interactively)
    }

    // Deliberately not auto-focused. `EmergencyPhoneEditor` and `DisplayNameEditor` raise the
    // keyboard on appear because they are a row that has just swapped itself for a field, and the
    // tap that opened them *was* the request to type. This is a whole screen arriving on its own,
    // and the other two full-screen fields in the flow — sign-in's address and `8b`'s camp name —
    // both let the reader read the question first. A keyboard that appears unasked over "Not now"
    // is the same discourtesy in every app that does it.

    /// Read twice per pass of `content`, which re-runs on every character typed — so it asks
    /// whether there is a non-space in the field rather than allocating a trimmed copy to
    /// measure. Same answer, no allocation.
    private var isNameUsable: Bool {
        name.contains { !$0.isWhitespace }
    }

    /// Both ways of answering the question end here — the button and the return key — so the
    /// keyboard is put away in one place and the guard is stated once. `CreateCampView.saveTheShape`
    /// does the same for the same reason.
    private func save() {
        guard isNameUsable else { return }
        isFocused = false
        onSave(name)
    }

    private var nameField: some View {
        let field = FormField(
            "Priya Nandan",
            text: $name,
            label: "Your name",
            metrics: .intakeCard,
            type: .intakeFieldTitle,
            focus: $isFocused
        )
        // A surname the dictionary has never seen is a surname, not a typo. This is the field in
        // the app where a silent rewrite would do the most damage.
        .autocorrectionDisabled()
        // Outside the `#if`: `onSubmit` is cross-platform and the return key is the only way to
        // answer this on a Mac. It is `submitLabel` that is iOS-only.
        .onSubmit(save)

        // Every one of these travels down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return field
        #endif
    }

    /// Quiet, centred, and under the button rather than beside it — this is the way out, not the
    /// other half of a choice.
    private var skip: some View {
        Button(action: onSkip) {
            Text("Not now")
                .typeStyle(.intakeFootnote, color: Theme.inkMuted)
                .frame(maxWidth: .infinity)
                // Grown to the 44pt minimum first, then given the shape — that order is what
                // makes the taller frame take the touch rather than only lay the label out.
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Skips this and asks again next time you sign in")
    }
}

// MARK: - Previews

#Preview("What should we call you?") {
    YourNameView(
        currentName: "",
        email: "alex@uclacamp.org",
        onSave: { _ in },
        onSkip: {}
    )
    .showsMockStatusBar()
}

/// The rarer state: an account that already has a name reaching this screen, which only happens
/// if somebody clears it and signs in again. The field starts from what is stored rather than
/// from nothing.
#Preview("What should we call you? — already named") {
    YourNameView(
        currentName: "Alex Ramos",
        email: "alex@uclacamp.org",
        onSave: { _ in },
        onSkip: {}
    )
    .showsMockStatusBar()
}

#Preview("What should we call you? — large type") {
    YourNameView(
        currentName: "",
        email: "alex@uclacamp.org",
        onSave: { _ in },
        onSkip: {}
    )
    .showsMockStatusBar()
    .dynamicTypeSize(.accessibility1)
}
