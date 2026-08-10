//
//  BlockStaffingTests.swift
//  SycamoreTests
//
//  The three decisions `4d` and `5d` make that are not drawings.
//
//  **Who the picker offers first.** `BlockCoachPicker.pool` lifts the signed-in person to the very
//  top of the list, and that is right on a checklist where the row somebody is hunting for is
//  their own. `4d` asks a different question — "who can I have at quarter to eleven" — and a
//  reader who is booked solid sitting above three free coaches is that question answered badly.
//  `ordered(_:by:)` sorts the tiers and lets the pool's order, "you first" included, survive inside
//  each one. The test that matters is `youStayFirstOnlyInsideYourOwnTier`: both halves of that
//  sentence, in one assertion.
//
//  **Which coaches a court has.** `ScheduleBlock.coachIDs(onCourt:)` carries an asymmetry that is
//  easy to read as a bug and is the whole point of the column — a court with *no* staffing entry
//  falls back to the block's coaches, and a court with an entry that is *empty* does not. Those are
//  different facts: not staffed per court, and staffed with nobody. Only the second is somebody's
//  problem this morning, and only the second draws amber.
//
//  **How the two new headers spell an hour.** Both frames drop the meridiem, and the app's
//  `timeLabel` does not. These pin the design's spelling literally rather than by shape — a test
//  that asserted "contains a dash" would pass on `10:45am – 12:15pm`, which is the exact string
//  this is here to keep off those two screens.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()
private let court1 = Group.ID()
private let court2 = Group.ID()

private let camp: Camp = {
    var camp = Camp(name: "Test Camp", sport: .tennis, inviteCode: "TST-0001", icon: "🌳", tint: .moss)
    camp.groups = [
        Group(id: court1, venueID: venueID, number: 1, label: "Court 1", rankOrder: 1, capacity: 8),
        Group(id: court2, venueID: venueID, number: 2, label: "Court 2", rankOrder: 2, capacity: 8),
    ]
    return camp
}()

private func staff(_ name: String) -> StaffMember {
    StaffMember(id: StaffMember.ID(), name: name, role: .worker)
}

private func block(
    _ title: String = "Match play",
    _ start: TimeOfDay = TimeOfDay(10, 45),
    _ end: TimeOfDay? = TimeOfDay(12, 15),
    coaches: [StaffMember.ID] = [],
    staffing: [BlockCourtStaffing] = []
) -> ScheduleBlock {
    ScheduleBlock(
        venueID: venueID,
        day: .tue,
        startsAt: start,
        endsAt: end,
        title: title,
        coachIDs: coaches,
        kind: staffing.isEmpty && coaches.isEmpty ? .regular : .assigned,
        courtIDs: [court1, court2],
        staffing: staffing
    )
}

// MARK: - The order of `4d`'s list

@Suite("BlockCourtStaffingSheet — the order of the list")
struct BlockStaffingOrderTests {

    /// The design's own three rows, in the design's own order: Hubert free, Alina free at 10:30,
    /// Tom on Court 3 (`design/rebuild/section-t4.html:226-240`).
    @Test("Free, then free later, then conflicted")
    func tiersSortFirst() {
        let hubert = staff("Hubert")
        let alina = staff("Alina")
        let tom = staff("Tom")

        // Handed in worst-first, so a function that did nothing would fail this.
        let ordered = BlockCourtStaffingSheet.ordered(
            [tom, alina, hubert],
            by: [
                tom.id: .busy(court: "Court 3", blockTitle: "Skills stations"),
                alina.id: .freesAt(TimeOfDay(10, 30), court: "Court 2"),
                hubert.id: .free(where: "roaming"),
            ]
        )

        #expect(ordered.map(\.name) == ["Hubert", "Alina", "Tom"])
    }

    /// The pool's order is the design's order for a list of people at a venue, and the sort must
    /// not disturb it inside a tier. `Array.sorted` is not documented stable, which is why the
    /// implementation carries the original index as its tiebreak rather than trusting it.
    @Test("Inside one tier the pool's order survives untouched")
    func poolOrderSurvivesInsideATier() {
        let people = (1...6).map { staff("Coach \($0)") }
        let free = people.reduce(into: [StaffMember.ID: CoachAvailability]()) {
            $0[$1.id] = .free(where: "no court")
        }

        #expect(BlockCourtStaffingSheet.ordered(people, by: free).map(\.name) == people.map(\.name))
    }

    /// The one behaviour this function exists for. `pool` puts you at the top of the whole list;
    /// here you keep that only among the people in the same state you are.
    @Test("You stay first only inside your own tier")
    func youStayFirstOnlyInsideYourOwnTier() {
        let me = staff("Alex")
        let hubert = staff("Hubert")
        let alina = staff("Alina")

        let ordered = BlockCourtStaffingSheet.ordered(
            // `pool`'s output: you first, then the rest in the venue's order.
            [me, hubert, alina],
            by: [
                me.id: .busy(court: "Court 1", blockTitle: "Warm-up"),
                hubert.id: .free(where: "roaming"),
                alina.id: .busy(court: "Court 2", blockTitle: "Warm-up"),
            ]
        )

        // Below the free coach, because a booked reader is not the answer to "who can I have".
        // Above the other conflicted one, because among equals the pool's lift still holds.
        #expect(ordered.map(\.name) == ["Hubert", "Alex", "Alina"])
    }

    /// The camp had not loaded when the rows were built, so nothing is known about anybody. Ranked
    /// with the free, which is the only tier that makes no claim the app cannot back up — and the
    /// list must still come out in the order it went in.
    @Test("A pool with no availability yet keeps the pool's order")
    func unknownAvailabilityRanksWithTheFree() {
        let people = [staff("Alex"), staff("Hubert"), staff("Alina")]

        #expect(BlockCourtStaffingSheet.ordered(people, by: [:]).map(\.name) == people.map(\.name))
    }
}

// MARK: - Who `5d` draws on a court

@Suite("BlockCourtCard — who is on one court")
struct BlockCourtStaffingResolveTests {

    @Test("A court with its own staffing shows that coach and not the block's")
    func perCourtStaffingWins() {
        let nass = staff("Nass")
        let alina = staff("Alina")
        var camp = camp
        camp.staff = [nass, alina]

        let target = block(
            coaches: [alina.id],
            staffing: [BlockCourtStaffing(courtID: court1, coachIDs: [nass.id])]
        )

        #expect(BlockCourtCard.coaches(on: target, court: court1, in: camp).map(\.name) == ["Nass"])
    }

    /// The back catalogue: every block written before per-court staffing existed carries its
    /// coaches on `coachIDs` and nothing in `staffing`. A card that consulted `staffing` alone
    /// would report every one of those courts as empty.
    @Test("A court with no staffing entry falls back to whoever runs the block")
    func noEntryFallsBackToTheBlock() {
        let nass = staff("Nass")
        var camp = camp
        camp.staff = [nass]

        let target = block(coaches: [nass.id])

        #expect(BlockCourtCard.coaches(on: target, court: court1, in: camp).map(\.name) == ["Nass"])
        #expect(BlockCourtCard.coaches(on: target, court: court2, in: camp).map(\.name) == ["Nass"])
    }

    /// The state somebody reaches by opening `4d` on a court and leaving without picking, and the
    /// one `5d` draws in amber. It must not fall back, or the gap disappears the moment anybody is
    /// on the block at all.
    @Test("A court staffed with nobody stays empty and does not fall back")
    func anEmptyEntryIsNotAnAbsentOne() {
        let nass = staff("Nass")
        var camp = camp
        camp.staff = [nass]

        let target = block(
            coaches: [nass.id],
            staffing: [BlockCourtStaffing(courtID: court2, coachIDs: [])]
        )

        #expect(BlockCourtCard.coaches(on: target, court: court2, in: camp).isEmpty)
        // …and the court beside it still falls back, so this is a fact about one court rather
        // than a switch thrown for the whole block.
        #expect(BlockCourtCard.coaches(on: target, court: court1, in: camp).map(\.name) == ["Nass"])
    }

    /// A `.regular` block names no courts, so the only question is who runs the block.
    @Test("No court named asks the block-wide question")
    func noCourtIsTheBlockWideQuestion() {
        let nass = staff("Nass")
        let alina = staff("Alina")
        var camp = camp
        camp.staff = [nass, alina]

        let target = block("Lunch", coaches: [nass.id, alina.id])

        #expect(
            BlockCourtCard.coaches(on: target, court: nil, in: camp).map(\.name) == ["Nass", "Alina"]
        )
    }

    /// "Remove from camp" deactivates rather than deletes, so an id on a block outlives the
    /// person's presence in `camp.staff`. That row is a fact about last Tuesday; it drops out
    /// rather than taking the screen with it.
    @Test("A coach who has left the camp drops out rather than crashing the card")
    func aDepartedCoachDropsOut() {
        let nass = staff("Nass")
        var camp = camp
        camp.staff = [nass]

        let target = block(
            staffing: [BlockCourtStaffing(courtID: court1, coachIDs: [StaffMember.ID(), nass.id])]
        )

        #expect(BlockCourtCard.coaches(on: target, court: court1, in: camp).map(\.name) == ["Nass"])
    }
}

// MARK: - How the two new headers spell an hour

@Suite("ScheduleBlock — the meridiem-less hours")
struct BlockShortTimeLabelTests {

    @Test("A block with an end reads 10:45 – 12:15")
    func aRangeDropsTheMeridiems() {
        let target = block()

        #expect(target.shortTimeLabel == "10:45 – 12:15")
        // The long form is still the long form. If these two ever agree, one of them has been
        // changed by accident.
        #expect(target.timeLabel == "10:45am – 12:15pm")
    }

    @Test("A block with no stated end reads its start alone")
    func anOpenEndPrintsOneTime() {
        #expect(block("Drop-off", TimeOfDay(8, 30), nil).shortTimeLabel == "8:30")
    }

    /// Noon and midnight are where a twelve-hour clock without a meridiem is easiest to get wrong
    /// — `hour % 12` is 0 for both, and printing "0:00" is the failure mode.
    @Test("Noon reads 12:00 rather than 0:00")
    func noonPrintsTwelve() {
        #expect(block("Lunch", TimeOfDay(12, 0), TimeOfDay(12, 45)).shortTimeLabel == "12:00 – 12:45")
    }
}
