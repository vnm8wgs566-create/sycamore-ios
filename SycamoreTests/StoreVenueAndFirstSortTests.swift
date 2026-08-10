//
//  StoreVenueAndFirstSortTests.swift
//  SycamoreTests
//
//  The three store-layer changes section 4 asked for, and the one repository symmetry they leaned
//  on. None of the four is visible in a screenshot and none of them has a screen yet.
//
//  * `readVenueID` gained a fourth step in front of its three, so 4a's venue pill has something to
//    write. The sharp half is not the precedence — it is what `selectVenue` does to the rows that
//    were already on screen when the venue changed underneath them.
//  * `finishFirstSort` composes a camp-wide ladder out of one venue's sort. The part worth pinning
//    is the tail: `FirstSort.playerIDs()` is `ladder + skipped`, which is the whole roll only once
//    the sort has settled, and a kid who is in neither must not fall out of the assignment.
//  * A block's per-court staffing has to survive the round trip both builds make, and has to stop
//    naming a court the camp no longer has. The Postgres side gets that from
//    `schedule_block_coaches.group_id`'s `on delete cascade`; the offline side has to be told, and
//    a divergence between the two is the class of bug `SectionEightRepository` has already been
//    caught in twice.
//
//  Driven through `InMemoryRepository` the way the rest of the store suites are, and failure is
//  provoked the same way they provoke it — by naming a camp the repository does not hold — because
//  there is no failing stub and a decorator over a sixty-five-method protocol would be more
//  machinery than these tests are worth.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Which venue section 8 is reading

@MainActor
@Suite("AppStore venue choice")
struct StoreVenueChoiceTests {

    /// Two venues, so "the other one" is a real place rather than a hypothetical.
    private static func twoVenueCamp() -> Camp {
        Fixture.camp([.init("Home", courts: 2), .init("Away", courts: 2)], players: 6)
    }

    @Test("With nothing chosen, the reads still fall through to the camp's first venue")
    func fallsThroughWhenNothingIsChosen() {
        let camp = Self.twoVenueCamp()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        #expect(store.chosenVenueID == nil)
        #expect(store.readVenueID == camp.orderedVenues[0].id)
    }

    @Test("A chosen venue outranks the fallback, which is what makes the pill a control")
    func aChoiceOutranksTheFallback() async {
        let camp = Self.twoVenueCamp()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        let away = camp.orderedVenues[1].id

        store.selectVenue(away)

        #expect(store.readVenueID == away)
        // Nothing has been read, and that is the intent's whole shape now. `selectVenue` writes the
        // choice and empties the two per-venue lists; the reload belongs to Overview's `.task(id:)`,
        // which is keyed on `readVenueID` (`OverviewView.swift:67`) and therefore already re-fires
        // on this write. It used to `await loadOverview()` here as well, which meant one tap issued
        // the same three reads twice over.
        #expect(store.courts.isEmpty)
        #expect(store.scheduleBlocks.isEmpty)

        // And that read, when the screen makes it, follows the choice rather than merely the
        // property: a switch that retargeted `readVenueID` and left Overview on the old venue's
        // courts would be worse than no switch.
        await store.loadOverview()

        #expect(!store.courts.isEmpty)
        #expect(store.courts.allSatisfy { $0.venueID == away })
    }

    /// The one that matters, and the reason the clearing is in the intent rather than in the load.
    ///
    /// `loadOverview` assigns only once each read has returned and never clears first — deliberate,
    /// because on a reload of the *same* venue an empty grid flashing between two identical answers
    /// is worse than a moment of yesterday's numbers. Switching venue inverts that. If the read
    /// then fails, the stale rows are another venue's courts drawn under this venue's name, and
    /// nothing on screen says so.
    ///
    /// Two halves now, because the switch and the read are two acts rather than one: the rows go
    /// the instant the venue changes, and the read that follows — Overview's, driven here by
    /// calling it directly — cannot put them back when it fails.
    @Test("A failed read after a venue switch leaves no rows behind, not the other venue's")
    func aFailedReadLeavesNothingStale() async {
        let camp = Self.twoVenueCamp()
        // The store holds the camp; the repository does not, so every read against it raises.
        let store = AppStore(repository: InMemoryRepository(camps: []))
        store.camp = camp
        let home = camp.orderedVenues[0]
        store.courts = [
            CourtCard(
                id: camp.groups(in: home.id)[0].id,
                venueID: home.id,
                groupName: "Group 1",
                courtLabel: "Court 1",
                rankOrder: 0,
                coachID: nil,
                coachName: nil,
                playersHere: 6,
                activity: nil,
                status: .open
            )
        ]

        store.selectVenue(camp.orderedVenues[1].id)

        // Gone before anything is read at all, which is stronger than this used to pin: while the
        // reload lived inside the intent, the old venue's card survived for as long as the round
        // trip took.
        #expect(store.courts.isEmpty)
        #expect(store.scheduleBlocks.isEmpty)
        #expect(store.errorMessage == nil)

        await store.loadOverview()

        #expect(store.errorMessage != nil)
        #expect(store.courts.isEmpty)
        #expect(store.scheduleBlocks.isEmpty)
    }

    @Test("Switching camps drops the chosen venue, because a venue id belongs to one camp")
    func aCampSwitchDropsTheChoice() {
        let camp = Self.twoVenueCamp()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        store.selectVenue(camp.orderedVenues[1].id)
        #expect(store.chosenVenueID != nil)

        store.switchCamp()

        // Carried across, it would name a venue the next camp does not have — and `readVenueID`
        // would answer it anyway, because the fallback only runs when the choice is nil.
        #expect(store.chosenVenueID == nil)
    }
}

// MARK: - The first sort, written back

@MainActor
@Suite("AppStore.finishFirstSort")
struct StoreFirstSortTests {

    /// Six kids at Home and four at Away, everybody returning so `FirstSort.seeded` opens settled.
    ///
    /// Seeding from `isReturning` is what makes the screen open at "30 of 42 placed" rather than at
    /// zero, and it is also what lets these tests assert about the *composition* without answering
    /// a hundred questions to get there.
    private static func camp() -> Camp {
        var camp = Fixture.camp([.init("Home", courts: 2), .init("Away", courts: 1)], players: 10)
        let away = camp.orderedVenues[1]
        let awayCourt = camp.groups(in: away.id).first?.id
        for index in camp.players.indices {
            camp.players[index].isReturning = true
            // The last four move to the second venue, so there is a section the sort must not touch.
            if index >= 6 {
                camp.players[index].venueID = away.id
                camp.players[index].groupID = awayCourt
            }
        }
        camp.reindex()
        return camp
    }

    private static func store(_ camp: Camp) -> AppStore {
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        return store
    }

    @Test("A settled sort lands as the venue's ladder, and closes the screen behind it")
    func aSettledSortLands() async throws {
        let camp = Self.camp()
        let store = Self.store(camp)
        let home = camp.orderedVenues[0].id
        store.beginFirstSort(in: home)
        #expect(store.pushedScreen == .firstSort(home))

        let sort = try #require(store.firstSort)
        #expect(sort.isSettled)
        let expected = sort.playerIDs()

        await store.finishFirstSort()

        #expect(store.errorMessage == nil)
        #expect(store.firstSort == nil)
        #expect(store.pushedScreen == nil)
        #expect(store.camp?.players(in: home).map(\.id) == expected)
        // Ranks are the camp's, not the venue's: `applyRankOrder` numbers straight through, so the
        // first venue's six take 1…6 and the second venue's four follow.
        #expect(store.camp?.players(in: home).map(\.overallRank) == Array(1...6))
    }

    /// The tail of `finishFirstSort`, and the only part of it that is not a straight substitution.
    ///
    /// `playerIDs()` is `ladder + skipped`, which is the whole roll **as the sort saw it** — and
    /// that is not the same as the roll now. A kid enrolled at the desk while the questions were
    /// being answered is in the camp and not in the sort, which is what this arranges: the sort is
    /// seeded over six kids and the seventh arrives under the open sheet. Without the tail they
    /// would be absent from the assignment, `applyRankOrder` skips what it is not given, and
    /// `reindex` threads them back in on a rank nobody meant.
    ///
    /// This used to arrange the same shortfall by leaving the sort *unsettled* — one kid not
    /// returning, so the seed left them pending — which `finishFirstSort` now refuses outright
    /// (see `anUnsettledSortIsRefused`). The tail is still needed and this is the case that still
    /// reaches it.
    @Test("A kid enrolled under the open sheet is appended to the venue, not dropped from the ladder")
    func aKidEnrolledMidSortSurvives() async throws {
        let camp = Self.camp()
        let home = camp.orderedVenues[0].id
        let newcomer = Player(
            firstName: "Newcomer",
            lastInitial: "T",
            age: 12,
            gender: .x,
            isReturning: true,
            venueID: home,
            groupID: camp.groups(in: home).first?.id,
            overallRank: 99,
            courtRank: 99
        )
        var enrolled = camp
        enrolled.players.append(newcomer)
        enrolled.reindex()

        // The repository holds the camp *with* the newcomer — the desk's write landed there — and
        // the store opens the sort over the graph as it read a moment earlier.
        let store = AppStore(repository: InMemoryRepository(camps: [enrolled]))
        store.camp = camp

        store.beginFirstSort(in: home)
        let sort = try #require(store.firstSort)
        #expect(sort.isSettled)
        #expect(!sort.playerIDs().contains(newcomer.id))

        // The graph catches up under the settled screen, which is what `rankAssignments()` reads.
        store.camp = enrolled

        await store.finishFirstSort()

        let placed = try #require(store.camp?.players(in: home).map(\.id))
        #expect(placed.contains(newcomer.id))
        #expect(placed.last == newcomer.id)
        #expect(placed.count == 7)
    }

    /// The invariant, now that it is the store's and not the screen's.
    ///
    /// One kid is new rather than returning, so the seed leaves them in `pending` and the sort has
    /// not settled — which makes `playerIDs()` six ids for a venue of seven, with the seventh in
    /// neither `ladder` nor `skipped`. Finishing there is the one mistake on `4c` that costs a
    /// child their place, and `FirstSortView` never offers it; the point of the guard is that a
    /// rewrite of the screen cannot reintroduce it.
    ///
    /// Nothing is written and nothing is closed. Leaving `firstSort` and `pushedScreen` standing is
    /// the honest refusal: the sort is still in flight, and clearing them would end a screen that
    /// still has a question on it.
    @Test("An unsettled sort is refused, so nobody in flight can fall out of the ladder")
    func anUnsettledSortIsRefused() async throws {
        var camp = Self.camp()
        let home = camp.orderedVenues[0].id
        camp.players.append(
            Player(
                firstName: "Newcomer",
                lastInitial: "T",
                age: 12,
                gender: .x,
                isReturning: false,
                venueID: home,
                groupID: camp.groups(in: home).first?.id,
                overallRank: 99,
                courtRank: 99
            )
        )
        camp.reindex()
        let store = Self.store(camp)
        let before = camp.players(in: home).map(\.id)

        store.beginFirstSort(in: home)
        let sort = try #require(store.firstSort)
        #expect(!sort.isSettled)

        await store.finishFirstSort()

        #expect(store.firstSort != nil)
        #expect(store.pushedScreen == .firstSort(home))
        #expect(store.camp?.players(in: home).map(\.id) == before)
    }

    /// The second write, which used to be the view's.
    ///
    /// `applyRankOrder` renumbers `overallRank` and moves nobody between courts, so a ladder
    /// committed on its own leaves every court holding whoever it held this morning. The fixture
    /// parks all six Home kids on one of two courts, so a deal that did not run is visible as an
    /// empty second court.
    ///
    /// Venue-scoped, and the second half of the assertion is the whole reason `spreadKids` is the
    /// verb rather than `evenOut()`: Away's four kids are on one court and stay exactly where they
    /// were, because ranking one venue must not rearrange another.
    @Test("Finishing deals this venue's courts, and leaves the other venue's alone")
    func aSettledSortDealsItsOwnCourts() async throws {
        let camp = Self.camp()
        let store = Self.store(camp)
        let home = camp.orderedVenues[0].id
        let away = camp.orderedVenues[1].id
        let homeCourts = camp.groups(in: home).map(\.id)
        #expect(camp.players(inGroup: homeCourts[1]).isEmpty)
        let awayBefore = camp.players(in: away).map { ($0.id, $0.groupID) }

        store.beginFirstSort(in: home)
        await store.finishFirstSort()

        let dealt = try #require(store.camp)
        #expect(dealt.players(inGroup: homeCourts[0]).count == 3)
        #expect(dealt.players(inGroup: homeCourts[1]).count == 3)
        #expect(dealt.players(in: away).map { ($0.id, $0.groupID) }.elementsEqual(awayBefore, by: ==))
    }

    @Test("The other venue's section is handed back untouched")
    func theOtherVenueIsUntouched() async throws {
        let camp = Self.camp()
        let store = Self.store(camp)
        let away = camp.orderedVenues[1].id
        let before = camp.players(in: away).map(\.id)

        store.beginFirstSort(in: camp.orderedVenues[0].id)
        await store.finishFirstSort()

        #expect(store.camp?.players(in: away).map(\.id) == before)
    }

    @Test("An answer with no sort in flight changes nothing rather than trapping")
    func answeringWithNoSortIsANoOp() {
        let store = Self.store(Self.camp())

        store.answerFirstSort(.candidate)
        store.answerFirstSort(.skip)

        #expect(store.firstSort == nil)
    }
}

// MARK: - Per-court staffing, offline

@Suite("Block staffing round trip")
struct BlockStaffingRoundTripTests {

    private static func board() async -> (InMemoryRepository, Camp) {
        let camp = Fixture.camp([.init("Home", courts: 2)], players: 6)
        return (InMemoryRepository(camps: [camp]), camp)
    }

    @Test("Who is on which court survives a write and a read")
    func staffingSurvivesTheRoundTrip() async throws {
        let (repository, camp) = await Self.board()
        let venue = camp.orderedVenues[0]
        let courts = camp.groups(in: venue.id)
        let nass = UUID()
        let alina = UUID()

        let block = ScheduleBlock(
            venueID: venue.id,
            day: .mon,
            startsAt: TimeOfDay(10, 45),
            endsAt: TimeOfDay(12, 0),
            title: "Match play",
            kind: .assigned,
            courtIDs: courts.map(\.id),
            staffing: [
                BlockCourtStaffing(courtID: courts[0].id, coachIDs: [nass]),
                BlockCourtStaffing(courtID: courts[1].id, coachIDs: [alina, nass]),
            ]
        )

        let day = try await repository.addScheduleBlock(block, campID: camp.id)

        let stored = try #require(day.first)
        #expect(stored.staffing.map(\.courtID) == courts.map(\.id))
        #expect(stored.coachIDs(onCourt: courts[0].id) == [nass])
        // The same coach on two courts of one block is the case the widened key exists for, and it
        // has to survive the trip rather than being collapsed into one court on the way.
        #expect(stored.coachIDs(onCourt: courts[1].id) == [alina, nass])
    }

    /// The symmetry with `schedule_block_coaches.group_id`'s `on delete cascade`.
    ///
    /// Postgres stops returning a staffing row the moment its court is deleted. Nothing does that
    /// offline — `Camp.syncGroups(for:)` trims the `Group` rows and never sees this array — so the
    /// read has to filter, exactly as it already filters `courtIDs`. Without it the offline build
    /// would go on naming who is running a court the camp does not have, in the one direction only
    /// the real database can show you.
    @Test("Staffing for a court the camp does not have is dropped on read")
    func staffingForAMissingCourtIsDropped() async throws {
        let (repository, camp) = await Self.board()
        let venue = camp.orderedVenues[0]
        let court = camp.groups(in: venue.id)[0]
        let ghost = UUID()

        let block = ScheduleBlock(
            venueID: venue.id,
            day: .mon,
            startsAt: TimeOfDay(10, 45),
            title: "Match play",
            kind: .assigned,
            courtIDs: [court.id, ghost],
            staffing: [
                BlockCourtStaffing(courtID: court.id, coachIDs: [UUID()]),
                BlockCourtStaffing(courtID: ghost, coachIDs: [UUID()]),
            ]
        )

        let day = try await repository.addScheduleBlock(block, campID: camp.id)

        let stored = try #require(day.first)
        #expect(stored.courtIDs == [court.id])
        #expect(stored.staffing.map(\.courtID) == [court.id])
    }
}
