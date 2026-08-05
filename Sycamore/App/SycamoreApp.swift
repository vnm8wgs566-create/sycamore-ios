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

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .opacity(isOpening ? 0 : 1)
                .overlay {
                    if isOpening {
                        SeedEntrance().transition(.opacity)
                    }
                }
                .task {
                    // The mark lands by 0.5s and the word finishes writing at about 0.95s;
                    // the rest is a beat of hold so the name is read rather than glimpsed.
                    try? await Task.sleep(for: .milliseconds(1900))
                    withAnimation(.smooth(duration: 0.45)) { isOpening = false }
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
