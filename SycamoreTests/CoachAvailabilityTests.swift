//
//  CoachAvailabilityTests.swift
//  SycamoreTests
//
//  Whether `4d` offers a coach or refuses them, and the grey line under their name.
//
//  The rule this file exists to pin is the one it would be easiest to get wrong by agreeing with
//  the neighbouring rule instead: **an open-ended block occupies the coach standing on it.**
//  `BlockRules.overlaps(_:_:)` says the opposite and argues it well — a block with no stated end
//  clashes with nothing, because every block a `DayShape` writes is open-ended and a flag that
//  fires on the app's own output is a flag nobody reads. That is right for the amber line on `8k`
//  and wrong here: the person running the 8:30 drop-off is not free to take Court 2 at nine
//  merely because nobody typed a finish time in. `openEndedBlockOccupiesTheCoach` is that
//  distinction, and `openEndedBlockIsClosedByWhatStartsNext` is the other half of it — the honest
//  reading of an open end is "until something else takes the space", not "until midnight".
//
//  The copy is pinned literally, not by shape. Every subtitle here is a design literal: sentence
//  case, a `·` with a space either side, `10:30` and never `10:30am`, and lower-case `roaming`
//  mid-sentence where two other screens capitalise it because it stands alone in a column. A test
//  that asserted "contains a middot" would pass on all the wrong strings.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()
private let otherVenueID = Venue.ID()
private let court1 = Group.ID()
private let court2 = Group.ID()
private let court3 = Group.ID()

private let nassID = StaffMember.ID()

/// One venue, three courts. Nothing else is read — `CoachAvailability` resolves a court label and
/// nothing more from the camp.
private let camp: Camp = {
    var camp = Camp(name: "Test Camp", sport: .tennis, inviteCode: "TST-0001", icon: "🌳", tint: .moss)
    camp.groups = [
        Group(id: court1, venueID: venueID, number: 1, label: "Court 1", rankOrder: 1, capacity: 8),
        Group(id: court2, venueID: venueID, number: 2, label: "Court 2", rankOrder: 2, capacity: 8),
        Group(id: court3, venueID: venueID, number: 3, label: "Court 3", rankOrder: 3, capacity: 8),
    ]
    return camp
}()

/// Nass, with whatever standing posting the test is about.
private func nass(
    on court: (id: Group.ID, number: Int, label: String)? = nil, roaming: Bool = false
) -> StaffMember {
    StaffMember(
        id: nassID,
        name: "Nass",
        role: roaming ? .trainer : .worker,
        isRoaming: roaming,
        assignment: court.map {
            CourtAssignment(
                venueID: venueID,
                venueName: "Sycamore",
                venueIcon: "🌳",
                groupID: $0.id,
                groupNumber: $0.number,
                groupLabel: $0.label
            )
        }
    )
}

private func block(
    _ title: String,
    _ start: TimeOfDay,
    _ end: TimeOfDay? = nil,
    on courts: [Group.ID] = [],
    coaches: [StaffMember.ID] = [],
    staffing: [BlockCourtStaffing] = [],
    venue: Venue.ID = venueID,
    day: Weekday = .wed
) -> ScheduleBlock {
    ScheduleBlock(
        venueID: venue,
        day: day,
        startsAt: start,
        endsAt: end,
        title: title,
        coachIDs: coaches,
        // Named courts make it an assigned block — the same convention `RunningBlockTests` uses,
        // and for the same reason: `block()` on the draft drops courts off a regular one.
        kind: courts.isEmpty ? .regular : .assigned,
        courtIDs: courts,
        staffing: staffing
    )
}

@Suite("CoachAvailability")
struct CoachAvailabilityTests {

    // MARK: Free

    @Test("Nobody else has them — free, with where they usually stand")
    func freeOnTheirOwnCourt() {
        let target = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0), on: [court2])
        let member = nass(on: (court3, 3, "Court 3"))

        let state = CoachAvailability.of(member, staffing: target, day: [target], camp: camp)

        #expect(state == .free(where: "Court 3"))
        #expect(state.subtitle == "Free now · Court 3")
        #expect(!state.isConflict)
    }

    @Test("A roamer is free and roaming, lower-case after the middot")
    func freeAndRoaming() {
        let target = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0), on: [court2])
        let member = nass(roaming: true)

        let state = CoachAvailability.of(member, staffing: target, day: [target], camp: camp)

        // `StaffMember.courtChip` writes `Roaming`; this is mid-sentence and takes lower case.
        #expect(state.subtitle == "Free now · roaming")
    }

    @Test("Somebody with no posting at all is free, on no court")
    func freeWithNoPosting() {
        let target = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0), on: [court2])

        let state = CoachAvailability.of(nass(), staffing: target, day: [target], camp: camp)

        #expect(state.subtitle == "Free now · no court")
    }

    @Test("Already on the block being staffed is not a conflict with themselves")
    func notInConflictWithItself() {
        let target = block(
            "Match play", TimeOfDay(10, 45), TimeOfDay(12, 0),
            on: [court1, court2],
            staffing: [BlockCourtStaffing(courtID: court1, coachIDs: [nassID])]
        )
        let member = nass(on: (court1, 1, "Court 1"))

        let state = CoachAvailability.of(member, staffing: target, day: [target], camp: camp)

        // `4d` is where somebody goes to move Nass from Court 1 to Court 2. A picker that greyed
        // out the person it was opened to move would be a dead end.
        #expect(state == .free(where: "Court 1"))
        #expect(!state.isConflict)
    }

    // MARK: Frees part way through

    @Test("A block that ends mid-way through this one frees them at its end")
    func freesPartWayThrough() {
        let busy = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 30),
            on: [court2],
            staffing: [BlockCourtStaffing(courtID: court2, coachIDs: [nassID])]
        )
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")), staffing: target, day: [busy, target], camp: camp
        )

        #expect(state == .freesAt(TimeOfDay(10, 30), court: "Court 2"))
        // `shortLabel`, not `clockLabel` — the design writes `10:30`, never `10:30am`.
        #expect(state.subtitle == "Free at 10:30 · Court 2 until then")
        // A late start is still a start: this row is offered, quietly.
        #expect(!state.isConflict)
    }

    @Test("A block that ends exactly when this one does frees nobody during it")
    func endingTogetherIsAConflict() {
        let busy = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(12, 0),
            on: [court2],
            staffing: [BlockCourtStaffing(courtID: court2, coachIDs: [nassID])]
        )
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(nass(), staffing: target, day: [busy, target], camp: camp)

        #expect(state == .busy(court: "Court 2", blockTitle: "Warm-up"))
        #expect(state.isConflict)
    }

    @Test("A block with no stated end of its own cannot be freed part way through")
    func openEndedTargetCollapsesTheMiddleTier() {
        let busy = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 30),
            on: [court2],
            staffing: [BlockCourtStaffing(courtID: court2, coachIDs: [nassID])]
        )
        let target = block("Match play", TimeOfDay(10, 0), on: [court1])

        let state = CoachAvailability.of(nass(), staffing: target, day: [busy, target], camp: camp)

        // There is no "before this one ends" to be earlier than, so the honest answer is the
        // cautious one rather than a promise the block cannot back.
        #expect(state == .busy(court: "Court 2", blockTitle: "Warm-up"))
    }

    // MARK: Busy

    @Test("A block with no stated end occupies the coach standing on it")
    func openEndedBlockOccupiesTheCoach() {
        // The distinction from `BlockRules.overlaps`, which — asked about this exact pair —
        // reports no clash at all, because the skills stations never said when they finish.
        let busy = block("Skills stations", TimeOfDay(8, 30), on: [court2, court3], coaches: [nassID])
        let target = block("Match play", TimeOfDay(9, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")), staffing: target, day: [busy, target], camp: camp
        )

        #expect(state == .busy(court: "Court 3", blockTitle: "Skills stations"))
        #expect(state.isConflict)
    }

    @Test("An open end is closed by whatever takes the space next")
    func openEndedBlockIsClosedByWhatStartsNext() {
        // The drop-off runs on Court 2 with no stated end; the block being staffed is on Court 1
        // and cannot end it. The huddle is venue-wide, so it can and does.
        let busy = block("Drop-off", TimeOfDay(8, 30), on: [court2], coaches: [nassID])
        let huddle = block("Huddle", TimeOfDay(9, 0))
        let target = block("Match play", TimeOfDay(9, 30), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")),
            staffing: target, day: [busy, huddle, target], camp: camp
        )

        // Not "the drop-off runs all day": the huddle took the venue at nine, so by half past
        // the person who ran the drop-off is available.
        #expect(state == .free(where: "Court 3"))
    }

    @Test("Coaches on the block as a whole are occupied, not only per-court ones")
    func blockWideCoachesCount() {
        // Every block written before per-court staffing existed carries its coaches this way, and
        // so does every whole-camp block written after it. Reading `staffing` alone would report
        // the entire back catalogue as free.
        let busy = block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0), coaches: [nassID])
        let target = block("Match play", TimeOfDay(12, 15), TimeOfDay(13, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")), staffing: target, day: [busy, target], camp: camp
        )

        #expect(state == .busy(court: "Court 3", blockTitle: "Lunch"))
    }

    @Test("The court comes from the block, in words")
    func busySpellsTheCourt() {
        let busy = block(
            "Skills stations", TimeOfDay(9, 0),
            on: [court1, court3],
            staffing: [BlockCourtStaffing(courtID: court3, coachIDs: [nassID])]
        )
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court2])

        let state = CoachAvailability.of(nass(), staffing: target, day: [busy, target], camp: camp)

        #expect(state.subtitle == "On Court 3 · Skills stations")
    }

    // MARK: Which court it names

    @Test("A single-court block names its court even with nothing recorded per-court")
    func fallsBackToTheBlocksOnlyCourt() {
        let busy = block("Skills stations", TimeOfDay(9, 0), on: [court2], coaches: [nassID])
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(nass(), staffing: target, day: [busy, target], camp: camp)

        #expect(state == .busy(court: "Court 2", blockTitle: "Skills stations"))
    }

    @Test("A multi-court block falls back to where the coach usually stands")
    func fallsBackToTheStandingPosting() {
        let busy = block(
            "Skills stations", TimeOfDay(9, 0), on: [court1, court2], coaches: [nassID]
        )
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court3])

        let state = CoachAvailability.of(
            nass(on: (court1, 1, "Court 1")), staffing: target, day: [busy, target], camp: camp
        )

        // Picking one of two courts would be a guess drawn as a fact; the standing posting is at
        // least a fact about that person.
        #expect(state == .busy(court: "Court 1", blockTitle: "Skills stations"))
    }

    @Test("With no court to name at all, the segment goes rather than printing an empty middot")
    func omitsTheCourtRatherThanLeavingAGap() {
        let busy = block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0), coaches: [nassID])
        let target = block("Match play", TimeOfDay(12, 15), TimeOfDay(13, 0), on: [court1])

        let state = CoachAvailability.of(nass(), staffing: target, day: [busy, target], camp: camp)

        #expect(state == .busy(court: nil, blockTitle: "Lunch"))
        #expect(state.subtitle == "Lunch")
        #expect(!state.subtitle.contains("·"))
    }

    @Test("Every case drops a missing segment whole")
    func noCaseEverPrintsATrailingMiddot() {
        let cases: [CoachAvailability] = [
            .free(where: nil),
            .freesAt(TimeOfDay(10, 30), court: nil),
            .busy(court: nil, blockTitle: "Lunch"),
        ]

        #expect(cases.map(\.subtitle) == ["Free now", "Free at 10:30", "Lunch"])
    }

    // MARK: Scope

    @Test("A block at another venue does not occupy them")
    func otherVenuesDoNotCount() {
        let busy = block(
            "Skills stations", TimeOfDay(9, 0), coaches: [nassID], venue: otherVenueID
        )
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")), staffing: target, day: [busy, target], camp: camp
        )

        #expect(state == .free(where: "Court 3"))
    }

    @Test("A block on another day does not occupy them")
    func otherDaysDoNotCount() {
        let busy = block("Skills stations", TimeOfDay(9, 0), coaches: [nassID], day: .thu)
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")), staffing: target, day: [busy, target], camp: camp
        )

        #expect(state == .free(where: "Court 3"))
    }

    @Test("A block that is over before this one starts does not occupy them")
    func finishedBlocksDoNotCount() {
        let busy = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court2], coaches: [nassID]
        )
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])

        let state = CoachAvailability.of(
            nass(on: (court3, 3, "Court 3")), staffing: target, day: [busy, target], camp: camp
        )

        // Half-open, the same reading `BlockRules.overlaps` uses: a block that ends exactly when
        // the next begins is an ordinary camp morning.
        #expect(state == .free(where: "Court 3"))
    }

    @Test("The answer does not depend on the order the day arrives in")
    func orderIndependent() {
        let first = block("Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 30), coaches: [nassID])
        let second = block("Handover", TimeOfDay(9, 30), TimeOfDay(11, 0), coaches: [nassID])
        let target = block("Match play", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court1])
        let member = nass(on: (court3, 3, "Court 3"))

        let forwards = CoachAvailability.of(
            member, staffing: target, day: [first, second, target], camp: camp
        )
        let backwards = CoachAvailability.of(
            member, staffing: target, day: [target, second, first], camp: camp
        )

        // `running(in:at:)` sorts, so the earliest-started block that has them is the one named
        // whichever way the array came. The warm-up starts first and frees them at 10:30.
        #expect(forwards == backwards)
        #expect(forwards == .freesAt(TimeOfDay(10, 30), court: "Court 3"))
    }

    // MARK: The trailing control

    @Test("Only a full conflict makes the row inert")
    func onlyBusyIsAConflict() {
        #expect(!CoachAvailability.free(where: "Court 1").isConflict)
        #expect(!CoachAvailability.freesAt(TimeOfDay(10, 30), court: "Court 1").isConflict)
        #expect(CoachAvailability.busy(court: "Court 1", blockTitle: "Warm-up").isConflict)
    }

    /// The near end of the same three-way question, and the pair has to stay a partition: `.free`
    /// draws the filled `Assign`, `.freesAt` the outlined one, `.busy` no button at all. A case
    /// that answered true to both — or to neither — would be a row with two pills or none.
    @Test("Free now is only the first tier, and the two predicates never overlap")
    func onlyFreeIsFreeNow() {
        let all: [CoachAvailability] = [
            .free(where: "Court 1"),
            .freesAt(TimeOfDay(10, 30), court: "Court 1"),
            .busy(court: "Court 1", blockTitle: "Warm-up"),
        ]

        #expect(all.map(\.isFreeNow) == [true, false, false])
        #expect(all.allSatisfy { !($0.isFreeNow && $0.isConflict) })
    }
}

// MARK: - The whole list at once

/// `map(for:staffing:day:camp:)`, which is what both screens actually call.
///
/// It exists for what it does *not* repeat: everything to the left of the per-member test in
/// `of(_:staffing:day:camp:)` depends only on the block and the day, and both call sites were
/// running it once per coach — `running(in:at:)`, whose `hasFinished` walks the day again for
/// every open-ended block, and every block a `DayShape` writes is open-ended. The block editor's
/// body redraws on every keystroke in the title field.
///
/// So the one thing worth pinning hardest is that it changed nothing: **the same answer as `of`,
/// for everybody, in every shape the suite above tests.** `agreesWithTheSingleMemberSpelling` is
/// that, asserted over a day built to reach all three tiers at once rather than over one case.
@Suite("CoachAvailability.map")
struct CoachAvailabilityMapTests {

    /// Three coaches, one of each tier, against one day.
    ///
    /// Alina's warm-up ends at eleven, inside the target block — `.freesAt`. Tom's runs to noon,
    /// which is when the target block ends too, so it frees him during none of it — `.busy`. Nass
    /// is on nothing at all.
    ///
    /// The open-ended drop-off is scenery and is there on purpose: it is the shape `hasFinished`
    /// walks the whole day for, which is the cost `map` exists to stop paying per coach.
    private static func day() -> (target: ScheduleBlock, day: [ScheduleBlock], people: [StaffMember]) {
        let alina = StaffMember(name: "Alina", role: .worker)
        let tom = StaffMember(name: "Tom", role: .worker)
        let dropOff = block("Drop-off", TimeOfDay(8, 30))
        let warmUp = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(11, 0), on: [court1], coaches: [alina.id]
        )
        let stations = block(
            "Skills stations", TimeOfDay(10, 0), TimeOfDay(12, 0), on: [court3], coaches: [tom.id]
        )
        let target = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0), on: [court2])
        return (
            target,
            [dropOff, warmUp, stations, target],
            [nass(on: (court3, 3, "Court 3")), alina, tom]
        )
    }

    @Test("It agrees with the single-member spelling, for every tier")
    func agreesWithTheSingleMemberSpelling() {
        let (target, day, people) = Self.day()

        let mapped = CoachAvailability.map(for: people, staffing: target, day: day, camp: camp)

        // All three tiers are actually reached, or the agreement below would be three easy cases.
        #expect(mapped[people[0].id] == .free(where: "Court 3"))
        #expect(mapped[people[1].id] == .freesAt(TimeOfDay(11, 0), court: "Court 1"))
        #expect(mapped[people[2].id] == .busy(court: "Court 3", blockTitle: "Skills stations"))

        for member in people {
            #expect(
                mapped[member.id]
                    == CoachAvailability.of(member, staffing: target, day: day, camp: camp)
            )
        }
    }

    @Test("Everybody asked about gets an entry, and nobody else does")
    func oneEntryPerPerson() {
        let (target, day, people) = Self.day()

        let mapped = CoachAvailability.map(for: people, staffing: target, day: day, camp: camp)

        #expect(mapped.count == people.count)
        #expect(Set(mapped.keys) == Set(people.map(\.id)))
        #expect(CoachAvailability.map(for: [], staffing: target, day: day, camp: camp).isEmpty)
    }

    /// The guards live in the shared half now — lifted out of the per-member filter — so this is
    /// the check that lifting them did not lose them. A day from another venue occupies nobody,
    /// however busy it looks.
    @Test("The venue and day guards survived the lift")
    func theGuardsStillHold() {
        let (_, _, people) = Self.day()
        let elsewhere = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(11, 0), coaches: people.map(\.id),
            venue: otherVenueID
        )
        let tomorrow = block(
            "Warm-up", TimeOfDay(9, 0), TimeOfDay(11, 0), coaches: people.map(\.id), day: .thu
        )
        let target = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0), on: [court2])

        let mapped = CoachAvailability.map(
            for: people, staffing: target, day: [elsewhere, tomorrow, target], camp: camp
        )

        #expect(mapped.values.allSatisfy { $0.isFreeNow })
    }

    /// Same argument as `orderIndependent` above, made about the shared candidate list: it is
    /// `running(in:at:)`'s output filtered, so the sort is still the deciding vote and the caller's
    /// array order is still not.
    @Test("The answers do not depend on the order the day arrives in")
    func orderIndependent() {
        let (target, day, people) = Self.day()

        let forwards = CoachAvailability.map(for: people, staffing: target, day: day, camp: camp)
        let backwards = CoachAvailability.map(
            for: people, staffing: target, day: day.reversed(), camp: camp
        )

        #expect(forwards == backwards)
    }
}
