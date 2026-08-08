//
//  CourtDetailRosterTests.swift
//  SycamoreTests
//
//  The list the court screen draws: who is on one court today, who is not, and whether the two
//  halves still add up to the roll.
//
//  Worth pinning for the reason `OverviewRosterTests` gives about the card's list — nothing on
//  screen looks wrong when it is wrong. But this one carries a sharper obligation. The court
//  screen deliberately shows away kids where Overview hides them, and the moment two derivations
//  answer "who is on this court" there are two answers that can drift. So the first suite below
//  is not about this type's own behaviour at all: it holds the *present* half byte for byte
//  against `TodayCourts.rosters`, which is the list the card that opens this screen draws.
//
//  Three questions:
//
//      here    the same kids, in the same order, with the same numerals as the card
//      away    the rest of the roll, and nobody twice
//      closed  who counts on a court that is out of play — which is the screen's decision, not
//              this type's, and is asserted here only so the split cannot silently absorb it
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

/// A camp with one venue, `courts` courts, and `players` kids dealt across them.
private func dealtCamp(courts: Int, players: Int) -> Camp {
    var camp = Fixture.camp([.init("Sycamore", courts: courts)], players: players)
    camp.partition()
    return camp
}

private func courts(of camp: Camp) -> [Group] {
    camp.groups(in: camp.orderedVenues[0].id)
}

// MARK: - Against the card that opens the screen

@Suite("CourtDetailRoster agrees with the card")
struct CourtDetailRosterAgreementTests {

    /// The invariant the whole split exists to protect. A court screen that renumbered its list,
    /// or ordered it differently, or quietly counted an away kid among the present ones would
    /// contradict the card a reader tapped to get here — and that card is still on screen behind
    /// it.
    @Test("The present half is exactly the card's list")
    func presentHalfMatchesTheCard() {
        let camp = SampleData.uclaTennisCamp
        let cardRosters = TodayCourts.rosters(in: camp, day: .wed)

        for court in camp.groups {
            let detail = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed)

            #expect(detail.here.rows == (cardRosters[court.id]?.rows ?? []))
        }
    }

    /// The same, on a camp built to a size rather than to a screenshot — `SampleData` marks one
    /// kid away on one court, which is enough to catch a filter and not enough to catch an
    /// ordering.
    @Test("The present half is the card's list on a dealt camp too", arguments: [0, 1, 2, 9, 50])
    func presentHalfMatchesOnADealtCamp(players: Int) {
        let camp = dealtCamp(courts: 3, players: players)
        let cardRosters = TodayCourts.rosters(in: camp)

        for court in courts(of: camp) {
            let detail = CourtDetailRoster.build(forCourt: court.id, in: camp)

            #expect(detail.here.rows == (cardRosters[court.id]?.rows ?? []))
        }
    }

    @Test("The present half is numbered 1…n, in court order")
    func presentRanksRunFromOne() {
        let camp = SampleData.uclaTennisCamp

        for court in camp.groups {
            let rows = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed).here.rows

            #expect(rows.map(\.rank) == rows.indices.map { $0 + 1 })
        }
    }

    /// `CourtRoster.headcount` means the same thing on both screens, which is what lets the lede
    /// read "8 here" off the same derivation the list under it comes from.
    @Test("The present half carries no folded-away overflow")
    func presentHalfIsWhole() {
        let camp = SampleData.uclaTennisCamp

        for court in camp.groups {
            let here = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed).here

            #expect(here.overflow == 0)
            #expect(here.headcount == here.rows.count)
        }
    }
}

// MARK: - The half Overview does not draw

@Suite("CourtDetailRoster keeps the kids who are away")
struct CourtDetailRosterAwayTests {

    /// The point of the type. Overview drops these kids entirely; a screen about one court is
    /// where "who is missing" is finally answerable.
    @Test("An away kid is on the screen, in the away half")
    func awayKidsAreKept() {
        let camp = SampleData.uclaTennisCamp
        let court = SampleData.nassCourt
        let away = camp.players(inGroup: court.id).filter { camp.isAway($0.id, on: .wed) }
        #expect(!away.isEmpty, "the fixture has to have somebody away for this to be a test")

        let roster = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed)

        // As sets: which kids are away is this assertion's question, and the order they come back
        // in is `awayIsInCourtOrder`'s.
        #expect(Set(roster.away.map(\.id)) == Set(away.map(\.id)))
        for kid in away {
            #expect(!roster.here.rows.contains { $0.id == kid.id })
        }
    }

    @Test("Every away row is flagged away, and no present row is")
    func theFlagMatchesTheHalf() {
        let camp = SampleData.uclaTennisCamp

        for court in camp.groups {
            let roster = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed)

            // A closure rather than a key path: `#expect` expands `allSatisfy` into a call whose
            // argument it cannot prove non-throwing when it is written as `\.isAway`.
            #expect(roster.away.allSatisfy { $0.isAway })
            #expect(roster.here.rows.allSatisfy { !$0.isAway })
        }
    }

    /// Nobody is in both halves and nobody has been dropped: the two lists partition the roll.
    /// This is the assertion that catches a filter written the wrong way round, which would
    /// otherwise leave a court looking plausibly half-empty.
    @Test("Here plus away is the whole roll, and nobody is in both")
    func thetwoHalvesPartitionTheRoll() {
        let camp = SampleData.uclaTennisCamp

        for court in camp.groups {
            let roll = camp.players(inGroup: court.id)
            let roster = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed)
            let drawn = Set(roster.here.rows.map(\.id)).union(roster.away.map(\.id))

            #expect(roster.rollCount == roll.count)
            #expect(drawn == Set(roll.map(\.id)))
            #expect(Set(roster.here.rows.map(\.id)).isDisjoint(with: roster.away.map(\.id)))
        }
    }

    @Test("The away half is in court order")
    func awayIsInCourtOrder() {
        let camp = SampleData.uclaTennisCamp

        for court in camp.groups {
            let away = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed).away

            #expect(away.map(\.rank) == away.map(\.player.courtRank))
            #expect(away.map(\.rank) == away.map(\.rank).sorted())
        }
    }

    /// A kid who is not in has not got a pick-up today, whatever row the table is carrying: the
    /// clock beside a name says "goes home early", and they have gone.
    @Test("An away row carries no pick-up time")
    func awayRowsCarryNoPickup() {
        let camp = SampleData.uclaTennisCamp

        for court in camp.groups {
            let away = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed).away

            #expect(away.allSatisfy { $0.leavesAt == nil })
        }
    }

    @Test("A kid going home early keeps their time in the present half")
    func presentRowsKeepTheirPickup() {
        let camp = SampleData.uclaTennisCamp
        let leaving = camp.players.filter { camp.leavesAt($0.id, on: .wed) != nil }
        #expect(!leaving.isEmpty)

        for kid in leaving {
            guard let courtID = kid.groupID else { continue }
            let roster = CourtDetailRoster.build(forCourt: courtID, in: camp, day: .wed)

            #expect(roster.here.rows.first { $0.id == kid.id }?.leavesAt
                    == camp.leavesAt(kid.id, on: .wed))
        }
    }

    /// The day is a parameter, not the clock. `SampleData` writes its attendance for Wednesday
    /// alone, so a Monday has nobody away and the section falls off the screen.
    @Test("Attendance written for one day does not touch another")
    func attendanceIsPerDay() {
        let camp = SampleData.uclaTennisCamp
        let court = SampleData.nassCourt

        let wednesday = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .wed)
        let monday = CourtDetailRoster.build(forCourt: court.id, in: camp, day: .mon)

        #expect(!wednesday.away.isEmpty)
        #expect(monday.away.isEmpty)
        #expect(monday.here.rows.count == camp.players(inGroup: court.id).count)
    }

    @Test("A court with nobody dealt to it is empty on both halves")
    func anEmptyCourt() {
        // Six courts, two kids: the deal gives one apiece to the first two and leaves the rest
        // standing empty.
        let camp = dealtCamp(courts: 6, players: 2)

        let roster = CourtDetailRoster.build(forCourt: courts(of: camp)[5].id, in: camp)

        #expect(roster.isEmpty)
        #expect(roster.rollCount == 0)
    }

    @Test("A court that is not in the camp at all lists nobody")
    func anUnknownCourt() {
        let roster = CourtDetailRoster.build(forCourt: UUID(), in: dealtCamp(courts: 3, players: 20))

        #expect(roster.isEmpty)
    }
}
