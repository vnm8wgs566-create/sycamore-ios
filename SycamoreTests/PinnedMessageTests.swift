//
//  PinnedMessageTests.swift
//  SycamoreTests
//
//  `inbox_items.title text not null check (char_length(title) between 1 and 120)`.
//
//  The pinned composer writes the reader's sentence straight into that column, so the rule that
//  decides whether the "Pin" button appears has to be the column's own rule. Get it wrong in the
//  generous direction and an over-long message passes every gate on the device and fails at
//  `insert`, after the keyboard has gone down.
//
//  These are the tests for the rule, not for the composer. `PinnedMessage.isValid` is pure and
//  the composer's button, its return key and its warning line all read it, so pinning it here
//  pins all three.
//
//  Modelled on `CampNameTests`, including the case that proves scalars matter.
//

import Testing
@testable import Sycamore

@Suite("PinnedMessage")
struct PinnedMessageTests {

    @Test("Refuses a message the column would refuse")
    func rejectsOutOfRange() {
        #expect(!PinnedMessage.isValid(""))
        #expect(!PinnedMessage.isValid(String(repeating: "a", count: 121)))
    }

    @Test("Accepts both ends of the range the column allows")
    func acceptsBounds() {
        #expect(PinnedMessage.isValid("a"))
        #expect(PinnedMessage.isValid(String(repeating: "a", count: 120)))
        #expect(PinnedMessage.isValid("Court 4 net is loose — keep the little ones off it."))
    }

    /// The reason the count is in unicode scalars and not `String.count`.
    ///
    /// Postgres' `char_length` counts characters of the UTF-8 string; Swift's `count` counts
    /// grapheme clusters, and one cluster can be many scalars. Counted the way Swift reads a
    /// string, a hundred family emoji are "100 characters" and sail through — then land on a
    /// column that sees several hundred and refuses them.
    @Test("Counts the way Postgres counts, not the way Swift reads")
    func countsScalars() {
        let family = "👩‍👩‍👧"
        #expect(family.count == 1)
        #expect(family.unicodeScalars.count > 1)

        // Comfortably inside 120 `Character`s, comfortably outside 120 scalars.
        let manyFamilies = String(repeating: family, count: 30)
        #expect(manyFamilies.count == 30)
        #expect(!PinnedMessage.isValid(manyFamilies))
    }

    /// `isValid` measures the trimmed value and the composer stores the trimmed value, so the
    /// string that passed the gate is the string that reaches the column.
    @Test("A draft is judged on what will actually be stored")
    func judgesTheStoredString() {
        #expect(!PinnedMessage.isValid(PinnedMessage.trimmed("   ")))

        let padded = "  Court 4 net is loose  "
        #expect(PinnedMessage.trimmed(padded) == "Court 4 net is loose")
        #expect(PinnedMessage.isValid(PinnedMessage.trimmed(padded)))

        // 119 characters plus two spaces: over the limit as typed, inside it as stored.
        let atTheEdge = " \(String(repeating: "a", count: 119)) "
        #expect(atTheEdge.count == 121)
        #expect(PinnedMessage.isValid(PinnedMessage.trimmed(atTheEdge)))
    }

    /// A pasted return is the one way a newline reaches a single-line field, and a message that
    /// is only a newline is not a message.
    @Test("Trims newlines as well as spaces")
    func trimsNewlines() {
        #expect(!PinnedMessage.isValid(PinnedMessage.trimmed("\n")))
        #expect(PinnedMessage.trimmed("\n Shade tent is up \n") == "Shade tent is up")
    }

    /// The number the composer prints under the field. It is asked of the *trimmed* string, so
    /// trailing spaces are never counted against a reader who is being told what to cut.
    @Test("Reports how far past the limit a draft is")
    func reportsOverrun() {
        #expect(PinnedMessage.overrun("") == 0)
        #expect(PinnedMessage.overrun(String(repeating: "a", count: 120)) == 0)
        #expect(PinnedMessage.overrun(String(repeating: "a", count: 123)) == 3)

        // Seven scalars to the cluster, so one emoji past the line is seven characters past it —
        // which is what the column will say too.
        let overByEmoji = String(repeating: "a", count: 120) + "👩‍👩‍👧"
        #expect(PinnedMessage.overrun(overByEmoji) == "👩‍👩‍👧".unicodeScalars.count)
    }
}
