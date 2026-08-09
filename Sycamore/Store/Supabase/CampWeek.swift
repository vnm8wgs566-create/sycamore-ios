//
//  CampWeek.swift
//  Sycamore
//
//  `Weekday` is `mon = 1 … sun = 7`. Postgres stores a `date`. This is the conversion.
//
//  It read "mon = 1 … fri = 5" until camps that open at a weekend needed saying. The numbering
//  here never changed — it was ISO all along, Monday 1 through Sunday 7 — so the two new cases
//  cost this file nothing but the sentences that had been describing the old limit. Which days a
//  *particular* camp runs is `Camp.days`, and no concern of the calendar.
//
//  The model is right to hold a weekday: a kid leaving at 14:30 on Thursday is a fact about
//  Thursday and not about the 6th of August. The database is right to hold a date: attendance
//  accumulates across weeks and a weekday alone cannot say which one. Neither is wrong, so
//  something has to sit between them, and it is better that it sit in one file than be
//  re-derived at every call site with a different idea of when a week starts.
//
//  Weeks run Monday-first here regardless of locale. A US calendar starts its week on Sunday,
//  which would put Monday's date a week ahead of Friday's for anyone opening the app on a
//  Sunday — the camp's own week is the ISO one.
//

import Foundation

enum CampWeek {

    /// Gregorian and Monday-first, in the reader's own time zone. The time zone matters: "today"
    /// at a camp is the local day, and a UTC-anchored formatter rolls over mid-afternoon in
    /// California.
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    // MARK: Weekday to date

    /// The date `day` falls on in the week containing `reference`.
    static func date(for day: Weekday, in week: Date = .now) -> Date {
        let calendar = calendar
        let start = calendar.startOfDay(for: week)
        // `.weekday` is Sunday = 1 … Saturday = 7. Rotating by five lands Monday on zero and
        // leaves Sunday six days *after* Monday, which is what makes a Sunday belong to the week
        // that just ended rather than the one about to begin.
        let offsetFromMonday = (calendar.component(.weekday, from: start) + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offsetFromMonday, to: start),
              let target = calendar.date(byAdding: .day, value: day.rawValue - 1, to: monday)
        else { return start }
        return target
    }

    /// `2026-08-05`.
    static func dateString(for day: Weekday, in week: Date = .now) -> String {
        string(from: date(for: day, in: week))
    }

    /// The Monday and Sunday of the week containing `reference`, as a range to filter a date
    /// column on — `camp(id:)` reads a whole week of attendance in one request.
    ///
    /// The far end was Friday while the model had no weekend. A camp that runs on a Saturday
    /// writes attendance on a Saturday, and a bound that stopped at Friday would have read the
    /// week back without it — the register would look empty on the one day it had been taken.
    static func weekBounds(in week: Date = .now) -> (monday: String, sunday: String) {
        (dateString(for: .mon, in: week), dateString(for: .sun, in: week))
    }

    // MARK: Date to weekday

    /// Nil only for a string that is not a date. This used to say "nil for a Saturday or Sunday:
    /// the model has no case for them" — it has both now, and the ISO arithmetic below already
    /// produced 6 and 7 for them, so the weekend stopped being unrepresentable the moment
    /// `Weekday` gained the cases.
    static func weekday(from text: String) -> Weekday? {
        guard let date = date(from: text) else { return nil }
        // Back to Monday = 1 … Sunday = 7, then straight into `Weekday`'s raw value.
        let isoIndex = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        return Weekday(rawValue: isoIndex)
    }

    // MARK: Formatting

    /// `en_US_POSIX` because `yyyy-MM-dd` has to mean the Gregorian year even for a reader whose
    /// device calendar is Buddhist or Japanese, where the default locale would render 2569.
    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func string(from date: Date) -> String {
        formatter().string(from: date)
    }

    static func date(from text: String) -> Date? {
        formatter().date(from: text)
    }
}

// MARK: - Times

/// `time without time zone` comes back as `08:30:00`, and goes out the same way.
///
/// `TimeOfDay` deliberately carries no date, which is the same thing the column means, so this
/// is a straight two-field parse rather than anything calendrical.
extension TimeOfDay {

    init?(postgresTime text: String) {
        let parts = text.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        self.init(hour, minute)
    }

    /// Seconds included: Postgres accepts `08:30` but returns `08:30:00`, and writing the same
    /// spelling we read keeps a round trip from looking like an edit.
    var postgresTime: String {
        String(format: "%02d:%02d:00", hour, minute)
    }
}
