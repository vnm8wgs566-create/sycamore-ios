//
//  FirstSort.swift
//  Sycamore
//
//  The ladder `4c` builds, one question at a time.
//
//  `4c` shows two kids and asks which is stronger. Its own caption says what it is doing —
//  "Tap the stronger player — the ladder builds itself" — and its progress figure says what shape
//  the doing has: "30 of 42 placed". That is insertion language, and it rules out most of the
//  alternatives before any of them is written down.
//
//  ── WHY BINARY INSERTION ─────────────────────────────────────────────────────────────────────
//
//  A rating system — Elo, or any of its relatives — has no terminal state and no honest "N
//  placed": every rating is provisional, so the screen could never say the ladder had settled and
//  the footnote promising a split "when the ladder settles" would be promising a moment that never
//  arrives. Merge sort takes fewer comparisons in the worst case and is worse here for the
//  opposite reason: nothing is *placed* until the final merge, so the bar would sit at zero
//  through forty questions and then jump to forty-two.
//
//  Binary insertion is the only one whose internal state **is the ladder**. Every answer leaves a
//  complete, valid ordering of everybody placed so far, which is exactly the shape
//  `RankAssignment` (`Models.swift:853`) and `Camp.applyRankOrder(_:)` (`:1250`) already take —
//  so the write path is the one that already exists, nothing new is persisted, and a sort
//  abandoned half way is a camp whose ladder is simply shorter rather than a camp mid-transaction.
//
//  ⌈log₂(n+1)⌉ questions per insertion. Seeding (below) is what keeps the real number small.
//
//  ── WHY IT IS SEEDED ─────────────────────────────────────────────────────────────────────────
//
//  `Player.isReturning` (`Models.swift:569`) and the existing `overallRank` are already a partial
//  order that somebody paid for last summer, and the design's own card copy reads it out loud —
//  "13 · returning · Group 1 last summer" against "12 · new this summer". Seeding the ladder with
//  the returning kids in the order they finished, and queueing only the new ones, is what makes a
//  camp of 42 with 30 returners *open* at "30 of 42 placed" with twelve insertions to do. It is
//  also the only reading in which the "last summer" line on the card earns its place.
//
//  ── WHY IT IS HERE ───────────────────────────────────────────────────────────────────────────
//
//  A separate file rather than more of `Models.swift`, for the reason `CampDays+Rules.swift:18-20`
//  states: that file is the one place every feature touches. Pure and `Sendable`, with no store
//  and no repository in it, so the arithmetic can be asked questions directly — which is what
//  `FirstSortTests.swift` does, and what `CampPartitionTests.swift` does to the other two sorters
//  in this app. A ladder that could only be exercised by driving a SwiftUI screen would be a
//  ladder nobody checks the corners of.
//

import Foundation

/// One venue's ranking session: what is settled, what is queued, and the pair on screen.
///
/// **Scope is one venue, not the camp.** `4c`'s crumb reads "Groups", and Groups is
/// venue-exclusive — one chip per venue and no "All" (`GroupsHeader.swift:110-118` states the
/// rule). Sorting the whole camp would also fight `applyRankOrder`, which reads section membership
/// as venue membership and would move kids between venues as a side effect of ranking them.
///
/// A value type with `private(set)` everywhere, so the only way the ladder changes is through one
/// of the four answers below. That is not ceremony: the invariant this type exists to keep is that
/// **nobody already placed is ever reshuffled**, and it is kept by there being no way to reach
/// `ladder` except by inserting into it.
struct FirstSort: Hashable, Sendable {

    let venueID: Venue.ID

    /// Settled, best first. Grows by exactly one on each insertion and is never reordered.
    private(set) var ladder: [Player.ID]
    /// Not yet asked about, in the order they will be asked.
    private(set) var pending: [Player.ID]
    /// Set aside. Kept in the order they were set aside, which — because `pending` is consumed
    /// from the front — is seed order.
    private(set) var skipped: [Player.ID]
    /// The kid on the top card: in flight, in neither `ladder` nor `pending`.
    private(set) var candidate: Player.ID?

    /// The candidate's live search window into `ladder`, half-open: they belong somewhere in
    /// `lo..<hi`, and `lo == hi` is the answer.
    ///
    /// Private because it is the algorithm's working state and not a fact about the camp. It is
    /// also the piece a `skip()` throws away, and a window that outlived its candidate would seat
    /// the *next* kid using the last one's answers.
    private var lo: Int
    private var hi: Int

    private init(
        venueID: Venue.ID,
        ladder: [Player.ID],
        pending: [Player.ID],
        skipped: [Player.ID],
        candidate: Player.ID?,
        lo: Int,
        hi: Int
    ) {
        self.venueID = venueID
        self.ladder = ladder
        self.pending = pending
        self.skipped = skipped
        self.candidate = candidate
        self.lo = lo
        self.hi = hi
    }

    /// A session over one venue's roll: returning kids already placed, new kids queued.
    ///
    /// The ladder is sorted by `overallRank` here rather than trusting the caller's order.
    /// `Camp.players(in:)` (`Models.swift:1021`) already returns them that way and every caller
    /// will pass it, which is exactly why this does not depend on it — a seed that reads
    /// differently depending on how the array arrived is the bug `ScheduleBlock.running(in:at:)`
    /// spent a whole comment block on (`SectionEight.swift:420-426`).
    ///
    /// `pending` keeps the caller's order, and that difference is deliberate. A returning kid has
    /// a rank and it is the whole point of seeding; a new kid has none — `overallRank` for a
    /// fresh import is whatever the roster file's line number turned into — so there is nothing
    /// to sort them by and the order they arrived in is as good an order to ask about them as any.
    ///
    /// Opens on the first question, or already settled: a venue of returners alone, or of one kid,
    /// has nothing to ask.
    static func seeded(venueID: Venue.ID, players: [Player]) -> FirstSort {
        var sort = FirstSort(
            venueID: venueID,
            ladder: players.filter(\.isReturning).sorted { $0.overallRank < $1.overallRank }.map(\.id),
            pending: players.filter { !$0.isReturning }.map(\.id),
            skipped: [],
            candidate: nil,
            lo: 0,
            hi: 0
        )
        sort.advance()
        return sort
    }

    // MARK: What the screen draws

    /// The two kids on screen — the candidate on the top card, the incumbent on the bottom. Nil
    /// once there is nothing left to ask.
    ///
    /// The incumbent is the midpoint of the live window, so answering it halves the window. It is
    /// a *different* person on nearly every question about the same candidate, which is the part
    /// worth saying out loud: the bottom card is not an opponent working their way up a list, it
    /// is the binary search's probe.
    var pair: (candidate: Player.ID, incumbent: Player.ID)? {
        guard let candidate, lo < hi else { return nil }
        return (candidate, ladder[(lo + hi) / 2])
    }

    /// The numerator of "30 of 42 placed".
    ///
    /// The ladder and nothing else. A kid on screen is not placed — they are the question — and a
    /// skipped kid is not placed either, which is what `skipped.count` is drawn separately for.
    var placed: Int { ladder.count }

    /// The denominator: the venue's whole roll, which does not move.
    ///
    /// Counted as the four buckets rather than remembered from the seed, because the four buckets
    /// are the roll — every kid is in exactly one of them at every moment. The in-flight candidate
    /// is counted **here and not in `placed`**, which is the arithmetic the design's own line
    /// describes: "30 of 42 placed · 3 skipped" is thirty settled, one on screen, three set aside
    /// and eight queued. A denominator that dipped to 41 while somebody was being asked about
    /// would be the total flickering under a progress bar that is meant to be filling.
    var total: Int {
        ladder.count + pending.count + skipped.count + (candidate == nil ? 0 : 1)
    }

    /// Nothing left to ask. Skipped kids do not hold this open — setting one aside is an answer,
    /// not a postponement.
    var isSettled: Bool { pending.isEmpty && candidate == nil }

    // MARK: The four answers

    /// The candidate is stronger than the incumbent: they belong above them.
    mutating func chooseCandidate() {
        guard let mid = probe else { return }
        hi = mid
        advance()
    }

    /// The incumbent is stronger: the candidate belongs below them.
    mutating func chooseIncumbent() {
        guard let mid = probe else { return }
        lo = mid + 1
        advance()
    }

    /// "About even" — seat the candidate directly below the incumbent and stop asking.
    ///
    /// The window collapses rather than narrowing: `lo` and `hi` both go to `mid + 1`, which is
    /// the slot immediately under the person they tie with, and `advance()` seats them there on
    /// the spot. A tie therefore costs **zero further questions**, which is the whole reason the
    /// control is on the screen — somebody who cannot separate two kids should not be made to
    /// answer three more questions about the same one.
    ///
    /// It reshuffles nobody. Seating below rather than above is a choice and the tie-break has to
    /// go somewhere; below is the one that leaves every existing position untouched, where above
    /// would push the incumbent and everyone under them down a rung on the strength of an answer
    /// that said the two were the same.
    mutating func tie() {
        guard let mid = probe else { return }
        lo = mid + 1
        hi = mid + 1
        advance()
    }

    /// Set the candidate aside and move on.
    ///
    /// **The partial window goes with them.** Half-answered questions about a kid nobody could
    /// place are not evidence to be kept: the window is an interval in a ladder that will have
    /// grown by the time anybody looks at that kid again, so `lo`/`hi` would be pointing at a
    /// position that has moved. `advance()` mints a fresh window for the next candidate, which is
    /// what discarding means in practice.
    ///
    /// Skipped kids fall to the foot of the venue in `playerIDs()`, keeping their relative order.
    /// They are not re-queued: a screen that handed the same undecidable pair back at the end
    /// would be refusing the answer somebody just gave.
    mutating func skip() {
        guard let candidate else { return }
        skipped.append(candidate)
        self.candidate = nil
        advance()
    }

    // MARK: Writing it back

    /// The venue's ladder as a `RankAssignment` wants it: settled kids in order, then the skipped
    /// ones at the foot in the order they were set aside.
    ///
    /// Skipped kids go to the foot rather than back where they started because there is nowhere
    /// else honest to put them — the sort was never told where they belong, and the foot is the
    /// one position that claims nothing. Keeping their relative order means a second pass over the
    /// same venue asks about them in the same sequence.
    ///
    /// **An in-flight candidate is in neither list.** Asked mid-question this omits the kid on
    /// screen, so a caller composing a `RankAssignment` from it should be doing so at
    /// `isSettled` — which is when `4c` finishes and calls `commitRankOrder(_:)`. There is no
    /// sensible third answer: the whole state of that kid is "we do not yet know", and inventing
    /// a rung for them is exactly the guess the screen exists to avoid.
    func playerIDs() -> [Player.ID] { ladder + skipped }

    // MARK: The loop

    /// The midpoint of the live window, or nil when there is no question on screen.
    ///
    /// The four answers all guard on this rather than on `candidate` alone, so a tap that lands
    /// after the last insertion — a double tap, or a view still holding the previous state — does
    /// nothing instead of moving a window that no longer belongs to anybody.
    private var probe: Int? {
        guard candidate != nil, lo < hi else { return nil }
        return (lo + hi) / 2
    }

    /// Seat whatever is finished and take the next question, repeatedly.
    ///
    /// A loop rather than one step, because seating a candidate can leave the next one with
    /// nothing to answer: the first kid into an empty ladder has a window of `0..<0` and is placed
    /// without a question, and so is every kid pulled after a `tie()` that emptied the queue. One
    /// step would leave `pair` nil with `pending` non-empty — a screen showing no cards and a
    /// progress bar short of full.
    private mutating func advance() {
        while true {
            if let candidate {
                // Still a question outstanding for this one — leave it on screen.
                guard lo == hi else { return }
                ladder.insert(candidate, at: lo)
                self.candidate = nil
            }
            guard !pending.isEmpty else { return }
            candidate = pending.removeFirst()
            lo = 0
            hi = ladder.count
        }
    }
}
