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

/// The same roster file, brought in again a week later.
///
/// Both writes are new — until now the repository could only ever *add* a kid — and both are
/// pinned here rather than only in the Supabase build because this suite is what
/// `SupabaseRepository` owes: same errors, same guarantee that a failure writes nothing, same
/// refusal to touch a ladder it was not asked about.
@Suite("InMemoryRepository — roster reconciliation")
struct RepositoryRosterTests {

    /// The design's camp: 100 kids ranked 1…N over two venues of six courts, everyone placed.
    /// `SampleData` reindexes on its way out, so a rank read off this fixture is the same number
    /// the repository will report back.
    private func loaded() -> (InMemoryRepository, Camp) {
        let camp = SampleData.uclaTennisCamp
        return (InMemoryRepository(camps: [camp]), camp)
    }

    @Test("Updating kids returns the whole camp, with the ladder in the order it was already in")
    func updateReturnsTheWholeCamp() async throws {
        let (repo, camp) = loaded()
        var patched = try #require(camp.orderedPlayers.first)
        patched.age = 15

        let after = try await repo.updatePlayers([patched], campID: camp.id)

        // The id sequence pins the head-count too, so there is no separate count assertion here.
        #expect(after.orderedPlayers.map(\.id) == camp.orderedPlayers.map(\.id))
        #expect(after.player(patched.id)?.age == 15)
        // Convention: a mutation returns the whole camp, so callers never patch local state.
        #expect(try await repo.camp(id: camp.id).player(patched.id)?.age == 15)
    }

    /// The three fields sent deliberately wrong here are the whole point of the method's shape. A
    /// file knows a name and an age; where a child stands is what the camp worked out over a
    /// morning, and a re-import that quietly reseated everybody would undo it.
    @Test("An update writes the fields a file can say and leaves venue, court and rank alone")
    func updateLeavesPlacementAlone() async throws {
        let (repo, camp) = loaded()
        let before = try #require(camp.orderedPlayers.first { $0.groupID != nil })
        var patched = before
        patched.firstName = "Wren"
        patched.lastInitial = "K"
        patched.lastName = "Kowalski"
        patched.age = 15
        patched.gender = .f
        patched.isReturning.toggle()
        patched.venueID = nil
        patched.groupID = nil
        patched.overallRank = 999
        patched.courtRank = 999

        let after = try await repo.updatePlayers([patched], campID: camp.id)
        let arrived = try #require(after.player(before.id))

        #expect(arrived.displayName == "Wren Kowalski")
        #expect(arrived.age == 15)
        #expect(arrived.gender == .f)
        #expect(arrived.isReturning == !before.isReturning)
        #expect(arrived.venueID == before.venueID)
        #expect(arrived.groupID == before.groupID)
        #expect(arrived.overallRank == before.overallRank)
        #expect(arrived.courtRank == before.courtRank)
    }

    /// The removal does no arithmetic at all — `reindex` closes the gap. What that has to mean is
    /// that everybody keeps the place they were already in, so the assertion is the whole sequence
    /// rather than "the count went down".
    @Test("Removing a kid closes the gap in the ladder without moving anybody past anybody")
    func removalClosesTheLadder() async throws {
        let (repo, camp) = loaded()
        let ladder = camp.orderedPlayers.map(\.id)
        let leaving = ladder[10]

        let after = try await repo.removePlayers([leaving], campID: camp.id)

        #expect(after.player(leaving) == nil)
        #expect(after.orderedPlayers.map(\.id) == ladder.filter { $0 != leaving })
        #expect(after.orderedPlayers.map(\.overallRank) == Array(1...after.players.count))
    }

    /// Two courts rather than one, so `courtRank` and `overallRank` do not coincide and the gap
    /// `reindex` closes is a real one. Somebody who is staying is marked away first, which is what
    /// makes the `presentCount` assertion say something: with nobody away it could only ever
    /// repeat `playerCount`.
    @Test("Removing a kid takes them off their court and drops that court's head-count by one")
    func removalEmptiesASeat() async throws {
        var camp = Fixture.camp([.init("Sycamore", courts: 2)], players: 6)
        camp.evenOut()
        let repo = InMemoryRepository(camps: [camp])
        let court = camp.groups(in: camp.venues[0].id)[0]
        let seated = camp.players(inGroup: court.id).map(\.id)
        let leaving = try #require(seated.first)
        let away = try #require(seated.last)
        _ = try await repo.setAttendance(playerID: away, day: .today, present: false, campID: camp.id)

        let after = try await repo.removePlayers([leaving], campID: camp.id)

        #expect(after.players(inGroup: court.id).map(\.id) == Array(seated.dropFirst()))
        #expect(after.players(inGroup: court.id).map(\.courtRank) == Array(1...(seated.count - 1)))
        #expect(after.group(court.id)?.playerCount == seated.count - 1)
        #expect(after.group(court.id)?.presentCount == seated.count - 2)
    }

    /// What hangs off a kid goes with them, because in Postgres it does: `attendance.player_id`
    /// cascades. Left behind, the row would be a fact about nobody — and one the head-counts
    /// would still be reading.
    @Test("A removed kid takes their attendance with them")
    func removalTakesTheAttendance() async throws {
        let camp = Fixture.camp([.init("Sycamore", courts: 1)], players: 5)
        let repo = InMemoryRepository(camps: [camp])
        let leaving = camp.orderedPlayers[0].id
        let staying = camp.orderedPlayers[1].id
        for kid in [leaving, staying] {
            _ = try await repo.setAttendance(
                playerID: kid, day: .today, present: false, campID: camp.id
            )
        }

        let after = try await repo.removePlayers([leaving], campID: camp.id)

        #expect(after.attendance.map(\.playerID) == [staying])
        #expect(after.isAway(staying))
    }

    @Test("Removing a kid who is not at this camp throws, and nothing else in the batch is written")
    func removingAStrangerWritesNothing() async throws {
        let (repo, camp) = loaded()
        let ours = try #require(camp.orderedPlayers.first).id

        await #expect(throws: SycamoreError.unknownPlayer) {
            try await repo.removePlayers([ours, UUID()], campID: camp.id)
        }

        let stored = try await repo.camp(id: camp.id)
        #expect(stored.players.count == camp.players.count)
        #expect(stored.player(ours) != nil)
    }

    @Test("Updating a kid who is not at this camp throws, and the rest of the batch is not written either")
    func updatingAStrangerWritesNothing() async throws {
        let (repo, camp) = loaded()
        var ours = try #require(camp.orderedPlayers.first)
        let wasCalled = ours.firstName
        ours.firstName = "Wren"
        // The same kid under an id this camp has never seen: it is the id that is checked, and
        // inventing a name and an age for the stranger would only invite a reader to look for
        // significance in them.
        var stranger = ours
        stranger.id = UUID()

        await #expect(throws: SycamoreError.unknownPlayer) {
            try await repo.updatePlayers([ours, stranger], campID: camp.id)
        }

        #expect(try await repo.camp(id: camp.id).player(ours.id)?.firstName == wasCalled)
    }

    /// `SupabaseRepository` answers both of these without opening the per-camp mutex, because
    /// PostgREST rejects `in.()` and a PATCH of nothing is a request with nothing to say. Here
    /// there is no round trip to skip — what is being pinned is that neither is an *error*, since
    /// a tick list nobody ticked is an ordinary way to leave `8d`.
    @Test("Removing nobody is not a round trip and not an error")
    func removingNobody() async throws {
        let (repo, camp) = loaded()

        let after = try await repo.removePlayers([], campID: camp.id)

        #expect(after.orderedPlayers.map(\.id) == camp.orderedPlayers.map(\.id))
    }

    @Test("Updating nobody is not a round trip and not an error")
    func updatingNobody() async throws {
        let (repo, camp) = loaded()

        let after = try await repo.updatePlayers([], campID: camp.id)

        #expect(after.orderedPlayers.map(\.id) == camp.orderedPlayers.map(\.id))
    }

    /// The one place the two builds can silently disagree.
    ///
    /// "What a roster file owns" is written twice — as Swift assignments in
    /// `InMemoryRepository.updatePlayers`, and as column names in
    /// `SupabaseRepository.playerFields` — and nothing in the type system ties them together. Add
    /// a seventh roster field to one and not the other and it updates offline but not online,
    /// which is the failure that only shows up on a real camp's wifi. `Player.lastName` is being
    /// filled in by imports right now (`Models.swift:427-429`), so this is a live risk rather than
    /// a hypothetical one.
    ///
    /// Encoded rather than read off `RowValues`, which keeps its columns private — the JSON is
    /// what actually goes to PostgREST, so it is the honest thing to assert about.
    @Test("The update payload carries what a file owns and no camp state")
    func theWireColumnsAreTheFilesColumns() throws {
        let kid = Player(
            firstName: "Wren", lastInitial: "K", lastName: "Kowalski", age: 15, gender: .f,
            isReturning: true, venueID: UUID(), groupID: UUID(), overallRank: 7, courtRank: 3
        )

        // The repository's own encoder, not a fresh one: it snake-cases keys, and asserting
        // against anything else would be asserting about a request nobody sends.
        let payload = try JSONSerialization.jsonObject(
            with: SupabaseCoding.encoder().encode(SupabaseRepository.playerFields(kid))
        )
        let columns = Set((payload as? [String: Any] ?? [:]).keys)

        #expect(columns == [
            "first_name", "last_initial", "last_name", "age", "gender", "is_returning",
        ])
        // Named separately from the equality above so a failure says which rule broke: `id` is the
        // row's identity, and `site_id` and `group_id` are camp state — a PATCH carrying either
        // would let a re-imported file reseat a kid somebody had deliberately placed.
        #expect(columns.isDisjoint(with: ["id", "site_id", "group_id"]))
    }

    @Test("Neither write reaches a camp that is not there", arguments: [true, false])
    func unknownCamp(_ viaUpdate: Bool) async throws {
        let (repo, camp) = loaded()
        let kid = try #require(camp.orderedPlayers.first)

        await #expect(throws: SycamoreError.unknownCamp) {
            if viaUpdate {
                _ = try await repo.updatePlayers([kid], campID: UUID())
            } else {
                _ = try await repo.removePlayers([kid.id], campID: UUID())
            }
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
        // Against `.today` rather than the literal "Wed" this used to assert. That passed only
        // because `Weekday.today` was stubbed to Wednesday; now that it reads the calendar, a
        // hardcoded day makes this test fail on six days out of seven — which is exactly what it
        // did the first time the stub came out.
        #expect(
            after.attendance(for: kid)?.leavingEarlyLabel
                == "Leaves \(Weekday.today.shortName) at 14:30"
        )
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

/// Alex coaches Court 3 at Sycamore and has a membership carrying today's post, so the design's
/// camp is the only fixture where a venue edit can be followed all the way from `upsert` through
/// the camp graph and out into what the picker and Profile read.
@Suite("InMemoryRepository — venue edits")
struct RepositoryVenueEditTests {

    private func loaded() -> (InMemoryRepository, Camp) {
        let repo = InMemoryRepository(
            accounts: [SampleData.account],
            memberships: SampleData.memberships,
            camps: SampleData.camps
        )
        return (repo, SampleData.uclaTennisCamp)
    }

    private func alexsTile(_ repo: InMemoryRepository, _ camp: Camp) async throws -> TodayAssignment {
        let memberships = try await repo.memberships(forAccount: SampleData.account.id)
        let membership = try #require(memberships.first { $0.campID == camp.id })
        return try #require(membership.todayAssignment)
    }

    /// Profile's "On today" tile draws the venue's emoji *on* the venue's tint. The projection
    /// took the emoji off the assignment's snapshot and the tint off the live venue, so the two
    /// halves of one tile arrived from two places and a new emoji landed on the tile before its
    /// colour did — 🌳 on citron.
    @Test("The today tile's emoji and tint come from the same venue")
    func theTodayTileIsOneVenue() async throws {
        let (repo, camp) = loaded()
        var venue = SampleData.sycamore
        venue.icon = "🎾"
        venue.tint = .suggested(for: "🎾")

        _ = try await repo.updateVenue(venue, campID: camp.id)

        let tile = try await alexsTile(repo, camp)
        #expect(tile.venueIcon == "🎾")
        #expect(tile.venueTint == .citron)
    }

    @Test("A renamed venue reaches the camp picker's copy of today's post")
    func theTodayTileFollowsARename() async throws {
        let (repo, camp) = loaded()
        var venue = SampleData.sycamore
        venue.name = "Sycamore North"

        _ = try await repo.updateVenue(venue, campID: camp.id)

        let tile = try await alexsTile(repo, camp)
        #expect(tile.venueName == "Sycamore North")
        #expect(tile.pathLabel == "Sycamore North · Court 3")
    }

    /// The same edit, read back off the camp graph rather than off the membership — Setup's staff
    /// card and the staff sheet go this way round.
    @Test("A renamed venue reaches the coach's own chip")
    func theCoachsChipFollowsARename() async throws {
        let (repo, camp) = loaded()
        let alex = try #require(camp.staff.first { $0.accountID == SampleData.account.id })
        var venue = SampleData.sycamore
        venue.name = "Sycamore North"
        venue.icon = "🎾"

        let after = try await repo.updateVenue(venue, campID: camp.id)

        #expect(after.staff(alex.id)?.assignment?.chip == "🎾 C3")
        #expect(after.staff(alex.id)?.detailLine == "Worker · Sycamore North · Court 3")
    }
}
