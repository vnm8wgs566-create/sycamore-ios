//
//  BlockCourtsTests.swift
//  SycamoreTests
//
//  What a block says about its courts: what the editor writes down, what survives a round trip,
//  and what happens to a court id after the court has gone.
//
//  Two halves, and they answer different people.
//
//  The draft half is about the write. `BlockEditorDraft` holds ticks while somebody is deciding
//  and `block()` decides what of that is actually stored — and the interesting case is switching
//  the kind back to "regular", where the ticks stay in the sheet and must not reach the row.
//
//  The repository half is about the two builds agreeing. A block's courts are a child relation in
//  Postgres (`schedule_block_courts`) and a field on a struct offline, which is exactly the split
//  that let coaches diverge on `copySchedule` — the in-memory copy gets its children free, and the
//  real one has to insert them by hand against ids it has just minted. These tests pin the answer
//  from the side that runs without a network, so a Postgres build that forgets the third insert
//  has something to fail against.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("BlockEditorDraft — kind and courts")
struct BlockEditorDraftCourtsTests {

    private static let venueID = UUID()
    private static let courtA = UUID()
    private static let courtB = UUID()

    private func draft(_ kind: ScheduleBlockKind, courts: Set<Group.ID>) -> BlockEditorDraft {
        var draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        draft.title = "Warm-up"
        draft.kind = kind
        draft.courtIDs = courts
        return draft
    }

    @Test("A new block is a regular one with no courts on it")
    func defaultsToRegular() {
        let draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        let block = draft.block()

        #expect(block.kind == .regular)
        #expect(block.courtIDs.isEmpty)
    }

    @Test("An assigned block writes the courts that were ticked")
    func writesTheCourts() {
        let block = draft(.assigned, courts: [Self.courtA, Self.courtB]).block()

        #expect(block.kind == .assigned)
        #expect(Set(block.courtIDs) == [Self.courtA, Self.courtB])
    }

    /// The case that would otherwise leave rows behind: somebody ticks three courts, changes their
    /// mind about the kind, and saves. The ticks stay in the sheet so tapping back does not lose
    /// them; the row gets none of them.
    @Test("Switching back to a regular block drops the courts at the write")
    func regularWritesNoCourts() {
        var draft = draft(.assigned, courts: [Self.courtA, Self.courtB])
        draft.kind = .regular

        // The draft still remembers, which is the point of holding them.
        #expect(draft.courtIDs == [Self.courtA, Self.courtB])
        #expect(draft.block().courtIDs.isEmpty)
        #expect(draft.block().kind == .regular)
    }

    /// The same claim `BlockEditorDraftTests` makes about coaches, for the same reason: two saves
    /// of one selection have to produce one row, or `ScheduleBlock: Equatable` reports a change
    /// where nobody made one.
    @Test("Two saves of the same courts produce the same order")
    func stableOrder() {
        let forwards = draft(.assigned, courts: [Self.courtA, Self.courtB]).block()
        let backwards = draft(.assigned, courts: [Self.courtB, Self.courtA]).block()

        #expect(forwards.courtIDs == backwards.courtIDs)
        #expect(forwards.courtIDs.count == 2)
    }

    @Test("Editing a block reads its kind and courts back into the sheet")
    func editingRoundTrips() {
        let original = ScheduleBlock(
            venueID: Self.venueID,
            day: .tue,
            startsAt: TimeOfDay(9, 0),
            title: "Warm-up",
            kind: .assigned,
            courtIDs: [Self.courtA]
        )

        let draft = BlockEditorDraft(editing: original)

        #expect(draft.kind == .assigned)
        #expect(draft.courtIDs == [Self.courtA])
        #expect(draft.block() == original)
    }

    /// A spread is an action, not a field. Re-opening a saved block must not offer to run last
    /// time's deal again as though it were still pending.
    @Test("A draft never inherits a kid spread from the block it is editing")
    func spreadStartsIdle() {
        let block = ScheduleBlock(
            venueID: Self.venueID,
            day: .tue,
            startsAt: TimeOfDay(9, 0),
            title: "Warm-up",
            kind: .assigned,
            courtIDs: [Self.courtA]
        )

        #expect(BlockEditorDraft(editing: block).spread == .leaveThem)
        #expect(BlockEditorDraft(creatingIn: Self.venueID, day: .tue).spread == .leaveThem)
    }
}

@Suite("BlockEditorDraft — which days it may be moved to")
struct BlockEditorDraftDayTests {

    private func camp(_ days: CampDays) -> Camp {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        camp.days = days
        return camp
    }

    private func draft(on day: Weekday, in camp: Camp) -> BlockEditorDraft {
        BlockEditorDraft(creatingIn: camp.venues[0].id, day: day)
    }

    /// The bug this rule exists for: Schedule draws a chip per camp day, so a block written onto a
    /// day the camp does not run is saved and then invisible.
    @Test("Offers only the days the camp runs")
    func offersTheCampsDays() {
        let camp = camp(.weekdays)
        let draft = draft(on: .tue, in: camp)

        #expect(draft.dayOptions(in: camp) == [.mon, .tue, .wed, .thu, .fri])
        #expect(!draft.isOnAClosedDay(in: camp))
    }

    @Test("A weekend camp offers its weekend")
    func offersAWeekend() {
        let camp = camp([.sat, .sun])
        let draft = draft(on: .sat, in: camp)

        #expect(draft.dayOptions(in: camp) == [.sat, .sun])
    }

    /// Reachable rather than hypothetical: a camp's days are editable after blocks exist.
    @Test("A block left on a closed day keeps its own chip, in calendar order")
    func keepsTheClosedDay() {
        let camp = camp(.weekdays)
        let draft = draft(on: .sat, in: camp)

        #expect(draft.dayOptions(in: camp) == [.mon, .tue, .wed, .thu, .fri, .sat])
        #expect(draft.isOnAClosedDay(in: camp))
    }

    @Test("Moving it off the closed day drops that chip and clears the warning")
    func movingItClearsTheStrayDay() {
        let camp = camp(.weekdays)
        var draft = draft(on: .sat, in: camp)

        draft.day = .mon

        #expect(draft.dayOptions(in: camp) == [.mon, .tue, .wed, .thu, .fri])
        #expect(!draft.isOnAClosedDay(in: camp))
    }

    /// A warning, never a refusal — blocking the commit would make "Delete block" the only way out
    /// of the sheet for somebody who opened it to fix a typo.
    @Test("A closed day does not stop the block being saved")
    func closedDayStillCommits() {
        let camp = camp(.weekdays)
        var draft = draft(on: .sat, in: camp)
        draft.title = "Saturday clinic"

        #expect(draft.isValid)
        #expect(draft.block().day == .sat)
    }

    /// The editor is presented before the camp graph is guaranteed to be in hand. One chip, and it
    /// is the block's own — never an empty row with nothing selected.
    @Test("With no camp in hand it offers the day the block is already on")
    func noCampOffersItsOwnDay() {
        let draft = BlockEditorDraft(creatingIn: UUID(), day: .thu)

        #expect(draft.dayOptions(in: nil) == [.thu])
        #expect(!draft.isOnAClosedDay(in: nil))
    }
}

@Suite("ScheduleBlock — the court line")
struct ScheduleBlockCourtLineTests {

    private static let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 8)

    private static func block(on courts: [Group.ID]) -> ScheduleBlock {
        ScheduleBlock(
            venueID: camp.venues[0].id,
            day: .tue,
            startsAt: TimeOfDay(9, 0),
            title: "Skills rotation",
            kind: .assigned,
            courtIDs: courts
        )
    }

    private static func line(on courtCount: Int) -> String? {
        let courts = Array(camp.groups(in: camp.venues[0].id).prefix(courtCount))
        return block(on: courts.map(\.id)).courtLine(in: courts)
    }

    /// A block with no courts draws no line at all, rather than an empty one.
    @Test("Nothing to say about a block that names no courts")
    func noCourts() {
        #expect(Self.line(on: 0) == nil)
    }

    @Test("One, two and three read as English")
    func joinsThemUp() {
        #expect(Self.line(on: 1) == "Court 1")
        #expect(Self.line(on: 2) == "Court 1 & Court 2")
        #expect(Self.line(on: 3) == "Court 1, Court 2 and Court 3")
        #expect(Self.line(on: 4) == "Court 1, Court 2, Court 3 and Court 4")
    }

    /// The deliberate difference from `coachLine(in:)`, which stops at two and counts the rest.
    /// A court label is short and *which* courts is the whole point of the line.
    @Test("Never truncates the way the coach line does")
    func doesNotTruncate() {
        let line = try? #require(Self.line(on: 4))
        #expect(line?.contains("Court 4") == true)
        #expect(line?.contains("+") == false)
    }

    /// The courts are resolved by the caller and never stored, so a rename in Setup reaches the
    /// timetable — the same contract `coachLine(in:)` keeps for names.
    @Test("Takes the labels as they are now, not as they were when the block was written")
    func followsARename() {
        var camp = Self.camp
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)
        camp.groups[0].label = "Show court"

        let renamed = camp.groups(in: venueID).filter { $0.id == courts[0].id }

        #expect(Self.block(on: [courts[0].id]).courtLine(in: renamed) == "Show court")
    }
}

@Suite("BlockKidSpread")
struct BlockKidSpreadTests {

    /// Four courts, twelve kids, everybody parked on court 1.
    private static func scene() -> (camp: Camp, venueID: Venue.ID, courts: [Group.ID]) {
        let camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 12)
        let venueID = camp.venues[0].id
        return (camp, venueID, camp.groups(in: venueID).map(\.id))
    }

    @Test("Leaving them alone writes nothing")
    func leaveThemIsANoOp() {
        let scene = Self.scene()
        var camp = scene.camp
        let before = Fixture.courtSizes(camp, in: scene.venueID)

        BlockKidSpread.leaveThem.apply(to: &camp, venueID: scene.venueID, courtIDs: scene.courts)

        #expect(Fixture.courtSizes(camp, in: scene.venueID) == before)
    }

    /// The arithmetic is `CampCourtSubsetTests`' business; what is unproven at this layer is that
    /// the three cases route to three different `Camp` calls. One fixture, all three, all
    /// different — which no amount of testing either end alone would catch.
    @Test("The three cases do three different things to the same venue")
    func casesRouteDifferently() {
        let scene = Self.scene()
        var evened = scene.camp
        evened.redistribute(in: scene.venueID)
        let twoCourts = [scene.courts[0], scene.courts[1]]

        var allKids = evened
        BlockKidSpread.allKids.apply(to: &allKids, venueID: scene.venueID, courtIDs: twoCourts)

        var evenly = evened
        BlockKidSpread.evenly.apply(to: &evenly, venueID: scene.venueID, courtIDs: twoCourts)

        var leftAlone = evened
        BlockKidSpread.leaveThem.apply(to: &leftAlone, venueID: scene.venueID, courtIDs: twoCourts)

        // Everybody pulled onto the two courts; only the six already there levelled; nothing.
        #expect(Fixture.courtSizes(allKids, in: scene.venueID) == [6, 6, 0, 0])
        #expect(Fixture.courtSizes(evenly, in: scene.venueID) == [3, 3, 3, 3])
        #expect(Fixture.courtSizes(leftAlone, in: scene.venueID) == [3, 3, 3, 3])
        // …and the two that agree on the sizes still differ, because "evenly" reseated nobody.
        #expect(evenly.players(inGroup: scene.courts[0]) == leftAlone.players(inGroup: scene.courts[0]))
    }

    /// The editor hides the section rather than disabling it, and `AppStore.spreadKids` refuses
    /// early — so this asserts the last line of defence rather than the first.
    @Test("No spread does anything without courts to spread onto")
    func noCourtsIsANoOp() {
        let scene = Self.scene()
        let before = Fixture.courtSizes(scene.camp, in: scene.venueID)

        for spread in BlockKidSpread.allCases {
            var camp = scene.camp
            spread.apply(to: &camp, venueID: scene.venueID, courtIDs: [])
            #expect(Fixture.courtSizes(camp, in: scene.venueID) == before)
        }
    }
}

@Suite("InMemoryRepository — spreading the kids over a block's courts")
struct SpreadKidsRepositoryTests {

    private func loaded() -> (InMemoryRepository, Camp, Venue.ID, [Group.ID]) {
        let camp = SampleData.uclaTennisCamp
        let venueID = camp.orderedVenues[0].id
        return (InMemoryRepository(camps: [camp]), camp, venueID, camp.groups(in: venueID).map(\.id))
    }

    /// The warm-up, end to end through the repository: one court, everybody at the venue on it.
    @Test("All kids lands the whole venue on the block's courts, in one write")
    func allKidsThroughTheRepository() async throws {
        let (repo, camp, venueID, courts) = loaded()
        let headcount = camp.players(in: venueID).count

        let after = try await repo.spreadKids(
            .allKids, overCourts: [courts[0]], atVenue: venueID, campID: camp.id
        )

        #expect(after.players(inGroup: courts[0]).count == headcount)
        #expect(Fixture.courtSizes(after, in: venueID).dropFirst().allSatisfy { $0 == 0 })
    }

    @Test("Divide evenly levels the courts named and leaves the others where they were")
    func evenlyThroughTheRepository() async throws {
        let (repo, camp, venueID, courts) = loaded()
        let pair = [courts[0], courts[1]]
        // Pile both courts' kids onto the first, so levelling has something to do.
        let piled = try await repo.spreadKids(
            .allKids, overCourts: [courts[0]], atVenue: venueID, campID: camp.id
        )
        let elsewhere = Fixture.courtSizes(piled, in: venueID)

        let after = try await repo.spreadKids(
            .evenly, overCourts: pair, atVenue: venueID, campID: camp.id
        )

        let sizes = Fixture.courtSizes(after, in: venueID)
        #expect(sizes[0] == sizes[1] || sizes[0] == sizes[1] + 1)
        #expect(sizes[0] + sizes[1] == elsewhere[0])
        #expect(Array(sizes.dropFirst(2)) == Array(elsewhere.dropFirst(2)))
    }

    /// The whole point of the method being on the repository: one call, one mutation, so the
    /// camp comes back reindexed rather than half-dealt.
    @Test("The camp comes back with its counts already refreshed")
    func reindexesOnTheWayBack() async throws {
        let (repo, camp, venueID, courts) = loaded()

        let after = try await repo.spreadKids(
            .allKids, overCourts: [courts[0], courts[1]], atVenue: venueID, campID: camp.id
        )

        for court in after.groups(in: venueID) {
            #expect(court.playerCount == after.players(inGroup: court.id).count)
            let ranks = after.players(inGroup: court.id).map(\.courtRank)
            #expect(ranks == ranks.indices.map { $0 + 1 })
        }
    }

    @Test("A venue this camp does not have is refused rather than silently doing nothing")
    func refusesAnUnknownVenue() async throws {
        let (repo, camp, _, courts) = loaded()

        await #expect(throws: SycamoreError.unknownVenue) {
            try await repo.spreadKids(
                .allKids, overCourts: [courts[0]], atVenue: UUID(), campID: camp.id
            )
        }
    }
}

@Suite("InMemoryRepository — a block's courts")
struct BlockCourtRepositoryTests {

    private func loaded() -> (InMemoryRepository, Camp, Venue.ID, [Group.ID]) {
        let camp = SampleData.uclaTennisCamp
        let venueID = camp.orderedVenues[0].id
        return (
            InMemoryRepository(camps: [camp]),
            camp,
            venueID,
            camp.groups(in: venueID).map(\.id)
        )
    }

    private func warmUp(_ venueID: Venue.ID, courts: [Group.ID]) -> ScheduleBlock {
        ScheduleBlock(
            venueID: venueID,
            day: .tue,
            startsAt: TimeOfDay(9, 0),
            title: "Warm-up",
            kind: .assigned,
            courtIDs: courts
        )
    }

    @Test("A block keeps its kind and its courts across a write and a read")
    func roundTrips() async throws {
        let (repo, camp, venueID, courts) = loaded()
        let block = warmUp(venueID, courts: [courts[0]])

        let written = try await repo.addScheduleBlock(block, campID: camp.id)

        let stored = try #require(written.first { $0.id == block.id })
        #expect(stored.kind == .assigned)
        #expect(stored.courtIDs == [courts[0]])
    }

    @Test("Editing a block replaces its courts rather than adding to them")
    func updateCovers() async throws {
        let (repo, camp, venueID, courts) = loaded()
        var block = warmUp(venueID, courts: [courts[0], courts[1]])
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        block.courtIDs = [courts[2]]
        let written = try await repo.updateScheduleBlock(block, campID: camp.id)

        #expect(written.first { $0.id == block.id }?.courtIDs == [courts[2]])
    }

    @Test("Turning a block back into a regular one takes its courts off it")
    func backToRegular() async throws {
        let (repo, camp, venueID, courts) = loaded()
        var block = warmUp(venueID, courts: [courts[0]])
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        block.kind = .regular
        block.courtIDs = []
        let written = try await repo.updateScheduleBlock(block, campID: camp.id)

        let stored = try #require(written.first { $0.id == block.id })
        #expect(stored.kind == .regular)
        #expect(stored.courtIDs.isEmpty)
    }

    /// The `copySchedule` trap, from the side that can be run. Postgres mints a fresh uuid per
    /// copied block, so its `schedule_block_courts` rows have to be inserted against the new ids
    /// by hand; this build copies the struct and gets them free. Both have to arrive here.
    @Test("Copying a day copies the courts each block runs on")
    func copyCarriesTheCourts() async throws {
        let (repo, camp, venueID, courts) = loaded()
        let block = warmUp(venueID, courts: [courts[0], courts[1]])
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        let copied = try await repo.copySchedule(
            fromDay: .tue, toDay: .wed, venueID: venueID, campID: camp.id
        )

        let copy = try #require(copied.first)
        #expect(copy.id != block.id)
        #expect(copy.day == .wed)
        #expect(copy.kind == .assigned)
        #expect(Set(copy.courtIDs) == [courts[0], courts[1]])
    }

    /// `schedule_block_courts.group_id` cascades on delete, so Postgres stops returning a court id
    /// the moment the court is gone. Nothing in this build deletes a row on its behalf, so the
    /// read has to filter — otherwise the offline build alone would go on claiming a block runs
    /// somewhere that no longer exists.
    @Test("A court deleted in Setup drops off the blocks that named it")
    func staleCourtsDropOut() async throws {
        var camp = SampleData.uclaTennisCamp
        let venueID = camp.orderedVenues[0].id
        let courts = camp.groups(in: venueID).map(\.id)
        let repo = InMemoryRepository(camps: [camp])
        let block = warmUp(venueID, courts: [courts[0], courts[courts.count - 1]])
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        // Trim the venue by one court, the way `VenueSheet`'s stepper does.
        let venueIndex = try #require(camp.venues.firstIndex { $0.id == venueID })
        camp.venues[venueIndex].groupCount = courts.count - 1
        camp.syncGroups(for: venueID)
        _ = try await repo.updateVenue(camp.venues[venueIndex], campID: camp.id)

        let read = try await repo.scheduleBlocks(forVenue: venueID, day: .tue, campID: camp.id)

        #expect(read.first { $0.id == block.id }?.courtIDs == [courts[0]])
    }

    /// A shape is a timetable, not a roster — `DayShape.blocks` is `(hour, minute, title, detail)`
    /// and names nowhere. Worth pinning because the Postgres insert behind this one writes no
    /// explicit `id`, so it is the one write that could not attach a court row even if a shape
    /// grew one.
    @Test("A day shape writes regular blocks with no courts on them")
    func shapesAreRegular() async throws {
        let (repo, camp, venueID, _) = loaded()

        let blocks = try await repo.applyDayShape(
            .halfDay, toVenue: venueID, day: .thu, campID: camp.id
        )

        #expect(!blocks.isEmpty)
        for block in blocks {
            #expect(block.kind == .regular)
            #expect(block.courtIDs.isEmpty)
        }
    }
}
