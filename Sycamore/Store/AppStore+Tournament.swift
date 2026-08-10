//
//  AppStore+Tournament.swift
//  Sycamore
//
//  The store surface for the Tournament tab: load a venue's draws, strike a new one, score it.
//
//  Split from `AppStore.swift` for the reason `AppStore+SectionEight.swift` gives — that one is the
//  file every feature edits, and this is the Tournament tab's.
//
//  ── WHERE THE SEEDING HAPPENS, AND WHY IT IS HERE ────────────────────────────────────────────
//
//  `Tournament.seeded` takes a pool: kids, already narrowed to the courts the draw is over and
//  already in ladder order. Narrowing it needs the camp graph, and the camp graph is here — so this
//  file is where a tap becomes a pool becomes a draw, and `TournamentRepository` is handed a value
//  that is already finished. Nothing below re-derives a bracket and nothing in the repository does
//  either; see that file's header.
//
//  The two things this layer *does* decide are the two that are facts about a venue's list rather
//  than about any one draw: what a new draw is called, and — a layer down — where it sits.
//

import Foundation

extension AppStore {

    // MARK: - The seam

    /// The repository, seen through its tournament half.
    ///
    /// A conditional cast rather than an inheritance clause on `SycamoreRepository`, which is how
    /// `SectionEightData` is reached. That clause lives in `Repository.swift`, which this work is
    /// not allowed to edit — see `TournamentRepository.swift`'s header for the whole argument and
    /// for the two lines that retire this.
    ///
    /// Both shipped repositories conform, so nil is unreachable in the app and in every preview. It
    /// is a `guard` rather than a force-cast so that a third repository — a fake in somebody's
    /// test, say — degrades to a tab that loads nothing rather than to a crash.
    var tournamentData: (any TournamentData)? { repository as? any TournamentData }

    // MARK: - Reads

    /// The venue's draws, and the record of which venue they are.
    ///
    /// **Clears first when the venue has changed, and only then.** That is `selectVenue`'s rule
    /// (`AppStore+SectionEight.swift`) arrived at from the other side: on a reload of the *same*
    /// venue an empty list flashing between two identical answers is worse than a moment of
    /// slightly old rows, but on a switch the stale rows are another venue's draws drawn under this
    /// venue's name, and nothing on the card would say so. `loadedTournamentVenueID` goes to nil
    /// with them, because the two together are what tell "this venue has no draws" from "nobody has
    /// asked yet" — and a cleared list still claiming the old venue would answer that question
    /// wrongly for the length of a round trip.
    ///
    /// Both are written *after* the read returns, so a failure leaves the previous venue's answer
    /// intact rather than replacing it with an emptiness the reader would take for a fact.
    ///
    /// Owned by the screen's `.task(id:)`, like every other section-8 read. Nothing here pushes it.
    func loadTournaments(at venueID: Venue.ID) async {
        guard let campID = camp?.id, let draws = tournamentData else { return }
        if loadedTournamentVenueID != venueID {
            tournaments = []
            loadedTournamentVenueID = nil
        }
        // Read before the suspension so the guard below can tell "the venue moved under us" from
        // "this load was never for the venue on screen". Not `venueID == readVenueID`: that is the
        // normal case but not the contract — the tests load a named venue directly, and a load
        // that was never current has not been superseded by anything.
        let entryVenueID = readVenueID

        await perform {
            let loaded = try await draws.tournaments(forVenue: venueID, campID: campID)

            // The chips are live behind the load, and `.task(id: readVenueID)` is the sole owner
            // of reloading — it will not re-fire on an id it has already seen. So a superseded run
            // that published anyway would stamp the old venue's draws, and `loadedTournamentVenueID`
            // with them, over the venue now on screen; the tab would then sit blank until somebody
            // switched venue a second time.
            guard self.readVenueID == entryVenueID else { return }

            self.tournaments = loaded
            self.loadedTournamentVenueID = venueID
        }
    }

    /// The venue's ladder, best first — what a draw is struck from.
    ///
    /// `Tournament.ladder(_:across:)` over every player in the camp rather than over
    /// `camp.players(in:)`, and that is not laziness: the ladder's own rule is that a kid on no
    /// court, or on a court outside the ones given, is not in it — so the courts are the filter and
    /// passing a pre-narrowed roster would be filtering twice by two different rules.
    ///
    /// Keyed off `readVenueID` rather than `loadedTournamentVenueID`, because this is the pool a
    /// *new* draw would be struck from and a new draw is struck at the venue being read. The two
    /// differ only while a load is in flight.
    var tournamentLadder: [Player] {
        guard let camp, let venueID = readVenueID else { return [] }
        return Tournament.ladder(camp.players, across: camp.groups(in: venueID))
    }

    // MARK: - Striking a draw

    /// One draw over the chosen courts.
    ///
    /// `name: nil` — or a name that is only whitespace — auto-numbers off the venue's list:
    /// "Tournament 1", "Tournament 2". The number counts the draws already there, which is why it
    /// is decided here and not in `Tournament`: it is a fact about the list, and the model has
    /// never been shown one.
    ///
    /// **An empty pool makes an empty draw rather than nothing at all.** That is `Tournament
    /// .seeded`'s documented behaviour and it is followed rather than second-guessed: the design's
    /// prototype bails on the tap, but a draw over courts that turn out to be empty is a thing the
    /// person who asked for it can see and delete, where a button that quietly did nothing is a
    /// thing they tap again. `createBandedTournaments` below is where the refusal does belong, and
    /// `Tournament.banded` makes it for us by dropping empty bands.
    func createTournament(
        _ seeding: Tournament.Seeding,
        name: String?,
        courtIndices: [Int],
        days: Int,
        at venueID: Venue.ID
    ) async {
        await addDraws(at: venueID, courtIndices: courtIndices) { existing, pool in
            [
                Tournament.seeded(
                    seeding,
                    name: Self.drawName(name, after: existing.count),
                    pool: pool,
                    courtIndices: courtIndices,
                    days: Self.storableDays(days)
                )
            ]
        }
    }

    /// `count` draws over contiguous rank bands of the chosen courts' pool — "make me three
    /// tournaments, strongest kids together".
    ///
    /// **Renamed after banding, so the venue keeps one numbering.** `Tournament.banded` numbers its
    /// own results 1…N, which is right for a function that has never seen a venue's list and wrong
    /// for a venue that already has two draws on it — three more called "Tournament 1", "Tournament
    /// 2", "Tournament 3" would put two of each name on one screen. The names are overwritten here,
    /// continuing the count, by exactly the rule `createTournament` uses.
    ///
    /// Fewer draws than asked for is a legitimate answer and is passed straight through: eight kids
    /// into five bands is five bands with two of them empty, and `banded` returns the three that
    /// have somebody in them. See its own note.
    func createBandedTournaments(
        _ seeding: Tournament.Seeding,
        into count: Int,
        courtIndices: [Int],
        days: Int,
        at venueID: Venue.ID
    ) async {
        await addDraws(at: venueID, courtIndices: courtIndices) { existing, pool in
            var made = Tournament.banded(
                seeding,
                ladder: pool,
                into: count,
                courtIndices: courtIndices,
                days: Self.storableDays(days)
            )
            for index in made.indices {
                made[index].name = Self.drawName(nil, after: existing.count + index)
            }
            return made
        }
    }

    /// Both creates, which differ only in what they build.
    ///
    /// One `perform` for the whole thing, including the count the name is derived from. The list is
    /// almost always already in hand — the tab loads before it can offer a create button — and the
    /// read below is the case where it is not: a create fired at a venue whose draws this store has
    /// never loaded would otherwise number from zero and put a second "Tournament 1" on the screen.
    /// Names are not unique in the schema, so nothing would refuse it; it would just be wrong.
    private func addDraws(
        at venueID: Venue.ID,
        courtIndices: [Int],
        _ build: ([Tournament], [Player]) -> [Tournament]
    ) async {
        guard let camp, let draws = tournamentData else { return }
        await perform {
            let existing = self.loadedTournamentVenueID == venueID
                ? self.tournaments
                : try await draws.tournaments(forVenue: venueID, campID: camp.id)
            let pool = Tournament.pool(
                camp.players, across: camp.groups(in: venueID), courtIndices: courtIndices
            )
            self.tournaments = try await draws.addTournaments(
                build(existing, pool), toVenue: venueID, campID: camp.id
            )
            self.loadedTournamentVenueID = venueID
        }
    }

    // MARK: - Writes against a draw already on the list

    /// Takes a draw off the venue's list. Everything hanging off it goes too.
    func removeTournament(_ id: Tournament.ID) async {
        await write { draws, venueID, campID in
            try await draws.removeTournament(id, fromVenue: venueID, campID: campID)
        }
    }

    /// Records a result, or clears one with `nil`.
    ///
    /// A draw is refused before anything is sent — see `TournamentData.setScore` — and arrives back
    /// here as an ordinary banner, because `perform` shows `errorDescription` and
    /// `TournamentError.drawnMatch` has one written for exactly this.
    func setScore(
        _ score: Tournament.Score?,
        forMatch matchID: Tournament.Match.ID,
        in tournamentID: Tournament.ID
    ) async {
        await write { draws, venueID, campID in
            try await draws.setScore(
                score, forMatch: matchID, in: tournamentID, atVenue: venueID, campID: campID
            )
        }
    }

    /// Who is running a team. Team tennis only; the list replaces whatever was there.
    ///
    /// The ids are `StaffMember.ID`s and stay that way. What gets *drawn* is the name, read off
    /// `camp.staff` at the moment of drawing, which is what every other coach chip in this app
    /// already does — see `Tournament.Team`, which argues at length why storing the name would mean
    /// a coach who corrected the spelling of their own name silently left every team they ran.
    func setTeamCoaches(
        _ coachIDs: [StaffMember.ID],
        forTeam teamID: Tournament.Team.ID,
        in tournamentID: Tournament.ID
    ) async {
        await write { draws, venueID, campID in
            try await draws.setTeamCoaches(
                coachIDs, forTeam: teamID, in: tournamentID, atVenue: venueID, campID: campID
            )
        }
    }

    /// The three writes above, which share a guard worth stating once.
    ///
    /// They act on a draw the reader is looking at, and what the reader is looking at is
    /// `tournaments` — which belongs to `loadedTournamentVenueID`, not to `readVenueID`. The two
    /// part company for the length of a load, and using the wrong one would send a score for a draw
    /// on one venue's list and answer with another venue's.
    ///
    /// Nothing loaded means there is no draw on screen to act on, so these do nothing rather than
    /// falling back to `readVenueID` and issuing a write that could only fail.
    private func write(
        _ mutate: (any TournamentData, Venue.ID, Camp.ID) async throws -> [Tournament]
    ) async {
        guard let campID = camp?.id,
              let venueID = loadedTournamentVenueID,
              let draws = tournamentData
        else { return }
        await perform {
            let written = try await mutate(draws, venueID, campID)

            // `venueID` was read before the suspension. If the reader switched venue during the
            // round trip, this result belongs to the venue they left, and publishing it would draw
            // one venue's draws under another's name with no reload path to correct it.
            guard self.loadedTournamentVenueID == venueID else { return }

            self.tournaments = written
        }
    }

    // MARK: - What the columns will take

    /// "Tournament 3", or the name somebody typed, trimmed and cut to what the column holds.
    ///
    /// `tournaments_name_len` is `char_length(name) between 1 and 80`, so an empty name and an
    /// eighty-first character are both rejected by Postgres. Both are handled here instead: a blank
    /// name is what the auto-number is *for*, and a long one is a reader who pasted something,
    /// which is not worth a red banner.
    private static func drawName(_ given: String?, after existingCount: Int) -> String {
        let typed = given?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String((typed.isEmpty ? "Tournament \(existingCount + 1)" : typed).prefix(80))
    }

    /// `tournaments_days_range` is 1…14. `Tournament.seeded` already floors at 1 and has no ceiling,
    /// because a ceiling is a fact about the column rather than about a draw — so it is applied
    /// here, on the way in, and the value the model holds is the value that gets stored.
    private static func storableDays(_ days: Int) -> Int { min(14, max(1, days)) }
}
