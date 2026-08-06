//
//  RowValues.swift
//  Sycamore
//
//  A write payload: the columns being set, and nothing else.
//
//  Not a `Codable` struct per table, because `JSONEncoder` drops a nil optional rather than
//  writing `null`, and half the writes in this repository are precisely "set this column to
//  null" — clear a coach off a court, cancel an early pick-up, take a kid out of a group. A
//  struct with optional fields cannot say the difference between "leave that column alone" and
//  "empty it", and PATCH needs both.
//
//  It also means a PATCH sends the two columns it changes instead of all thirteen, so two
//  clients editing different fields of the same venue do not silently undo each other.
//

import Foundation

/// One JSON value, in the shapes Postgres columns actually take here.
enum PostgresValue: Encodable, Hashable, Sendable {
    case text(String)
    case uuid(UUID)
    case int(Int)
    case number(Double)
    case bool(Bool)
    case null

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .uuid(let value): try container.encode(value.uuidString)
        case .int(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    /// The nullable spellings, so a call site can write `.uuid(player.groupID)` and get `null`
    /// for a kid with no court instead of an `if`.
    static func uuid(_ value: UUID?) -> PostgresValue { value.map { .uuid($0) } ?? .null }
    static func text(_ value: String?) -> PostgresValue { value.map { .text($0) } ?? .null }
    static func int(_ value: Int?) -> PostgresValue { value.map { .int($0) } ?? .null }
}

/// The columns of one row — and, since it is really just a JSON object with explicit nulls, the
/// body of a GoTrue call as well.
///
/// Keys are the database's own spelling. `JSONEncoder`'s snake-case conversion leaves a key that
/// is already snake-cased alone, so `site_id` survives the trip unchanged.
struct RowValues: Encodable, Sendable, ExpressibleByDictionaryLiteral {

    private var columns: [String: PostgresValue]

    init(dictionaryLiteral elements: (String, PostgresValue)...) {
        columns = Dictionary(elements) { _, last in last }
    }

    init(_ columns: [String: PostgresValue]) {
        self.columns = columns
    }

    subscript(column: String) -> PostgresValue? {
        get { columns[column] }
        set { columns[column] = newValue }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (name, value) in columns {
            try container.encode(value, forKey: DynamicKey(name))
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
