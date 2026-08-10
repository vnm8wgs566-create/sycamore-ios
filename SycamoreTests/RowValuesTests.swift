//
//  RowValuesTests.swift
//  SycamoreTests
//
//  What `RowValues` actually puts on the wire, tested through the seam `PostgRESTQueryTests`
//  already picked.
//
//  There is one thing here worth a test and it is the null. `JSONEncoder` omits a nil `Optional`
//  entirely rather than writing it, and half the writes in this repository are precisely "set
//  this column to null" — clear a coach off a court, cancel an early pick-up, take a kid out of
//  a group. `RowValues` exists to say the difference between "leave that column alone" and
//  "empty it", and until now nothing checked that it does.
//
//  The arguments below are a real payload rather than an invented one: they are what
//  `assignStaff` posts to `assign_coach_to_court`, which is the case where the stakes are
//  clearest. PostgREST resolves an RPC by the argument *names* present in the body, so a dropped
//  `court` names a two-argument function that does not exist — and *only* the unassign path
//  breaks. Putting a coach on a court still carries its `court`, still resolves, still works. A
//  regression there ships half a working feature.
//
//  This file was `CoachMoveTests` and tested a bespoke `SupabaseRepository.CoachMove` that
//  hand-wrote `encode(to:)` to do what `RowValues` already did. The struct is gone; the
//  assertions moved down onto the shared type, which is used by every write in the actor and had
//  no tests of its own.
//
//  Exact strings, for the reason the query tests give: an assertion that the body "contains
//  coach" would pass throughout the bug it is here to catch.
//

import Foundation
import Testing

@testable import Sycamore

@Suite("What RowValues puts on the wire")
struct RowValuesTests {

    /// Fixed so the expectations below can be written out rather than interpolated back from the
    /// thing under test.
    static let coach = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
    static let court = UUID(uuidString: "16D8B4EE-3E7B-4A34-9C0F-2A9C1E7D5B31")!

    /// `SupabaseCoding.encoder()` and not a fresh `JSONEncoder`: the snake-casing is part of what
    /// is being checked, and a local encoder would be testing a different one than ships.
    ///
    /// `sortedKeys` is the one addition, and it changes nothing being asserted — it fixes the key
    /// order so the whole body can be compared as a string. The three names are already in
    /// alphabetical order, so this is determinism rather than a rearrangement.
    private static func encode(_ arguments: RowValues) throws -> String {
        let encoder = SupabaseCoding.encoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(arguments), as: UTF8.self)
    }

    @Test("Putting a coach on a court names the court")
    func ontoACourt() throws {
        let body = try Self.encode(
            ["coach": .uuid(Self.coach), "court": .uuid(Self.court), "roaming": .bool(false)]
        )
        #expect(
            body == """
                {"coach":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F",\
                "court":"16D8B4EE-3E7B-4A34-9C0F-2A9C1E7D5B31",\
                "roaming":false}
                """
        )
    }

    /// The one that would break silently on the happy path. `"court":null` is present and is the
    /// whole point — an omitted key is a different function signature, not a null argument.
    @Test("Taking a coach off a court writes the null rather than dropping the key")
    func offACourt() throws {
        let body = try Self.encode(
            ["coach": .uuid(Self.coach), "court": .uuid(nil), "roaming": .bool(true)]
        )
        #expect(
            body == """
                {"coach":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F",\
                "court":null,\
                "roaming":true}
                """
        )
    }

    /// Said as its own assertion because the failure it guards against is not a wrong value but a
    /// missing key, and the test above would still read as a body-shaped string without it.
    @Test("Every argument the function declares is sent, on both moves")
    func allThreeArgumentsAreAlwaysPresent() throws {
        for court in [Self.court, nil] {
            let body = try Self.encode(
                ["coach": .uuid(Self.coach), "court": .uuid(court), "roaming": .bool(false)]
            )
            let sent = try #require(
                try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
            )
            #expect(Set(sent.keys) == ["coach", "court", "roaming"])
        }
    }
}
