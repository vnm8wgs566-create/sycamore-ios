//
//  RosterFileFormat.swift
//  Sycamore
//
//  What a sign-up list is allowed to arrive as — said once, for the picker and for the chips.
//
//  `8c` draws the accepted formats as chips on the drop plate, above the button that opens the
//  picker. That is a promise made *before* the tap, and the whole argument of that screen is that a
//  promise the next screen refuses is the worst way to learn a limit: `BringInTheWeekView`'s
//  `.fileImporter` greys a PDF out rather than accepting one and failing, precisely so nobody
//  discovers the rule by being turned away.
//
//  Which means the chips and `allowedContentTypes` have to agree, and until this type existed they
//  agreed *because a comment said so*. That is the wrong guarantee for this particular pair, and
//  the drift is silent in the dangerous direction — a picker that accepts more than the chips
//  advertise inconveniences nobody and is never noticed, while a chip that promises more than the
//  picker accepts is found by the one person whose office only sends that format, at the moment
//  they are refused. So both are projections of this list and neither is written out.
//
//  ---------------------------------------------------------------------------------------------
//  TWO CASES, BECAUSE THERE ARE TWO READERS
//  ---------------------------------------------------------------------------------------------
//
//  Not one case per `UTType`. `IntakeFile.parse(_:named:)` branches exactly twice — a workbook
//  through `XLSXReader`, or UTF-8 separated text — so a case here is a *reader*, and the three text
//  types are three spellings of the one that reads them. That is also why the labels cannot be
//  derived from `UTType.localizedDescription`, which would offer "comma-separated values",
//  "tab-separated values" and "plain text" as three chips for one reader, in the system's words
//  rather than the design's.
//
//  **Deliberately no PDF.** Its text needs extracting server-side and there is no server, so it is
//  absent here and therefore absent from both the picker and the plate — which is the point of the
//  type. Adding the case is what turns a PDF on, in one place, once there is something to read it
//  with. The design's frame draws the chip already (`design/Sycamore 3a System.dc.html`, the frame
//  badged `8c`: `XLSX` · `CSV` · `PDF`); the app draws two, and will draw three the day the third
//  is true.
//
//  The failure messages in `IntakeRoster` and `XLSXReader` name these formats again in prose. They
//  are deliberately left alone: those are sentences a person reads *after* a file has been refused,
//  written to say what to do next, and they are not the promise this type exists to keep.
//

import Foundation
import UniformTypeIdentifiers

/// One kind of file the app can read a roster out of.
enum RosterFileFormat: CaseIterable, Sendable {

    /// An Excel export, read by `XLSXReader`. First because it is what most offices actually send,
    /// and because the design puts it first.
    case excel
    /// Comma, tab or semicolon separated text. One case rather than three: the delimiter is
    /// sniffed rather than declared (`IntakeFile.separator(in:)`), so all three reach one reader.
    case separatedText

    /// What the chip on `8c` says.
    var label: String {
        switch self {
        case .excel: "XLSX"
        case .separatedText: "CSV"
        }
    }

    /// What VoiceOver says instead. "XLSX" is read letter by letter and "CSV" is a word people say
    /// out loud, so only the first needs a spoken form — and the spoken form of a file format is
    /// the name of the thing that writes it.
    var spokenName: String {
        switch self {
        case .excel: "Excel"
        case .separatedText: "CSV"
        }
    }

    /// The types the document browser should leave selectable.
    ///
    /// `.plainText` earns its place beside the two separated-text types: an export saved as `.txt`,
    /// and the type a great many mail attachments arrive declared as.
    var contentTypes: [UTType] {
        switch self {
        // The narrow `UTType.xlsx` rather than the broad `.spreadsheet`; see that token for why.
        case .excel: [.xlsx]
        case .separatedText: [.commaSeparatedText, .tabSeparatedText, .plainText]
        }
    }

    /// Everything the picker may offer, in one array for `.fileImporter`.
    static let allowedContentTypes: [UTType] = allCases.flatMap(\.contentTypes)

    /// "Excel and CSV" — the chips as one spoken phrase.
    ///
    /// Through `ListFormatStyle` rather than joined by hand, so a third format reads "Excel, CSV
    /// and PDF" with the comma and the conjunction the reader's language puts there.
    static var spokenNames: String {
        allCases.map(\.spokenName).formatted(.list(type: .and))
    }
}
