//
//  PastedRosterTests.swift
//  SycamoreTests
//
//  A roster typed or pasted into the box on `8c`, rather than chosen as a file.
//
//  The interesting rule is the one about headers. `IntakeFile.parse(rows:named:)` refuses a
//  header-less file outright, because `Last, First` and `First, Last` are indistinguishable and a
//  positional guess imports a whole camp backwards while reading perfectly cleanly. A paste box is
//  the one place that argument does not hold: the placeholder states the order before anything is
//  typed. So the order is declared once and the same `Columns` engine reads it.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("A pasted roster")
struct PastedRosterTests {

    // MARK: The declared order

    @Test("The design's own placeholder parses")
    func thePlaceholderParses() throws {
        let file = try IntakeFile.parse(pasted: "Serene Chu, 11, F\nLiam Prior, 12, M")

        #expect(file.players.count == 2)
        #expect(file.players[0].firstName == "Serene")
        #expect(file.players[0].lastName == "Chu")
        #expect(file.players[0].age == 11)
        #expect(file.players[0].gender == .f)
        #expect(file.players[1].displayName == "Liam Prior")
        #expect(file.players[1].gender == .m)
        // Nothing on the review screen is asking about any of them.
        #expect(file.needsDetail.isEmpty)
    }

    /// The exact case the file path refuses. Refusing it here as well would make the box useless —
    /// nobody types a header row into a phone.
    @Test("No header row is needed")
    func noHeaderIsNeeded() throws {
        let file = try IntakeFile.parse(pasted: "Ara Demir, 9, F")

        #expect(file.players.count == 1)
        #expect(file.players[0].firstName == "Ara")
    }

    /// And a file still refuses one, which is the half that must not have moved.
    @Test("A file with no header is still refused")
    func aFileStillRefusesOne() {
        #expect(throws: IntakeFile.ReadError.noHeaderRow) {
            try IntakeFile.parse("Ara Demir, 9, F", named: "sign-ups.csv")
        }
    }

    /// Somebody selecting a spreadsheet range including row 1 gets that header read, not ignored —
    /// which is what keeps a surname-first paste from being read backwards.
    @Test("A paste that carries its own header is read by it")
    func aCarriedHeaderWins() throws {
        let file = try IntakeFile.parse(
            pasted: "Last Name, First Name, Age\nDemir, Ara, 9"
        )

        #expect(file.players.count == 1)
        #expect(file.players[0].firstName == "Ara")
        #expect(file.players[0].lastName == "Demir")
    }

    // MARK: What the box tolerates

    @Test("Blank lines between names are not kids")
    func blankLinesAreNotKids() throws {
        let file = try IntakeFile.parse(pasted: "Ara Demir, 9, F\n\n\nTom Hale, 10, M\n")

        #expect(file.players.count == 2)
    }

    /// The delimiter is sniffed for a paste exactly as it is for a file, so a block copied out of a
    /// spreadsheet — which arrives tab-separated — reads without anybody being told to convert it.
    @Test("A tab-separated paste reads")
    func tabsRead() throws {
        let file = try IntakeFile.parse(pasted: "Ara Demir\t9\tF\nTom Hale\t10\tM")

        #expect(file.players.count == 2)
        #expect(file.players[0].age == 9)
        #expect(file.players[1].gender == .m)
    }

    /// A name and nothing else is a kid with a gap, which is a row on the review screen beside a
    /// Fix button — not a refusal, and not an invented age.
    @Test("A bare list of names imports with the gaps showing")
    func namesAloneKeepTheirGaps() throws {
        let file = try IntakeFile.parse(pasted: "Ara Demir\nTom Hale")

        #expect(file.players.count == 2)
        #expect(file.needsDetail.count == 2)
        #expect(file.players[0].issue == .noAge)
    }

    @Test("An empty box is refused rather than imported as nobody")
    func emptyIsRefused() {
        #expect(throws: IntakeFile.ReadError.nothingToImport) {
            try IntakeFile.parse(pasted: "   \n\n  ")
        }
    }

    // MARK: The count on the button

    /// The button's whole feedback loop: a person pasting twelve lines and reading "Add 11 kids"
    /// has been told about the blank one before they commit to anything.
    @Test("The count is what would actually be imported")
    func theCountMatches() {
        #expect(IntakeFile.pastedCount("Ara Demir, 9, F\nTom Hale, 10, M") == 2)
        #expect(IntakeFile.pastedCount("Ara Demir, 9, F\n\nTom Hale, 10, M\n") == 2)
    }

    /// It runs on every keystroke, where a half-typed line is the normal state — so it answers 0
    /// rather than throwing at somebody who is still typing.
    @Test("A half-typed box counts zero rather than complaining")
    func partialCountsZero() {
        #expect(IntakeFile.pastedCount("") == 0)
        #expect(IntakeFile.pastedCount("   ") == 0)
        #expect(IntakeFile.pastedCount("\n\n") == 0)
    }

    // MARK: Where it says it came from

    /// The review screen leads with "From sign-ups.csv"; a paste has no file to name, and this is
    /// the only line on that screen saying where forty names came from.
    @Test("The review screen names the paste rather than a file")
    func theSubtitleNamesThePaste() throws {
        let file = try IntakeFile.parse(pasted: "Ara Demir, 9, F")

        #expect(file.fileName == IntakeFile.pastedName)
        #expect(file.subtitle.contains("the pasted list"))
    }
}
