//
//  AttendanceEntry.swift
//  Sycamore
//
//  One kid, as `8m` draws them.
//
//  Not `PlayerRow`: that shape is built for Groups and Rank, and carries a court rank rather
//  than the court's name. `8m` needs the name — a block runs across "Courts 1–3", so the list a
//  coach marks can span three of them and "Court 2" is how they tell two Liams apart.
//

import Foundation

struct AttendanceEntry: Identifiable, Hashable, Sendable {
    let id: Player.ID
    let name: String
    /// Ladder position. The design numbers these 1, 2, 3 … 11, which is the venue ladder rather
    /// than the court's own 1…8.
    let rank: Int
    /// "Court 1". Nil when the session covers a single court, where naming it says nothing.
    let courtLabel: String?
    /// What the day already says. `nil` is not a state here — a kid is either here or away; the
    /// screen's third state ("not answered yet") lives in `AttendanceView`, because the model
    /// has no word for it.
    let isAway: Bool
    let leavesAt: TimeOfDay?

    /// "Leaves 2:30pm today" — the amber line under a marked name.
    var pickupLine: String? {
        guard let leavesAt else { return nil }
        return "Leaves \(leavesAt.clockLabel) today"
    }
}
