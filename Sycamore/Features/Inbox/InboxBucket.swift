//
//  InboxBucket.swift
//  Sycamore
//
//  The rule that decides which heading a feed row falls under.
//
//  Derived from `createdAt` rather than stored. The design's two headings — "This morning" and
//  "Yesterday" — are true for about four hours on the day they were drawn; a screen that
//  hard-codes them says "This morning" at four in the afternoon and "Yesterday" for ever.
//

import Foundation

/// Which day a row happened on and — for today only — which part of it.
///
/// Only today is split three ways. That is the design's own asymmetry and it is the right one:
/// while you are inside a day you place things against *now* ("this morning" is over, "this
/// afternoon" has not started), and once a day is behind you all that matters is which day.
struct InboxBucket: Hashable, Comparable, Sendable {

    /// Midnight of the item's own day, in the reader's calendar.
    let dayStart: Date
    /// Nil for any day but today.
    let part: DayPart?

    enum DayPart: Int, Hashable, Comparable, Sendable, CaseIterable {
        case morning, afternoon, evening

        /// Noon and five — where a camp day actually breaks, and where the design's "This
        /// morning" stops being true.
        init(hour: Int) {
            switch hour {
            case ..<12: self = .morning
            case ..<17: self = .afternoon
            default: self = .evening
            }
        }

        var noun: String {
            switch self {
            case .morning: "morning"
            case .afternoon: "afternoon"
            case .evening: "evening"
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    init(for date: Date, now: Date, calendar: Calendar) {
        dayStart = calendar.startOfDay(for: date)
        part = calendar.isDate(date, inSameDayAs: now)
            ? DayPart(hour: calendar.component(.hour, from: date))
            : nil
    }

    /// "This morning", "Yesterday", "Tuesday", "12 Mar".
    ///
    /// The weekday and the date come from `Date.FormatStyle` rather than a hand-built pattern,
    /// so a reader whose calendar writes the day before the month gets their own order.
    func title(now: Date, calendar: Calendar) -> String {
        if let part { return "This \(part.noun)" }
        if calendar.isDateInYesterday(dayStart) { return "Yesterday" }

        // Inside a week the weekday alone places it; past that it needs a date, because
        // "Tuesday" could be either of two.
        let elapsed = calendar.dateComponents([.day], from: dayStart, to: calendar.startOfDay(for: now)).day
        if let elapsed, elapsed < 7 {
            return dayStart.formatted(.dateTime.weekday(.wide))
        }
        return dayStart.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Chronological. The feed sorts on the reverse of this.
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.dayStart != rhs.dayStart { return lhs.dayStart < rhs.dayStart }
        // No part sorts below any part, which only ever compares a bucket with itself.
        return (lhs.part?.rawValue ?? -1) < (rhs.part?.rawValue ?? -1)
    }
}
