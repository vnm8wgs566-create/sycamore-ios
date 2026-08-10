//
//  PlayerCourtChoices.swift
//  Sycamore
//
//  Every group a kid could be sent to — the list behind `8q`'s bar, with no view in it.
//
//  ── It says "Group 3", and it says it from `Group.number` ─────────────────────────────────────
//
//  The rows read `Group 3` and not `Group.label`'s `Court 3`. Groups titles its cards
//  "Group \(card.group.number)" (`GroupCard.swift:63`), the design writes `8q`'s bar "Move to
//  another group", and a coach who reads a card as a group and then has to pick a court is being
//  asked to translate between two names for one row. `Group.label` keeps its meaning — it is the
//  sport's noun for the *place*, "Court 1" / "Lane 1", and Attendance, Overview and Schedule still
//  want it — so this list stops reading it rather than the model changing under them.
//
//  Composed here from `number` rather than borrowed from `GroupCard`, which is a `View` and so
//  `@MainActor`; the one line of formatting is cheaper than the isolation. What stops the two
//  drifting is that both count off the same field, and `PlayerMoveTargetsTheGroupTests` holds the
//  sentence to the letter.
//
//  Lifted out of `PlayerCourtPicker` for the reason `GroupsLandingPlan` was lifted out of
//  `GroupsView` (`GroupsLandingPlan.swift:7-11`) and `ScheduleResizePlan` out of a finger on a
//  card's edge: everything decided here is something a person could otherwise only check by
//  putting a finger on a device, and every way it can be wrong looks right. A picker that quietly
//  dropped the second venue's six groups still reads as a picker. One that ticked the wrong row
//  still reads as a picker. One that numbered its rows off `rankOrder` instead of `number` still
//  reads as a picker, and disagrees with the Groups tab on every row a coach has reordered.
//
//  It also settles an agreement that would otherwise be invisible. `PlayerScreen` asks this type
//  whether the bar has anywhere to go, and `PlayerCourtPicker` asks it what to draw — so a live
//  bar over an empty picker, or a dead bar over a full one, is not a state the two can reach.
//
//  Nothing in here touches `AppStore`, `SwiftUI` or an actor. A `View` is `@MainActor` by
//  inference under Swift 6 and its statics come with it (`CoachPill.swift:43-46` records what that
//  costs); a plain struct over the camp graph is a struct a test can build in a line.
//

import Foundation

// MARK: - One group on the list

/// A group a kid could be sent to, with everything a person needs to aim at it.
///
/// The type keeps its name. Everything it describes is a `Group` row, and the app's own vocabulary
/// for those rows is still split — `Group.label`, `AppStore.closedCourts`, `CourtCapacity` — so a
/// rename here would move the seam rather than close it. What a person *reads* is the thing this
/// pass was about, and that is `label` below.
struct PlayerCourtOption: Identifiable, Hashable, Sendable {

    let id: Group.ID
    /// Carried because the write takes one — `movePlayer(_:toVenue:group:)` — and because a group
    /// two venues away is a legitimate destination, so the venue cannot be inferred from the kid.
    let venueID: Venue.ID
    /// `Group 3` — `Group.number` under the same sentence `GroupCard` titles its cards with.
    ///
    /// Deliberately **not** `Group.label`, which is the sport-derived name for the place a group
    /// plays on: "Court 3", "Lane 3", "Pitch 3". A venue that renames its courts must not change
    /// what the move screen calls a group, which is why this reads the numeral and not the string.
    let label: String
    /// Nil where nobody has this court yet; said as `CoachPill.needsACoach`, which is the words
    /// Overview and Schedule already use for the same hole.
    let coachName: String?
    /// Nil where there is nothing to measure against — see `CourtCapacity.reading(for group:)`.
    let capacity: CourtCapacity?
    /// Out of play today — "Net down", "Tom is on it". A fact about this morning rather than about
    /// the camp, which is why it is handed in beside the court rather than read off it; see
    /// `PlayerCourtChoices.init`.
    let isClosed: Bool
    /// Where the kid stands right now. Ticked and inert, rather than absent: a picker that hid
    /// their own group would make them count rows to work out which one they were in.
    let isCurrent: Bool

    /// The one state this row is in — `2 spots`, `Full`, `1 over`, `Closed` — or nil on a court
    /// with no ceiling to measure against, which can say nothing about its fill at all.
    ///
    /// `CourtCapacity.Flag` and not this list's own words. Overview's card says the same thing
    /// about the same court from the same enum, which is what stopped the two screens disagreeing
    /// about which states are worth flagging; that file's header carries the argument.
    ///
    /// **Closure beats the arithmetic.** A court that is shut *and* over its ceiling reads
    /// `Closed`, because the question this sheet answers is where to send a child and a court out
    /// of play is out of play whatever its head-count. It is also what Overview does a card
    /// earlier: `CourtCapacity.reading(for:capacity:)` returns nil on a closed court and the
    /// `Closed` badge is the only thing in that slot.
    ///
    /// **Closure survives a missing ceiling, where the fill cannot.** A court with `capacity == 0`
    /// has nothing to measure and so has no fill state — but it can still be shut, and a shut court
    /// offered unmarked is the defect this property exists to close. Hence the branch on
    /// `isClosed` before the optional and not inside it.
    ///
    /// **A flag, not a bar.** There is deliberately no `isEligible` beside this and nothing
    /// downstream disables a row; `CourtCapacity.Flag.isWarning` carries that argument now, and
    /// `PlayerCourtPicker` honours it by drawing an amber pill and keeping the row tappable.
    var flag: CourtCapacity.Flag? {
        if isClosed { return .closed }
        return capacity?.flag
    }

    /// `6 of 8 · Nass`, or `6 of 8 · Needs a coach` — the line under the group's name.
    ///
    /// The coach segment is always there, including when there is nobody: "who has it" is one of
    /// the three things this list exists to answer, and a row that simply omitted the answer would
    /// read as a court whose coach the sheet had failed to load.
    var meta: String {
        [capacity?.reading, coachName ?? CoachPill.needsACoach]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// What VoiceOver hears instead of the three runs above.
    ///
    /// `CourtCapacity.spokenReading` rather than `reading`, for the reason it exists: "6 of 8" on
    /// its own reads as a score or a date.
    ///
    /// The figure and the flag are appended separately rather than through
    /// `CourtCapacity.spokenLabel`, which folds them together for Overview's badge. This row's flag
    /// is not always the capacity's — a closed court says `Closed` over the top of whatever its
    /// fill is — and reading the fold would say one word here while the pill beside it said
    /// another. Same `flag`, seen and heard, is the whole point of it being one property.
    var spokenLabel: String {
        var parts = [label]
        if let capacity { parts.append(capacity.spokenReading) }
        if let flag { parts.append(flag.spokenLabel) }
        parts.append(coachName.map { "Coach \($0)" } ?? CoachPill.needsACoach)
        return parts.joined(separator: ". ")
    }
}

// MARK: - One venue's worth of them

/// The groups at one venue, under that venue's name.
///
/// Sectioned rather than flat because the numbering restarts at every venue: `SampleData` alone has
/// a "Group 1" at Sycamore and a "Group 1" at LATC, and a single list of twelve would offer two
/// identical rows with no way to tell which is which. That was already true of `Group.label` and it
/// is no less true of `Group.number`, which `syncGroups` counts from one per venue
/// (`Models.swift:1592-1598`) — so the venue header is load-bearing, not decoration.
struct PlayerCourtSection: Identifiable, Hashable, Sendable {
    let id: Venue.ID
    /// The venue's name. Deliberately not its emoji as well: the header is set uppercase through
    /// `SheetSectionHeader`, and an icon in it would be read out by VoiceOver ahead of every court
    /// under it for no gain over the name that follows.
    let title: String
    let courts: [PlayerCourtOption]
}

// MARK: - The whole list

/// Every group in the camp, ordered, with the kid's own marked.
struct PlayerCourtChoices: Equatable, Sendable {

    let sections: [PlayerCourtSection]

    /// - Parameters:
    ///   - playerID: the kid being moved. A kid the camp does not hold — a roster that has moved
    ///     on under an open sheet — still gets the whole list with nothing ticked, rather than an
    ///     empty one: the courts are a fact about the camp, not about them.
    ///   - camp: nil while the store is still loading, which is an empty list and not an empty
    ///     camp; `PlayerCourtPicker` draws the difference.
    ///   - closedCourts: the courts `today_courts` says are out of play this morning. Handed in
    ///     rather than read off the graph because closure is not on it: a `Group` is a court in the
    ///     camp, and whether it is shut *today* is a `CourtCard` fact. `AppStore.closedCourts` is
    ///     what the sheet passes, and says out loud what it can and cannot see.
    ///
    ///     Defaulted to none, and that default is safe rather than convenient: closure changes what
    ///     a row *says* and never which rows exist, so `hasSomewhereElse` — the one caller that
    ///     asks a question about the shape of the list — cannot be wrong for want of it. A caller
    ///     that draws the rows must pass it.
    init(for playerID: Player.ID, in camp: Camp?, closedCourts: Set<Group.ID> = []) {
        guard let camp else {
            sections = []
            return
        }

        let currentCourtID = camp.player(playerID)?.groupID

        // `orderedVenues` and `groups(in:)` rather than the stored arrays: the first sorts by the
        // venue's `sortIndex`, the second by each court's `rankOrder`, and the two together are the
        // order every other screen in the app lists courts in. The arrays themselves come off a
        // repository and their order is nobody's promise — a picker with an order of its own would
        // send somebody hunting for Court 3 between Court 5 and Court 1.
        sections = camp.orderedVenues.compactMap { venue in
            let courts = camp.groups(in: venue.id).map { court in
                PlayerCourtOption(
                    id: court.id,
                    venueID: venue.id,
                    // `number`, not `label`. See `PlayerCourtOption.label` and this file's header:
                    // the row names the rank band, which is what a move changes, and `Group.label`
                    // names the place it plays on.
                    label: "Group \(court.number)",
                    coachName: camp.coach(forGroup: court.id)?.name,
                    capacity: CourtCapacity.reading(for: court),
                    isClosed: closedCourts.contains(court.id),
                    isCurrent: court.id == currentCourtID
                )
            }
            // A venue with no courts is dropped rather than headed. `Venue.groupCount` says how
            // many it is *shaped* for, and a camp part-way through setup can have a venue with none
            // built yet — a bare heading over nothing reads as a list that failed to load.
            return courts.isEmpty
                ? nil
                : PlayerCourtSection(id: venue.id, title: venue.name, courts: courts)
        }
    }

    /// Every court on the list, sections flattened away. What the tests read; the view reads the
    /// sections.
    var courts: [PlayerCourtOption] { sections.flatMap(\.courts) }

    /// Whether this list is worth opening: is there a group that is not already theirs.
    ///
    /// What `PlayerScreen` enables the bar on. Not "is there a group above this one" — that was the
    /// old bar's question, from when the bar performed the move itself.
    ///
    /// Nested `contains` rather than `courts.contains`, which is the same sentence one line
    /// shorter. `flatMap` does not short-circuit: it would build and copy the whole flattened
    /// array before the predicate ran once, and `PlayerScreen` asks this on every body pass.
    var hasSomewhereElse: Bool {
        sections.contains { section in section.courts.contains { !$0.isCurrent } }
    }

    // `capacity(of:)` used to sit here: a `CourtCapacity` built by hand behind a `capacity > 0`
    // guard, with a comment asking for the sibling that now exists. It is
    // `CourtCapacity.reading(for group:)`, beside the `CourtCard` overload Overview reads, so
    // "of 0 is not a sentence" is one rule in one place rather than two copies that agreed on the
    // day they were written. Its argument about the numerator — `presentCount` and not the roll —
    // went with it, because that is a fact about the reading and not about this sheet.
}
