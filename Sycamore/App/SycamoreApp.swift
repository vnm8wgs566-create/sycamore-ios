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
    @State private var store = AppStore()

    /// Cleared once the opening beat has played. Scene-scoped, so it happens on a cold launch
    /// and not every time the app returns from the background.
    @State private var isOpening = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        WindowGroup {
            // The screen underneath is at full opacity the whole time — it is not fading *in*.
            // The entrance sits over it and dissolves to nothing, so what you see is one layer
            // clearing to reveal the page that was always there.
            //
            // Fading both at once — the entrance out while the page came in — is what this
            // used to do, and it washes out in the middle: two half-transparent layers over
            // each other, neither of them the colour they should be. Only the top layer moves
            // now, so every frame of the transition is the page at its real weight with some
            // amount of splash still over it.
            RootView(store: store)
                .overlay {
                    if isOpening {
                        SeedEntrance().transition(.opacity)
                    }
                }
                .task {
                    // The choreography, end to end:
                    //
                    //   0.00  the mark lands       (0.42s)
                    //   0.22  the word writes in   (0.56s, done at 0.78)
                    //   0.78  — held, so the name is read rather than glimpsed —
                    //   1.25  the whole entrance — mark, word, seeds and ground — fades to
                    //         nothing over the page (0.55s, done at 1.80)
                    //
                    // Down from 2.8s. This is opened many times a day by someone standing on a
                    // court, and a second of that was the splash being admired rather than
                    // read. 1.8s still lands every beat.
                    //
                    // Under Reduce Motion the hold is shorter still: the seeds are gone and the
                    // word arrives without its sweep, so there is materially less to watch and
                    // holding the same beat would just be a wait.
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 900 : 1250))
                    withAnimation(.easeInOut(duration: reduceMotion ? 0.4 : 0.55)) {
                        isOpening = false
                    }
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
