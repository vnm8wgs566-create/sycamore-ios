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
    /// That resolve is now written three times — here, in `coachLine(in:)`, and in
    /// `BlockAssigneeList.coaches(on:in:)` — and the rule about departed coaches four times, because
    /// it has nowhere to be stated once. It belongs on the model as
    /// `ScheduleBlock.coaches(in: [StaffMember]) -> [StaffMember]`, with `coachLine` composed on top
    /// of it and this reading `block.coaches(in: staff)`. `Models/` is another unit's file.
    let coaches: [StaffMember]

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
        guard let ends = block.endsAt else { return "from \(block.startsAt.formatted)" }
        return "until \(ends.formatted)"
    }

    /// "Skills rotation · until 10:30" — the line under the screen's title.
    var headerLine: String { "\(title) · \(timeLabel)" }
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

        return OverviewNow(block: block, coaches: block.coachIDs.compactMap { byID[$0] })
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
