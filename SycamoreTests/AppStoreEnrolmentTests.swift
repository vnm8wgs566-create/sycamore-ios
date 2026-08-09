//
//  AppStoreEnrolmentTests.swift
//  SycamoreTests
//
//  One intent, three writes, and the order they go in.
//
//  `applyRoster` is the only place in the app that makes three round trips inside one intent, and
//  there is no transaction across them — so the order is not tidiness, it is what a half-failure
//  leaves behind. That is the thing worth pinning: a run that fails at the update must not already
//  have deleted anybody, because a camp with extra kids in it is a state somebody can look at and
//  fix, and a camp with kids missing is not.
//
//  Driven through `InMemoryRepository`, which keeps the same all-or-nothing promises the Postgres
//  one does — `mutate` stores nothing when its edit throws, and both `updatePlayers` and
//  `removePlayers` check every id before writing a field.
//
//  One thing here is deliberately **not** tested: that an empty list skips its repository call.
//  That guard exists because each of the three methods answers an empty request with
//  `camp(id:)` — eight PostgREST selects — and against the in-memory store the skipped call and
//  the made one are indistinguishable in every observable way. It is a cost, not a semantic, and
//  the comment on `applyRoster` is what guards it.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("AppStore.applyRoster")
struct AppStoreEnrolmentTests {

    /// A camp of six kids across two venues, loaded into a store that shares it with the
    /// repository — which is the state every one of these starts from, and the state the flow
    /// itself is in when the reader taps the button.
    private static func loaded() -> (AppStore, Camp) {
        let camp = Fixture.camp(
            [.init("Home", courts: 2), .init("Away", courts: 2)], players: 6
        )
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        return (store, camp)
    }

    private static func arrival(_ name: String, venueIndex: Int = 0) -> IntakePlayer {
        IntakePlayer(firstName: name, lastName: "New", age: 12, gender: .f, venueIndex: venueIndex)
    }

    // MARK: The three writes

    @Test("Everything ticked lands, in one intent and with no banner")
    func allThree() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        var patched = try #require(camp.orderedPlayers.first)
        patched.age = 13

        let leaving = try #require(camp.orderedPlayers.last)

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [Self.arrival("Nina")],
                updating: [patched],
                removing: [leaving.id]
            ),
            venues: venues
        )

        let after = try #require(store.camp)
        #expect(store.errorMessage == nil)
        #expect(after.players.count == 6)
        #expect(after.players.contains { $0.firstName == "Nina" })
        #expect(after.players.first { $0.id == patched.id }?.age == 13)
        #expect(!after.players.contains { $0.id == leaving.id })
    }

    /// The ordering decision, stated as the failure it exists to prevent.
    ///
    /// The update names a kid this camp does not hold, so `updatePlayers` throws. If the removal
    /// ran first — or ran at all — the kid ticked for removal would be gone and the reader would
    /// be looking at a banner about an update while a child had quietly left the roster.
    @Test("A failed update leaves nobody deleted, because removals run last")
    func removalsRunLast() async throws {
        let (store, camp) = Self.loaded()
        let leaving = try #require(camp.orderedPlayers.last)

        // A kid with an id nobody at this camp has.
        var stranger = try #require(camp.orderedPlayers.first)
        stranger.id = UUID()

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [], updating: [stranger], removing: [leaving.id]
            ),
            venues: camp.orderedVenues.map(\.id)
        )

        let after = try #require(store.camp)
        #expect(store.errorMessage != nil)
        #expect(after.players.contains { $0.id == leaving.id })
        #expect(after.players.count == 6)
    }

    /// The other half of the same order: the additive step has already landed when a later one
    /// fails, which is the recoverable direction.
    @Test("A failed removal leaves the arrivals it already wrote, which is the survivable half")
    func insertsSurviveALaterFailure() async throws {
        let (store, camp) = Self.loaded()

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [Self.arrival("Nina")], updating: [], removing: [UUID()]
            ),
            venues: camp.orderedVenues.map(\.id)
        )

        let after = try #require(store.camp)
        #expect(store.errorMessage != nil)
        #expect(after.players.contains { $0.firstName == "Nina" })
    }

    // MARK: Where an arrival lands

    @Test("An arrival lands in the venue its index names")
    func arrivalVenue() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [Self.arrival("Nina", venueIndex: 1)], updating: [], removing: []
            ),
            venues: venues
        )

        let nina = try #require(store.camp?.players.first { $0.firstName == "Nina" })
        #expect(nina.venueID == venues[1])
        // And with no court, which is what Groups' unassigned band is for.
        #expect(nina.groupID == nil)
    }

    /// `min(index, count - 1)`. A file carries no venue column, so every row defaults to 0 — but a
    /// camp that lost a venue between two imports would otherwise index past the end.
    @Test("An index past the last venue lands in the last venue rather than falling off the end")
    func arrivalVenueClamped() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [Self.arrival("Nina", venueIndex: 9)], updating: [], removing: []
            ),
            venues: venues
        )

        let nina = try #require(store.camp?.players.first { $0.firstName == "Nina" })
        #expect(nina.venueID == venues.last)
    }

    @Test("Arrivals answered into different venues each go to their own")
    func arrivalsSplitByVenue() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [Self.arrival("Nina", venueIndex: 0), Self.arrival("Rafe", venueIndex: 1)],
                updating: [],
                removing: []
            ),
            venues: venues
        )

        let after = try #require(store.camp)
        #expect(after.players.first { $0.firstName == "Nina" }?.venueID == venues[0])
        #expect(after.players.first { $0.firstName == "Rafe" }?.venueID == venues[1])
    }

    // MARK: Refusals

    @Test("A commit nobody ticked writes nothing and raises nothing")
    func emptyCommit() async throws {
        let (store, camp) = Self.loaded()

        await store.applyRoster(
            RosterReconciliation.Commit(inserting: [], updating: [], removing: []),
            venues: camp.orderedVenues.map(\.id)
        )

        #expect(store.errorMessage == nil)
        #expect(store.camp?.players.count == 6)
    }

    /// Refused whole rather than written partly. Doing the updates and silently dropping the
    /// arrivals would report success for a roster missing the half the reader came for.
    @Test("Arrivals with nowhere to land write nothing at all, not even the updates beside them")
    func noVenueWritesNothing() async throws {
        let (store, camp) = Self.loaded()

        var patched = try #require(camp.orderedPlayers.first)
        patched.age = 13

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [Self.arrival("Nina")], updating: [patched], removing: []
            ),
            venues: []
        )

        let after = try #require(store.camp)
        #expect(!after.players.contains { $0.firstName == "Nina" })
        #expect(after.players.first { $0.id == patched.id }?.age == 12)
    }

    // MARK: One kid

    @Test("A kid typed in by hand is written straight away, into the venue that was chosen")
    func addOnePlayer() async throws {
        let (store, camp) = Self.loaded()
        let venues = camp.orderedVenues.map(\.id)

        await store.addPlayer(Self.arrival("Walk-in"), toVenue: venues[1])

        let kid = try #require(store.camp?.players.first { $0.firstName == "Walk-in" })
        #expect(store.errorMessage == nil)
        #expect(kid.venueID == venues[1])
        #expect(kid.groupID == nil)
        #expect(store.camp?.players.count == 7)
    }

    /// The two paths that write a kid have to agree about what a gap means, or a walk-in added at
    /// 8:55 reads differently from the same kid arriving in a file ten minutes earlier.
    @Test("A kid with no age keeps the gap rather than landing as a zero")
    func addOnePlayerWithNoAge() async throws {
        let (store, camp) = Self.loaded()
        let venue = try #require(camp.orderedVenues.first?.id)

        await store.addPlayer(
            IntakePlayer(firstName: "Walk-in", lastName: "", age: nil, gender: nil),
            toVenue: venue
        )

        let kid = try #require(store.camp?.players.first { $0.firstName == "Walk-in" })
        #expect(kid.age == nil)
        // No gender in the file reads as `.x`, which is the answer the app already means by
        // "not said" — `IntakePlayer.asPlayer()` owns that, and this is the caller that proves it.
        #expect(kid.gender == .x)
    }
}

// MARK: - Onboarding writes through the same intent

@MainActor
@Suite("Onboarding's roster is a commit of arrivals")
struct OnboardingCommitTests {

    /// `OnboardingFlowView.saveRoster` used to go straight to the repository, and its own comment
    /// recorded the debt. It now builds this shape, so the sentence is worth pinning: at
    /// onboarding there is nobody to reconcile against, every row is an arrival, and the two
    /// destructive phases are empty.
    @Test("Every row at onboarding is an insert, so nothing is updated and nobody is removed")
    func onboardingIsAllArrivals() async throws {
        let camp = Fixture.camp([.init("Home", courts: 2)], players: 0)
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        let byHand = IntakePlayer(firstName: "Walk-in", lastName: "Tan", age: 11, gender: .f)
        let fromFile = try IntakeFile.parse(RosterTemplate.csv, named: "template.csv").players

        await store.applyRoster(
            RosterReconciliation.Commit(
                inserting: [byHand] + fromFile, updating: [], removing: []
            ),
            venues: camp.orderedVenues.map(\.id)
        )

        let after = try #require(store.camp)
        #expect(store.errorMessage == nil)
        #expect(after.players.count == 4)
        // The hand-typed kid goes in front of the file, which is the order this had before the
        // rewrite — and one batch rather than four round trips.
        #expect(after.orderedPlayers.map(\.firstName) == ["Walk-in", "Serene", "Priya", "Liam"])
    }
}
