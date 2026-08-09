//
//  IntakeFileTests.swift
//  SycamoreTests
//
//  The parser, which had no tests at all.
//
//  `IntakeFile.parse` is the only code in the app that reads something a stranger wrote. It is
//  deliberately tolerant — a header is sniffed rather than demanded, a column is matched by what
//  it contains rather than by an exact spelling — and tolerance without tests is indistinguishable
//  from a parser that quietly reads the wrong thing. Three of the sentences below were red before
//  the fixes that landed with them: a tab-separated file, a semicolon-separated file, and the
//  difference between a file that says "not returning" and one that never mentions returning.
//
//  Everything the file does not say has to stay nil, because a second file is now read against a
//  camp that already exists and `RosterReconciliation` reads nil as silence. A default invented
//  here is a change proposed there.
//

import Foundation
import Testing
@testable import Sycamore

private func parse(_ text: String) throws -> IntakeImport {
    try IntakeFile.parse(text, named: "sign-ups.csv")
}

// MARK: - Finding the columns

@Suite("Reading a file — the header")
struct IntakeFileHeaderTests {

    @Test(
        "A header row is recognised by its words, so \"First Name\", \"first_name\" and \"Given name\" all land in the same column",
        arguments: [
            "First Name,Last Name,Age,Gender",
            "first_name,last_name,age,gender",
            "Given name,Family name,Age,Gender",
            "GIVEN NAME , SURNAME , AGE , SEX",
        ]
    )
    func aHeaderIsRecognisedByItsWords(_ header: String) throws {
        let file = try parse("\(header)\nSerene,Chu,13,F")

        let kid = try #require(file.players.first)
        #expect(file.players.count == 1)
        #expect(kid.firstName == "Serene")
        #expect(kid.lastName == "Chu")
        #expect(kid.age == 13)
        #expect(kid.gender == .f)
    }

    /// "Sage" contains "age", so the words alone would read this row as a header and eat a kid.
    /// The number in the third cell is what saves it.
    @Test("A first row that is data is kept, because nobody calls a column \"12\"")
    func aFirstRowThatIsDataIsKept() throws {
        let file = try parse("Sage,Miller,13,F\nLiam,Prior,12,M")

        #expect(file.players.count == 2)
        #expect(file.players.map(\.firstName) == ["Sage", "Liam"])
    }

    @Test("Without a header the columns are read as first, last, age, gender, in that order")
    func withoutAHeaderTheColumnsArePositional() throws {
        let file = try parse("Serene,Chu,13,F")

        let kid = try #require(file.players.first)
        #expect(kid.firstName == "Serene")
        #expect(kid.lastName == "Chu")
        #expect(kid.age == 13)
        #expect(kid.gender == .f)
    }

    @Test("A single \"Name\" column splits on the first space, and everything after it is the surname")
    func aSingleNameColumnSplitsOnTheFirstSpace() throws {
        let file = try parse("Name,Age,Gender\nMaria de la Cruz,12,F")

        let kid = try #require(file.players.first)
        #expect(kid.firstName == "Maria")
        #expect(kid.lastName == "de la Cruz")
    }
}

// MARK: - Where one field ends and the next begins

@Suite("Reading a file — the separators")
struct IntakeFileSeparatorTests {

    @Test("A quoted comma stays inside its field, so \"Nandan, Priya\" is one name and not two")
    func aQuotedCommaStaysInsideItsField() throws {
        let file = try parse("Name,Age,Gender\n\"Nandan, Priya\",12,F")

        // One kid, and the age is still 12 — which is the thing a swallowed comma breaks. Had the
        // quote not held, "Priya" would have become the age column and 12 the gender.
        let kid = try #require(file.players.first)
        #expect(file.players.count == 1)
        #expect(kid.displayName == "Nandan, Priya")
        #expect(kid.age == 12)
        #expect(kid.gender == .f)
    }

    /// `BringInTheWeekView` puts `.tabSeparatedText` in the picker's `allowedContentTypes`, so a
    /// TSV is a file the app offers to open. Split on commas it became **one glued column** — and
    /// the header sniff still succeeded, because the glued cell contains "first", so every field
    /// read that same cell and the whole row became a first name.
    @Test("A tab-separated file is read by its tabs, because the picker offers one")
    func aTabSeparatedFileIsReadByItsTabs() throws {
        let file = try parse("First name\tLast name\tAge\tGender\nSerene\tChu\t13\tF\nLiam\tPrior\t12\tM")

        #expect(file.players.count == 2)
        let kid = try #require(file.players.first)
        #expect(kid.firstName == "Serene")
        #expect(kid.lastName == "Chu")
        #expect(kid.age == 13)
        #expect(kid.gender == .f)
    }

    @Test("A semicolon-separated file, which is what a European Excel exports, reads the same way")
    func aSemicolonSeparatedFileReadsTheSameWay() throws {
        let file = try parse("First name;Last name;Age;Gender\nSerene;Chu;13;F\nLiam;Prior;12;M")

        #expect(file.players.count == 2)
        let kid = try #require(file.players.first)
        #expect(kid.firstName == "Serene")
        #expect(kid.lastName == "Chu")
        #expect(kid.age == 13)
        #expect(kid.gender == .f)
    }

    /// The sniff has to fall back rather than fail: a file with none of the three candidates is a
    /// one-column list of names, which is a real thing an office sends and used to work.
    @Test("A file with no separator in it at all is one column of names, as it always was")
    func aFileWithNoSeparator() throws {
        let file = try parse("Name\nSerene\nLiam")

        #expect(file.players.map(\.firstName) == ["Serene", "Liam"])
    }

    @Test("Windows line endings do not leave a carriage return glued to the last field")
    func windowsLineEndings() throws {
        let file = try parse("First name,Age,Gender,Last name\r\nSerene,13,F,Chu\r\nLiam,12,M,Prior\r\n")

        #expect(file.players.count == 2)
        #expect(file.players.map(\.lastName) == ["Chu", "Prior"])
    }

    @Test("Blank lines between kids are skipped rather than read as empty ones")
    func blankLinesAreSkipped() throws {
        let file = try parse("First name,Last name,Age,Gender\n\nSerene,Chu,13,F\n\n\n,,,\nLiam,Prior,12,M\n")

        #expect(file.players.count == 2)
        #expect(file.players.map(\.firstName) == ["Serene", "Liam"])
    }

    @Test("A row with no name at all is a spacer or a total, and does not become a kid")
    func aRowWithNoNameIsNotAKid() throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,13,F\n,,42,\nLiam,Prior,12,M")

        #expect(file.players.count == 2)
        #expect(file.players.map(\.firstName) == ["Serene", "Liam"])
    }

    @Test(
        "An empty file and a file of nothing but commas both read as nothing to import",
        arguments: ["", "\n\n", ",,,\n,,,\n", "   \n"]
    )
    func nothingToImport(_ text: String) {
        #expect(throws: IntakeFile.ReadError.nothingToImport) {
            try IntakeFile.parse(text, named: "empty.csv")
        }
    }
}

// MARK: - Reading one cell

@Suite("Reading a file — the cells")
struct IntakeFileCellTests {

    /// Through `parse` rather than straight at `Gender(fileValue:)`, which `GenderFileValueTests`
    /// already covers: the question here is whether a whole row survives the spelling, not whether
    /// the cell reader knows the word.
    @Test(
        "Gender reads F, female, girl, W, M, boy, X, other and \"prefer not to say\"",
        arguments: [
            ("F", Gender.f), ("female", .f), ("Girl", .f), ("W", .f), ("Woman", .f),
            ("M", .m), ("boy", .m), ("Male", .m),
            ("X", .x), ("other", .x), ("\"prefer not to say\"", .x), ("Non-binary", .x),
        ]
    )
    func genderReadsHoweverTheOfficeSpellsIt(_ cell: String, _ expected: Gender) throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,13,\(cell)")

        #expect(file.players.first?.gender == expected)
        #expect(file.players.first?.issue == nil)
    }

    @Test(
        "A gender the file spells in a way we do not recognise stays nil rather than becoming a guess",
        arguments: ["", "   ", "-", "42", "unknown", "enby", "Q"]
    )
    func anUnreadableGenderStaysNil(_ cell: String) throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,13,\(cell)")

        // Not a guess and not a default: a question, asked by name on `8d` beside a Fix button.
        #expect(file.players.first?.gender == nil)
        #expect(file.players.first?.issue == .noGender)
        #expect(file.needsDetail.count == 1)
    }

    @Test(
        "A returning column is read however the office spells yes — Y, true, returning, 1",
        arguments: ["Y", "yes", "Yes", "TRUE", "true", "returning", "Returner", "1"]
    )
    func aReturningColumnIsReadHoweverTheOfficeSpellsYes(_ cell: String) throws {
        let file = try parse("First name,Last name,Age,Gender,Returning\nSerene,Chu,13,F,\(cell)")

        #expect(file.players.first?.isReturning == true)
        #expect(file.returningCount == 1)
    }

    /// The one place a blank cell is *not* silence. An office that tracks returners ticks them and
    /// leaves everybody else empty, so a blank inside a real returning column is a no — and a
    /// re-import that could never un-return anybody would be worse than one that can.
    @Test(
        "A blank cell inside a returning column is a no, because an office ticks its returners and leaves the rest empty",
        arguments: ["", "N", "no", "false", "0"]
    )
    func aBlankCellInsideAReturningColumnIsANo(_ cell: String) throws {
        let file = try parse("First name,Last name,Age,Gender,Returning\nSerene,Chu,13,F,\(cell)")

        #expect(file.players.first?.isReturning == false)
        #expect(file.newCount == 1)
    }

    /// The defect this replaced: `false` stood for both "the office said no" and "the office had
    /// no such column", and the second is by far the commoner — the column is only found when a
    /// header cell contains "return", and a file read positionally never has one. A re-import of
    /// an ordinary four-column file would have proposed un-returning every returning kid.
    @Test("A file with no returning column says nothing about returning, rather than saying no")
    func aFileWithNoReturningColumnSaysNothing() throws {
        let withHeader = try parse("First name,Last name,Age,Gender\nSerene,Chu,13,F")
        let positional = try parse("Serene,Chu,13,F")

        #expect(withHeader.players.first?.isReturning == nil)
        #expect(positional.players.first?.isReturning == nil)

        // And the counts card on `8d` reads exactly as it always did: nobody has been told these
        // kids were here last year, so nobody is counted as returning.
        #expect(withHeader.newCount == 1)
        #expect(withHeader.returningCount == 0)
    }

    @Test("An age that is not a number stays nil and becomes a row that needs a detail")
    func anUnreadableAgeStaysNil() throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,thirteen,F")

        #expect(file.players.first?.age == nil)
        #expect(file.players.first?.issue == .noAge)
        #expect(file.needsDetail.count == 1)
    }
}

// MARK: - The two cells the roster column will not take

/// `players_age_check` admits 4…19 and `players_last_name_len` admits 1…60 characters, and
/// `importPlayers` sends the whole roster in a single insert. Before these two cases existed, one
/// kid whose spreadsheet said 25 rejected **every other kid in the file** with a raw PostgREST
/// message and no row to point at.
@Suite("Reading a file — cells the column would reject")
struct IntakeFileRejectionTests {

    @Test("An age of 25 is a detail to fix, not a roster that fails at the door")
    func anImpossibleAgeIsADetailToFix() throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,25,F\nLiam,Prior,12,M")

        #expect(file.players[0].age == 25)
        #expect(file.players[0].issue == .impossibleAge)
        #expect(file.players[1].issue == nil)
        #expect(file.needsDetail.count == 1)
        #expect(file.readCleanly.count == 1)
        #expect(IntakeIssue.impossibleAge.label == "An age outside 4 to 19")
    }

    @Test("The ages the column does take are read without a question", arguments: [4, 12, 19])
    func theAgesTheColumnTakes(_ age: Int) throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,\(age),F")

        #expect(file.players.first?.issue == nil)
    }

    @Test("The ages either side of the column's limits are not", arguments: [0, 3, 20, 99])
    func theAgesTheColumnRejects(_ age: Int) throws {
        let file = try parse("First name,Last name,Age,Gender\nSerene,Chu,\(age),F")

        #expect(file.players.first?.issue == .impossibleAge)
    }

    @Test("A surname longer than the column takes is a detail to fix, for the same reason")
    func aLongSurnameIsADetailToFix() throws {
        let tooLong = String(repeating: "a", count: 61)
        let atTheLimit = String(repeating: "a", count: 60)

        let rejected = try parse("First name,Last name,Age,Gender\nSerene,\(tooLong),13,F")
        let accepted = try parse("First name,Last name,Age,Gender\nSerene,\(atTheLimit),13,F")

        #expect(rejected.players.first?.issue == .longSurname)
        #expect(accepted.players.first?.issue == nil)
        #expect(IntakeIssue.longSurname.label == "A surname longer than 60 letters")
    }

    /// The mistake `CharLength` exists to stop, and the one a test built the obvious way misses.
    /// Postgres counts characters of the UTF-8 string; Swift's `.count` counts grapheme clusters,
    /// and one cluster can be many scalars — so twenty family emoji are "20 characters" here and
    /// several hundred to the column that has to store them.
    @Test("A surname is counted the way Postgres counts, not the way Swift reads")
    func aSurnameIsCountedInScalars() throws {
        let manyFamilies = String(repeating: "👩‍👩‍👧", count: 20)
        #expect(manyFamilies.count == 20, "comfortably inside 60 Characters")

        let file = try parse("First name,Last name,Age,Gender\nSerene,\(manyFamilies),13,F")

        #expect(file.players.first?.issue == .longSurname)
    }
}
