//
//  AppClockTests.swift
//  SycamoreTests
//
//  What the clock says, and — the part worth a test — who it wakes up when it says it.
//
//  `AppClock.today` was a computed property over `now`, so it was correct on every read and still
//  wrong: `@Observable` records the storage a `body` touched, and `now` moves every minute for an
//  answer that moves once a day. Six reads ask for the day (`ScheduleView.swift:79`,
//  `AttendanceView.swift:206`, `OverviewView.swift:67`, `OverviewScreen.swift:87`,
//  `CourtScreen.swift:167`, `PlayerScreen.swift:231`) and every one of them rebuilt on every tick.
//
//  Nothing about that is visible in a value. `clock.today` returns the same `Weekday` under both
//  designs, on every date, so a test that only reads it passes just as happily against the bug it
//  is meant to catch. The observation *event* is the behaviour, so `withObservationTracking` is
//  what these assert on — a plain `#expect(clock.today == …)` would pin nothing.
//
//  Dates are built from `Calendar.current`, the same calendar `Weekday.today(_:)` defaults to, so
//  these run the same in every timezone and across a DST boundary — `date(byAdding: .day)` moves
//  a whole day, not 86,400 seconds.
//

import Foundation
import Testing
@testable import Sycamore

/// Somewhere to record that the tracker fired.
///
/// `withObservationTracking`'s `onChange` is `@Sendable`, so it cannot mutate a captured local in
/// Swift 6 — even though everything here is on the main actor and the callback runs synchronously
/// under the assignment. A reference the closure can reach is the smallest way to say that.
private final class Fired: @unchecked Sendable {
    var value = false
}

@MainActor
@Suite("AppClock")
struct AppClockTests {

    /// Nine in the morning, today, in the calendar the clock itself reads.
    ///
    /// Built from components rather than `startOfDay(for:) + 9h`, which is nine o'clock on 364
    /// days a year: the spring-forward day is 23 hours long, so nine hours after the start of it
    /// is ten. `theTimeOfDayStillFollowsEveryTick` asserts on the hour, and a test that fails one
    /// morning a year is worse than no test.
    private static func at(_ hour: Int) -> Date {
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: .now)
        parts.hour = hour
        parts.minute = 0
        return calendar.date(from: parts) ?? .now
    }

    private static var morning: Date { at(9) }

    private static func nextDay(after date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
    }

    /// Watches `clock.today`, runs `change`, and answers whether the read was invalidated.
    private static func dayInvalidated(
        _ clock: AppClock, by change: (AppClock) -> Void
    ) -> Bool {
        let fired = Fired()
        withObservationTracking {
            _ = clock.today
        } onChange: {
            fired.value = true
        }
        change(clock)
        return fired.value
    }

    @Test("Starts on the day it was given")
    func startsOnTheDayItWasGiven() {
        let start = Self.morning
        #expect(AppClock(now: start).today == Weekday.today(start))
    }

    // MARK: - The tick

    /// The whole point. A minute passing moves `now`, and a screen that only asked what day it is
    /// hears nothing.
    @Test("A minute passing does not invalidate the day")
    func aMinutePassingDoesNotInvalidateTheDay() {
        let start = Self.morning
        let clock = AppClock(now: start)

        let invalidated = Self.dayInvalidated(clock) {
            $0.refresh(to: start.addingTimeInterval(60))
        }

        #expect(invalidated == false)
        #expect(clock.today == Weekday.today(start))
        #expect(clock.now == start.addingTimeInterval(60))
    }

    /// The same, over the span a phone actually sits on one tab. Thirteen hours of ticks — 8am to
    /// 9pm, through every block boundary and both of the Inbox's — and the day is still the day.
    ///
    /// Stops at 9pm rather than running to midnight because the last hours of a day are where the
    /// clocks change, and the assertion is about the rollover, not about which timezone the
    /// machine is in.
    @Test("A whole day of ticks, short of midnight, invalidates nothing")
    func aWholeDayOfTicksInvalidatesNothing() {
        let start = Self.at(8)
        let clock = AppClock(now: start)

        let invalidated = Self.dayInvalidated(clock) { clock in
            for minute in 1...(13 * 60) {
                clock.refresh(to: start.addingTimeInterval(TimeInterval(minute * 60)))
            }
        }

        #expect(invalidated == false)
        #expect(clock.today == Weekday.today(start))
    }

    // MARK: - Midnight

    /// And the guard must not be a mute: the one tick that matters still has to land, or Schedule
    /// opens on yesterday and Attendance takes the register against it.
    @Test("Midnight moves the day and invalidates it")
    func midnightMovesTheDay() {
        let start = Self.morning
        let tomorrow = Self.nextDay(after: start)
        let clock = AppClock(now: start)

        let invalidated = Self.dayInvalidated(clock) { $0.refresh(to: tomorrow) }

        #expect(invalidated)
        #expect(clock.today == Weekday.today(tomorrow))
        #expect(clock.today != Weekday.today(start))
    }

    /// The foreground case, which is the one that jumps rather than ticks: `SycamoreApp` calls
    /// `refresh()` on `.active` because the gap across a backgrounded night is hours, and the day
    /// has to come with it.
    @Test("A jump of several days lands on the right one")
    func aJumpOfSeveralDaysLandsOnTheRightOne() {
        let start = Self.morning
        var later = start
        for _ in 1...4 { later = Self.nextDay(after: later) }
        let clock = AppClock(now: start)

        clock.refresh(to: later)

        #expect(clock.today == Weekday.today(later))
    }

    // MARK: - The minute is still the minute

    /// `timeOfDay` is left computed off `now` deliberately — a reader of it wants every tick — so
    /// this pins that the guard above did not quietly slow it down too.
    @Test("The time of day still follows every tick")
    func theTimeOfDayStillFollowsEveryTick() {
        let start = Self.morning
        let clock = AppClock(now: start)

        clock.refresh(to: start.addingTimeInterval(60))

        #expect(clock.timeOfDay == TimeOfDay(9, 1))
    }
}
