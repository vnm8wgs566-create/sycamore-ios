//
//  InMemoryRepositoryTests.swift
//  SycamoreTests
//
//  The repository seam, exercised end to end.
//
//  `InMemoryRepository` is an actor with no network, so every method on `SycamoreRepository` is
//  reachable with a plain `await`. That makes it the only place the model, the validation and
//  the repository's two conventions — every mutation returns the whole camp, nothing here knows
//  about SwiftUI — can be tested together rather than one at a time.
//
//  It is also the contract the Supabase implementation has to match. A test that pins what
//  `InMemoryRepository` does is a test that says what `SupabaseRepository` owes.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("InMemoryRepository — sign-in")
struct RepositorySignInTests {

    @Test("Rejects the address the old three-way check waved through")
    func rejectsABadAddress() async throws {
        let repo = InMemoryRepository()

        await #expect(throws: SycamoreError.invalidEmail) {
            try await repo.requestSignInCode(email: "a@.")
        }
    }

    @Test("Echoes the address back normalised, which is the form it stores")
    func normalisesTheAddress() async throws {
        let repo = InMemoryRepository()

        let challenge = try await repo.requestSignInCode(email: "  Alex@UCLACamp.org  ")

        #expect(challenge.email == "alex@uclacamp.org")
        #expect(challenge.codeLength == 6)
        #expect(challenge.resendAfter == 42)
    }

    @Test("A code has to be six digits")
    func codeLength() async throws {
        let repo = InMemoryRepository()

        await #expect(throws: SycamoreError.invalidCode) {
            try await repo.verifySignInCode("12345", email: "alex@uclacamp.org")
        }
        await #expect(throws: SycamoreError.invalidCode) {
            try await repo.verifySignInCode("1234567", email: "alex@uclacamp.org")
        }
        await #expect(throws: SycamoreError.invalidCode) {
            try await repo.verifySignInCode("", email: "alex@uclacamp.org")
        }
    }

    @Test("Counts digits, not characters — a pasted code brings its punctuation")
    func codeIgnoresPunctuation() async throws {
        let repo = InMemoryRepository()

        let account = try await repo.verifySignInCode("12-34 56", email: "alex@uclacamp.org")

        #expect(account.email == "alex@uclacamp.org")
    }

    @Test("The same address is the same person, however it was typed")
    func signingInTwiceIsTheSamePerson() async throws {
        let repo = InMemoryRepository()

        let first = try await repo.verifySignInCode("123456", email: "alex@uclacamp.org")
        let second = try await repo.verifySignInCode("654321", email: "  ALEX@UCLACamp.org ")

        #expect(first.id == second.id)
    }

    @Test("An unknown account cannot be fetched or updated")
    func unknownAccount() async throws {
        let repo = InMemoryRepository()
        let stranger = Account(email: "nobody@example.org", displayName: "Nobody")

        await #expect(throws: SycamoreError.unknownAccount) {
            try await repo.account(id: stranger.id)
        }
        await #expect(throws: SycamoreError.unknownAccount) {
            try await repo.updateAccount(stranger)
        }
    }
}

@Suite("InMemoryRepository — camps")
struct RepositoryCampTests {

    @Test("An unknown camp is an error, not an empty camp")
    func unknownCamp() async throws {
        let repo = InMemoryRepository()

        await #expect(throws: SycamoreError.unknownCamp) {
            try await repo.camp(id: UUID())
        }
    }

    @Test("A camp needs a name")
    func campNameIsRequired() async throws {
        let repo = InMemoryRepository()
        let account = try await repo.verifySignInCode("123456", email: "alex@uclacamp.org")

        await #expect(throws: SycamoreError.campNameRequired) {
            try await repo.createCamp(CampDraft(name: "   "), accountID: account.id)
        }
    }

    @Test("The creator becomes the camp's first admin, and the shape matches the draft")
    func createCamp() async throws {
        let repo = InMemoryRepository()
        let account = try await repo.verifySignInCode("123456", email: "alex@uclacamp.org")

        let membership = try await repo.createCamp(
            CampDraft(name: "UCLA Tennis", sport: .tennis, venueCount: 3, groupsPerVenue: 4),
            accountID: account.id
        )
        let camp = try await repo.camp(id: membership.campID)

        #expect(membership.role == .admin)
        #expect(camp.venues.count == 3)
        #expect(camp.groups.count == 12)
        #expect(camp.staff.count == 1)
        #expect(camp.staff[0].accountID == account.id)
        #expect(camp.staff[0].role == .admin)
        // The sport names the courts, so a soccer camp would read "Field 1".
        #expect(camp.groups.allSatisfy { $0.label.hasPrefix("Court ") })
    }

    @Test("An unknown invite code is an error")
    func unknownInviteCode() async throws {
        let repo = InMemoryRepository()
        let account = try await repo.verifySignInCode("123456", email: "alex@uclacamp.org")

        await #expect(throws: SycamoreError.unknownInviteCode) {
            try await repo.joinCamp(inviteCode: "NOPE-0000", accountID: account.id)
        }
    }

    @Test("An invite code is read the way people write it down", arguments: [
        "SYC-4821", "syc-4821", "syc4821", "SYC 4821", " syc 4821 ",
    ])
    func inviteCodesNormalise(_ code: String) async throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        camp.inviteCode = "SYC-4821"
        let repo = InMemoryRepository(camps: [camp])
        let account = try await repo.verifySignInCode("123456", email: "alex@uclacamp.org")

        let membership = try await repo.joinCamp(inviteCode: code, accountID: account.id)

        #expect(membership.campID == camp.id)
        #expect(membership.role == .worker)
    }

    /// Joining twice is a thing people do — they tap the button again when the network is slow.
    /// A second membership would put the camp in the picker twice; a second staff row would put
    /// the same person on Setup's roster twice.
    @Test("Joining twice adds one membership and one staff row")
    func joiningIsIdempotent() async throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        camp.inviteCode = "SYC-4821"
        let repo = InMemoryRepository(camps: [camp])
        let account = try await repo.verifySignInCode("123456", email: "alex@uclacamp.org")

        let first = try await repo.joinCamp(inviteCode: "SYC-4821", accountID: account.id)
        let second = try await repo.joinCamp(inviteCode: "SYC-4821", accountID: account.id)

        #expect(first.id == second.id)
        #expect(try await repo.memberships(forAccount: account.id).count == 1)
        #expect(try await repo.camp(id: camp.id).staff.count == 1)
    }
}

@Suite("InMemoryRepository — enrolment")
struct RepositoryEnrolmentTests {

    /// The design's camp: 100 kids, two venues of six courts.
    private func loaded() -> (InMemoryRepository, Camp) {
        let camp = SampleData.uclaTennisCamp
        return (InMemoryRepository(camps: [camp]), camp)
    }

    @Test("A new kid comes back in the camp the write returns")
    func addPlayerRoundTrip() async throws {
        let (repo, camp) = loaded()
        let venue = camp.orderedVenues[0]
        let newcomer = Player(
            firstName: "Wren", lastInitial: "K", age: 11, gender: .f, isReturning: false,
            venueID: nil, groupID: nil, overallRank: 0, courtRank: 0
        )

        let after = try await repo.addPlayer(newcomer, toVenue: venue.id, campID: camp.id)

        #expect(after.players.count == camp.players.count + 1)
        #expect(after.player(newcomer.id)?.displayName == "Wren K")
        #expect(after.player(newcomer.id)?.venueID == venue.id)
        // Convention: a mutation returns the whole camp, so callers never patch local state.
        #expect(try await repo.camp(id: camp.id).players.count == after.players.count)
    }

    /// An import that dropped kids onto court 1 would quietly outrank the children already
    /// standing there, and nobody asked it to. They belong in Groups' unassigned band until a
    /// person decides.
    @Test("An imported kid arrives with no court")
    func importedKidsHaveNoCourt() async throws {
        let (repo, camp) = loaded()
        let venue = camp.orderedVenues[0]
        let batch = (1...3).map {
            Player(
                firstName: "New\($0)", lastInitial: "K", age: 11, gender: .x, isReturning: false,
                venueID: nil, groupID: nil, overallRank: 0, courtRank: 0
            )
        }

        let after = try await repo.importPlayers(batch, toVenue: venue.id, campID: camp.id)

        for player in batch {
            #expect(after.player(player.id)?.groupID == nil)
            #expect(after.player(player.id)?.venueID == venue.id)
        }
    }

    @Test("A batch keeps the order the roster was read in")
    func importKeepsBatchOrder() async throws {
        let (repo, camp) = loaded()
        let venue = camp.orderedVenues[0]
        let batch = (1...4).map {
            Player(
                firstName: "New\($0)", lastInitial: "K", age: 11, gender: .x, isReturning: false,
                venueID: nil, groupID: nil, overallRank: 0, courtRank: 0
            )
        }

        let after = try await repo.importPlayers(batch, toVenue: venue.id, campID: camp.id)

        let ranks = batch.compactMap { after.player($0.id)?.overallRank }
        #expect(ranks == ranks.sorted())
        #expect(Set(ranks).count == batch.count)
    }

    @Test("The camp ladder is still 1…N after an import")
    func ladderStaysContiguous() async throws {
        let (repo, camp) = loaded()
        let venue = camp.orderedVenues[1]
        let batch = (1...5).map {
            Player(
                firstName: "New\($0)", lastInitial: "K", age: 11, gender: .x, isReturning: false,
                venueID: nil, groupID: nil, overallRank: 0, courtRank: 0
            )
        }

        let after = try await repo.importPlayers(batch, toVenue: venue.id, campID: camp.id)

        #expect(after.orderedPlayers.map(\.overallRank) == Array(1...after.players.count))
    }

    /// The second venue is the one that catches the arithmetic. `overallRank` is camp-wide, so a
    /// rank counted off the venue's head-count rather than off where its block ends puts a new
    /// arrival at the *top* of the venue instead of the back of it — ahead of fifty children who
    /// were already there. Nothing errors and the roster count is right, which is why it survived
    /// as long as it did.
    @Test("An imported kid joins the back of their venue's ladder")
    func importedKidsJoinTheBackOfTheVenue() async throws {
        let (repo, camp) = loaded()
        let venue = camp.orderedVenues[1]
        let newcomer = Player(
            firstName: "Wren", lastInitial: "K", age: 11, gender: .f, isReturning: false,
            venueID: nil, groupID: nil, overallRank: 0, courtRank: 0
        )

        let after = try await repo.importPlayers([newcomer], toVenue: venue.id, campID: camp.id)
        let arrived = try #require(after.player(newcomer.id))
        let neighbours = after.players(in: venue.id).filter { $0.id != newcomer.id }

        #expect(neighbours.allSatisfy { $0.overallRank < arrived.overallRank })
    }

    @Test("An import into a venue that is not there fails, and writes nothing")
    func importIntoAnUnknownVenue() async throws {
        let (repo, camp) = loaded()
        let newcomer = Player(
            firstName: "Wren", lastInitial: "K", age: 11, gender: .f, isReturning: false,
            venueID: nil, groupID: nil, overallRank: 0, courtRank: 0
        )

        await #expect(throws: SycamoreError.unknownVenue) {
            try await repo.importPlayers([newcomer], toVenue: UUID(), campID: camp.id)
        }
        #expect(try await repo.camp(id: camp.id).players.count == camp.players.count)
    }

    @Test("An import into a camp that is not there fails")
    func importIntoAnUnknownCamp() async throws {
        let (repo, camp) = loaded()

        await #expect(throws: SycamoreError.unknownCamp) {
            try await repo.importPlayers([], toVenue: camp.orderedVenues[0].id, campID: UUID())
        }
    }
}

@Suite("InMemoryRepository — order")
struct RepositoryOrderTests {

    /// Two courts of three in one venue, so a reorder is unambiguous.
    private func loaded() -> (InMemoryRepository, Camp) {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 6)
        camp.evenOut()
        return (InMemoryRepository(camps: [camp]), camp)
    }

    /// The reorder that shipped as a silent no-op is the reason this asserts the whole sequence
    /// rather than "the first kid changed". Every write succeeded, every reload succeeded, and
    /// the ladder came back exactly as it went out.
    @Test("A reorder lands in the order it asked for")
    func reorderIsNotANoop() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups(in: camp.venues[0].id)[0]
        let before = camp.players(inGroup: court.id).map(\.id)
        let reversed = Array(before.reversed())

        let after = try await repo.reorderGroup(court.id, playerIDs: reversed, campID: camp.id)

        #expect(after.players(inGroup: court.id).map(\.id) == reversed)
        #expect(after.players(inGroup: court.id).map(\.id) != before)
        #expect(after.players(inGroup: court.id).map(\.courtRank) == [1, 2, 3])
    }

    /// Court order is the coach's business and the camp ladder is the admin's. A drag inside one
    /// card must not renumber the Rank tab.
    @Test("A reorder inside a court leaves the camp ladder alone")
    func reorderDoesNotTouchTheLadder() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups(in: camp.venues[0].id)[0]
        let reversed = camp.players(inGroup: court.id).map(\.id).reversed()

        let after = try await repo.reorderGroup(court.id, playerIDs: Array(reversed), campID: camp.id)

        #expect(after.orderedPlayers.map(\.id) == camp.orderedPlayers.map(\.id))
    }

    @Test("A reorder naming a court that is not there fails")
    func reorderAnUnknownCourt() async throws {
        let (repo, camp) = loaded()

        await #expect(throws: SycamoreError.unknownGroup) {
            try await repo.reorderGroup(UUID(), playerIDs: [], campID: camp.id)
        }
    }

    /// Every move path writes `Int.max / 2` and lets `reindex` turn it into a real number. If
    /// that stopped meaning "last", a kid moved up a court would arrive at the front of it.
    @Test("A kid moved to another court arrives at the back of it")
    func movingLandsAtTheBack() async throws {
        let (repo, camp) = loaded()
        let courts = camp.groups(in: camp.venues[0].id)
        let mover = camp.players(inGroup: courts[0].id)[0]
        let destination = camp.players(inGroup: courts[1].id).map(\.id)

        let after = try await repo.movePlayer(
            mover.id, toVenue: camp.venues[0].id, group: courts[1].id, campID: camp.id
        )

        #expect(after.players(inGroup: courts[1].id).map(\.id) == destination + [mover.id])
        #expect(after.players(inGroup: courts[0].id).count == 2)
        // Where they rank in the camp is a separate question, and moving courts does not answer
        // it — the mover is still the camp's top kid.
        #expect(after.orderedPlayers[0].id == mover.id)
    }

    @Test("Moving into a venue that is not there fails")
    func movingToAnUnknownVenue() async throws {
        let (repo, camp) = loaded()
        let mover = camp.orderedPlayers[0]

        await #expect(throws: SycamoreError.unknownVenue) {
            try await repo.movePlayer(mover.id, toVenue: UUID(), group: nil, campID: camp.id)
        }
    }

    @Test("Moving a kid who is not in the camp fails")
    func movingAnUnknownKid() async throws {
        let (repo, camp) = loaded()

        await #expect(throws: SycamoreError.unknownPlayer) {
            try await repo.movePlayer(
                UUID(), toVenue: camp.venues[0].id, group: nil, campID: camp.id
            )
        }
    }

    @Test("A camp-wide reorder moves a kid across a venue rule")
    func reorderCampCrossesAVenueRule() async throws {
        var camp = Fixture.camp(
            [.init("Sycamore", courts: 2), .init("LATC", courts: 2)], players: 6
        )
        camp.partition()
        let repo = InMemoryRepository(camps: [camp])
        let venues = camp.orderedVenues
        let sycamore = camp.players(in: venues[0].id).map(\.id)
        let latc = camp.players(in: venues[1].id).map(\.id)
        let mover = try #require(sycamore.last)

        let after = try await repo.reorderCamp(
            [
                RankAssignment(venueID: venues[0].id, playerIDs: sycamore.dropLast()),
                RankAssignment(venueID: venues[1].id, playerIDs: [mover] + latc),
            ],
            campID: camp.id
        )

        #expect(after.player(mover)?.venueID == venues[1].id)
        // Crossing the rule has to put them on a court in the venue they landed in, or they
        // vanish from Groups entirely.
        let landedOn = try #require(after.player(mover)?.groupID)
        #expect(after.group(landedOn)?.venueID == venues[1].id)
        #expect(after.players(in: venues[0].id).count == 2)
        #expect(after.players(in: venues[1].id).count == 4)
    }

    @Test("A camp-wide reorder naming a venue that is not there fails")
    func reorderCampWithAnUnknownVenue() async throws {
        let (repo, camp) = loaded()

        await #expect(throws: SycamoreError.unknownVenue) {
            try await repo.reorderCamp(
                [RankAssignment(venueID: UUID(), playerIDs: [])], campID: camp.id
            )
        }
    }

    @Test("Even out through the repository levels every court")
    func evenOutThroughTheRepository() async throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 4)], players: 10)
        // Everyone on court 1, which is what an import leaves behind.
        let first = camp.groups(in: camp.venues[0].id)[0].id
        for index in camp.players.indices { camp.players[index].groupID = first }
        camp.reindex()
        let repo = InMemoryRepository(camps: [camp])

        let after = try await repo.evenOut(camp.id)

        #expect(Fixture.courtSizes(after, in: camp.venues[0].id) == [3, 3, 2, 2])
    }

    @Test("Partition through the repository fills the venues by rank")
    func partitionThroughTheRepository() async throws {
        let camp = Fixture.camp(
            [.init("Sycamore", courts: 3), .init("LATC", courts: 3)], players: 12
        )
        let repo = InMemoryRepository(camps: [camp])

        let after = try await repo.partitionCamp(camp.id)

        #expect(Fixture.venueSizes(after) == [6, 6])
        #expect(after.players(in: after.orderedVenues[0].id).map(\.overallRank) == Array(1...6))
    }
}

@Suite("InMemoryRepository — the day")
struct RepositoryAttendanceTests {

    private func loaded() -> (InMemoryRepository, Camp) {
        var camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        camp.reindex()
        return (InMemoryRepository(camps: [camp]), camp)
    }

    @Test("Marking a kid away drops today's head-count, not the roster")
    func markAway() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups[0].id
        let away = camp.orderedPlayers[0].id

        let after = try await repo.setAttendance(
            playerID: away, day: .today, present: false, campID: camp.id
        )

        #expect(after.group(court)?.presentCount == 4)
        #expect(after.group(court)?.playerCount == 5)
        #expect(after.isAway(away))
    }

    @Test("An early pick-up is recorded without marking the kid away")
    func earlyPickup() async throws {
        let (repo, camp) = loaded()
        let kid = camp.orderedPlayers[0].id

        let after = try await repo.setEarlyPickup(
            playerID: kid, day: .today, leavesAt: TimeOfDay(14, 30), campID: camp.id
        )

        #expect(after.leavesAt(kid) == TimeOfDay(14, 30))
        #expect(!after.isAway(kid))
        #expect(after.attendance(for: kid)?.leavingEarlyLabel == "Leaves Wed at 14:30")
    }

    @Test("Cancelling a pick-up removes the row rather than blanking it")
    func cancelPickup() async throws {
        let (repo, camp) = loaded()
        let kid = camp.orderedPlayers[0].id

        _ = try await repo.setEarlyPickup(
            playerID: kid, day: .today, leavesAt: TimeOfDay(14, 30), campID: camp.id
        )
        let after = try await repo.setEarlyPickup(
            playerID: kid, day: .today, leavesAt: nil, campID: camp.id
        )

        #expect(after.attendance.isEmpty)
    }

    @Test("A pick-up on another day does not move today's head-count")
    func anotherDaysPickup() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups[0].id
        let kid = camp.orderedPlayers[0].id

        let after = try await repo.setAttendance(
            playerID: kid, day: .mon, present: false, campID: camp.id
        )

        #expect(after.group(court)?.presentCount == 5)
        #expect(!after.isAway(kid))
        #expect(after.isAway(kid, on: .mon))
    }

    @Test("Marking a kid who is not in the camp fails")
    func unknownKid() async throws {
        let (repo, camp) = loaded()

        await #expect(throws: SycamoreError.unknownPlayer) {
            try await repo.setAttendance(
                playerID: UUID(), day: .today, present: false, campID: camp.id
            )
        }
    }
}

@Suite("InMemoryRepository — staff")
struct RepositoryStaffTests {

    private func loaded() -> (InMemoryRepository, Camp) {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 4)
        camp.staff = [
            StaffMember(name: "Nass", role: .worker),
            StaffMember(name: "Hubert", role: .worker),
        ]
        camp.reindex()
        return (InMemoryRepository(camps: [camp]), camp)
    }

    @Test("One coach per court — assigning a second bumps the first")
    func oneCoachPerCourt() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups(in: camp.venues[0].id)[0]
        let nass = camp.staff[0], hubert = camp.staff[1]

        _ = try await repo.assignStaff(nass.id, toGroup: court.id, campID: camp.id)
        let after = try await repo.assignStaff(hubert.id, toGroup: court.id, campID: camp.id)

        #expect(after.coach(forGroup: court.id)?.id == hubert.id)
        #expect(after.staff(nass.id)?.assignment == nil)
        #expect(after.group(court.id)?.coachID == hubert.id)
    }

    @Test("Assigning to no court clears the post")
    func unassign() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups(in: camp.venues[0].id)[0]
        let nass = camp.staff[0]

        _ = try await repo.assignStaff(nass.id, toGroup: court.id, campID: camp.id)
        let after = try await repo.assignStaff(nass.id, toGroup: nil, campID: camp.id)

        #expect(after.staff(nass.id)?.isUnassigned == true)
        #expect(after.group(court.id)?.coachID == nil)
    }

    /// A trainer roams by default and nobody else does, so a role change is also a placement
    /// change — but only for someone who is not already standing somewhere.
    @Test("Making someone a trainer sets them roaming if they have no court")
    func trainersRoam() async throws {
        let (repo, camp) = loaded()
        let nass = camp.staff[0]

        let after = try await repo.updateStaffRole(nass.id, role: .trainer, campID: camp.id)

        #expect(after.staff(nass.id)?.isRoaming == true)
        #expect(after.staff(nass.id)?.courtChip == "Roaming")
    }

    @Test("A trainer who is already on a court stays on it")
    func trainersOnACourtStayPut() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups(in: camp.venues[0].id)[0]
        let nass = camp.staff[0]

        _ = try await repo.assignStaff(nass.id, toGroup: court.id, campID: camp.id)
        let after = try await repo.updateStaffRole(nass.id, role: .trainer, campID: camp.id)

        #expect(after.staff(nass.id)?.isRoaming == false)
        #expect(after.staff(nass.id)?.groupID == court.id)
    }

    @Test("Removing someone empties the court they were on")
    func removeStaff() async throws {
        let (repo, camp) = loaded()
        let court = camp.groups(in: camp.venues[0].id)[0]
        let nass = camp.staff[0]

        _ = try await repo.assignStaff(nass.id, toGroup: court.id, campID: camp.id)
        let after = try await repo.removeStaff(nass.id, campID: camp.id)

        #expect(after.staff.count == 1)
        #expect(after.group(court.id)?.coachID == nil)
    }

    @Test("Naming someone who is not on the roster fails", arguments: [true, false])
    func unknownStaff(_ viaRole: Bool) async throws {
        let (repo, camp) = loaded()

        await #expect(throws: SycamoreError.unknownStaff) {
            if viaRole {
                _ = try await repo.updateStaffRole(UUID(), role: .admin, campID: camp.id)
            } else {
                _ = try await repo.removeStaff(UUID(), campID: camp.id)
            }
        }
    }
}
