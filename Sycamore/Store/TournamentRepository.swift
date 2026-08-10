//
//  TournamentRepository.swift
//  Sycamore
//
//  The reads and writes the Tournament tab needs, and the in-memory implementation.
//
//  A third protocol beside `SycamoreRepository` and `SectionEightData`, for the reason
//  `SectionEightRepository.swift` gives for being the second: the file every feature edits is the
//  file every feature conflicts in, and the Tournament tab is being built by several hands at once.
//  Same shape as the rest of the seam — `async throws`, `Sendable`, every write answering with the
//  venue's whole list — so the Postgres half drops in behind it without a screen changing.
//
//  ── WHAT THIS LAYER DOES AND DOES NOT DECIDE ─────────────────────────────────────────────────
//
//  It does not seed. `Tournament.seeded(_:name:pool:courtIndices:days:)` is a pure function over a
//  ladder and it stays that way: the store narrows the camp's players into a pool, hands it to the
//  model, and gives the finished value to a repository to write down. Nothing below re-derives a
//  bracket, which is what keeps "does this pool always draw the same way?" a question `Tournament`
//  can answer on its own — see that file's header, and `TournamentTests.seedingIsDeterministic`.
//
//  It does decide the two things that are facts about a *venue's list* rather than about a draw:
//  what a new draw is called (`AppStore+Tournament.swift`, where the list is in hand) and where it
//  sits in the list (`sort_index`, in the Postgres half, which is the only build with a list to
//  count).
//
//  ── THE ONE PLACE THIS DEPARTS FROM `SectionEightData`, AND IT IS TEMPORARY ───────────────────
//
//  `Repository.swift` spells `protocol SycamoreRepository: SectionEightData`, which is what lets a
//  call site hold one repository and see both halves, and it declares `InMemoryRepository`'s
//  storage — `sectionEightBlocks` and friends are internal precisely so an extension in another
//  file can reach them. This work was not allowed to edit that file: it is being edited by other
//  agents on this branch right now, and a merge conflict there is a merge conflict for all of them.
//
//  So two accommodations stand in, both of which are two lines away from going:
//
//  1. `AppStore+Tournament.swift` reaches this protocol through a conditional cast rather than
//     through `SycamoreRepository`'s inheritance list. Both shipped repositories conform, so the
//     nil branch is unreachable in the app.
//  2. The offline build's draws are held in `OfflineDraws` below, beside the repository rather than
//     on it, because a Swift extension cannot add a stored property.
//
//  Folding them in is: add `TournamentData` to `SycamoreRepository`'s inheritance clause, and add
//  `var tournamentDraws: [Venue.ID: [Tournament]] = [:]` beside `sectionEightBlocks`. Then the cast
//  becomes a plain call and `OfflineDraws` deletes.
//

import Foundation

// MARK: - Protocol

protocol TournamentData: Sendable {

    /// A venue's draws, oldest first.
    ///
    /// Venue-scoped rather than camp-wide, which is the opposite call from the Inbox's
    /// `inboxItems(forCamp:)` and for the opposite reason: a draw is struck from *one* venue's
    /// ladder, so the two venues of a camp have nothing to say to each other here. There is no
    /// screen that wants both, and a camp-wide read would have to be narrowed again by every
    /// caller.
    func tournaments(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [Tournament]

    /// Writes finished draws and answers with the venue's list.
    ///
    /// Plural because a band split makes several at once and they belong to one tap: three
    /// tournaments over three rank bands is one decision, and a loop over a singular method would
    /// let the second of them fail with the first already written and no way to say which half of
    /// the split the camp is now holding. Same argument `importPlayers` makes for a roster.
    ///
    /// The draws arrive already seeded. Nothing here inspects a bracket.
    func addTournaments(
        _ draws: [Tournament], toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [Tournament]

    /// Takes a draw off the list. Its entrants, their members, their coaches and its fixtures go
    /// with it — `on delete cascade` on the Postgres side, and the whole value on the offline one.
    func removeTournament(
        _ id: Tournament.ID, fromVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [Tournament]

    /// Records a result, or rubs one out with `nil`.
    ///
    /// **An equal score is refused**, by both implementations, before either sends anything. The
    /// column says so too — `tournament_matches_no_draw` — but a CHECK violation arrives as
    /// `23514: new row for relation "tournament_matches" violates check constraint`, which is not a
    /// sentence to put in front of a coach holding a scorecard. `TournamentError.drawnMatch` is,
    /// and refusing in both builds is what keeps the offline one from accepting a score the real
    /// one would bounce. The design's own score sheet returns early on equal numbers, so this is
    /// the rule the screen already states, restated where it can be enforced.
    ///
    /// `venueID` is asked for rather than derived from the tournament. The caller is looking at one
    /// venue's list and that list is what comes back; deriving it would be a round trip to learn
    /// something the caller already knows.
    func setScore(
        _ score: Tournament.Score?,
        forMatch matchID: Tournament.Match.ID,
        in tournamentID: Tournament.ID,
        atVenue venueID: Venue.ID,
        campID: Camp.ID
    ) async throws -> [Tournament]

    /// Team tennis only: who is running a team.
    ///
    /// A cover rather than a diff — the whole list replaces whatever was there — which is the same
    /// call `setBlockCoaches` makes a file away and for the same reason: the set is two or three
    /// rows, so a diff would spend a read to save writing them.
    func setTeamCoaches(
        _ coachIDs: [StaffMember.ID],
        forTeam teamID: Tournament.Team.ID,
        in tournamentID: Tournament.ID,
        atVenue venueID: Venue.ID,
        campID: Camp.ID
    ) async throws -> [Tournament]
}

// MARK: - Refusals

/// What can go wrong with a draw, in sentences.
///
/// Its own type rather than four more cases on `SycamoreError`, for the reason this file's header
/// gives: `Repository.swift` is not editable from here. It is a `LocalizedError`, which is the
/// whole of what `AppStore.perform` needs — the banner shows `error.localizedDescription` and does
/// not care which type produced it.
///
/// The two score rules are the two CHECKs on `tournament_matches`, restated on this side of the
/// wire. That is deliberate duplication: the column is the thing that cannot be got round, and this
/// is the thing that can be read.
enum TournamentError: LocalizedError, Equatable {
    case unknownTournament
    case unknownMatch
    case unknownTeam
    /// Both sides on the same number. `tournament_matches_no_draw`.
    case drawnMatch
    /// A negative game count. `tournament_matches_score_nonnegative`.
    case impossibleScore

    var errorDescription: String? {
        switch self {
        case .unknownTournament: "We couldn't find that draw."
        case .unknownMatch: "We couldn't find that match."
        case .unknownTeam: "We couldn't find that team."
        case .drawnMatch: "A match needs a winner. Give one side more games than the other."
        case .impossibleScore: "A score can't be negative."
        }
    }

    /// Throws if `score` is one the schema would bounce. `nil` — rubbing a result out — is fine.
    ///
    /// Static, and called by both implementations, so the offline build and Postgres refuse exactly
    /// the same set. A rule enforced in one build and not the other is a rule you only find out
    /// about on camp wifi.
    static func check(_ score: Tournament.Score?) throws {
        guard let score else { return }
        guard score.a >= 0, score.b >= 0 else { throw TournamentError.impossibleScore }
        guard score.a != score.b else { throw TournamentError.drawnMatch }
    }
}

// MARK: - In-memory implementation

extension InMemoryRepository: TournamentData {

    func tournaments(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [Tournament] {
        // No venue check, deliberately. The Postgres read is a filter on `site_id`, and a venue
        // that is not there matches no row rather than raising — an offline build that threw where
        // the real one returns nothing would be a difference only the offline build could show you.
        await OfflineDraws.shared.draws(of: self, at: venueID)
    }

    /// Checks the venue before writing, which the real one gets from `tournaments_site_id_fkey`.
    func addTournaments(
        _ draws: [Tournament], toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [Tournament] {
        try await requireVenue(venueID, campID: campID)
        return await OfflineDraws.shared.mutate(self, at: venueID) { list in
            list.append(contentsOf: draws)
        }
    }

    func removeTournament(
        _ id: Tournament.ID, fromVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [Tournament] {
        try await OfflineDraws.shared.mutate(self, at: venueID) { list in
            guard list.contains(where: { $0.id == id }) else {
                throw TournamentError.unknownTournament
            }
            list.removeAll { $0.id == id }
        }
    }

    /// The score, checked and then stored against the match id.
    ///
    /// The match has to exist, and that is not pedantry: `scores` is a dictionary keyed by a string
    /// the model mints, so a typo'd id would store a result nothing ever reads and the screen would
    /// show the match still unplayed. Postgres cannot make that mistake — there is a row or there
    /// is not — so the offline build has to check on purpose.
    func setScore(
        _ score: Tournament.Score?,
        forMatch matchID: Tournament.Match.ID,
        in tournamentID: Tournament.ID,
        atVenue venueID: Venue.ID,
        campID: Camp.ID
    ) async throws -> [Tournament] {
        try TournamentError.check(score)
        return try await OfflineDraws.shared.mutate(self, at: venueID) { list in
            guard let index = list.firstIndex(where: { $0.id == tournamentID }) else {
                throw TournamentError.unknownTournament
            }
            guard list[index].matches.contains(where: { $0.id == matchID }) else {
                throw TournamentError.unknownMatch
            }
            list[index].scores[matchID] = score
        }
    }

    func setTeamCoaches(
        _ coachIDs: [StaffMember.ID],
        forTeam teamID: Tournament.Team.ID,
        in tournamentID: Tournament.ID,
        atVenue venueID: Venue.ID,
        campID: Camp.ID
    ) async throws -> [Tournament] {
        try await OfflineDraws.shared.mutate(self, at: venueID) { list in
            guard let index = list.firstIndex(where: { $0.id == tournamentID }) else {
                throw TournamentError.unknownTournament
            }
            guard let team = list[index].teams.firstIndex(where: { $0.id == teamID }) else {
                throw TournamentError.unknownTeam
            }
            // Deduplicated in order, which is what `tournament_entrant_coaches`' composite primary
            // key does on the other side: the same coach named twice is a `23505` there and would
            // be a chip drawn twice here.
            var seen: Set<StaffMember.ID> = []
            list[index].teams[team].coachIDs = coachIDs.filter { seen.insert($0).inserted }
        }
    }

    /// File-private, and the one guard the offline build has to make by hand.
    private func requireVenue(_ venueID: Venue.ID, campID: Camp.ID) async throws {
        let camp = try await camp(id: campID)
        guard camp.venue(venueID) != nil else { throw SycamoreError.unknownVenue }
    }
}

// MARK: - Where the offline build's draws live

/// The draws `InMemoryRepository` holds, held beside it rather than on it.
///
/// **This exists because of a file boundary, not because of a design.** `InMemoryRepository`'s
/// stored properties are declared in `Repository.swift`, which this work is not allowed to edit
/// (see the file header), and a Swift extension cannot add one. Everything below is the price of
/// that, and it goes the moment `var tournamentDraws: [Venue.ID: [Tournament]] = [:]` can be
/// written beside `sectionEightBlocks`.
///
/// Two things it nonetheless has to get right:
///
/// **Keyed by the repository, weakly.** An `ObjectIdentifier` is an address, and an address is
/// reused the moment the object at it is freed — so a test that lets one repository go and makes
/// another could otherwise inherit the first one's tournaments, which is the kind of failure that
/// only shows up when the suite is run in a different order. The owner is held weakly beside the
/// draws and checked with `===` on every read, so a reused address is a miss rather than a wrong
/// answer, and dead slots are swept on every write.
///
/// **One hop, not two.** Every method here does its whole read-modify-write inside this actor, so
/// nothing suspends in the middle of one. `InMemoryRepository`'s own mutations are atomic because
/// they never suspend (`SupabaseRepository.serialised` exists to buy back exactly that property for
/// the build that does), and routing a write through a *second* actor would have given it a
/// suspension point it did not have — two concurrent creates could read the same list, append to
/// their own copy, and the second write would lose the first.
private actor OfflineDraws {

    static let shared = OfflineDraws()

    private struct Slot {
        weak var owner: InMemoryRepository?
        var byVenue: [Venue.ID: [Tournament]]
    }

    private var slots: [ObjectIdentifier: Slot] = [:]

    func draws(of repository: InMemoryRepository, at venueID: Venue.ID) -> [Tournament] {
        slot(of: repository)?.byVenue[venueID] ?? []
    }

    /// Edits one venue's list and hands it back, all without suspending. `rethrows`, so a refusal
    /// inside `edit` leaves the stored list exactly as it was — the same all-or-nothing promise
    /// `InMemoryRepository.mutate` makes for the camp graph.
    func mutate(
        _ repository: InMemoryRepository,
        at venueID: Venue.ID,
        _ edit: @Sendable (inout [Tournament]) throws -> Void
    ) rethrows -> [Tournament] {
        var list = slot(of: repository)?.byVenue[venueID] ?? []
        try edit(&list)

        // Swept here rather than on read: a read is the hot path and a dead slot costs it nothing.
        slots = slots.filter { $0.value.owner != nil }
        var current = slot(of: repository)?.byVenue ?? [:]
        current[venueID] = list
        slots[ObjectIdentifier(repository)] = Slot(owner: repository, byVenue: current)
        return list
    }

    /// The slot, but only if it is still *this* repository's — see the type's note on address reuse.
    private func slot(of repository: InMemoryRepository) -> Slot? {
        guard let slot = slots[ObjectIdentifier(repository)], slot.owner === repository else {
            return nil
        }
        return slot
    }
}
