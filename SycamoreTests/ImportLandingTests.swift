//
//  ImportLandingTests.swift
//  SycamoreTests
//
//  Where the reader ends up after a roster lands.
//
//  `doImport` finishes `tab: 'groups', venueSel: venue.id, page: null` (`state1.js:567`). The app
//  finished nowhere in particular: onboarding was torn down by `store.camp` landing and `RootView`
//  chose, while `EnrolmentFlowView` called `onClose()` and left whichever screen had presented it
//  showing whatever it had been showing. Forty kids were written and nothing on screen moved.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Landing on the kids who just arrived")
struct ImportLandingTests {

    /// Two venues with room, and a reader standing somewhere else entirely.
    private static func loaded() -> (AppStore, Camp) {
        let camp = Fixture.camp(
            [.init("Home", courts: 2), .init("Away", courts: 2)], players: 6
        )
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        store.selectedTab = .overview
        store.venueFilter = .all
        return (store, camp)
    }

    private static func arrival(_ name: String, venueIndex: Int = 0) -> IntakePlayer {
        IntakePlayer(firstName: name, lastName: "New", age: 12, gender: .f, venueIndex: venueIndex)
    }

    private static func commit(_ arrivals: [IntakePlayer]) -> RosterReconciliation.Commit {
        RosterReconciliation.Commit(inserting: arrivals, updating: [], removing: [])
    }

    @Test("An import lands on Groups at the venue it went to")
    func landsOnGroups() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.applyRoster(Self.commit([Self.arrival("Ara"), Self.arrival("Tom")]), venues: venues)

        #expect(store.errorMessage == nil)
        #expect(store.selectedTab == .groups)
        #expect(store.venueFilter == .venue(venues[0]))
    }

    /// A roster routed across two venues lands on the one that took the most of it — the prototype
    /// has one venue selected and never has to answer this.
    @Test("It lands at the venue that took the most of them")
    func landsAtTheBusiestVenue() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.applyRoster(
            Self.commit([
                Self.arrival("Ara", venueIndex: 1),
                Self.arrival("Tom", venueIndex: 1),
                Self.arrival("Mo", venueIndex: 0),
            ]),
            venues: venues
        )

        #expect(store.venueFilter == .venue(venues[1]))
    }

    /// Ties fall to the camp's own venue order, so two devices importing the same file land the
    /// same way — the same reason the seating pass runs in venue order rather than a set's.
    @Test("A tie falls to the first venue")
    func aTieFallsToTheFirst() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.applyRoster(
            Self.commit([Self.arrival("Ara", venueIndex: 1), Self.arrival("Tom", venueIndex: 0)]),
            venues: venues
        )

        #expect(store.venueFilter == .venue(venues[0]))
    }

    /// A commit that only corrects ages moves nobody, so it moves the reader nowhere either — they
    /// are looking at a screen they chose.
    @Test("A commit with no arrivals leaves the reader where they were")
    func noArrivalsNoMove() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        var patched = try #require(camp.orderedPlayers.first)
        patched.age = 13
        await store.applyRoster(
            RosterReconciliation.Commit(inserting: [], updating: [patched], removing: []),
            venues: venues
        )

        #expect(store.selectedTab == .overview)
        #expect(store.venueFilter == .all)
    }
}
