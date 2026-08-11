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
//  There are now two kinds of file behind that same shape. `parse(_:named:)` cuts separated text;
//  `parse(rows:named:)` takes a grid somebody else cut, which is what `XLSXReader` hands over for
//  a spreadsheet. Everything below the cut — which column is which, what a blank cell means, what
//  becomes a `Player` — is shared, so an `.xlsx` and a CSV of the same roster produce the same
//  rows and there is one place to be wrong rather than two.
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
    /// column is only found when a header cell contains "return", and most offices send four
    /// columns of name, age and gender — so reading it as a "no" meant an ordinary file would
    /// propose **un-returning every returning kid at the camp**. Nothing else on this type lets a
    /// file say something it never mentioned, and this no longer does either.
    var isReturning: Bool?
    /// Which venue this kid was answered into, **by position**.
    ///
    /// A position rather than a `Venue.ID` because at onboarding the venues do not exist yet — the
    /// camp is written at the end of the flow, and until then a venue is a row somebody drew on
    /// `8b`. A file's rows keep the default: "Venue — optional, ask later" is what `8c` promises,
    /// and the first venue is where the design puts everyone who has not been asked.
    ///
    /// It stayed a position once the same screens were reached from **inside** a camp, where the
    /// venues do exist and `EnrolmentFlowView` hands `AddPlayerView` the real ones through
    /// `Venue.shape`. A `Venue.ID` here would be right for that caller and unrepresentable for the
    /// other, and the resolution — `venues[min(index, venues.count - 1)]` — is one line in
    /// `AppStore.applyRoster`, which is the only thing on either path that holds the venues.
    ///
    /// A destination for an **arrival** only. `RosterReconciliation` reads it for a row that
    /// becomes a new kid and never for a row that matched somebody already at the camp: which
    /// venue a kid stands in is a decision the camp made on Groups, and a spreadsheet column that
    /// mostly holds its own default does not get to overturn it.
    var venueIndex: Int = 0

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
    /// The bounds are read off `PlayerRules` rather than kept here. They were statics on this
    /// type, which made them the *file's* rules — so the by-hand path checked neither, and `8e`,
    /// the screen this row's Fix button opens, could re-create the very issue it was opened to
    /// settle.
    ///
    /// Read in the row's own order — the name, then the age, then the gender — so the question
    /// follows the reader's eye across the spreadsheet line they are looking at.
    ///
    /// The **constants** rather than `PlayerRules.age(_:)`, deliberately: the filter folds an
    /// out-of-range value and a missing one into the same nil, and telling those two apart is this
    /// property's entire job.
    var issue: IntakeIssue? {
        // `lastName` is counted as it stands rather than trimmed first: both writers hand it over
        // trimmed already — `IntakeFile.fields(in:separator:)` trims every cell it reads and
        // `AddPlayerView.save()` trims the field — so this counts what will actually be sent.
        if !CharLength.of(lastName, atMost: PlayerRules.surnameLimit) { return .longSurname }
        guard let age else { return .noAge }
        if !PlayerRules.ageLimits.contains(age) { return .impossibleAge }
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
    /// **The one place a spreadsheet row becomes a database row**, and therefore the one place
    /// that has to answer "what may I write" rather than "what did the file say". Both write paths
    /// funnel through here — `AppStore.applyRoster` maps arrivals through it before
    /// `importPlayers`, and `AppStore.addPlayer` calls it on the single kid `8e` produced — so
    /// every coercion below is made once for both.
    ///
    /// Three gaps are closed because `Player` cannot hold them open:
    ///
    /// - No gender reads as `.x`, which is the case the app already means by "not said". The file
    ///   left the column blank; nobody is being assigned one.
    /// - `Player.isReturning` is not optional, and a file that said nothing about returning is a
    ///   kid who has not been here before as far as anyone can tell. That is the right default
    ///   **for a kid being created**, and only for one — `RosterReconciliation` reads
    ///   `IntakePlayer.isReturning` directly rather than through here, so a silent file changes
    ///   nobody who is already at the camp.
    /// - Age stays unknown when it is unknown. `Player.age` is `Int?`, so a row somebody read and
    ///   imported anyway keeps its gap instead of landing as a `0` — a zero reads as a real age
    ///   *and* is rejected by the column's own 4…19 CHECK, so that kid could not round-trip.
    ///
    /// And two values are **refused** rather than passed on, through `PlayerRules`. `commit`
    /// deliberately does not drop rows with an open `IntakeIssue` (`RosterSelection.swift:59-62`)
    /// and neither review screen's button refuses to write one — the reader saw the row under
    /// "Needs a detail", declined the Fix, and asked for the import anyway. Sending the value on
    /// would fail the **whole insert**, because `importPlayers` sends the roster as one array; so
    /// forty-one legitimate kids would be rejected by one merged cell, with a raw PostgREST
    /// message and no row to point at. Dropping the offending value imports the kid with the gap
    /// they already had on screen, which is the outcome the reader was looking at.
    ///
    /// The whole surname comes across otherwise. `lastInitial` is still derived, because every
    /// existing row has only that and ~21 files read it; `lastName` sits beside it so "Serene Chu"
    /// survives an import rather than being cut to "Serene C" at the door. It is derived from the
    /// **filtered** surname, so a cell the column would refuse leaves no initial behind either —
    /// half of a rejected value is not a name.
    ///
    /// Venue, court and rank are the repository's to set — a kid joins the back of a venue's
    /// ladder with no court, which is what `Groups`' unassigned band is for.
    func asPlayer() -> Player {
        let surname = PlayerRules.surname(lastName)
        return Player(
            firstName: firstName,
            lastInitial: surname?.first.map { String($0).uppercased() } ?? "",
            lastName: surname,
            age: PlayerRules.age(age),
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
        /// The first row is data rather than column names. See `parse(rows:named:)`.
        case noHeaderRow

        var errorDescription: String? {
            switch self {
            // Reworded when `.xlsx` became a file the picker offers. It said "a CSV exported from
            // the office works best", which was true when a CSV was the only thing that could be
            // read and is now advice to convert a file that would have opened.
            case .unreadable:
                "We couldn't open that file. A CSV or an Excel .xlsx from the office both work."
            case .nothingToImport:
                "There were no kids in that file."
            case .noHeaderRow:
                "The first row needs to name the columns — first name, last name, age, gender. Without it we would be guessing which is which."
            }
        }
    }

    /// A file of bytes, whichever of the two kinds it is.
    ///
    /// **The way in.** Which reader a file needs is a fact about rosters, so it is answered here
    /// rather than in the screen that happens to hold the picker — `8c` used to make the call in
    /// its `.fileImporter` callback, which meant the sniff, the UTF-8 fallback and the mapping to
    /// `.unreadable` sat in a view, untested, waiting to be re-derived by the second entry point
    /// (a drop onto the card, a share sheet, "Open in Sycamore").
    ///
    /// The kind is read from the **bytes**, not from the extension. An office that renames a
    /// workbook `roster.csv` is common enough to be worth surviving, and so is the reverse; the
    /// picker's `allowedContentTypes` decides what may be chosen, and this decides how what was
    /// chosen is read.
    static func parse(_ data: Data, named fileName: String) throws -> IntakeImport {
        if XLSXReader.looksLikeAWorkbook(data) {
            return try parse(rows: XLSXReader.rows(from: data), named: fileName)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ReadError.unreadable
        }
        return try parse(text, named: fileName)
    }

    /// Parses a separated-values roster.
    ///
    /// Tolerant on purpose — the file comes from whatever the office uses, not from us. The
    /// delimiter is sniffed, quotes are honoured, and the header's columns are matched by what
    /// they contain rather than by an exact spelling, so "First Name", "first_name" and "Given
    /// name" all land.
    static func parse(_ text: String, named fileName: String) throws -> IntakeImport {
        let lines = text.split(whereSeparator: \.isNewline)
        let separator = separator(in: lines)
        return try parse(rows: lines.map { fields(in: String($0), separator: separator) }, named: fileName)
    }

    /// The same roster, once somebody else has done the cutting.
    ///
    /// Split out when `.xlsx` arrived. A spreadsheet is already a grid — `XLSXReader` hands over
    /// rows of cells directly — and the alternative was to have it write a CSV for `parse(_:)` to
    /// cut back up, which would mean inventing quoting rules on the way out and depending on
    /// `fields(in:separator:)` to undo them exactly. A name with a quote in it is where that goes
    /// wrong, and it goes wrong silently. So the column logic is shared at the grid, which is the
    /// shape both readers genuinely have in common, and everything downstream — reconciliation,
    /// `8d`, the commit — never learns there are two kinds of file.
    ///
    /// **Cells are expected trimmed.** Both producers do it at the point they cut the bytes, and
    /// `IntakePlayer.issue` counts a surname on that promise (`:92-94`).
    ///
    /// **Anything the file does not say stays nil** and becomes a row on `8d` rather than a
    /// guess. That was already true of age and gender; it is now true of returning too, which is
    /// what lets the same parse be reconciled against a camp that already exists. A nil here is
    /// the file's silence, and `RosterReconciliation` never turns silence into an instruction.
    ///
    /// ## A file with no header row is refused
    ///
    /// This used to fall back to `first, last, age, gender` by position. That guess was made
    /// against the layout `8c`'s own example card draws, and the first real export anybody tried
    /// it on is laid out `Last Name, First Name, Age, Gender` — surname first, which most
    /// sign-up systems export because that is how a register sorts. A header-less copy of that
    /// file would have imported eighty kids with their names the wrong way round, every row
    /// reading cleanly, nothing on `8d` to notice and a whole camp to correct by hand afterwards.
    ///
    /// There is no signal that tells the two apart. "Ara" and "Cameron" are both first names and
    /// both surnames, and no amount of sniffing fixes that — a positional read is a coin toss
    /// dressed as a parse. So the coin is not tossed: a file whose first row is not a header is
    /// refused with a sentence saying what to add, which is a thirty-second fix in any
    /// spreadsheet and cannot be got wrong. Refusing to guess costs the header-less file; guessing
    /// wrong costs the roster, silently, and is only ever found weeks later.
    static func parse(rows: [[String]], named fileName: String) throws -> IntakeImport {
        let rows = rows.filter { row in row.contains { !$0.isEmpty } }
        guard !rows.isEmpty else { throw ReadError.nothingToImport }
        guard let columns = Columns(header: rows[0]) else { throw ReadError.noHeaderRow }

        let players = rows.dropFirst().compactMap { columns.player(from: $0) }
        guard !players.isEmpty else { throw ReadError.nothingToImport }
        return IntakeImport(fileName: fileName, players: players)
    }

    /// What `IntakeImport.subtitle` calls a roster nobody chose a file for.
    ///
    /// A name rather than an empty string, because that field is printed — "From the pasted list ·
    /// 2 need a detail" — and it is the only thing on the review screen that says where these
    /// forty names came from.
    static let pastedName = "the pasted list"

    /// The order a pasted line is read in when it does not say. See `parse(pasted:)`.
    ///
    /// Spelled as column names rather than as three indices so it goes through the same
    /// `Columns(header:)` every file does: a paste and a file then agree about what "Gender" means,
    /// and there is one place to be wrong instead of two. `Name` rather than `First`/`Last`, which
    /// is what makes "Serene Chu" split on the space — the box's placeholder writes it that way and
    /// `Columns.player(from:)` has read a single name column since it was written.
    private static let pastedHeader = ["Name", "Age", "Gender"]

    /// A roster somebody typed or pasted in, rather than a file they chose.
    ///
    /// ## Why this may go without a header row when a file may not
    ///
    /// `parse(rows:named:)` refuses a header-less file, and the argument there is not fussiness:
    /// there is no signal that tells `Last, First` from `First, Last`, so a positional read is a
    /// coin toss that imports a whole camp backwards and reads cleanly while doing it.
    ///
    /// A paste box is the one case where that argument does not hold, because the box **states the
    /// order before anything is typed**. The placeholder is `Serene Chu, 11, F`, which is a
    /// contract the reader has already agreed to by typing under it — where a file arrives from an
    /// office that was never asked. So the order is declared here, once, and the same `Columns`
    /// engine reads it.
    ///
    /// A pasted block that *does* carry its header — somebody selecting a spreadsheet range
    /// including row 1 — is read by that header instead, so the common accident still works.
    ///
    /// The residual case is a first line that reads as column names and is really a kid: `Ann
    /// Nameson, F` is accepted as a header, because the cell contains "name" and nothing in it is a
    /// number. It is the same arbiter the file path uses rather than a second one, and the mistake
    /// is visible — the review screen leads with the count, and a roster one short of what was
    /// pasted is the first thing anybody checks.
    static func parse(pasted text: String) throws -> IntakeImport {
        let lines = text.split(whereSeparator: \.isNewline)
        let separator = separator(in: lines)
        var rows = lines
            .map { fields(in: String($0), separator: separator) }
            .filter { row in row.contains { !$0.isEmpty } }

        guard !rows.isEmpty else { throw ReadError.nothingToImport }
        if Columns(header: rows[0]) == nil {
            rows.insert(pastedHeader, at: 0)
        }
        return try parse(rows: rows, named: pastedName)
    }

    /// How many kids a paste would bring in, for the button that has to say so before it is
    /// pressed.
    ///
    /// Swallows the throw on purpose: this runs on **every keystroke** in the box, where a half-
    /// typed line is the normal state rather than an error, and a message under a field somebody
    /// is still typing into cannot be acted on. The refusals still happen — `parse(pasted:)` is
    /// what the button calls — and by then there is something to say them about.
    static func pastedCount(_ text: String) -> Int {
        (try? parse(pasted: text))?.players.count ?? 0
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

        // One pass with three counters, rather than `max(by:)` over a closure that re-counts the
        // line for every comparison and once more for the guard — five walks of the header to
        // learn three numbers. The comma leads the list because ties fall to the first, and so
        // does a header with none of the three.
        var comma = 0, tab = 0, semicolon = 0
        for character in line {
            switch character {
            case ",": comma += 1
            case "\t": tab += 1
            case ";": semicolon += 1
            default: break
            }
        }
        if tab > comma, tab >= semicolon { return "\t" }
        if semicolon > comma, semicolon > tab { return ";" }
        return ","
    }

    /// Splits one line on `separator`, honouring double quotes so `"Nandan, Priya"` stays one
    /// field. A trailing carriage return is trimmed with the rest of the whitespace, so a file
    /// saved on Windows does not glue one onto its last column.
    /// A cell reduced to the letters in it, lower-cased — how every cell this file recognises by
    /// its wording is compared.
    ///
    /// Three places asked the same question and each spelled the answer out: the header sniffer,
    /// `Gender(fileValue:)` and `Bool(fileValue:)`. It is what lets "First Name", "first_name" and
    /// "Given name " reach the same column, and "F", "f " and "Female" reach the same gender.
    ///
    /// Digits are dropped deliberately, which is why this is not `RosterReconciliation.fold`.
    /// That one keeps them, because a digit is part of a child's name and a folded key that lost
    /// it would match two different people; here a digit is never part of the wording, and a
    /// header cell reading `Age 2` is still the age column.
    static func cellKey(_ cell: String) -> String {
        cell.lowercased().filter(\.isLetter)
    }

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

        // There is deliberately no `positional` fallback any more, and so no memberwise
        // initialiser either — it existed to build one. The fallback read `first, last, age,
        // gender` by position, which reads a surname-first export backwards and cleanly; see
        // `parse(rows:named:)` for why that is refused rather than guessed at.

        /// Nil when the first row is data rather than a header — which is the case as soon as
        /// one of its cells is a number, because no column is called "12". Returning nil is now
        /// the end of the read rather than the start of a guess.
        init?(header: [String]) {
            let keys = header.map(IntakeFile.cellKey)
            guard keys.contains(where: { $0.contains("name") || $0.contains("age") || $0.contains("gender") }),
                  !header.contains(where: { Int($0) != nil })
            else { return nil }

            firstName = keys.firstIndex { $0.contains("first") || $0.contains("given") }
            lastName = keys.firstIndex { $0.contains("last") || $0.contains("surname") || $0.contains("family") }
            // Only when there is no first-name column: a file with both "First name" and "Name"
            // means the second by something else entirely.
            fullName = firstName == nil ? keys.firstIndex { $0.contains("name") } : nil
            age = keys.firstIndex { $0.contains("age") }
            gender = keys.firstIndex { $0.contains("gender") || $0 == "sex" }
            isReturning = keys.firstIndex { $0.contains("return") }

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
                //
                // Most real files have no such column: the header has to contain "return" for one
                // to be found, and the export this was last checked against is four columns of
                // name, age and gender. So the common case is silence, and it has to stay silent.
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
        let value = IntakeFile.cellKey(fileValue)
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
        let value = IntakeFile.cellKey(fileValue)
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
