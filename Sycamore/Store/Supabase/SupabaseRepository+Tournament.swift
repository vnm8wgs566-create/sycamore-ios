//
//  SupabaseRepository+Tournament.swift
//  Sycamore
//
//  `TournamentData` against Postgres: five tables, and one genuinely awkward join.
//
//  ── THE IDS DO NOT LINE UP, AND THAT IS THE WHOLE OF THIS FILE ────────────────────────────────
//
//  `Tournament.Entrant.id` and `Tournament.Match.id` are short derived strings — `"e0p"`, `"m3"` —
//  minted by the seeding and not stored anywhere, because `Tournament.swift`'s header wants two
//  seedings of one pool to be `==`. The tables use uuid primary keys, because a match is a row and
//  `a_from_match` is a real self-referencing foreign key. Neither side is going to change: uuids on
//  the model would break its `Hashable`, and string keys in the schema would break the FK.
//
//  So they are mapped **deterministically, off the two UNIQUE keys the migration put there for it**:
//
//    - an entrant ↔ its row by `(tournament_id, seed)`, `seed` being the entrant's offset in
//      `Tournament.entrants` plus one — dense and 1-based, and *not* `Entrant.ladderIndex`, which
//      is a fractional strength and would truncate into collisions. See `entrantID(kind:seed:_:)`.
//    - a match ↔ its row by `(tournament_id, round, sort_index)`. `Tournament` mints `m1, m2, …` in
//      round order and then position order, in both the round-robin and the knockout builder, so
//      the row sorted `n`th by `(round, sort_index)` is `"m\(n + 1)"`. See `matchIDs(for:)`.
//
//  Writing does not need either mapping: the uuids are minted here, before anything is sent, so
//  every child row already knows what it points at. That is the same trick `scheduleRow` plays with
//  `schedule_blocks.id`. Reading is where the mapping earns its keep.
//
//  ── ONE THING DOES NOT SURVIVE THE ROUND TRIP ────────────────────────────────────────────────
//
//  `Entrant.ladderIndex` is a fractional mean of two ladder positions — a pair of the 1st and 2nd
//  kids sits at 1.5 — and there is no column for it. It comes back as the dense position instead,
//  which is exact for singles and lossy for doubles. Nothing downstream reads it: the entrants come
//  back in the order it produced, and the bracket, the standings and every card count offsets.
//
//  ── WHAT IS NOT HERE ─────────────────────────────────────────────────────────────────────────
//
//  No `adminWrite`. Every policy on these five tables is `site_id in site_ids_for_caller()` —
//  membership, not admin — which the migration states outright: "a coach with a court needs to open
//  a draw and put a score on it". Wrapping these would rename an ordinary refusal to "Only an admin
//  can do that.", which is the confident lie `logActivity` a file away declines to tell.
//

import Foundation

extension SupabaseRepository: TournamentData {

    // MARK: - Read

    /// A venue's draws, in two round trips.
    ///
    /// Wave one is the draws themselves and the venue's courts — the courts because
    /// `tournaments.group_ids` holds court *ids* and `Tournament.courtIndices` holds *positions*,
    /// and only the venue's court order can convert between them.
    ///
    /// Wave two is everything hanging off the draws, filtered by the ids wave one returned. The two
    /// grandchild tables reach a tournament through an embedded inner join — `tournament_entrants
    /// !inner(tournament_id)` with the filter on the embedded column, which is the shape
    /// `SupabaseRepository+Graph` already uses to reach a site through `players` — rather than
    /// through an `in.(…)` over entrant ids. That is not only tidiness: ten forty-kid draws is four
    /// hundred entrants, and four hundred quoted uuids is a fifteen-kilobyte query string, which is
    /// past what a proxy in front of PostgREST will accept on one request line.
    ///
    /// Ordering is done here rather than on the wire. PostgREST spells a two-key sort as one query
    /// item (`order=round.asc,sort_index.asc`) and this client's `order` builder appends one item
    /// per call, so two calls would be two `order` params and only one of them would count. Matches
    /// are sorted on two keys and their order *is* their identity, so it is not something to leave
    /// to a spelling that half-works.
    func tournaments(forVenue venueID: Venue.ID, campID: Camp.ID) async throws -> [Tournament] {
        async let drawsTask: [TournamentRecord] = db.select(
            Relation.tournaments, .select("*").eq("site_id", venueID)
        )
        // The same read `courts(forVenue:campID:)` makes, for the same reason it makes it: this is
        // the venue's court order, and `rank_order` is what defines it.
        async let courtsTask: [GroupRecord] = db.select(
            Relation.groups, .select("*").eq("site_id", venueID).order("rank_order")
        )
        let (drawRecords, courtRecords) = try await (drawsTask, courtsTask)
        guard !drawRecords.isEmpty else { return [] }

        let drawIDs = drawRecords.map(\.id)

        async let entrantsTask: [TournamentEntrantRecord] = db.select(
            Relation.tournamentEntrants, .select("*").within("tournament_id", drawIDs)
        )
        async let membersTask: [TournamentEntrantPlayerRecord] = db.select(
            Relation.tournamentEntrantPlayers,
            .select("entrant_id,player_id,slot,tournament_entrants!inner(tournament_id)")
                .within("tournament_entrants.tournament_id", drawIDs)
        )
        async let coachesTask: [TournamentEntrantCoachRecord] = db.select(
            Relation.tournamentEntrantCoaches,
            .select("entrant_id,coach_id,tournament_entrants!inner(tournament_id)")
                .within("tournament_entrants.tournament_id", drawIDs)
        )
        async let matchesTask: [TournamentMatchRecord] = db.select(
            Relation.tournamentMatches, .select("*").within("tournament_id", drawIDs)
        )
        let (entrantRecords, memberRecords, coachRecords, matchRecords) =
            try await (entrantsTask, membersTask, coachesTask, matchesTask)

        let courts = Self.courts(courtRecords)
        let entrantsByDraw = Dictionary(grouping: entrantRecords, by: \.tournamentId)
        let matchesByDraw = Dictionary(grouping: matchRecords, by: \.tournamentId)
        // Members carry `slot`; the sort is applied per entrant at the fan-in, where the array is
        // small and already in hand.
        let membersByEntrant = Dictionary(grouping: memberRecords, by: \.entrantId)
        let coachesByEntrant = Dictionary(grouping: coachRecords, by: \.entrantId)

        return drawRecords
            .sorted {
                $0.sortIndex == $1.sortIndex
                    ? $0.createdAt < $1.createdAt
                    : $0.sortIndex < $1.sortIndex
            }
            .map { record in
                Self.tournament(
                    record,
                    courts: courts,
                    entrants: entrantsByDraw[record.id] ?? [],
                    matches: matchesByDraw[record.id] ?? [],
                    membersByEntrant: membersByEntrant,
                    coachesByEntrant: coachesByEntrant
                )
            }
    }

    // MARK: - Write

    /// Writes each draw whole, then re-reads the venue.
    ///
    /// `sort_index` is settled before the loop, off the highest one already at the venue, so a band
    /// split lands as a contiguous run at the end of the list in the order it was struck. It is
    /// counted here rather than passed in because it is a fact about the venue's rows, and this is
    /// the only build that has any.
    ///
    /// Draw by draw rather than one insert per table across all of them. A band split is two or
    /// three draws, the saving would be a handful of round trips, and the cost would be that a
    /// failure part-way leaves entrants belonging to a tournament row that was never written —
    /// which is a state nothing can show anybody. Per draw, a failure leaves whole draws behind and
    /// one partial one, and the partial one is visible on the list and removable.
    func addTournaments(
        _ draws: [Tournament], toVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [Tournament] {
        guard !draws.isEmpty else {
            return try await tournaments(forVenue: venueID, campID: campID)
        }

        async let courtsTask: [GroupRecord] = db.select(
            Relation.groups, .select("*").eq("site_id", venueID).order("rank_order")
        )
        async let tailTask: [TournamentRecord] = db.select(
            Relation.tournaments,
            .select("*").eq("site_id", venueID).order("sort_index", ascending: false).limit(1)
        )
        let (courtRecords, tail) = try await (courtsTask, tailTask)

        let courts = Self.courts(courtRecords)
        var sortIndex = (tail.first?.sortIndex ?? -1) + 1
        for draw in draws {
            try await insert(draw, atVenue: venueID, sortIndex: sortIndex, courts: courts)
            sortIndex += 1
        }
        return try await tournaments(forVenue: venueID, campID: campID)
    }

    /// One draw, as five inserts.
    ///
    /// The order is forced rather than chosen, and by **two** independent rules that happen to want
    /// the same thing. Both are worth stating, because satisfying one is not satisfying the other.
    ///
    /// **Foreign keys.** The tournament row comes first because everything references it; the
    /// entrants next because the members, the coaches and the fixtures all reference *them*; and the
    /// fixtures round by round, ascending, because `a_from_match` and `b_from_match` are
    /// self-referencing — a semi-final naming its two quarter-finals cannot be inserted until those
    /// rows exist. `Tournament.knockoutMatches` only ever points a round at the round directly
    /// before it, so ascending is sufficient; a round robin points at no match at all.
    ///
    /// **Row level security, which is the one that would have been found the hard way.** These are
    /// separate statements, and they have to be. `tournament_entrants_member` checks
    /// `tournament_id in (select private.tournament_ids_for_caller())`, and that helper is `STABLE`
    /// — so within a *single* statement it sees the snapshot as of statement start, and a
    /// tournament being created in the same statement does not exist for it yet. The tidy-looking
    /// `with t as (insert into tournaments … returning id), e as (insert into tournament_entrants
    /// select id … from t)` is answered `42501: new row violates row-level security policy`, and it
    /// is the policy being right rather than a bug to work around. `private
    /// .tournament_entrant_ids_for_caller` is `STABLE` too, so the same trap sits between the
    /// entrants and *their* members and coaches — which is to say at every level here, not just the
    /// first. Separate requests, parents before children, is the shape PostgREST gives us anyway.
    ///
    /// Verified live against the project as a real member, all four levels, inside a transaction
    /// that was rolled back.
    private func insert(
        _ draw: Tournament, atVenue venueID: Venue.ID, sortIndex: Int, courts: [Group]
    ) async throws {
        try await db.insert(
            Relation.tournaments,
            [Self.tournamentRow(draw, venueID: venueID, sortIndex: sortIndex, courts: courts)]
        )

        let entrants = Self.entrantDrafts(draw)
        try await db.insert(Relation.tournamentEntrants, entrants.map { $0.row(in: draw.id) })
        try await db.insert(Relation.tournamentEntrantPlayers, entrants.flatMap(\.memberRows))
        try await db.insert(Relation.tournamentEntrantCoaches, entrants.flatMap(\.coachRows))

        guard !draw.matches.isEmpty else { return }
        let entrantIDs = Dictionary(
            entrants.compactMap { draft in draft.modelID.map { ($0, draft.rowID) } },
            uniquingKeysWith: { first, _ in first }
        )
        let matchIDs = Dictionary(
            draw.matches.map { ($0.id, UUID()) }, uniquingKeysWith: { first, _ in first }
        )
        let byRound = Dictionary(grouping: draw.matches, by: \.round)
        for round in byRound.keys.sorted() {
            let rows = (byRound[round] ?? []).enumerated().map { offset, match in
                Self.matchRow(
                    match,
                    in: draw.id,
                    rowID: matchIDs[match.id] ?? UUID(),
                    sortIndex: offset,
                    entrantIDs: entrantIDs,
                    matchIDs: matchIDs
                )
            }
            try await db.insert(Relation.tournamentMatches, rows)
        }
    }

    /// One DELETE. The four child tables all cascade off `tournaments.id`, so the entrants, their
    /// members, their coaches and every fixture go in the same statement.
    ///
    /// Nothing back means the row was not there. On these tables that really is what it means — the
    /// same policy predicate governs select and delete, so a draw you can read is a draw you can
    /// remove, and there is no `using`-clause refusal hiding behind the empty answer the way
    /// `missingOrRefused` has to allow for on `groups` and `inbox_items`.
    func removeTournament(
        _ id: Tournament.ID, fromVenue venueID: Venue.ID, campID: Camp.ID
    ) async throws -> [Tournament] {
        let deleted: [RowIDRecord] = try await db.delete(
            Relation.tournaments, where: PostgRESTQuery().eq("id", id), returning: RowIDRecord.self
        )
        guard !deleted.isEmpty else { throw TournamentError.unknownTournament }
        return try await tournaments(forVenue: venueID, campID: campID)
    }

    /// A result against one fixture, or `nil` to rub one out.
    ///
    /// Checked before anything is sent — see `TournamentError.check` — so the two rules the columns
    /// state arrive as sentences rather than as `23514 … violates check constraint
    /// "tournament_matches_no_draw"`.
    ///
    /// The match's row has to be found first, because `matchID` is `"m7"` and the row is a uuid.
    /// That is one read of this tournament's fixtures, sorted the way the ids were minted; see the
    /// file header. Cheaper would be to carry the uuid on the model, and the model is deliberately
    /// not carrying it.
    func setScore(
        _ score: Tournament.Score?,
        forMatch matchID: Tournament.Match.ID,
        in tournamentID: Tournament.ID,
        atVenue venueID: Venue.ID,
        campID: Camp.ID
    ) async throws -> [Tournament] {
        try TournamentError.check(score)

        let records: [TournamentMatchRecord] = try await db.select(
            Relation.tournamentMatches, .select("*").eq("tournament_id", tournamentID)
        )
        guard let rowID = Self.matchIDs(for: records)[matchID] else {
            throw TournamentError.unknownMatch
        }
        let updated: [TournamentMatchRecord] = try await db.update(
            Relation.tournamentMatches,
            // Both columns every time, which `tournament_matches_score_paired` requires: half a
            // score is a write that got interrupted, and clearing one of the two would be exactly
            // that.
            set: ["a_score": .int(score?.a), "b_score": .int(score?.b)],
            where: PostgRESTQuery().eq("id", rowID),
            returning: TournamentMatchRecord.self
        )
        guard !updated.isEmpty else { throw TournamentError.unknownMatch }
        return try await tournaments(forVenue: venueID, campID: campID)
    }

    /// The team's coaches, covered rather than diffed — clear what is there, insert what is there
    /// now. `setBlockCoaches` makes the same call for the same reason: the set is a handful of rows,
    /// so a diff would spend a read to save writing two of them.
    ///
    /// A team is an entrant row, and `Team.id` is its draft position — so the row is the one at
    /// `seed = teamID + 1`, which `UNIQUE (tournament_id, seed)` makes exactly one row.
    func setTeamCoaches(
        _ coachIDs: [StaffMember.ID],
        forTeam teamID: Tournament.Team.ID,
        in tournamentID: Tournament.ID,
        atVenue venueID: Venue.ID,
        campID: Camp.ID
    ) async throws -> [Tournament] {
        let entrants: [TournamentEntrantRecord] = try await db.select(
            Relation.tournamentEntrants,
            .select("*").eq("tournament_id", tournamentID).eq("seed", teamID + 1).limit(1)
        )
        guard let entrant = entrants.first else { throw TournamentError.unknownTeam }

        try await db.delete(
            Relation.tournamentEntrantCoaches,
            where: PostgRESTQuery().eq("entrant_id", entrant.id)
        )
        // Deduplicated in order: `(entrant_id, coach_id)` is the primary key, so a coach named twice
        // is a `23505` rather than a harmless no-op.
        var seen: Set<StaffMember.ID> = []
        try await db.insert(
            Relation.tournamentEntrantCoaches,
            coachIDs
                .filter { seen.insert($0).inserted }
                .map { ["entrant_id": .uuid(entrant.id), "coach_id": .uuid($0)] }
        )
        return try await tournaments(forVenue: venueID, campID: campID)
    }

    // MARK: - Rows out

    private static func tournamentRow(
        _ draw: Tournament, venueID: Venue.ID, sortIndex: Int, courts: [Group]
    ) -> RowValues {
        [
            "id": .uuid(draw.id),
            "site_id": .uuid(venueID),
            "name": .text(draw.name),
            "kind": .text(TournamentText.text(draw.kind)),
            "mode": .text(TournamentText.text(draw.mode)),
            "group_ids": .text(
                Self.arrayLiteral(Tournament.courtIDs(of: draw.courtIndices, in: courts))
            ),
            "days": .int(draw.days),
            "sort_index": .int(sortIndex),
        ]
    }

    private static func matchRow(
        _ match: Tournament.Match,
        in tournamentID: Tournament.ID,
        rowID: UUID,
        sortIndex: Int,
        entrantIDs: [String: UUID],
        matchIDs: [String: UUID]
    ) -> RowValues {
        var columns: [String: PostgresValue] = [
            "id": .uuid(rowID),
            "tournament_id": .uuid(tournamentID),
            "round": .int(match.round),
            "sort_index": .int(sortIndex),
        ]
        for (column, value) in Self.side(match.a, "a", entrantIDs, matchIDs) {
            columns[column] = value
        }
        for (column, value) in Self.side(match.b, "b", entrantIDs, matchIDs) {
            columns[column] = value
        }
        return RowValues(columns)
    }

    /// One half of a fixture, as its two columns — and always both of them, because
    /// `tournament_matches_a_one_source` says a side is one thing or the other and an unwritten
    /// column on an UPDATE would leave the other kind of source standing.
    ///
    /// A lookup that misses writes NULL rather than failing the insert. That would mean a bracket
    /// naming an entrant no entrant carries, which is a defect on this side of the wire; drawn as a
    /// bye it is visible, where a refused insert would take the whole draw down with it.
    private static func side(
        _ side: Tournament.Side?,
        _ prefix: String,
        _ entrantIDs: [String: UUID],
        _ matchIDs: [String: UUID]
    ) -> [String: PostgresValue] {
        switch side {
        case .entrant(let id):
            ["\(prefix)_entrant_id": .uuid(entrantIDs[id]), "\(prefix)_from_match": .null]
        case .winner(let matchID):
            ["\(prefix)_entrant_id": .null, "\(prefix)_from_match": .uuid(matchIDs[matchID])]
        case nil:
            ["\(prefix)_entrant_id": .null, "\(prefix)_from_match": .null]
        }
    }

    /// An entrant on its way down: the row, its members and its coaches, keyed by a uuid minted
    /// here so the fixtures know what to point at.
    ///
    /// One type for entrants *and* teams, which is what the schema says they are — the migration's
    /// header puts it as "the entrant is the unit, not the player", and it is why a match table can
    /// be format-blind. `modelID` is the only asymmetry: a team has no `Entrant.id` because no
    /// fixture ever names one, so it is nil and nothing looks for it.
    private struct EntrantDraft {
        let rowID = UUID()
        var modelID: String?
        var seed: Int
        var name: String?
        var isRequested: Bool
        var playerIDs: [Player.ID]
        var coachIDs: [StaffMember.ID]

        func row(in tournamentID: Tournament.ID) -> RowValues {
            [
                "id": .uuid(rowID),
                "tournament_id": .uuid(tournamentID),
                "seed": .int(seed),
                "name": .text(name),
                "is_requested": .bool(isRequested),
            ]
        }

        /// `slot` is the position *after* deduplication, so it stays dense — `UNIQUE (entrant_id,
        /// slot)` would otherwise be fine but the gap would misreport draft order for a team.
        var memberRows: [RowValues] {
            playerIDs.enumerated().map { slot, playerID in
                ["entrant_id": .uuid(rowID), "player_id": .uuid(playerID), "slot": .int(slot)]
            }
        }

        var coachRows: [RowValues] {
            coachIDs.map { ["entrant_id": .uuid(rowID), "coach_id": .uuid($0)] }
        }
    }

    /// A draw's competitors, whichever of the two shapes it keeps them in.
    ///
    /// Both lists are deduplicated on the way past because both target tables key on the pair:
    /// `(entrant_id, player_id)` and `(entrant_id, coach_id)` are primary keys, so a kid named twice
    /// inside one entrant is a `23505` that would take the whole draw down. `Tournament
    /// .doublesEntrants` can produce one from a `PairRequest` naming the same kid twice, which it
    /// documents as a precondition on its caller rather than something it prevents.
    private static func entrantDrafts(_ draw: Tournament) -> [EntrantDraft] {
        if draw.kind == .team {
            return draw.teams.map { team in
                EntrantDraft(
                    modelID: nil,
                    // `Team.id` is the draft position, 0-based; the column is 1-based and dense.
                    seed: team.id + 1,
                    name: team.name,
                    isRequested: false,
                    playerIDs: unique(team.playerIDs),
                    coachIDs: unique(team.coachIDs)
                )
            }
        }
        return draw.entrants.enumerated().map { offset, entrant in
            EntrantDraft(
                modelID: entrant.id,
                // The offset plus one, and emphatically **not** `entrant.ladderIndex` — see the
                // file header, and the model's own note on why that property was renamed.
                seed: offset + 1,
                // Null for singles and doubles: the label is built from the members' names, and
                // storing it would be a second place for a kid's name to be wrong.
                name: nil,
                isRequested: entrant.isRequested,
                playerIDs: unique(entrant.playerIDs),
                coachIDs: []
            )
        }
    }

    private static func unique<ID: Hashable>(_ ids: [ID]) -> [ID] {
        var seen: Set<ID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    /// `{a,b}` — Postgres's own array input syntax, sent as a JSON string.
    ///
    /// `PostgresValue` has no array case, and `RowValues.swift` is not a file this work may edit.
    /// It does not need one: PostgREST hands the body to `json_populate_recordset`, which, for a
    /// JSON *string* against an array column, runs the type's input function over it — so
    /// `"{a,b}"` arrives as `uuid[]`. Confirmed against the project before this was written, along
    /// with `"{}"` for the empty case, which is also the column's DEFAULT.
    ///
    /// No quoting or escaping, and none is needed: a uuid's text form is thirty-two hex digits and
    /// four hyphens, none of which are the comma, brace, quote or backslash the array grammar reads.
    private static func arrayLiteral(_ ids: [UUID]) -> String {
        "{\(ids.map(\.uuidString).joined(separator: ","))}"
    }

    // MARK: - Rows in

    private static func tournament(
        _ record: TournamentRecord,
        courts: [Group],
        entrants: [TournamentEntrantRecord],
        matches: [TournamentMatchRecord],
        membersByEntrant: [UUID: [TournamentEntrantPlayerRecord]],
        coachesByEntrant: [UUID: [TournamentEntrantCoachRecord]]
    ) -> Tournament {
        let kind = TournamentText.kind(record.kind)
        let ordered = entrants.sorted { $0.seed < $1.seed }
        let members = { (row: TournamentEntrantRecord) -> [Player.ID] in
            (membersByEntrant[row.id] ?? []).sorted { $0.slot < $1.slot }.map(\.playerId)
        }

        var draw = Tournament(
            id: record.id,
            name: record.name,
            kind: kind,
            mode: TournamentText.mode(record.mode, kind: kind),
            courtIndices: Tournament.courtIndices(of: record.groupIds, in: courts),
            days: record.days
        )

        if kind == .team {
            draw.teams = ordered.map { row in
                Tournament.Team(
                    id: row.seed - 1,
                    // A row with no name is not something this app writes, but the column is
                    // nullable and the model's is not — and "Team 3" is exactly what the draft
                    // would have called it.
                    name: row.name ?? "Team \(row.seed)",
                    coachIDs: (coachesByEntrant[row.id] ?? []).map(\.coachId),
                    playerIDs: members(row)
                )
            }
            // A team draw has no fixtures. `tournament_matches` will have none either, but reading
            // `entrants` and `matches` back as empty is what says so in the model.
            return draw
        }

        var idByRow: [UUID: String] = [:]
        draw.entrants = ordered.map { row in
            let playerIDs = members(row)
            let id = entrantID(kind: kind, seed: row.seed, playerIDs)
            idByRow[row.id] = id
            return Tournament.Entrant(
                id: id,
                playerIDs: playerIDs,
                isRequested: row.isRequested,
                // The dense position, because the fractional mean has no column. Exact for singles;
                // see the file header for what is lost in doubles and why nothing reads it.
                ladderIndex: Double(row.seed - 1)
            )
        }

        let sorted = matches.sorted {
            $0.round == $1.round ? $0.sortIndex < $1.sortIndex : $0.round < $1.round
        }
        let idByMatchRow = matchIDs(for: sorted).reduce(into: [UUID: String]()) { out, pair in
            out[pair.value] = pair.key
        }
        draw.matches = sorted.map { row in
            Tournament.Match(
                id: idByMatchRow[row.id] ?? "m?",
                round: row.round,
                a: side(row.aEntrantId, row.aFromMatch, idByRow, idByMatchRow),
                b: side(row.bEntrantId, row.bFromMatch, idByRow, idByMatchRow)
            )
        }
        // Keyed through the same lookup the fixtures were, rather than off the offset again. The
        // two would agree — the offset *is* how `matchIDs(for:)` numbers them — and that is exactly
        // the kind of agreement that stops holding when one of the two is edited.
        for row in sorted {
            guard let a = row.aScore, let b = row.bScore, let id = idByMatchRow[row.id] else {
                continue
            }
            draw.scores[id] = Tournament.Score(a, b)
        }
        return draw
    }

    private static func side(
        _ entrantID: UUID?,
        _ fromMatch: UUID?,
        _ idByRow: [UUID: String],
        _ idByMatchRow: [UUID: String]
    ) -> Tournament.Side? {
        if let entrantID, let id = idByRow[entrantID] { return .entrant(id) }
        if let fromMatch, let id = idByMatchRow[fromMatch] { return .winner(of: id) }
        // Both null is a bye, which is a side that is genuinely nobody. So is a reference to a row
        // this read did not get — an entrant whose kids all left the camp, say — and drawing it as
        // a bye is the honest answer rather than pointing at an entrant that is not in the list.
        return nil
    }

    /// `Tournament.Match.id` for each row, keyed the other way round.
    ///
    /// The whole mapping in one line, and the line is the file header's second bullet: both match
    /// builders mint `m1, m2, …` walking rounds in order and positions inside them in order, so the
    /// row that sorts `n`th by `(round, sort_index)` is `"m\(n + 1)"`. Sorting here rather than
    /// trusting the caller, because `setScore` hands over an unsorted read.
    private static func matchIDs(for records: [TournamentMatchRecord]) -> [String: UUID] {
        let sorted = records.sorted {
            $0.round == $1.round ? $0.sortIndex < $1.sortIndex : $0.round < $1.round
        }
        return Dictionary(
            sorted.enumerated().map { ("m\($0.offset + 1)", $0.element.id) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// `Tournament.Entrant.id`, regenerated from what the row carries.
    ///
    /// Two spellings because the model has two: `singlesEntrants` mints `"e<player uuid>"` and
    /// `doublesEntrants` mints `"e<offset>p"`. It matters only that this function is the *single*
    /// source of both the entrant list's ids and the ids the match sides resolve to — which it is,
    /// through `idByRow` — so the two cannot disagree even if a spelling here were wrong.
    ///
    /// A singles entrant whose kid has left the camp has no member row left (the membership cascades
    /// off `players`) and falls back to the doubles spelling. It is still unique within the draw,
    /// which is all the bracket asks of it.
    private static func entrantID(
        kind: Tournament.Kind, seed: Int, _ playerIDs: [Player.ID]
    ) -> String {
        if kind == .singles, let playerID = playerIDs.first { return "e\(playerID.uuidString)" }
        return "e\(seed - 1)p"
    }

    /// The venue's courts in rank order.
    ///
    /// Built as `Group`s only so `Tournament.courtIDs(of:in:)` and `Tournament.courtIndices(of:in:)`
    /// can be called rather than written out a second time here — the model put them there for a
    /// persistence layer, and two spellings of one conversion is how the two start disagreeing.
    /// Only the ids and the array order are read; `number` and `capacity` are not facts this read
    /// has, and nothing sees these values.
    private static func courts(_ records: [GroupRecord]) -> [Group] {
        records.enumerated().map { Group($0.element, number: $0.offset + 1, capacity: 0) }
    }
}

// MARK: - The two constrained text columns

/// `tournaments.kind` and `tournaments.mode`, both ways.
///
/// `kind` is `Tournament.Kind.rawValue` unchanged. `mode` is not: the model spells `roundRobin` and
/// the column spells `round_robin`, and — the part worth being careful about — the column has a
/// third value, `'none'`, for the team draws whose `Tournament.mode` is nil.
/// `tournaments_team_has_no_mode` ties the two together as an equivalence, so this restates it in
/// both directions rather than translating leniently: a team row cannot carry a mode and a
/// non-team row cannot carry `'none'`.
///
/// An unknown `kind` falls back rather than throwing, which is the rule `PostgresEnum` states for
/// every CHECK-constrained text column in this schema: a database that has grown a case this build
/// predates should draw the draw plainly rather than refuse to draw the tab.
private enum TournamentText {

    static func text(_ kind: Tournament.Kind) -> String { kind.rawValue }

    static func kind(_ raw: String) -> Tournament.Kind {
        Tournament.Kind(rawValue: raw) ?? .singles
    }

    static func text(_ mode: Tournament.Mode?) -> String {
        switch mode {
        case .roundRobin: "round_robin"
        case .knockout: "knockout"
        case nil: "none"
        }
    }

    /// Read through the kind, not on its own. The CHECK guarantees the two agree, and reading them
    /// together means a row that somehow did not can still only produce a value the model considers
    /// legal — a team draw with no mode, or a played draw with one.
    static func mode(_ raw: String, kind: Tournament.Kind) -> Tournament.Mode? {
        guard kind != .team else { return nil }
        return raw == "knockout" ? .knockout : .roundRobin
    }
}
