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
//  ── Two granularities, stored apart ──────────────────────────────────────────────────────────
//
//  `now` moves every minute. The day it belongs to moves once. `today` was
//  `var today: Weekday { Weekday.today(now) }`, and a computed property hands its readers the
//  storage it was computed from: `@Observable` records what a `body` *read*, so every screen that
//  asked what day it was had subscribed to a value that changes 1440 times for each time the
//  answer does.
//
//  That is not theoretical. `ScheduleView` resolves the day it opens on from `store.today` inside
//  `body` (`ScheduleView.swift:79`) rather than seeding a `@State`, so the chip row, every block
//  card and the current-block calculation rebuilt once a minute on a screen nobody had touched —
//  which is the state the tab is in on every fresh presentation. The same read is at
//  `AttendanceView.swift:206`, `OverviewView.swift:67`, `OverviewScreen.swift:87`,
//  `CourtScreen.swift:167` and `PlayerScreen.swift:231`.
//
//  So `today` is stored, and `refresh(to:)` writes it only when the day has actually rolled over.
//  The `if` is the whole of the fix and not an optimisation on top of one: `@Observable` does not
//  compare before it fires, so assigning the same `Weekday` still announces a mutation and all six
//  of those reads invalidate anyway. Same lesson `AppStore.perform` records at
//  `AppStore.swift:1380-1385` about clearing an `errorMessage` that was already nil.
//
//  `timeOfDay` stays computed off `now`, because there the minute *is* the answer — a reader of
//  it wants to hear about every one.
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

    /// The moment the last tick landed. Views read `timeOfDay` off this rather than calling
    /// `.now` themselves, so everything on screen agrees about when it is.
    ///
    /// `today` is derived from it too, but through `refresh(to:)` rather than on read — see the
    /// header for why a screen that only wants the day must not be reading this.
    private(set) var now: Date

    /// The day it is, which is also what decides whether the Schedule opens on today.
    ///
    /// Stored rather than computed off `now`, and written only when it changes. That guard is
    /// what keeps a screen asking for the day off a value that moves every minute; the header
    /// has the six call sites and the reasoning.
    private(set) var today: Weekday

    /// The wall clock, as the camp's own time-of-day — what `ScheduleBlock.running(in:at:)` takes.
    var timeOfDay: TimeOfDay { TimeOfDay.now(now) }

    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(now: Date = .now) {
        self.now = now
        self.today = Weekday.today(now)
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
                self.refresh()
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

    /// Moves the clock, and is the only thing that does — the tick above and the foreground come
    /// through here. Called bare on foreground it pulls the time forward now rather than waiting
    /// for the next minute, where the gap since the last tick can be hours.
    ///
    /// One writer rather than an assignment to `now` at each site, because `today` has to be
    /// reconsidered alongside it: two writers is how a clock ends up carrying today's minute
    /// under yesterday's day. The tick used to set `now` itself (`self.now = .now`).
    ///
    /// Takes the date rather than reading `.now` inside itself, for the reason
    /// `Weekday.today(_:calendar:)` gives at `Models.swift:148-149` — a test can walk this across
    /// a midnight without waiting for one. Nothing in the app passes it.
    func refresh(to date: Date = .now) {
        now = date
        // Guarded, and the guard is what storing `today` is *for* — not a saving on top of it.
        // `@Observable` announces the assignment, not the change, so writing the same `Weekday`
        // back would rebuild every screen that reads the day — once a minute, for an answer that
        // moves at midnight. See the header.
        let day = Weekday.today(date)
        if day != today { today = day }
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
