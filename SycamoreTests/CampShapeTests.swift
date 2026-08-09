//
//  CampShapeTests.swift
//  SycamoreTests
//
//  A venue's name, subtitle, emoji, ceiling and floor are all chosen on "Shape the camp", but the
//  camp is not created there — the flow creates it at the end from `CampDraft`, which has no room
//  for a per-venue anything. So every one of those choices survives only because
//  `CampShape.venue(applying:)` writes it back over the value `Camp.make(from:)` seeded from the
//  venue's position, on the same round trip that corrects the court counts.
//
//  That is a long enough path that "the editor draws the typed name" and "the venue keeps the
//  typed name" are two different claims. These pin the second one, which no screen can show.
//
//  Two more things are pinned here because nothing else can reach them. The first is
//  `sites_ranges_ordered` — `check (coach_min <= coach_max and player_min <= player_max)` — which
//  fails at `insert`, after the whole onboarding flow has been walked, and so must hold by
//  construction rather than by test. The corner cases below are what "by construction" means.
//  The second is that a name somebody typed survives a removal, which used to renumber everything
//  it could reach.
//

import Testing
@testable import Sycamore

@Suite("CampShape")
struct CampShapeTests {

    /// The seed. `Camp.make(from:)` walks `Venue.iconOptions` by venue index and this screen has
    /// to walk it the same way, or a camp saved without opening the editor would be redrawn
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
    /// in the editor, not the one its position implies.
    @Test("A chosen emoji reaches the created venue")
    func choosingWritesThroughToTheVenue() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)

        // All the icon grid writes. The tint is computed, so it cannot be left behind.
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

    /// `applyShape` sends nothing when a venue already agrees with its row. Carrying four more
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
        #expect(first.playerMax == 32)
        #expect(first.coachMin == 4)
        #expect(first.name == "Venue 1")
        #expect(shape.venue(applying: 0, to: first) == nil)
    }

    /// The regression this whole change could most easily cause. A name, a subtitle and two head
    /// counts all reach the venue through `venue(applying:)`; if any of them were not a pure
    /// function of the row — a trim applied to the wrong side, a `coachMax` built from `existing`
    /// — the second pass would differ from the first and camp creation would write once per venue
    /// for ever.
    @Test("Applying twice sends nothing the second time, with a name and two numbers on the row")
    func secondApplicationIsSilentWithEverythingSet() throws {
        var shape = CampShape.initial(venueCount: 2, courts: 6)
        shape.venues[0].name = "  Main Courts  "
        shape.venues[0].subtitle = "  Higher level  "
        shape.venues[0].icon = "🌊"
        shape.venues[0].maxKids = 41
        shape.venues[0].minCoaches = 3

        var draft = CampDraft()
        draft.name = "UCLA Tennis Camp"
        let camp = Camp.make(from: shape.applied(to: draft), inviteCode: "SYC-0001")

        let first = try #require(shape.venue(applying: 0, to: camp.orderedVenues[0]))
        #expect(shape.venue(applying: 0, to: first) == nil)

        let second = try #require(shape.venue(applying: 1, to: camp.orderedVenues[1]))
        #expect(shape.venue(applying: 1, to: second) == nil)
    }

    // MARK: - Names

    /// Names nobody typed are positional and renumber; names somebody typed do not, and neither do
    /// the emoji. Removing the first of three rows used to rewrite every name it could reach.
    @Test("Removing a row renumbers the names nobody has typed")
    func removalKeepsTypedNamesAndChosenIcons() {
        var shape = CampShape.initial(venueCount: 3, courts: 6)
        shape.venues[1].name = "Main Courts"
        shape.venues[2].icon = "🌊"

        let removed = shape.venues[0].id
        shape.removeVenue(removed)

        // "Main Courts" is venue one now and keeps its name; the row behind it takes venue two's
        // number, which is its absolute position in the camp.
        #expect(shape.venues.map(\.name) == ["Main Courts", "Venue 2"])
        #expect(shape.venues[0].icon == Venue.iconOptions[1])
        #expect(shape.venues[1].icon == "🌊")
        #expect(shape.venues[1].tint == .sky)
    }

    @Test("A venue named by hand keeps its name through every removal")
    func typedNamesSurviveEveryRemoval() {
        var shape = CampShape.initial(venueCount: 4, courts: 6)
        shape.venues[2].name = "Main Courts"

        shape.removeVenue(shape.venues[0].id)
        #expect(shape.venues.map(\.name) == ["Venue 1", "Main Courts", "Venue 3"])

        shape.removeVenue(shape.venues[0].id)
        #expect(shape.venues.map(\.name) == ["Main Courts", "Venue 2"])

        shape.removeVenue(shape.venues[1].id)
        #expect(shape.venues.map(\.name) == ["Main Courts"])
    }

    @Test("A venue nobody named takes the number of its place in the camp")
    func positionalNamesCountAbsolutePosition() {
        var shape = CampShape.initial(venueCount: 3, courts: 6)
        shape.venues[0].name = "Main Courts"

        // Nothing moved, so nothing renumbers: Main Courts *is* venue one.
        shape.removeVenue(shape.venues[2].id)
        #expect(shape.venues.map(\.name) == ["Main Courts", "Venue 2"])

        // And the next row takes the number of the place it lands in, not the next free ordinal
        // among the positional rows.
        shape.addVenue()
        #expect(shape.venues.map(\.name) == ["Main Courts", "Venue 2", "Venue 3"])
    }

    @Test("Removing a row from a camp where nothing was named renumbers all of it, as before")
    func untouchedCampStillRenumbersEverything() {
        var shape = CampShape.initial(venueCount: 3, courts: 6)

        shape.removeVenue(shape.venues[0].id)

        #expect(shape.venues.map(\.name) == ["Venue 1", "Venue 2"])
    }

    @Test("Venue 3 is one of ours; Court 3, Venue A and Venue are not")
    func recognisesOnlyItsOwnNumbering() {
        #expect(CampShape.isPositionalName("Venue 3"))
        #expect(CampShape.isPositionalName("venue 3"))
        #expect(CampShape.isPositionalName("  VENUE   12  "))

        #expect(!CampShape.isPositionalName("Court 4"))
        #expect(!CampShape.isPositionalName("Venue A"))
        #expect(!CampShape.isPositionalName("Venue"))
        #expect(!CampShape.isPositionalName("Venue 3a"))
        #expect(!CampShape.isPositionalName("Venue3"))
        #expect(!CampShape.isPositionalName("Main Courts"))
    }

    @Test("A name is free when nobody else has it, whatever the case or the spacing")
    func namesCollideByEarRatherThanByBytes() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)
        shape.venues[0].name = "Main Courts"

        let second = shape.venues[1].id
        #expect(!shape.isVenueNameAvailable("Main Courts", excluding: second))
        #expect(!shape.isVenueNameAvailable("main courts", excluding: second))
        #expect(!shape.isVenueNameAvailable("MAIN COURTS", excluding: second))
        #expect(shape.isVenueNameAvailable("The Annexe", excluding: second))

        // A row never collides with itself, or nothing could be saved without being renamed.
        #expect(shape.isVenueNameAvailable("Main Courts", excluding: shape.venues[0].id))
    }

    @Test("A typed name reaches the created venue, and so does a typed subtitle")
    func typedNameAndSubtitleReachTheVenue() throws {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.venues[0].name = "  Main Courts  "
        shape.venues[0].subtitle = "  Higher level  "

        let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))

        #expect(updated.name == "Main Courts")
        #expect(updated.subtitle == "Higher level")
    }

    @Test("An empty subtitle reaches the venue as nothing rather than as an empty string")
    func blankSubtitleBecomesNil() throws {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.venues[0].subtitle = "   "

        // `#require` rather than an optional comparison: nil would satisfy `?.subtitle == nil`
        // without the trim ever having run.
        let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))

        #expect(updated.subtitle == nil)
    }

    // MARK: - Limits

    @Test("A venue's own ceiling and floor reach the created venue")
    func ownLimitsReachTheVenue() throws {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.venues[0].maxKids = 41
        shape.venues[0].minCoaches = 3

        let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))

        #expect(updated.playerMax == 41)
        #expect(updated.coachMin == 3)
    }

    @Test("Coaches, most is always one more than coaches, fewest")
    func coachMaxIsAlwaysOneOver() throws {
        for floor in [0, 1, 7, CampShape.venueCoachRange.upperBound] {
            var shape = CampShape.initial(venueCount: 1, courts: 6)
            shape.venues[0].minCoaches = floor

            let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))
            #expect(updated.coachMax == updated.coachMin + CampShape.coachSlack)
        }
    }

    @Test("The floor on kids is always zero, whatever the ceiling")
    func playerMinIsAlwaysZero() throws {
        for ceiling in [0, 1, 200, CampShape.venueKidsRange.upperBound] {
            var shape = CampShape.initial(venueCount: 1, courts: 6)
            shape.venues[0].maxKids = ceiling

            let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))
            #expect(updated.playerMin == 0)
        }
    }

    @Test("A ceiling past what the screen can describe is clamped rather than sent")
    func ceilingIsClamped() throws {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.venues[0].maxKids = 10_000

        let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))

        #expect(updated.playerMax == CampShape.venueKidsRange.upperBound)
        #expect(updated.playerMax == 384)
    }

    @Test("A floor below zero is clamped rather than sent")
    func floorIsClamped() throws {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.venues[0].minCoaches = -12

        let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))

        #expect(updated.coachMin == 0)
        #expect(updated.coachMax == CampShape.coachSlack)
    }

    /// `sites_ranges_ordered` fires at `insert`, which on this path is after the entire onboarding
    /// flow. It cannot be allowed to fire at all, so both halves are checked at every corner of
    /// both ranges and a little way outside them.
    @Test("Both ordered checks hold for every corner of both ranges")
    func orderedChecksHoldEverywhere() throws {
        let ceilings = [-1, 0, 1, CampShape.venueKidsRange.upperBound, CampShape.venueKidsRange.upperBound + 1]
        let floors = [-1, 0, 1, CampShape.venueCoachRange.upperBound, CampShape.venueCoachRange.upperBound + 1]

        for ceiling in ceilings {
            for floor in floors {
                var shape = CampShape.initial(venueCount: 1, courts: 6)
                shape.venues[0].maxKids = ceiling
                shape.venues[0].minCoaches = floor

                let updated = try #require(shape.venue(applying: 0, to: createdVenue(from: shape)))
                #expect(updated.coachMin <= updated.coachMax)
                #expect(updated.playerMin <= updated.playerMax)
            }
        }
    }

    // MARK: - Rates

    @Test("Adding a venue seeds it from the camp-wide rates and its own court count")
    func addedVenueIsSeededFromTheRates() {
        var shape = CampShape.initial(venueCount: 1, courts: 4, kidsPerCourt: 9, coachesPerCourt: 2)
        shape.addVenue()

        let added = shape.venues[1]
        #expect(added.courts == 4)
        #expect(added.maxKids == 36)
        #expect(added.minCoaches == 8)
    }

    @Test("Moving the camp-wide kids stepper writes into every venue")
    func kidsRateWritesIntoEveryVenue() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)
        shape.venues[0].maxKids = 3

        shape.setKidsPerCourt(10)

        #expect(shape.kidsPerCourt == 10)
        #expect(shape.venues.map(\.maxKids) == [60, 60])
    }

    @Test("Moving the camp-wide coaches stepper writes into every venue")
    func coachRateWritesIntoEveryVenue() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)
        shape.venues[1].minCoaches = 0

        shape.setCoachesPerCourt(2)

        #expect(shape.coachesPerCourt == 2)
        #expect(shape.venues.map(\.minCoaches) == [12, 12])
    }

    @Test("Changing a venue's courts re-derives its ceiling and its floor")
    func courtsReDeriveTheRowsLimits() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)
        #expect(shape.venues[0].maxKids == 48)

        shape.setCourts(8, for: shape.venues[0].id)

        #expect(shape.venues[0].courts == 8)
        #expect(shape.venues[0].maxKids == 64)
        #expect(shape.venues[0].minCoaches == 8)
        // And only that row.
        #expect(shape.venues[1].maxKids == 48)
    }

    /// The floor holds: one venue is the fewest a camp can have, so the last row refuses to go.
    @Test("The last row cannot be removed")
    func keepsTheLastRow() {
        var shape = CampShape.initial(venueCount: 1, courts: 6)
        shape.removeVenue(shape.venues[0].id)
        #expect(shape.venues.count == 1)
    }

    // MARK: - Fixture

    /// The venue the flow would actually hand `venue(applying:)` — seeded by `Camp.make(from:)`
    /// from the draft, not built here, so the "already agrees" comparison is against the real
    /// starting point.
    private func createdVenue(from shape: CampShape, at index: Int = 0) -> Venue {
        var draft = CampDraft()
        draft.name = "UCLA Tennis Camp"
        return Camp.make(from: shape.applied(to: draft), inviteCode: "SYC-0001").orderedVenues[index]
    }
}
