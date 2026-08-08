//
//  CampShapeTests.swift
//  SycamoreTests
//
//  A venue's emoji is chosen on "Shape the camp", but the camp is not created there — the flow
//  creates it at the end from `CampDraft`, which has no room for a per-venue anything. So the
//  choice survives only because `CampShape.venue(applying:)` writes it back over the value
//  `Camp.make(from:)` seeded from the venue's position, on the same round trip that corrects the
//  court counts.
//
//  That is a long enough path that "the tile draws the chosen emoji" and "the venue keeps the
//  chosen emoji" are two different claims. These pin the second one, which no screen can show.
//

import Testing
@testable import Sycamore

@Suite("CampShape")
struct CampShapeTests {

    /// The seed. `Camp.make(from:)` walks `Venue.iconOptions` by venue index and this screen has
    /// to walk it the same way, or a camp saved without opening the icon menu would be redrawn
    /// the moment it was created.
    @Test("Seeds the rotation the camp would have seeded, and tints follow it")
    func seedsTheSameRotation() {
        let shape = CampShape.initial(venueCount: 3, courts: 6)

        #expect(shape.venues.map(\.icon) == Array(Venue.iconOptions.prefix(3)))
        for venue in shape.venues {
            #expect(venue.tint == .suggested(for: venue.icon))
        }
    }

    /// The claim the whole unit rests on: a venue created from the draft carries the emoji picked
    /// on the row, not the one its position implies.
    @Test("A chosen emoji reaches the created venue")
    func choosingWritesThroughToTheVenue() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)

        // All the tile's menu writes. The tint is computed, so it cannot be left behind.
        shape.venues[0].icon = "🌊"
        #expect(shape.venues[0].tint == .sky)

        var draft = CampDraft()
        draft.name = "UCLA Tennis Camp"
        let camp = Camp.make(from: shape.applied(to: draft), inviteCode: "SYC-0001")

        // The seed is the position's emoji, which is exactly what has to be overwritten.
        #expect(camp.orderedVenues[0].icon == Venue.iconOptions[0])

        let updated = shape.venue(applying: 0, to: camp.orderedVenues[0])
        #expect(updated?.icon == "🌊")
        #expect(updated?.tint == .sky)

        // And the venue nobody touched is left on its seeded pair rather than dragged along.
        let untouched = shape.venue(applying: 1, to: camp.orderedVenues[1])
        #expect(untouched?.icon == Venue.iconOptions[1])
        #expect(untouched?.tint == .suggested(for: Venue.iconOptions[1]))
    }

    /// `applyShape` sends nothing when a venue already agrees with its row. Carrying two more
    /// fields must not turn that into a write on every venue on every run.
    @Test("Applying twice sends nothing the second time")
    func secondApplicationIsSilent() throws {
        var shape = CampShape.initial(venueCount: 1, courts: 4)
        shape.venues[0].icon = "🔥"

        var draft = CampDraft()
        draft.name = "UCLA Tennis Camp"
        let camp = Camp.make(from: shape.applied(to: draft), inviteCode: "SYC-0001")

        let first = try #require(shape.venue(applying: 0, to: camp.orderedVenues[0]))
        #expect(first.icon == "🔥")
        #expect(shape.venue(applying: 0, to: first) == nil)
    }

    /// Names are positional and renumber; emoji are chosen and do not. Removing the first of
    /// three rows used to re-derive every tint from the new index, which would now quietly undo
    /// a choice made two taps earlier.
    @Test("Removing a row renumbers the names and leaves the emoji alone")
    func removalKeepsChosenIcons() {
        var shape = CampShape.initial(venueCount: 3, courts: 6)
        shape.venues[2].icon = "🌊"

        let removed = shape.venues[0].id
        shape.removeVenue(removed)

        #expect(shape.venues.map(\.name) == ["Venue 1", "Venue 2"])
        #expect(shape.venues[0].icon == Venue.iconOptions[1])
        #expect(shape.venues[1].icon == "🌊")
        #expect(shape.venues[1].tint == .sky)
    }

    /// The floor holds: one venue is the fewest a camp can have, so the last row refuses to go.
    @Test("The last row cannot be removed")
    func keepsTheLastRow() {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.removeVenue(shape.venues[0].id)
        #expect(shape.venues.count == 1)
    }
}
