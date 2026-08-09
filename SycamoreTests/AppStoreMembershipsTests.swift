//
//  AppStoreMembershipsTests.swift
//  SycamoreTests
//
//  The store's half of "no camps" versus "not asked yet".
//
//  `memberships` is an empty array on a store that has just launched, on an account that belongs
//  to nothing, and on an account with three camps whose fetch is still out — and the first run
//  reads the last of those as the first (`FirstRunStep`). `hasLoadedMemberships` is what tells
//  them apart, so the thing worth pinning is not what it says but *when* it changes: down until a
//  fetch returns, up whatever the fetch returned, and down again the moment the account it was
//  about signs out.
//
//  That last one is the leak this is really guarding. The flag outliving the account would hand
//  the next person to sign in on the device the previous one's answer, and the wrong first run
//  with it — which on a shared iPad at a camp is the common case rather than the exotic one.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Have we asked for this account's camps yet?")
struct AppStoreMembershipsTests {

    /// Alex, signed in, with both sample camps sitting in the repository waiting to be asked for.
    /// `auth` is set directly rather than driven through the code screen: this is about what a
    /// fetch does to the flag, and the six digits in front of it are `InMemoryRepositoryTests`'.
    private static func signedIn(owning memberships: [Membership]) -> AppStore {
        let store = AppStore(
            repository: InMemoryRepository(
                accounts: [SampleData.account], memberships: memberships
            )
        )
        store.auth = .signedIn(SampleData.account)
        return store
    }

    @Test("A store that has only just launched has asked nobody anything")
    func downAtLaunch() {
        let store = AppStore()

        #expect(store.hasLoadedMemberships == false)
        #expect(store.memberships.isEmpty)
    }

    /// Signing in is not the same event as the camps arriving, which is the whole reason this flag
    /// exists: `finishSignIn` sets `auth` on the line before it awaits them.
    @Test("Being signed in is not on its own an answer about camps")
    func signingInIsNotAnAnswer() {
        let store = Self.signedIn(owning: SampleData.memberships)

        #expect(store.hasLoadedMemberships == false)
    }

    @Test("A fetch that returns raises it, and brings the camps with it")
    func aFetchRaisesIt() async {
        let store = Self.signedIn(owning: SampleData.memberships)

        await store.loadMemberships()

        #expect(store.hasLoadedMemberships)
        #expect(store.memberships.count == SampleData.memberships.count)
    }

    /// The empty answer is still an answer, and it is the one the whole distinction is about — an
    /// account that genuinely belongs to nothing has to get past the hold to the question it needs.
    @Test("An account that belongs to no camp gets an answer all the same")
    func anEmptyAnswerIsStillAnAnswer() async {
        let store = Self.signedIn(owning: [])

        await store.loadMemberships()

        #expect(store.hasLoadedMemberships)
        #expect(store.memberships.isEmpty)
    }

    /// Nothing to ask about, so nothing is asked and nothing is claimed. Without the guard in
    /// `loadMemberships` this would be a store reporting it knows the camps of no account at all.
    @Test("A signed-out store learns nothing by being asked")
    func signedOutLearnsNothing() async {
        let store = AppStore()

        await store.loadMemberships()

        #expect(store.hasLoadedMemberships == false)
    }

    /// The array and the flag go back together or they do not go back at all. Signing out and in
    /// again on the same device is how the next person inherits the last person's first run.
    @Test("Signing out takes the answer with it, not just the camps")
    func signingOutTakesItDown() async {
        let store = Self.signedIn(owning: SampleData.memberships)
        await store.loadMemberships()
        #expect(store.hasLoadedMemberships)

        await store.signOut()

        #expect(store.hasLoadedMemberships == false)
        #expect(store.memberships.isEmpty)
    }
}
