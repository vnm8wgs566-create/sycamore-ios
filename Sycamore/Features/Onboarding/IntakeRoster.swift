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
//  committed. `IntakePlayer.lastName` is the whole surname because the file has one and the
//  review screen needs it — two Liams cannot be told apart by an initial. It is no longer cut
//  down at the door: `Player.lastName` now holds a surname too, so `asPlayer()` hands the whole
//  thing over and the initial is derived beside it rather than instead of it.
//
//  A file is no longer only read at onboarding. The same rows are now handed to
//  `RosterReconciliation`, which reads them against a camp that already has kids in it — so
//  every optional on `IntakePlayer` has a second job it did not have before: it is the file's
//  *silence*, and silence must never be readable as an instruction to change something. That is
//  what made `isReturning` optional, and it is why nothing here fills a gap in with a default
//  except `asPlayer()`, which is only ever called on a kid being created.
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
    /// Optional for the same reason `age` and `gender` are, plus one the re-import made urgent.
    ///
    /// `false` used to stand for two different files at once: one whose returning column said no,
    /// and one that had no returning column at all. The second is by far the commoner — the
    /// column is only found when a header cell contains "return", and a file read positionally
    /// never has one — so reading it as a "no" meant an ordinary four-column file would propose
    /// **un-returning every returning kid at the camp**. Nothing else on this type lets a file
    /// say something it never mentioned, and this no longer does either.
    var isReturning: Bool?
    /// Which of `8b`'s venues this kid was answered into, by position.
    ///
    /// A position rather than a `Venue.ID` because the venues do not exist yet — the camp is
    /// written at the end of the flow, and until then a venue is a row somebody drew. A file's
    /// rows keep the default: "Venue — optional, ask later" is what `8c` promises, and the first
    /// venue is where the design puts everyone who has not been asked.
    ///
    /// A destination for an **arrival** only. `RosterReconciliation` reads it for a row that
    /// becomes a new kid and never for a row that matched somebody already at the camp: which
    /// venue a kid stands in is a decision the camp made on Groups, and a spreadsheet column that
    /// mostly holds its own default does not get to overturn it.
    var venueIndex: Int = 0

    /// The CHECK, in Swift: `players_age_check` admits `age >= 4 AND age <= 19`.
    static let ageLimits = 4...19
    /// The other one: `players_last_name_len` admits `last_name IS NULL OR char_length(last_name)
    /// BETWEEN 1 AND 60`, added by `20260806031106_section8_model_gaps.sql`.
    ///
    /// A ceiling rather than a range, because the floor is already kept elsewhere — `asPlayer()`
    /// sends an empty cell as nil, which is the branch of the CHECK that admits it. Counted
    /// through `CharLength` like the app's four other column mirrors: Postgres counts UTF-8
    /// characters and `String.count` counts grapheme clusters, so a surname of emoji passes a
    /// `.count` gate and then fails the very insert the gate exists to prevent.
    static let surnameLimit = 60

    /// `Priya Nandan`, and just the first name when the file gave no surname.
    var displayName: String {
        lastName.isEmpty ? firstName : "\(firstName) \(lastName)"
    }

    /// The first thing about this row a person has to settle. One at a time: a row offers one
    /// "Fix", and filling it in re-reads this, so a row with two gaps is asked twice rather than
    /// ambiguously.
    ///
    /// Two of the four are not gaps but *refusals* — an age of 25 and a surname of 200 characters
    /// are both rejected by the column's own CHECK, and `importPlayers` sends the whole roster in
    /// a single insert. One bad cell therefore fails the entire import with a raw PostgREST
    /// message and no row to point at. Routing them here instead puts them in `8d`'s "Needs a
    /// detail" section beside a Fix button, which is where a person can actually do something
    /// about them.
    ///
    /// Read in the row's own order — the name, then the age, then the gender — so the question
    /// follows the reader's eye across the spreadsheet line they are looking at.
    var issue: IntakeIssue? {
        // `lastName` is counted as it stands rather than trimmed first: both writers hand it over
        // trimmed already — `IntakeFile.fields(in:separator:)` trims every cell it reads and
        // `AddPlayerView.save()` trims the field — so this counts what will actually be sent.
        if !CharLength.of(lastName, atMost: Self.surnameLimit) { return .longSurname }
        guard let age else { return .noAge }
        if !Self.ageLimits.contains(age) { return .impossibleAge }
        if gender == nil { return .noGender }
        return nil
    }

    /// `13 years` — the grey line under a name that read cleanly.
    var detail: String {
        guard let age else { return "Age unknown" }
        return "\(age) year\(age == 1 ? "" : "s")"
    }

    /// The kid the camp keeps.
    ///
    /// One gap still has to be closed here, because `Player` cannot hold it open: no gender reads
    /// as `.x`, which is the case the app already means by "not said". The file left the column
    /// blank; nobody is being assigned one.
    ///
    /// The other two now pass straight through, which is what lets `8d` save a row it could only
    /// show before:
    ///
    /// - Age stays unknown. `Player.age` is `Int?`, so a row somebody read and imported anyway
    ///   keeps its gap instead of landing as a `0` — a zero reads as a real age *and* is rejected
    ///   by the column's own 4…19 CHECK, so that kid could not round-trip at all.
    /// - The whole surname comes with it. `lastInitial` is still derived, because every existing
    ///   row has only that and ~21 files read it; `lastName` sits beside it so "Serene Chu"
    ///   survives an import rather than being cut to "Serene C" at the door. An empty cell goes as
    ///   nil rather than `""` — the column admits null or 1…60 characters and nothing between.
    ///
    /// Venue, court and rank are the repository's to set — a kid joins the back of a venue's
    /// ladder with no court, which is what `Groups`' unassigned band is for.
    ///
    /// A third gap closes here for the same reason as gender: `Player.isReturning` is not
    /// optional, and a file that said nothing about returning is a kid who has not been here
    /// before as far as anyone can tell. That is the right default **for a kid being created**,
    /// and only for one — `RosterReconciliation` reads `IntakePlayer.isReturning` directly rather
    /// than through here, so a silent file changes nobody who is already at the camp.
    func asPlayer() -> Player {
        let surname = lastName.trimmingCharacters(in: .whitespaces)
        return Player(
            firstName: firstName,
            lastInitial: surname.first.map { String($0).uppercased() } ?? "",
            lastName: surname.isEmpty ? nil : surname,
            age: age,
            gender: gender ?? .x,
            isReturning: isReturning ?? false,
            overallRank: 0,
            courtRank: 0
        )
    }
}

enum IntakeIssue: Hashable, Sendable {
    case noAge
    case noGender
    /// An age the roster column will not take. `4…19` is not this app's opinion — it is
    /// `players_age_check`, and a 25 in one cell rejects every other kid in the same insert.
    case impossibleAge
    /// A surname past `players_last_name_len`'s 60 characters, which fails the same way. Usually
    /// a merged cell or a whole address that landed in the wrong column.
    case longSurname

    var label: String {
        switch self {
        case .noAge: "No age in the file"
        case .noGender: "No gender in the file"
        case .impossibleAge: "An age outside 4 to 19"
        case .longSurname: "A surname longer than 60 letters"
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

    /// A file that never mentioned returning counts everybody as new, which is what the counts
    /// card said before `isReturning` could be nil and is still the honest reading: nobody has
    /// been told these kids were here last year.
    var newCount: Int { players.count { $0.isReturning != true } }
    var returningCount: Int { players.count { $0.isReturning == true } }

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

    /// Parses a separated-values roster.
    ///
    /// Tolerant on purpose — the file comes from whatever the office uses, not from us. A header
    /// row is used when there is one, and its columns are matched by what they contain rather
    /// than by an exact spelling, so "First Name", "first_name" and "Given name" all land.
    /// Without a header the columns are read positionally in the order `8c` asks for them.
    ///
    /// **Anything the file does not say stays nil** and becomes a row on `8d` rather than a
    /// guess. That was already true of age and gender; it is now true of returning too, which is
    /// what lets the same parse be reconciled against a camp that already exists. A nil here is
    /// the file's silence, and `RosterReconciliation` never turns silence into an instruction.
    static func parse(_ text: String, named fileName: String) throws -> IntakeImport {
        let lines = text.split(whereSeparator: \.isNewline)
        let separator = separator(in: lines)
        var rows = lines
            .map { fields(in: String($0), separator: separator) }
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

    /// Which character this file puts between its columns.
    ///
    /// Sniffed rather than assumed, because the picker on `8c` already accepts more than one
    /// format: `.tabSeparatedText` is in its `allowedContentTypes`, and a semicolon is what an
    /// Excel installed in most of Europe writes when the decimal separator is a comma. Splitting
    /// either of those on commas produces **one glued column** — and the header sniff still
    /// succeeds, because the glued cell contains "first", so every field reads that same cell and
    /// the whole row becomes a first name. It fails into a review screen that looks plausible,
    /// which is the worst way for a parse to fail.
    ///
    /// Whichever candidate occurs most on the first line that has anything on it wins; a comma
    /// wins a tie and a file with none of the three, which keeps a single-column file reading as
    /// it always has. Quotes are not honoured for the count — a header rarely has any, and one
    /// stray comma inside a quoted cell cannot outvote a row's worth of real separators.
    private static func separator(in lines: [Substring]) -> Character {
        guard let line = lines.first(where: { $0.contains { !$0.isWhitespace } }) else { return "," }
        func occurrences(of candidate: Character) -> Int { line.count { $0 == candidate } }

        // `max(by:)` keeps the first of equal elements, so the comma at the head of the list is
        // what a tie — and a file with none of the three — falls back to.
        let candidates: [Character] = [",", "\t", ";"]
        guard let winner = candidates.max(by: { occurrences(of: $0) < occurrences(of: $1) }),
              occurrences(of: winner) > 0
        else { return "," }
        return winner
    }

    /// Splits one line on `separator`, honouring double quotes so `"Nandan, Priya"` stays one
    /// field. A trailing carriage return is trimmed with the rest of the whitespace, so a file
    /// saved on Windows does not glue one onto its last column.
    private static func fields(in line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var isQuoted = false

        for character in line {
            switch character {
            case "\"":
                isQuoted.toggle()
            case separator where !isQuoted:
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            default:
                current.append(character)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
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
                // The `map` over the *column index* is the rule: no column, no answer. That is the
                // difference between "the office said no" and "the office was never asked", and
                // the whole reason `IntakePlayer.isReturning` is optional. A blank cell inside a
                // column that does exist is still a no — an office that tracks returners ticks
                // them and leaves everyone else empty, and reading those blanks as silence would
                // mean a re-import could never un-return anybody.
                isReturning: isReturning.map { Bool(fileValue: value($0)) }
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

    /// The order the chips run in on `8e`. The words themselves are `Gender.label`, hoisted to
    /// the model: they are read back by every screen that draws a mark instead of a word, and
    /// the chip and the readback disagreeing is what sent them there.
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
