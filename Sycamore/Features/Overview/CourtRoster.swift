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

import Foundation

struct CourtRoster: Hashable, Sendable {
    var rows: [PlayerRow]
    /// The `+3 more` line. Zero draws nothing.
    var overflow: Int

    /// A card that lists nobody: every court but the one being looked at.
    static let none = CourtRoster(rows: [], overflow: 0)

    var isEmpty: Bool { rows.isEmpty }
}
