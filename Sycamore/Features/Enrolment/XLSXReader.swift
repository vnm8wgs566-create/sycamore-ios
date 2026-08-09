//
//  XLSXReader.swift
//  Sycamore
//
//  The office sends Excel. This reads it.
//
//  `8c` offered `.commaSeparatedText`, `.tabSeparatedText` and `.plainText`, which meant the one
//  file most camps actually have — the `.xlsx` their sign-up system exports — was greyed out in
//  the picker with nothing on screen to say why. Everything downstream was already fine:
//  `IntakeFile.Columns(header:)` matches a column by the words in it rather than by its position,
//  so this file's surname-first `Last Name, First Name, Age, Gender` lands correctly, and
//  `Gender(fileValue:)` folds "Female" to `.f`. The only thing missing was the ability to read
//  the bytes.
//
//  An `.xlsx` is a ZIP of XML — `ZIPArchive` opens the container, `XMLParser` reads the parts.
//  What comes out is `[[String]]`, the same row-of-cells shape `IntakeFile.fields(in:separator:)`
//  produces for a CSV, so reconciliation, the review screen and the commit path never learn that
//  a second kind of file exists.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT THIS DELIBERATELY DOES NOT DO
//  ---------------------------------------------------------------------------------------------
//
//  A roster is names, ages and genders. It is not a spreadsheet, and reading one as if it were
//  would mean carrying a formula engine and a calendar around for a file that has neither.
//
//  - **Formulas are not evaluated.** A formula cell's *cached* result — the value Excel wrote
//    beside the formula when it last recalculated — is taken as the cell's text, which is what
//    the person looking at the spreadsheet saw. A workbook saved by something that writes
//    formulas without caching their results gives blank cells, and those land on `8d` as a
//    question rather than as a wrong answer.
//  - **Dates are not converted.** Excel stores a date as a day count and a number format, and
//    this reads the day count. Nothing on a roster is a date — the age column is an age — so a
//    date cell would arrive as `45000` and become "no age", which is a visible question rather
//    than a silent wrong number.
//  - **The first sheet only.** Resolved properly, through `xl/workbook.xml` and its relationships
//    rather than by assuming `sheet1.xml`, because the two disagree more often than you would
//    think. A workbook with the roster on its second tab reads the first tab; that is a limit
//    worth stating rather than a heuristic worth guessing at.
//  - **No styles, merges, filters or hidden rows.** A hidden row is still a kid.
//
//  Anything it cannot open is refused with a sentence, never half-read. A spreadsheet reader that
//  silently drops a column is worse than one that declines the file.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - The type the picker offers

extension UTType {

    /// `org.openxmlformats.spreadsheetml.sheet` — Excel's `.xlsx`, and nothing else.
    ///
    /// Deliberately **not** `UTType.spreadsheet`, which is `public.spreadsheet`: everything from
    /// Numbers documents to `.ods` to Excel's own binary `.xls` conforms to it, and every one of
    /// those would be offered by the picker and then refused by this reader. A picker that greys
    /// out a file it cannot read is telling the truth before the tap; one that accepts it and
    /// fails afterwards is not.
    ///
    /// `importedAs:` rather than the failable `UTType(_:)`. The identifier is system-declared on
    /// both platforms this ships to, and `importedAs:` returns that declaration when it exists —
    /// but it is also non-failable, so there is no `?? .data` fallback here quietly widening the
    /// picker on a platform where the lookup missed.
    static let xlsx = UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet")
}

// MARK: - The reader

enum XLSXReader {

    enum ReadError: LocalizedError, Equatable {
        /// The bytes are not a workbook. Usually an `.xls` — Excel's pre-2007 binary format,
        /// which is not a ZIP and shares nothing with this one but the icon.
        case notAWorkbook
        /// A ZIP, but not one with a sheet in it.
        case noWorksheet
        /// Opened, and something inside would not read.
        case damaged

        var errorDescription: String? {
            switch self {
            case .notAWorkbook:
                "That doesn't look like an Excel file. Save it as .xlsx, or export a CSV."
            case .noWorksheet:
                "We opened that workbook and found no sheet in it."
            case .damaged:
                "We couldn't read that workbook. Opening it in Excel and saving it again usually fixes it."
            }
        }
    }

    /// Whether these bytes are worth handing to `rows(from:)`.
    ///
    /// Sniffed from the bytes rather than taken from the file extension, and that is the point: a
    /// file the office named `roster.csv` and exported as a workbook is common enough to be worth
    /// handling, and so is the reverse. The picker's `allowedContentTypes` decides what may be
    /// chosen; this decides how what was chosen is read.
    static func looksLikeAWorkbook(_ data: Data) -> Bool {
        data.starts(with: ZIPArchive.magic)
    }

    /// Every row of the first sheet, as cells.
    ///
    /// Cells arrive **trimmed**, because the CSV path trims too — `IntakeFile.fields(in:separator:)`
    /// trims each field it cuts, and `IntakePlayer.issue` counts a surname's length on the promise
    /// that "both writers hand it over trimmed already" (`IntakeRoster.swift:92-94`). A second
    /// producer of rows has to keep that promise or the promise stops being one.
    ///
    /// Blank rows are emitted as they stand rather than filtered here; `IntakeFile.parse(rows:)`
    /// drops them for both file kinds in one place.
    static func rows(from data: Data) throws -> [[String]] {
        guard looksLikeAWorkbook(data) else { throw ReadError.notAWorkbook }

        do {
            let archive = try ZIPArchive(data)
            guard let path = worksheetPath(in: archive),
                  let sheet = try archive.data(for: path)
            else { throw ReadError.noWorksheet }

            // Both parses are checked rather than taken for what they managed. `XMLParser` reports
            // rows right up to the point a document stops being well-formed and then simply stops,
            // so a sheet cut in half hands back the kids it reached and no indication that there
            // were more — a roster silently missing its last forty names, which is the exact
            // failure this whole file is written to avoid.
            var shared: [String] = []
            if let table = try archive.data(for: "xl/sharedStrings.xml") {
                guard let parsed = SharedStringParser.strings(in: table) else {
                    throw ReadError.damaged
                }
                shared = parsed
            }
            guard let cells = SheetParser.rows(in: sheet, sharedStrings: shared) else {
                throw ReadError.damaged
            }
            return cells
        } catch let error as ReadError {
            throw error
        } catch {
            // Every remaining failure is the container's, and the sniff above has already ruled
            // out "this was never a workbook" — bytes that begin `PK` and then will not open are
            // a download that stopped, or a file something wrote badly. `damaged` says so and
            // suggests the fix that works for both.
            throw ReadError.damaged
        }
    }

    // MARK: Which sheet

    /// The path of the first sheet, resolved the long way round.
    ///
    /// `xl/workbook.xml` lists the tabs in the order they appear and names each by a relationship
    /// id; `xl/_rels/workbook.xml.rels` maps that id to a part. Assuming `xl/worksheets/sheet1.xml`
    /// works often and not always — a workbook whose first tab was deleted keeps `sheet2.xml` as
    /// its first sheet, and the file this was written against names its only tab "4" while storing
    /// it in `sheet1.xml`, which is the same trap seen from the other side.
    ///
    /// Two fallbacks, in order, because a workbook written by something other than Excel may skip
    /// either part: the conventional path, then whichever member is under `xl/worksheets/`. The
    /// last one sorts, so a workbook with several sheets and no index picks the same one twice
    /// running rather than whichever the dictionary happened to yield first.
    private static func worksheetPath(in archive: ZIPArchive) -> String? {
        if let target = firstSheetTarget(in: archive), archive.contains(target) {
            return target
        }
        if archive.contains("xl/worksheets/sheet1.xml") {
            return "xl/worksheets/sheet1.xml"
        }
        return archive.names
            .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .min()
    }

    private static func firstSheetTarget(in archive: ZIPArchive) -> String? {
        guard let workbook = try? archive.data(for: "xl/workbook.xml"),
              let relationshipID = FirstSheetParser.relationshipID(in: workbook),
              let rels = try? archive.data(for: "xl/_rels/workbook.xml.rels"),
              let target = RelationshipParser.targets(in: rels)[relationshipID]
        else { return nil }

        // A target is relative to the part that declared it — `xl/workbook.xml` — unless it is
        // absolute, in which case it is relative to the package root and the leading slash is the
        // only thing standing between the two readings.
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        return "xl/" + target
    }

    // MARK: Driving the parser

    /// Runs `delegate` over `data`, and says whether the document held together.
    ///
    /// One place, because the four parses below do not agree on what a `false` means and that
    /// disagreement is deliberate. The sheet and the shared strings are the roster: a document
    /// that stops half way gives back a roster missing its last forty kids with nothing to say
    /// so, which is the failure this whole file exists to avoid, and both of those callers refuse
    /// it. The workbook index and its relationships are a *hint* — there are two fallbacks behind
    /// them — so those two take whatever they got and let `worksheetPath` carry on.
    private static func read(_ data: Data, with delegate: some XMLParserDelegate) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        return parser.parse()
    }

    // MARK: - Reading the sheet

    /// `xl/worksheets/sheetN.xml` — the rows themselves.
    ///
    /// A `final class` on `NSObject` because that is what `XMLParserDelegate` is: an `@objc`
    /// protocol. It is created, driven and dropped inside one synchronous call, so nothing about
    /// it ever crosses an isolation boundary.
    private final class SheetParser: NSObject, XMLParserDelegate {

        /// Nil when the document is not well-formed all the way to the end — see `rows(from:)`.
        static func rows(in data: Data, sharedStrings: [String]) -> [[String]]? {
            let delegate = SheetParser(sharedStrings: sharedStrings)
            return read(data, with: delegate) ? delegate.rows : nil
        }

        private let sharedStrings: [String]
        private var rows: [[String]] = []

        private var row: [String] = []
        /// Which column the cell being read belongs to, taken from its `r="B7"` reference. This
        /// is the whole reason cells are placed rather than appended: a row is allowed to omit
        /// its empty cells entirely, so a kid with no age arrives as `A7, B7, D7` and appending
        /// would slide the gender into the age column for that row and no other.
        private var column = 0
        private var cellType = ""
        /// Accumulated across every `<v>` and `<t>` inside the current cell. Appended rather than
        /// assigned so an inline string written as several formatting runs comes back whole.
        private var cell = ""
        private var isReadingText = false
        private var isInsideCell = false

        init(sharedStrings: [String]) {
            self.sharedStrings = sharedStrings
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            switch elementName {
            case "row":
                row = []
                column = 0
            case "c":
                isInsideCell = true
                cell = ""
                cellType = attributes["t"] ?? ""
                column = attributes["r"].flatMap(Self.columnIndex(inReference:)) ?? row.count
            case "v", "t":
                // Only inside a cell, so that neither `<f>`'s formula text nor anything in the
                // sheet's own preamble is mistaken for a value.
                guard isInsideCell else { return }
                isReadingText = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isReadingText else { return }
            cell += string
        }

        /// A `<![CDATA[…]]>` section, which is a legal way to write a cell's text and which
        /// `foundCharacters` is never called for. Excel does not write them; a workbook produced
        /// by a reporting tool sometimes does, and without this its names come back empty.
        /// (Entities are not this method's business — `XMLParser` resolves `&apos;` and hands
        /// `O'Neill` to `foundCharacters` already whole.)
        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            guard isReadingText else { return }
            cell += String(decoding: CDATABlock, as: UTF8.self)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch elementName {
            case "v", "t":
                isReadingText = false
            case "c":
                isInsideCell = false
                place(resolved(), at: column)
            case "row":
                rows.append(row)
            default:
                break
            }
        }

        /// The cell's text, once its `t` has been honoured.
        private func resolved() -> String {
            switch cellType {
            case "s":
                // An index the table cannot answer is left blank rather than guessed at. It means
                // the workbook contradicts itself, and a blank becomes a question on `8d`.
                //
                // The table is already trimmed, entry by entry, rather than each hit being
                // trimmed here: "Female" and "12" are each referenced by dozens of cells in a
                // roster, so trimming at the reference does the same work over and over.
                guard let index = Int(cell.trimmingCharacters(in: .whitespacesAndNewlines)),
                      sharedStrings.indices.contains(index)
                else { return "" }
                return sharedStrings[index]
            case "e":
                // `#N/A`, `#REF!`. A broken formula is not a value, and passing the text on would
                // put "#N/A" in somebody's surname.
                return ""
            default:
                // `inlineStr`, `str` (a formula's cached text), `b`, and the untyped numeric cell
                // all mean "what is written here".
                return cell.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        private func place(_ value: String, at index: Int) {
            if index >= row.count {
                row.append(contentsOf: repeatElement("", count: index - row.count))
                row.append(value)
            } else {
                row[index] = value
            }
        }

        /// The widest a sheet can be — `XFD`, and the format's own limit rather than a number
        /// picked here.
        ///
        /// It is a ceiling on an allocation the *file* controls, which is the only such place in
        /// this reader: a row is a dense array, so one cell claiming column `AAAAAA1` would have
        /// `place(_:at:)` pad three hundred million empty strings into it. Bounding the reference
        /// at what Excel itself can produce caps a row at 16 384 slots — a roster uses four — and
        /// a reference past it is not a column at all, so it falls back to the running position
        /// rather than being honoured.
        static let columnLimit = 16_384

        /// `"AB7"` → 27. The letters are base-26 with no zero, so `A` is 1 and `Z` is 26; one is
        /// taken off at the end to make it an array index.
        static func columnIndex(inReference reference: String) -> Int? {
            var value = 0
            for character in reference {
                guard let ascii = character.asciiValue else { break }
                // `& 0b1101_1111` folds `a`–`z` onto `A`–`Z` and leaves everything else where it
                // is, so the digits that follow the letters end the loop as they should.
                let letter = ascii & 0b1101_1111
                guard letter >= 65, letter <= 90 else { break }
                value = value * 26 + Int(letter - 64)
                guard value <= columnLimit else { return nil }
            }
            return value > 0 ? value - 1 : nil
        }
    }

    // MARK: - Reading the strings

    /// `xl/sharedStrings.xml` — one entry per `<si>`, with its runs joined, in index order.
    ///
    /// Nearly every text cell in a real workbook is `t="s"` and an index into this table — the
    /// export this was written against stores its ages that way too — so an entry dropped here
    /// would shift every name in the roster by one and produce a file that looks entirely
    /// plausible.
    private final class SharedStringParser: NSObject, XMLParserDelegate {

        /// Nil when the document is not well-formed to the end — see `rows(from:)`. A table cut
        /// short is worse than a sheet cut short: every index past the cut resolves to a blank,
        /// so the roster comes back with its names *silently missing* rather than short.
        static func strings(in data: Data) -> [String]? {
            let delegate = SharedStringParser()
            return read(data, with: delegate) ? delegate.strings : nil
        }

        private var strings: [String] = []
        private var current = ""
        private var isInsideItem = false
        private var isReadingText = false
        /// Depth of `<rPh>`, the phonetic guide a Japanese workbook carries beside a name. Its
        /// `<t>` looks exactly like the name's own, so without this a shared string comes back
        /// with its reading glued to the end of it.
        private var phoneticDepth = 0

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            switch elementName {
            case "si":
                isInsideItem = true
                current = ""
            case "rPh":
                phoneticDepth += 1
            case "t":
                isReadingText = isInsideItem && phoneticDepth == 0
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isReadingText else { return }
            current += string
        }

        /// Same reasoning as `SheetParser`'s: a shared string written as CDATA is legal and
        /// arrives nowhere else.
        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            guard isReadingText else { return }
            current += String(decoding: CDATABlock, as: UTF8.self)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch elementName {
            case "t":
                isReadingText = false
            case "rPh":
                phoneticDepth = max(0, phoneticDepth - 1)
            case "si":
                // Trimmed once, here, rather than at each of the dozens of cells that reference
                // it — and trimmed at all because the CSV reader trims every field it cuts, and
                // `IntakePlayer.issue` counts a surname's length on the promise that both
                // producers do (`IntakeRoster.swift:92-94`).
                strings.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                isInsideItem = false
            default:
                break
            }
        }
    }

    // MARK: - Reading the index

    /// `xl/workbook.xml` — the relationship id of the first `<sheet>`, in tab order.
    private final class FirstSheetParser: NSObject, XMLParserDelegate {

        static func relationshipID(in data: Data) -> String? {
            let delegate = FirstSheetParser()
            _ = read(data, with: delegate)
            return delegate.relationshipID
        }

        private var relationshipID: String?

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            // Namespace processing is off, so the attribute arrives under its qualified name.
            // Both spellings are accepted because a workbook written against a differently
            // prefixed relationships namespace is still naming the same thing.
            guard elementName == "sheet", relationshipID == nil else { return }
            relationshipID = attributes["r:id"] ?? attributes["id"]
        }
    }

    /// `xl/_rels/workbook.xml.rels` — relationship id to part path.
    private final class RelationshipParser: NSObject, XMLParserDelegate {

        static func targets(in data: Data) -> [String: String] {
            let delegate = RelationshipParser()
            _ = read(data, with: delegate)
            return delegate.targets
        }

        private var targets: [String: String] = [:]

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            guard elementName == "Relationship",
                  let id = attributes["Id"],
                  let target = attributes["Target"]
            else { return }
            targets[id] = target
        }
    }
}
