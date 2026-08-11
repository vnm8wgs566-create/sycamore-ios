//
//  RemoveVenueTests.swift
//  SycamoreTests
//
//  Taking a venue off a camp that already exists. The design draws the button and the app had no
//  verb behind it — `VenueRemoveButton` was written for this and had only ever been used before
//  the camp was written, where its kid count is always nought.
//
//  The kids go with it, which is the design's answer (`state1.js:256` filters both lists) and the
//  schema's: every foreign key into `sites` either cascades or sets null.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Removing a venue")
struct RemoveVenueTests {

    private func loaded() -> (AppStore, Camp) {
        var camp = Fixture.camp(
            [.init("Home", courts: 2), .init("Away", courts: 2)], players: 8
        )
        camp.partition()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        return (store, camp)
    }

    @Test("The venue goes, with its courts and its kids")
    func removalTakesTheVenueWhole() async throws {
        let (store, camp) = loaded()
        let leaving = camp.orderedVenues[0].id
        let staying = camp.orderedVenues[1].id
        let survivors = camp.players(in: staying).count

        await store.removeVenue(leaving)

        let after = try #require(store.camp)
        #expect(store.errorMessage == nil)
        #expect(after.venue(leaving) == nil)
        #expect(after.groups(in: leaving).isEmpty)
        #expect(after.players.allSatisfy { $0.venueID == staying })
        #expect(after.players.count == survivors)
    }

    /// The ladder closes over the gap. A camp that kept 1…4 and 7…8 would draw ranks with holes
    /// in them on the Rank tab.
    @Test("The ladder renumbers over what left")
    func theLadderCloses() async throws {
        let (store, camp) = loaded()
        let leaving = camp.orderedVenues[0].id
        let survivors = camp.players(in: camp.orderedVenues[1].id).count

        await store.removeVenue(leaving)

        let ranks = try #require(store.camp).orderedPlayers.map(\.overallRank)
        #expect(ranks == Array(1...survivors))
    }

    /// A coach is not part of the venue — `coaches.site_id` is `on delete set null`, so they
    /// survive it standing nowhere. Their roaming goes back to what their role implies, which is
    /// the half Postgres does not write and the model has to.
    @Test("A coach standing there survives, unassigned")
    func aCoachSurvives() async throws {
        var camp = Fixture.camp([.init("Home", courts: 2), .init("Away", courts: 2)], players: 4)
        let leaving = camp.orderedVenues[0].id
        let court = try #require(camp.groups(in: leaving).first)
        var coach = StaffMember(name: "Ravi", role: .worker)
        camp.staff = [coach]
        camp.assignStaff(coach.id, toGroup: court.id)
        coach = try #require(camp.staff(coach.id))
        #expect(coach.assignment != nil)

        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        await store.removeVenue(leaving)

        let after = try #require(store.camp?.staff(coach.id))
        #expect(after.assignment == nil)
        #expect(after.isRoaming == Role.worker.roamsByDefault)
    }

    /// **The bug that shipping deletion creates.** `addVenue` allocated `sortIndex` off
    /// `venues.count`, so deleting from the middle made the next venue tie a survivor — and
    /// `orderedVenues` sorts on that field with no tiebreaker, so the two swapped places between
    /// reloads. Allocated past the highest in use now.
    @Test("A venue added after a deletion does not tie the one that survived")
    func theNextVenueTakesAFreeSlot() async throws {
        var camp = Fixture.camp(
            [.init("One", courts: 1), .init("Two", courts: 1), .init("Three", courts: 1)],
            players: 0
        )
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        await store.removeVenue(camp.orderedVenues[1].id)
        await store.addVenue()

        camp = try #require(store.camp)
        let slots = camp.venues.map(\.sortIndex)
        #expect(Set(slots).count == slots.count)
        #expect(camp.orderedVenues.map(\.name).last == "Venue 4")
    }

    @Test("It says what left, and how many went with it")
    func itSaysSo() async throws {
        let (store, camp) = loaded()
        let leaving = camp.orderedVenues[0]
        let kids = camp.players(in: leaving.id).count

        await store.removeVenue(leaving.id)

        #expect(store.toast?.message == "\(leaving.name) removed · \(kids) kids with it")
        // No way back: the kids are deleted, not unassigned.
        #expect(store.toast?.undo == nil)
    }
}
