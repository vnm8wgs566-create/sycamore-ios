//
//  SycamoreApp.swift
//  Sycamore
//
//  The entry point. It owns exactly one thing — the `AppStore` — and hands it to
//  `RootView`, which decides what a person is looking at.
//
//  The design is drawn light-only (every surface is white or one of two near-white greys),
//  so the app pins its colour scheme rather than shipping a half-finished dark palette.
//

import SwiftUI

@main
struct SycamoreApp: App {

    /// One store for the whole process. `@State` gives it the lifetime of the scene and,
    /// because `AppStore` is `@Observable`, every view that reads it re-renders on its own.
    ///
    /// This is the single line that decides whether the app talks to Postgres or to nothing.
    /// `SycamoreRepository` was written `async throws` from the start so that swapping the
    /// implementation here would need no other change anywhere — not a view, not the store. It
    /// held: this is the whole switch.
    ///
    /// `InMemoryRepository()` is still what every `#Preview` and the `AppStore.preview` family
    /// construct, so previews keep rendering without a network.
    @State private var store = AppStore(repository: SycamoreApp.repository())

    /// Postgres, unless a debug build was launched with `-offline`.
    ///
    /// The switch exists because walking the app end to end otherwise costs a real sign-in, and
    /// this project has no custom SMTP: GoTrue's built-in mailer sends to project members only,
    /// twice an hour. Verifying that the screens compose is not worth that budget, and it is a
    /// different question from whether the network layer works.
    ///
    /// Debug only, on purpose. A release build has no way to reach the offline store however it
    /// is launched, so this cannot become a shipped code path by accident.
    private static func repository() -> SycamoreRepository {
        #if DEBUG
        if CommandLine.arguments.contains("-offline") { return InMemoryRepository() }
        #endif
        return SupabaseRepository()
    }

    /// Cleared once the opening beat has played. Scene-scoped, so it happens on a cold launch
    /// and not every time the app returns from the background.
    @State private var isOpening = true
    /// The entrance's opacity, animated declaratively by `.animation(_:value:)` below.
    ///
    /// Two earlier attempts at this fade did not render at all, both measured off screen
    /// captures rather than assumed:
    ///
    /// 1. `.transition(.opacity)` on the overlay — the splash went from fully opaque to gone
    ///    between two frames, a 16ms cut.
    /// 2. `withAnimation { entranceOpacity = 0 }` inside `.task` — same cut, even when the
    ///    duration was stretched to six seconds to make any ramp unmissable. `withAnimation`
    ///    after an `await` is not reliably picked up as a view-update transaction, so the
    ///    value simply snapped.
    ///
    /// `.animation(_:value:)` is declarative: it animates the change because the value
    /// differs, with no dependence on what context the mutation happened in.
    @State private var entranceOpacity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared by the modifier and the teardown, so the wait cannot drift from the animation.
    private var fadeDuration: Double { Motion.Entrance.fade(reduceMotion: reduceMotion) }

    var body: some Scene {
        WindowGroup {
            // The screen underneath is at full opacity the whole time — it is not fading *in*.
            // The entrance sits over it and dissolves to nothing, so what you see is one layer
            // clearing to reveal the page that was always there.
            //
            // Fading both at once — the entrance out while the page came in — washes out in
            // the middle: two half-transparent layers over each other, neither of them the
            // colour they should be. Only the top layer moves, so every frame of the
            // transition is the page at its real weight with some amount of splash over it.
            ZStack {
                RootView(store: store)

                if isOpening {
                    SeedEntrance()
                        .opacity(entranceOpacity)
                        // Once it starts leaving it must not swallow taps meant for the page.
                        .allowsHitTesting(false)
                }
            }
                .animation(.easeInOut(duration: fadeDuration), value: entranceOpacity)
                .task {
                    // The choreography, end to end:
                    //
                    //   0.00  the mark lands       (0.42s)
                    //   0.22  the word types in    (eight keystrokes at 0.07s — the first
                    //         letter at 0.29, the last at 0.78)
                    //   0.78  — held 0.47s, so the name is read rather than glimpsed —
                    //   1.25  the whole entrance — mark, word, seeds and ground — fades to
                    //         nothing over the page (0.6s, done at 1.85)
                    //
                    // Down from 2.8s. This is opened many times a day by someone standing on a
                    // court, and a second of that was the splash being admired rather than
                    // read. 1.85s still lands every beat.
                    //
                    // Those numbers are `Motion.Entrance`'s, not this comment's. The 1.25 below
                    // is the sum of beats that `FallingSeeds` plays, so it is computed from them
                    // rather than typed out here — a comment in this file cannot stop the hold
                    // going stale when the typing rate changes in that one, and a hold that has
                    // gone stale means the fade starting over a half-written word.
                    //
                    // Under Reduce Motion the hold is shorter still: the seeds are gone and the
                    // word is simply already there, so the same 0.47s dwell measured from the
                    // mark landing puts the fade at 0.89 and the entrance away by 1.29. There is
                    // materially less to watch and holding the same beat would just be a wait.
                    try? await Task.sleep(for: .seconds(Motion.Entrance.hold(reduceMotion: reduceMotion)))
                    entranceOpacity = 0

                    // Torn down only once it is already invisible. Removing it while it is
                    // still on screen is what produced the cut the first time round.
                    try? await Task.sleep(for: .seconds(fadeDuration + 0.15))
                    isOpening = false
                }
                // Text scales with the reader's setting, but only to the first accessibility
                // step. The design is transcribed from CSS at fixed point sizes — a 34×32
                // stepper, a 42pt tab pill, stat tiles sized to their numerals — and past
                // `.accessibility1` those frames clip rather than reflow. A cap that holds the
                // layout together is worth more than uncapped growth that breaks it; lifting
                // it is a layout job, not a typography one.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        #if os(macOS)
        // The macOS build exists only so `swift build` typechecks the shared sources.
        // Sizing the window to a phone keeps that build glanceable rather than useful.
        .defaultSize(width: 402, height: 874)
        #endif
    }
}
