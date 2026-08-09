//
//  AppStoreLandingTests.swift
//  SycamoreTests
//
//  One drop on the Groups screen: applied here, written after, and put back if the write fails.
//
//  This is the half of `8p` no build can catch and no screenshot shows. `AppStore.land` writes the
//  camp graph *before* it has asked the repository for anything, which is the whole of the answer
//  to "the ordering is not intuitive/responsive" — the drag used to await two serialised round
//  trips with the row snapped back and the screen frozen in between. Optimism is only safe if the
//  failure path is exact, and a failure path is exactly what nobody exercises by hand: it needs a
//  dead connection at the moment of a drop.
//
//  Three things are pinned here, and the middle one is the sharp one.
//
//  * The plan lands — both halves of it, from one intent. `GroupsLandingPlan` decides *where*
//    and `GroupsLandingPlanTests` covers that; this covers the graph actually being written.
//  * The graph holds the drop **before** the repository has answered. Deterministic rather than
//    hopeful: `land` mutates `camp` and only then awaits, so one `Task.yield()` is enough to
//    catch the state between the two.
//  * A failed write restores the camp exactly — every player, rank and court back where they
//    were — and raises a banner. Half of a rollback is worse than none: it would leave a kid
//    standing on a court the server has never heard of, and nothing on screen would say so. The
//    last test pins where that restoration *stops*: a snapshot held here can put back this
//    process's copy and nothing else, so a landing whose second write fails leaves the first one
//    committed. Stated as an assertion rather than left to be discovered.
//
//  Driven through `InMemoryRepository`, whose `mutate` performs the same two model methods the
//  Postgres one does. Failure is provoked the way the rest of this suite provokes it — by naming
//  something the repository does not hold — because there is no failing stub to reach for and a
//  decorator over a sixty-five-method protocol would be more machinery than the test is worth.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("AppStore.land")
struct AppStoreLandingTests {

    /// Two courts in one venue, six kids ranked 1…6 — all of them parked on the first court,
    /// which is what `Fixture.camp` builds.
    ///
    /// `@MainActor` in its own right: the suite's annotation isolates the suite's members, and a
    /// nested type is a type of its own. Everything in here touches the store.
    @MainActor
    private struct Board {
        let store: AppStore
        /// Kept rather than dropped: the half-failure test has to ask what the *repository* holds,
        /// which is the one thing the store's own rollback cannot speak for.
        let repository: InMemoryRepository
        let camp: Camp
        let venueID: Venue.ID
        let courtOne: Group.ID
        let courtTwo: Group.ID

        init(repositoryHoldsTheCamp: Bool = true) {
            let camp = Fixture.camp([.init("Home", courts: 2)], players: 6)
            let repository = InMemoryRepository(camps: repositoryHoldsTheCamp ? [camp] : [])
            let store = AppStore(repository: repository)
            store.camp = camp

            self.camp = camp
            self.repository = repository
            self.store = store
            self.venueID = camp.orderedVenues[0].id
            self.courtOne = camp.groups(in: camp.orderedVenues[0].id)[0].id
            self.courtTwo = camp.groups(in: camp.orderedVenues[0].id)[1].id
        }

        /// The camp ladder as the fixture's own names, top to bottom.
        var ladder: [String] { store.camp.map(Fixture.ladder) ?? [] }

        func court(_ groupID: Group.ID) -> [String] {
            (store.camp?.players(inGroup: groupID) ?? [])
                .sorted { $0.courtRank < $1.courtRank }
                .map(\.firstName)
        }

        func plan(moving name: String, to groupID: Group.ID, above anchor: String?) -> GroupsLandingPlan? {
            guard let mover = camp.players.first(where: { $0.firstName == name }) else { return nil }
            return GroupsLandingPlan(
                moving: mover.id,
                to: GroupsLanding(
                    groupID: groupID,
                    venueID: venueID,
                    anchor: anchor.flatMap { name in
                        camp.players.first { $0.firstName == name }?.id
                    }
                ),
                ladder: store.rankAssignments(),
                roster: camp.players(inGroup: groupID)
            )
        }
    }

    // MARK: One intent, both orders

    @Test("A drop inside one court writes the camp ladder as well as the court's own sequence")
    func aReorderWritesBothOrders() async throws {
        let board = Board()
        let plan = try #require(board.plan(moving: "Kid5", to: board.courtOne, above: "Kid2"))

        await board.store.land(plan, in: board.courtOne)

        #expect(board.store.errorMessage == nil)
        // The numeral beside a kid on this screen is their place in the *camp*, so a reorder
        // inside a court that left `overallRank` alone would land them wearing the wrong number.
        #expect(board.ladder == ["Kid1", "Kid5", "Kid2", "Kid3", "Kid4", "Kid6"])
        #expect(board.court(board.courtOne) == ["Kid1", "Kid5", "Kid2", "Kid3", "Kid4", "Kid6"])
    }

    @Test("A drop on another court moves the kid's card and their band together")
    func aCourtChangeWritesBothOrders() async throws {
        let board = Board()
        let plan = try #require(board.plan(moving: "Kid2", to: board.courtTwo, above: nil))

        await board.store.land(plan, in: board.courtTwo)

        #expect(board.store.errorMessage == nil)
        #expect(board.court(board.courtTwo) == ["Kid2"])
        #expect(board.court(board.courtOne) == ["Kid1", "Kid3", "Kid4", "Kid5", "Kid6"])
        // An empty court has no place of its own in the ladder yet, so the back of it is the back
        // of the venue — see `GroupsLandingPlan`.
        #expect(board.ladder == ["Kid1", "Kid3", "Kid4", "Kid5", "Kid6", "Kid2"])
    }

    // MARK: Nothing waits on the write

    /// The reason the whole intent exists. `land` applies the plan and only then awaits, so a
    /// single yield catches the graph in the state the screen draws a frame after the finger
    /// leaves the handle — with the drop already in it and no repository consulted.
    @Test("The graph holds the drop before the repository has answered")
    func theWriteIsOptimistic() async throws {
        let board = Board()
        let plan = try #require(board.plan(moving: "Kid6", to: board.courtOne, above: "Kid1"))

        let write = Task { await board.store.land(plan, in: board.courtOne) }
        // One hop: enough for `land` to run everything before its first suspension, which is the
        // call into the repository actor.
        await Task.yield()

        #expect(board.ladder == ["Kid6", "Kid1", "Kid2", "Kid3", "Kid4", "Kid5"])

        await write.value
        #expect(board.ladder == ["Kid6", "Kid1", "Kid2", "Kid3", "Kid4", "Kid5"])
    }

    // MARK: Putting it back

    @Test("A write that fails outright leaves the camp exactly as it was, and says so")
    func aFailedWriteRollsBack() async throws {
        let board = Board(repositoryHoldsTheCamp: false)
        let before = try #require(board.store.camp)
        let plan = try #require(board.plan(moving: "Kid5", to: board.courtTwo, above: nil))

        await board.store.land(plan, in: board.courtTwo)

        #expect(board.store.camp == before)
        #expect(board.ladder == ["Kid1", "Kid2", "Kid3", "Kid4", "Kid5", "Kid6"])
        #expect(board.court(board.courtTwo).isEmpty)
        // `MainTabView` is the only place this app reports a failed write, and it reads exactly
        // this. A rollback with no banner is a gesture that silently did nothing.
        #expect(board.store.errorMessage == SycamoreError.unknownCamp.errorDescription)
    }

    /// The half-failure, and **the limit of a store-held rollback**, pinned rather than papered
    /// over. Two writes with no transaction between them can land in this state — a court deleted
    /// from another phone between the two — and a `Camp` snapshot can only put back the copy this
    /// process holds. The ladder the first call committed stays committed.
    ///
    /// So the screen is right, the banner is right, and the backend is a write ahead. That gap
    /// closes when `SycamoreRepository` grows a verb for the whole landing — one call, one
    /// transaction — which is the change `AppStore.land`'s own doc asks for and which touches
    /// `Store/Repository.swift` and both of its implementations. Asserted both ways here so that
    /// whoever makes it finds this test in front of them rather than behind them.
    @Test("A second write that fails restores the screen, and cannot unwrite the first")
    func aHalfFailureRestoresWhatItHolds() async throws {
        let board = Board()
        let before = try #require(board.store.camp)
        let vanished = Group.ID()
        let plan = try #require(board.plan(moving: "Kid5", to: board.courtTwo, above: nil))

        // The ladder is fine and lands; the court named alongside it is one the camp does not
        // hold, so `reorderGroup` throws after `reorderCamp` has already written.
        await board.store.land(plan, in: vanished)

        #expect(board.store.camp == before)
        #expect(board.ladder == ["Kid1", "Kid2", "Kid3", "Kid4", "Kid5", "Kid6"])
        #expect(board.store.errorMessage == SycamoreError.unknownGroup.errorDescription)

        // The half that got through. Kid5 is at the back of the venue's ladder there and at their
        // old rank here — change this line when the repository grows the transaction, do not
        // delete it.
        let stored = try await board.repository.camp(id: before.id)
        #expect(Fixture.ladder(stored) == ["Kid1", "Kid2", "Kid3", "Kid4", "Kid6", "Kid5"])
    }

    @Test("A store with no camp loaded writes nothing and raises nothing")
    func noCampIsNotAFailure() async throws {
        let board = Board()
        let plan = try #require(board.plan(moving: "Kid5", to: board.courtOne, above: "Kid1"))
        board.store.camp = nil

        await board.store.land(plan, in: board.courtOne)

        #expect(board.store.camp == nil)
        #expect(board.store.errorMessage == nil)
    }
}
