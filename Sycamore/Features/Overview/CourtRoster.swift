//
//  CourtRoster.swift
//  Sycamore
//
//  The numbered list under a court card: the kids on the court, in court order, and how many
//  of them the card did not have room for.
//
//  The overflow is carried rather than worked out at the call site, because "+3 more" counts
//  the kids who are *here* — it has to agree with the headcount in the line above the list,
//  not with the length of the roll.
//
//  Which is also why the fold itself is a method here rather than a `prefix` wherever a card is
//  built. `rows.count + overflow` is this type's one invariant, and every place that cut the
//  list would otherwise have to restate the arithmetic that keeps it true.
//

import Foundation

struct CourtRoster: Hashable, Sendable {
    var rows: [PlayerRow]
    /// The `+3 more` line. Zero draws nothing.
    var overflow: Int

    /// A card that lists nobody: a closed court, or a court with nobody on it today.
    static let none = CourtRoster(rows: [], overflow: 0)

    var isEmpty: Bool { rows.isEmpty }

    /// Everybody on the court, drawn or folded away — so it still agrees with the card's
    /// `playersHere` whichever way the fold is turned.
    var headcount: Int { rows.count + overflow }
}

// MARK: - Folding

extension CourtRoster {

    /// The same court cut to `preview` kids, with the rest counted into `overflow`.
    ///
    /// How many is `GroupsRules.visibleCount`'s answer rather than a `prefix` of our own. Its
    /// `+ 1` is the whole point — folding a single row away spends a "1 more" row to hide a
    /// row, which is not a saving — and a court card and a group card that folded a list of
    /// kids by different rules would read as two apps.
    func folded(to preview: Int, isExpanded: Bool = false) -> CourtRoster {
        let visible = GroupsRules.visibleCount(
            of: rows.count, preview: preview, isExpanded: isExpanded
        )
        guard visible < rows.count else { return self }
        return CourtRoster(
            rows: Array(rows.prefix(visible)),
            overflow: overflow + (rows.count - visible)
        )
    }

    /// Whether this court has enough kids for the fold to save anything.
    ///
    /// The same rule as `folded(to:isExpanded:)`, asked as a question rather than restated —
    /// a card that is not foldable gets no control at all, and the two answers disagreeing
    /// would leave either a "+0 more" that does nothing or a court with no way back.
    ///
    /// Counted off `headcount`, so it stays true once the card is open and "Show less" is
    /// still reachable.
    func isFoldable(to preview: Int) -> Bool {
        GroupsRules.visibleCount(of: headcount, preview: preview, isExpanded: false) < headcount
    }
}
