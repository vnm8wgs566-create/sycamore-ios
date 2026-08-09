//
//  PlayerCourtPickerTests.swift
//  SycamoreTests
//
//  The list `8q`'s bar opens: every court in the camp, venue by venue, with the kid's own marked.
//
//  Worth pinning for the reason `OverviewCapacityTests` gives about the reading it borrows —
//  nothing on screen looks wrong when it is wrong. A picker that quietly dropped the second
//  venue's six courts still reads as a picker; one that ticked the wrong row still reads as a
//  picker; and a court flagged full when it has two spots left looks exactly like one that is.
//  The only thing that catches any of it is `PlayerCourtChoices`, which is why the list is a
//  struct with no view in it.
//
//  Four questions:
//
//      sections            -> is every court there, in an order somebody can hunt through
//      isCurrent           -> is the kid's own court marked, and only theirs
//      flag / meta         -> does a full court say so, and does a court with room stay quiet
//      hasSomewhereElse    -> and should the bar that opens all this be live at all
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private enum Courts {

    /// Two venues of two courts each, four kids, all four parked on Sycamore's Court 1.
    ///
    /// `Fixture.camp`'s own arrangement, and the reason it puts everybody in one place holds here
    /// too: a test that asserts which court is marked as theirs is worthless if every court is.
    static func camp(ceiling: Int = 4) -> Camp {
        var camp = Fixture.camp(
            [Fixture.VenueSpec("Sycamore", courts: 2), Fixture.VenueSpec("LATC", courts: 2)],
            players: 4
        )
        // Set by hand rather than left to `syncGroups`, which derives a ceiling from
        // `playerMax / groupCount` — 999/2 with the fixture's defaults. A test that wants to say
        // "this court is exactly full" needs to choose the number it is full at.
        for index in camp.groups.indices {
            camp.groups[index].capacity = ceiling
        }
        camp.reindex()
        return camp
    }

    /// The kid every test below moves — top of the ladder, on Sycamore's Court 1.
    static func kid(_ camp: Camp) -> Player { camp.orderedPlayers[0] }

    static func court(_ camp: Camp, venue: Int, court: Int) -> Group {
        camp.groups(in: camp.orderedVenues[venue].id)[court]
    }

    /// Every row the picker would draw, venue name and all, in the order it would draw them.
    static func rows(_ choices: PlayerCourtChoices) -> [String] {
        choices.sections.flatMap { section in
            section.courts.map { "\(section.title) · \($0.label)" }
        }
    }

    /// `assignStaff` rather than a hand-built `CourtAssignment`, which is how `CampReindexTests`
    /// puts a coach on a court too. It derives all six of the assignment's denormalised fields from
    /// the graph, so a fixture pointed at the second venue cannot quietly produce an assignment
    /// naming the first — and it reindexes, which is what makes `coach(forGroup:)` answer.
    static func putACoachOn(_ court: Group, named name: String, in camp: Camp) -> Camp {
        var camp = camp
        let coach = StaffMember(name: name, role: .worker)
        camp.staff.append(coach)
        camp.assignStaff(coach.id, toGroup: court.id)
        return camp
    }
}

// MARK: - Is every court there

@Suite("The picker offers the whole camp")
struct PlayerCourtChoicesShapeTests {

    /// The change this list exists for. The bar it replaced could only reach one court — the next
    /// one up inside the kid's own venue — so the four rows below were three courts a kid could
    /// not be sent to from this screen, one of them at a venue the bar could not name.
    @Test("Every court at every venue is on the list, not just the ones above them")
    func everyCourt() {
        let camp = Courts.camp()
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.sections.count == 2)
        #expect(choices.courts.count == 4)
        #expect(
            Courts.rows(choices) == [
                "Sycamore · Court 1",
                "Sycamore · Court 2",
                "LATC · Court 1",
                "LATC · Court 2",
            ]
        )
    }

    /// Court labels repeat across venues — "Court 1" is at both — so the section a row sits in is
    /// the only thing that tells two identical rows apart. It is also what the write needs:
    /// `movePlayer` takes a venue as well as a court.
    @Test("A court carries the venue it belongs to, because two venues both have a Court 1")
    func courtsCarryTheirVenue() {
        let camp = Courts.camp()
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        let sycamore = camp.orderedVenues[0].id
        let latc = camp.orderedVenues[1].id

        #expect(choices.sections[0].id == sycamore)
        #expect(choices.sections[1].id == latc)
        #expect(choices.sections[0].courts.allSatisfy { $0.venueID == sycamore })
        #expect(choices.sections[1].courts.allSatisfy { $0.venueID == latc })
    }

    /// Venues by `sortIndex`, courts by `rankOrder` — the order every other screen lists them in.
    /// Held against a shuffled graph rather than the one the fixture happens to build, because the
    /// arrays come off a repository and their order is not a promise anybody made.
    @Test("The order is the camp's own, whatever order the graph arrives in")
    func orderIsStable() {
        var camp = Courts.camp()
        let expected = Courts.rows(PlayerCourtChoices(for: Courts.kid(camp).id, in: camp))

        camp.venues.reverse()
        camp.groups.reverse()
        let shuffled = Courts.rows(PlayerCourtChoices(for: Courts.kid(camp).id, in: camp))

        #expect(shuffled == expected)
    }

    /// A venue shaped but not yet built gets no heading. A bare venue name over nothing reads as a
    /// list that failed to load rather than as a venue with no courts.
    @Test("A venue with no courts yet is left out rather than headed over nothing")
    func emptyVenueDropped() {
        var camp = Courts.camp()
        let latc = camp.orderedVenues[1].id
        camp.groups.removeAll { $0.venueID == latc }
        camp.reindex()

        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.sections.count == 1)
        #expect(choices.sections[0].title == "Sycamore")
    }

    /// The store's loading state, which the sheet draws as a written explanation rather than a
    /// blank plate. Nil is "no camp yet", not "a camp with no courts".
    @Test("No camp is an empty list rather than a crash or an invented court")
    func noCamp() {
        let choices = PlayerCourtChoices(for: UUID(), in: nil)

        #expect(choices.sections.isEmpty)
        #expect(choices.courts.isEmpty)
        #expect(!choices.hasSomewhereElse)
    }
}

// MARK: - Which one is theirs

@Suite("The kid's own court is marked and nothing else is")
struct PlayerCourtChoicesCurrentTests {

    @Test("Their court is on the list, ticked, rather than hidden from it")
    func currentIsMarked() {
        let camp = Courts.camp()
        let kid = Courts.kid(camp)
        let choices = PlayerCourtChoices(for: kid.id, in: camp)

        let current = choices.courts.filter(\.isCurrent)

        #expect(current.count == 1)
        #expect(current.first?.id == kid.groupID)
        #expect(current.first?.label == "Court 1")
        #expect(current.first?.venueID == camp.orderedVenues[0].id)
    }

    /// Sycamore's Court 1 and LATC's Court 1 share a label and nothing else. A `isCurrent` keyed
    /// on anything but the id would tick both.
    @Test("The other venue's Court 1 is not ticked as well")
    func onlyOneIsCurrent() {
        let camp = Courts.camp()
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.sections[1].courts.allSatisfy { !$0.isCurrent })
    }

    /// A kid off a court — imported, or dropped off one by `syncGroups` when a venue was trimmed.
    /// Every court is a destination and none is theirs, which is exactly what should be offered.
    @Test("A kid with no court yet is offered all of them and shown as being on none")
    func noCourtYet() throws {
        var camp = Courts.camp()
        let kidID = Courts.kid(camp).id
        let index = try #require(camp.players.firstIndex { $0.id == kidID })
        camp.players[index].groupID = nil
        camp.reindex()

        let choices = PlayerCourtChoices(for: kidID, in: camp)

        #expect(choices.courts.count == 4)
        #expect(choices.courts.allSatisfy { !$0.isCurrent })
        #expect(choices.hasSomewhereElse)
    }

    /// A roster that has moved on under an open sheet. The courts are a fact about the camp, not
    /// about the kid, so they are still listed — with nothing ticked, because nothing is theirs.
    @Test("A kid the camp no longer holds still gets the courts, with none of them ticked")
    func unknownKid() {
        let camp = Courts.camp()
        let choices = PlayerCourtChoices(for: UUID(), in: camp)

        #expect(choices.courts.count == 4)
        #expect(choices.courts.allSatisfy { !$0.isCurrent })
    }
}

// MARK: - What a row says

@Suite("A row says how full the court is and who has it")
struct PlayerCourtOptionReadingTests {

    /// The fixture's four kids are all on Sycamore's Court 1, so at a ceiling of four it is
    /// exactly full and the other three courts are empty.
    @Test("A court at its ceiling is flagged Full, and one with room is flagged nothing")
    func fullIsFlagged() {
        let camp = Courts.camp(ceiling: 4)
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)
        let courts = choices.courts

        #expect(courts[0].flag == "Full")
        #expect(courts[0].capacity?.reading == "4 of 4")
        #expect(courts[1].flag == nil)
        #expect(courts[1].capacity?.reading == "0 of 4")
    }

    /// **Flagged, not blocked.** There is deliberately no "eligible" or "disabled" on an option,
    /// and this is the test that says so out loud: a full court somebody is not already on is an
    /// ordinary row that a tap moves a kid onto. `ScheduleResize.swift:19-42` and
    /// `BlockEditorDraft.swift:96-125` argue the rule for the schedule's overlaps; it is the same
    /// rule, and a picker that greyed the row would be a second opinion about it.
    @Test("A full court is still an ordinary destination — the app flags a clash, it does not refuse one")
    func fullIsStillOffered() {
        var camp = Courts.camp(ceiling: 3)
        // One kid off Court 1 leaves it at exactly three of three, and gives us somebody for whom
        // that full court is a destination rather than the court they are standing on.
        let mover = camp.orderedPlayers[3]
        let secondCourt = Courts.court(camp, venue: 0, court: 1)
        camp.movePlayer(mover.id, toVenue: secondCourt.venueID, group: secondCourt.id)

        let choices = PlayerCourtChoices(for: mover.id, in: camp)
        let full = choices.courts[0]

        #expect(full.capacity?.reading == "3 of 3")
        #expect(full.flag == "Full")
        #expect(!full.isCurrent)
        #expect(choices.hasSomewhereElse)
    }

    /// The over-capacity wording is `CourtCapacity.pillLabel`'s, so this row and Overview's card
    /// say the same thing about the same court rather than two things that agree today.
    @Test("A court past its ceiling borrows Overview's own words for it")
    func overIsFlagged() {
        let camp = Courts.camp(ceiling: 3)
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.courts[0].flag == "1 over")
        #expect(choices.courts[0].capacity?.isOver == true)
    }

    /// A ceiling of zero has nothing to measure against, so the row draws no figure at all rather
    /// than "4 of 0" — `CourtCapacity.reading(for:capacity:)`'s own rule, restated over the graph.
    @Test("A court with no ceiling reads nothing rather than a fraction over zero")
    func noCeiling() {
        let camp = Courts.camp(ceiling: 0)
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.courts[0].capacity == nil)
        #expect(choices.courts[0].flag == nil)
        #expect(choices.courts[0].meta == "Needs a coach")
    }

    @Test("The line under a court's name is its fill and its coach")
    func metaLine() {
        let camp = Courts.camp(ceiling: 4)
        let withCoach = Courts.putACoachOn(Courts.court(camp, venue: 0, court: 0), named: "Nass", in: camp)
        let choices = PlayerCourtChoices(for: Courts.kid(withCoach).id, in: withCoach)

        #expect(choices.courts[0].coachName == "Nass")
        #expect(choices.courts[0].meta == "4 of 4 · Nass")
    }

    /// The coach segment is never simply dropped. "Who has it" is one of the three things this
    /// list exists to answer, and a row that omitted the answer would read as one whose coach the
    /// sheet had failed to load.
    @Test("A court nobody has says so, in the words the rest of the app uses")
    func noCoach() {
        let camp = Courts.camp(ceiling: 4)
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.courts[1].coachName == nil)
        #expect(choices.courts[1].meta == "0 of 4 · Needs a coach")
    }

    /// "4 of 4" read aloud is a score or a date, which is why `CourtCapacity.spokenLabel` exists;
    /// it is also the only place the exactly-full court says "Full" to somebody who cannot see the
    /// pill beside it.
    @Test("VoiceOver hears a sentence, and hears the word Full on a court at its ceiling")
    func spokenLabel() {
        let camp = Courts.camp(ceiling: 4)
        let withCoach = Courts.putACoachOn(Courts.court(camp, venue: 0, court: 0), named: "Nass", in: camp)
        let choices = PlayerCourtChoices(for: Courts.kid(withCoach).id, in: withCoach)

        #expect(choices.courts[0].spokenLabel == "Court 1. 4 of 4 kids. Full. Coach Nass")
        #expect(choices.courts[1].spokenLabel == "Court 2. 0 of 4 kids. 4 spots left. Needs a coach")
    }

    /// A kid who is away is not standing on the court, which is what `Group.isOverCapacity`
    /// measures and therefore what this reads. A numerator taken from the roll would put this row
    /// at "4 of 4 · Full" beside an Overview card calling the same court in range.
    @Test("The fill counts who is here today, the way every other capacity reading does")
    func fillCountsToday() {
        var camp = Courts.camp(ceiling: 4)
        camp.attendance.append(
            Attendance(playerID: Courts.kid(camp).id, day: .today, present: false, leavesAt: nil)
        )
        camp.reindex()

        let choices = PlayerCourtChoices(for: camp.orderedPlayers[1].id, in: camp)

        #expect(choices.courts[0].capacity?.reading == "3 of 4")
        #expect(choices.courts[0].flag == nil)
    }
}

// MARK: - Whether the bar opens at all

@Suite("The bar is live when there is somewhere else to go")
struct PlayerCourtChoicesBarTests {

    /// The reason `PlayerScreen` asks this type rather than counting courts itself: the bar and
    /// the sheet cannot disagree if only one of them answers.
    ///
    /// The four kids are spread over three courts and both venues first — `Fixture.camp` parks
    /// them all on one, and a loop over four kids standing in the same place asserts one case four
    /// times.
    @Test("A camp of several courts has somewhere else, whichever one the kid is on")
    func somewhereElse() {
        var camp = Courts.camp()
        let sycamoreSecond = Courts.court(camp, venue: 0, court: 1)
        let latcFirst = Courts.court(camp, venue: 1, court: 0)
        camp.movePlayer(camp.orderedPlayers[1].id, toVenue: sycamoreSecond.venueID, group: sycamoreSecond.id)
        camp.movePlayer(camp.orderedPlayers[2].id, toVenue: latcFirst.venueID, group: latcFirst.id)

        // Three distinct courts between them, which is what makes the loop below four questions.
        #expect(Set(camp.orderedPlayers.compactMap(\.groupID)).count == 3)

        for kid in camp.orderedPlayers {
            let choices = PlayerCourtChoices(for: kid.id, in: camp)
            #expect(choices.hasSomewhereElse)
        }
    }

    /// What the disabled bar is actually for now. Not "already on the top court" — that used to
    /// stand the bar down and no longer does, because the top court is a perfectly good place to
    /// be moved off.
    @Test("A camp of one court has nowhere else, and that is the only time the bar stands down")
    func nowhereElse() {
        let camp = Fixture.camp([Fixture.VenueSpec("Sycamore", courts: 1)], players: 2)
        let choices = PlayerCourtChoices(for: Courts.kid(camp).id, in: camp)

        #expect(choices.courts.count == 1)
        #expect(choices.courts[0].isCurrent)
        #expect(!choices.hasSomewhereElse)
    }

    /// The state that used to disable the bar. Kept as a test rather than deleted with the rule,
    /// because "the kid on the top court can still be moved" is the whole change.
    @Test("A kid on the top court still has somewhere to go, which is the point of the change")
    func topCourtStillMoves() {
        let camp = Courts.camp()
        let topCourt = Courts.court(camp, venue: 0, court: 0)
        let kid = Courts.kid(camp)

        #expect(kid.groupID == topCourt.id)
        #expect(PlayerCourtChoices(for: kid.id, in: camp).hasSomewhereElse)
    }
}
