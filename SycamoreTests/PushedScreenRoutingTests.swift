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

/// The half the first pass missed: `previousPushedScreen` is only meaningful if nothing else can
/// leave a value in it. Thirty-odd sites assign `pushedScreen` directly — a tab opening a screen,
/// one screen replacing another, a sign-out clearing it, or SwiftUI writing `nil` back on an
/// interactive dismissal — and none of them maintained it.
@MainActor
@Suite("The way back cannot go stale")
struct PushedScreenStalenessTests {

    private func store() -> AppStore { AppStore(repository: InMemoryRepository()) }

    /// The sequence a reviewer walked: push, dismiss by hand, then open something from a *tab*.
    /// Its back arrow must mean the tabs, not the screen from two navigations ago.
    @Test("A screen dismissed by hand is not restored by a later, unrelated pop")
    func aDismissalForgetsWhatItCovered() {
        let store = store()
        store.pushedScreen = .campHome
        store.push(.profile)

        // SwiftUI writing nil back on an interactive dismissal.
        store.pushedScreen = nil

        store.push(.campSettings)
        store.popPushed()

        #expect(store.pushedScreen == nil)
    }

    @Test("Replacing one screen with another forgets the first")
    func aDirectReplacementForgets() {
        let store = store()
        store.pushedScreen = .campHome
        store.push(.profile)

        // A direct assignment, the way most of the app navigates.
        store.pushedScreen = .rank
        store.popPushed()

        #expect(store.pushedScreen == nil)
    }

    /// And the case it exists for still works after all that.
    @Test("A push still remembers what it covered")
    func aPushStillRemembers() {
        let store = store()
        store.pushedScreen = .campHome
        store.push(.profile)
        store.popPushed()

        #expect(store.pushedScreen == .campHome)
    }
}
