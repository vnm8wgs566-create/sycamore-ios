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
    /// schedule can title exactly one of those cards correctly.
    var activity: String?
    var status: CourtStatus

    /// "Court 1 – 8 players", or "Court 4 – Tom is on it" when it is closed.
    var subtitle: String {
        if case .closed(let reason) = status { return "\(courtLabel ?? groupName) – \(reason)" }
        return "\(courtLabel ?? groupName) – \(playersHere) player\(playersHere == 1 ? "" : "s")"
    }
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
    /// The grey second line — "Courts 1–3 · 22 players", "Shade lawn", "15 min". One field
    /// rather than parsed parts because the design composes it differently on every row.
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

    /// The block a camp is in the middle of: the last one that has started, unless it has ended.
    ///
    /// One rule, in the model, because there were three — Overview asked the clock, the Postgres
    /// repository asked the clock again in its own words, and Schedule asked block *status*
    /// ("first one not marked done"). On any morning where a coach forgot to mark a block done,
    /// the tabs named different blocks as current and neither was wrong by its own definition.
    ///
    /// It is a fact about a list of blocks, not a drawing decision, which is why it lives here
    /// rather than in whichever screen needed it first.
    static func running(in blocks: [ScheduleBlock], at time: TimeOfDay) -> ScheduleBlock? {
        blocks
            .filter { $0.startsAt <= time }
            .max { $0.startsAt < $1.startsAt }
            .flatMap { block in
                guard let ends = block.endsAt, ends <= time else { return block }
                return nil
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
