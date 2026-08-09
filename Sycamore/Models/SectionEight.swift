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

    /// "8:30", and "8:30 – 9:00" once there is an end.
    var timeLabel: String {
        guard let endsAt else { return startsAt.clockLabel }
        return "\(startsAt.clockLabel) – \(endsAt.clockLabel)"
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
        let byID = Dictionary(staff.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let names = coachIDs.compactMap { byID[$0] }
        return switch names.count {
        case 0: nil
        case 1: names[0]
        case 2: "\(names[0]) & \(names[1])"
        default: "\(names[0]) +\(names.count - 1)"
        }
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
    /// breaks the tie on `id.uuidString`, the same arbitrary-but-fixed tie-break
    /// `BlockEditorDraft.block()` uses on `coachIDs` and `courtIDs`. Two blocks that genuinely
    /// start at the same minute on the same court are a clash the schedule flags
    /// (`BlockRules.overlap(with:in:)`); what matters here is only that they do not swap places
    /// between one read and the next.
    static func running(in blocks: [ScheduleBlock], at time: TimeOfDay) -> [ScheduleBlock] {
        blocks
            .filter { $0.startsAt <= time && !hasFinished($0, by: time, amongst: blocks) }
            .sorted { ($0.startsAt, $0.id.uuidString) < ($1.startsAt, $1.id.uuidString) }
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
enum ScheduleBlockKind: String, Hashable, Sendable, Codable, CaseIterable {
    /// A block that just happens. The shape everything on the schedule had until now.
    case regular
    /// A block that names its courts and the coaches on them.
    case assigned

    var displayName: String {
        switch self {
        case .regular: "Regular event"
        case .assigned: "Courts & coaches"
        }
    }

    /// The one line under each option in the editor's picker.
    var detail: String {
        switch self {
        case .regular: "A title and a time. Lunch, a briefing, a break."
        case .assigned: "Says which courts are running and who is on them."
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
