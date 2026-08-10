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
    ///
    /// **Still `Group.label`, and deliberately so.** The pass that made `8q`'s move bar and its
    /// picker read "Group N" off `Group.number` stopped here on purpose. Those screens name the
    /// rank band a kid belongs to, which is what a move changes. This one names somewhere to walk:
    /// a coach marking "Courts 1–3" is holding a phone in the middle of three courts, and the
    /// answer to "which of these is Liam on" has to be the court, not a band they would then have
    /// to map back onto one. The header above the list says the same thing from the same source —
    /// `AttendanceView.sessionLine` joins these labels when there is no block to name the session —
    /// so renaming half of the pair would put a "Group 2" row under a "Court 1, Court 2" header.
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
