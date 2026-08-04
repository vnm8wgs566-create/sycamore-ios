//
//  SignInView.swift
//  Sycamore
//
//  Screen 1 — Sign in. White, full bleed, 24pt gutters. The mark and the pitch sit at the
//  top, everything you can act on is pinned to the bottom within thumb reach.
//

import SwiftUI

struct SignInView: View {
    @Environment(AppStore.self) private var store
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            StatusBarMock()
            mark
            Spacer(minLength: Spacing.hero)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .onSubmit { Task { await store.submitEmail() } }
    }

    // MARK: Mark

    private var mark: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: Radius.cardLarge, style: .continuous)
                .fill(Theme.markTile)
                .frame(width: 56, height: 56)
                .overlay {
                    // The design's glyph is Phosphor's `tennis-ball` — a ball, not a player.
                    // `figure.tennis` was the wrong call: it reads as a figure mid-swing at
                    // 29pt and loses the mark's simplicity.
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 29, weight: .medium))
                        .foregroundStyle(Theme.lime)
                }
                .padding(.bottom, Spacing.hero)

            Text("Sycamore")
                .typeStyle(.display, color: Theme.ink)

            Text("Camp management for people standing on a court, not sitting at a desk.")
                .typeStyle(.body, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.hero)
        .padding(.top, 74)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: 0) {
            PrimaryButton("Continue with Apple", tone: .dark, systemImage: "apple.logo") {
                Task { await store.continueWithApple() }
            }

            divider
                .padding(.vertical, 20)

            Text("Email")
                .typeStyle(.sectionHeader, color: Theme.inkMuted)
                .padding(.bottom, Spacing.small)

            emailField
                .padding(.bottom, Spacing.row)

            // The design draws only the live button, so the disabled state stays restrained:
            // the same accent fill at the opacity "Create camp" already uses for its own
            // not-yet-valid state, rather than a colour the palette does not contain.
            // `submitEmail` still throws `.invalidEmail` for anything that gets past this —
            // the gate is the affordance, the throw is the backstop.
            PrimaryButton("Email me a code") {
                isEmailFocused = false
                Task { await store.submitEmail() }
            }
            .opacity(store.canSubmitEmail ? 1 : 0.45)
            .disabled(!store.canSubmitEmail)

            if let message = store.errorMessage {
                Text(message)
                    .typeStyle(.footnote, color: Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }

            Text("No passwords. Nothing to forget with wet hands.")
                .typeStyle(.footnote, color: Theme.inkFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Spacing.large)
        }
        .padding(.horizontal, Spacing.hero)
        .padding(.bottom, 48)
    }

    private var divider: some View {
        HStack(spacing: Spacing.medium) {
            Hairline(color: Theme.strokeAlt)
            Text("or")
                .typeStyle(.dividerLabel, color: Theme.inkFaint)
            Hairline(color: Theme.strokeAlt)
        }
    }

    // MARK: Email

    private var emailField: some View {
        @Bindable var store = store

        return HStack(spacing: Spacing.row) {
            Image(systemName: "envelope")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Theme.inkFaint)

            ZStack(alignment: .leading) {
                if store.emailInput.isEmpty {
                    // `foregroundStyle` rather than the colour argument: the `Text` overload
                    // of `typeStyle` resolves to the deprecated `Text.foregroundColor`, which
                    // the app's `.tint(Theme.accent)` was overriding — the placeholder came
                    // out accent blue instead of #A2A6AE.
                    // `verbatim:` matters here. A plain string literal becomes a
                    // LocalizedStringKey, which SwiftUI parses as Markdown — and Markdown
                    // autolinks bare email addresses. The placeholder was rendering as a
                    // tinted link (#1568F0) and ignoring every foreground colour we set.
                    Text(verbatim: "you@yourcamp.org")
                        .typeStyle(.fieldValue, color: Theme.inkFaint)
                }
                textField($store.emailInput)
            }
            .padding(.vertical, Spacing.large)
        }
        .padding(.horizontal, 15)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: BorderWidth.input)
        }
        .contentShape(Rectangle())
        .onTapGesture { isEmailFocused = true }
    }

    private func textField(_ text: Binding<String>) -> some View {
        let base = TextField("", text: text)
            .textFieldStyle(.plain)
            .typeStyle(.fieldValue, color: Theme.ink)
            .focused($isEmailFocused)
            .autocorrectionDisabled()

        #if os(iOS)
        return base
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .submitLabel(.go)
        #else
        return base
        #endif
    }
}

// MARK: - Previews

#Preview("Sign in") {
    SignInView()
        .environment(AppStore.previewSignedOut)
        .showsMockStatusBar()
}

#Preview("Sign in — typed") {
    let store = AppStore.previewSignedOut
    store.emailInput = "alex@uclacamp.org"
    return SignInView()
        .environment(store)
        .showsMockStatusBar()
}
