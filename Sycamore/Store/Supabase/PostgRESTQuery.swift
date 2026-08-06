//
//  PostgRESTQuery.swift
//  Sycamore
//
//  PostgREST's filter grammar, typed.
//
//  The grammar is small — `?col=eq.value`, `?order=col.asc`, `?select=a,b(c)` — and building it
//  with string interpolation works right up until a value carries a character the grammar also
//  uses, at which point PostgREST reads one filter as two and answers with the wrong rows rather
//  than with an error.
//
//  Quoting is not symmetric, which is the trap and the reason this is a type and not a helper
//  function. `in.("a","b")` takes double-quoted elements — that is how a comma inside a value
//  stays inside it. A scalar `eq` does *not*: PostgREST passes the quotes straight through to
//  Postgres, so `?name=eq."Sycamore"` matches nothing and `?id=eq."<uuid>"` is a type error. So
//  list elements are quoted, scalars never are, and everything is percent-encoded on the way out.
//

import Foundation

struct PostgRESTQuery: Sendable {

    private var items: [(name: String, value: String)] = []

    init() {}

    /// `?select=id,name,ratings(rating)` — embedded resources included.
    static func select(_ columns: String) -> PostgRESTQuery {
        PostgRESTQuery().raw("select", columns)
    }

    // MARK: Filters

    func eq(_ column: String, _ value: some PostgRESTValue) -> Self {
        appending(column, "eq.\(value.postgrestLiteral)")
    }

    func neq(_ column: String, _ value: some PostgRESTValue) -> Self {
        appending(column, "neq.\(value.postgrestLiteral)")
    }

    func gte(_ column: String, _ value: some PostgRESTValue) -> Self {
        appending(column, "gte.\(value.postgrestLiteral)")
    }

    func lte(_ column: String, _ value: some PostgRESTValue) -> Self {
        appending(column, "lte.\(value.postgrestLiteral)")
    }

    /// `?id=in.("a","b")`. An empty list is left to the caller — PostgREST rejects `in.()`, and
    /// a caller with nothing to match almost always wants to skip the request rather than send
    /// one that cannot succeed.
    func within(_ column: String, _ values: [some PostgRESTValue]) -> Self {
        let list = values.map { Self.quoted($0.postgrestLiteral) }.joined(separator: ",")
        return appending(column, "in.(\(list))")
    }

    /// `?group_id=is.null`. `is` takes a keyword rather than a value, so nothing is escaped.
    func isNull(_ column: String, _ isNull: Bool = true) -> Self {
        appending(column, isNull ? "is.null" : "not.is.null")
    }

    func isTrue(_ column: String, _ expected: Bool = true) -> Self {
        appending(column, expected ? "is.true" : "is.false")
    }

    // MARK: Shape

    func order(_ column: String, ascending: Bool = true, nullsFirst: Bool = false) -> Self {
        appending(
            "order",
            "\(column).\(ascending ? "asc" : "desc").\(nullsFirst ? "nullsfirst" : "nullslast")"
        )
    }

    func limit(_ count: Int) -> Self {
        appending("limit", String(count))
    }

    /// `on_conflict=account_id,camp_id` and its like: a query item PostgREST reads as
    /// configuration rather than as a value.
    func raw(_ name: String, _ value: String) -> Self {
        appending(name, value)
    }

    // MARK: Rendering

    /// The query string, or nil when there is nothing to say.
    ///
    /// Encoded by hand rather than through `URLComponents.queryItems`, which leaves `+` alone —
    /// and a server reads a bare `+` in a query as a space, which is how the plus in an email
    /// address becomes a space somewhere between here and Postgres.
    var encoded: String? {
        guard !items.isEmpty else { return nil }
        return items
            .map { "\(Self.escaped($0.name))=\(Self.escaped($0.value))" }
            .joined(separator: "&")
    }

    private func appending(_ name: String, _ value: String) -> Self {
        var copy = self
        copy.items.append((name, value))
        return copy
    }

    private static func quoted(_ raw: String) -> String {
        let escaped = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Everything PostgREST parses structurally is left alone; everything else is escaped.
    ///
    /// That split is the whole point. `,` `(` `)` `*` `!` `.` are grammar — escaping them would
    /// turn `select=*,players!inner(site_id)` into a column name. `&` `=` `+` `#` `%` and space
    /// are not, and leaving *those* alone is how a value silently becomes two query items.
    private static let unescaped: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~*!(),:")
        return set
    }()

    private static func escaped(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: unescaped) ?? raw
    }
}

// MARK: - Values

/// Anything that can sit on the right of a filter. Deliberately closed: a type that reaches
/// PostgREST through `description` is a type nobody checked the spelling of, and `Date`'s
/// description is not a date literal Postgres accepts.
protocol PostgRESTValue: Sendable {
    var postgrestLiteral: String { get }
}

extension String: PostgRESTValue {
    var postgrestLiteral: String { self }
}

extension UUID: PostgRESTValue {
    var postgrestLiteral: String { uuidString }
}

extension Int: PostgRESTValue {
    var postgrestLiteral: String { String(self) }
}

extension Bool: PostgRESTValue {
    var postgrestLiteral: String { self ? "true" : "false" }
}
