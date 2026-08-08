//
//  GenderStringsTests.swift
//  SycamoreTests
//
//  `Gender` had five display spellings across four files — `F`/`M`/`X`, `Girl`/`Boy`/`Prefer not
//  to say`, `Girl`/`Boy`/`Gender not recorded`, `Female`/`Male`/`Unspecified`, `Girl`/`Boy`/`Kid`
//  — and every one of them was private to the screen that wrote it. The third case disagreed with
//  itself four ways: a chip on `8e` accepted the answer as a choice and the roster row beside it
//  read the same kid back as an absence.
//
//  Three strings now, all on the model. The tests below are the two that can regress silently:
//  the raw values, which Postgres and `Codable` both ride and which no screen ever shows, and the
//  agreement between the answer a reader taps and the words VoiceOver reads back to them.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("Gender raw values")
struct GenderRawValueTests {

    @Test("The raw values are the lower-cased letters the column stores upper-cased")
    func rawValues() {
        #expect(Gender.f.rawValue == "f")
        #expect(Gender.m.rawValue == "m")
        #expect(Gender.x.rawValue == "x")
    }

    @Test("`symbol` is the raw value upper-cased, which is what the write path sends")
    func symbolMatchesTheColumn() {
        for gender in Gender.allCases {
            #expect(gender.symbol == gender.rawValue.uppercased())
        }
    }

    @Test("Round-trips through the column's spelling, the way the read path does it")
    func roundTripsThroughPostgres() {
        for gender in Gender.allCases {
            #expect(Gender(rawValue: gender.symbol.lowercased()) == gender)
        }
    }
}

@Suite("Gender display strings")
struct GenderDisplayStringTests {

    @Test("`8e` offers the answer the roster row reads back — the same string, both directions")
    func theChipAndTheReadbackAgree() {
        // The chip's title and the mark's accessibility label are one property, so this cannot
        // drift; the test is here to fail loudly if somebody splits them again.
        #expect(Gender.intakeOptions.map(\.label) == ["Girl", "Boy", "Other"])
    }

    @Test("`.x` says the answer, not the absence")
    func theThirdAnswerIsAffirmative() {
        // `.x` means both "chose the third chip" and "the file's column was blank" —
        // `IntakePlayer.asPlayer()` coerces `gender ?? .x`. The strings pick the first reading,
        // because the second is already modelled by `IntakePlayer.gender` being optional.
        #expect(Gender.x.label == "Other")
        #expect(Gender.x.noun == "Kid")
    }

    @Test("`noun` reads as a sentence about one kid, `label` as an answer to a question")
    func nounAndLabelDivergeOnlyOnTheThirdCase() {
        #expect(Gender.f.noun == Gender.f.label)
        #expect(Gender.m.noun == Gender.m.label)
        #expect(Gender.x.noun != Gender.x.label)
    }

    @Test("Every case has all three strings, and none of them is a letter twice")
    func allThreeCasesAreDistinct() {
        #expect(Set(Gender.allCases.map(\.symbol)).count == Gender.allCases.count)
        #expect(Set(Gender.allCases.map(\.label)).count == Gender.allCases.count)
        #expect(Set(Gender.allCases.map(\.noun)).count == Gender.allCases.count)
    }
}

@Suite("Gender, read out of a file")
struct GenderFileValueTests {

    @Test("The spellings an office writes for the third column all land on `.x`")
    func thirdAnswerSpellings() {
        for cell in ["X", "other", "Other", "non-binary", "prefer not to say", "N/A"] {
            #expect(Gender(fileValue: cell) == .x, "\(cell)")
        }
    }

    @Test("A cell it cannot read stays nil, so `8d` asks rather than guesses")
    func unreadableCellsStayNil() {
        for cell in ["", "   ", "42", "?"] {
            #expect(Gender(fileValue: cell) == nil, "\(cell)")
        }
    }
}
