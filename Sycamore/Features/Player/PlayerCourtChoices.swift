//
//  PlayerCourtChoices.swift
//  Sycamore
//
//  Every court a kid could be sent to — the list behind `8q`'s bar, with no view in it.
//
//  Lifted out of `PlayerCourtPicker` for the reason `GroupsLandingPlan` was lifted out of
//  `GroupsView` (`GroupsLandingPlan.swift:7-11`) and `ScheduleResizePlan` out of a finger on a
//  card's edge: everything decided here is something a person could otherwise only check by
//  putting a finger on a device, and every way it can be wrong looks right. A picker that quietly
//  dropped the second venue's six courts still reads as a picker. One that ticked the wrong row
//  still reads as a picker.
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

// MARK: - One court on the list

/// A court a kid could be sent to, with everything a person needs to aim at it.
struct PlayerCourtOption: Identifiable, Hashable, Sendable {

    let id: Group.ID
    /// Carried because the write takes one — `movePlayer(_:toVenue:group:)` — and because a court
    /// two venues away is a legitimate destination, so the venue cannot be inferred from the kid.
    let venueID: Venue.ID
    /// `Court 3` — `Group.label`, which is the sport's noun plus the number.
    let label: String
    /// Nil where nobody has this court yet; said as `CoachPill.needsACoach`, which is the words
    /// Overview and Schedule already use for the same hole.
    let coachName: String?
    /// Nil where there is nothing to measure against — see `PlayerCourtChoices.capacity(of:)`.
    let capacity: CourtCapacity?
    /// Where the kid stands right now. Ticked and inert, rather than absent: a picker that hid
    /// their own court would make them count courts to work out which one they were on.
    let isCurrent: Bool

    /// `Full`, `1 over`, `2 over` — or nil on a court with room, which wears nothing.
    ///
    /// **A flag, not a bar.** There is deliberately no `isEligible` beside this and nothing
    /// downstream disables a row: the app flags a clash rather than refusing one, which is argued
    /// at length for the schedule's overlaps in `ScheduleResize.swift:19-42` and
    /// `BlockEditorDraft.swift:96-125` and holds here for the same reasons. A camp may
    /// legitimately go over, somebody wants to *see* it rather than be stopped at seven in the
    /// morning, and Overview draws the same amber on the same court without disabling anything.
    ///
    /// The over-capacity wording is `CourtCapacity.pillLabel`'s rather than a second phrasing of
    /// it, so this row and Overview's card say the same thing about the same court. `Full` is this
    /// list's own addition: `pillLabel` is nil at exactly the ceiling because `8i` had nothing to
    /// put in that slot, and a picker that flagged nine-on-eight but not eight-on-eight would be
    /// silent about the state it most needs to warn on.
    ///
    /// That addition leaves the word "Full" with two owners: `CourtCapacity.spokenLabel` already
    /// says it, and `spokenLabel` below reads *that* one while the pill reads this one — so a row
    /// can be seen to say one word and heard to say another. The right home is a `flagLabel`
    /// beside `pillLabel` on `CourtCapacity`, which is where `isOver` and `overBy` already live for
    /// exactly this argument; `Features/Overview` belongs to another unit this wave.
    /// `PlayerCourtPickerTests.spokenLabel` pins the two together in the meantime.
    var flag: String? {
        guard let capacity else { return nil }
        if capacity.isOver { return capacity.pillLabel }
        return capacity.spotsFree == 0 ? "Full" : nil
    }

    /// `6 of 8 · Nass`, or `6 of 8 · Needs a coach` — the line under the court's name.
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
    /// `CourtCapacity.spokenLabel` rather than `reading`, for the reason it exists: "6 of 8" on its
    /// own reads as a score or a date. It is also the only place a court sitting exactly on its
    /// ceiling says "Full" to somebody who cannot see the pill beside it.
    var spokenLabel: String {
        var parts = [label]
        if let capacity { parts.append(capacity.spokenLabel) }
        parts.append(coachName.map { "Coach \($0)" } ?? CoachPill.needsACoach)
        return parts.joined(separator: ". ")
    }
}

// MARK: - One venue's worth of them

/// The courts at one venue, under that venue's name.
///
/// Sectioned rather than flat because court labels repeat: `SampleData` alone has a "Court 1" at
/// Sycamore and a "Court 1" at LATC, and a single list of twelve would offer two identical rows
/// with no way to tell which is which.
struct PlayerCourtSection: Identifiable, Hashable, Sendable {
    let id: Venue.ID
    /// The venue's name. Deliberately not its emoji as well: the header is set uppercase through
    /// `SheetSectionHeader`, and an icon in it would be read out by VoiceOver ahead of every court
    /// under it for no gain over the name that follows.
    let title: String
    let courts: [PlayerCourtOption]
}

// MARK: - The whole list

/// Every court in the camp, ordered, with the kid's own marked.
struct PlayerCourtChoices: Equatable, Sendable {

    let sections: [PlayerCourtSection]

    /// - Parameters:
    ///   - playerID: the kid being moved. A kid the camp does not hold — a roster that has moved
    ///     on under an open sheet — still gets the whole list with nothing ticked, rather than an
    ///     empty one: the courts are a fact about the camp, not about them.
    ///   - camp: nil while the store is still loading, which is an empty list and not an empty
    ///     camp; `PlayerCourtPicker` draws the difference.
    init(for playerID: Player.ID, in camp: Camp?) {
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
                    label: court.label,
                    coachName: camp.coach(forGroup: court.id)?.name,
                    capacity: Self.capacity(of: court),
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

    /// Whether this list is worth opening: is there a court that is not already theirs.
    ///
    /// What `PlayerScreen` enables the bar on. Not "is there a court above this one" — that was the
    /// old bar's question, from when the bar performed the move itself.
    ///
    /// Nested `contains` rather than `courts.contains`, which is the same sentence one line
    /// shorter. `flatMap` does not short-circuit: it would build and copy the whole flattened
    /// array before the predicate ran once, and `PlayerScreen` asks this on every body pass.
    var hasSomewhereElse: Bool {
        sections.contains { section in section.courts.contains { !$0.isCurrent } }
    }

    /// How full a court is, or nil where there is nothing to measure it against.
    ///
    /// `presentCount` is the numerator, not `playerCount`, and the two differ by whoever is away.
    /// `Group.isOverCapacity` measures against today's count on purpose — `Models.swift:495-498`
    /// argues it, and `Group.capacityBanner` and Overview's amber both follow it — so a reading
    /// built on the roll would let a row here say "8 of 8 · Full" beside a court the rest of the
    /// app calls in range. One numerator, or the figure and the flag drift apart the first day
    /// somebody is off sick.
    ///
    /// Nil on a ceiling of zero or less, mirroring `CourtCapacity.reading(for:capacity:)`: "of 0"
    /// is not a sentence. That entry point takes a `CourtCard` — a row of `today_courts` — so the
    /// reading is built from the graph directly instead. The proper home for this is a sibling
    /// `reading(for group: Group)` on the same extension, so the guard has one owner rather than
    /// two; `Features/Overview` belongs to another unit this wave.
    ///
    /// **A court closed today is listed like any other, unflagged.** Closure is `CourtStatus` on a
    /// `CourtCard` (`SectionEight.swift:88-110`), which is a row of `today_courts` per venue; the
    /// camp graph a `Group` comes off has no such field. That is defensible as far as it goes — a
    /// move is a roster change and a closure is a fact about this morning, so a kid can reasonably
    /// be placed on a court that is out of play today — but "Net down" ought to be visible on the
    /// row of somebody deciding where to send a child. Raising closure onto `Group`, or reading
    /// `today_courts` for every venue from here, are both off-limits files.
    private static func capacity(of court: Group) -> CourtCapacity? {
        guard court.capacity > 0 else { return nil }
        return CourtCapacity(here: court.presentCount, capacity: court.capacity)
    }
}
