//
//  CampReindexTests.swift
//  SycamoreTests
//
//  `Camp.reindex()` is the last line of every mutation in the model, so a screen never reads a
//  count it computed itself. That makes it the one function in the domain that, if it drifts,
//  drifts everywhere at once and silently — the numbers stay plausible, they are just wrong.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("Camp.reindex")
struct CampReindexTests {

    // MARK: The overall ladder

    @Test("Renumbers the camp ladder 1…N with no gaps")
    func closesGapsInTheLadder() {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 6)
        camp.players[0].overallRank = 40
        camp.players[3].overallRank = 41

        camp.reindex()

        #expect(camp.orderedPlayers.map(\.overallRank) == [1, 2, 3, 4, 5, 6])
    }

    @Test("Sorts the ladder by rank rather than by insertion order")
    func sortsTheLadder() {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        // Kid4 promoted to the top, Kid1 demoted to the bottom.
        camp.players[0].overallRank = 99
        camp.players[3].overallRank = 0

        camp.reindex()

        #expect(Fixture.ladder(camp) == ["Kid4", "Kid2", "Kid3", "Kid1"])
    }

    // MARK: Court order

    @Test("Renumbers court ranks from 1 with no gaps")
    func closesGapsInACourt() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 4)
        let court = camp.groups[0].id
        for index in camp.players.indices {
            camp.players[index].courtRank *= 10  // 10, 20, 30, 40
        }

        camp.reindex()

        #expect(camp.players(inGroup: court).map(\.courtRank) == [1, 2, 3, 4])
    }

    @Test("Keeps the order the coach put the court in, not the camp's")
    func courtOrderIsTheCoachsBusiness() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 3)
        let court = camp.groups[0].id
        // The coach has the camp's third-ranked kid at the front of the court.
        camp.players[2].courtRank = 1
        camp.players[0].courtRank = 2
        camp.players[1].courtRank = 3

        camp.reindex()

        #expect(camp.players(inGroup: court).map(\.firstName) == ["Kid3", "Kid1", "Kid2"])
    }

    /// The reorder that shipped as a no-op did so because a `numeric(7,2)` column rounded away
    /// the fractional tie-break the app used to slot a kid *between* two others: both sides of
    /// the intended split came back holding the same rank.
    ///
    /// Ties therefore have to survive a round trip, and they have to resolve the same way every
    /// time. `Swift.sort` is not documented as stable, so the court comparator falls through to
    /// overall rank rather than leaving equal court ranks to the sort — and equal court ranks
    /// come out in camp-ladder order.
    @Test("A court-rank tie resolves in camp-ladder order")
    func tiesBreakByOverallRank() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 3)
        let court = camp.groups[0].id
        camp.players[1].courtRank = 2
        camp.players[2].courtRank = 2

        camp.reindex()

        #expect(camp.players(inGroup: court).map(\.firstName) == ["Kid1", "Kid2", "Kid3"])
        #expect(camp.players(inGroup: court).map(\.courtRank) == [1, 2, 3])
    }

    /// `movePlayer`, `applyRankOrder` and `syncGroups` all write `Int.max / 2` to mean "put them
    /// at the back and let reindex work out the number". If that sentinel ever stopped sorting
    /// last, every one of those paths would quietly deposit the kid at the *front* of the court
    /// they were moved to.
    @Test("The Int.max / 2 sentinel sinks a kid to the back of their court")
    func theSentinelSinks() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 4)
        let court = camp.groups[0].id
        camp.players[0].courtRank = Int.max / 2

        camp.reindex()

        #expect(camp.players(inGroup: court).map(\.firstName) == ["Kid2", "Kid3", "Kid4", "Kid1"])
    }

    @Test("Two sentinels keep their relative order rather than swapping")
    func twoSentinelsAreOrderedByRank() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 4)
        let court = camp.groups[0].id
        camp.players[1].courtRank = Int.max / 2
        camp.players[0].courtRank = Int.max / 2

        camp.reindex()

        #expect(camp.players(inGroup: court).map(\.firstName) == ["Kid3", "Kid4", "Kid1", "Kid2"])
    }

    // MARK: Denormalised counts

    @Test("Refreshes each court's player count")
    func refreshesPlayerCounts() {
        var camp = Fixture.camp([.init("Sycamore", courts: 3)], players: 9)
        camp.evenOut()

        #expect(camp.groups(in: camp.venues[0].id).map(\.playerCount) == [3, 3, 3])
    }

    @Test("Refreshes each court's coach from the staff list")
    func refreshesCoachIDs() {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        let courts = camp.groups(in: camp.venues[0].id)
        let nass = StaffMember(name: "Nass", role: .worker)
        camp.staff.append(nass)
        camp.assignStaff(nass.id, toGroup: courts[1].id)

        #expect(camp.group(courts[0].id)?.coachID == nil)
        #expect(camp.group(courts[1].id)?.coachID == nass.id)
    }

    // MARK: Denormalised court assignments

    /// A `CourtAssignment` copies the venue's name and emoji so a chip renders without walking
    /// back to the graph, and `assignStaff` was the only thing that ever wrote them. So renaming
    /// a venue, or picking a new emoji in the venue sheet, left every coach already standing
    /// there carrying the old pair — on Setup's staff row, on the staff sheet's subtitle, and in
    /// the camp picker — until they happened to be reassigned.
    @Test("A renamed, re-iconed venue reaches the coaches already standing on it")
    func assignmentsFollowTheVenue() {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        let court = camp.groups(in: camp.venues[0].id)[0]
        let nass = StaffMember(name: "Nass", role: .worker)
        camp.staff.append(nass)
        camp.assignStaff(nass.id, toGroup: court.id)
        #expect(camp.staff(nass.id)?.assignment?.chip == "🌳 C1")

        var venue = camp.venues[0]
        venue.name = "Sycamore North"
        venue.icon = "🎾"
        camp.upsert(venue)

        let assignment = camp.staff(nass.id)?.assignment
        #expect(assignment?.chip == "🎾 C1")
        #expect(assignment?.pathLabel == "Sycamore North · Court 1")
        #expect(assignment?.pickerLabel == "Sycamore North, Court 1")
        // Setup's staff row reads the chip through the member, not the assignment.
        #expect(camp.staff(nass.id)?.courtChip == "🎾 C1")
    }

    /// Two venues, one edit: a coach at the other venue is not holding a copy of the venue that
    /// was edited, and re-reading everyone's must not hand them one.
    @Test("Editing one venue leaves a coach at the other alone")
    func editingOneVenueLeavesTheOtherAlone() {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 1), .init("LATC", courts: 1)],
            players: 4
        )
        let latcCourt = camp.groups(in: camp.orderedVenues[1].id)[0]
        let hubert = StaffMember(name: "Hubert", role: .worker)
        camp.staff.append(hubert)
        camp.assignStaff(hubert.id, toGroup: latcCourt.id)

        var sycamore = camp.orderedVenues[0]
        sycamore.name = "Sycamore North"
        sycamore.icon = "🎾"
        camp.upsert(sycamore)

        #expect(camp.staff(hubert.id)?.assignment?.pathLabel == "LATC · Court 1")
        #expect(camp.staff(hubert.id)?.assignment?.chip == "🌳 C1")
    }

    // MARK: `presentCount` is a statement about today

    /// The bug this pins: `reindex` used to take the day it was being called *about*, so writing
    /// a Monday pick-up recounted every court against Monday — a day with no away-records — and
    /// reported all twelve courts full. Head-counts describe who is standing on the court now.
    @Test("An absence on another day leaves today's head-count alone")
    func anotherDaysAbsenceDoesNotMoveTodaysCount() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        let court = camp.groups[0].id
        let away = camp.orderedPlayers[0].id

        camp.setAttendance(playerID: away, day: .mon, present: false)

        #expect(camp.group(court)?.presentCount == 5)
        #expect(camp.group(court)?.playerCount == 5)
    }

    @Test("An absence today drops the head-count but not the roster")
    func todaysAbsenceDropsTheHeadCount() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        let court = camp.groups[0].id
        let away = camp.orderedPlayers[0].id

        camp.setAttendance(playerID: away, day: .today, present: false)

        #expect(camp.group(court)?.presentCount == 4)
        #expect(camp.group(court)?.playerCount == 5)
    }

    @Test("Marking someone back restores the head-count and drops the row")
    func markingBackClearsTheRecord() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        let court = camp.groups[0].id
        let kid = camp.orderedPlayers[0].id

        camp.setAttendance(playerID: kid, day: .today, present: false)
        camp.setAttendance(playerID: kid, day: .today, present: true)

        #expect(camp.group(court)?.presentCount == 5)
        // Sparse by design: a row saying "here, all day" says nothing, so it should not exist.
        #expect(camp.attendance.isEmpty)
    }

    @Test("An early pick-up keeps the kid in today's head-count")
    func anEarlyPickupIsStillPresent() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        let court = camp.groups[0].id
        let kid = camp.orderedPlayers[0].id

        camp.setEarlyPickup(playerID: kid, day: .today, leavesAt: TimeOfDay(14, 30))

        #expect(camp.group(court)?.presentCount == 5)
        #expect(camp.isLeavingEarly(kid))
        #expect(!camp.isAway(kid))
    }

    @Test("Marking someone away clears a pick-up they no longer need")
    func awayClearsThePickup() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        let kid = camp.orderedPlayers[0].id

        camp.setEarlyPickup(playerID: kid, day: .today, leavesAt: TimeOfDay(14, 30))
        camp.setAttendance(playerID: kid, day: .today, present: false)

        #expect(camp.leavesAt(kid) == nil)
        #expect(camp.isAway(kid))
    }

    /// The design's Court 1 holds nine kids against a working ceiling of eight and still reads
    /// "in range", because one of them is away. Measuring capacity against the roster rather
    /// than against who turned up would put a blue banner on a court that is fine.
    @Test("Over-capacity is measured against who turned up, not the roster")
    func capacityIsMeasuredAgainstTodaysCourt() {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 9)
        camp.groups[0].capacity = 8
        camp.reindex()

        #expect(camp.groups[0].isOverCapacity)
        #expect(camp.groups[0].capacityBanner == "1 over — move one kid down")

        camp.setAttendance(playerID: camp.orderedPlayers[0].id, day: .today, present: false)

        #expect(!camp.groups[0].isOverCapacity)
        #expect(camp.groups[0].capacityBanner == nil)
    }
}
