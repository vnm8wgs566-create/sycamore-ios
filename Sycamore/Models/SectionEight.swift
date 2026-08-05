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
    /// "Drills", "Match play", "Skills rotation" — the block running on this court right now,
    /// resolved from the schedule rather than stored per court.
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
    var notes: [String] = []

    /// "8:30", and "8:30 – 9:00" once there is an end.
    var timeLabel: String {
        guard let endsAt else { return startsAt.clockLabel }
        return "\(startsAt.clockLabel) – \(endsAt.clockLabel)"
    }

    var noteSummary: String? {
        guard let first = notes.first else { return nil }
        return notes.count == 1 ? "1 note · \(first)" : "\(notes.count) notes"
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
