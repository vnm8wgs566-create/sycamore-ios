//
//  StorageClient.swift
//  Sycamore
//
//  The three Storage calls this app makes — put an object, fetch one, delete one — over
//  `URLSession` and nothing else.
//
//  A sibling of `PostgRESTClient` and written for the same reason it was: the surface is three
//  verbs and two headers, and taking `supabase-swift` (and its transitive graph, its version pin
//  and an SPM resolution step in every clean build) to avoid a hundred lines would be a poor trade
//  in a project that has no dependencies at all. What is shared with that file is the pattern
//  rather than the code — the auth actor, the refresh-once-on-401 dance, the `SupabaseError`
//  vocabulary — because the two speak different protocols underneath: PostgREST answers JSON and
//  Storage answers bytes.
//
//  ── One bucket, private, one folder per person ────────────────────────────────────────────────
//
//  `avatars` is not public. A coach's face is not something to publish at a guessable URL, and the
//  app always holds a session when it needs one, so the fetch below is an authenticated GET rather
//  than a signed link with an expiry to manage.
//
//  Every object lives at `<uid>/avatar.jpg`, and that path is the whole of the access control:
//  the four policies on `storage.objects` compare `(storage.foldername(name))[1]` against
//  `auth.uid()`. A fixed leaf rather than a fresh name per upload, because a new photo should
//  *replace* the old one — otherwise every person accumulates every picture they have ever taken
//  and nothing ever deletes them.
//
//  That fixed name is also why the URL written into `profiles.avatar_url` is not a cache key. It
//  is stable across uploads, so anything that caches by URL — `URLSession`'s own cache included —
//  would keep serving the previous face. `fetch` asks for `reloadIgnoringLocalCacheData`; see it.
//

import Foundation

struct StorageClient: Sendable {

    private let auth: SupabaseAuth
    private let urlSession: URLSession

    init(auth: SupabaseAuth, urlSession: URLSession = .shared) {
        self.auth = auth
        self.urlSession = urlSession
    }

    // MARK: - The avatars bucket

    enum Bucket {
        static let avatars = "avatars"
    }

    /// Where one person's photo lives. See the header for why the leaf is fixed.
    static func avatarPath(for accountID: Account.ID) -> String {
        "\(accountID.uuidString.lowercased())/avatar.jpg"
    }

    // MARK: - Verbs

    /// Writes `data` to `path`, replacing whatever was there.
    ///
    /// `x-upsert: true` rather than a delete-then-put: two calls with no transaction across them
    /// leave a window in which the person has no photo at all, and a failure in the second leaves
    /// them with none permanently. One call either replaces the object or does not.
    ///
    /// Returns the object's public-shaped URL, which is what `profiles.avatar_url` stores. On a
    /// private bucket that URL is not fetchable without a token — which is correct, and is what
    /// `fetch` supplies.
    func upload(_ data: Data, to path: String, in bucket: String, contentType: String) async throws -> URL {
        _ = try await send(
            .post, objectURL(bucket, path), body: data,
            headers: ["Content-Type": contentType, "x-upsert": "true"]
        )
        return objectURL(bucket, path)
    }

    /// The bytes back, or nil where the object is simply not there.
    ///
    /// **A missing photo is not an error.** Somebody who has never set one has no object, Storage
    /// answers 404, and a throw here would put a failure banner over a profile screen that is
    /// working exactly as intended. Every other status still throws.
    func fetch(_ path: String, in bucket: String) async throws -> Data? {
        do {
            return try await send(.get, objectURL(bucket, path), body: nil, headers: [:])
        } catch let error as SupabaseError where error.isNotFound {
            return nil
        }
    }

    func delete(_ path: String, in bucket: String) async throws {
        do {
            _ = try await send(.delete, objectURL(bucket, path), body: nil, headers: [:])
        } catch let error as SupabaseError where error.isNotFound {
            // Deleting a photo nobody set is the state the caller wanted.
        }
    }

    // MARK: - Transport

    private enum Method: String {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    private func objectURL(_ bucket: String, _ path: String) -> URL {
        SupabaseConfig.storageURL.appending(path: "object/\(bucket)/\(path)")
    }

    /// The same refresh-once dance `PostgRESTClient.send` does, and for the same reason: an access
    /// token that expired between opening the picker and choosing a photo is not a failure worth
    /// showing anybody.
    private func send(
        _ method: Method, _ url: URL, body: Data?, headers: [String: String]
    ) async throws -> Data {
        do {
            return try await attempt(method, url, body: body, headers: headers)
        } catch let expired as SupabaseError where expired.isExpiredCredential {
            do {
                try await auth.refresh()
            } catch let failure as SupabaseError where failure.isOffline {
                throw failure
            } catch {
                throw expired
            }
            return try await attempt(method, url, body: body, headers: headers)
        }
    }

    private func attempt(
        _ method: Method, _ url: URL, body: Data?, headers: [String: String]
    ) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: SupabaseConfig.requestTimeout)
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(await auth.bearerToken)", forHTTPHeaderField: "Authorization")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = body
        // The object path never changes for a given person — see the header — so a cached response
        // is the previous photo, served forever.
        request.cachePolicy = .reloadIgnoringLocalCacheData

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

    /// Storage's error body is `{"statusCode","error","message"}` — a different shape from
    /// PostgREST's, which is why this is not shared with that file.
    private static func message(in data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return json["message"] as? String ?? json["error"] as? String ?? ""
    }
}
