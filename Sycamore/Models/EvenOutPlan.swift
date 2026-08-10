//
//  EvenOutPlan.swift
//  Sycamore
//
//  "Even out the groups?" — what the button is about to do, worked out before it is pressed.
//
//  ---------------------------------------------------------------------------------------------
//  THE PREVIEW IS THE WRITE, RUN AGAINST A COPY
//  ---------------------------------------------------------------------------------------------
//
//  The obvious way to build this sheet is to write the split out a second time: `base = total /
//  courts`, `remainder = total % courts`, hand the leftovers to the courts that come first. That
//  is four lines, and it is the wrong four lines. `Camp.deal(_:across:)` already decides this, and
//  a second copy of the arithmetic is a second thing to keep in step — the moment the model learns
//  to skip a closed court, or to seat a venue's ladder differently, the sheet promises one thing
//  and the button does another. A preview that can disagree with its own button is worse than no
//  preview at all: it is a screen that lies about a decision somebody is making on behalf of
//  forty children.
//
//  So this runs the real thing. `Camp` is a value type, so a copy is `var after = camp`, and
//  `BlockKidSpread.allKids.apply(to:venueID:courtIDs:)` is the *same call the repository makes*
//  (`SectionEightRepository.spreadKids`) — not a re-implementation of it, not a sibling of it, the
//  function itself. Whatever it does to the copy is exactly what the button will do to the camp,
//  including anything either of them learns to do later.
//
//  `.allKids` and not `.evenly`, because those two answer different questions and only one of them
//  is this sheet's. `.evenly` levels the kids *already standing on* the named courts and pulls in
//  nobody else; `.allKids` deals the venue's whole ladder across them. The design's `redeal` is the
//  second — `state1.js:443-448` takes `ladderOf(camp, venue)`, every kid at the venue — and it is
//  also what `AppStore.finishFirstSort` runs after a ladder is committed. A venue with kids sitting
//  unassigned would otherwise be "evened out" and still have them sitting there.
//
//  ---------------------------------------------------------------------------------------------
//  NO `reindex()` ON THE COPY
//  ---------------------------------------------------------------------------------------------
//
//  The repository's `mutate` reindexes after the spread, and this does not. That is a deliberate
//  omission rather than a missing line: `reindex()` renumbers `overallRank` and `courtRank` and
//  refreshes the denormalised counts on `Group`, and touches no `groupID` at all. Both numbers
//  this type reads — who is on which court, and who changed courts — are read from `groupID`
//  through `players(inGroup:)`, which filters the players themselves rather than trusting
//  `Group.playerCount`. So the reindex could not move either figure, and running it would walk
//  every player in the camp twice to produce the same answer.
//
//  ---------------------------------------------------------------------------------------------
//  A MOVE IS A CHANGE OF COURT, NOT A CHANGE OF SIZE
//  ---------------------------------------------------------------------------------------------
//
//  `9 · 7 · 8 · 6` becoming `8 · 8 · 7 · 7` is two courts' worth of arithmetic and nowhere near
//  two kids' worth of walking: the deal re-seats the venue's whole ladder, so a kid can move from
//  Group 2 to Group 3 while both groups keep the size they had. The design counts the same thing
//  (`state1.js:437` — `if (k.group !== gi) moves++`), and the count in the button's label has to
//  be the number of children who will find themselves somewhere else, because that is what the
//  person pressing it is agreeing to.
//
//  A kid who was **unassigned** and lands on a court counts as a move, which the design has no
//  case for because every kid in it has a group. Here they can: an import leaves `groupID` nil on
//  purpose (`Repository.swift:607-610`), so "even out" is often the very thing that first places
//  them, and a count that ignored them would read 0 on the one venue where the button does the
//  most.
//

import Foundation

/// What "Even out" would do to one venue, and what to say about it.
///
/// A value with no reference to the camp it was computed from, so a sheet can hold it in `@State`
/// across a presentation without holding a stale graph. It carries `courtIDs` for the same reason
/// it carries the rows: whoever presses the button should be sending the write over the very
/// courts the preview was drawn from, rather than resolving them again a second later against a
/// camp that may have moved.
struct EvenOutPlan: Equatable, Sendable {

    /// One court's line: what it holds now, and what it would hold.
    struct Row: Identifiable, Equatable, Sendable {
        let id: Group.ID
        /// `Group 1`. The design's word and the design's numbering — position in the venue's rank
        /// order, counted from one — rather than `Group.label`, which follows the camp's sport and
        /// reads "Court 1" or "Lane 3". This sheet is about *groups of kids*; which patch of
        /// ground they stand on is not what is being decided.
        let title: String
        let from: Int
        let to: Int

        /// A court the deal would leave exactly as it is. The row is still drawn — a preview that
        /// hid the unchanged courts would not add up to the venue — but it can be drawn quietly.
        var isUnchanged: Bool { from == to }

        /// `Group 2, 9 kids, becomes 8` — the row as one phrase.
        ///
        /// VoiceOver reads a row of three labels as "Group 2", "9", "8", which is three
        /// announcements of which two are bare numerals and none says what it is counting. The
        /// arrow between them is a glyph and reads as nothing at all. This is the sentence the
        /// sighted reader gets from the layout, said out loud.
        ///
        /// An unchanged court says "stays at 8" rather than "becomes 8", because "becomes" invites
        /// the listener to wait for a change that is not coming.
        var accessibilityPhrase: String {
            let held = "\(from) kid\(from == 1 ? "" : "s")"
            return isUnchanged ? "\(title), stays at \(held)" : "\(title), \(held), becomes \(to)"
        }
    }

    /// The venue this is about, for the line under the title.
    let venueName: String
    /// The venue's courts in rank order — every one of them, including any the deal would empty.
    let rows: [Row]
    /// How many children would find themselves on a different court.
    let moves: Int
    /// The courts the write should run over, in the order the preview read them.
    let courtIDs: [Group.ID]

    /// Nothing to do: either the venue is already level or it has no courts to level.
    ///
    /// Read off `moves` rather than off the rows, because those are two different claims. Every row
    /// can be `isUnchanged` — the sizes already right — while the deal still re-seats kids between
    /// courts of equal size, and that is a write, not a no-op.
    var isNoOp: Bool { moves == 0 }

    /// `Sycamore · 9 · 7 · 8 · 6` — the venue and the sizes it holds today.
    var contextLine: String {
        guard !rows.isEmpty else { return venueName }
        return ([venueName] + rows.map { "\($0.from)" }).joined(separator: " · ")
    }

    /// `9 kids move.` / `1 kid moves.`
    ///
    /// The verb agrees as well as the noun. "1 kids move" is the kind of sentence that makes a
    /// person distrust the numbers beside it.
    var movesLine: String {
        moves == 1 ? "1 kid moves." : "\(moves) kids move."
    }

    /// `Even out · 9 moves`. The count is in the label because it is what is being agreed to —
    /// the same rule `8d`'s "Import 42 players" follows.
    var ctaTitle: String {
        "Even out · \(moves) move\(moves == 1 ? "" : "s")"
    }
}

// MARK: - Working it out

extension EvenOutPlan {

    /// What "Even out" would do to `venueID` in `camp`, or nil if the camp has no such venue.
    ///
    /// Nil rather than an empty plan for a venue that is not there, because those are different
    /// answers: an unknown venue is a caller holding a stale id and the sheet has nothing to draw,
    /// while a venue with no courts is a real venue with a real, empty answer.
    ///
    /// The whole camp rather than the venue's players and courts, deliberately. The mutation this
    /// runs is `Camp`'s, so the camp is what it needs; and taking the pieces apart here would mean
    /// this type deciding which pieces matter, which is precisely the judgement it exists not to
    /// make a second copy of.
    init?(camp: Camp, venueID: Venue.ID) {
        guard let venue = camp.venue(venueID) else { return nil }

        let courts = camp.groups(in: venueID)
        let courtIDs = courts.map(\.id)

        // Where everybody stands now, keyed once. The alternative is a `firstIndex(where:)` per
        // player inside the count below, which on a 50-kid venue is 2,500 comparisons to answer a
        // question one dictionary already holds.
        let before = Dictionary(
            camp.players(in: venueID).map { ($0.id, $0.groupID) }, uniquingKeysWith: { _, last in last }
        )

        var after = camp
        BlockKidSpread.allKids.apply(to: &after, venueID: venueID, courtIDs: courtIDs)

        self.venueName = venue.name
        self.courtIDs = courtIDs
        self.rows = courts.enumerated().map { offset, court in
            Row(
                id: court.id,
                title: "Group \(offset + 1)",
                from: camp.players(inGroup: court.id).count,
                to: after.players(inGroup: court.id).count
            )
        }
        // `before[id] ?? nil` flattens the double optional a dictionary lookup of an optional value
        // produces. A player the map somehow missed reads as "was nowhere", which counts them as
        // moving — the safe direction for a number that exists to warn somebody.
        self.moves = after.players(in: venueID).count { (before[$0.id] ?? nil) != $0.groupID }
    }
}
