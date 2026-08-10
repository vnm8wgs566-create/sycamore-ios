//
//  GroupsUnassignedTests.swift
//  SycamoreTests
//
//  The three claims the Groups tab now makes about a kid with no group, and the one it has always
//  made about the ladder.
//
//  * `AppStore.removeGroup` deletes the group the caller named, leaves its kids standing at the
//    venue, and decrements the count so the deletion does not undo itself on the next upsert. The
//    arithmetic is `Camp.removeGroup(_:from:)`'s and `CampRemoveGroupTests` covers it; what is
//    pinned here is the store applying it optimistically, guarding a stale id, and putting the camp
//    back when the write fails. A rollback is the half nobody exercises by hand — it needs a dead
//    connection at the moment of a delete.
//
//    **And that it survives the round trip**, which for most of this suite's life it did not. The
//    store wrote the deletion out as `updateVenue`, and `syncGroups(for:)` trims a venue's *last*
//    court and re-seats whoever that orphaned — so deleting group 1 of three deleted group 3 as
//    soon as anything reloaded, and the stranded kids were quietly put back on a court. Every test
//    below that removes a group removes one that is **not** the venue's last, because the last is
//    precisely the case where the broken path and the correct one delete the same row; and two of
//    them put a second write through the repository afterwards, which is the moment the old
//    behaviour showed itself. `SycamoreRepository.deleteGroup(_:campID:)` is the verb that closed
//    it.
//
//    Only `InMemoryRepository` is driven here. `SupabaseRepository` is an actor over `URLSession`
//    with no stub layer anywhere in this target, so there is no way to exercise it without a
//    project; what stands in its place is the contract in `InMemoryRepositoryTests` — "a test that
//    pins what `InMemoryRepository` does is a test that says what `SupabaseRepository` owes" — and
//    the round trip is observable offline, which is the half that matters for this defect.
//  * `GroupsVenueSection.unassigned` actually carries those kids to the screen, under the same
//    search and the same chips as the cards, and does not let a venue vanish out from under the one
//    kid a search matched.
//  * `UnassignedReason` says *why*, and says the honest one: the band is re-derivable and is asked
//    first; anyone the band admits is here because a group went.
//
//  And the ladder. Section 8's whole claim is that the numeral beside a kid is their place in the
//  camp, 1…N with no gaps and no restart inside a group — so the last suite asserts that after the
//  two writes that could break it: a drop across a group boundary, and a group being deleted out
//  from under eight kids. Those were checked by reading `Camp.reindex()` and believing it; a claim
//  the whole screen is built on is worth an assertion.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - The store intent

@MainActor
@Suite("AppStore.removeGroup")
struct AppStoreRemoveGroupTests {

    /// Three courts at one venue, nine kids ranked 1…9 dealt evenly across them.
    ///
    /// Dealt rather than left where `Fixture.camp` parks them: the point of every test below is
    /// which kids a deletion touches, and a fixture with everybody on one court cannot tell the
    /// difference between "the right group went" and "any group went".
    @MainActor
    private struct Board {
        let store: AppStore
        let repository: InMemoryRepository
        let venueID: Venue.ID
        /// The venue's courts in their own order, as they stood before anything was deleted.
        let courts: [Group.ID]

        init(repositoryHoldsTheCamp: Bool = true) {
            var camp = Fixture.camp([.init("Home", courts: 3)], players: 9)
            let venueID = camp.orderedVenues[0].id
            camp.evenOut()

            let repository = InMemoryRepository(camps: repositoryHoldsTheCamp ? [camp] : [])
            let store = AppStore(repository: repository)
            store.camp = camp

            self.repository = repository
            self.store = store
            self.venueID = venueID
            self.courts = camp.groups(in: venueID).map(\.id)
        }

        var camp: Camp { store.camp ?? Camp(name: "", sport: .tennis, inviteCode: "", icon: "", tint: .moss) }

        /// Who is at the venue and in no group, by the fixture's names.
        var unassigned: [String] {
            camp.players(in: venueID).filter { $0.groupID == nil }.map(\.firstName)
        }

        /// Each surviving group's number paired with the kids on it, in the venue's own order.
        var shape: [(number: Int, kids: [String])] {
            camp.groups(in: venueID).map { group in
                (group.number, camp.players(inGroup: group.id).map(\.firstName))
            }
        }
    }

    @Test("Removing a group leaves its kids at the venue with no group")
    func kidsStayAtTheVenue() async {
        let board = Board()
        let doomed = board.courts[1]
        let stranded = board.camp.players(inGroup: doomed).map(\.firstName)

        await board.store.removeGroup(doomed, from: board.venueID)

        #expect(board.store.errorMessage == nil)
        #expect(board.camp.group(doomed) == nil)
        #expect(board.unassigned == stranded)
        // Still at the venue and still in the ladder — that is what "unassigned" is supposed to
        // mean, and the difference between it and being removed from the camp.
        #expect(board.camp.players(in: board.venueID).count == 9)
    }

    @Test("The survivors renumber so the venue still reads Group 1 upwards")
    func survivorsRenumber() async {
        let board = Board()
        let before = board.shape

        await board.store.removeGroup(board.courts[0], from: board.venueID)

        #expect(board.shape.map(\.number) == [1, 2])
        // The kids move up a number without changing group: what was Group 2 is Group 1 now, and
        // it is holding exactly the kids it was holding a moment ago.
        #expect(board.shape.map(\.kids) == [before[1].kids, before[2].kids])
    }

    @Test("The venue's group count comes down, so the next upsert does not put it back")
    func theCountComesDown() async {
        let board = Board()

        await board.store.removeGroup(board.courts[0], from: board.venueID)
        #expect(board.camp.venue(board.venueID)?.groupCount == 2)

        // The proof rather than the promise: an upsert is exactly what would re-create a court to
        // reach `groupCount`, so put one through and check the group stays gone.
        let venue = try? #require(board.camp.venue(board.venueID))
        if let venue { await board.store.updateVenue(venue) }
        #expect(board.camp.groups(in: board.venueID).count == 2)

        // `courts[0]` and not `courts[2]`, and the second assertion is the whole reason. This test
        // deleted the venue's **last** court for as long as it existed, which is the one case where
        // `syncGroups(for:)`'s trim happens to remove the group the caller named — so it passed for
        // years against a store that could not delete a middle group at all. Counting the survivors
        // is not enough on its own either: three courts minus one is two whichever one went.
        #expect(board.camp.group(board.courts[0]) == nil)
        #expect(board.camp.groups(in: board.venueID).map(\.id) == [board.courts[1], board.courts[2]])
    }

    /// The reviewer's probe, as a test. Delete a middle group, then put an ordinary write through
    /// the repository — the moment the old implementation undid itself — and read the answer back.
    ///
    /// `setAttendance` is the second write on purpose. It is the most innocuous call in the app
    /// that returns a whole camp, and it says nothing at all about courts, so anything it reports
    /// about which groups exist came from what the repository was actually holding rather than from
    /// an argument this test handed it. A venue write would not do: `syncGroups(for:)` seats every
    /// unassigned kid at the venue onto the smallest court, which is its documented job and would
    /// mask the third assertion below whether the deletion had persisted or not.
    @Test("A middle group is still the one that is gone after the next write comes back")
    func aMiddleGroupStaysGone() async throws {
        let board = Board()
        let doomed = board.courts[1]
        let stranded = board.camp.players(inGroup: doomed).map(\.id)
        #expect(stranded.count == 3)

        await board.store.removeGroup(doomed, from: board.venueID)
        #expect(board.store.errorMessage == nil)

        let anyKid = try #require(board.camp.players.first)
        let reloaded = try await board.repository.setAttendance(
            playerID: anyKid.id, day: .today, present: false, campID: board.camp.id
        )

        // The right group, still gone. Under the bug this read `[courts[0], courts[1]]` — the
        // deleted court back, and the venue's last one gone in its place.
        #expect(reloaded.group(doomed) == nil)
        #expect(reloaded.groups(in: board.venueID).map(\.id) == [board.courts[0], board.courts[2]])
        // Renumbered 1…n with no gap, and labelled to match. A venue reading Court 1, Court 3 has
        // lost a court in a way the screen cannot explain.
        #expect(reloaded.groups(in: board.venueID).map(\.number) == [1, 2])
        #expect(reloaded.groups(in: board.venueID).map(\.label) == ["Court 1", "Court 2"])
        // And the kids are still waiting. `UnassignedReason.groupRemoved` used to be a pre-refresh
        // state — these three were re-seated by whatever wrote next.
        #expect(stranded.allSatisfy { reloaded.player($0)?.groupID == nil })
        #expect(stranded.allSatisfy { reloaded.player($0)?.venueID == board.venueID })
    }

    @Test("The store keeps the graph the repository sends back, not a different one")
    func theStoreAndTheRepositoryAgree() async throws {
        let board = Board()

        await board.store.removeGroup(board.courts[1], from: board.venueID)

        // The old body discarded the returned camp, and had to: it came back holding a deletion
        // nobody asked for. Now the two are the same arithmetic run a round trip apart, so they can
        // be compared — and this is the assertion that would fail first if they ever diverged
        // again, before any screen had a chance to show the difference.
        let stored = try await board.repository.camp(id: board.camp.id)
        #expect(stored == board.camp)
    }

    @Test("A group id that is not at the venue named is left alone")
    func aStaleIdIsRefused() async {
        var camp = Fixture.camp([.init("Home", courts: 2), .init("Away", courts: 2)], players: 4)
        camp.partition()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        let home = camp.orderedVenues[0].id
        let away = camp.orderedVenues[1].id
        let awayCourt = camp.groups(in: away)[0].id

        await store.removeGroup(awayCourt, from: home)

        // Not "the wrong one went" — nothing went. A caller holding a group and a venue that
        // disagree is a screen that has moved on, not permission to delete something else.
        #expect(store.camp?.group(awayCourt) != nil)
        #expect(store.camp?.groups(in: home).count == 2)
        #expect(store.camp?.groups(in: away).count == 2)
    }

    /// The floor, from the store's end. `GroupsView` does not offer the swipe on a venue's only
    /// group, so this is the stale-screen route: the list drew two groups, another device took the
    /// venue to one, and the tap arrives anyway.
    ///
    /// Two assertions and the first is the one worth having. The optimistic pass is
    /// `Camp.removeGroup`, which refuses too — so the group never leaves the screen to be put back
    /// by the rollback, and the reader sees a sentence rather than a group that vanished and
    /// returned under one.
    @Test("A venue's only group is left alone, and the reader is told why")
    func theOnlyGroupIsRefused() async {
        var camp = Fixture.camp([.init("Home", courts: 1)], players: 4)
        camp.evenOut()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        let venueID = camp.orderedVenues[0].id
        let only = camp.groups(in: venueID)[0].id

        await store.removeGroup(only, from: venueID)

        #expect(store.camp == camp)
        #expect(store.camp?.group(only) != nil)
        // The sentence, not `sites_group_count_range`. That is the whole reason the refusal is a
        // `SycamoreError` and not a constraint left to fire.
        #expect(store.errorMessage == SycamoreError.lastGroupAtVenue.errorDescription)
    }

    @Test("A failed write puts every group, kid and rank back")
    func aFailedWriteRollsBack() async {
        // The repository does not hold this camp, so `updateVenue` throws `unknownCamp` — which is
        // how the rest of this suite provokes a failure, there being no failing stub to reach for.
        let board = Board(repositoryHoldsTheCamp: false)
        let before = board.camp

        await board.store.removeGroup(board.courts[1], from: board.venueID)

        #expect(board.store.errorMessage != nil)
        #expect(board.camp == before)
        #expect(board.unassigned.isEmpty)
    }

    @Test("The graph holds the deletion before the repository has answered")
    func theDeletionIsOptimistic() async {
        let board = Board()
        let doomed = board.courts[1]

        // `removeGroup` mutates and only then awaits, so one yield is enough to catch the state in
        // between — the same deterministic trick `AppStoreLandingTests` uses on `land`.
        async let write: Void = board.store.removeGroup(doomed, from: board.venueID)
        await Task.yield()
        #expect(board.camp.group(doomed) == nil)
        await write
    }
}

// MARK: - Reaching the screen

@MainActor
@Suite("The Groups tab surfaces the kids with no group")
struct GroupsUnassignedSectionTests {

    /// One venue, four kids, and the first two of them turned out of their group by an age band.
    ///
    /// Through the band rather than by writing `groupID = nil` by hand, so the fixture exercises
    /// the path the app actually takes: `upsert(_ venue:)` → `syncGroups(for:)` → `admit(_:at:)`.
    @MainActor
    private struct Board {
        let store: AppStore
        let venueID: Venue.ID

        init() {
            var camp = Fixture.camp([.init("Home", courts: 1)], players: 4)
            let venueID = camp.orderedVenues[0].id

            // Kid1 and Kid2 are nine; everybody else stays twelve. `Fixture.camp` builds them all
            // at twelve, so this is the only difference between the two halves.
            for index in camp.players.indices where ["Kid1", "Kid2"].contains(camp.players[index].firstName) {
                camp.players[index].age = 9
            }
            var venue = camp.venue(venueID)
            venue?.ageBand = .from(12)
            if let venue { camp.upsert(venue) }

            let store = AppStore(repository: InMemoryRepository(camps: [camp]))
            store.camp = camp
            store.venueFilter = .venue(venueID)

            self.store = store
            self.venueID = venueID
        }

        var section: GroupsVenueSection? { store.groupsSections.first { $0.id == venueID } }
        var unassigned: [String] { (section?.unassigned ?? []).map { $0.player.firstName } }
    }

    @Test("Kids the band refused reach the screen instead of vanishing off it")
    func theBandsRefusalsAreDrawn() {
        let board = Board()
        #expect(board.unassigned == ["Kid1", "Kid2"])
        // And they are not double-counted: the cards hold the other two and nobody else.
        #expect((board.section?.cards ?? []).flatMap(\.rows).count == 2)
    }

    @Test("A search narrows the waiting kids exactly as it narrows the cards")
    func aSearchNarrowsThem() {
        let board = Board()
        board.store.searchText = "Kid2"

        #expect(board.unassigned == ["Kid2"])
        // The venue survives on the strength of an unplaced kid alone. Before this, a section with
        // no matching cards was dropped — which would have taken the one kid the reader was looking
        // for off the screen along with it.
        #expect(board.section != nil)
        #expect((board.section?.cards ?? []).isEmpty)
    }

    @Test("A search matching nobody at all still drops the venue")
    func aSearchMatchingNobodyDropsTheVenue() {
        let board = Board()
        board.store.searchText = "Nobody"
        #expect(board.section == nil)
    }

    @Test("They arrive in ladder order, not in court-rank order")
    func theyArriveInLadderOrder() {
        let board = Board()
        let ranks = (board.section?.unassigned ?? []).map { $0.player.overallRank }
        #expect(ranks == ranks.sorted())
        // `rank` is the numeral the row draws, and for a kid on no court the only true one is
        // their place in the camp. `courtRank` is `Int.max / 2` for all of them.
        #expect((board.section?.unassigned ?? []).allSatisfy { $0.rank == $0.player.overallRank })
    }
}

// MARK: - Why they have no group

@Suite("Why a kid has no group")
struct UnassignedReasonTests {

    @Test("A kid the band refuses is told it is the band, and the band is named")
    func theBandIsNamed() {
        let reason = UnassignedReason.reason(forAge: 9, at: .from(12))
        #expect(reason == .outsideBand(.from(12)))
        #expect(reason.line == "Outside this venue's 12 & up band")
        #expect(reason.isWarning)
    }

    @Test("A kid the band admits is here because their group went")
    func theResidualIsAGroupThatWent() {
        let reason = UnassignedReason.reason(forAge: 14, at: .from(12))
        #expect(reason == .groupRemoved)
        #expect(reason.line == "Their group was removed")
        // Not a warning: a removed group is a thing that already happened and needs no colour. The
        // band is a rule still being enforced, which the reader may want to change.
        #expect(!reason.isWarning)
    }

    @Test("An unrestricted venue never blames the band")
    func anUnrestrictedVenueBlamesNobody() {
        // Including the kid with no age at all, whom `AgeBand.admits(_:)` refuses at a *restricted*
        // band and admits at an open one. A venue that is not asking cannot be the reason.
        #expect(UnassignedReason.reason(forAge: nil, at: .all) == .groupRemoved)
        #expect(UnassignedReason.reason(forAge: nil, at: .from(12)) == .outsideBand(.from(12)))
    }
}

// MARK: - One ladder, 1…N

@MainActor
@Suite("The rank runs 1…N across the whole camp")
struct GroupsLadderContinuityTests {

    /// Two venues of two courts each and ten kids, partitioned — so the ladder spans venues as well
    /// as groups, which is the case a per-venue renumbering would pass and a camp-wide one has to.
    private func board() -> (store: AppStore, camp: Camp, venueID: Venue.ID, courts: [Group.ID]) {
        var camp = Fixture.camp([.init("Home", courts: 2), .init("Away", courts: 2)], players: 10)
        camp.partition()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        let venueID = camp.orderedVenues[0].id
        return (store, camp, venueID, camp.groups(in: venueID).map(\.id))
    }

    /// Every rank in the camp, in order. The invariant is that this is always `1...N`.
    private func ranks(_ store: AppStore) -> [Int] {
        (store.camp?.players ?? []).map(\.overallRank).sorted()
    }

    @Test("A drop across a group boundary renumbers both sides and leaves no gap")
    func aCrossGroupDropRenumbersBothSides() async throws {
        let (store, camp, venueID, courts) = board()
        let mover = try #require(camp.players(inGroup: courts[0]).last)

        let plan = try #require(
            GroupsLandingPlan(
                moving: mover.id,
                to: GroupsLanding(groupID: courts[1], venueID: venueID, anchor: nil),
                ladder: store.rankAssignments(),
                roster: camp.players(inGroup: courts[1])
            )
        )
        await store.land(plan, in: courts[1])

        #expect(store.errorMessage == nil)
        #expect(ranks(store) == Array(1...10))
        // The band each group covers is a contiguous run with nothing repeated: a rank that
        // restarted inside a group would show up here as a duplicate.
        let placed = (store.camp?.players ?? []).filter { $0.groupID != nil }.map(\.overallRank)
        #expect(Set(placed).count == placed.count)
    }

    @Test("A group being deleted leaves the ladder continuous, kids and all")
    func aDeletionLeavesNoHoleInTheLadder() async {
        let (store, camp, venueID, courts) = board()
        // Counted off the camp rather than written as a literal: `partition()` deals ten kids
        // across two venues by their limits, and a hard-coded five would be asserting the deal
        // rather than the ladder.
        let stranded = camp.players(inGroup: courts[0]).count
        #expect(stranded > 0)

        await store.removeGroup(courts[0], from: venueID)

        #expect(store.errorMessage == nil)
        #expect(ranks(store) == Array(1...10))
        // The kids who lost their group keep their place in the camp. The ladder is the one thing a
        // deletion must not touch — it is what tells anybody where to put them back.
        #expect((store.camp?.players ?? []).filter { $0.groupID == nil }.count == stranded)
    }

    @Test("A kid lifted from no group is never a no-op, wherever they are aimed")
    func aKidFromNoGroupAlwaysMoves() {
        // `isNoop` is what a release over the kid's own boundary falls into. A kid in no group
        // stands either side of nothing, so every landing is a real move — which is what makes the
        // "No group yet" card's rows draggable in the first place.
        let player = Player(
            firstName: "Kid1",
            lastInitial: "T",
            age: 12,
            gender: .x,
            isReturning: false,
            venueID: nil,
            groupID: nil,
            overallRank: 1,
            courtRank: 1
        )
        let row = PlayerRow(id: player.id, player: player, rank: 1, isAway: false, leavesAt: nil)
        let group = Group.ID()
        let venue = Venue.ID()

        let move = GroupsMove(
            row: row,
            sourceGroupID: nil,
            nextRowID: nil,
            origin: .zero,
            slots: [],
            unfolded: []
        )
        let slot = GroupsDropSlot(
            landing: GroupsLanding(groupID: group, venueID: venue, anchor: row.id),
            y: 0,
            rank: 1
        )
        #expect(!move.isNoop(slot))
    }
}
