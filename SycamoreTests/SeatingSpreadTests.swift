//
//  SeatingSpreadTests.swift
//  SycamoreTests
//
//  Where kids land — across *courts* and across *venues* — rather than who the band refuses.
//
//  This file exists because the suite had 1149 passing tests while the app put an entire imported
//  roster on one court at one venue, and every one of those tests was right about its own claim.
//  The gap was the shape of the question. Two habits hid the bug:
//
//  1. **Every test that reached the seating loop used a one-court venue.** `CampAgeBandDealTests`
//     sets `groupCount = 1` before asserting `courtSizes == [3]`; `GroupsUnassignedTests` builds
//     `Fixture.camp([.init("Home", courts: 1)], …)`. On one court "all on the first court" and
//     "spread evenly" are the same array, so the assertion cannot tell them apart. Every test
//     below uses **three**, which is the smallest number where stacking and spreading differ and
//     the difference survives a rounding argument.
//
//  2. **Band tests asserted who was refused, never where the admitted ones sat.** A camp can filter
//     perfectly and still stack the survivors on Court 1 — that was the shipped behaviour, and it
//     passes any test written as "the nine-year-old has no group".
//
//  So the assertions here are about *distribution*: the sizes of every court in a venue, and the
//  venue every kid ended at. `smallestGroupID` had no test of its own at all before this file.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("Seating — how kids spread across courts and venues")
struct SeatingSpreadTests {

    // MARK: - The court-of-last-resort loop

    /// The reported bug, at its smallest.
    ///
    /// `smallestGroupID(in:)` used to rank courts by `Group.playerCount`, which is denormalised and
    /// written only by `reindex()`. `syncGroups(for:)` seats kids in a loop and reindexes *after*
    /// it, so every iteration read the same pre-loop counts, `min` answered the same court every
    /// time, and the whole queue landed on it. On a fresh venue all counts are 0, the tie breaks on
    /// `rankOrder`, and that court is always Court 1.
    ///
    /// A rename is the control on purpose: no band, no court-count change, nothing else in
    /// `syncGroups` has any work to do, so the seating loop is the only thing that can explain the
    /// result. Before the fix this was `[5, 0, 0]`.
    @Test("A venue write spreads its unseated kids over every court, not onto the first")
    func aVenueWriteSpreadsRatherThanStacks() {
        var camp = Fixture.camp([.init("Home", courts: 3)], players: 5)
        let venueID = camp.orderedVenues[0].id

        // Everybody at the venue, nobody on a court — the state an import leaves behind.
        for index in camp.players.indices { camp.players[index].groupID = nil }
        camp.reindex()

        var renamed = try! #require(camp.venue(venueID))
        renamed.name = "Home Courts"
        camp.upsert(renamed)

        #expect(Fixture.courtSizes(camp, in: venueID) == [2, 2, 1])
        #expect(camp.players.allSatisfy { $0.groupID != nil })
    }

    /// The same loop, asked to seat more kids than it has courts twice over, so a stacking bug
    /// cannot hide inside a rounding remainder.
    @Test("Nine kids over three courts come out three apiece")
    func nineOverThreeIsEven() {
        var camp = Fixture.camp([.init("Home", courts: 3)], players: 9)
        let venueID = camp.orderedVenues[0].id

        for index in camp.players.indices { camp.players[index].groupID = nil }
        camp.reindex()

        var renamed = try! #require(camp.venue(venueID))
        renamed.subtitle = "Main site"
        camp.upsert(renamed)

        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 3, 3])
    }

    /// The band still gets the last word on *who* is seated. This is the half that already worked,
    /// pinned here beside the half that did not so a future change cannot trade one for the other.
    @Test("Spreading seats only the kids the band admits")
    func spreadingStillObeysTheBand() {
        var camp = Fixture.camp([.init("Seniors", courts: 3)], players: 0)
        let venueID = camp.orderedVenues[0].id

        // Six kids, alternating either side of twelve.
        for rank in 1...6 {
            camp.players.append(
                Player(
                    firstName: "Kid\(rank)",
                    lastInitial: "T",
                    age: rank.isMultiple(of: 2) ? 9 : 14,
                    gender: .x,
                    isReturning: false,
                    venueID: venueID,
                    groupID: nil,
                    overallRank: rank,
                    courtRank: rank
                )
            )
        }
        camp.reindex()

        var banded = try! #require(camp.venue(venueID))
        banded.ageBand = AgeBand(minAge: 12)
        camp.upsert(banded)

        // Three fourteen-year-olds, one per court — spread, not stacked.
        #expect(Fixture.courtSizes(camp, in: venueID) == [1, 1, 1])
        // The three nine-year-olds keep the venue and take no court.
        let refused = camp.players.filter { $0.age == 9 }
        #expect(refused.count == 3)
        #expect(refused.allSatisfy { $0.groupID == nil && $0.venueID == venueID })
    }

    // MARK: - Partition across venues

    /// `partition()` walked one ladder and handed each venue a *contiguous* slice of it, which
    /// ignores the band completely. With the ladder deliberately opposed to the age split, every
    /// senior was sent to the junior venue and vice versa — and `redistribute`, which *does* gate
    /// on the band, then refused all of them. The button a coach reaches for when the courts look
    /// wrong emptied the entire camp.
    @Test("Partition sends each kid to a venue that admits them, whatever their rank")
    func partitionRespectsTheBand() {
        var camp = Fixture.camp(
            [.init("Seniors", courts: 2), .init("Juniors", courts: 2)],
            players: 0
        )
        let seniorID = camp.orderedVenues[0].id
        let juniorID = camp.orderedVenues[1].id

        // The top of the ladder is entirely juniors and the bottom entirely seniors, so a
        // rank-contiguous slice is guaranteed to get every single kid wrong.
        for rank in 1...8 {
            camp.players.append(
                Player(
                    firstName: "Kid\(rank)",
                    lastInitial: "T",
                    age: rank <= 4 ? 9 : 14,
                    gender: .x,
                    isReturning: false,
                    venueID: seniorID,
                    groupID: nil,
                    overallRank: rank,
                    courtRank: rank
                )
            )
        }

        var seniors = try! #require(camp.venue(seniorID))
        seniors.ageBand = AgeBand(minAge: 12)
        camp.upsert(seniors)
        var juniors = try! #require(camp.venue(juniorID))
        juniors.ageBand = AgeBand(maxAge: 11)
        camp.upsert(juniors)

        camp.partition()

        // Nobody sits where they would only be refused. `age` is optional, and an unknown age is
        // failure here rather than a pass — every kid in this fixture has one, so a nil would mean
        // the fixture stopped saying what the test claims it says.
        #expect(camp.players(in: seniorID).allSatisfy { ($0.age ?? 0) >= 12 })
        #expect(camp.players(in: juniorID).allSatisfy { ($0.age ?? 99) <= 11 })
        #expect(camp.players(in: seniorID).count == 4)
        #expect(camp.players(in: juniorID).count == 4)

        // And having reached the right venue they are spread over its courts, not stacked.
        #expect(Fixture.courtSizes(camp, in: seniorID) == [2, 2])
        #expect(Fixture.courtSizes(camp, in: juniorID) == [2, 2])
        // Which means nobody is left over anywhere.
        #expect(camp.players.allSatisfy { $0.groupID != nil })
    }

    /// A kid no venue will take keeps the venue they had rather than being moved somewhere they
    /// would only be refused again. The second-offer sweep must not strand them either.
    @Test("A kid outside every band keeps their venue and takes no court")
    func aKidNoVenueAdmitsStaysPut() {
        var camp = Fixture.camp([.init("Seniors", courts: 2)], players: 0)
        let venueID = camp.orderedVenues[0].id

        for (offset, age) in [14, 15, 8].enumerated() {
            camp.players.append(
                Player(
                    firstName: "Kid\(offset + 1)",
                    lastInitial: "T",
                    age: age,
                    gender: .x,
                    isReturning: false,
                    venueID: venueID,
                    groupID: nil,
                    overallRank: offset + 1,
                    courtRank: offset + 1
                )
            )
        }

        var banded = try! #require(camp.venue(venueID))
        banded.ageBand = AgeBand(minAge: 12)
        camp.upsert(banded)

        camp.partition()

        let stranded = try! #require(camp.players.first { $0.age == 8 })
        #expect(stranded.venueID == venueID)
        #expect(stranded.groupID == nil)
        #expect(Fixture.courtSizes(camp, in: venueID) == [1, 1])
    }
}

/// The same question asked of the real write path rather than of `Camp` alone.
///
/// A separate suite because `AppStore` is `@MainActor` and the model tests above are not —
/// isolating the whole file would put the pure arithmetic on the main actor for no reason.
@MainActor
@Suite("Seating — an import, through the store")
struct ImportSeatingTests {

    /// **The seam nothing covered.** `RosterAgeFitTests` stops at what the review screen is handed;
    /// `AppStoreEnrolmentTests` never asked where anybody sat. Between them a roster could be
    /// routed correctly on screen, written to one venue, and stacked on one court, and every test
    /// passed.
    ///
    /// So this drives the real path — `AppStore.applyRoster` over `InMemoryRepository` — with a
    /// commit built exactly the way `OnboardingFlowView.saveRoster()` builds one: raw rows whose
    /// `venueIndex` is defaulted, because no roster file has a venue column.
    @Test("An imported roster lands by band and spreads over the courts")
    func anImportRoutesAndDeals() async throws {
        var camp = Fixture.camp(
            [.init("Seniors", courts: 3), .init("Juniors", courts: 3)],
            players: 0
        )
        var seniors = try #require(camp.venue(camp.orderedVenues[0].id))
        seniors.ageBand = AgeBand(minAge: 12)
        camp.upsert(seniors)
        var juniors = try #require(camp.venue(camp.orderedVenues[1].id))
        juniors.ageBand = AgeBand(maxAge: 11)
        camp.upsert(juniors)

        let venues = camp.orderedVenues.map(\.id)
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        // Twelve kids, six either side of the split, every one of them defaulted to venue 0 —
        // which is the state a spreadsheet actually arrives in.
        let rows = (1...12).map { index in
            IntakePlayer(
                firstName: "Kid\(index)", lastName: "T",
                age: index.isMultiple(of: 2) ? 9 : 14, gender: .x
            )
        }
        let fit = [seniors.rosterVenue, juniors.rosterVenue]

        await store.applyRoster(
            RosterReconciliation.Commit(inserting: rows, updating: [], removing: [])
                .routed(by: fit),
            venues: venues
        )

        let after = try #require(store.camp)
        #expect(store.errorMessage == nil)

        // Routed: each kid at the venue whose band admits them.
        #expect(after.players(in: venues[0]).count == 6)
        #expect(after.players(in: venues[1]).count == 6)
        #expect(after.players(in: venues[0]).allSatisfy { ($0.age ?? 0) >= 12 })
        #expect(after.players(in: venues[1]).allSatisfy { ($0.age ?? 99) <= 11 })

        // Dealt: spread over each venue's three courts, not stacked on the first.
        #expect(Fixture.courtSizes(after, in: venues[0]) == [2, 2, 2])
        #expect(Fixture.courtSizes(after, in: venues[1]) == [2, 2, 2])
        #expect(after.players.allSatisfy { $0.groupID != nil })
    }

    /// Seating an arrival must not disturb a coach's own ordering, which is the objection the
    /// import path's "deliberately no group" comment was written to answer. It is answered by
    /// seating only the group-less: a second import moves nobody.
    @Test("A second import seats the new kids and leaves the placed ones alone")
    func aSecondImportMovesNobody() async throws {
        let camp = Fixture.camp([.init("Home", courts: 3)], players: 0)
        let venueID = camp.orderedVenues[0].id
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        func send(_ names: [String]) async {
            await store.applyRoster(
                RosterReconciliation.Commit(
                    inserting: names.map {
                        IntakePlayer(firstName: $0, lastName: "T", age: 12, gender: .x)
                    },
                    updating: [], removing: []
                ),
                venues: [venueID]
            )
        }

        await send(["Ada", "Bo", "Cy"])
        let firstPass = try #require(store.camp)
        let placements = Dictionary(
            uniqueKeysWithValues: firstPass.players.map { ($0.firstName, $0.groupID) }
        )
        #expect(Fixture.courtSizes(firstPass, in: venueID) == [1, 1, 1])

        await send(["Dev", "Eve", "Fin"])
        let secondPass = try #require(store.camp)

        // The first three are exactly where they were.
        for name in ["Ada", "Bo", "Cy"] {
            let kid = try #require(secondPass.players.first { $0.firstName == name })
            #expect(kid.groupID == placements[name])
        }
        #expect(Fixture.courtSizes(secondPass, in: venueID) == [2, 2, 2])
    }
}

/// The sentence under the age band, which is arithmetic a reader is asked to trust before they
/// save. It has to agree with `Camp.seatUnassigned` exactly — a count that says eight will take a
/// court while the deal seats seven is worse than no count at all.
@Suite("The age band's live consequence")
struct AgeBandConsequenceTests {

    private func line(_ band: AgeBand, _ ages: [Int?]) -> String? {
        AgeBandConsequence.sentence(of: band, over: ages)
    }

    /// Nothing to report is nil, not "0 of 0" — a venue with no kids has no consequence, and a
    /// zero pair reads as a warning about something that has not happened.
    @Test("A venue with nobody at it says nothing")
    func silentWhenEmpty() {
        #expect(line(AgeBand(minAge: 12), []) == nil)
    }

    @Test("A band that refuses nobody says so without a split")
    func allAdmitted() {
        #expect(line(AgeBand(minAge: 12), [12, 14, 15]) == "All 3 here still take a court.")
    }

    @Test("A band that refuses somebody counts both sides")
    func someRefused() {
        #expect(
            line(AgeBand(minAge: 12), [12, 9, 14, 8])
                == "2 of 4 here take a court · 2 wait to be placed."
        )
    }

    /// The one that could silently disagree with the deal. `AgeBand.admits(_:)` refuses a nil age
    /// at a restricted band — a spreadsheet with a blank cell — so the count has to refuse it too.
    @Test("A kid with no age on file counts as refused, the way the deal refuses them")
    func nilAgeCountsAsRefused() {
        #expect(
            line(AgeBand(minAge: 12), [12, nil])
                == "1 of 2 here take a court · 1 wait to be placed."
        )
        // The same rule from the far side: a venue that is not asking admits them, so an
        // unrestricted band reports no split at all.
        #expect(line(AgeBand(), [12, nil]) == "All 2 here still take a court.")
    }

    @Test("A closed band counts both bounds")
    func closedBand() {
        #expect(
            line(AgeBand(minAge: 9, maxAge: 12), [8, 9, 12, 13])
                == "2 of 4 here take a court · 2 wait to be placed."
        )
    }
}
