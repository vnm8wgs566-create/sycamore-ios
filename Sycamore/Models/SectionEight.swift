//
//  SectionEight.swift
//  Sycamore
//
//  The three shapes section 8 introduces that the app had no model for: a court on Overview
//  (`8i`/`8j`), a block on Schedule (`8k`/`8l`) and an item in the Inbox (`8r`).
//
//  Separate from `Models.swift` deliberately. That file is already 21 types and is the one place
//  every feature touches; adding three more to it makes it the merge conflict for every screen
//  built from here on.
//
//  Each maps onto exactly one relation in Postgres — `today_courts`, `schedule_blocks`,
//  `inbox_items` — and the field names are the column names so the decoding stays boring.
//
//  ── One reach upwards, deliberately ──────────────────────────────────────────────────────────
//
//  `ScheduleBlock.running(in:at:)` calls `BlockRules` (`Features/Schedule/BlockEditorDraft.swift`),
//  which is a file in a feature. That is the wrong way round for `Models/` and it is the lesser of
//  the two wrongs: the alternative is a second copy of "do these two blocks contend for the same
//  courts", and the whole reason `running` lives in the model is that three screens each having
//  their own answer to a question is how the tabs came to disagree in the first place.
//
//  The repair is the one PR #53 wrote down as a follow-up when it put the rule where it did:
//  `BlockRules` holds four mirrors of SQL CHECKs and one rule that is not a mirror of anything,
//  and the clash half belongs here beside `running` rather than beside the editor's validation.
//  It is a move, not a rewrite, and it wants its own change — `Features/Schedule/**` is a good
//  deal of surface to disturb for a call that compiles perfectly well today.
//

import Foundation

// MARK: - Overview

/// One court on `8i` / `8j`: what is happening on it, who has it, and who is there.
///
/// Backed by the `today_courts` view rather than assembled client-side. The count of kids
/// present is a correlated subquery over `attendance`, and doing that in Swift would mean
/// fetching every attendance row for the day to count a handful of them.
struct CourtCard: Identifiable, Hashable, Sendable {
    var id: Group.ID
    var venueID: Venue.ID
    /// "Group 1" — the design writes this as the court label when there is one.
    var groupName: String
    /// "Court 1". Nil for a group that has not been given a court yet.
    var courtLabel: String?
    var rankOrder: Int
    var coachID: StaffMember.ID?
    /// "Nass". Nil reads as unassigned, which the design draws as "Needs a coach".
    var coachName: String?
    var playersHere: Int
    /// "Drills", "Match play", "Skills rotation", "Net down" — what is happening on *this* court.
    ///
    /// `groups.activity` when the court has one, and the running block's title when it has not.
    /// Both, in that order, because `8i` draws a header reading "Skills rotation · until 10:30"
    /// over four cards of which only one agrees with it: an activity that could only come from the
    /// schedule can title exactly one of those cards correctly. `CourtScreen` is where the two are
    /// composed; a repository supplies the second.
    ///
    /// **The block half is `ScheduleBlock.running(on:in:at:)` — per court, and it was not.** Both
    /// repositories resolved one running block for the venue and stamped its title onto every card
    /// in the list, which is the header's sentence written four times over: the exact reading the
    /// paragraph above says the field exists to avoid. A warm-up on Court 1 has nothing to say
    /// about Courts 2–4, and titling them with it is the card claiming a session that court is not
    /// in.
    ///
    /// `today_courts` (`20260805141707:161`) carries the same assumption by omission — it selects
    /// the coach, the label, the rank and the head-count, and no activity at all, so anything
    /// reading it has to fetch the schedule separately and is left to decide for itself how widely
    /// the answer applies. That is exactly where the venue-wide stamp came from. The view is
    /// granted (`20260805152045:30`) but unused: `SupabaseRepository.courts(forVenue:campID:)`
    /// assembles the card from `groups`, `coaches`, `players` and `attendance` instead, and says
    /// why. **No migration here.** Adding a column to a view nothing reads would be schema written
    /// against a hypothesis; the note belongs with whoever moves the app back onto it, and this is
    /// it — a court's activity is a per-court question, and a single-activity view cannot answer
    /// it whatever the grants say.
    var activity: String?
    var status: CourtStatus

    // `subtitle` used to live here — "Court 1 – 8 players", or "Court 4 – Tom is on it" when
    // closed. It went with the card that read it. `8i` draws the head-count as a measured pair
    // (`6 of 8`, and a `1 spot` pill) rather than as prose, so the number is `CourtCapacity`'s
    // now and the closure reason is the `Closed` badge's; a string that glued the two together
    // could be neither. Its last reader was `CourtCard.overviewSubtitle`, removed with it.
}

/// The design draws two: an open court, and one taken out of play with a reason ("Net down",
/// "Tom is on it"). A closed court keeps its card — it is information, not an absence.
enum CourtStatus: Hashable, Sendable {
    case open
    case closed(reason: String)

    var badge: String {
        switch self {
        case .open: "Open"
        case .closed: "Closed"
        }
    }

    /// Why the court is out of play, or nil while it is in play.
    ///
    /// The one place `.closed` is unwrapped, so "is it closed" and "why" are the same question
    /// asked two ways. Three screens had written the `if case .closed` out longhand and two of
    /// them could not reach `CourtCard.isClosed`, which is where it used to live — a predicate
    /// about a status belongs on the status.
    var closureReason: String? {
        if case .closed(let reason) = self { reason } else { nil }
    }

    var isClosed: Bool { closureReason != nil }
}

// MARK: - Schedule

/// Which coaches are running one court of one block.
///
/// `ScheduleBlock.coachIDs` (`:172`) is the same fact asked of the whole block — who is running
/// it at all — and the two are not interchangeable. A `.regular` block names no courts
/// (`ScheduleBlockKind`, `:517`), so its coaches cannot be per-court and must stay on the block;
/// an `.assigned` block that says "Nass on Court 1, Alina on Court 2" cannot say it in one flat
/// list at all, because the flat list has thrown away which is which. So this is an addition to
/// `coachIDs`, not a replacement for it, and `coachIDs(onCourt:)` (`:288`) is the one place that
/// decides which of the two answers a given court.
///
/// **Keyed by the court, not by the coach**, because that is the question both readers have. 5b
/// draws a row per court and asks who is on it; 4d opens from one of those rows under the title
/// "Who takes Court 2?". A `[StaffMember.ID: [Group.ID]]` holds the identical information and
/// answers the mirror question, which would leave both screens inverting it on every redraw.
///
/// `coachIDs` is an array rather than a `Set`, for the reason `BlockEditorDraft.block()` gives
/// about its own two lists: the wire is ordered rows, `ScheduleBlock: Equatable` reports a
/// reordering as a change, and a stable order is what keeps a re-read from looking like an edit.
/// Nothing here dedupes or refuses a second name — two coaches on one court is the ten-minute
/// handover `BlockRules.overlaps(_:_:)` (`BlockEditorDraft.swift:151`) argues at length that
/// the app must be able to write down.
///
/// `Codable` because `ScheduleBlock` is (`:146`) and synthesis is all-or-nothing: a stored
/// property whose element type is not `Codable` takes the conformance off the block with it.
/// `Group.ID` and `StaffMember.ID` are both `UUID`, so the conformance costs nothing.
struct BlockCourtStaffing: Hashable, Sendable, Codable, Identifiable {
    let courtID: Group.ID
    var coachIDs: [StaffMember.ID]

    var id: Group.ID { courtID }
}

/// One card on `8k`. The camp's morning in time order.
struct ScheduleBlock: Identifiable, Hashable, Sendable, Codable {
    var id: UUID = UUID()
    var venueID: Venue.ID
    var day: Weekday
    var startsAt: TimeOfDay
    var endsAt: TimeOfDay?
    /// "Skills rotation", "Water & regroup", "Lunch".
    var title: String
    /// The grey second line — "Shade lawn", "15 min", "Round two". One field rather than parsed
    /// parts because the design composes it differently on every row.
    ///
    /// It used to be where the courts lived too: the design writes "Courts 1–3 · 22 players" on
    /// one of its cards, and this comment used to cite that as the reason the field could only
    /// ever be free text. `courtIDs` is that half of the sentence now, in a column that can be
    /// read back and acted on — so what is left here is prose, and a block that says "Courts 1–3"
    /// in it is describing itself rather than recording anything.
    var detail: String?
    var status: ScheduleBlockStatus = .planned
    /// "1 note · shade tent is up". Notes hang off a block; the count is what the card shows.
    var notes: [BlockNote] = []
    /// Who is running this block, as opposed to who happens to be at the venue.
    ///
    /// Declared last deliberately. `ScheduleBlock`'s memberwise initialiser is called with
    /// labels but in declaration order in three places — `SupabaseDTOs.swift`,
    /// `ScheduleSampleDay.swift` and `SectionEightRepository.swift` — and a stored property
    /// added above `notes` would have broken all three at once.
    var coachIDs: [StaffMember.ID] = []

    /// What kind of thing this block is — and therefore what the editor asks about it.
    ///
    /// Appended after `coachIDs` for the reason stated directly above: the memberwise initialiser
    /// is called positionally in three files, so the tail is the only safe place to grow.
    ///
    /// Deliberately **not** folded into `status`, which is `planned | done | needs_coach` and
    /// answers a different question. A block's kind is what it *is*; its status is where it has
    /// got to. Overloading one on the other would make "a done warm-up" unsayable.
    var kind: ScheduleBlockKind = .regular
    /// The courts this block runs on, when it is one that says. Empty on a `.regular` block, and
    /// empty on an `.assigned` one nobody has chosen courts for yet.
    var courtIDs: [Group.ID] = []

    /// Who is on which court — the per-court half of `coachIDs`, for the block that says.
    ///
    /// Empty on a `.regular` block, which names no courts to staff, and empty on an `.assigned`
    /// one nobody has staffed court by court yet. Both of those read back through
    /// `coachIDs(onCourt:)` as "whoever is on the block", which is the honest answer: a block
    /// staffed as a whole is staffed on every court it claims.
    ///
    /// Appended after `courtIDs` for the reason stated twice above (`:137-141`, `:144-146`), and
    /// the claim was checked rather than taken on trust before this landed. The memberwise
    /// initialiser is called with labels but in full declaration order at `SupabaseDTOs.swift:414`
    /// — all twelve members, `id` through `courtIDs` — and with a labelled prefix of that order in
    /// `ScheduleSampleDay.swift:34` and `SectionEightRepository.swift:527`. A property inserted
    /// anywhere but the tail would have broken the first of those on the spot; the tail plus a
    /// default breaks none of the three, and none of them needed editing.
    var staffing: [BlockCourtStaffing] = []

    /// "8:30", and "8:30 – 9:00" once there is an end.
    var timeLabel: String {
        guard let endsAt else { return startsAt.clockLabel }
        return "\(startsAt.clockLabel) – \(endsAt.clockLabel)"
    }

    /// The same sentence without the meridiems: `10:45 – 12:15`, and `10:45` on a block with no
    /// stated end.
    ///
    /// A second speller beside `timeLabel` rather than a flag on it, because the two are read in
    /// different places and both are design literals. `timeLabel` writes `10:45am – 12:15pm` and is
    /// what a card carries; `4d`'s eyebrow and `5d`'s header subtitle drop the meridiems
    /// (`design/rebuild/section-t4.html:221`, `section-t5.html:194`) because they sit under a title
    /// that has already said which morning this is. `TimeOfDay.shortLabel` exists for exactly that
    /// and states the assumption it rests on: a camp day does not wrap round midnight, so a
    /// twelve-hour clock with no meridiem is unambiguous.
    ///
    /// **The two frames disagree about the dash and one of them had to lose.** `4d` writes
    /// `10:45–12:00` tight and `5d` writes `10:45 – 12:15` spaced, in header lines of identical
    /// construction. Spaced wins, because the line above already joins a range that way and the
    /// short form should be the long form minus the meridiems rather than a second range spelling.
    ///
    /// Declared here, beside the label it is the short form of. It was written in
    /// `BlockCourtStaffingSheet.swift` with a comment saying this file was where it belonged and
    /// that the file was not that unit's to edit; it has two callers in two files
    /// (`BlockCourtStaffingSheet.swift:153`, `BlockDetailView.swift:203`), which is one more reason
    /// than a lodger needs.
    var shortTimeLabel: String {
        guard let endsAt else { return startsAt.shortLabel }
        return "\(startsAt.shortLabel) – \(endsAt.shortLabel)"
    }

    var noteSummary: String? {
        guard let first = notes.first else { return nil }
        return notes.count == 1 ? "1 note · \(first.text)" : "\(notes.count) notes"
    }

    /// Who is running this block, in words: "Nass", "Nass & Alina", "Nass +2". Nil when nobody
    /// is on it, which the design draws as "Needs a coach" rather than as an empty line.
    ///
    /// Takes the roster instead of storing the names, and that is the decision worth recording.
    /// A name lives on `StaffMember`; a copy pinned to every block a person runs is a second copy
    /// to keep in step, and renaming a coach in Setup would leave yesterday's spelling on the
    /// timetable. `CourtCard.coachName` is the same field stored, for a reason that does not
    /// apply here — that card is assembled by the repository from `coaches` in the same read, so
    /// there is no later moment at which it could go stale. `StaffMember.assignment` is the
    /// opposite case again and says so out loud: denormalised on purpose, "so a court chip draws
    /// without walking the graph".
    ///
    /// `compactMap`, never a force-resolve. "Remove from camp" deactivates rather than deletes —
    /// `SupabaseRepository.removeStaff` sets `active = false` — and every camp read filters
    /// `.isTrue("active")`, so a departed coach keeps their `schedule_block_coaches` row and their
    /// id will not be in `staff`. The foreign key's cascade cannot clean that up either, because
    /// nothing in the app hard-deletes a coach. An unresolved id is therefore ordinary, not a bug,
    /// and a block whose only coach has left reads "Needs a coach" — which is true.
    func coachLine(in staff: [StaffMember]) -> String? {
        let names = coachNames(in: staff)
        return switch names.count {
        case 0: nil
        case 1: names[0]
        case 2: "\(names[0]) & \(names[1])"
        default: "\(names[0]) +\(names.count - 1)"
        }
    }

    /// The same coaches, resolved and in order, with no sentence built round them —
    /// `["Nass", "Alina", "Tom"]`, which `4a`'s meta line joins with `", "`.
    ///
    /// A second speller beside `coachLine(in:)` rather than a style flag on it, and the two are
    /// stacked rather than parallel: `coachLine` is written in terms of this, so the resolve — the
    /// dictionary, the `compactMap`, and the whole argument at `:214-228` about why a departed
    /// coach's id is ordinary rather than a bug — exists once and cannot come to differ between
    /// them. Only the tail differs, and the tail is the entire reason there are two.
    ///
    /// `coachLine` stops at two names and counts the rest because it writes into a narrow card.
    /// `4a`'s line is the full width of the screen under a running block and wants every name,
    /// which is the same argument `courtLine(in:)` makes at `:337-340` for not abbreviating a
    /// court list: knowing three coaches are on without knowing *which* three is no use to
    /// somebody looking for one of them.
    ///
    /// Returns the array rather than the joined string so the caller owns the separator. `4a`
    /// wants `", "`; a `VoiceOver` label for the same three names wants `" and "` before the last,
    /// and a component that has to be told which is a component that should have been handed the
    /// names.
    func coachNames(in staff: [StaffMember]) -> [String] {
        let byID = Dictionary(staff.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return coachIDs.compactMap { byID[$0] }
    }

    /// Who is running one court of this block: the court's own staffing when it has been given
    /// any, and otherwise everybody on the block.
    ///
    /// The fallback is the whole point, and it is not a convenience. Every block written before
    /// per-court staffing existed — and every `.regular` block written after it — carries its
    /// coaches on `coachIDs` and nothing in `staffing`, so a reader that consulted `staffing`
    /// alone would report an empty court for the entire back catalogue and for every block that
    /// is by definition venue-wide. A block staffed as a whole is staffed on each court it claims;
    /// that is what staffing it as a whole *means*.
    ///
    /// **A present entry wins even when it is empty**, and that asymmetry is deliberate. Nobody
    /// writes `BlockCourtStaffing(courtID: c, coachIDs: [])` by accident: it is the record of
    /// somebody having opened `4d` for that court and left without picking, which is exactly the
    /// state `5d`'s head row draws as "Needs a coach". Falling back there would erase the one
    /// distinction the type exists to carry — *not staffed per court* and *staffed with nobody*
    /// are different facts, and only the second is somebody's problem this morning.
    ///
    /// Not filtered against `courtIDs`. Asked about a court this block does not claim, the answer
    /// is whoever is on the block, which is the same answer `BlockRules.claims(_:court:)` gives
    /// for a block that names no courts at all — an unfinished block claims the venue, and so do
    /// its coaches. A caller that wants "only the courts this block runs on" already has
    /// `courtIDs` to iterate.
    func coachIDs(onCourt courtID: Group.ID) -> [StaffMember.ID] {
        if let court = staffing.first(where: { $0.courtID == courtID }) { return court.coachIDs }
        return self.coachIDs
    }

    /// Where this block runs, counted rather than named: "Court 1", "Courts 1–3",
    /// "Courts 1, 2 and 5". Nil on a block that names no courts.
    ///
    /// A third speller beside `courtLine(in:)` (`:341`) and it takes the camp rather than a
    /// resolved list, which is the difference that matters: `courtLine` writes labels
    /// ("Court 1 & Court 2") because its caller has already resolved them for its own reasons,
    /// and `4a` has a `Camp` and a block and nothing in between. Resolving through
    /// `Camp.group(_:)` here rather than making the caller do it keeps the one screen that draws
    /// this from having to know that a court is a `Group`.
    ///
    /// **The run collapses, and it may.** `CampDays.summaryLine` (`CampDays+Rules.swift:55-62`)
    /// refuses exactly this and says why: the week is Monday-first, so `[.sun, .mon, .tue]` is
    /// contiguous and has no contiguous spelling, and a rule with a corner that reads as a bug is
    /// worse than a list. Court numbers are 1…N inside a venue and do not wrap, so the corner does
    /// not exist here — `1–3` is three courts and never five.
    ///
    /// Two courts are listed rather than ranged. "Courts 1–2" saves one character over "Courts 1
    /// and 2" and reads as a range somebody might have to work out; three is where a range starts
    /// paying for itself. `and` rather than `courtLine`'s `&` because this line already carries a
    /// `·` and a `&` beside it is two joining marks doing one job.
    ///
    /// The noun follows the sport — `Sport.groupNoun` (`Models.swift:402`) — so a swim camp reads
    /// "Lanes 1–3" rather than being told it has courts. Unresolvable ids drop out rather than
    /// standing in as a gap: a court deleted out from under a block leaves the block describing
    /// the courts that are still there, which is true, and a block whose courts have all gone
    /// reads as nil, which is the absence every screen already draws.
    func courtSummary(in camp: Camp) -> String? {
        let numbers = Set(courtIDs.compactMap { camp.group($0)?.number }).sorted()
        guard let first = numbers.first, let last = numbers.last else { return nil }
        let noun = camp.sport.groupNoun
        if numbers.count == 1 { return "\(noun) \(first)" }
        if numbers.count > 2, last - first == numbers.count - 1 { return "\(noun)s \(first)–\(last)" }
        let listed = numbers.dropLast().map(String.init).joined(separator: ", ")
        return "\(noun)s \(listed) and \(last)"
    }

    /// Where this block runs, in words: "Court 1", "Court 1 & Court 2", "Court 1, Court 2 and
    /// Court 4". Nil on a block that names no courts, which every screen draws as an absence
    /// rather than as an empty line.
    ///
    /// Beside `coachLine(in:)` on purpose, and takes its courts the same way round: resolved by
    /// the caller, never stored, so renaming a court in Setup cannot leave yesterday's spelling on
    /// the timetable. `BlockCourtPicker.courts(on:in:)` is what resolves them.
    ///
    /// The one difference is the tail. `coachLine` stops at two and counts the rest ("Nass +2")
    /// because a name is long and a card is narrow; a court label is "Court 4", so they all fit —
    /// and a reader wants all of them. Knowing that three courts are running without knowing
    /// *which* three is no use to somebody carrying a ball cart.
    func courtLine(in courts: [Group]) -> String? {
        let labels = courts.map(\.label)
        guard let last = labels.last else { return nil }
        return switch labels.count {
        case 1: last
        case 2: "\(labels[0]) & \(last)"
        default: "\(labels.dropLast().joined(separator: ", ")) and \(last)"
        }
    }
}

/// A line pinned to a block — "shade tent is up", "two nut allergies".
///
/// Carries its own id rather than being a bare `String`, and that is the point of the type. A
/// note has to be deletable, and an index into a list re-read from the server is a race: the
/// list can change between the tap and the write. `BlockNotesCard` had already hit the same
/// edge from the other side and keyed its `ForEach` on indices because "two coaches can write
/// the same line, and identical strings would collapse into one row" — an id settles both.
///
/// The id is an `InboxItem.ID` because that is what a block note *is*. There is no notes table:
/// a note is a row of `inbox_items` with `kind = 'note'` carrying `schedule_block_id`, which is
/// the design the seed migration states and the column that already exists to serve it.
struct BlockNote: Identifiable, Hashable, Sendable, Codable {
    var id: InboxItem.ID
    var text: String
    /// Nil when the author has left the camp — `removeStaff` deactivates rather than deletes,
    /// so the row survives its author.
    var authorName: String?
    var at: Date
}

extension ScheduleBlock {

    /// Every block the camp is in the middle of, earliest first.
    ///
    /// One rule, in the model, because there were three — Overview asked the clock, the Postgres
    /// repository asked the clock again in its own words, and Schedule asked block *status*
    /// ("first one not marked done"). On any morning where a coach forgot to mark a block done,
    /// the tabs named different blocks as current and neither was wrong by its own definition.
    ///
    /// It is a fact about a list of blocks, not a drawing decision, which is why it lives here
    /// rather than in whichever screen needed it first.
    ///
    /// ── WHY IT IS A LIST ──────────────────────────────────────────────────────────────────────
    ///
    /// This returned one block, and said so: *the last one that has started, unless it has ended*.
    /// That sentence was true while a venue could only be doing one thing at a time, and
    /// `ScheduleBlockKind.assigned` with `courtIDs` (`SectionEight.swift:143-154`) is exactly the
    /// pair that stopped it being true. "Warm-up 9:00–9:15 on Court 1" beside "Free play
    /// 9:00–10:00 on Courts 2–4" is a morning the schedule is now meant to be able to write down —
    /// `BlockRules.sharesSpace(_:_:)` is where that is stated — and no single block is the answer
    /// to what is running at ten past nine.
    ///
    /// Asked for one anyway, it did not merely pick a side; it could answer **nothing at all**.
    /// The two blocks tie on `startsAt`, `max(by:)` keeps whichever the array holds first, and if
    /// that was the short one the "unless it has ended" then threw the pair away — so at 9:20 the
    /// app reported an empty morning while twenty-two children were on Courts 2–4. Which of the
    /// two won depended on array order, and `scheduleBlocks(forVenue:day:campID:)` orders by
    /// `starts_at` and nothing else. Overview's `RunningBlockCard` vanished and `8k`'s "On now"
    /// went out mid-session, on some days and not others.
    ///
    /// ── WHAT ENDS A BLOCK ─────────────────────────────────────────────────────────────────────
    ///
    /// Three clauses now, and the middle one is where the old rule hid an assumption:
    ///
    ///   - it has **started** — `startsAt <= time`;
    ///   - it has not **finished** — see `hasFinished(_:by:amongst:)`;
    ///   - and that is all. There is no "latest one wins" left, because that was never a fact
    ///     about a block. It was a proxy for *blocks do not overlap*, which was true only while
    ///     the app refused an overlap — and PR #53 is the change that stopped refusing them.
    ///
    /// The proxy is not merely redundant now, it is wrong: "Warm-up 9:00–10:00" interrupted by
    /// "Handover 9:30–9:40" on the same court left `max(by:)` holding the handover, which by 9:45
    /// has ended — and the warm-up, which has twenty minutes left on it, was reported as over.
    /// Same bug, different arrangement. A stated end is now the only thing that ends a block that
    /// stated one.
    ///
    /// ── ORDER ─────────────────────────────────────────────────────────────────────────────────
    ///
    /// Sorted, because the input is not. The caller's array order was the deciding vote in the bug
    /// above and must not be the deciding vote in anything again — so this sorts by start and
    /// breaks the tie on the id, the same arbitrary-but-fixed tie-break `BlockEditorDraft.block()`
    /// uses on `coachIDs` and `courtIDs`. Two blocks that genuinely start at the same minute on the
    /// same court are a clash the schedule flags (`BlockRules.overlap(with:in:)`); what matters
    /// here is only that they do not swap places between one read and the next.
    ///
    /// The tie-break is `UUID.precedes(_:)` (`Models.swift:28-65`) and not `id.uuidString <
    /// id.uuidString`, which is what it was: identical order, and no pair of 36-character `String`s
    /// rendered per comparison. `CoachAvailability.map` (`CoachAvailability.swift:235`) runs this
    /// sort once per keystroke in the block editor's title field, which is what made the
    /// difference worth spending a method on.
    static func running(in blocks: [ScheduleBlock], at time: TimeOfDay) -> [ScheduleBlock] {
        blocks
            .filter { $0.startsAt <= time && !hasFinished($0, by: time, amongst: blocks) }
            .sorted {
                $0.startsAt == $1.startsAt
                    ? $0.id.precedes($1.id)
                    : $0.startsAt < $1.startsAt
            }
    }

    /// What is running on one court: the block the person standing on it is in the middle of.
    ///
    /// The question every screen scoped to a court actually has — Overview's card is about *your*
    /// court, and `CourtCard.activity` is a column on one court rather than a banner over the
    /// venue. Nil is an ordinary answer and the one the old venue-wide rule could not give: a
    /// coach on Court 3 during a warm-up on Courts 1–2 is between blocks, and telling them the
    /// warm-up is on would be telling them to go and run it.
    ///
    /// **One court can have more than one block on it, and this returns the earliest-started.**
    /// Two blocks that both claim this court share space by definition, so an open-ended one is
    /// finished by whichever starts next — but a block that *stated* an end keeps it, so "Warm-up
    /// 9:00–10:00" and "Handover 9:30–9:40" on the same court are both genuinely running at 9:35.
    /// That is a clash, and the schedule flags it as one (`BlockRules.overlap(with:in:)`); it is
    /// not this rule's job to pick a winner and pretend there was never a question.
    ///
    /// Earliest rather than most-recently-started, which is the tempting alternative — the
    /// handover is arguably the more specific answer. It is a card that does not change under
    /// somebody: the warm-up is what a coach was told is on, and swapping it for a ten-minute
    /// handover and back again is the screen flickering through a conflict rather than reporting
    /// one. It also keeps this the same choice `OverviewNow.resolve` makes for an admin and
    /// `BlockRules.overlap` makes for a clash, so the three cannot name different blocks.
    static func running(
        on court: CourtGroup.ID, in blocks: [ScheduleBlock], at time: TimeOfDay
    ) -> ScheduleBlock? {
        running(in: blocks, at: time).first { BlockRules.claims($0, court: court) }
    }

    /// Whether `block` is behind us by `time`.
    ///
    /// **A stated end is an end.** A block that says it runs until 10:00 is running at 9:45,
    /// whatever else the morning has started and finished in the meantime.
    ///
    /// **An unstated end is implied by the next thing in the same space.** `ends_at` is nullable
    /// by design — `20260805074039:27-28` records that the design's 8:30 "Drop-off · done" has no
    /// stated end and "inventing one would put a time on screen that nobody entered" — so
    /// something has to close it, and the honest candidate is whatever starts next where it was
    /// standing. Read any other way, 8:30 "Drop-off" is the activity on every court all afternoon;
    /// that exact sentence is what `SupabaseRepository+SectionEight.swift` warned about when it
    /// kept its own copy of this rule, and it is the one thing the old spelling got right.
    ///
    /// The superseding block need only have **started**, not still be running. Once the nine
    /// o'clock huddle has begun, the drop-off is over — and stays over after the huddle ends,
    /// rather than springing back to life because nothing newer has taken the venue. An
    /// open-ended block that resumed at the end of every later block is the "all afternoon" bug
    /// again, arriving in instalments.
    ///
    /// `sharesSpace` and not a court comparison written out here: the four cases it settles —
    /// two regulars, one of each, assigned blocks that share a court, assigned blocks that do not
    /// — are the same four cases whether the question is *is this a clash* or *is this over*, and
    /// they belong in one place. It is also what makes the venue and day guards apply: a block on
    /// Tuesday cannot end one on Wednesday, however the caller assembled the list.
    private static func hasFinished(
        _ block: ScheduleBlock, by time: TimeOfDay, amongst day: [ScheduleBlock]
    ) -> Bool {
        if let ends = block.endsAt { return ends <= time }
        // Two integer compares before the set-building one, the ordering
        // `BlockRules.overlaps(_:_:)` states and for the same reason: on a day that is simply in
        // order — which is most days — no set is ever built.
        return day.contains {
            $0.startsAt > block.startsAt && $0.startsAt <= time && BlockRules.sharesSpace($0, block)
        }
    }
}

/// What a block is, as opposed to where it has got to.
///
/// Two kinds, because the design asks two different sets of questions. A regular block is a title,
/// a time and whatever notes hang off it — a lunch, a parents' briefing. An assigned block also
/// says *where* it happens and *who is on it*: "warm-up, one court, everybody", which is a
/// sentence the schedule could not previously write down. Before this, the courts a block used
/// lived in `detail` — one free-text line reading "Courts 1–3 · 22 players" that nothing could
/// read back.
/// ── DECLARATION ORDER IS THE PICKER'S ORDER ───────────────────────────────────────────────────
///
/// `.assigned` first, which is a reversal. `allCases` is synthesised in declaration order and
/// `BlockEditorSheet.swift:287` draws the picker straight off it, so this is the only place the
/// order can be stated — and 5a puts the courts option on top because that is the block somebody
/// opens the editor to write. A whole-camp lunch is the easy one and does not need the first slot.
///
/// **Safe on the wire.** The raw values are the case names — `"regular"`, `"assigned"` — spelled
/// by the compiler from the identifiers rather than assigned positionally, so reordering the
/// cases moves nothing in `schedule_blocks.kind` and no stored row changes meaning. The default
/// on `ScheduleBlock.kind` (`:182`) stays `.regular` for the same reason it always was: a block
/// that never said is a block that just happens.
enum ScheduleBlockKind: String, Hashable, Sendable, Codable, CaseIterable {
    /// A block that names its courts and the coaches on them.
    case assigned
    /// A block that just happens. The shape everything on the schedule had until now.
    case regular

    /// The title of each option in the editor's picker, under the heading "Type".
    ///
    /// Named for what the block *does* rather than for what it is made of. "Courts & coaches"
    /// and "Regular event" were the field names read out loud — one listed its own two columns,
    /// the other was a category with no content — and neither told somebody at seven in the
    /// morning which one to tap. "On courts" and "Whole camp" are the two shapes a camp morning
    /// actually comes in, and they are the words a coach would use for them.
    var displayName: String {
        switch self {
        case .assigned: "On courts"
        case .regular: "Whole camp"
        }
    }

    /// The one line under each option in the editor's picker.
    var detail: String {
        switch self {
        case .assigned: "Kids and coaches are placed court by court."
        case .regular: "Everyone together, no courts — lunch, water, regroup."
        }
    }
}

enum ScheduleBlockStatus: String, Hashable, Sendable, Codable, CaseIterable {
    /// The ordinary state.
    case planned
    /// "Drop-off · done" — behind us.
    case done
    /// "Needs a coach" — the design draws this one in the warning amber, because it is the only
    /// row on the screen that is somebody's problem right now.
    case needsCoach = "needs_coach"
}

// MARK: - Inbox

/// One row on `8r`.
struct InboxItem: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var venueID: Venue.ID
    var kind: InboxKind
    /// "Austin Zheng → Court 2", "Nass pinned a note".
    var title: String
    /// "Nass asked · 8 min ago", "Skills rotation · net on 4 is loose".
    var detail: String?
    /// "Review", "Assign". Only `needsAction` items carry one — the database enforces that too.
    var actionLabel: String?
    var actorID: StaffMember.ID?
    var playerID: Player.ID?
    var groupID: Group.ID?
    /// The block this row is about, which is what makes `8k`'s "1 note · shade tent is up" and
    /// "2 notes" counts rather than guesses. A group alone could not say it: a court runs every
    /// block of the day, so a note tied only to the court belongs to all five at once. Nil for
    /// the rows that really are about the camp rather than a moment in it.
    var scheduleBlockID: ScheduleBlock.ID?
    /// Held at the top of the Inbox and drawn on Overview as the pinned banner, until an admin
    /// takes it down.
    ///
    /// Stored rather than inferred. It used to be read off the shape of the row — a `.note`
    /// with no `groupID` — which was two rules pretending to be one, and the wrong way round:
    /// attaching a note to a court *un-pinned* it. A camp-wide note and a pinned one are
    /// different claims and a row is entitled to make either, both or neither.
    ///
    /// Writing it is admin-only, and the enforcement that counts is the RLS policy on
    /// `inbox_items` rather than anything on this side of the wire.
    var pinned: Bool = false
    var resolved: Bool = false
    var createdAt: Date = .now
}

/// The design's three filter chips are All / Needs you / Notes, and the feed beneath them is a
/// fourth thing again — so this is one closed set rather than a pair of booleans that can
/// contradict each other.
enum InboxKind: String, Hashable, Sendable, Codable, CaseIterable {
    /// Waiting on a decision. Carries an action label and drives the "Needs you · 2" count.
    case needsAction = "needs_action"
    /// Something a coach wrote down.
    case note
    /// Something that happened. Read-only history.
    case activity
}

/// `8r`'s chip row.
enum InboxFilter: String, CaseIterable, Identifiable, Sendable {
    case all, needsYou, notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .needsYou: "Needs you"
        case .notes: "Notes"
        }
    }

    /// `all` matches everything; the other two narrow to one kind. Written as a predicate rather
    /// than a `kind?` so the "all" case does not have to be special-cased at every call site.
    func matches(_ item: InboxItem) -> Bool {
        switch self {
        case .all: true
        case .needsYou: item.kind == .needsAction
        case .notes: item.kind == .note
        }
    }
}
