//
//  IntakeRoster.swift
//  Sycamore
//
//  A week's kids between the office's file and the camp: what came across, what the file left
//  out, and what `8d` counts up at the top.
//
//  Deliberately not `Player`. A `Player` has a rank, a venue and a court; none of that is
//  decided yet — "nobody is ranked yet" is the promise `8c` makes — and a half-filled `Player`
//  with a sentinel rank would leak into the ladder the first time somebody forgot to check.
//  This is the shape of a row in a spreadsheet, and it becomes a `Player` at the moment it is
//  committed. `IntakePlayer.lastName` is the whole surname for the same reason: the file has
//  it, `Player.lastInitial` does not, and dropping it before the import is confirmed means two
//  Liams cannot be told apart on the review screen.
//

import Foundation

// MARK: - A kid on the list

struct IntakePlayer: Identifiable, Hashable, Sendable {
    var id = UUID()
    var firstName: String
    var lastName: String
    /// Optional because a file is allowed to be missing one — that is the whole point of `8d`.
    var age: Int?
    var gender: Gender?
    var isReturning: Bool = false

    /// `Priya Nandan`, and just the first name when the file gave no surname.
    var displayName: String {
        lastName.isEmpty ? firstName : "\(firstName) \(lastName)"
    }

    /// The first thing the file failed to say. One at a time: a row offers one "Fix", and
    /// filling it in re-reads this, so a row missing both is asked twice rather than ambiguously.
    var issue: IntakeIssue? {
        if age == nil { return .noAge }
        if gender == nil { return .noGender }
        return nil
    }

    /// `13 years` — the grey line under a name that read cleanly.
    var detail: String {
        guard let age else { return "Age unknown" }
        return "\(age) year\(age == 1 ? "" : "s")"
    }
}

enum IntakeIssue: Hashable, Sendable {
    case noAge
    case noGender

    var label: String {
        switch self {
        case .noAge: "No age in the file"
        case .noGender: "No gender in the file"
        }
    }
}

// MARK: - A file, read

/// One import, from the moment the file is parsed to the moment it is committed.
struct IntakeImport: Hashable, Sendable {
    /// `sign-ups.csv`, as the design prints it.
    var fileName: String
    var players: [IntakePlayer]

    /// `42 players`
    var title: String {
        "\(players.count) player\(players.count == 1 ? "" : "s")"
    }

    /// `From sign-ups.csv · 2 need a detail`
    var subtitle: String {
        let gaps = needsDetail.count
        guard gaps > 0 else { return "From \(fileName) · everything read cleanly" }
        return "From \(fileName) · \(gaps) need\(gaps == 1 ? "s" : "") a detail"
    }

    var needsDetail: [IntakePlayer] { players.filter { $0.issue != nil } }
    var readCleanly: [IntakePlayer] { players.filter { $0.issue == nil } }

    var newCount: Int { players.count { !$0.isReturning } }
    var returningCount: Int { players.count(where: \.isReturning) }

    /// Always zero, and stated rather than counted: an import ranks nobody. The first sort does.
    var rankedCount: Int { 0 }

    /// Replaces a row in place after `8e` fills in what the file was missing.
    mutating func update(_ player: IntakePlayer) {
        guard let index = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[index] = player
    }
}

// MARK: - Reading the file

enum IntakeFile {

    enum ReadError: LocalizedError, Equatable {
        case unreadable
        case nothingToImport

        var errorDescription: String? {
            switch self {
            case .unreadable: "We couldn't open that file. A CSV exported from the office works best."
            case .nothingToImport: "There were no kids in that file."
            }
        }
    }

    /// Parses a comma-separated roster.
    ///
    /// Tolerant on purpose — the file comes from whatever the office uses, not from us. A header
    /// row is used when there is one, and its columns are matched by what they contain rather
    /// than by an exact spelling, so "First Name", "first_name" and "Given name" all land.
    /// Without a header the columns are read positionally in the order `8c` asks for them.
    /// Anything the file does not say stays nil and becomes a row on `8d` rather than a guess.
    static func parse(_ text: String, named fileName: String) throws -> IntakeImport {
        var rows = text
            .split(whereSeparator: \.isNewline)
            .map { fields(in: String($0)) }
            .filter { row in row.contains { !$0.isEmpty } }

        guard !rows.isEmpty else { throw ReadError.nothingToImport }

        let columns: Columns
        if let header = rows.first, let mapped = Columns(header: header) {
            columns = mapped
            rows.removeFirst()
        } else {
            columns = .positional
        }

        let players = rows.compactMap { columns.player(from: $0) }
        guard !players.isEmpty else { throw ReadError.nothingToImport }
        return IntakeImport(fileName: fileName, players: players)
    }

    /// Splits one line on commas, honouring double quotes so `"Nandan, Priya"` stays one field.
    private static func fields(in line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var isQuoted = false

        for character in line {
            switch character {
            case "\"":
                isQuoted.toggle()
            case "," where !isQuoted:
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            default:
                current.append(character)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    /// Which column holds what.
    private struct Columns {
        var firstName: Int?
        var lastName: Int?
        /// A single "Name" column, split on the first space.
        var fullName: Int?
        var age: Int?
        var gender: Int?
        var isReturning: Int?

        init(firstName: Int?, lastName: Int?, fullName: Int?, age: Int?, gender: Int?, isReturning: Int?) {
            self.firstName = firstName
            self.lastName = lastName
            self.fullName = fullName
            self.age = age
            self.gender = gender
            self.isReturning = isReturning
        }

        /// `first, last, age, gender` — what a file with no header is read as.
        static let positional = Columns(
            firstName: 0, lastName: 1, fullName: nil, age: 2, gender: 3, isReturning: nil
        )

        /// Nil when the first row is data rather than a header — which is the case as soon as
        /// one of its cells is a number, because no column is called "12".
        init?(header: [String]) {
            let keys = header.map { $0.lowercased().filter(\.isLetter) }
            guard keys.contains(where: { $0.contains("name") || $0.contains("age") || $0.contains("gender") }),
                  !header.contains(where: { Int($0) != nil })
            else { return nil }

            let first = keys.firstIndex { $0.contains("first") || $0.contains("given") }
            let last = keys.firstIndex { $0.contains("last") || $0.contains("surname") || $0.contains("family") }

            self.init(
                firstName: first,
                lastName: last,
                fullName: first == nil ? keys.firstIndex { $0.contains("name") } : nil,
                age: keys.firstIndex { $0.contains("age") },
                gender: keys.firstIndex { $0.contains("gender") || $0 == "sex" },
                isReturning: keys.firstIndex { $0.contains("return") }
            )

            guard firstName != nil || fullName != nil else { return nil }
        }

        func player(from row: [String]) -> IntakePlayer? {
            func value(_ column: Int?) -> String {
                guard let column, row.indices.contains(column) else { return "" }
                return row[column]
            }

            var first = value(firstName)
            var last = value(lastName)

            if first.isEmpty {
                let whole = value(fullName).split(separator: " ")
                first = String(whole.first ?? "")
                last = whole.dropFirst().joined(separator: " ")
            }

            // A row with no name at all is a spacer or a total, not a kid.
            guard !first.isEmpty else { return nil }

            return IntakePlayer(
                firstName: first,
                lastName: last,
                age: Int(value(age)),
                gender: Gender(fileValue: value(gender)),
                isReturning: Bool(fileValue: value(isReturning))
            )
        }
    }
}

// MARK: - Reading a cell

extension Gender {
    /// `F`, `female`, `girl`, `M`, `boy`, `X`, `other`, `prefer not to say`. Anything the file
    /// leaves blank, or writes in a way this does not recognise, stays nil and becomes a
    /// question on `8d` — guessing a kid's gender out of an unreadable cell is not a mistake
    /// worth making silently.
    init?(fileValue: String) {
        let value = fileValue.lowercased().filter(\.isLetter)
        guard let initial = value.first else { return nil }

        switch initial {
        case "f", "g", "w": self = .f
        case "m", "b": self = .m
        case "x", "o", "n", "p": self = .x
        default: return nil
        }
    }

    /// How `8e` offers the three answers.
    var intakeLabel: String {
        switch self {
        case .f: "Girl"
        case .m: "Boy"
        case .x: "Prefer not to say"
        }
    }

    /// The order the chips run in on `8e`.
    static let intakeOptions: [Gender] = [.f, .m, .x]
}

private extension Bool {
    /// A returning-camper column, however the office spells yes.
    init(fileValue: String) {
        let value = fileValue.lowercased().filter(\.isLetter)
        self = value.hasPrefix("y") || value.hasPrefix("t") || value.hasPrefix("r")
            || fileValue.trimmingCharacters(in: .whitespaces) == "1"
    }
}

// MARK: - Fixtures

extension IntakeImport {
    /// The list `8d` draws, at the size it draws it: 42 kids, two of them missing a detail, two
    /// of them returning. Only previews use it — nothing in the app invents a roster.
    static var preview: IntakeImport {
        let clean = [
            ("Serene", "Chu", 13, Gender.f), ("Liam", "Prior", 12, .m),
            ("Austin", "Zheng", 13, .m), ("Mia", "Karim", 12, .f),
            ("Noor", "Haddad", 11, .f), ("Theo", "Vance", 14, .m),
        ]
        var players = clean.map {
            IntakePlayer(firstName: $0.0, lastName: $0.1, age: $0.2, gender: $0.3)
        }
        // Enough bodies to make the counts read like a real week.
        players += (0..<34).map { index in
            IntakePlayer(firstName: "Kid", lastName: "\(index + 1)", age: 12, gender: .m)
        }
        players[0].isReturning = true
        players[1].isReturning = true
        players.insert(IntakePlayer(firstName: "Priya", lastName: "Nandan", age: nil, gender: .f), at: 0)
        players.insert(IntakePlayer(firstName: "Sam", lastName: "Okafor", age: 12, gender: nil), at: 1)

        return IntakeImport(fileName: "sign-ups.csv", players: players)
    }
}
