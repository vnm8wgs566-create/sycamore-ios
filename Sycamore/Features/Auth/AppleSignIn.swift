//
//  AppleSignIn.swift
//  Sycamore
//
//  Screen 1's "Continue with Apple", from the tap to the JWT GoTrue wants. Nothing here talks to
//  Supabase: it hands `AppStore.continueWithApple` a token and a name and stops.
//
//  `SignInWithAppleButton` would have saved this file, and it is not used. That view draws Apple's
//  own label in SF Pro and owns its corner radius; screen 1 wants Manrope Bold 16.5 at −0.015em on
//  a 56pt plate at `Radius.button`, which is what `PrimaryButton` already makes. Adopting it would
//  leave the screen with one button in the app's type and one in the system's, stacked. Apple's
//  guidelines allow a button you draw yourself as long as it keeps the mark, the wording and the
//  size — this one does — so the cost of exactness is `ASAuthorizationController` by hand.
//

import Foundation

#if os(iOS)
import AuthenticationServices
#endif

/// One authorisation, reduced to the two things the app can use.
struct AppleIdentity: Sendable, Hashable {
    /// The JWT Apple signed. GoTrue validates it against Apple and mints its own session from the
    /// address inside, which is why nothing here needs to read it.
    var identityToken: String
    /// `nil` on every authorisation after the first.
    ///
    /// Apple releases the name once — the first time this Apple ID ever authorises this app — and
    /// never again, on any device, after any reinstall, until the person revokes the app in
    /// Settings. Whoever receives this has one chance to write it down.
    var fullName: String?
}

#if os(iOS)

/// Runs the system sheet and answers with what came back.
@MainActor
enum AppleSignIn {

    /// `nil` means the person backed out of the sheet. That is not a failure and must not raise
    /// screen 1's banner — dismissing the sheet is how you say "not this way", and being told off
    /// for it would be the app arguing with a decision it just asked for.
    static func authorize() async throws -> AppleIdentity? {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Deliberately no `request.nonce`. Setting one puts a `nonce` claim in the JWT, and GoTrue
        // rejects a token carrying a claim it was not also given the raw value for — and
        // `SupabaseAuth.signInWithApple` posts `provider` and `id_token`, nothing else. The replay
        // window a nonce would close is Apple's own token, sent over TLS to one endpoint.

        return try await AuthorizationDelegate().run(
            ASAuthorizationController(authorizationRequests: [request])
        )
    }
}

/// `ASAuthorizationController` reports through two delegate callbacks and holds its delegate
/// weakly, so this bridges the pair into one `await` and keeps itself alive across the suspension:
/// the sheet outlives every local that opened it.
///
/// Resumes with `AppleIdentity?` rather than the `ASAuthorization` — the credential is read here,
/// on the main actor it arrived on, so nothing non-`Sendable` crosses the continuation.
@MainActor
private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<AppleIdentity?, any Error>?
    /// Self, until an answer arrives. See the type comment.
    private var whileInFlight: AuthorizationDelegate?

    func run(_ controller: ASAuthorizationController) async throws -> AppleIdentity? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.whileInFlight = self
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8)
        else {
            // An authorisation with no readable token is nothing the coach can act on, and there
            // is no second route through this button. The screen sends them to the email field.
            finish(.failure(SycamoreError.appleSignInUnavailable))
            return
        }
        let identity = AppleIdentity(
            identityToken: token, fullName: Self.name(from: credential.fullName)
        )
        finish(.success(identity))
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithError error: any Error
    ) {
        if let failure = error as? ASAuthorizationError, failure.code == .canceled {
            finish(.success(nil))
        } else {
            finish(.failure(error))
        }
    }

    /// The sheet needs a window to sit over. The app declares a single scene, so the key window is
    /// the only window there is; the bare anchor at the end cannot be reached while a button in
    /// that window is being tapped, and exists because the protocol will not take `nil`.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<AppleIdentity?, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
        whileInFlight = nil
    }

    /// Apple sends components, not a string. `.medium` is given plus family — the name a person
    /// would put on a roster, without the prefixes and suffixes `.long` would drag in.
    private static func name(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = components.formatted(.name(style: .medium))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

#else

/// macOS exists here only so `swift build` can typecheck the module without an iOS SDK — see
/// `Package.swift`. There is no Mac app, so there is no window to present a sheet over and no
/// point pretending otherwise.
@MainActor
enum AppleSignIn {
    static func authorize() async throws -> AppleIdentity? {
        throw SycamoreError.appleSignInUnavailable
    }
}

#endif
