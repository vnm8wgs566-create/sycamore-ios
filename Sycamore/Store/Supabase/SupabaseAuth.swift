//
//  SupabaseAuth.swift
//  Sycamore
//
//  Screens 1 and 2 against GoTrue: post a six-digit code to an address, trade the code for a
//  session, hold the session while the app runs.
//
//  Held in memory only. There is no keychain write here, so closing the app signs you out —
//  which is exactly what `AppStore` already assumes, since it starts every launch at
//  `.signedOut` and shows screen 1. Persisting the refresh token is a product decision (stay
//  signed in for a fortnight?) with a keychain entitlement attached, and inventing it here would
//  make the app behave in a way no screen describes.
//
//  One thing this cannot do from the client and shouldn't: delete the `auth.users` row. That
//  needs the service role key, which does not belong in a shipped binary. See
//  `SupabaseRepository.deleteAccount(id:)` for what happens instead.
//

import Foundation

actor SupabaseAuth {

    /// What a successful sign-in hands back. `expiresAt` is absolute rather than the `expires_in`
    /// seconds GoTrue sends, because the interesting question is always "is it still good now".
    struct Session: Sendable, Hashable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: UUID
        var email: String
    }

    private var session: Session?
    /// The refresh in flight, if there is one. See `refresh()`.
    private var refreshTask: Task<Session, any Error>?
    /// Bumped by `signOut`. See `adopt(_:from:)`.
    private var signOutEpoch = 0
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// The `Authorization` header for a PostgREST call.
    ///
    /// Falls back to the publishable key rather than throwing: PostgREST wants the header on
    /// every request including anonymous ones, and the reads that happen before anybody signs in
    /// — checking an invite code, say — are meant to work.
    var bearerToken: String {
        session?.accessToken ?? SupabaseConfig.publishableKey
    }

    // MARK: Getting in

    /// Screen 1. GoTrue answers 200 with an empty body once the mail is away.
    ///
    /// Whether the message contains six digits or a magic link is a property of the project's
    /// email template, not of this call — the template has to interpolate `{{ .Token }}` for
    /// screen 2 to have anything to type.
    func requestCode(email: String) async throws {
        _ = try await post("otp", body: ["email": .text(email), "create_user": .bool(true)])
    }

    /// Screen 2.
    func verify(code: String, email: String) async throws -> Session {
        let epoch = signOutEpoch
        let data = try await post(
            "verify", body: ["email": .text(email), "token": .text(code), "type": .text("email")]
        )
        return try adopt(data, from: epoch)
    }

    /// Screen 1's "Continue with Apple". `identityToken` is the JWT out of `ASAuthorization`;
    /// GoTrue validates it against Apple and mints its own session from the address inside.
    func signInWithApple(identityToken: String) async throws -> Session {
        let epoch = signOutEpoch
        let data = try await post(
            "token", query: "grant_type=id_token",
            body: ["provider": .text("apple"), "id_token": .text(identityToken)]
        )
        return try adopt(data, from: epoch)
    }

    /// Best-effort: the local session is dropped whether or not the server acknowledges, because
    /// a coach who taps "Sign out" on a dead connection must still end up signed out.
    func signOut() async {
        signOutEpoch &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        if session != nil {
            _ = try? await post("logout", body: RowValues([:]))
        }
        session = nil
    }

    /// Trades the refresh token for a new access token. Called by `PostgRESTClient` when a
    /// request comes back 401, which is the only reliable signal that the old one has gone stale.
    ///
    /// Single-flight, and that is not an optimisation. Loading a camp fans out into eight
    /// concurrent requests; an expired token means eight simultaneous 401s and, without this,
    /// eight simultaneous refreshes replaying the same token. Supabase rotates refresh tokens and
    /// reads a replay outside its reuse window as theft — it revokes the whole family, so the
    /// naive version signs the coach out for opening a screen.
    @discardableResult
    func refresh() async throws -> Session {
        if let inFlight = refreshTask { return try await inFlight.value }
        guard let refreshToken = session?.refreshToken else { throw SupabaseError.notSignedIn }

        let task = Task { try await self.exchange(refreshToken: refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            return try await task.value
        } catch {
            // A rotated or revoked token is not coming back, and holding the dead access token
            // would 401 every later request — including the anonymous reads that are meant to
            // work signed out — with no route to the sign-in screen but killing the app.
            if let failure = error as? SupabaseError, case .rejected = failure { session = nil }
            throw error
        }
    }

    private func exchange(refreshToken: String) async throws -> Session {
        let epoch = signOutEpoch
        let data = try await post(
            "token", query: "grant_type=refresh_token",
            body: ["refresh_token": .text(refreshToken)]
        )
        return try adopt(data, from: epoch)
    }

    // MARK: Plumbing

    /// Every call that mints a session suspends in the middle, so "did the person sign out while
    /// this was in the air" is a real question with a real wrong answer: a refresh landing after
    /// a sign-out would hand the actor a live token for an account the app has already left.
    private func adopt(_ data: Data, from epoch: Int) throws -> Session {
        let decoded: TokenResponse
        do {
            decoded = try SupabaseCoding.decoder().decode(TokenResponse.self, from: data)
        } catch {
            throw SupabaseError.malformedResponse("sign-in response: \(error)")
        }
        guard let userID = UUID(uuidString: decoded.user.id) else {
            throw SupabaseError.malformedResponse("sign-in response carried no user id")
        }
        let session = Session(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: .now.addingTimeInterval(TimeInterval(decoded.expiresIn)),
            userID: userID,
            email: decoded.user.email ?? ""
        )
        if epoch == signOutEpoch { self.session = session }
        return session
    }

    private func post(
        _ path: String, query: String? = nil, body: RowValues
    ) async throws -> Data {
        var components = URLComponents(
            url: SupabaseConfig.authURL.appending(path: path), resolvingAgainstBaseURL: false
        )
        components?.percentEncodedQuery = query
        guard let url = components?.url else {
            throw SupabaseError.malformedResponse("could not build an auth URL for \(path)")
        }

        var request = URLRequest(url: url, timeoutInterval: SupabaseConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try SupabaseCoding.encoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw SupabaseError.transportFailure(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw SupabaseError.rejected(status: status, message: Self.message(in: data))
        }
        return data
    }

    /// GoTrue has used three shapes for an error body across its versions and still emits two of
    /// them, so all three are read rather than betting on one.
    private static func message(in data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        for key in ["msg", "error_description", "message", "error"] {
            if let text = json[key] as? String, !text.isEmpty { return text }
        }
        return ""
    }
}

// MARK: - Wire types

private struct TokenResponse: Decodable {
    struct User: Decodable {
        var id: String
        var email: String?
    }

    var accessToken: String
    var refreshToken: String
    var expiresIn: Int
    var user: User
}
