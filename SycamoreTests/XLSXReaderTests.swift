//
//  XLSXReaderTests.swift
//  SycamoreTests
//
//  The spreadsheet reader, hard.
//
//  A parser that quietly drops a column is worse than one that refuses the file: the refusal is
//  a sentence somebody can act on, and the drop is eighty kids imported with their genders one
//  column to the left, every row reading cleanly on `8d`, found out in week three. So the
//  assertions below are mostly about *placement* — which value ended up in which column — and
//  about what happens to a file the reader cannot open.
//
//  Everything is built by `XLSXFixture`, which writes a real ZIP with real deflate streams in it.
//  Nothing here came out of anybody's spreadsheet; see that file's header.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - The office's file

@Suite("Reading a workbook — the office's shape")
struct XLSXReaderOfficeTests {

    @Test("Every row and every column of a surname-first roster comes back")
    func theWholeGrid() throws {
        let rows = try XLSXReader.rows(from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster))

        #expect(rows == XLSXFixture.officeRoster)
    }

    /// The whole point of the change. `IntakeFile` already matched columns by their header words
    /// rather than by position, so a surname-first export lands correctly — but nothing had ever
    /// proved it end to end, because the bytes could not be read at all.
    @Test("A surname-first header lands the right way round, not backwards")
    func namesAreNotReversed() throws {
        let rows = try XLSXReader.rows(from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster))
        let file = try IntakeFile.parse(rows: rows, named: "roster.xlsx")

        #expect(file.players.count == 6)
        let first = try #require(file.players.first)
        #expect(first.firstName == "Amara")
        #expect(first.lastName == "Okonjo")
        #expect(first.age == 11)
        #expect(first.gender == .f)
    }

    /// "Male" and "Female" rather than "M" and "F", which is what the real export writes.
    @Test("Genders spelled out in full are read, and nobody needs a detail")
    func fullWordGenders() throws {
        let rows = try XLSXReader.rows(from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster))
        let file = try IntakeFile.parse(rows: rows, named: "roster.xlsx")

        #expect(file.players.map(\.gender) == [.f, .m, .m, .f, .f, .m])
        #expect(file.needsDetail.isEmpty)
    }

    /// A repeated surname is the case a reader gets away with on a tidy file and not on a real
    /// one: two Okonjos have to stay two people, with their own first names and ages.
    @Test("Two children with the same surname stay two children")
    func repeatedSurnames() throws {
        let rows = try XLSXReader.rows(from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster))
        let file = try IntakeFile.parse(rows: rows, named: "roster.xlsx")

        let okonjos = file.players.filter { $0.lastName == "Okonjo" }
        #expect(okonjos.map(\.firstName) == ["Amara", "Chidi"])
        #expect(okonjos.map(\.age) == [11, 9])
    }

    /// Nothing about a spreadsheet says the whole roster has to be one file, so the same grid is
    /// asserted through both readers: an `.xlsx` and the CSV of it must produce the same kids or
    /// the two paths have drifted.
    @Test("A workbook and the CSV of the same roster read identically")
    func theTwoReadersAgree() throws {
        let csv = XLSXFixture.officeRoster.map { $0.joined(separator: ",") }.joined(separator: "\n")

        let fromText = try IntakeFile.parse(csv, named: "roster.csv")
        let fromWorkbook = try IntakeFile.parse(
            rows: XLSXReader.rows(from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster)),
            named: "roster.xlsx"
        )

        #expect(fromText.players.map(\.displayName) == fromWorkbook.players.map(\.displayName))
        #expect(fromText.players.map(\.age) == fromWorkbook.players.map(\.age))
        #expect(fromText.players.map(\.gender) == fromWorkbook.players.map(\.gender))
    }
}

// MARK: - Choosing a reader

/// `IntakeFile.parse(_ data:named:)` is the way in from the picker, and the decision it makes —
/// which of the two readers a file needs — is the one part of the intake path that used to have
/// no test, because it was written inline in a `.fileImporter` callback.
@Suite("Reading a file — which reader")
struct IntakeFileDispatchTests {

    @Test("A workbook's bytes go to the spreadsheet reader")
    func aWorkbook() throws {
        let data = XLSXFixture.workbook(rows: XLSXFixture.officeRoster)
        let file = try IntakeFile.parse(data, named: "roster.xlsx")

        #expect(file.players.count == 6)
        #expect(file.players.first?.displayName == "Amara Okonjo")
    }

    @Test("A CSV's bytes go to the text reader")
    func aCSV() throws {
        let csv = "First name,Last name,Age,Gender\nAmara,Okonjo,11,Female"
        let file = try IntakeFile.parse(Data(csv.utf8), named: "roster.csv")

        #expect(file.players.count == 1)
        #expect(file.players.first?.displayName == "Amara Okonjo")
    }

    /// The reason the choice is made from the bytes rather than the extension: an office that
    /// exports a workbook and names it `.csv` is common enough to be worth surviving, and the
    /// name is the one thing about a file nobody checks.
    @Test("A workbook named .csv is still read as a workbook")
    func aMisnamedWorkbook() throws {
        let data = XLSXFixture.workbook(rows: XLSXFixture.officeRoster)
        let file = try IntakeFile.parse(data, named: "roster.csv")

        #expect(file.players.count == 6)
        #expect(file.fileName == "roster.csv", "the name is still what the person will see")
    }

    /// Bytes that are neither. UTF-8 is what a text export is, and something that is not it and
    /// not a ZIP has nothing left to try.
    @Test("Bytes that are neither a workbook nor text are refused")
    func neither() {
        #expect(throws: IntakeFile.ReadError.unreadable) {
            try IntakeFile.parse(Data([0xFF, 0xFE, 0xC0, 0x80, 0xFF]), named: "mystery.dat")
        }
    }
}

// MARK: - The container

@Suite("Reading a workbook — the container")
struct XLSXReaderContainerTests {

    /// Stored members are legal and some writers emit them for small parts. A reader that only
    /// knows deflate opens most files and fails on a few, which is the worst distribution.
    @Test("A workbook whose members are stored rather than deflated reads the same")
    func storedMembers() throws {
        let rows = try XLSXReader.rows(
            from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster, compressed: false)
        )

        #expect(rows == XLSXFixture.officeRoster)
    }

    @Test("A sheet stored somewhere other than sheet1.xml is found through the relationships")
    func sheetPathIsResolved() throws {
        let data = XLSXFixture.workbook(
            rows: XLSXFixture.officeRoster,
            sheetPath: "xl/worksheets/sheet4.xml"
        )

        #expect(try XLSXReader.rows(from: data) == XLSXFixture.officeRoster)
    }

    /// The fallback behind the fallback: a workbook written by something that skipped the
    /// relationship part entirely still has its sheet under `xl/worksheets/`.
    @Test("A workbook with no relationship part falls back to the one sheet it has")
    func sheetPathFallback() throws {
        let sheetOnly = XLSXFixture.archive([
            ("[Content_Types].xml", "<Types/>"),
            (
                "xl/worksheets/sheet2.xml",
                """
                <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
                <sheetData><row r="1">\
                <c r="A1" t="inlineStr"><is><t>First name</t></is></c>\
                <c r="B1" t="inlineStr"><is><t>Age</t></is></c>\
                </row><row r="2">\
                <c r="A2" t="inlineStr"><is><t>Amara</t></is></c>\
                <c r="B2" t="inlineStr"><is><t>11</t></is></c>\
                </row></sheetData></worksheet>
                """
            ),
        ])

        #expect(try XLSXReader.rows(from: sheetOnly) == [["First name", "Age"], ["Amara", "11"]])
    }

    @Test("Anything that is not a ZIP is refused rather than read as an empty roster")
    func notAWorkbook() {
        let csv = Data("First name,Last name,Age,Gender\nAmara,Okonjo,11,F".utf8)

        #expect(!XLSXReader.looksLikeAWorkbook(csv))
        #expect(throws: XLSXReader.ReadError.notAWorkbook) {
            try XLSXReader.rows(from: csv)
        }
    }

    @Test("A ZIP with no sheet in it is refused by name")
    func noWorksheet() {
        let empty = XLSXFixture.archive([("[Content_Types].xml", "<Types/>")])

        #expect(XLSXReader.looksLikeAWorkbook(empty))
        #expect(throws: XLSXReader.ReadError.noWorksheet) {
            try XLSXReader.rows(from: empty)
        }
    }

    /// A download that stopped early. It still begins `PK`, so the sniff says workbook and the
    /// reader has to be the one that notices.
    @Test("A workbook cut in half is refused rather than half-read")
    func truncated() {
        var data = XLSXFixture.workbook(rows: XLSXFixture.officeRoster)
        data = data.prefix(data.count / 2)

        #expect(XLSXReader.looksLikeAWorkbook(data))
        #expect(throws: (any Error).self) {
            try XLSXReader.rows(from: data)
        }
    }

    /// ZIP64 moves the real sizes and offsets into an extra field this reader does not parse, and
    /// saturates the 32-bit ones at `0xFFFF_FFFF`. Refusing is the point: reading `0xFFFF_FFFF`
    /// as an offset would send it looking four gigabytes past the end of a spreadsheet.
    @Test("A ZIP64 archive is refused rather than read at a saturated offset")
    func zip64IsRefused() throws {
        var data = XLSXFixture.workbook(rows: XLSXFixture.officeRoster)
        // The end record is the last 22 bytes and the central directory's offset is 16 into it.
        let field = data.count - 6
        for index in field..<(field + 4) { data[index] = 0xFF }

        #expect(throws: ZIPArchive.ReadError.zip64) {
            _ = try ZIPArchive(data)
        }
        #expect(throws: XLSXReader.ReadError.damaged) {
            try XLSXReader.rows(from: data)
        }
    }

    @Test("A workbook's own bytes are recognised, a CSV's are not")
    func sniffing() {
        #expect(XLSXReader.looksLikeAWorkbook(XLSXFixture.workbook(rows: XLSXFixture.officeRoster)))
        #expect(!XLSXReader.looksLikeAWorkbook(Data("Name,Age\nAmara,11".utf8)))
        #expect(!XLSXReader.looksLikeAWorkbook(Data()))
        #expect(!XLSXReader.looksLikeAWorkbook(Data("PK".utf8)), "half the magic is not the magic")
    }

    /// The sniff is four bytes and makes no promise beyond them — a file that begins `PK` and
    /// then stops is a workbook as far as it is concerned, and the reader is what refuses it.
    /// Worth pinning because the two together are what decides which sentence a person is shown.
    @Test("The magic and nothing after it is refused by the reader, not by the sniff")
    func theMagicAlone() {
        let magicOnly = Data([0x50, 0x4B, 0x03, 0x04])

        #expect(XLSXReader.looksLikeAWorkbook(magicOnly))
        #expect(throws: XLSXReader.ReadError.damaged) {
            try XLSXReader.rows(from: magicOnly)
        }
    }

    /// `XMLParser` reports what it read right up to the point a document stops being well-formed
    /// and then simply stops. Taken at face value that is a roster silently missing its last
    /// forty kids — every row that did arrive reading cleanly on `8d`, and no way to tell.
    @Test("A sheet that stops half way is refused, not handed back short")
    func aTruncatedSheetIsRefused() {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1"><c r="A1" t="inlineStr"><is><t>First name</t></is></c></row>\
                <row r="2"><c r="A2" t="inlineStr"><is><t>Amara</t></is></c></row>\
                <row r="3"><c r="A3" t="inlineStr"><is><t>Chidi
                """
        )

        #expect(throws: XLSXReader.ReadError.damaged) {
            try XLSXReader.rows(from: data)
        }
    }

    /// The same, one part over. A shared-string table cut short is worse than a sheet cut short:
    /// every index past the cut resolves to a blank, so the names do not go missing — they go
    /// *empty*, which reads as a file the office filled in badly.
    @Test("A shared-string table that stops half way is refused too")
    func aTruncatedStringTableIsRefused() {
        let data = XLSXFixture.workbook(
            sheetBody: #"<row r="1"><c r="A1" t="s"><v>0</v></c></row>"#,
            sharedStrings: """
                <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
                <si><t>Amara</t></si><si><t>Chidi
                """
        )

        #expect(throws: XLSXReader.ReadError.damaged) {
            try XLSXReader.rows(from: data)
        }
    }
}

// MARK: - The cells

@Suite("Reading a workbook — the cells")
struct XLSXReaderCellTests {

    /// The one that would ruin a roster silently. A spreadsheet omits a blank cell rather than
    /// writing an empty one, so a row with no age jumps from `B` to `D` — and a reader that
    /// appends values as it meets them puts the gender where the age should be, **for that row
    /// only**, which is exactly the shape of defect nobody spots on a review screen.
    @Test("A row that skips a column keeps everything else in its own column")
    func aGapInTheColumnLetters() throws {
        let data = XLSXFixture.workbook(rows: [
            ["First name", "Last name", "Age", "Gender"],
            ["Amara", "Okonjo", "11", "Female"],
            ["Chidi", "Okonjo", nil, "Male"],
        ])

        let rows = try XLSXReader.rows(from: data)
        #expect(rows[2] == ["Chidi", "Okonjo", "", "Male"])

        let file = try IntakeFile.parse(rows: rows, named: "roster.xlsx")
        let chidi = try #require(file.players.last)
        #expect(chidi.age == nil)
        #expect(chidi.gender == .m, "the gender must not have slid into the age column")
        #expect(chidi.issue == .noAge)
    }

    @Test("A leading gap is a gap, not a shift")
    func aGapInTheFirstColumn() throws {
        let data = XLSXFixture.workbook(rows: [
            ["First name", "Last name", "Age"],
            [nil, "Okonjo", "11"],
        ])

        #expect(try XLSXReader.rows(from: data)[1] == ["", "Okonjo", "11"])
    }

    @Test("Inline strings read the same as shared ones")
    func inlineStrings() throws {
        let shared = try XLSXReader.rows(from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster))
        let inline = try XLSXReader.rows(
            from: XLSXFixture.workbook(rows: XLSXFixture.officeRoster, inline: true)
        )

        #expect(inline == shared)
    }

    /// A name Excel split into formatting runs — half of it bold, say — is one name.
    @Test("A shared string written as several runs comes back whole")
    func richTextRuns() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1"><c r="A1" t="s"><v>0</v></c></row>
                """,
            sharedStrings: """
                <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
                <si><r><t>Fen</t></r><r><t>wick</t></r></si></sst>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Fenwick"]])
    }

    /// A Japanese workbook carries the reading of a name beside it in `<rPh>`, whose `<t>` looks
    /// exactly like the name's own. Glued on, the surname would be twice as long as it is.
    @Test("A phonetic guide beside a name is not read as part of the name")
    func phoneticGuidesAreIgnored() throws {
        let data = XLSXFixture.workbook(
            sheetBody: #"<row r="1"><c r="A1" t="s"><v>0</v></c></row>"#,
            sharedStrings: """
                <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
                <si><t>Okonjo</t><rPh sb="0" eb="1"><t>OKONJO</t></rPh></si></sst>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Okonjo"]])
    }

    /// The reader states that it does not evaluate formulas. What it does instead is take the
    /// value Excel cached beside the formula, which is what the person looking at the sheet saw
    /// — and it must never take the formula's *text*.
    @Test("A formula's cached result is the cell's value, and the formula itself is not")
    func formulasUseTheCachedValue() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1">\
                <c r="A1" t="str"><f>CONCATENATE(B1,C1)</f><v>Amara</v></c>\
                <c r="B1"><f>2024-2013</f><v>11</v></c>\
                </row>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Amara", "11"]])
    }

    @Test("An error cell is blank rather than the word #N/A in somebody's surname")
    func errorCells() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1">\
                <c r="A1" t="inlineStr"><is><t>Amara</t></is></c>\
                <c r="B1" t="e"><v>#N/A</v></c>\
                </row>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Amara", ""]])
    }

    /// An age typed as a number rather than as text is the commonest cell in a roster after the
    /// names, and it carries no `t` at all.
    @Test("An untyped numeric cell reads its digits")
    func numbers() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1">\
                <c r="A1" t="inlineStr"><is><t>Age</t></is></c>\
                </row><row r="2"><c r="A2"><v>11</v></c></row>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Age"], ["11"]])
    }

    /// A workbook that contradicts itself. Blank is the honest answer: it becomes a question on
    /// `8d` rather than somebody else's name.
    @Test("A shared-string index the table cannot answer is blank, not a crash and not a guess")
    func aSharedStringIndexOutOfRange() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1">\
                <c r="A1" t="s"><v>0</v></c>\
                <c r="B1" t="s"><v>99</v></c>\
                <c r="C1" t="s"><v>not a number</v></c>\
                </row>
                """,
            sharedStrings: """
                <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
                <si><t>Amara</t></si></sst>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Amara", "", ""]])
    }

    /// The CSV path trims every field it cuts, and `IntakePlayer.issue` counts a surname's length
    /// on the promise that both writers do. A second producer that did not would make the two
    /// kinds of file disagree about a name with a trailing space in it.
    @Test("Cells arrive trimmed, the way the CSV reader's do")
    func cellsAreTrimmed() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1">\
                <c r="A1" t="inlineStr"><is><t xml:space="preserve">  Amara  </t></is></c>\
                </row>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Amara"]])
    }

    /// `parse(rows:)` drops them, the same way it drops an empty CSV line, so a spreadsheet with
    /// a spacer row between two halves of the roster does not produce a nameless kid.
    @Test("An empty row in the middle of a sheet does not become a kid")
    func emptyRows() throws {
        let data = XLSXFixture.workbook(rows: [
            ["First name", "Last name", "Age", "Gender"],
            ["Amara", "Okonjo", "11", "Female"],
            [nil, nil, nil, nil],
            ["Chidi", "Okonjo", "9", "Male"],
        ])

        let file = try IntakeFile.parse(rows: try XLSXReader.rows(from: data), named: "roster.xlsx")
        #expect(file.players.map(\.firstName) == ["Amara", "Chidi"])
    }

    /// Base-26 with no zero, which is the one piece of arithmetic in the reader that is easy to
    /// get wrong at exactly the boundary a 26-column roster would find.
    @Test(
        "A column reference is read in base-26",
        arguments: [("A1", 0), ("B2", 1), ("Z9", 25), ("AA1", 26), ("AB1", 27), ("BA1", 52)]
    )
    func columnReferences(_ reference: String, _ expected: Int) throws {
        let data = XLSXFixture.workbook(
            sheetBody: #"<row r="1"><c r="\#(reference)" t="inlineStr"><is><t>x</t></is></c></row>"#
        )

        let row = try #require(try XLSXReader.rows(from: data).first)
        #expect(row.count == expected + 1)
        #expect(row.last == "x")
    }

    /// The one place in the reader where a number in the file decides the size of an allocation.
    /// A row is a dense array, so `AAAAAA1` would have three hundred million empty strings padded
    /// into it before anybody noticed. Excel's own widest column is `XFD`; past that the reference
    /// is not a column, and the cell falls back to the position it was met in.
    @Test("A column reference wider than a spreadsheet can be does not pad a row to it")
    func anAbsurdColumnReference() throws {
        let data = XLSXFixture.workbook(
            sheetBody: """
                <row r="1">\
                <c r="A1" t="inlineStr"><is><t>Amara</t></is></c>\
                <c r="AAAAAA1" t="inlineStr"><is><t>Chidi</t></is></c>\
                </row>
                """
        )

        #expect(try XLSXReader.rows(from: data) == [["Amara", "Chidi"]])
    }

    /// `XFD` itself is a real column and still resolves, so the ceiling is the format's rather
    /// than a smaller one invented here.
    @Test("The widest column a spreadsheet can have still resolves")
    func theWidestRealColumn() throws {
        let data = XLSXFixture.workbook(
            sheetBody: #"<row r="1"><c r="XFD1" t="inlineStr"><is><t>x</t></is></c></row>"#
        )

        let row = try #require(try XLSXReader.rows(from: data).first)
        #expect(row.count == 16_384)
        #expect(row.last == "x")
    }
}
