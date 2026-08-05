//
//  PostgRESTClient.swift
//  Sycamore
//
//  Every request this app makes to Postgres, in one place, over `URLSession` and nothing else.
//
//  Hand-rolled rather than `supabase-swift`: the repository needs six verbs, all of which are
//  one HTTP call with two headers, and the whole surface fits on a screen. Taking a dependency
//  — and the transitive graph, the version pin, the SPM resolution step in every clean build —
//  to avoid writing this would be a poor trade in a project that has none.
//
//  A `struct`, not an actor. It holds no mutable state: the only thing that changes between
//  requests is the access token, and that lives on `SupabaseAuth`, which is an actor already.
//

import Foundation

struct PostgRESTClient: Sendable {

    private let auth: SupabaseAuth
    private let urlSession: URLSession

    init(auth: SupabaseAuth, urlSession: URLSession = .shared) {
        self.auth = auth
        self.urlSession = urlSession
    }

    // MARK: Reads

    func select<Row: Decodable & Sendable>(
        _ relation: String, _ query: PostgRESTQuery, as: Row.Type = Row.self
    ) async throws -> [Row] {
        let data = try await send(.get, relation, query: query, body: nil, prefer: [])
        return try decode(data, relation: relation)
    }

    // MARK: Writes

    /// `Prefer: return=minimal` — the repository re-reads the whole camp after every write, so
    /// asking Postgres to serialise the inserted rows as well is work nobody reads.
    func insert(_ relation: String, _ rows: [RowValues]) async throws {
        guard !rows.isEmpty else { return }
        _ = try await send(
            .post, relation, query: PostgRESTQuery(),
            body: try encode(rows), prefer: ["return=minimal"]
        )
    }

    /// Insert-or-update against `onConflict`'s unique constraint, in one statement. Note that
    /// merge-duplicates updates *only the columns in the payload*, which is what makes it safe
    /// to upsert `{player_id, rating}` into a `ratings` row that also carries `n_events`.
    func upsert(_ relation: String, _ rows: [RowValues], onConflict: String) async throws {
        guard !rows.isEmpty else { return }
        _ = try await send(
            .post, relation, query: PostgRESTQuery().raw("on_conflict", onConflict),
            body: try encode(rows),
            prefer: ["return=minimal", "resolution=merge-duplicates"]
        )
    }

    func update(
        _ relation: String, set values: RowValues, where query: PostgRESTQuery
    ) async throws {
        _ = try await send(
            .patch, relation, query: query, body: try encode(values), prefer: ["return=minimal"]
        )
    }

    func delete(_ relation: String, where query: PostgRESTQuery) async throws {
        _ = try await send(.delete, relation, query: query, body: nil, prefer: ["return=minimal"])
    }

    /// The returning variants. A `PATCH` or `DELETE` that matches nothing is a 204 either way, so
    /// asking for the rows back is how a caller tells "changed it" from "there was nothing there"
    /// without a second request to look first.
    func update<Row: Decodable & Sendable>(
        _ relation: String,
        set values: RowValues,
        where query: PostgRESTQuery,
        returning: Row.Type
    ) async throws -> [Row] {
        let data = try await send(
            .patch, relation, query: query, body: try encode(values),
            prefer: ["return=representation"]
        )
        return try decode(data, relation: relation)
    }

    func delete<Row: Decodable & Sendable>(
        _ relation: String, where query: PostgRESTQuery, returning: Row.Type
    ) async throws -> [Row] {
        let data = try await send(
            .delete, relation, query: query, body: nil, prefer: ["return=representation"]
        )
        return try decode(data, relation: relation)
    }

    /// A `SECURITY INVOKER` function called over REST. Nothing uses one yet — the schema's only
    /// callable is a maintenance helper the migration explicitly revoked from `anon` — but a
    /// client that cannot call a function forces the next piece of set-based logic back into
    /// Swift, which is the wrong place for it.
    func rpc<Row: Decodable & Sendable>(
        _ function: String, _ arguments: some Encodable & Sendable, returning: Row.Type = Row.self
    ) async throws -> [Row] {
        let data = try await send(
            .post, "rpc/\(function)", query: PostgRESTQuery(),
            body: try encode(arguments), prefer: []
        )
        return try decode(data, relation: function)
    }

    // MARK: Plumbing

    private enum Method: String {
        case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE"
    }

    /// Sends, and on a 401 refreshes the access token and sends once more.
    ///
    /// Once, not in a loop: if the second attempt is also refused the credential is not merely
    /// stale, and a client that keeps retrying a rejected token is how you get an account locked
    /// out by its own app.
    private func send(
        _ method: Method,
        _ relation: String,
        query: PostgRESTQuery,
        body: Data?,
        prefer: [String]
    ) async throws -> Data {
        // PostgREST applies an unfiltered PATCH or DELETE to every row in the table, and the
        // `mvp_all` policy standing in for real row level security would not stop it. No caller
        // here means that, so a query that lost its filter is a bug caught before it ships.
        if method == .patch || method == .delete, query.encoded == nil {
            throw SupabaseError.unfilteredWrite(relation)
        }
        do {
            return try await attempt(method, relation, query: query, body: body, prefer: prefer)
        } catch let expired as SupabaseError where expired.isExpiredCredential {
            do {
                try await auth.refresh()
            } catch let failure as SupabaseError where failure.isOffline {
                // The refresh never left the device. Reporting the 401 would tell the coach they
                // lack access when what they lack is signal, and send them looking for the wrong
                // fix.
                throw failure
            } catch {
                throw expired
            }
            return try await attempt(method, relation, query: query, body: body, prefer: prefer)
        }
    }

    private func attempt(
        _ method: Method,
        _ relation: String,
        query: PostgRESTQuery,
        body: Data?,
        prefer: [String]
    ) async throws -> Data {
        var components = URLComponents(
            url: SupabaseConfig.restURL.appending(path: relation), resolvingAgainstBaseURL: false
        )
        components?.percentEncodedQuery = query.encoded
        guard let url = components?.url else {
            throw SupabaseError.malformedResponse("could not build a URL for \(relation)")
        }

        var request = URLRequest(url: url, timeoutInterval: SupabaseConfig.requestTimeout)
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(await auth.bearerToken)", forHTTPHeaderField: "Authorization")
        if !prefer.isEmpty {
            request.setValue(prefer.joined(separator: ","), forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

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

    private func encode(_ value: some Encodable & Sendable) throws -> Data {
        do {
            return try SupabaseCoding.encoder().encode(value)
        } catch {
            throw SupabaseError.malformedResponse("could not encode a write body: \(error)")
        }
    }

    private func decode<Row: Decodable>(_ data: Data, relation: String) throws -> [Row] {
        // A `return=minimal` write answers 204 with nothing at all, and so does a function that
        // returns void. Both are success, not an empty-body failure.
        guard !data.isEmpty else { return [] }
        do {
            return try SupabaseCoding.decoder().decode([Row].self, from: data)
        } catch {
            throw SupabaseError.malformedResponse("\(relation): \(error)")
        }
    }

    /// PostgREST's error body is `{"code","details","hint","message"}`. The code is the thing
    /// worth keeping — `23505` is how `isUniqueViolation` recognises a name already taken.
    private static func message(in data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        let message = json["message"] as? String ?? ""
        guard let code = json["code"] as? String, !code.isEmpty else { return message }
        return message.isEmpty ? code : "\(code): \(message)"
    }
}
