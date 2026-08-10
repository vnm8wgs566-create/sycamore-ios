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
//  A third has joined them. `8b` is drawn as a "No venues yet" state, so a shape now starts with
//  nothing in it and the floor of one venue is kept by `isCreatable` at the save gate rather than
//  by `removeVenue` refusing. That moves a rule out of the one place a screen could demonstrate it
//  — the last row used to simply not swipe — and into a property, so the suite is where the floor
//  is now shown to hold at all.
//
//  The camp's operating days are pinned here for the first of those reasons and not the second.
//  Their path is the short one — `8b` writes them straight onto `CampDraft`, which has a field for
//  them, so they take neither `CampShape` nor the correction pass — but its end is the same:
//  `camps_camp_days_check` (`check (camp_days > 0 …)`) is another constraint that fires at
//  `insert`, after the whole onboarding flow has been walked, and the picker's refusal is the only
//  thing standing in front of it. So the floor, the default the column shares, and the wrap
//  `openingDay(from:)` does at the end of the week are all asked here, where they can be.
//
//  They are asked in *this* suite rather than a new one because this is where "what `8b` collected
//  reaches the created camp" is already established, and the days are the one answer that screen
//  collects which no other test would otherwise follow all the way down.
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
        // 40 courts × 24 kids. Spelled out as well as derived on purpose — the line above would
        // keep passing if the ceiling moved, and this is the one that notices.
        //
        // It noticed. This read 384 (16 × 24) until `courtRange` widened from `1...16` to the
        // design's own stepper range of `1...40`. That is a real change and the number followed
        // it; nothing here is being re-baselined to make a failure go away. `sites.player_max`
        // has no upper CHECK — only `player_min <= player_max` — so 960 is writable.
        #expect(updated.playerMax == 960)
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

    // MARK: - No venues yet

    /// What "Create a camp" now opens on. `8b` is drawn as an empty state, so nought venues is the
    /// screen's first state rather than one nothing could reach.
    @Test("A new camp is shaped with no venues and the two default rates")
    func aNewShapeIsEmpty() {
        let shape = CampShape.empty

        #expect(shape.venues.isEmpty)
        #expect(shape.totalCourts == 0)
        // The rates survive the emptiness, because the first venue is seeded from them.
        #expect(shape.kidsPerCourt == CampShape.defaultKidsPerCourt)
        #expect(shape.coachesPerCourt == CampShape.defaultCoachesPerCourt)
    }

    /// The floor moved rather than went. A *form* may hold no venues; a *camp* may not, and this is
    /// the one property that says which — `CreateCampView` draws "Save the shape" only where it
    /// holds, and `saveTheShape` refuses without it.
    @Test("A shape with no venues cannot reach a camp; one with a venue can")
    func theFloorIsKeptByIsCreatable() {
        let empty = CampShape.empty
        #expect(!empty.isCreatable)

        var one = CampShape.empty
        one.addVenue()
        #expect(one.isCreatable)

        // The ceiling is a separate rule and stays where it was, so a full camp is still creatable.
        let full = CampShape.initial(venueCount: CampShape.venueRange.upperBound, courts: 6)
        #expect(full.isCreatable)
    }

    /// The ceiling, which `addVenue` guards on and `8b`'s "Add a venue" both disables and dims by.
    /// One property with three readers, so the row can never be live over a mutator that refuses.
    @Test("The eighth venue is the last one; the row that adds it goes out with the rule")
    func theCeilingIsOneRuleWithThreeReaders() {
        var shape = CampShape.initial(venueCount: CampShape.venueRange.upperBound - 1, courts: 6)
        #expect(shape.canAddVenue)

        shape.addVenue()
        #expect(shape.venues.count == CampShape.venueRange.upperBound)
        #expect(!shape.canAddVenue)

        // And the mutator refuses rather than growing past it.
        shape.addVenue()
        #expect(shape.venues.count == CampShape.venueRange.upperBound)
    }

    /// "Create your first venue" is `addVenue()` on an empty shape, and the row it makes has to be
    /// the row `initial()` would have seeded — same name, same emoji, same courts — or the design's
    /// footnote ("One venue is enough to start") would be buying a *different* venue from the one
    /// the app used to hand out.
    @Test("The first venue created by hand is the venue setup would have seeded")
    func firstVenueMatchesTheSeed() {
        var shape = CampShape.empty
        shape.addVenue()

        let seeded = CampShape.initial(venueCount: 1).venues[0]
        let created = shape.venues[0]

        #expect(created.name == "Venue 1")
        #expect(created.icon == seeded.icon)
        #expect(created.tint == seeded.tint)
        #expect(created.courts == seeded.courts)
        #expect(created.maxKids == seeded.maxKids)
        #expect(created.minCoaches == seeded.minCoaches)
    }

    /// The way back to the drawn state. This used to refuse — one venue was the fewest a camp could
    /// have — which was a rule about a camp being kept by a form, and left `8b`'s empty state
    /// unreachable once a venue existed.
    @Test("The last row can be removed, and lands back on the empty state")
    func removingTheLastRowEmptiesTheShape() {
        var shape = CampShape.initial(venueCount: 1, courts: 6)

        shape.removeVenue(shape.venues[0].id)

        #expect(shape.venues.isEmpty)
        #expect(!shape.isCreatable)
        // And the rates are still standing, so the venue created next is seeded from what was set
        // before the removal rather than from the defaults.
        #expect(shape.kidsPerCourt == CampShape.defaultKidsPerCourt)
    }

    /// A removal that names nobody leaves the shape alone. Reachable now that the guard on the
    /// count has gone: what stood in front of this was a floor rather than a check on the id.
    @Test("Removing an id that is not there changes nothing")
    func removingAStrangerChangesNothing() {
        var shape = CampShape.initial(venueCount: 2, courts: 6)
        shape.venues[1].name = "Main Courts"
        let before = shape

        shape.removeVenue(VenueShape.ID())

        #expect(shape == before)
    }

    // MARK: - Days

    /// The claim every camp created before this week rests on. `CampDraft`, `CampShape` and the
    /// column all say Monday-to-Friday on their own, and this is the one place all three are asked
    /// at once — 31 is `camps.camp_days`' DEFAULT, so a camp saved without opening the day picker
    /// is written with exactly the number the database would have chosen for it.
    @Test("A camp created without saying anything runs Monday to Friday")
    func defaultsToTheWorkingWeek() {
        var draft = CampDraft()
        draft.name = "UCLA Tennis Camp"

        let camp = Camp.make(from: CampShape.initial().applied(to: draft), inviteCode: "SYC-0001")

        #expect(camp.days == .weekdays)
        #expect(camp.days.rawValue == 31)
        #expect(camp.days.ordered == [.mon, .tue, .wed, .thu, .fri])
    }

    /// The round trip the screen depends on. The days are the one answer `8b` collects that goes
    /// straight onto the draft — `CampDraft` has a field for them, where a venue's name and
    /// courts have none — so they take neither `CampShape` nor the correction pass, and this is
    /// the whole of their path to the camp.
    @Test("The week drawn on 8b reaches the created camp")
    func chosenDaysReachTheCamp() {
        var draft = CampDraft()
        draft.name = "Saturday Swim Club"
        draft.days = CampDays([.sat, .sun])

        let shape = CampShape.initial(venueCount: 2, courts: 6)
        let camp = Camp.make(from: shape.applied(to: draft), inviteCode: "SYC-0001")

        #expect(camp.days == CampDays([.sat, .sun]))
        #expect(camp.days.ordered == [.sat, .sun])
        // And the shape passing through leaves the week alone — `applied(to:)` writes the venue
        // count and the courts, and must not reset anything the draft was already carrying.
        #expect(camp.venueCount == 2)
    }

    /// The refusal, at the layer that owns it. Below this, `CampDays.toggle(_:)` flips
    /// unconditionally; above it, nothing may hand `camp_days` a zero.
    @Test("The last day on cannot be switched off")
    func refusesTheEmptyWeek() {
        let wednesdayOnly = CampDays([.wed])

        #expect(wednesdayOnly.toggling(.wed) == wednesdayOnly)
        #expect(wednesdayOnly.toggling(.wed).isValid)

        // Every other day is still free to move, which is what makes the refusal a floor rather
        // than a lock.
        #expect(wednesdayOnly.toggling(.sat) == CampDays([.wed, .sat]))

        // And the walk down to it: four of the five weekdays go out, the fifth stays.
        var week = CampDays.weekdays
        for day in [Weekday.mon, .tue, .thu, .fri] {
            week = week.toggling(day)
        }
        #expect(week == CampDays([.wed]))
        #expect(week.toggling(.wed) == CampDays([.wed]))
    }

    /// What the picker draws its disabled chip from, and what the caption under it reads.
    ///
    /// `isSingleDay` is asked of the mask rather than by counting, so the two ways of being at
    /// the floor — one bit set, and "toggling this day would change nothing" — have to agree at
    /// every day of the week or a chip somewhere looks live and does nothing.
    @Test("Being down to one day is the same fact however it is asked")
    func theFloorIsOneFactTwoWays() {
        #expect(!CampDays.weekdays.isSingleDay)
        #expect(!CampDays.everyDay.isSingleDay)
        #expect(CampDays([.sun]).isSingleDay)
        // A bit outside the seven is not a day, so it cannot be the one the camp runs.
        #expect(!CampDays(rawValue: 1 << 7).isSingleDay)

        for day in Weekday.allCases {
            let onlyThatDay = CampDays([day])
            #expect(onlyThatDay.isSingleDay)
            #expect(onlyThatDay.toggling(day) == onlyThatDay)
            // And a week with room to lose one is never drawn as refusing.
            #expect(CampDays.everyDay.toggling(day) != .everyDay)
        }
    }

    /// A day switched off and on again is the week it started as — the property four taps in the
    /// editor rely on, and the one a bitmask gets wrong if the bit index and the raw value drift.
    @Test("A day switched off and back on leaves the week where it was")
    func togglingIsItsOwnInverse() {
        for day in Weekday.allCases {
            let without = CampDays.everyDay.toggling(day)
            #expect(!without.contains(day))
            #expect(without.toggling(day) == .everyDay)
        }
    }

    /// The backstop `Camp.make(from:)` keeps, because the CHECK it stands in front of fires at
    /// `insert` — five screens after the picker that should have refused this.
    @Test("A draft that somehow carried no days is created Monday to Friday")
    func emptyDraftIsCreatedOnTheDefaultWeek() {
        var draft = CampDraft()
        draft.name = "UCLA Tennis Camp"
        draft.days = CampDays(rawValue: 0)

        let camp = Camp.make(from: draft, inviteCode: "SYC-0001")

        #expect(camp.days == .weekdays)
        // The CHECK is `camp_days > 0`; this is what stops it being asked.
        #expect(camp.days.rawValue > 0)
    }

    // MARK: - Opening day

    /// Schedule opens on the camp's own next day, not on a day of the week it does not run.
    @Test("A camp that runs today opens on today")
    func opensOnTodayWhenItRuns() {
        #expect(CampDays.weekdays.openingDay(from: .wed) == .wed)
        #expect(CampDays.everyDay.openingDay(from: .sun) == .sun)
    }

    /// The wrap. A Sunday at a Monday-to-Friday camp is the case that falls backwards into a
    /// Friday that has already happened if the search runs the wrong way.
    @Test("A day the camp is shut opens on the next day it runs, wrapping into next week")
    func wrapsIntoNextWeek() {
        #expect(CampDays.weekdays.openingDay(from: .sat) == .mon)
        #expect(CampDays.weekdays.openingDay(from: .sun) == .mon)

        // A weekend club, asked on a Monday, is six days from opening — and answers Saturday
        // rather than the Sunday just gone.
        #expect(CampDays([.sat, .sun]).openingDay(from: .mon) == .sat)
        #expect(CampDays([.sat, .sun]).openingDay(from: .sun) == .sun)

        // One day a week: every other day of the week points at it.
        let tuesdayOnly = CampDays([.tue])
        for day in Weekday.allCases {
            #expect(tuesdayOnly.openingDay(from: day) == .tue)
        }
    }

    /// A camp with no days has no opening day, and says so rather than guessing at Monday. Only
    /// reachable through `CampDays(rawValue: 0)` — the editors and the CHECK both refuse it — and
    /// the whole reason `openingDay` returns an optional.
    @Test("A camp with no days has no opening day")
    func noDaysMeansNoOpeningDay() {
        #expect(CampDays(rawValue: 0).openingDay(from: .mon) == nil)
    }

    // MARK: - In words

    /// What the Season row's subtitle and `8b`'s summary line read. Both special cases earn their
    /// place: "Mon, Tue, Wed, Thu, Fri" is the commonest week in the app spelled at four times the
    /// length, and "Every day" is the one a list of seven says worst.
    @Test("The week reads as a phrase where there is one, and as its days otherwise")
    func summaryLineSpellsTheWeek() {
        #expect(CampDays.weekdays.summaryLine == "Mon–Fri")
        #expect(CampDays.everyDay.summaryLine == "Every day")
        #expect(CampDays([.sat, .sun]).summaryLine == "Sat, Sun")
        #expect(CampDays([.tue, .thu]).summaryLine == "Tue, Thu")
        #expect(CampDays([.wed]).summaryLine == "Wed")
        // Monday first whatever order the days were named in.
        #expect(CampDays([.fri, .mon]).summaryLine == "Mon, Fri")
    }

    /// The count, and the sentence that replaces it at the floor. Both screens read this rather
    /// than spelling the refusal themselves, so the words cannot differ between them.
    @Test("The count line stops counting and states the floor at one day")
    func countLineExplainsTheFloor() {
        #expect(CampDays.weekdays.countLine == "5 days a week")
        #expect(CampDays.everyDay.countLine == "7 days a week")
        #expect(CampDays([.sat, .sun]).countLine == "2 days a week")
        #expect(CampDays([.wed]).countLine == "at least one day")
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
