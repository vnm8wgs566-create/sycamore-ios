//
//  OverviewCapacityTests.swift
//  SycamoreTests
//
//  "8 of 8", "6 of 8 · 2 spots", "7 of 8 · 1 spot" — the reading `8i` puts at the head of every
//  open court card.
//
//  Worth pinning for the reason `OverviewRosterTests` gives about the list underneath it: nothing
//  on screen looks wrong when it is wrong. A card that says "6 of 8 · 3 spots" still reads as a
//  card; one that says "-1 spots" reads as a rendering fault rather than as the arithmetic error it
//  is; and a court that has quietly gone one over its ceiling looks exactly like one that has not.
//  The only thing that catches any of it is the arithmetic, and the arithmetic is out of the view
//  and in `CourtCapacity`.
//
//  Four questions:
//
//      reading / spotsFree / pillLabel  -> what the card says
//      isOver / overBy                  -> the state the design never draws
//      reading(for:capacity:)           -> and whether the card says anything at all
//      capacities(in:venueID:)          -> where the denominator comes from
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private func card(
    here: Int, status: CourtStatus = .open, id: Group.ID = UUID()
) -> CourtCard {
    CourtCard(
        id: id,
        venueID: UUID(),
        groupName: "Group 1",
        courtLabel: "Court 1",
        rankOrder: 1,
        coachID: nil,
        coachName: nil,
        playersHere: here,
        activity: "Drills",
        status: status
    )
}

// MARK: - What the card says

@Suite("CourtCapacity")
struct CourtCapacityTests {

    /// `8i`'s own three open courts, in the order it draws them. The whole point of the change: a
    /// head-count with nothing to measure it against cannot answer "where is there room".
    @Test(
        "The design's own three readings",
        arguments: [
            (8, 8, "8 of 8", nil),
            (6, 8, "6 of 8", "2 spots"),
            (7, 8, "7 of 8", "1 spot"),
        ] as [(Int, Int, String, String?)]
    )
    func theDesignsReadings(here: Int, capacity: Int, reading: String, pill: String?) {
        let subject = CourtCapacity(here: here, capacity: capacity)

        #expect(subject.reading == reading)
        #expect(subject.pillLabel == pill)
    }

    /// A full court draws the figure and no pill. The pill is "there is room", not "here is the
    /// count again", so a court with none has nothing to put in that slot.
    @Test("A full court offers no pill")
    func fullDrawsNoPill() {
        let subject = CourtCapacity(here: 8, capacity: 8)

        #expect(subject.spotsFree == 0)
        #expect(subject.pillLabel == nil)
        #expect(!subject.isOver)
    }

    @Test("Spots left is the gap, and never negative", arguments: 0...12)
    func spotsFreeIsTheGap(here: Int) {
        let subject = CourtCapacity(here: here, capacity: 8)

        #expect(subject.spotsFree == max(0, 8 - here))
        #expect(subject.spotsFree >= 0)
    }

    /// The singular is not cosmetic: "1 spots" is the kind of thing that survives a review and
    /// then sits on the busiest screen in the app all season.
    @Test("One place left is a spot, not spots")
    func oneIsSingular() {
        #expect(CourtCapacity(here: 7, capacity: 8).pillLabel == "1 spot")
        #expect(CourtCapacity(here: 6, capacity: 8).pillLabel == "2 spots")
    }

    // MARK: The state the design never draws

    /// `8i` has no picture of a court past its ceiling. `Group.capacityBanner` writes "1 over —
    /// move one kid down" for exactly this, so the state is real; what must not happen is the
    /// green "spots" pill quietly counting downwards through zero.
    @Test("A court over its ceiling says so, and never offers spots", arguments: 9...12)
    func overCapacity(here: Int) {
        let subject = CourtCapacity(here: here, capacity: 8)

        #expect(subject.isOver)
        #expect(subject.overBy == here - 8)
        #expect(subject.spotsFree == 0)
        #expect(subject.pillLabel == "\(here - 8) over")
    }

    /// `isOver` / `overBy` are `Group.isOverCapacity` / `Group.overCapacityBy` restated over this
    /// type's own numerator — see the file header on `CourtCapacity` for why they are restated
    /// rather than delegated. This is the assertion that keeps the two definitions the same one.
    @Test("The over-capacity rule matches the model's", arguments: 0...12)
    func overCapacityAgreesWithTheModel(here: Int) {
        var group = Group(
            venueID: UUID(), number: 1, label: "Court 1", rankOrder: 1, coachID: nil, capacity: 8
        )
        group.presentCount = here
        // Bound to a `let` first: `#expect` cannot call a mutating member, and reading a computed
        // property off a `var` counts.
        let modelSaysOver = group.isOverCapacity
        let modelSaysBy = group.overCapacityBy

        let subject = CourtCapacity(here: here, capacity: 8)

        #expect(subject.isOver == modelSaysOver)
        #expect(subject.overBy == modelSaysBy)
    }

    /// Exactly at the ceiling is not over it. The boundary either side of `capacity` is the one
    /// place an off-by-one would put an amber warning on a perfectly ordinary court.
    @Test("The boundary is inclusive")
    func theBoundary() {
        #expect(!CourtCapacity(here: 8, capacity: 8).isOver)
        #expect(CourtCapacity(here: 9, capacity: 8).isOver)
        #expect(CourtCapacity(here: 8, capacity: 8).overBy == 0)
    }

    // MARK: What VoiceOver hears

    /// "8 of 8" read aloud is a score or a date. The spoken form says what the numbers are, and
    /// folds the pill in rather than leaving it as a second fragment after it.
    @Test("The spoken label is a sentence, and pluralises")
    func theSpokenLabel() {
        #expect(CourtCapacity(here: 8, capacity: 8).spokenLabel == "8 of 8 kids. Full")
        #expect(CourtCapacity(here: 7, capacity: 8).spokenLabel == "7 of 8 kids. 1 spot left")
        #expect(CourtCapacity(here: 6, capacity: 8).spokenLabel == "6 of 8 kids. 2 spots left")
        #expect(CourtCapacity(here: 9, capacity: 8).spokenLabel == "9 of 8 kids. 1 over capacity")
    }
}

// MARK: - Whether the card draws a reading at all

@Suite("CourtCapacity.reading(for:capacity:)")
struct CourtCapacityReadingTests {

    @Test("An open court with a ceiling reads its head-count against it")
    func anOpenCourtReads() {
        let reading = CourtCapacity.reading(for: card(here: 6), capacity: 8)

        #expect(reading == CourtCapacity(here: 6, capacity: 8))
    }

    /// `8i` gives Court 4 a `Closed` badge in this slot and no numbers whatsoever. There is nobody
    /// on a closed court and no room on it either, so a reading would be two claims that are both
    /// beside the point.
    @Test("A closed court reads nothing, whatever the graph says is on it")
    func aClosedCourtReadsNothing() {
        let shut = card(here: 6, status: .closed(reason: "Net down"))

        #expect(CourtCapacity.reading(for: shut, capacity: 8) == nil)
    }

    /// A `today_courts` row the camp graph has no group for is a read that has got ahead of the
    /// camp, not a court with a ceiling of zero.
    @Test("A court the graph has no group for reads nothing")
    func anUnknownCourtReadsNothing() {
        #expect(CourtCapacity.reading(for: card(here: 6), capacity: nil) == nil)
    }

    @Test("A ceiling of zero or less reads nothing rather than dividing by it", arguments: [0, -1])
    func aZeroCeilingReadsNothing(capacity: Int) {
        #expect(CourtCapacity.reading(for: card(here: 6), capacity: capacity) == nil)
    }

    /// An empty court is a real reading and has to draw one — "0 of 8 · 8 spots" is exactly the
    /// answer an admin looking for somewhere to put a late arrival wants.
    @Test("A court nobody has arrived at still reads")
    func anEmptyCourtReads() {
        let reading = CourtCapacity.reading(for: card(here: 0), capacity: 8)

        #expect(reading?.reading == "0 of 8")
        #expect(reading?.pillLabel == "8 spots")
    }
}

// MARK: - Where the denominator comes from

@Suite("TodayCourts.capacities")
struct TodayCourtsCapacitiesTests {

    private func camp(venues: Int, courtsEach: Int) -> Camp {
        var camp = Fixture.camp(
            (0..<venues).map { .init("Venue \($0 + 1)", courts: courtsEach) }, players: 40
        )
        // Nothing to deal onto a venue with no courts, and `partition` on one is a different
        // question from the one this suite asks.
        if courtsEach > 0 { camp.partition() }
        return camp
    }

    @Test("Every court in the camp reports its own ceiling")
    func everyCourtReports() {
        let camp = camp(venues: 2, courtsEach: 3)

        let capacities = TodayCourts.capacities(in: camp)

        #expect(capacities.count == camp.groups.count)
        for group in camp.groups {
            #expect(capacities[group.id] == group.capacity)
        }
    }

    /// Overview draws one venue at a time — `store.courts` is `readVenueID`'s courts — so the
    /// other venue's ceilings would be rows nothing ever looks up. Narrowed for the same reason
    /// `rosters(in:day:venueID:)` narrows.
    @Test("Narrowing to a venue leaves the rest of the camp out")
    func narrowedToAVenue() {
        let camp = camp(venues: 2, courtsEach: 3)
        let venue = camp.orderedVenues[0]

        let capacities = TodayCourts.capacities(in: camp, venueID: venue.id)

        #expect(capacities.count == 3)
        #expect(Set(capacities.keys) == Set(camp.groups(in: venue.id).map(\.id)))
    }

    @Test("A camp with no courts yields no ceilings at all")
    func anEmptyCamp() {
        #expect(TodayCourts.capacities(in: camp(venues: 1, courtsEach: 0)).isEmpty)
    }

    /// The seam this pass exists to close. `CourtCapacity` takes its numerator off the card and
    /// its denominator off the graph, so the two have to be talking about the same court and the
    /// same day — `SectionEightRepository` counts `playersHere` exactly as `Camp.reindex` counts
    /// `presentCount`, and this is what says so out loud.
    @Test("The card's head-count is the group's present count")
    func theNumeratorAgreesWithTheGraph() {
        let camp = camp(venues: 1, courtsEach: 4)

        for group in camp.groups {
            let here = camp.players(inGroup: group.id).count { !camp.isAway($0.id, on: .today) }
            #expect(here == group.presentCount)
        }
    }
}
