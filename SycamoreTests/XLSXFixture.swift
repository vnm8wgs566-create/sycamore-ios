//
//  XLSXFixture.swift
//  SycamoreTests
//
//  Builds an `.xlsx` in memory, so the reader can be tested without a binary blob in the repo.
//
//  The alternative was to check in a sample workbook, and there are two reasons not to. The
//  obvious one: the real export this reader was written against is eighty-two children's names
//  and ages, this repository is public, and a fixture is a file you stop thinking about. The
//  less obvious one is better — a checked-in workbook is opaque. "Why does this test fail?" is
//  answerable when the ZIP and the XML are written twenty lines above the assertion, and is a
//  hex editor otherwise. Every shape the reader has to survive — a gap in the column letters, a
//  sheet that is not `sheet1.xml`, an inline string, a stored rather than deflated member — is a
//  parameter here rather than another binary.
//
//  So this writes the container as well as the parts: local headers, a central directory and an
//  end record, with the payloads deflated through `Compression` the same way `ZIPArchive`
//  inflates them. Anything the reader relies on is therefore genuinely exercised rather than
//  stubbed past.
//
//  **The CRC-32 fields are zero.** `ZIPArchive` does not check them and says so in its header, so
//  writing one here would be code no assertion depends on. It does mean these bytes are not a
//  workbook Excel would open — if the reader ever starts verifying integrity, this is the file
//  that has to start computing one.
//

import Compression
import Foundation
@testable import Sycamore

enum XLSXFixture {

    // MARK: The office's shape

    /// A roster laid out the way the real export is: **surname first**, genders spelled out in
    /// full, ages as text, and repeated surnames — two Okonjos and two Vasquezes — because that
    /// is what a school roll looks like and it is what a reader that matches columns by position
    /// would get away with on a tidier file.
    ///
    /// Invented names throughout. Nothing from the file this was checked against is in here, or
    /// anywhere else in this repository.
    static let officeRoster: [[String]] = [
        ["Last Name", "First Name", "Age", "Gender"],
        ["Okonjo", "Amara", "11", "Female"],
        ["Okonjo", "Chidi", "9", "Male"],
        ["Vasquez", "Mateo", "13", "Male"],
        ["Vasquez", "Lucia", "8", "Female"],
        ["Lindqvist", "Elin", "12", "Female"],
        ["Barrowman", "Fenwick", "7", "Male"],
    ]

    // MARK: A whole workbook

    /// An `.xlsx` holding one sheet of `rows`.
    ///
    /// - Parameters:
    ///   - rows: the grid, one array per row. A `nil` cell is **omitted from the XML entirely**,
    ///     which is what a real spreadsheet does with a blank — the row's column letters skip
    ///     from `A` to `C` and a reader that appends rather than places puts the next value in
    ///     the wrong column. An empty string writes a present-but-empty cell.
    ///   - sheetPath: where the sheet is stored inside the package. The relationship always
    ///     points at it, so a path other than `sheet1.xml` tests the resolution rather than the
    ///     fallback.
    ///   - inline: writes every cell as `t="inlineStr"` instead of into the shared string table.
    ///   - compressed: deflated members when true, stored when false.
    static func workbook(
        rows: [[String?]],
        sheetPath: String = "xl/worksheets/sheet1.xml",
        inline: Bool = false,
        compressed: Bool = true
    ) -> Data {
        var parts: [(String, String)] = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", packageRels),
            ("xl/workbook.xml", workbookXML),
            ("xl/_rels/workbook.xml.rels", workbookRels(sheetPath: sheetPath)),
        ]

        if inline {
            parts.append((sheetPath, sheetXML(rows: rows, table: nil)))
        } else {
            let table = sharedStringTable(in: rows)
            parts.append((sheetPath, sheetXML(rows: rows, table: table)))
            parts.append(("xl/sharedStrings.xml", sharedStringsXML(table)))
        }

        return archive(parts, compressed: compressed)
    }

    /// The same, for a grid with no gaps in it.
    static func workbook(
        rows: [[String]],
        sheetPath: String = "xl/worksheets/sheet1.xml",
        inline: Bool = false,
        compressed: Bool = true
    ) -> Data {
        workbook(
            rows: rows.map { $0.map { Optional($0) } },
            sheetPath: sheetPath,
            inline: inline,
            compressed: compressed
        )
    }

    // MARK: The parts

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="xml" ContentType="application/xml"/></Types>
        """

    private static let packageRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" \
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" \
        Target="xl/workbook.xml"/></Relationships>
        """

    /// The tab is named "4" on purpose: the real export names its only sheet that while storing
    /// it in `sheet1.xml`, and a reader that took the sheet's *name* for its filename would be
    /// looking for `xl/worksheets/4.xml`.
    private static let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="4" sheetId="1" r:id="rId1"/></sheets></workbook>
        """

    /// The target is relative to `xl/`, which is how a real workbook writes it.
    private static func workbookRels(sheetPath: String) -> String {
        let target = sheetPath.hasPrefix("xl/") ? String(sheetPath.dropFirst(3)) : sheetPath
        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" \
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" \
            Target="\(escaped(target))"/></Relationships>
            """
    }

    /// Every distinct cell value, in first-seen order — which is how Excel builds the table.
    private static func sharedStringTable(in rows: [[String?]]) -> [String] {
        var order: [String] = []
        var seen: Set<String> = []
        for row in rows {
            for case let value? in row where !seen.contains(value) {
                seen.insert(value)
                order.append(value)
            }
        }
        return order
    }

    private static func sharedStringsXML(_ table: [String]) -> String {
        let items = table.map { "<si><t>\(escaped($0))</t></si>" }.joined()
        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
            count="\(table.count)" uniqueCount="\(table.count)">\(items)</sst>
            """
    }

    /// - Parameter table: the shared string table to index into, or `nil` to write inline
    ///   strings instead.
    private static func sheetXML(rows: [[String?]], table: [String]?) -> String {
        let body = rows.enumerated().map { rowIndex, row in
            let cells = row.enumerated().compactMap { columnIndex, value -> String? in
                guard let value else { return nil }
                let reference = "\(columnLetters(columnIndex))\(rowIndex + 1)"
                guard let table else {
                    return "<c r=\"\(reference)\" t=\"inlineStr\"><is><t>\(escaped(value))</t></is></c>"
                }
                // A value not in the table cannot happen — the table is built from these rows —
                // but the fallback writes a blank rather than crashing a fixture.
                guard let index = table.firstIndex(of: value) else { return "<c r=\"\(reference)\"/>" }
                return "<c r=\"\(reference)\" t=\"s\"><v>\(index)</v></c>"
            }
            return "<row r=\"\(rowIndex + 1)\">\(cells.joined())</row>"
        }
        .joined()

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
            <sheetData>\(body)</sheetData></worksheet>
            """
    }

    /// A sheet whose XML the test writes itself, wrapped in a workbook. For the cell shapes a
    /// grid cannot express — a formula beside its cached value, an error cell, a number, a
    /// shared-string table that contradicts the sheet referencing it.
    ///
    /// - Parameter sharedStrings: the `<sst>` document, when the sheet's cells are `t="s"`. Left
    ///   out entirely when they are not, because a workbook whose cells are all inline genuinely
    ///   has no such part — which is itself a case the reader has to survive.
    static func workbook(sheetBody: String, sharedStrings: String? = nil) -> Data {
        let sheet = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
            <sheetData>\(sheetBody)</sheetData></worksheet>
            """
        var parts = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", packageRels),
            ("xl/workbook.xml", workbookXML),
            ("xl/_rels/workbook.xml.rels", workbookRels(sheetPath: "xl/worksheets/sheet1.xml")),
            ("xl/worksheets/sheet1.xml", sheet),
        ]
        if let sharedStrings {
            parts.append(("xl/sharedStrings.xml", sharedStrings))
        }
        return archive(parts)
    }

    // MARK: Spelling

    /// `0` → `A`, `26` → `AA`. The inverse of the reader's own base-26.
    private static func columnLetters(_ index: Int) -> String {
        var letters = ""
        var value = index + 1
        while value > 0 {
            let remainder = (value - 1) % 26
            letters = String(UnicodeScalar(UInt8(65 + remainder))) + letters
            value = (value - 1) / 26
        }
        return letters
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: The container

    /// Writes the parts into a ZIP: a local header and payload each, then the central directory
    /// the reader actually reads, then the end record.
    static func archive(_ parts: [(String, String)], compressed: Bool = true) -> Data {
        var output: [UInt8] = []
        var directory: [UInt8] = []
        let method = compressed ? ZIPArchive.Method.deflated : ZIPArchive.Method.stored

        for (name, xml) in parts {
            let plain = [UInt8](xml.utf8)
            let payload = compressed ? deflate(plain) : plain
            let nameBytes = [UInt8](name.utf8)
            let offset = output.count

            // Through `ZIPArchive`'s own constants rather than a second set of literals: a magic
            // number the writer and the reader each spell for themselves is one they can drift on.
            output += u32(ZIPArchive.Signature.localHeader)
            output += u16(20) + u16(0) + u16(method) + u16(0) + u16(0)
            output += u32(0)                                   // CRC-32 — see the header.
            output += u32(UInt32(payload.count)) + u32(UInt32(plain.count))
            output += u16(UInt16(nameBytes.count)) + u16(0)
            output += nameBytes
            output += payload

            directory += u32(ZIPArchive.Signature.centralDirectory)
            directory += u16(20) + u16(20) + u16(0) + u16(method) + u16(0) + u16(0)
            directory += u32(0)
            directory += u32(UInt32(payload.count)) + u32(UInt32(plain.count))
            directory += u16(UInt16(nameBytes.count)) + u16(0) + u16(0)
            directory += u16(0) + u16(0) + u32(0)
            directory += u32(UInt32(offset))
            directory += nameBytes
        }

        let directoryOffset = output.count
        output += directory
        output += u32(ZIPArchive.Signature.endOfCentralDirectory)
        output += u16(0) + u16(0)
        output += u16(UInt16(parts.count)) + u16(UInt16(parts.count))
        output += u32(UInt32(directory.count)) + u32(UInt32(directoryOffset))
        output += u16(0)

        return Data(output)
    }

    /// Raw DEFLATE, the same `COMPRESSION_ZLIB` the reader inflates with.
    private static func deflate(_ bytes: [UInt8]) -> [UInt8] {
        precondition(!bytes.isEmpty, "the fixture never writes an empty part")
        // Generous, because deflate is allowed to grow incompressible input.
        var destination = [UInt8](repeating: 0, count: bytes.count * 2 + 128)
        let written = destination.withUnsafeMutableBufferPointer { out in
            bytes.withUnsafeBufferPointer { input in
                compression_encode_buffer(
                    out.baseAddress!, out.count,
                    input.baseAddress!, input.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        precondition(written > 0, "the fixture's deflate produced nothing")
        return Array(destination[0..<written])
    }

    private static func u16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8)]
    }

    private static func u32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ]
    }
}
