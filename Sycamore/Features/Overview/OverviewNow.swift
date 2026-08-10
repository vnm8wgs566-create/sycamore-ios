//
//  OverviewNow.swift
//  Sycamore
//
//  What the camp is in the middle of, resolved into the handful of facts Overview draws.
//
//  Overview has known which block was running since it was written — `OverviewView` has called
//  `ScheduleBlock.running(in:at:)` from the start — and it spent that knowledge on two things: a
//  header line reading "Skills rotation · until 10:30", and the *first* note off the block, drawn
//  on your own court and nowhere else. Everything else the block carries went unread: who is on
//  it, what it says to do, the rest of its notes, and (since the editor learned to say so) which
//  courts it runs on.
//
//  So this is the block, unpacked. It is a value rather than a view because every one of those is
//  arithmetic — which block, whose ids resolve, which courts float to the top — and the house rule
//  for this feature is that the arithmetic lives outside `body` where a test can reach it.
//  `TodayCourts` is the same argument about the roster, and `OverviewRosterTests` is what it buys.
//
//  Built once per pass by `OverviewView` and handed down, for the reason `OverviewScreen.body`
//  states about rosters: this screen redraws on every tick of `AppStore.clock`, and a resolve per
//  card would walk the staff list once per court, once a minute, forever.
//

import Foundation

/// The running block and everything Overview says about it.
///
/// Nil at the store level means "no block is running", which is two different situations the
/// screen has to tell apart and this type deliberately does not: a day with no blocks on it at all
/// (which draws the call to action) and a day whose blocks have all finished (which does not). See
/// `OverviewView.now` — the day's block *count* is what separates them, and it is a fact about the
/// day rather than about a block that does not exist.
struct OverviewNow: Hashable, Sendable {

    /// The block itself, so a caller that needs a field this type has not named can still ask.
    let block: ScheduleBlock

    /// Who the block says is running it, in the order it names them.
    ///
    /// `compactMap`ped rather than force-resolved, for the reason `ScheduleBlock.coachLine(in:)`
    /// spells out: "Remove from camp" deactivates rather than deletes, so a departed coach keeps
    /// their `schedule_block_coaches` row while dropping out of `staff`. An id that resolves to
    /// nobody is ordinary, and a block whose only coach has left draws as a block nobody is on —
    /// which is true, and is the state an admin needs to see.
    ///
    /// That resolve is now written four times — here, in `ScheduleBlock.coachLine(in:)`
    /// (`SectionEight.swift:259`), in `BlockAssigneeList.coaches(on:in:)`
    /// (`BlockAssigneeList.swift:54`) and in `BlockCourtCard.coaches(on:court:in:)`
    /// (`BlockCourtCard.swift:196`) — and the rule about departed coaches five times, because it has
    /// nowhere to be stated once. It belongs beside `coachLine` as
    /// `ScheduleBlock.coaches(in: [StaffMember]) -> [StaffMember]`, with `coachLine` composed on top
    /// of it and this reading `block.coaches(in: staff)`.
    ///
    /// **This used to say "`Models/` is another unit's file", and that is no longer the reason.**
    /// It was a true statement about one wave's folder split and it read as a standing rule, which
    /// is the failure worth naming: an excuse that outlives its cause is indistinguishable from an
    /// argument. `Models/` took two new files this change — `FirstSort.swift` and
    /// `CoachAvailability.swift` — so nothing is walled off.
    ///
    /// What is actually left is scope, and it points the other way from where the excuse pointed:
    /// the new function is one declaration in `Models/SectionEight.swift`, but the *value* of it is
    /// the three call sites it deletes, and all three are in `Features/Schedule/`. Landing only the
    /// model half would put a fifth spelling of this resolve in the app and remove none — strictly
    /// worse than the four. It moves when the same pass can touch `Schedule/` too.
    let coaches: [StaffMember]

    /// The clock this was resolved against — what makes "41 min left" a countdown rather than a
    /// figure somebody typed.
    ///
    /// Carried on the value rather than read inside `remainingLabel`, and for the reason the whole
    /// type exists: `resolve` is already told what "now" means by its caller (`AppStore.timeOfDay`
    /// in the app, a fixed time in a test), and a second reading of the wall clock further down
    /// would let the card's countdown and the card's *existence* disagree about what time it is.
    /// The screen redraws on every tick of `AppStore.clock`, so this moves with it.
    ///
    /// Optional, and nil is honest rather than defensive: `OverviewNow` can be built directly — the
    /// previews and `OverviewNowTests` both do — and a value built with no clock draws the card
    /// with no countdown on it, which is exactly the rule below.
    var at: TimeOfDay? = nil

    /// What follows this block, for the same reader.
    ///
    /// **The same scope as the card itself, deliberately.** A venue can run two blocks at once
    /// (`resolve`'s own header), so "next" is as much a question about who is asking as "now" is: a
    /// coach on Court 1 gets what is next *on Court 1*, and an admin gets the next thing to start
    /// anywhere in the venue. Resolved in `resolve` alongside the running block, from the same list
    /// and through the same court filter, so the two halves of the card cannot come to be about
    /// different people.
    var next: ScheduleBlock? = nil

    /// "Skills rotation".
    var title: String { block.title }

    /// The block's own instruction — "Cross-court forehand feeds, then a volley ladder." Nil is
    /// the ordinary case: a block is entitled to be just a title and a time.
    var instruction: String? { block.detail }

    /// Everything written against the block, not just the first line of it.
    ///
    /// Overview drew `notes.first` and only on your own court, which was a reasonable reading of a
    /// design frame with one note in it and a poor one of a morning: the second note off a block is
    /// as likely to be the allergy as the first, and a coach standing on Court 3 could not see
    /// either.
    var notes: [BlockNote] { block.notes }

    /// "until 10:30", or "from 8:30" on a block nobody gave an end.
    ///
    /// The endless case used to draw the bare title with no time at all, which read as a block with
    /// no hours rather than one with no finish. Both halves are composed here so the header line
    /// and the card cannot word the same fact differently.
    var timeLabel: String {
        guard let ends = block.endsAt else { return "from \(block.startsAt.shortLabel)" }
        return "until \(ends.shortLabel)"
    }

    /// "Skills rotation · until 10:30" — the line 8i put under the screen's title.
    ///
    /// **Nothing on Overview draws this any more.** 4a's header carries the date and the camp-day
    /// index instead ("Tuesday, 12 August · day 2 of 5"), because the block now has a card of its
    /// own at the top of the scroll and a header that repeated it was answering a question the
    /// screen no longer had. Kept because it is the one composition of these two facts and the next
    /// screen that wants the pair should read it rather than write a second one.
    var headerLine: String { "\(title) · \(timeLabel)" }

    // MARK: 4a's on-now card

    /// `41` — whole minutes between the clock this was resolved at and the block's stated end.
    ///
    /// Nil three ways, and each is a real morning rather than a guard: a block with no `endsAt`
    /// (`OverviewNow` draws "from 8:30" for those and has nothing to count down to), a value built
    /// with no clock, and a block already past its end — which `ScheduleBlock.running` will not
    /// hand back, but this type can be constructed directly and must not report a negative.
    var minutesLeft: Int? {
        guard let ends = block.endsAt, let at, at < ends else { return nil }
        return ends.id - at.id
    }

    /// `41 min left`, or nil where there is nothing to count.
    ///
    /// **Minutes all the way up, and no hour rollover.** `ScheduleDay.statusLine`
    /// (`ScheduleBlockPresentation.swift:129-152`) already writes this exact clause for `8k`'s
    /// running card and writes it that way, so a two-hour block reads "118 min left" on both
    /// screens or on neither. A camp block is a rotation and runs in tens of minutes; the one that
    /// does not is a whole morning, where "118 min left" is odd and "1 h 58 min left" is a format
    /// nothing else in the app knows how to say.
    ///
    /// Spelled here rather than called over there. The two are the same clause and that is worth
    /// being uncomfortable about — but `ScheduleDay.statusLine` returns the *whole* line and folds
    /// four other states into it ("Done", "Earlier today", "Needs a coach"), none of which this
    /// card is ever drawn in: it exists only for a block that is running, and it draws its line in
    /// `Theme.accent`. Calling it would mean a green "Needs a coach" the first morning somebody
    /// left a running block unstaffed.
    var remainingLabel: String? {
        minutesLeft.map { "\($0) min left" }
    }

    /// `On now · 41 min left`, and plainly `On now` where the block has no end to count to.
    ///
    /// Composed here so the middot can never be printed with nothing after it — the one thing the
    /// design's own separator makes easy to get wrong.
    var statusLine: String {
        guard let remainingLabel else { return "On now" }
        return "On now · \(remainingLabel)"
    }

    /// `ends 10:30`, the quiet figure at the trailing edge of the same row. Nil on an open-ended
    /// block, where `statusLine` has already said "On now" and there is nothing to add.
    var endsLabel: String? {
        block.endsAt.map { "ends \($0.shortLabel)" }
    }

    /// `Next · Water & regroup · 10:30` — the card's footer. Nil when nothing follows, which is the
    /// last block of the day and draws no rule and no line rather than "Next · nothing".
    var nextLine: String? {
        next.map { "Next · \($0.title) · \($0.startsAt.shortLabel)" }
    }

    /// `Courts 1–3 · 22 players · Nass, Alina, Tom` — the line under the block's title.
    ///
    /// Three clauses, each dropped when it cannot be answered, and the middot only ever printed
    /// between two clauses that exist. A `.regular` block names no courts, so a lunch reads
    /// "50 players" and no more — which is true of a lunch.
    ///
    /// **The head-count is today's, not the roll.** `playersHere` counts the kids standing on those
    /// courts with the away records taken off, which is the same arithmetic `CourtCard.playersHere`
    /// and `TodayCourts` use for "8 of 8" further down the same screen. A card that said 22 over a
    /// morning where two are off would disagree with the four cards under it.
    ///
    /// Takes the camp rather than storing the string, for `ScheduleBlock.coachLine(in:)`'s reason:
    /// a name lives on `StaffMember`, and a copy pinned to the block is a copy to keep in step.
    /// Nil overall when none of the three resolves — a block with no courts, no kids and nobody on
    /// it draws no line at all rather than an empty one.
    func metaLine(in camp: Camp?) -> String? {
        guard let camp else { return nil }
        var parts: [String] = []
        if let courts = block.courtSummary(in: camp) { parts.append(courts) }
        let players = playersHere(in: camp)
        if players > 0 { parts.append("\(players) player\(players == 1 ? "" : "s")") }
        let names = block.coachNames(in: camp.staff)
        if !names.isEmpty { parts.append(names.joined(separator: ", ")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Kids on this block's courts today. The venue's own when the block names no courts, which is
    /// what a `.regular` block means — everybody, wherever they are standing.
    ///
    /// The same fallback `BlockDetailView.openAttendance` (`BlockDetailView.swift:272-288`) applies
    /// to the register itself, and for the same reason: a lunch happens on no court in particular,
    /// and the venue is who is there. Written as one rule here so the count on the card and the
    /// roll behind the button cannot come to be about different children.
    func playersHere(in camp: Camp) -> Int {
        courtIDs(in: camp)
            .flatMap { camp.players(inGroup: $0) }
            .count { !camp.isAway($0.id, on: block.day) }
    }

    /// Which courts the block's register covers — its own where it says, the venue's where it
    /// does not. See `playersHere(in:)`.
    func courtIDs(in camp: Camp) -> [Group.ID] {
        block.courtIDs.isEmpty ? camp.groups(in: block.venueID).map(\.id) : block.courtIDs
    }
}

// MARK: - Resolving one

extension OverviewNow {

    /// The block the reader is in the middle of, with its coaches looked up.
    ///
    /// `at:` is passed in rather than read off the clock here, so the caller decides what "now"
    /// means — `AppStore.timeOfDay` in the app, a fixed time in a test. `ScheduleBlock.running`
    /// makes the same choice for the same reason, and this is the only place the two are composed.
    ///
    /// **`onCourt:` is who is asking.** A venue can now be running two blocks at once — a warm-up
    /// on Court 1 beside free play on Courts 2–4 — so "the block" is a question with a reader in
    /// it, and `RunningBlockCard` sits at the top of a screen that already knows whose court it is
    /// drawing. A coach gets what is on their court and nothing else: nil where they are between
    /// blocks, even while the rest of the venue is mid-session. Telling somebody on Court 3 that
    /// the Court 1 warm-up is on is telling them to go and run it.
    ///
    /// Nil court is the admin, who is standing on all of them, and gets the first running block in
    /// the order `running(in:at:)` fixed — the earliest to have started. That is a genuine choice
    /// and worth naming as one: an admin looking at a venue running two blocks sees one card. The
    /// alternative is a card that stacks them, which is a design `8i` does not draw and a decision
    /// for whoever draws it; picking the earliest at least means the card does not change under
    /// them when a second block starts. `BlockRules.overlap(with:in:)` reports the earliest of its
    /// clashes for the same want of a better reason, and it is better than array order, which is
    /// what the venue-wide rule this replaced was quietly using.
    static func resolve(
        in blocks: [ScheduleBlock], at time: TimeOfDay, staff: [StaffMember],
        onCourt court: Group.ID? = nil
    ) -> OverviewNow? {
        // One branch runs, so the day is walked once either way — and the court case goes through
        // the model's own `running(on:in:at:)` rather than re-spelling "which of these claims my
        // court" here, which is the copy this whole change exists to avoid making.
        let found = if let court {
            ScheduleBlock.running(on: court, in: blocks, at: time)
        } else {
            ScheduleBlock.running(in: blocks, at: time).first
        }
        guard let block = found else { return nil }

        // Indexed rather than searched per id: `coachIDs` is short but `staff` need not be, and
        // this runs on every tick of the clock. `uniquingKeysWith` because a duplicate id in
        // `staff` is a graph that is already wrong, and picking the first is what
        // `coachLine(in:)` already does with the same table.
        let byID = Dictionary(staff.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return OverviewNow(
            block: block,
            coaches: block.coachIDs.compactMap { byID[$0] },
            at: time,
            next: following(time, in: blocks, onCourt: court)
        )
    }

    /// What starts next, for the same reader — 4a's `Next · Water & regroup · 10:30`.
    ///
    /// **Measured from the clock, not from the running block's end**, and that is the whole of the
    /// rule. An end is not something every block has: `endsAt` is nullable by design, and an
    /// open-ended block is closed by whatever starts next in the same space
    /// (`ScheduleBlock.hasFinished`). A start is something every block has. Strictly after `time`,
    /// so a block that begins on this very minute is *running* — which is exactly where
    /// `running(in:at:)` draws the same line — and cannot be announced as the next thing while its
    /// own card is on screen.
    ///
    /// Ordered on the start time with the id breaking ties, which is `running(in:at:)`'s own
    /// comparator: two blocks beginning at the same minute must not swap places between two draws
    /// of one screen.
    ///
    /// Scoped by `BlockRules.claims` where the reader is standing on a court, so a coach's footer
    /// names what is next on *their* court rather than the next thing anywhere in the venue. An
    /// admin has no court and gets the venue's, which is the same asymmetry `resolve` above applies
    /// to the running block — and it is the answer to a question the design leaves open, a venue
    /// running two blocks at once having two candidates for "next".
    private static func following(
        _ time: TimeOfDay, in blocks: [ScheduleBlock], onCourt court: Group.ID?
    ) -> ScheduleBlock? {
        blocks
            .filter { $0.startsAt > time }
            .filter { block in court.map { BlockRules.claims(block, court: $0) } ?? true }
            .min { ($0.startsAt, $0.id.uuidString) < ($1.startsAt, $1.id.uuidString) }
    }
}

// MARK: - Which courts the block is about

extension OverviewNow {

    /// `courts`, with the ones this block names moved to the front.
    ///
    /// A **sort, deliberately not a filter.** A block that names Courts 1–3 is saying where the
    /// warm-up happens; it is not saying that Court 4 has emptied. Court 4 still has kids on it,
    /// still has a coach, and is still the answer to "where is my child" — hiding it would make
    /// Overview lie about the venue to make one card look tidier.
    ///
    /// Stable within each half, so the courts keep the rank order `today_courts` returned them in.
    /// Written as two passes rather than `sorted(by:)` because `sorted` is not documented stable —
    /// a court's rank is what the numbers on the cards mean, and shuffling two courts that tie on
    /// "named by the block" would renumber the screen for no reason.
    ///
    /// `block.courtIDs` is empty on a `.regular` block and on an `.assigned` one nobody has picked
    /// courts for yet — which is every block today, the editor that writes the column being still
    /// unwired. That case is the identity, which is what makes this safe to call unconditionally.
    func preferring(_ courts: [CourtCard]) -> [CourtCard] {
        guard !block.courtIDs.isEmpty else { return courts }
        let named = Set(block.courtIDs)
        return courts.filter { named.contains($0.id) } + courts.filter { !named.contains($0.id) }
    }
}
