//
//  OverviewNowTests.swift
//  SycamoreTests
//
//  The block Overview draws at the top of the screen: which one it is, whose names come out of it,
//  what its line reads, and which courts it floats to the front.
//
//  Worth pinning for the reason `OverviewRosterTests` gives about the roster: none of it looks
//  wrong when it is wrong. A card naming yesterday's block still reads as a card. A coach quietly
//  dropped because their id no longer resolves leaves a card that says two people are on a block
//  when three are. A `preferring` that filtered instead of sorting would draw a perfectly tidy
//  screen with a court missing off the bottom of it — and the court would be one with kids
//  standing on it.
//
//  Three questions, in the order the screen asks them:
//
//      OverviewNow.resolve(in:at:staff:)  -> which block, and who is on it
//      headerLine / timeLabel             -> how the header and the card word the same fact
//      preferring(_:)                     -> which courts the block is about
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()

private func block(
    _ title: String,
    from start: TimeOfDay,
    to end: TimeOfDay? = nil,
    coaches: [StaffMember.ID] = [],
    courts: [Group.ID] = [],
    notes: [BlockNote] = []
) -> ScheduleBlock {
    ScheduleBlock(
        venueID: venueID,
        day: .wed,
        startsAt: start,
        endsAt: end,
        title: title,
        notes: notes,
        coachIDs: coaches,
        // Naming courts is what makes a block assigned — `BlockEditorDraft.block()` drops them off
        // a regular one, so a `.regular` block holding court ids is a value the app cannot write.
        // It matters here because `BlockRules.claims` reads the kind before the list: left
        // `.regular`, a block "on Court 1" would claim the whole venue and the per-court tests
        // would pass for the wrong reason.
        kind: courts.isEmpty ? .regular : .assigned,
        courtIDs: courts
    )
}

private func coach(_ name: String) -> StaffMember {
    StaffMember(name: name, role: .worker)
}

private func note(_ text: String) -> BlockNote {
    BlockNote(id: UUID(), text: text, authorName: nil, at: .now)
}

private func court(_ rank: Int) -> CourtCard {
    CourtCard(
        id: Group.ID(),
        venueID: venueID,
        groupName: "Group \(rank)",
        courtLabel: "Court \(rank)",
        rankOrder: rank,
        coachID: nil,
        coachName: nil,
        playersHere: 8,
        activity: nil,
        status: .open
    )
}

// MARK: - Which block, and who is on it

@Suite("OverviewNow.resolve")
struct OverviewNowResolveTests {

    @Test("The running block is the one the model names, not one of our own choosing")
    func agreesWithTheModel() {
        let blocks = [
            block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(9, 30)),
            block("Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30)),
            block("Lunch", from: TimeOfDay(12, 0)),
        ]
        let time = TimeOfDay(10, 0)

        let now = OverviewNow.resolve(in: blocks, at: time, staff: [])

        // `.first`, because the model answers with every block running at once now. An admin —
        // which is what `onCourt: nil` means — reads the earliest of them; see `OverviewNow.resolve`.
        #expect(now?.block == ScheduleBlock.running(in: blocks, at: time).first)
        #expect(now?.title == "Skills rotation")
    }

    /// The gap between blocks is a real state and the card has to be absent for it, not stuck on
    /// the block that has finished.
    @Test("Nothing running resolves to nothing")
    func nothingRunning() {
        let blocks = [block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(9, 30))]

        #expect(OverviewNow.resolve(in: blocks, at: TimeOfDay(9, 45), staff: []) == nil)
        #expect(OverviewNow.resolve(in: blocks, at: TimeOfDay(8, 0), staff: []) == nil)
        #expect(OverviewNow.resolve(in: [], at: TimeOfDay(9, 45), staff: []) == nil)
    }

    @Test("The block's coaches come back as people, in the order the block names them")
    func coachesResolveInOrder() {
        let nass = coach("Nass")
        let alina = coach("Alina")
        let tom = coach("Tom")
        let running = block("Skills rotation", from: TimeOfDay(9, 0), coaches: [alina.id, nass.id])

        let now = OverviewNow.resolve(
            in: [running], at: TimeOfDay(9, 30), staff: [nass, alina, tom]
        )

        #expect(now?.coaches.map(\.name) == ["Alina", "Nass"])
    }

    /// "Remove from camp" deactivates rather than deletes, so a departed coach keeps their
    /// `schedule_block_coaches` row while dropping out of `staff`. An id that resolves to nobody is
    /// ordinary — and force-resolving it would crash the first tab a camp opened after a coach left.
    @Test("A coach who has left the camp is dropped, not faked")
    func departedCoachesAreDropped() {
        let nass = coach("Nass")
        let departed = StaffMember.ID()
        let running = block("Skills rotation", from: TimeOfDay(9, 0), coaches: [departed, nass.id])

        let now = OverviewNow.resolve(in: [running], at: TimeOfDay(9, 30), staff: [nass])

        #expect(now?.coaches.map(\.name) == ["Nass"])
    }

    @Test("A block nobody is on resolves to a block with nobody on it")
    func nobodyOnIt() {
        let running = block("Lunch", from: TimeOfDay(12, 0))

        let now = OverviewNow.resolve(in: [running], at: TimeOfDay(12, 15), staff: [coach("Nass")])

        #expect(now?.coaches.isEmpty == true)
    }

    /// The card sits at the top of a screen that already knows whose court it is drawing, and a
    /// venue can now be running two blocks at once. `ScheduleBlock.running(on:in:at:)` is where
    /// this is pinned properly; here it is only that `resolve` asks it with the right court.
    @Test("The card is about the reader's own court")
    func theCardFollowsTheReader() {
        let court1 = Group.ID()
        let court2 = Group.ID()
        let day = [
            block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(9, 15), courts: [court1]),
            block("Free play", from: TimeOfDay(9, 0), to: TimeOfDay(10, 0), courts: [court2]),
        ]

        let onOne = OverviewNow.resolve(in: day, at: TimeOfDay(9, 10), staff: [], onCourt: court1)
        let onTwo = OverviewNow.resolve(in: day, at: TimeOfDay(9, 10), staff: [], onCourt: court2)

        #expect(onOne?.title == "Warm-up")
        #expect(onTwo?.title == "Free play")
    }

    /// Nil rather than the other court's block. A coach whose warm-up has finished is between
    /// blocks even while the rest of the venue is mid-session, and the card has to be absent for
    /// that — which is the state the venue-wide rule could not express.
    @Test("A reader whose own court is between blocks gets no card")
    func nothingOnMyCourt() {
        let court1 = Group.ID()
        let court2 = Group.ID()
        let day = [
            block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(9, 15), courts: [court1]),
            block("Free play", from: TimeOfDay(9, 0), to: TimeOfDay(10, 0), courts: [court2]),
        ]

        #expect(OverviewNow.resolve(in: day, at: TimeOfDay(9, 20), staff: [], onCourt: court1) == nil)
        #expect(
            OverviewNow.resolve(in: day, at: TimeOfDay(9, 20), staff: [], onCourt: court2)?.title
                == "Free play"
        )
    }

    /// An admin is standing on all of them. One card, and the earliest-started of the running
    /// blocks fills it — see `resolve` for why that is a choice rather than an obvious answer.
    @Test("An admin, who has no court, gets the earliest block running")
    func anAdminGetsTheEarliest() {
        let warmUp = block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(11, 0), courts: [Group.ID()])
        let later = block("Free play", from: TimeOfDay(9, 30), to: TimeOfDay(11, 0), courts: [Group.ID()])

        // Handed the later one first, so a `first` that trusted the array would answer "Free play".
        let now = OverviewNow.resolve(in: [later, warmUp], at: TimeOfDay(10, 0), staff: [])

        #expect(now?.title == "Warm-up")
    }

    @Test("The instruction and every note come through, not just the first")
    func instructionAndNotes() {
        var running = block(
            "Skills rotation",
            from: TimeOfDay(9, 0),
            notes: [note("two nut allergies"), note("ball machine on Court 1")]
        )
        running.detail = "Cross-court forehand feeds."

        let now = OverviewNow.resolve(in: [running], at: TimeOfDay(9, 30), staff: [])

        #expect(now?.instruction == "Cross-court forehand feeds.")
        #expect(now?.notes.map(\.text) == ["two nut allergies", "ball machine on Court 1"])
    }
}

// MARK: - How it words itself

@Suite("OverviewNow — the line")
struct OverviewNowLineTests {

    private func now(_ block: ScheduleBlock) -> OverviewNow {
        OverviewNow(block: block, coaches: [])
    }

    @Test("A block with an end reads until it")
    func untilTheEnd() {
        let subject = now(block("Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30)))

        #expect(subject.timeLabel == "until 10:30")
        #expect(subject.headerLine == "Skills rotation · until 10:30")
    }

    /// The endless block used to draw its bare title, which read as a block with no hours rather
    /// than one with no finish.
    @Test("A block with no end reads from its start")
    func fromTheStart() {
        let subject = now(block("Lunch", from: TimeOfDay(12, 0)))

        #expect(subject.timeLabel == "from 12:00")
        #expect(subject.headerLine == "Lunch · from 12:00")
    }
}

// MARK: - Which courts it is about

@Suite("OverviewNow.preferring")
struct OverviewNowPreferringTests {

    @Test("A block that names no courts leaves the order exactly as it found it")
    func namingNoneIsTheIdentity() {
        let courts = (1...4).map { court($0) }
        let subject = OverviewNow(block: block("Lunch", from: TimeOfDay(12, 0)), coaches: [])

        #expect(subject.preferring(courts) == courts)
    }

    @Test("The courts the block names come first")
    func namedCourtsFloat() {
        let courts = (1...4).map { court($0) }
        let named = [courts[2].id, courts[3].id]
        let subject = OverviewNow(block: block("Warm-up", from: TimeOfDay(9, 0), courts: named), coaches: [])

        #expect(subject.preferring(courts).map(\.rankOrder) == [3, 4, 1, 2])
    }

    /// A sort, deliberately not a filter. A block on Courts 1–2 is saying where the warm-up
    /// happens; Court 4 still has kids on it, and Overview exists to answer where a child is.
    @Test("No court is ever dropped")
    func nothingIsFilteredOut() {
        let courts = (1...4).map { court($0) }
        let named = [courts[1].id]
        let subject = OverviewNow(block: block("Warm-up", from: TimeOfDay(9, 0), courts: named), coaches: [])

        let ordered = subject.preferring(courts)

        #expect(ordered.count == courts.count)
        #expect(Set(ordered.map(\.id)) == Set(courts.map(\.id)))
    }

    /// Rank order is what the numbers on the cards mean, so two courts that tie on "named by the
    /// block" must not swap.
    @Test("Rank order survives inside each half")
    func stableWithinEachHalf() {
        let courts = (1...6).map { court($0) }
        let named = [courts[4].id, courts[1].id]
        let subject = OverviewNow(block: block("Warm-up", from: TimeOfDay(9, 0), courts: named), coaches: [])

        #expect(subject.preferring(courts).map(\.rankOrder) == [2, 5, 1, 3, 4, 6])
    }

    /// The column is written by an editor that is still being wired, so a block can name a court
    /// this venue does not have — a court closed, or a block copied from another day.
    @Test("A named court the venue does not have is simply not there")
    func namingAnAbsentCourt() {
        let courts = (1...3).map { court($0) }
        let stranger = Group.ID()
        let subject = OverviewNow(block: block("Warm-up", from: TimeOfDay(9, 0), courts: [stranger]), coaches: [])

        #expect(subject.preferring(courts) == courts)
    }
}
