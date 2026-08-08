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
            // The samara from `Sycamore Logo v2.dc.html`, replacing the tennis ball. A ball
            // said "tennis"; the camp runs swim and soccer too, and a seed that travels and
            // takes root says what the product is for rather than which sport it started in.
            // The design's 3e — two seeds, the large one and a smaller turned one, the way a
            // sycamore drops them in pairs. Takes the mark's default variant.
            SycamoreAppMark(size: 56)
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
                isEmailFocused = false
                Task { await signInWithApple() }
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

    /// The system sheet, then the exchange. `nil` is a person who backed out of the sheet, and
    /// they are left exactly where they were — no banner, nothing to dismiss. Only Apple failing
    /// on its own account reaches the store, because everything after the token has its own
    /// error path through `perform`.
    ///
    /// Except on a debug simulator build, where the button skips all of it.
    ///
    /// This branch used to be the whole of `#if DEBUG`, because neither end of the real path was
    /// standing up: Sign In with Apple was not on the App ID and the Apple provider was not
    /// enabled in Supabase. Both are now on, so a debug build on a *device* takes the real path
    /// like every other build — which is the only way the exchange is ever exercised before
    /// release.
    ///
    /// What is left is the case where Apple cannot work whatever anyone configures. The simulator
    /// forces `ENTITLEMENTS_ALLOWED = NO`, so `com.apple.developer.applesignin` is stripped from
    /// the installed binary and `ASAuthorizationController` answers `.unknown` without drawing
    /// anything — there is no sheet to back out of and no token to exchange. Sending that to
    /// `signInFailed` would put a banner on screen 1 every time somebody ran the app on a Mac,
    /// reporting a misconfiguration that does not exist.
    ///
    /// `bypassSignIn` puts you in the app on the offline store instead. The email path is real in
    /// the simulator and is the way to exercise Postgres from one.
    private func signInWithApple() async {
        #if DEBUG && targetEnvironment(simulator)
        await store.bypassSignIn()
        #else
        do {
            guard let identity = try await AppleSignIn.authorize() else { return }
            await store.continueWithApple(
                identityToken: identity.identityToken, fullName: identity.fullName
            )
        } catch {
            store.signInFailed(error)
        }
        #endif
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

    /// The shared field in its `.outlined` box. The placeholder is still `verbatim:` — see
    /// `FormField`, which carries the reasoning now, and the bug it came from: a bare literal is
    /// a `LocalizedStringKey`, SwiftUI parses those as Markdown, and Markdown autolinks a bare
    /// email address. This exact string once rendered as a tinted link that ignored every
    /// foreground colour set on it.
    private var emailField: some View {
        @Bindable var store = store

        let field = FormField(
            "you@yourcamp.org",
            text: $store.emailInput,
            // The "Email" header above says what it is on screen; VoiceOver reads the field on
            // its own, and without this it would fall back to reading out the example address.
            label: "Email address",
            icon: "envelope",
            focus: $isEmailFocused
        )
        .autocorrectionDisabled()

        // Every one of these travels down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .submitLabel(.go)
        #else
        return field
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
