//
//  SectionEightScheduleTests.swift
//  SycamoreTests
//
//  Where a block note lives, who is on a block, and the one refusal the app has a sentence for.
//
//  The first of those is the reason this file exists. A note is not a field on a block — it is a
//  row of `inbox_items` carrying `schedule_block_id`, which is what Postgres has always stored and
//  what `InMemoryRepository` now derives rather than duplicates. Two builds that disagree about
//  where a note lives is a bug you can only find by running both, so these tests pin the answer
//  from the side that can be run without a network: add a note, and it has to appear on the block
//  *and* in the day's feed, because there is only one row and both screens read it.
//
//  Same reasoning for the deletions. `inbox_items.schedule_block_id` is `on delete cascade`, so a
//  block taken off the timetable takes its notes with it; an offline build that left them behind
//  would draw them on `8r` attached to nothing.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Notes

@Suite("InMemoryRepository — block notes")
struct BlockNoteTests {

    /// The design's camp, which is the only fixture with staff on it — and the author's name has
    /// to be resolved from somewhere.
    private func loaded() -> (InMemoryRepository, Camp, Venue.ID) {
        let camp = SampleData.uclaTennisCamp
        return (InMemoryRepository(camps: [camp]), camp, camp.orderedVenues[0].id)
    }

    private func block(_ venueID: Venue.ID, at time: TimeOfDay = TimeOfDay(9, 0)) -> ScheduleBlock {
        ScheduleBlock(venueID: venueID, day: .tue, startsAt: time, title: "Skills rotation")
    }

    @Test("A note lands on its block and in the Inbox, because it is one row in both")
    func noteIsAnInboxRow() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        let blocks = try await repo.addBlockNote(
            "net on 4 is loose", to: block, authorID: nil, campID: camp.id
        )

        #expect(blocks.first?.notes.map(\.text) == ["net on 4 is loose"])

        let feed = try await repo.inboxItems(forVenue: venueID, campID: camp.id)
        let note = try #require(feed.first { $0.scheduleBlockID == block.id })
        #expect(note.kind == .note)
        #expect(note.detail == "net on 4 is loose")
        // The block's title, not the note's text — that is what `8r` draws as the row heading and
        // what the Postgres write puts there.
        #expect(note.title == "Skills rotation")
        // One row, seen twice. The id the block hands back is the id the feed holds, which is what
        // makes deleting by id from either screen mean the same thing.
        #expect(blocks.first?.notes.first?.id == note.id)
    }

    @Test("The note carries its author's name, resolved from the roster rather than stored")
    func authorNameResolves() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        let author = try #require(camp.staff.first)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        let blocks = try await repo.addBlockNote(
            "shade tent is up", to: block, authorID: author.id, campID: camp.id
        )

        #expect(blocks.first?.notes.first?.authorName == author.name)
    }

    /// `removeStaff` deactivates rather than deletes, so a note outlives the person who wrote it
    /// and their id stops resolving. Nil is the right answer, not a crash and not a blank string.
    @Test("An author who is no longer on the roster leaves the name empty")
    func authorNameSurvivesADeparture() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        let blocks = try await repo.addBlockNote(
            "two nut allergies", to: block, authorID: UUID(), campID: camp.id
        )

        #expect(blocks.first?.notes.count == 1)
        #expect(blocks.first?.notes.first?.authorName == nil)
    }

    /// `ScheduleBlockCard` pins `notes.first` on the day list, so newest-first would swap the
    /// pinned line out from under a coach every time somebody added one. `BlockCourtCard` used to
    /// pin it a second time on `8l` and `5d` took that away — one reader rather than two, and the
    /// rule is unchanged: the pinned note is the *first* one.
    @Test("Notes come back oldest first, so the pinned line stays put")
    func notesAreOldestFirst() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)

        for text in ["first", "second", "third"] {
            _ = try await repo.addBlockNote(text, to: block, authorID: nil, campID: camp.id)
        }
        let blocks = try await repo.scheduleBlocks(forVenue: venueID, day: .tue, campID: camp.id)

        #expect(blocks.first?.notes.map(\.text) == ["first", "second", "third"])
    }

    /// `ScheduleSampleDay` states its notes inline, which is how every Schedule preview is
    /// populated. They have to survive being stored as rows and read back as notes.
    @Test("A block that arrives carrying notes keeps them, as inbox rows")
    func inlineNotesAreSplitOut() async throws {
        let (repo, camp, venueID) = loaded()
        let author = try #require(camp.staff.first)
        var block = block(venueID)
        block.notes = [
            BlockNote(id: UUID(), text: "cones on the service line", authorName: nil, at: .now),
            BlockNote(id: UUID(), text: "net on 4 is loose", authorName: author.name, at: .now),
        ]

        let blocks = try await repo.addScheduleBlock(block, campID: camp.id)

        #expect(blocks.first?.notes.map(\.text) == ["cones on the service line", "net on 4 is loose"])
        // The name round-trips through an id, because that is what the read resolves.
        #expect(blocks.first?.notes.last?.authorName == author.name)
        let feed = try await repo.inboxItems(forVenue: venueID, campID: camp.id)
        #expect(feed.count { $0.scheduleBlockID == block.id } == 2)
    }

    @Test("Editing a block leaves its notes alone rather than writing them again")
    func updatingABlockDoesNotDuplicateNotes() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)
        _ = try await repo.addBlockNote("net on 4 is loose", to: block, authorID: nil, campID: camp.id)

        var edited = try #require(
            try await repo.scheduleBlocks(forVenue: venueID, day: .tue, campID: camp.id).first
        )
        edited.title = "Match play"
        let blocks = try await repo.updateScheduleBlock(edited, campID: camp.id)

        #expect(blocks.first?.title == "Match play")
        #expect(blocks.first?.notes.count == 1)
        let feed = try await repo.inboxItems(forVenue: venueID, campID: camp.id)
        #expect(feed.count { $0.scheduleBlockID == block.id } == 1)
    }

    @Test("Deleting a note takes it off the block and out of the feed")
    func deletingANote() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)
        let withNote = try await repo.addBlockNote(
            "net on 4 is loose", to: block, authorID: nil, campID: camp.id
        )
        let noteID = try #require(withNote.first?.notes.first?.id)

        let blocks = try await repo.deleteBlockNote(noteID, from: block, campID: camp.id)

        #expect(blocks.first?.notes.isEmpty == true)
        let feed = try await repo.inboxItems(forVenue: venueID, campID: camp.id)
        #expect(feed.contains { $0.id == noteID } == false)
    }

    /// `on delete cascade` on `inbox_items.schedule_block_id`, obeyed by the offline build too.
    @Test("Deleting a block takes its notes with it")
    func deletingABlockCascades() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)
        _ = try await repo.addBlockNote("net on 4 is loose", to: block, authorID: nil, campID: camp.id)

        _ = try await repo.deleteScheduleBlock(block.id, campID: camp.id)

        let feed = try await repo.inboxItems(forVenue: venueID, campID: camp.id)
        #expect(feed.contains { $0.scheduleBlockID == block.id } == false)
    }

    @Test("Starting from a shape replaces the day, notes and all")
    func applyingAShapeCascades() async throws {
        let (repo, camp, venueID) = loaded()
        let block = block(venueID)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)
        _ = try await repo.addBlockNote("net on 4 is loose", to: block, authorID: nil, campID: camp.id)

        let blocks = try await repo.applyDayShape(.halfDay, toVenue: venueID, day: .tue, campID: camp.id)

        #expect(blocks.count == DayShape.halfDay.blocks.count)
        #expect(blocks.allSatisfy { $0.notes.isEmpty })
        let feed = try await repo.inboxItems(forVenue: venueID, campID: camp.id)
        #expect(feed.contains { $0.scheduleBlockID == block.id } == false)
    }

    /// The same argument `copy.status` makes: a copied day starts fresh. Who is *rostered* on a
    /// block is not a fact about one morning, so the coaches are the half that travels.
    @Test("A copied day brings the coaches and leaves the notes behind")
    func copyingADayTakesCoachesNotNotes() async throws {
        let (repo, camp, venueID) = loaded()
        var block = block(venueID)
        block.coachIDs = camp.staff.prefix(2).map(\.id)
        _ = try await repo.addScheduleBlock(block, campID: camp.id)
        _ = try await repo.addBlockNote("net on 4 is loose", to: block, authorID: nil, campID: camp.id)

        let copied = try await repo.copySchedule(
            fromDay: .tue, toDay: .wed, venueID: venueID, campID: camp.id
        )

        #expect(copied.count == 1)
        #expect(copied.first?.coachIDs == block.coachIDs)
        #expect(copied.first?.notes.isEmpty == true)
        // And the morning it was copied from still has its own.
        let source = try await repo.scheduleBlocks(forVenue: venueID, day: .tue, campID: camp.id)
        #expect(source.first?.notes.count == 1)
    }

    @Test("A note against a block that is not there fails, and writes nothing")
    func noteOnAnUnknownBlock() async throws {
        let (repo, camp, venueID) = loaded()

        await #expect(throws: SycamoreError.unknownGroup) {
            try await repo.addBlockNote(
                "net on 4 is loose", to: block(venueID), authorID: nil, campID: camp.id
            )
        }
        #expect(try await repo.inboxItems(forVenue: venueID, campID: camp.id).allSatisfy {
            $0.scheduleBlockID == nil
        })
    }
}

// MARK: - Coaches

@Suite("ScheduleBlock — the coach line")
struct BlockCoachLineTests {

    private let staff = SampleData.uclaTennisCamp.staff

    private func block(_ coachIDs: [StaffMember.ID]) -> ScheduleBlock {
        var block = ScheduleBlock(
            venueID: UUID(), day: .tue, startsAt: TimeOfDay(9, 0), title: "Skills rotation"
        )
        block.coachIDs = coachIDs
        return block
    }

    @Test("Nobody on it reads as nothing, which the card draws as \"Needs a coach\"")
    func emptyIsNil() {
        #expect(block([]).coachLine(in: staff) == nil)
    }

    @Test("One name, then two joined, then the first and a count")
    func theThreeShapes() throws {
        let ids = staff.prefix(3).map(\.id)
        let names = staff.prefix(3).map(\.name)
        try #require(names.count == 3)

        #expect(block([ids[0]]).coachLine(in: staff) == names[0])
        #expect(block([ids[0], ids[1]]).coachLine(in: staff) == "\(names[0]) & \(names[1])")
        #expect(block(Array(ids)).coachLine(in: staff) == "\(names[0]) +2")
    }

    /// A coach removed from the camp is deactivated, not deleted, so their join row outlives them
    /// and the id stops resolving. `compactMap` rather than a force-resolve is the whole point:
    /// the line has to read as if they were never on it.
    @Test("An id that no longer resolves is dropped rather than forced")
    func departedCoachesAreSkipped() throws {
        let present = try #require(staff.first)

        #expect(block([UUID(), present.id]).coachLine(in: staff) == present.name)
        #expect(block([UUID(), UUID()]).coachLine(in: staff) == nil)
    }

    @Test("The roster's order does not decide the line — the block's does")
    func orderComesFromTheBlock() throws {
        let ids = staff.prefix(2).map(\.id)
        let names = staff.prefix(2).map(\.name)
        try #require(names.count == 2)

        #expect(block([ids[1], ids[0]]).coachLine(in: staff) == "\(names[1]) & \(names[0])")
    }
}

// MARK: - Refusals

@Suite("SupabaseError — telling a rule from a stale session")
struct PolicyRefusalTests {

    @Test("403 is the policy answering")
    func forbiddenIsARefusal() {
        #expect(SupabaseError.rejected(status: 403, message: "").isPolicyRefusal)
    }

    /// The two have to stay apart. A 401 is retried once with a fresh token; a 403 would answer
    /// the same way twice, and retrying it is how an account gets locked out by its own app.
    @Test("401 is not — it is the token, and it is the one worth retrying")
    func unauthorisedIsNotARefusal() {
        let expired = SupabaseError.rejected(status: 401, message: "")
        #expect(expired.isPolicyRefusal == false)
        #expect(expired.isExpiredCredential)
    }

    @Test("A unique violation is neither", arguments: [409, 400])
    func otherRejectionsAreNeither(status: Int) {
        let clash = SupabaseError.rejected(status: status, message: "23505: duplicate key")
        #expect(clash.isPolicyRefusal == false)
        #expect(clash.isExpiredCredential == false)
        #expect(clash.isUniqueViolation)
    }

    /// The sentence is the reason the flag exists: `SycamoreError.notPermitted` has been declared
    /// since the first repository and thrown by nothing.
    @Test("The domain has a sentence for it, and it is not the one about access")
    func theTwoSentencesDiffer() {
        #expect(SycamoreError.notPermitted.errorDescription == "Only an admin can do that.")
        #expect(
            SupabaseError.rejected(status: 403, message: "").errorDescription
                != SycamoreError.notPermitted.errorDescription
        )
    }
}
