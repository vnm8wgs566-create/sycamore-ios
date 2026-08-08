//
//  CampNameTests.swift
//  SycamoreTests
//
//  `camps.name text not null check (char_length(name) between 1 and 80)`.
//
//  The upper bound had no client guard at all: "Shape the camp" and Setup's rename each tested
//  for empty and neither for long, so an over-long name passed every gate on the device and
//  failed at `insert` — and because the camp is not written until the end of onboarding, it
//  failed after the whole import flow rather than at the field that caused it.
//
//  These are the tests for the rule, not for the screens. `CampName.isValid` is pure and both
//  screens call it now, so pinning it here pins both.
//

import Testing
@testable import Sycamore

@Suite("CampName")
struct CampNameTests {

    @Test("Refuses a name the column would refuse")
    func rejectsOutOfRange() {
        #expect(!CampName.isValid(""))
        #expect(!CampName.isValid(String(repeating: "a", count: 81)))
    }

    @Test("Accepts both ends of the range the column allows")
    func acceptsBounds() {
        #expect(CampName.isValid("a"))
        #expect(CampName.isValid(String(repeating: "a", count: 80)))
        #expect(CampName.isValid("UCLA Tennis Camp"))
    }

    /// The reason the count is in unicode scalars and not `String.count`.
    ///
    /// Postgres' `char_length` counts characters of the UTF-8 string; Swift's `count` counts
    /// grapheme clusters, and one cluster can be many scalars. Counted the way Swift reads a
    /// string, eighty family emoji are "80 characters" and sail through — then land on a column
    /// that sees several hundred and refuses them.
    @Test("Counts the way Postgres counts, not the way Swift reads")
    func countsScalars() {
        let family = "👩‍👩‍👧"
        #expect(family.count == 1)
        #expect(family.unicodeScalars.count > 1)

        // Comfortably inside 80 `Character`s, comfortably outside 80 scalars.
        let manyFamilies = String(repeating: family, count: 20)
        #expect(manyFamilies.count == 20)
        #expect(!CampName.isValid(manyFamilies))
    }

    /// `isValid` measures the trimmed value and `Camp.make` stores the trimmed value, so the
    /// string that passed the gate is the string that reaches the column.
    @Test("A draft is judged on what will actually be stored")
    func judgesTheStoredString() {
        var draft = CampDraft()

        draft.name = "   "
        #expect(!draft.isValid)

        draft.name = "  UCLA Tennis Camp  "
        #expect(draft.isValid)
        #expect(draft.trimmedName == "UCLA Tennis Camp")
        #expect(Camp.make(from: draft, inviteCode: "SYC-0001").name == "UCLA Tennis Camp")

        // 78 characters plus two spaces: over the limit as typed, inside it as stored.
        draft.name = " \(String(repeating: "a", count: 79)) "
        #expect(draft.name.count == 81)
        #expect(draft.isValid)
    }
}
