//
//  RosterTemplate.swift
//  Sycamore
//
//  The file we would write, if we were the office.
//
//  "Tolerant format" is the decision, and the parser keeps it: headers are matched by what they
//  contain, the delimiter is sniffed, and a missing column is silence. But tolerance is invisible
//  — a person looking at a spreadsheet cannot tell whether the app will read it, and the only way
//  to find out today is to import it and see. So the card on `8c` says what a good file looks
//  like, and this is the same thing as a file you can send to whoever makes yours.
//
//  Three kids, chosen for what they demonstrate rather than to look like a roster:
//
//  - **Serene Chu** — a whole surname, which is what makes a re-import able to match by name and
//    then correct "Serene C" to "Serene Chu" a week later.
//  - **Priya Nandan** — a blank age. The commonest gap in a real sign-up list, and the row that
//    shows a blank cell is allowed rather than fatal: it lands in "Needs a detail" with a Fix
//    button and imports fine once answered.
//  - **Liam Prior** — the returning flag, which is the one column most offices do not send and
//    the one whose absence used to be read as a "no" for everybody.
//
//  Commas, because `.commaSeparatedText` is what the export declares and a comma is what the
//  sniffer falls back to. A tab or a semicolon reads identically; saying so is the card's job.
//
//  ---------------------------------------------------------------------------------------------
//  THE TEMPLATE MUST ROUND-TRIP THROUGH `IntakeFile.parse`, AND THAT IS A TEST.
//  ---------------------------------------------------------------------------------------------
//
//  This string and the card beside it are a *promise about the parser*, and nothing in the
//  compiler connects them to it. Rename a recognised column word, tighten the header sniff, change
//  what a blank cell means, and the file the app hands out stops being a file the app can read —
//  silently, and only for the people who took us at our word. `RosterTemplateTests` parses this
//  constant and asserts the three kids come back, so the drift shows up as a red test rather than
//  as a support email.
//
//  ---------------------------------------------------------------------------------------------
//  A CSV, THOUGH THE FRAME'S ROW SAYS "XLSX, FOUR COLUMNS"
//  ---------------------------------------------------------------------------------------------
//
//  `8c` labels the download `XLSX, four columns` (`design/Sycamore 3a System.dc.html`, the frame
//  captioned "Bring in the week": `Download the template` / `XLSX, four columns`). The app hands
//  over a CSV, so the row is labelled `CSV` — a button saying XLSX that shares a `.csv` is the one
//  outcome not on the table.
//
//  Writing a real `.xlsx` was considered and rejected, and not for want of effort:
//
//  - `XLSXReader` reads workbooks; `ZIPArchive` reads archives. Neither writes. An `.xlsx` would
//    need a ZIP writer (with a CRC-32, which `ZIPArchive.swift:30-34` deliberately does not even
//    *check* on the way in) plus five OOXML parts emitted by hand. That is a new subsystem, and a
//    new subsystem is not the objection.
//  - The objection is what it would be worth. This file's whole value is that **the office opens
//    it**, and the one thing no test in this repository can assert is "Excel opens it". A
//    round-trip through our own reader would prove only that we agree with ourselves; a part
//    Excel rejects for a missing relationship reads as "Sycamore sent me a broken file", and it
//    would be found by a camp administrator rather than by CI.
//  - A CSV is the format every spreadsheet on earth has opened for thirty years, and the app reads
//    it straight back. So the label moves and the file does not.
//
//  Five columns rather than the frame's four: the frame counts first, last, age and gender, and
//  this file also carries Returning — which is in it precisely because it is the column most
//  offices omit and the one whose absence used to be read as a "no" for everybody. Dropping it to
//  make the caption true would delete the demonstration to save a word.
//
//  The caption itself is *not* here. It is a literal beside the row that draws it
//  (`BringInTheWeekView.templateRow`), because screen copy belongs with the screen — a constant
//  here spelling out "CSV, five columns" would put a copy edit to one label on `8c` in a model
//  file, a folder away from every other word that screen says. What guards it instead is
//  `RosterTemplateTests`, which counts the header of this constant and fails if the number the
//  caption states stops being true.
//
//  ---------------------------------------------------------------------------------------------
//  ONE TYPE, AND `Transferable` RATHER THAN A TEMP FILE
//  ---------------------------------------------------------------------------------------------
//
//  There is no `ShareLink`, `fileExporter` or `UTType` usage anywhere under `Sycamore/` apart from
//  `BringInTheWeekView`'s importer, so the export machinery is kept to this one type rather than
//  spread across a helper and a view.
//
//  `Transferable` rather than writing a temp file and sharing its URL: a temp file needs a
//  directory, a unique name, a cleanup nobody runs, and a `URL` that is only valid for as long as
//  the share sheet is up. `DataRepresentation` hands the bytes and the filename straight to
//  `ShareLink`, which works on iOS and macOS alike with nothing on disk.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The canonical roster, and the thing `ShareLink` sends.
struct RosterTemplate: Transferable, Sendable {

    /// The file itself. `\n` throughout — the parser splits on `\.isNewline`, so a Windows reader
    /// opening this is the only thing that would notice, and every spreadsheet handles it.
    static let csv = """
        First name,Last name,Age,Gender,Returning
        Serene,Chu,13,F,Yes
        Priya,Nandan,,F,No
        Liam,Prior,12,M,Yes
        """

    /// What the office would call it, if the office asked us.
    static let fileName = "sycamore-roster-template.csv"

    /// The value a `ShareLink` is handed. A singleton rather than an initialiser, because there is
    /// exactly one template and a second instance would mean nothing.
    static let file = RosterTemplate()

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { _ in
            Data(RosterTemplate.csv.utf8)
        }
        .suggestedFileName(RosterTemplate.fileName)
    }
}
