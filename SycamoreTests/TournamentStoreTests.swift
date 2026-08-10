//
//  TournamentStoreTests.swift
//  SycamoreTests
//
//  Striking a draw, writing it down, and reading it back the same.
//
//  `TournamentTests.swift` covers the arithmetic — who is paired with whom, how a bracket pads, why
//  a snake draft balances. This file covers the layer over it, which has three jobs and gets tested
//  on all three:
//
//    - **A draw survives the round trip whole.** `Tournament` is `Hashable` on derived ids, so a
//      write-then-read either comes back `==` or does not, with no partial credit. That is a
//      stronger assertion than it looks: it pins the entrants, their members' order, every fixture,
//      every forward reference into an earlier match, and the scores.
//    - **The venue's list decides the name.** "Tournament 3" is a fact about a list, not about a
//      draw, so `Tournament` has never been shown one and `AppStore` is where the counting happens.
//      Auto-numbering is one line and one line is exactly what silently starts over at 1.
//    - **A drawn match is refused before it is sent.** `tournament_matches_no_draw` is the rule and
//      Postgres is where it cannot be got round — but a CHECK violation is not a sentence to put in
//      front of a coach, and a rule enforced in one build and not the other is a rule you find out
//      about on camp wifi. Both builds refuse; this pins the offline one, which is the one a test
//      can run.
//
//  Driven through `InMemoryRepository`, which holds a whole `Tournament` value and therefore cannot
//  disagree with itself about a bracket. What it *can* disagree with is Postgres, and the two places
//  that is known to happen are written down in `SupabaseRepository+Tournament.swift`'s header rather
//  than asserted here, because no test on this side of the wire can see them.
//

import Foundation
import Testing

@testable import Sycamore

// MARK: - Fixtures

/// Two venues, `players` kids, all of them on the first venue's first court.
///
/// Everybody in one place is what `CampFixture` already does and it suits this file: a pool taken
/// over court 0 is then the whole roster in ladder order, so a test that asserts an entrant count
/// is asserting about the draw rather than about where `evenOut` happened to put somebody.
private func loaded(players: Int = 8) -> (InMemoryRepository, Camp, Venue.ID, Venue.ID) {
    let camp = Fixture.camp(
        [.init("Home", courts: 2), .init("Away", courts: 2)], players: players
    )
    let venues = camp.orderedVenues.map(\.id)
    return (InMemoryRepository(camps: [camp]), camp, venues[0], venues[1])
}

@MainActor
private func store(_ camp: Camp) -> AppStore {
    let store = AppStore(repository: InMemoryRepository(camps: [camp]))
    store.camp = camp
    return store
}

/// A draw over the whole of a venue's first court, struck the way the store strikes one.
private func draw(
    _ seeding: Tournament.Seeding,
    named name: String = "Tournament 1",
    in camp: Camp,
    at venueID: Venue.ID,
    courtIndices: [Int] = [0],
    days: Int = 1
) -> Tournament {
    Tournament.seeded(
        seeding,
        name: name,
        pool: Tournament.pool(
            camp.players, across: camp.groups(in: venueID), courtIndices: courtIndices
        ),
        courtIndices: courtIndices,
        days: days
    )
}

// MARK: - The repository

@Suite("InMemoryRepository — tournaments")
struct TournamentRepositoryTests {

    // MARK: Round trips

    @Test("A singles round robin comes back exactly as it went in")
    func singlesRoundRobinRoundTrips() async throws {
        let (repo, camp, home, _) = loaded()
        let singles = draw(.singles(.roundRobin), in: camp, at: home)

        let written = try await repo.addTournaments([singles], toVenue: home, campID: camp.id)

        #expect(written == [singles])
        // Eight entrants play each other once.
        #expect(singles.entrants.count == 8)
        #expect(singles.matches.count == 28)
        let reread = try await repo.tournaments(forVenue: home, campID: camp.id)
        #expect(reread == [singles])
    }

    /// The one that would break quietly. A knockout's later rounds hold `.winner(of: "m3")` rather
    /// than an entrant, so a persistence layer that resolved forward references on the way down —
    /// or lost the round they belong to — would still hand back a plausible-looking bracket.
    @Test("A doubles knockout keeps its forward references and its byes")
    func doublesKnockoutRoundTrips() async throws {
        let (repo, camp, home, _) = loaded(players: 11)
        let doubles = draw(.doubles(.knockout), in: camp, at: home)

        let written = try await repo.addTournaments([doubles], toVenue: home, campID: camp.id)
        let read = try #require(written.first)

        #expect(read == doubles)
        // 11 kids make five pairs and one kid with nobody to play with; six entrants pad to a
        // bracket of eight, so round one has four fixtures and two of them are byes.
        #expect(read.entrants.count == 6)
        #expect(read.unpairedEntrants.count == 1)
        #expect(read.matches.filter { $0.round == 1 }.count == 4)
        #expect(read.matches.filter(\.isBye).count == 2)
        // And the later rounds still name matches rather than entrants.
        let later = read.matches.filter { $0.round > 1 }
        #expect(later.count == 3)
        #expect(later.allSatisfy { match in
            if case .winner = match.a, case .winner = match.b { return true } else { return false }
        })
    }

    @Test("A team draft comes back with its rosters in draft order and no fixtures")
    func teamDraftRoundTrips() async throws {
        let (repo, camp, home, _) = loaded()
        let teams = draw(.team(count: 3), in: camp, at: home)

        let written = try await repo.addTournaments([teams], toVenue: home, campID: camp.id)
        let read = try #require(written.first)

        #expect(read == teams)
        #expect(read.teams.count == 3)
        #expect(read.entrants.isEmpty)
        // Team tennis has no fixtures — the design leaves them for later — and no mode at all.
        #expect(read.matches.isEmpty)
        #expect(read.mode == nil)
        // Eight kids snaked over three teams: 3, 3, 2.
        #expect(read.teams.map(\.playerIDs.count) == [3, 3, 2])
    }

    @Test("A venue nobody has drawn at reads empty rather than raising")
    func anUndrawnVenueIsEmpty() async throws {
        let (repo, camp, home, away) = loaded()
        _ = try await repo.addTournaments(
            [draw(.singles(.roundRobin), in: camp, at: home)], toVenue: home, campID: camp.id
        )

        let atAway = try await repo.tournaments(forVenue: away, campID: camp.id)
        #expect(atAway.isEmpty)
        // And a venue that is not in the camp at all, which the Postgres read answers as a filter
        // matching nothing rather than as an error.
        let atNowhere = try await repo.tournaments(forVenue: Venue.ID(), campID: camp.id)
        #expect(atNowhere.isEmpty)
    }

    @Test("Draws belong to their venue and two repositories do not share them")
    func drawsAreScoped() async throws {
        let (repo, camp, home, away) = loaded()
        let mine = draw(.singles(.roundRobin), in: camp, at: home)
        _ = try await repo.addTournaments([mine], toVenue: home, campID: camp.id)
        _ = try await repo.addTournaments(
            [draw(.singles(.knockout), named: "Away 1", in: camp, at: away, courtIndices: [])],
            toVenue: away, campID: camp.id
        )

        let here = try await repo.tournaments(forVenue: home, campID: camp.id)
        let there = try await repo.tournaments(forVenue: away, campID: camp.id)
        #expect(here.map(\.name) == ["Tournament 1"])
        #expect(there.map(\.name) == ["Away 1"])

        // A second repository over the same camp starts empty. The offline build's draws are held
        // beside the repository rather than on it (see `TournamentRepository.swift`), and "beside"
        // has to mean *this* repository — a store keyed on the camp, or on a reused address, would
        // hand one repository's draws to another and no test that used one repository could see it.
        let other = InMemoryRepository(camps: [camp])
        let itsDraws = try await other.tournaments(forVenue: home, campID: camp.id)
        #expect(itsDraws.isEmpty)
    }

    @Test("A draw at a venue the camp does not have is refused")
    func anUnknownVenueIsRefused() async throws {
        let (repo, camp, home, _) = loaded()
        await #expect(throws: SycamoreError.unknownVenue) {
            try await repo.addTournaments(
                [draw(.singles(.roundRobin), in: camp, at: home)],
                toVenue: Venue.ID(), campID: camp.id
            )
        }
    }

    // MARK: Scores

    @Test("A score is recorded against its match and cleared again")
    func scoreIsSetAndCleared() async throws {
        let (repo, camp, home, _) = loaded()
        let singles = draw(.singles(.roundRobin), in: camp, at: home)
        _ = try await repo.addTournaments([singles], toVenue: home, campID: camp.id)
        let match = try #require(singles.playableMatches.first)

        let scored = try await repo.setScore(
            Tournament.Score(6, 3), forMatch: match.id, in: singles.id,
            atVenue: home, campID: camp.id
        )
        #expect(scored.first?.scores[match.id] == Tournament.Score(6, 3))
        #expect(scored.first?.playedCount == 1)
        // The result is what the standings are built from, so the winner has to have moved.
        let winner = try #require(scored.first?.winner(of: match.id))
        #expect(winner == singles.entrantID(of: match.a))

        let cleared = try await repo.setScore(
            nil, forMatch: match.id, in: singles.id, atVenue: home, campID: camp.id
        )
        // Cleared, not zeroed. `scores` is sparse and an absent key is what "not played yet" is.
        #expect(cleared.first?.scores[match.id] == nil)
        #expect(cleared.first?.playedCount == 0)
        #expect(cleared == [singles])
    }

    /// The design's score sheet returns early on equal numbers and
    /// `tournament_matches_no_draw` restates it at the column. This is the third statement of it,
    /// on the side a test can reach.
    @Test("A drawn match is refused, and nothing is written")
    func aDrawIsRefused() async throws {
        let (repo, camp, home, _) = loaded()
        let singles = draw(.singles(.roundRobin), in: camp, at: home)
        _ = try await repo.addTournaments([singles], toVenue: home, campID: camp.id)
        let match = try #require(singles.playableMatches.first)

        await #expect(throws: TournamentError.drawnMatch) {
            try await repo.setScore(
                Tournament.Score(6, 6), forMatch: match.id, in: singles.id,
                atVenue: home, campID: camp.id
            )
        }
        // Refused before anything moved: the draw is exactly as it was struck.
        let after = try await repo.tournaments(forVenue: home, campID: camp.id)
        #expect(after == [singles])
    }

    @Test("A negative score is refused too — the other CHECK on the same columns")
    func aNegativeScoreIsRefused() async throws {
        let (repo, camp, home, _) = loaded()
        let singles = draw(.singles(.roundRobin), in: camp, at: home)
        _ = try await repo.addTournaments([singles], toVenue: home, campID: camp.id)
        let match = try #require(singles.playableMatches.first)

        await #expect(throws: TournamentError.impossibleScore) {
            try await repo.setScore(
                Tournament.Score(-1, 3), forMatch: match.id, in: singles.id,
                atVenue: home, campID: camp.id
            )
        }
    }

    @Test("A score against a match that is not in the draw is refused")
    func anUnknownMatchIsRefused() async throws {
        let (repo, camp, home, _) = loaded()
        let singles = draw(.singles(.roundRobin), in: camp, at: home)
        _ = try await repo.addTournaments([singles], toVenue: home, campID: camp.id)

        await #expect(throws: TournamentError.unknownMatch) {
            try await repo.setScore(
                Tournament.Score(6, 3), forMatch: "m999", in: singles.id,
                atVenue: home, campID: camp.id
            )
        }
        await #expect(throws: TournamentError.unknownTournament) {
            try await repo.setScore(
                Tournament.Score(6, 3), forMatch: "m1", in: Tournament.ID(),
                atVenue: home, campID: camp.id
            )
        }
    }

    // MARK: Teams

    @Test("A team's coaches are ids, replaced wholesale, and deduplicated")
    func teamCoachesAreCovered() async throws {
        let (repo, camp, home, _) = loaded()
        let teams = draw(.team(count: 2), in: camp, at: home)
        _ = try await repo.addTournaments([teams], toVenue: home, campID: camp.id)
        let alex = StaffMember.ID()
        let sam = StaffMember.ID()

        let one = try await repo.setTeamCoaches(
            [alex, sam, alex], forTeam: 0, in: teams.id, atVenue: home, campID: camp.id
        )
        // `(entrant_id, coach_id)` is a primary key on the other side, so a name twice is a 23505
        // there and must be collapsed here rather than drawn as two chips.
        #expect(one.first?.teams.first?.coachIDs == [alex, sam])
        // The other team is untouched.
        #expect(one.first?.teams.last?.coachIDs.isEmpty == true)

        // A cover, not a merge: the second call replaces the first.
        let two = try await repo.setTeamCoaches(
            [sam], forTeam: 0, in: teams.id, atVenue: home, campID: camp.id
        )
        #expect(two.first?.teams.first?.coachIDs == [sam])

        await #expect(throws: TournamentError.unknownTeam) {
            try await repo.setTeamCoaches(
                [alex], forTeam: 9, in: teams.id, atVenue: home, campID: camp.id
            )
        }
    }

    // MARK: Removal

    @Test("Removing a draw takes it off the list and leaves the others alone")
    func removingADraw() async throws {
        let (repo, camp, home, _) = loaded()
        let first = draw(.singles(.roundRobin), named: "Tournament 1", in: camp, at: home)
        let second = draw(.doubles(.roundRobin), named: "Tournament 2", in: camp, at: home)
        _ = try await repo.addTournaments([first, second], toVenue: home, campID: camp.id)

        let left = try await repo.removeTournament(first.id, fromVenue: home, campID: camp.id)
        #expect(left == [second])

        await #expect(throws: TournamentError.unknownTournament) {
            try await repo.removeTournament(first.id, fromVenue: home, campID: camp.id)
        }
    }
}

// MARK: - The intents

@MainActor
@Suite("AppStore — tournaments")
struct AppStoreTournamentTests {

    private static func loaded(players: Int = 8) -> (AppStore, Camp, Venue.ID, Venue.ID) {
        let camp = Fixture.camp(
            [.init("Home", courts: 2), .init("Away", courts: 2)], players: players
        )
        let venues = camp.orderedVenues.map(\.id)
        return (store(camp), camp, venues[0], venues[1])
    }

    // MARK: Loading

    @Test("A load records which venue the list is for")
    func loadRecordsItsVenue() async throws {
        let (store, _, home, away) = Self.loaded()

        // Nil until something asks, which is what tells "this venue has no draws" from "nobody has
        // asked yet" — the two states an empty array cannot tell apart.
        #expect(store.loadedTournamentVenueID == nil)

        await store.loadTournaments(at: home)
        #expect(store.loadedTournamentVenueID == home)
        #expect(store.tournaments.isEmpty)
        #expect(store.errorMessage == nil)

        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
        )
        #expect(store.tournaments.count == 1)

        // Switching venue clears rather than redrawing one venue's draws under another's name.
        await store.loadTournaments(at: away)
        #expect(store.loadedTournamentVenueID == away)
        #expect(store.tournaments.isEmpty)
    }

    // MARK: Names

    @Test("An unnamed draw is numbered off the venue's list")
    func autoNumbering() async throws {
        let (store, _, home, away) = Self.loaded()
        await store.loadTournaments(at: home)

        for _ in 0..<3 {
            await store.createTournament(
                .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
            )
        }
        #expect(store.tournaments.map(\.name) == ["Tournament 1", "Tournament 2", "Tournament 3"])

        // The count is per venue, so the other venue starts at one again.
        await store.loadTournaments(at: away)
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [], days: 1, at: away
        )
        #expect(store.tournaments.map(\.name) == ["Tournament 1"])
    }

    /// The case the count is *for*. A create fired at a venue this store has never loaded has no
    /// list to count, and numbering from zero would put a second "Tournament 1" on the screen —
    /// which nothing in the schema refuses, because names are not unique.
    @Test("Numbering reads the venue's list even when the tab has not loaded it")
    func autoNumberingWithoutALoad() async throws {
        let (store, camp, home, _) = Self.loaded()
        let repo = try #require(store.tournamentData)
        _ = try await repo.addTournaments(
            [draw(.singles(.roundRobin), in: camp, at: home)], toVenue: home, campID: camp.id
        )

        #expect(store.loadedTournamentVenueID == nil)
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
        )

        #expect(store.tournaments.map(\.name) == ["Tournament 1", "Tournament 2"])
        #expect(store.loadedTournamentVenueID == home)
    }

    @Test("A typed name is kept; a blank one falls back to the number")
    func typedNames() async throws {
        let (store, _, home, _) = Self.loaded()
        await store.loadTournaments(at: home)

        await store.createTournament(
            .singles(.roundRobin), name: "  Friday finals  ", courtIndices: [0], days: 1, at: home
        )
        await store.createTournament(
            .singles(.roundRobin), name: "   ", courtIndices: [0], days: 1, at: home
        )
        // Trimmed, and a name that is only whitespace is no name at all — `tournaments_name_len`
        // would refuse it outright, and the auto-number is what it is for.
        #expect(store.tournaments.map(\.name) == ["Friday finals", "Tournament 2"])
    }

    @Test("A name past what the column holds is cut rather than rejected")
    func longNamesAreCut() async throws {
        let (store, _, home, _) = Self.loaded()
        await store.createTournament(
            .singles(.roundRobin), name: String(repeating: "z", count: 200),
            courtIndices: [0], days: 1, at: home
        )
        #expect(store.tournaments.first?.name.count == 80)
        #expect(store.errorMessage == nil)
    }

    @Test("Days are held to what the column takes")
    func daysAreClamped() async throws {
        let (store, _, home, _) = Self.loaded()
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 90, at: home
        )
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 0, at: home
        )
        #expect(store.tournaments.map(\.days) == [14, 1])
    }

    // MARK: Bands

    @Test("A band split makes one draw per band and keeps the venue's numbering going")
    func bandedCreation() async throws {
        let (store, _, home, _) = Self.loaded()
        await store.loadTournaments(at: home)
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
        )

        await store.createBandedTournaments(
            .singles(.knockout), into: 3, courtIndices: [0], days: 1, at: home
        )

        // `Tournament.banded` numbers its own results 1…N, which is right for a function that has
        // never seen a venue's list and would put a second "Tournament 1" here.
        #expect(store.tournaments.map(\.name)
            == ["Tournament 1", "Tournament 2", "Tournament 3", "Tournament 4"])
        // Eight kids into three bands is 3 / 3 / 2, strongest band first.
        #expect(store.tournaments.dropFirst().map(\.entrants.count) == [3, 3, 2])
    }

    @Test("A ladder too short for the bands asked for makes fewer draws, not empty ones")
    func bandedCreationDropsEmptyBands() async throws {
        let (store, _, home, _) = Self.loaded(players: 3)
        await store.createBandedTournaments(
            .singles(.roundRobin), into: 5, courtIndices: [0], days: 1, at: home
        )
        // Three kids into five bands is three bands of one and two of nothing, and a tournament
        // with nobody in it is not something a camp can run.
        #expect(store.tournaments.count == 3)
        #expect(store.tournaments.allSatisfy { $0.entrants.count == 1 })
    }

    // MARK: The ladder

    @Test("The ladder is the venue's kids, best first, and only the ones on a court")
    func ladderIsTheVenues() async throws {
        let (store, camp, _, _) = Self.loaded()
        #expect(store.tournamentLadder.map(\.firstName) == Fixture.ladder(camp))

        // A kid on no court is mid-import and is not on a rung, so a draw cannot include them.
        var loose = camp
        loose.players[0].groupID = nil
        store.camp = loose
        #expect(store.tournamentLadder.count == 7)
    }

    // MARK: Writes against a loaded list

    @Test("A score reaches the list; a drawn one reaches the banner instead")
    func scoringThroughTheStore() async throws {
        let (store, _, home, _) = Self.loaded()
        await store.loadTournaments(at: home)
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
        )
        let singles = try #require(store.tournaments.first)
        let match = try #require(singles.playableMatches.first)

        await store.setScore(Tournament.Score(6, 2), forMatch: match.id, in: singles.id)
        #expect(store.errorMessage == nil)
        #expect(store.tournaments.first?.scores[match.id] == Tournament.Score(6, 2))

        await store.setScore(Tournament.Score(6, 6), forMatch: match.id, in: singles.id)
        #expect(store.errorMessage == TournamentError.drawnMatch.errorDescription)
        // The refused write left the recorded one standing.
        #expect(store.tournaments.first?.scores[match.id] == Tournament.Score(6, 2))
    }

    @Test("Removing a draw takes it off the list the reader is looking at")
    func removingThroughTheStore() async throws {
        let (store, _, home, _) = Self.loaded()
        await store.loadTournaments(at: home)
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
        )
        await store.createTournament(
            .doubles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: home
        )
        let first = try #require(store.tournaments.first)

        await store.removeTournament(first.id)

        #expect(store.errorMessage == nil)
        #expect(store.tournaments.map(\.name) == ["Tournament 2"])
    }

    @Test("A team's coaches are set through the store and read back as ids")
    func teamCoachesThroughTheStore() async throws {
        let (store, camp, home, _) = Self.loaded()
        await store.loadTournaments(at: home)
        await store.createTournament(
            .team(count: 2), name: nil, courtIndices: [0], days: 1, at: home
        )
        let teams = try #require(store.tournaments.first)
        let coach = StaffMember.ID()

        await store.setTeamCoaches([coach], forTeam: 0, in: teams.id)

        #expect(store.errorMessage == nil)
        #expect(store.tournaments.first?.teams.first?.coachIDs == [coach])
        // Ids and not names, which is the whole point of the field: the name is read off the camp
        // at the moment of drawing, so a coach correcting their own spelling does not silently
        // leave every team they run.
        #expect(camp.staff(coach) == nil)
    }

    /// Nothing loaded means there is no draw on screen to act on, so the three writes do nothing
    /// rather than falling back to `readVenueID` and issuing a write that could only fail.
    @Test("A write with no list loaded is a no-op, not a banner")
    func writesNeedALoadedList() async throws {
        let (store, _, _, _) = Self.loaded()
        await store.removeTournament(Tournament.ID())
        #expect(store.errorMessage == nil)
        #expect(store.tournaments.isEmpty)
    }
}

// MARK: - A venue switch mid-load

/// The Tournament tab reloads through `.task(id: readVenueID)` and nothing else, so a load that
/// resolves *after* the reader has moved on has no second chance to be corrected: whatever it
/// publishes stays until the next write or the next venue switch. `loadTournaments` and `write`
/// both guard against that by re-reading the venue after their await.
///
/// **The drop itself is not pinned here.** Reproducing it needs the venue to change *during* the
/// suspension, and `InMemoryRepository` resolves without ever yielding to a point a test could
/// interleave at — setting `chosenVenueID` before the call just moves the value the guard reads at
/// entry, which is not the same thing. A test shaped like that passes whether or not the guard
/// exists, so it is not written; it would be evidence of nothing. What is pinned is the half a
/// regression would actually hit: the guard must not reject the loads that should land, which is
/// exactly what an over-tight first attempt at it did (it compared against `readVenueID` rather
/// than against the value at entry, and broke "A load records which venue the list is for").
@MainActor
@Suite("AppStore — tournaments, the guard does not over-reject")
struct TournamentLoadGuardTests {

    private static func loaded() -> (AppStore, Venue.ID, Venue.ID) {
        let camp = Fixture.camp([.init("Home", courts: 2), .init("Away", courts: 2)], players: 8)
        let venues = camp.orderedVenues.map(\.id)
        return (store(camp), venues[0], venues[1])
    }

    @Test("An ordinary load, for the venue on screen, publishes")
    func theOrdinaryLoadLands() async {
        let (store, home, _) = Self.loaded()

        store.chosenVenueID = home
        await store.loadTournaments(at: home)

        #expect(store.loadedTournamentVenueID == home)
        #expect(store.errorMessage == nil)
    }

    @Test("A load for a venue nobody is standing on publishes too")
    func aDirectLoadLands() async {
        let (store, home, away) = Self.loaded()

        // The guard asks whether the venue *moved*, not whether this load is for the current one.
        // Every test in the suite above loads a named venue directly and must keep working.
        store.chosenVenueID = home
        await store.loadTournaments(at: away)

        #expect(store.loadedTournamentVenueID == away)
        #expect(store.errorMessage == nil)
    }

    @Test("A write after a direct load still reaches the list")
    func aWriteAfterADirectLoadLands() async {
        let (store, home, away) = Self.loaded()

        store.chosenVenueID = home
        await store.loadTournaments(at: away)
        await store.createTournament(
            .singles(.roundRobin), name: nil, courtIndices: [0], days: 1, at: away
        )

        #expect(store.tournaments.count == 1)
        #expect(store.errorMessage == nil)
    }
}
