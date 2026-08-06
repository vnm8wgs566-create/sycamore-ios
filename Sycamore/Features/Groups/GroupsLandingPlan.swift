//
//  GroupsLandingPlan.swift
//  Sycamore
//
//  What a landing turns into: the camp ladder, and the group's own sequence.
//
//  Lifted out of `GroupsView.commit(_:to:)` unchanged, so it can be tested. It was `private` on
//  a `@MainActor` view that reads `@Environment` and ends in a `Task` — none of which the
//  arithmetic needs, and all of which stood between it and a test. This is the part of section 8
//  that decides where a dragged child actually lands, and it was the only untested thing in the
//  app that could put a kid on the wrong court without anything looking wrong.
//
//  In its own file rather than beside `GroupsLanding` in `GroupsMove.swift` only to keep the
//  move out of a file other work is in.
//

import Foundation

/// The two orders one drop is written as.
///
/// Section 8 folds ranking into the Groups screen, so a move is a change to the **camp ladder**
/// first and to the group second — which is why this produces both, and why the group's order is
/// read back off the ladder rather than authored separately. Two orders that are each written by
/// hand are two orders that can disagree.
struct GroupsLandingPlan: Equatable {

    /// The camp ladder, venue by venue, with the mover in their new place.
    let assignments: [RankAssignment]
    /// The landing group's own sequence, including the mover.
    let courtOrder: [Player.ID]

    /// Nil when the landing names a venue the ladder does not have, which is not something to
    /// write.
    ///
    /// - Parameters:
    ///   - moverID: the kid being put down.
    ///   - landing: where they are going, said as "directly above this other kid".
    ///   - assignments: the camp ladder as it stands, top to bottom, venue by venue.
    ///   - roster: the landing group's current members. The mover is filtered out here rather
    ///     than by the caller, so there is one place that can forget to.
    init?(
        moving moverID: Player.ID,
        to landing: GroupsLanding,
        ladder assignments: [RankAssignment],
        roster: [Player]
    ) {
        var assignments = assignments
        guard let target = assignments.firstIndex(where: { $0.venueID == landing.venueID }) else {
            return nil
        }
        for index in assignments.indices {
            assignments[index].playerIDs.removeAll { $0 == moverID }
        }

        // The landing already names the kid the insertion bar sat above, so there is no index to
        // translate. That is the point of anchoring on an id: a row number only means something
        // beside the list it was counted against, and this screen's list is filtered by the
        // search field, folded to three rows, and about to have the mover taken out of it.
        //
        // Taking the mover out of every assignment first (above) is what keeps the arithmetic to
        // one step: every row below them has already shifted up, so the anchor's index in the
        // ladder *is* the insertion point.
        let ladder = assignments[target].playerIDs
        let roster = roster.filter { $0.id != moverID }

        // A nil anchor means the back of the group, which is whoever there holds its highest
        // rank — and landing behind them is one past their place in the ladder.
        let isBackOfGroup = landing.anchor == nil
        let anchor = landing.anchor ?? roster.max { $0.overallRank < $1.overallRank }?.id

        let insertion = anchor
            .flatMap { ladder.firstIndex(of: $0) }
            .map { isBackOfGroup ? $0 + 1 : $0 }
            // An empty group has no place of its own in the ladder yet, and the back of the
            // venue is the only answer that does not invent one.
            ?? ladder.count
        assignments[target].playerIDs.insert(moverID, at: insertion)

        // The group's own order, read back off the ladder that was just built — the two cannot
        // disagree if only one of them is authored.
        var members = Set(roster.map(\.id))
        members.insert(moverID)

        self.assignments = assignments
        self.courtOrder = assignments[target].playerIDs.filter { members.contains($0) }
    }
}
