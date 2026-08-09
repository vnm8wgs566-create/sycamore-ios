//
//  AppClock.swift
//  Sycamore
//
//  One clock, ticking once a minute, that every screen reads instead of `Date.now`.
//
//  The app already read the wall clock in a handful of places — `TimeOfDay.now()` decides which
//  block is running, `InboxBucket` decides whether a row belongs to "This morning" — but nothing
//  ever told a view to look again. There is no `Timer` in the codebase, no `TimelineView` outside
//  the launch animation, and no `scenePhase` observer, so those values were computed once per
//  body pass and then held. In practice `RootView` rebuilds the tab view on every tab switch, so
//  switching tabs was the only thing that moved time forward: a phone left on Overview at 11:58
//  still said "This morning" and still named the 11:00 block at half past twelve.
//
//  A minute is the resolution every one of those readers works at — block boundaries are on
//  fifteen-minute marks and the Inbox breaks at noon and five — so a minute is the tick. Anything
//  finer would wake the app to redraw text that has not changed.
//
//  Deliberately not a `TimelineView(.everyMinute)` at each site. That would put a scheduler behind
//  every screen that wants the time and still leave each of them holding its own idea of "now",
//  which is how two views end up disagreeing about which block is running. One value, read from
//  the environment, is also the only shape a test can pin.
//

import Foundation
import Observation
import SwiftUI

/// The current time, as something a view can observe.
///
/// `@Observable` rather than a `Timer` a view owns: a stored property that changes is what makes
/// SwiftUI re-read, and it means the tick lives for the app rather than for whichever screen
/// happened to be on top when it started.
@Observable
@MainActor
final class AppClock {

    /// The moment the last tick landed. Views read `today` and `timeOfDay` off this rather than
    /// calling `.now` themselves, so everything on screen agrees about when it is.
    private(set) var now: Date

    /// The day it is, which is also what decides whether the Schedule opens on today.
    var today: Weekday { Weekday.today(now) }

    /// The wall clock, as the camp's own time-of-day — what `ScheduleBlock.running(in:at:)` takes.
    var timeOfDay: TimeOfDay { TimeOfDay.now(now) }

    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(now: Date = .now) {
        self.now = now
    }

    deinit {
        ticker?.cancel()
    }

    /// Starts ticking, aligned to the top of the next minute.
    ///
    /// Aligned rather than every-sixty-seconds-from-whenever-this-was-called, because the readers
    /// care about boundaries: a block that ends at 11:00 should stop being "running" at 11:00 and
    /// not at 11:00:43. The first sleep is the remainder of the current minute; every one after it
    /// is a whole one.
    func start() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let seconds = Calendar.current.component(.second, from: self.now)
                let untilNextMinute = 60 - seconds
                do {
                    try await Task.sleep(for: .seconds(untilNextMinute))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.now = .now
            }
        }
    }

    /// Stops the tick. Called when the app goes to the background — a clock nobody can see is a
    /// wake-up nobody asked for, and the `refresh()` on the way back is what makes the first frame
    /// right anyway.
    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    /// Pulls the time forward now rather than waiting for the next minute. Used on foreground,
    /// where the gap since the last tick can be hours.
    func refresh() {
        now = .now
    }
}

// Reached through `AppStore.clock`, not through a second environment key.
//
// `@Entry var clock = AppClock()` was the first shape and does not compile: the macro synthesises
// the default in a nonisolated context and this class is `@MainActor`. Working around that would
// mean an implicitly-unwrapped key or a nonisolated shadow of the clock, both of which buy a
// second way to reach one value. Every screen already holds the store through
// `@Environment(AppStore.self)`, and the store is where `today` was read from before this
// existed — so it stays the one place to ask what time it is.
