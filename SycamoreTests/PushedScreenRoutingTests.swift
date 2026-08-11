//
//  PushedScreenRoutingTests.swift
//  SycamoreTests
//
//  `pushedScreen` is one slot, which is the design's own depth — `closePage` (`state1.js:41`) is
//  literally "the shape page goes back to the camp page, everything else goes back to the tabs".
//  What it was missing was the memory to do that: opening a second screen overwrote the first with
//  nothing recorded, so every back control had to *guess* where it came from, and the one that
//  guessed hardest — Camp settings' arrow, hardcoded to Profile — was right about one of its four
//  entry points.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Going back lands where you came from")
struct PushedScreenRoutingTests {

    private func store() -> AppStore {
        AppStore(repository: InMemoryRepository())
    }

    @Test("Pushing over a screen and popping puts that screen back")
    func popRestoresTheScreenUnderneath() {
        let store = store()
        store.pushedScreen = .campHome

        store.push(.profile)
        #expect(store.pushedScreen == .profile)

        store.popPushed()
        #expect(store.pushedScreen == .campHome)
    }

    /// The four-entry-point bug, as a rule: Camp settings is pushed from the camp page, from
    /// Profile, from Tournament's empty state and from Overview's venue-sheet follow-up, and back
    /// has to mean four different things.
    @Test("Camp settings goes back to whichever screen opened it", arguments: [
        PushedScreen.campHome, .profile,
    ])
    func campSettingsReturnsToItsOpener(_ opener: PushedScreen) {
        let store = store()
        store.pushedScreen = opener

        store.push(.campSettings)
        store.popPushed()

        #expect(store.pushedScreen == opener)
    }

    /// Pushed from a tab rather than from another screen — Tournament's "Add a venue" and
    /// Overview's follow-up both do this. Back means the tabs, and must not invent a screen.
    @Test("A screen pushed from a tab goes back to the tabs")
    func popFromATabEndsAtTheTabs() {
        let store = store()
        #expect(store.pushedScreen == nil)

        store.push(.campSettings)
        store.popPushed()

        #expect(store.pushedScreen == nil)
    }

    /// Popping twice must not resurrect anything. One level is the whole contract, and a second
    /// pop that put the first screen back would be a stack pretending to be one level.
    @Test("Popping past the bottom stays at the bottom")
    func popTwiceIsStillTheTabs() {
        let store = store()
        store.pushedScreen = .campHome
        store.push(.profile)

        store.popPushed()
        store.popPushed()

        #expect(store.pushedScreen == nil)
    }
}
