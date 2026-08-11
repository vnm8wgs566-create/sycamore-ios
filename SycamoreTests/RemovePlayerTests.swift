//
//  RemovePlayerTests.swift
//  SycamoreTests
//
//  Taking a kid off the camp. `removePlayers` existed and was reachable only from roster
//  reconciliation, so a child who left on Tuesday stayed on every list until somebody re-imported
//  the whole spreadsheet without them.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Removing a kid from the camp")
struct RemovePlayerTests {

    private func loaded() -> (AppStore, Camp) {
        var camp = Fixture.camp([.init("Home", courts: 2)], players: 6)
        camp.evenOut()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        return (store, camp)
    }

    @Test("The kid goes, and the camp keeps everybody else")
    func removalTakesOneKid() async throws {
        let (store, camp) = loaded()
        let leaving = try #require(camp.orderedPlayers.first)

        await store.removePlayer(leaving.id)

        #expect(store.errorMessage == nil)
        #expect(store.camp?.player(leaving.id) == nil)
        #expect(store.camp?.players.count == 5)
    }

    /// The ladder closes over the gap rather than leaving a hole. `mutate` reindexes, so this is
    /// really a test that removal goes through the same door every other mutation does.
    @Test("The ladder renumbers 1…N with no gap")
    func theLadderCloses() async throws {
        let (store, camp) = loaded()
        let leaving = try #require(camp.orderedPlayers.first)

        await store.removePlayer(leaving.id)

        let ranks = try #require(store.camp).orderedPlayers.map(\.overallRank)
        #expect(ranks == Array(1...5))
    }

    /// It says so. The design toasts every write on this screen, and a child vanishing from a
    /// list with no word is the one that most looks like a bug.
    @Test("It says who was removed")
    func itSaysSo() async throws {
        let (store, camp) = loaded()
        let leaving = try #require(camp.orderedPlayers.first)
        let name = leaving.displayName

        await store.removePlayer(leaving.id)

        #expect(store.toast?.message == "\(name) removed")
        // And offers no way back: `removePlayers` is a delete, so putting them back would mint a
        // new row at the foot of the ladder with their court, rank and note gone.
        #expect(store.toast?.undo == nil)
    }

    @Test("Removing a kid who is already gone reports rather than pretending")
    func removingAGhost() async throws {
        let (store, _) = loaded()

        await store.removePlayer(UUID())

        #expect(store.errorMessage != nil)
        #expect(store.camp?.players.count == 6)
    }
}
