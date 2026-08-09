//
//  RosterTemplateTests.swift
//  SycamoreTests
//
//  The file the app hands out has to be a file the app can read.
//
//  `RosterTemplate` is a promise about the parser made in a string constant, and nothing in the
//  compiler connects the two. Rename a recognised column word, tighten the header sniff, decide a
//  blank cell means something else — and the template goes on compiling while quietly ceasing to
//  work, for exactly the people who took us at our word and sent it to their office.
//
//  So the template is parsed here, and the three kids are asserted one field at a time. Each of
//  them is in the file to demonstrate something, and the assertions are written as those
//  demonstrations rather than as "row 2 equals row 2": a whole surname, a blank age that survives
//  as a gap rather than a zero, and a returning column read both ways.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("The roster template is a file the parser reads")
struct RosterTemplateTests {

    private func parsed() throws -> [IntakePlayer] {
        try IntakeFile.parse(RosterTemplate.csv, named: RosterTemplate.fileName).players
    }

    @Test("Three kids come back, and the header row is not one of them")
    func rowCount() throws {
        #expect(try parsed().count == 3)
    }

    @Test("The whole surname survives, which is what a re-import matches on")
    func wholeSurname() throws {
        let serene = try #require(parsed().first)
        #expect(serene.firstName == "Serene")
        #expect(serene.lastName == "Chu")
        #expect(serene.displayName == "Serene Chu")
    }

    @Test("A blank age cell stays a gap rather than becoming a zero")
    func blankAge() throws {
        let priya = try #require(parsed().dropFirst().first)
        #expect(priya.firstName == "Priya")
        #expect(priya.age == nil)
        // Which is the whole reason the row is in the template: it lands on the review screen with
        // a Fix button rather than failing the import.
        #expect(priya.issue == .noAge)
    }

    @Test("The returning column is read both ways, so the file demonstrates a yes and a no")
    func returning() throws {
        let rows = try parsed()
        #expect(rows.map(\.isReturning) == [true, false, true])
    }

    @Test("Ages and genders come across as the template writes them")
    func agesAndGenders() throws {
        let rows = try parsed()
        #expect(rows.map(\.age) == [13, nil, 12])
        #expect(rows.map(\.gender) == [.f, .f, .m])
    }

    /// The two rows the card promises are clean have to actually be clean, or the example is
    /// teaching somebody to send a file that lands in "Needs a detail".
    @Test("Only the deliberately blank age is an issue; the other two rows read cleanly")
    func onlyOneGap() throws {
        #expect(try parsed().filter { $0.issue != nil }.count == 1)
    }

    /// The card beside the template says a file may be commas, tabs or semicolons. That claim is
    /// the sniffer's, so it is worth reading the same three kids out of all three spellings.
    @Test("The same three kids come back whichever delimiter the office's spreadsheet writes",
          arguments: [",", "\t", ";"])
    func anyDelimiter(separator: String) throws {
        let rewritten = RosterTemplate.csv.replacingOccurrences(of: ",", with: separator)
        let rows = try IntakeFile.parse(rewritten, named: "office-export").players

        #expect(rows.map(\.displayName) == ["Serene Chu", "Priya Nandan", "Liam Prior"])
        #expect(rows.map(\.age) == [13, nil, 12])
    }

    /// The other half of the same claim: the header is matched by what it says, not where it sits.
    @Test("Shuffling the columns changes nothing, because the header is read rather than counted")
    func anyOrder() throws {
        let shuffled = """
            Returning,Age,Gender,Last name,First name
            Yes,13,F,Chu,Serene
            No,,F,Nandan,Priya
            Yes,12,M,Prior,Liam
            """
        let rows = try IntakeFile.parse(shuffled, named: "office-export.csv").players

        #expect(rows.map(\.displayName) == ["Serene Chu", "Priya Nandan", "Liam Prior"])
        #expect(rows.map(\.age) == [13, nil, 12])
        #expect(rows.map(\.isReturning) == [true, false, true])
    }
}
