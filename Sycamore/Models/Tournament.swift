//
//  Tournament.swift
//  Sycamore
//
//  The draw a camp runs on a Friday, seeded off the ladder somebody spent Monday building.
//
//  ── WHY THE LADDER IS THE ONLY INPUT ─────────────────────────────────────────────────────────
//
//  Every one of the four seedings below is a function of one list: the venue's kids, best first.
//  Singles takes it as-is, doubles folds it in half, the team draft snakes down it, and the band
//  split cuts it into contiguous slices. Nothing here asks who won last year, who is friends with
//  whom, or who is away on Thursday — and that is deliberate rather than unfinished. The ladder is
//  the one ordering the camp has already agreed on (`FirstSort.swift` is the screen where they
//  agree on it), so a draw seeded from it is a draw nobody has to justify. The prototype's own
//  toast says as much: "Draw seeded by rank".
//
//  Availability is the one thing that legitimately re-orders a finished draw, and it is not here.
//  The design moves a match to a later day when somebody in it is away (`state1.js:805-824`), which
//  needs `Attendance` and the camp's day labels — store territory. What this file gives that layer
//  is `day(ofRound:)`, the *base* day a round falls on, which is the input that shifting works from.
//
//  ── WHY THE IDS ARE STRINGS ──────────────────────────────────────────────────────────────────
//
//  Every other model in this app carries a `UUID`, and every other model is a row somebody typed.
//  Entrants and matches are neither: they are *derived*, minted whole by `seeded(_:name:pool:…)`
//  from a pool and a rule, and they die when the tournament does. Giving them uuids would make two
//  seedings of the same pool unequal, which would quietly make `Hashable` useless for the one
//  question worth asking of a seeding — "does this pool always draw the same way?" — and would make
//  every test in `TournamentTests.swift` compare shapes instead of values.
//
//  So they are the prototype's own ids: `m1`, `m2`, … in the order matches are emitted, and `e0p`,
//  `e1p`, … in seed order. Deterministic, readable in a JSON column, and — because a bracket's
//  later rounds reference *earlier matches* rather than entrants — the thing `Side.winner(of:)`
//  points at. `Tournament.id` is the sole uuid here, because the tournament itself is a row.
//
//  ── WHY THE ODD KID IS AN ENTRANT ────────────────────────────────────────────────────────────
//
//  The prototype pairs the unrequested kids two at a time with `for (let i = 0; i + 1 < rest.length;
//  i += 2)` (`state1.js:915`), which walks off the end of an odd list and leaves the last kid out of
//  the draw entirely — no entrant, no match, no mention. An earlier version of the same loop
//  (`:684-687`) kept them as a one-person entrant and the card wrote them as "· bye".
//
//  This file does what the earlier version did. A camp of nineteen cannot be told it has nine
//  doubles pairs and no nineteenth child; the arithmetic has to leave a mark somewhere a screen can
//  find it, and `unpairedEntrants` is that mark. Whether the odd kid sits out, plays with a coach,
//  or makes somebody a three is a decision for the person running the camp — but they have to be
//  shown that the decision exists.
//
//  ── WHY IT IS HERE ───────────────────────────────────────────────────────────────────────────
//
//  Its own file, pure and `Sendable`, for the reason `FirstSort.swift:38-45` gives: `Models.swift`
//  is the file every feature touches, and arithmetic nobody can call without a store is arithmetic
//  nobody checks the corners of. The corners here are real — an odd pool, a requested pair with one
//  member missing, a bracket that is not a power of two, four tournaments asked of three kids — and
//  every one of them is a `#expect` in `TournamentTests.swift` rather than a screen somebody has to
//  drive to find out.
//

import Foundation

/// One draw over one venue's kids: who is in it, how they are paired, and who plays whom.
///
/// Value semantics throughout, and every field either given by the person creating it or derived
/// from the pool at that moment. There is no method on this type that reseeds itself — a draw is
/// struck once and then only scored, because a bracket that reshuffled when a kid was added is a
/// bracket nobody can print on Thursday night.
struct Tournament: Identifiable, Hashable, Codable, Sendable {

    // MARK: - What kind of draw

    /// What the kids play. The design's chips: "Singles", "Doubles", "Team tennis".
    enum Kind: String, Hashable, Codable, Sendable, CaseIterable {
        case singles, doubles, team
    }

    /// How the matches are laid out. The design's chips: "Round robin", "Draw".
    ///
    /// **Nil for team tennis, rather than a default nobody reads.** `state1.js:901-905` seeds
    /// rosters and stops, and `tCard` prints "Team matchups come later" — a team draw has no
    /// fixtures, so it has no layout for them either. The prototype stores `'rr'` on one anyway
    /// because its sheet draft carries the field whichever kind is picked, and that is the copy
    /// worth not making: a team tournament claiming to be a round robin is a claim some future
    /// caller will act on. `tournaments_team_has_no_mode` states the same rule at the column.
    enum Mode: String, Hashable, Codable, Sendable, CaseIterable {
        case roundRobin, knockout
    }

    /// Two kids somebody asked to keep together. Honoured only when **both** are in the pool.
    ///
    /// Order is kept as given rather than normalised to ladder order, because the pair's label is
    /// written "A + B" straight off this and the person who picked them picked them in an order.
    struct PairRequest: Hashable, Codable, Sendable {
        var a: Player.ID
        var b: Player.ID

        init(_ a: Player.ID, _ b: Player.ID) {
            self.a = a
            self.b = b
        }
    }

    /// The recipe a draw is struck from — the tournament sheet's draft, minus the parts every kind
    /// shares (name, courts, days).
    ///
    /// One case per kind rather than a `kind` plus four optional fields, so the combinations that
    /// cannot happen cannot be spelled: a team tournament has no mode and no requested pairs, and a
    /// singles tournament has no team count. `seeded(_:name:pool:courtIndices:days:)` switches on
    /// this and can therefore have no "what do I do with a team count on a singles draw" branch.
    enum Seeding: Hashable, Sendable {
        case singles(Mode)
        case doubles(Mode, requestedPairs: [PairRequest] = [])
        case team(count: Int)

        var kind: Kind {
            switch self {
            case .singles: .singles
            case .doubles: .doubles
            case .team: .team
            }
        }

        /// Nil for team tennis, which has no fixtures to lay out. See `Mode`.
        var mode: Mode? {
            switch self {
            case .singles(let mode), .doubles(let mode, _): mode
            case .team: nil
            }
        }
    }

    // MARK: - Who is in it

    /// One side of a match: a kid in singles, a pair in doubles, occasionally a lone kid.
    ///
    /// `playerIDs` rather than `playerID` even for singles, so the whole of `Match`, the whole of
    /// `standings` and the whole of the bracket read one shape. The prototype does the same
    /// (`ids: [k.id]`), and it is why the doubles and singles paths differ in exactly one function
    /// instead of throughout.
    struct Entrant: Identifiable, Hashable, Codable, Sendable {
        var id: String
        var playerIDs: [Player.ID]
        /// Whether this pair was asked for by name. Drawn as a pin on the card.
        var isRequested: Bool = false
        /// Position in the draw, in ladder indices: a kid's own index in singles, the **mean** of
        /// the two members' indices in doubles.
        ///
        /// A mean rather than the better half's index, so a pair of the 1st and the 20th seeds
        /// somewhere near the middle instead of at the top. It is fractional on purpose — 1 and 2
        /// seed at 1.5, which no whole index can express — and it is what the entrants are sorted
        /// by, so a requested pair takes the position its two members' strength earns rather than
        /// the position of whoever asked first.
        ///
        /// **Named `ladderIndex` and not `seed`, because a column called `seed` means something
        /// else.** `tournament_entrants.seed` is the 1-based, dense *seeding number* — an entrant's
        /// offset in `entrants` plus one, which is what the bracket's 1-vs-N pairing counts in.
        /// This is a fractional *strength*, and it exists only to produce that order.
        ///
        /// They were both called "seed" for about an hour. A repository writing `entrant.seed`
        /// straight into the column would have compiled after one `Int(...)`, truncated 1.5 to 1,
        /// and collided with the entrant actually seeded 1 — against a `UNIQUE (tournament_id,
        /// seed)`. That is a write failure at best and a silently reordered draw at worst, and
        /// the only thing standing between the two was a doc comment. Now the names differ.
        var ladderIndex: Double

        /// One person on this side. Unremarkable in singles, where it is *every* entrant, and the
        /// whole story in doubles — which is why the notable reading is `Tournament
        /// .unpairedEntrants` and not this. This is the raw fact; that one is the fact worth
        /// drawing.
        var isSolo: Bool { playerIDs.count == 1 }
    }

    /// A team-tennis roster.
    ///
    /// `id` is the draft position, not a uuid, for the reason the file header gives: the draft is
    /// derived, and "Team 3" *is* index 2.
    ///
    /// **Coaches are ids, although the design stores names.** `state1.js:783` keeps
    /// `tm.coaches` as strings picked out of `camp.staff`, which is a list of names in the
    /// prototype and a list of `StaffMember` records here. Storing the name would mean a coach who
    /// corrects the spelling of their own name silently leaves every team they were running, and
    /// two coaches called Sam would be one coach. It would also have nothing for
    /// `tournament_entrant_coaches.coach_id` to point at, which is a real foreign key with a real
    /// cascade — a coach removed from the camp comes off their teams because the database says so,
    /// not because something remembered to go and look.
    ///
    /// The name is still what gets drawn. It is read from `Camp.staff` at the moment of drawing,
    /// which is the same thing every other coach chip in this app already does.
    struct Team: Identifiable, Hashable, Codable, Sendable {
        var id: Int
        var name: String
        var coachIDs: [StaffMember.ID] = []
        var playerIDs: [Player.ID] = []
    }

    // MARK: - Who plays whom

    /// One half of a fixture: an entrant, or whoever comes out of an earlier match.
    ///
    /// The second case is what makes a bracket printable before it is played. A knockout's later
    /// rounds are struck at the same moment as its first, and they have to name *something* — the
    /// design draws it as "Winner of M3". Resolving it into a real entrant is `entrantID(of:)`,
    /// which needs the scores and therefore cannot live on the side itself.
    enum Side: Hashable, Sendable {
        case entrant(Entrant.ID)
        case winner(of: Match.ID)
    }

    /// One fixture. A nil side is a bye — the other side goes through unplayed.
    struct Match: Identifiable, Hashable, Codable, Sendable {
        var id: String
        /// 1-based. Round robin rounds are the circle's turns; knockout rounds are the bracket's
        /// columns, so round 1 is always the widest.
        var round: Int
        var a: Side?
        var b: Side?

        /// Exactly one side present: somebody walks through. Both sides nil is not a bye, it is a
        /// fixture with nobody in it, and `playableMatches` drops it either way.
        var isBye: Bool { (a == nil) != (b == nil) }
    }

    /// Games to A, games to B. Recorded against `Match.id`.
    struct Score: Hashable, Codable, Sendable {
        var a: Int
        var b: Int

        init(_ a: Int, _ b: Int) {
            self.a = a
            self.b = b
        }
    }

    /// A row of the round-robin table.
    struct Standing: Hashable, Sendable {
        var entrantID: Entrant.ID
        var won: Int
        var lost: Int
    }

    // MARK: - Stored

    var id: UUID = UUID()
    /// "Tournament 2". Numbered by the caller, because the number is a fact about the venue's list
    /// and not about the draw.
    var name: String
    var kind: Kind
    /// Nil exactly when `kind == .team`. See `Mode`.
    var mode: Mode?

    /// Which of the venue's courts fed the pool, as **0-based positions in the venue's own court
    /// order** — `Camp.groups(in:)` order, which is `rankOrder`.
    ///
    /// Positions rather than `Group.ID`s, matching the prototype, and that is a real trade. Ids
    /// would survive a court being reordered; positions survive a court being *deleted and
    /// recreated*, which is what `syncGroups(for:)` does every time somebody changes a venue's
    /// court count. Neither is safe against both, and the design's own chip reads them out as
    /// positions — "Group 1+2" — so an id would have to be resolved back to a position to draw the
    /// card this field exists for.
    ///
    /// Either way it is **provenance, not a relationship**: it records which courts were asked for
    /// when the draw was struck, and re-reading it never changes who is playing — that is settled
    /// in `entrants`. `courtIndices(of:in:)` and `courtIDs(of:in:)` convert, for a persistence
    /// layer that would rather keep ids.
    var courtIndices: [Int]

    /// How many days the rounds are spread over. At least 1; see `day(ofRound:)`.
    var days: Int

    /// Seed order, best first. Empty for team tennis.
    var entrants: [Entrant] = []
    /// Empty for anything but team tennis.
    var teams: [Team] = []
    /// Empty for team tennis, whose fixtures the design leaves for later.
    var matches: [Match] = []
    /// Sparse — only matches somebody has scored.
    var scores: [Match.ID: Score] = [:]
}

// MARK: - Seeding

extension Tournament {

    /// Strikes the draw: entrants seeded off `pool`, then fixtures laid out over them.
    ///
    /// `pool` is taken already narrowed and already in ladder order — `pool(_:across:courtIndices:)`
    /// is the function that narrows it — because every rule below is positional. "Pair adjacently",
    /// "seed at the mean index" and "snake down the list" all mean nothing except relative to an
    /// order, and a seeding that re-sorted its own input would be entitled to disagree with the
    /// ladder somebody built by hand.
    ///
    /// An empty pool draws an empty tournament rather than refusing to. The prototype bails
    /// (`state1.js:898`), which is right for a button somebody just tapped and wrong for a value
    /// type — a caller that cannot make an empty one has to duplicate the emptiness check to find
    /// out. `banded` below is where the refusal actually belongs, and it makes it.
    static func seeded(
        _ seeding: Seeding,
        name: String,
        pool: [Player],
        courtIndices: [Int],
        days: Int = 1
    ) -> Tournament {
        var tournament = Tournament(
            name: name,
            kind: seeding.kind,
            mode: seeding.mode,
            // Numerically, unlike the prototype's bare `.sort()`, which is JavaScript's
            // lexicographic default and would order an eleven-court venue 0, 1, 10, 2.
            courtIndices: courtIndices.sorted(),
            days: max(1, days)
        )

        let mode: Mode
        switch seeding {
        case .singles(let picked):
            mode = picked
            tournament.entrants = singlesEntrants(pool: pool)
        case .doubles(let picked, let requestedPairs):
            mode = picked
            tournament.entrants = doublesEntrants(pool: pool, requestedPairs: requestedPairs)
        case .team(let count):
            tournament.teams = teams(pool: pool, count: count)
            return tournament
        }

        tournament.matches = mode == .roundRobin
            ? roundRobinMatches(tournament.entrants)
            : knockoutMatches(tournament.entrants)
        return tournament
    }

    /// `count` tournaments, one per contiguous rank band off `ladder`.
    ///
    /// The other half of the question the design answered only once. `createTournament`
    /// (`state1.js:670`) split the venue into `cnt` bands and drew a tournament in each; the live
    /// `createTourney2` (`:893`) replaced that with picking courts, and the split went with it —
    /// but "make me three tournaments, strongest kids together" is a thing camps ask for and
    /// picking courts only answers it when the courts happen to be the bands. Both are here.
    ///
    /// Bands are contiguous and the remainder goes to the **stronger** ones, which is
    /// `Camp.deal(_:across:)`'s rule (`Models.swift:1462`) and `bandSizes`' below. 20 kids into 3
    /// gives 7 / 7 / 6, and the extra kid lands where the standard is highest rather than where it
    /// is lowest.
    ///
    /// **Fewer tournaments come back than were asked for when the ladder is short.** 3 kids into 5
    /// bands is three bands of one and two of nothing, and a tournament with nobody in it is not
    /// something a camp can run — `createTourney2` refuses to make one and so does this. The count
    /// of the returned array is the honest answer; `bands(_:into:)` is there for a caller that
    /// wants to see the empties.
    static func banded(
        _ seeding: Seeding,
        namePrefix: String = "Tournament",
        ladder: [Player],
        into count: Int,
        courtIndices: [Int],
        days: Int = 1
    ) -> [Tournament] {
        bands(ladder, into: count)
            .filter { !$0.isEmpty }
            .enumerated()
            .map { offset, band in
                seeded(
                    seeding,
                    name: "\(namePrefix) \(offset + 1)",
                    pool: band,
                    courtIndices: courtIndices,
                    days: days
                )
            }
    }

    // MARK: The pool

    /// The venue's kids as one ladder, best first: court by court in the venue's own court order,
    /// and by `courtRank` inside each court.
    ///
    /// This is `ladderOf` (`state1.js:424`), whose sort is `(group, rank)`. Court *order* here is
    /// the caller's array order rather than `Group.number`, because `Camp.groups(in:)` already
    /// sorts by `rankOrder` and `rankOrder` is the thing that moves when somebody reorders courts —
    /// reading `number` would ignore the reorder and seed the draw off the old ladder.
    ///
    /// A kid on no court, or on a court outside `courts`, is not in the ladder. That is how the
    /// narrowing below works at all, and it is also right for the whole-venue call: a kid with a
    /// nil `groupID` is mid-import, and putting them in a draw would be inventing a rung for them.
    ///
    /// `overallRank` breaks a `courtRank` tie. There should never be one — `Camp.reindex()`
    /// renumbers every court from 1 — but Swift's sort is not stable, and a camp read mid-reindex
    /// would otherwise seed differently on different runs from the same data.
    static func ladder(_ players: [Player], across courts: [Group]) -> [Player] {
        var position: [Group.ID: Int] = [:]
        for (offset, court) in courts.enumerated() { position[court.id] = offset }

        return players
            .compactMap { player -> (court: Int, player: Player)? in
                guard let groupID = player.groupID, let court = position[groupID] else { return nil }
                return (court, player)
            }
            .sorted { left, right in
                if left.court != right.court { return left.court < right.court }
                if left.player.courtRank != right.player.courtRank {
                    return left.player.courtRank < right.player.courtRank
                }
                return left.player.overallRank < right.player.overallRank
            }
            .map(\.player)
    }

    /// That ladder, narrowed to the courts a tournament draws from. `courtIndices` are 0-based
    /// positions in `courts`; an index off the end selects nothing rather than trapping.
    static func pool(_ players: [Player], across courts: [Group], courtIndices: [Int]) -> [Player] {
        let wanted = Set(courtIndices)
        let chosen = courts.enumerated().filter { wanted.contains($0.offset) }.map(\.element)
        return ladder(players, across: chosen)
    }

    /// The courts named by `courtIndices`, as ids.
    ///
    /// A persistence layer would rather store ids than positions — `tournaments.group_ids` does —
    /// and the conversion is a fact about the venue's court order rather than about either layer,
    /// so it lives here where a test can reach it rather than being written out twice. Both
    /// directions drop what they cannot resolve: an index past the end of the venue, or an id
    /// belonging to a court that has since been deleted, is a court that is not there.
    static func courtIDs(of courtIndices: [Int], in courts: [Group]) -> [Group.ID] {
        courtIndices.filter(courts.indices.contains).map { courts[$0].id }
    }

    /// The other direction: court ids back to positions in the venue's court order, sorted.
    static func courtIndices(of courtIDs: [Group.ID], in courts: [Group]) -> [Int] {
        let wanted = Set(courtIDs)
        return courts.enumerated().filter { wanted.contains($0.element.id) }.map(\.offset)
    }

    // MARK: Bands

    /// `count` band sizes summing to `total`, each within one of the others, remainder to the front.
    ///
    /// The same arithmetic as `Camp.deal(_:across:)` (`Models.swift:1462`) and the prototype's
    /// `bandSizes` (`state1.js:427`), and it is written out a third time rather than shared because
    /// the two existing copies both take things this does not have: `deal` wants courts and mutates
    /// players, and the prototype's wants a venue. What is shared is the *rule*, and the rule is
    /// worth stating: remainder to the earlier bands, so a split of a ladder puts the spare kid
    /// where the play is strongest.
    ///
    /// A count of zero or less returns no bands, which is the only answer that does not divide by
    /// zero and the same guard `deal` opens with.
    static func bandSizes(_ total: Int, into count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let size = max(0, total)
        let base = size / count
        let remainder = size % count
        return (0..<count).map { base + ($0 < remainder ? 1 : 0) }
    }

    /// `ladder` cut into `count` contiguous slices by `bandSizes`. Always exactly `count` of them —
    /// a short ladder yields empty bands at the tail rather than fewer bands.
    static func bands<Element>(_ ladder: [Element], into count: Int) -> [[Element]] {
        var cursor = 0
        return bandSizes(ladder.count, into: count).map { size in
            defer { cursor += size }
            return Array(ladder[cursor..<(cursor + size)])
        }
    }

    // MARK: Entrants

    /// One entrant per kid, in ladder order. Seeds are the ladder indices themselves.
    static func singlesEntrants(pool: [Player]) -> [Entrant] {
        pool.enumerated().map { offset, player in
            Entrant(id: "e\(player.id.uuidString)", playerIDs: [player.id], ladderIndex: Double(offset))
        }
    }

    /// Pairs, seeded by mean ladder index: requested pairs first, then everybody else paired
    /// adjacently down the ladder, then the lot sorted by seed.
    ///
    /// **Adjacent pairing, not strong-with-weak.** Kids 1 and 2 play together, 3 and 4 play
    /// together. It reads backwards — the usual instinct is to balance each pair — but balancing
    /// makes every pair identical in strength, and a draw of identical pairs has no seeding left in
    /// it. Pairing adjacently keeps the ladder's spread *between* the pairs, which is what makes
    /// the first round of a bracket 1-vs-N rather than a coin toss.
    ///
    /// **A requested pair with one member outside the pool is not honoured.** Both of them fall
    /// back into the adjacent pairing, including the one who is in the pool — the prototype's
    /// filter runs before `inReq` is built (`state1.js:911-913`), and it is the right order: the
    /// in-pool half of a broken request is just a kid who needs a partner. (The superseded version
    /// at `:680` built `inReq` from the *unfiltered* list and left that kid out of `rest` as well,
    /// dropping them exactly the way the odd-kid loop does.)
    ///
    /// **A kid named in two requested pairs enters twice.** That is the design's behaviour and it
    /// is not defended here — it is a precondition on the caller, whose pair picker is what stops
    /// it from happening. See the report.
    static func doublesEntrants(pool: [Player], requestedPairs: [PairRequest] = []) -> [Entrant] {
        var index: [Player.ID: Int] = [:]
        for (offset, player) in pool.enumerated() { index[player.id] = offset }

        typealias Draft = (playerIDs: [Player.ID], isRequested: Bool, ladderIndex: Double)

        var drafts: [Draft] = requestedPairs.compactMap { pair in
            guard let a = index[pair.a], let b = index[pair.b] else { return nil }
            return ([pair.a, pair.b], true, Double(a + b) / 2)
        }

        // Carried with their ladder indices rather than looked up again: `rest` is a subsequence of
        // `pool`, so the enumeration offset *is* the seed, and nothing has to be force-unwrapped
        // back out of `index` to find it.
        let claimed = Set(drafts.flatMap(\.playerIDs))
        let rest = pool.enumerated().filter { !claimed.contains($0.element.id) }

        var cursor = 0
        while cursor + 1 < rest.count {
            let left = rest[cursor], right = rest[cursor + 1]
            drafts.append(([left.element.id, right.element.id], false, Double(left.offset + right.offset) / 2))
            cursor += 2
        }
        // The odd kid. The prototype's loop condition steps straight past them; see the file header.
        if cursor < rest.count {
            let last = rest[cursor]
            drafts.append(([last.element.id], false, Double(last.offset)))
        }

        // Sorted by seed, ties broken by the order the drafts were built in — requested pairs
        // first, then down the ladder. Swift's sort is not stable and JavaScript's is, so the
        // tie-break is spelled out rather than assumed: a requested pair of the 1st and 4th seeds
        // and an adjacent pair of the 2nd and 3rd both seed at 1.5, and which of them is entrant
        // zero should not depend on the sort's internals.
        return drafts.enumerated()
            .sorted { left, right in
                left.element.ladderIndex == right.element.ladderIndex
                    ? left.offset < right.offset
                    : left.element.ladderIndex < right.element.ladderIndex
            }
            .enumerated()
            .map { position, draft in
                Entrant(
                    id: "e\(position)p",
                    playerIDs: draft.element.playerIDs,
                    isRequested: draft.element.isRequested,
                    ladderIndex: draft.element.ladderIndex
                )
            }
    }

    /// A snake draft down the ladder: 1st kid to team 1, 2nd to team 2, and the next round back the
    /// other way so the team that picked last picks first.
    ///
    /// Serpentine rather than straight round-robin because a straight deal hands team 1 the 1st,
    /// 5th, 9th and 13th kids and team 4 the 4th, 8th, 12th and 16th — a whole rung of the ladder
    /// between them, every round, compounding. Reversing alternate rounds pairs each team's early
    /// pick with a late one, and the teams come out within a round's worth of each other in total
    /// strength. That balance is what `TournamentTests` measures, because it is the only reason to
    /// prefer this to the obvious deal.
    static func teams(pool: [Player], count: Int) -> [Team] {
        guard count > 0 else { return [] }
        var teams = (0..<count).map { Team(id: $0, name: "Team \($0 + 1)") }
        for (offset, player) in pool.enumerated() {
            let round = offset / count
            let position = round.isMultiple(of: 2) ? offset % count : count - 1 - (offset % count)
            teams[position].playerIDs.append(player.id)
        }
        return teams
    }

    // MARK: Fixtures

    /// Everybody plays everybody once — the circle method, with a nil seat when the count is odd.
    ///
    /// One entrant is pinned and the rest rotate around them, which is what guarantees the two
    /// properties a round robin is judged on: `n(n-1)/2` matches, and nobody playing twice in the
    /// same round. Naive "every pair, in some order" gets the count right and the second property
    /// wrong, and a camp cannot run a round where a kid is on two courts.
    ///
    /// An odd count pads with a nil, and the nil rotates like anybody else — so the sit-out is a
    /// different entrant each round rather than the same unlucky one. **Byes are not emitted as
    /// matches.** A round-robin bye is not a fixture, it is an hour off, and a card that listed
    /// "Ana vs —" would be asking somebody to score it.
    static func roundRobinMatches(_ entrants: [Entrant]) -> [Match] {
        guard entrants.count >= 2 else { return [] }

        var wheel: [Entrant.ID?] = entrants.map(\.id)
        if !wheel.count.isMultiple(of: 2) { wheel.append(nil) }
        let seats = wheel.count
        let half = seats / 2

        var rotating = Array(wheel.dropFirst())
        var matches: [Match] = []

        for round in 0..<(seats - 1) {
            let left = [wheel[0]] + rotating.prefix(half - 1)
            let right = Array(rotating.dropFirst(half - 1).reversed())
            for seat in 0..<half {
                guard let a = left[seat], let b = right[seat] else { continue }
                matches.append(
                    Match(id: "m\(matches.count + 1)", round: round + 1, a: .entrant(a), b: .entrant(b))
                )
            }
            if let last = rotating.popLast() { rotating.insert(last, at: 0) }
        }
        return matches
    }

    /// A knockout bracket, padded up to the next power of two, seed `i` against seed `size-1-i`.
    ///
    /// **The padding is byes, not filler entrants.** 11 pairs make a bracket of 16 with five
    /// first-round matches missing a side, and the five top seeds are the ones who get them —
    /// `seeds[size - 1 - i]` runs off the end of the list first. That is the whole point of the
    /// pairing: 1-vs-16, 2-vs-15, so the strongest entrants meet the weakest early and each other
    /// late, and the ones who skip round one are the ones who earned it on the ladder.
    ///
    /// Later rounds are struck at the same time as the first and reference matches, not entrants —
    /// see `Side`. That is what lets the whole bracket be drawn before a ball is hit.
    static func knockoutMatches(_ entrants: [Entrant]) -> [Match] {
        guard entrants.count >= 2 else { return [] }

        let seeds = entrants.map(\.id)
        var size = 1
        while size < seeds.count { size *= 2 }

        func side(_ index: Int) -> Side? {
            seeds.indices.contains(index) ? .entrant(seeds[index]) : nil
        }

        var previous = (0..<(size / 2)).map { position in
            Match(
                id: "m\(position + 1)",
                round: 1,
                a: side(position),
                b: side(size - 1 - position)
            )
        }
        var matches = previous
        var minted = previous.count
        var round = 2

        while previous.count > 1 {
            var current: [Match] = []
            var position = 0
            while position + 1 < previous.count {
                minted += 1
                current.append(
                    Match(
                        id: "m\(minted)",
                        round: round,
                        a: .winner(of: previous[position].id),
                        b: .winner(of: previous[position + 1].id)
                    )
                )
                position += 2
            }
            matches += current
            previous = current
            round += 1
        }
        return matches
    }
}

// MARK: - What the card reads back

extension Tournament {

    func entrant(_ id: Entrant.ID) -> Entrant? { entrants.first { $0.id == id } }

    /// Kids left without a partner: at most one, and only in doubles.
    ///
    /// The property the file header promises. A screen that draws pairs and never looks at this
    /// will silently show one fewer kid than the camp has, which is the defect this file exists to
    /// not repeat — the design's older card wrote them as "· bye" (`state1.js:663`).
    ///
    /// **Gated on the kind, not just on `Entrant.isSolo`.** Every singles entrant is one person, so
    /// the ungated read would return the whole draw and a screen wired to it would announce that
    /// forty kids had nobody to play with. The state being reported here is *doubles that could not
    /// pair somebody*, and only doubles can be in it.
    var unpairedEntrants: [Entrant] {
        kind == .doubles ? entrants.filter(\.isSolo) : []
    }

    /// Fixtures with somebody on both sides. A bye is not one, and neither is a bracket slot whose
    /// feeder had nobody in it.
    var playableMatches: [Match] { matches.filter { $0.a != nil && $0.b != nil } }

    /// The rounds this draw has, in order. Derived rather than stored, because a round is only ever
    /// "a number some matches share".
    var rounds: [Int] { Set(matches.map(\.round)).sorted() }

    /// Which day a round falls on, 1-based.
    ///
    /// Rounds are spread evenly and in order, filling each day before starting the next: 7 rounds
    /// over 2 days is 4 then 3, not 3 then 4. The ceiling is what makes it fit — a floor would
    /// leave rounds past the last day with nowhere to go.
    ///
    /// This is the *base* day. The design moves individual matches later when somebody in them is
    /// away, which is a read over `Attendance` and does not belong in the model — see the file
    /// header.
    func day(ofRound round: Int) -> Int {
        let ordered = rounds
        guard let position = ordered.firstIndex(of: round) else { return 1 }
        let spread = max(1, days)
        let perDay = max(1, (ordered.count + spread - 1) / spread)
        return position / perDay + 1
    }

    /// "Final", "Semis", "Quarters", "Round of 16" — named from the **end** of the bracket, because
    /// that is where the names come from. The last round is the final whether the draw started at
    /// 32 or at 4, and only the rounds further out than the quarters are named by their width.
    func roundName(_ round: Int) -> String {
        let ordered = rounds
        guard let position = ordered.firstIndex(of: round) else { return "Round \(round)" }
        switch ordered.count - 1 - position {
        case 0: return "Final"
        case 1: return "Semis"
        case 2: return "Quarters"
        default: return "Round of \(matches.filter { $0.round == round }.count * 2)"
        }
    }

    /// Who is actually standing on this side of a fixture, following "winner of M3" back through
    /// the bracket as far as the scores allow. Nil while it is still undecided.
    func entrantID(of side: Side?) -> Entrant.ID? {
        resolve(side, fuel: matches.count * 2 + 2)
    }

    /// Who came out of a match. Nil until it has been scored — except for a bye, which needs no
    /// score because there was nobody to play.
    ///
    /// **An equal score is a win for B.** That is the design's rule (`state1.js:797`, `sc[0] > sc[1]
    /// ? A : B`) and it is transcribed rather than corrected; see the report. Camps score sets, so
    /// a draw should not be reachable — but nothing stops somebody typing 6–6.
    func winner(of matchID: Match.ID) -> Entrant.ID? {
        winner(of: matchID, fuel: matches.count * 2 + 2)
    }

    /// The round-robin table: most wins first, fewest losses breaking a tie, seed order breaking
    /// that.
    ///
    /// Seed order last is what stops the table from reshuffling between reads when nothing has been
    /// played — every row is 0–0 at the start, and a table that came back in a different order each
    /// time somebody opened the card would look like results arriving.
    var standings: [Standing] {
        var won: [Entrant.ID: Int] = [:]
        var lost: [Entrant.ID: Int] = [:]

        for match in playableMatches {
            guard let score = scores[match.id],
                  let a = entrantID(of: match.a),
                  let b = entrantID(of: match.b)
            else { continue }
            let (winner, loser) = score.a > score.b ? (a, b) : (b, a)
            won[winner, default: 0] += 1
            lost[loser, default: 0] += 1
        }

        return entrants.enumerated()
            .map { (order: $0.offset, standing: Standing(entrantID: $0.element.id, won: won[$0.element.id, default: 0], lost: lost[$0.element.id, default: 0])) }
            .sorted { left, right in
                if left.standing.won != right.standing.won { return left.standing.won > right.standing.won }
                if left.standing.lost != right.standing.lost { return left.standing.lost < right.standing.lost }
                return left.order < right.order
            }
            .map(\.standing)
    }

    /// `12 of 21 played`, as its two numbers.
    var playedCount: Int { playableMatches.filter { scores[$0.id] != nil }.count }

    // MARK: The walk back through the bracket

    /// Resolution is mutually recursive — a side names a match, a match's winner is a side — and the
    /// data it walks is decodable from outside, so a hand-edited or corrupted bracket could name a
    /// cycle. `fuel` is what makes that a nil instead of a hang: no honest chain is longer than the
    /// bracket is deep, and the depth is bounded by the match count.
    private func resolve(_ side: Side?, fuel: Int) -> Entrant.ID? {
        guard fuel > 0, let side else { return nil }
        switch side {
        case .entrant(let id): return id
        case .winner(let matchID): return winner(of: matchID, fuel: fuel - 1)
        }
    }

    private func winner(of matchID: Match.ID, fuel: Int) -> Entrant.ID? {
        guard fuel > 0, let match = matches.first(where: { $0.id == matchID }) else { return nil }
        if match.b == nil { return resolve(match.a, fuel: fuel - 1) }
        if match.a == nil { return resolve(match.b, fuel: fuel - 1) }
        guard let score = scores[matchID],
              let a = resolve(match.a, fuel: fuel - 1),
              let b = resolve(match.b, fuel: fuel - 1)
        else { return nil }
        return score.a > score.b ? a : b
    }
}

// MARK: - Wire shape

/// Written the way the prototype writes it: a plain string for an entrant, `{"w": "m3"}` for a
/// forward reference. The synthesised encoding for an enum with associated values would spell the
/// first as `{"entrant": {"_0": "e0p"}}` — legible to nobody, and pinned to the case names, so
/// renaming a case would silently orphan every bracket already in the database.
extension Tournament.Side: Codable {
    private enum Key: String, CodingKey { case w }

    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let id = try? single.decode(String.self) {
            self = .entrant(id)
            return
        }
        let keyed = try decoder.container(keyedBy: Key.self)
        self = .winner(of: try keyed.decode(String.self, forKey: .w))
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .entrant(let id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case .winner(let matchID):
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(matchID, forKey: .w)
        }
    }
}
