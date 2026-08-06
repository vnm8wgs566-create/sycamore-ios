//
//  SupabaseCoding.swift
//  Sycamore
//
//  One encoder and one decoder, configured the same way everywhere.
//
//  Two settings do all the work. `convertFromSnakeCase` means the row types can be written in
//  Swift's spelling with no `CodingKeys` block at all — two hundred lines of ceremony whose only
//  job would be to restate the column names. And `timestamptz` needs a custom date strategy:
//  Postgres returns `2026-08-01T19:43:48.195644+00:00`, and `.iso8601` refuses anything with a
//  fractional second, so the default would fail on every audit column in the schema.
//
//  Fresh instances per call rather than shared statics: `JSONEncoder` is a non-`Sendable` class,
//  and allocating one is nothing against a network round trip.
//

import Foundation

enum SupabaseCoding {

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = timestamp(from: text) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Not a timestamp: \(text)")
                )
            }
            return date
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601(from: date))
        }
        return encoder
    }

    /// Both spellings Postgres uses, in the order they actually turn up.
    private static func timestamp(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private static func iso8601(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
