//
//  StaffIdentityTests.swift
//  SycamoreTests
//
//  `coaches.name` and `coaches.phone` are a copy of the profile, taken once when somebody joins a
//  camp. Nothing kept the copy in step, so renaming yourself in Profile changed what *you* saw and
//  nothing anybody else did — the Staff list, the staff sheet and every coach chip went on showing
//  the name you signed up with. The one person who could not see the bug was the one who caused it,
//  which is why it survived this long.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("A rename reaches the camp's staff row")
struct StaffIdentityTests {

    /// A camp whose only staff member is the signed-in account, which is what creating a camp
    /// produces: `createCamp` writes the creator in as its first admin, out of the profile.
    /// The staff row carries the *same* name and phone as the account, because that is what
    /// `createCamp` and `joinCamp` produce — they copy both out of the profile. A fixture where
    /// the two already disagree would be testing a state the app cannot reach, and the first
    /// draft of this file did exactly that: it gave the coach a phone the profile never had, then
    /// read the sync clearing it as a bug rather than as the rule working.
    private func signedIn() -> (AppStore, Account, StaffMember.ID) {
        var camp = Fixture.camp([.init("Home", courts: 2)], players: 4)
        var account = Account(email: "alex@uclacamp.org", displayName: "Alex Ramos")
        account.emergencyPhone = "555 0101"
        var me = StaffMember(accountID: account.id, name: "Alex Ramos", role: .admin)
        me.phone = "555 0101"
        camp.staff = [me]

        let store = AppStore(repository: InMemoryRepository(accounts: [account], camps: [camp]))
        store.auth = .signedIn(account)
        store.camp = camp
        return (store, account, me.id)
    }

    @Test("Changing your display name changes the name the camp shows for you")
    func renameReachesTheStaffRow() async throws {
        let (store, account, staffID) = signedIn()

        var renamed = account
        renamed.displayName = "Alex Ramos-Vega"
        await store.updateAccount(renamed)

        #expect(store.errorMessage == nil)
        #expect(store.account?.displayName == "Alex Ramos-Vega")
        // The half that was missing.
        #expect(store.camp?.staff(staffID)?.name == "Alex Ramos-Vega")
    }

    @Test("Changing your emergency phone changes the one the camp can call")
    func phoneReachesTheStaffRow() async throws {
        let (store, account, staffID) = signedIn()

        var updated = account
        updated.emergencyPhone = "555 0199"
        await store.updateAccount(updated)

        #expect(store.camp?.staff(staffID)?.phone == "555 0199")
    }

    /// The write is skipped when there is nothing to write. Not an optimisation — a PATCH per
    /// keystroke-settled save on a field nobody touched is a round trip that can fail, and a
    /// failure banner over an edit somebody did not make is worse than the saving.
    @Test("A save that changes neither name nor phone writes nothing to the camp")
    func unchangedIdentityDoesNotWrite() async throws {
        let (store, account, staffID) = signedIn()
        let before = try #require(store.camp)

        var updated = account
        updated.notificationsEnabled.toggle()
        await store.updateAccount(updated)

        #expect(store.camp == before)
        #expect(store.camp?.staff(staffID)?.name == "Alex Ramos")
    }

    /// Somebody who is signed in but standing in no camp — between camps, or having just left
    /// one. The profile still saves; there is simply no copy to bring along.
    @Test("A rename with no camp open still saves the profile")
    func renameWithNoCamp() async throws {
        let account = Account(email: "alex@uclacamp.org", displayName: "Alex Ramos")
        let store = AppStore(repository: InMemoryRepository(accounts: [account]))
        store.auth = .signedIn(account)

        var renamed = account
        renamed.displayName = "Alex Ramos-Vega"
        await store.updateAccount(renamed)

        #expect(store.errorMessage == nil)
        #expect(store.account?.displayName == "Alex Ramos-Vega")
    }

    /// The profile is the source of truth in both directions. Clearing your emergency phone has
    /// to clear the camp's copy too — a camp that went on offering a number you have withdrawn is
    /// the worse half of this bug, not a safe fallback.
    @Test("Clearing your phone clears the one the camp holds")
    func clearingThePhoneClearsTheStaffRow() async throws {
        let (store, account, staffID) = signedIn()

        var updated = account
        updated.emergencyPhone = nil
        await store.updateAccount(updated)

        #expect(store.camp?.staff(staffID)?.phone == nil)
    }
}
