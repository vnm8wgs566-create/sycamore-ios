//
//  AppStoreDeleteCampTests.swift
//  SycamoreTests
//
//  The one irreversible thing in the app.
//
//  Everything else the store writes can be argued with afterwards: a kid dragged to the wrong
//  court is dragged back, a rolled invite code is rolled again, a signed-out account signs in.
//  Deleting a camp takes its venues, its kids, its courts, its tournaments and its schedule with
//  it, takes them from every other member as well, and there is nothing to reload from. So the
//  things worth pinning here are not "does the row work" but the three ways this can be wrong in
//  a way nobody can repair:
//
//  1. **It leaves.** The camp is gone from the repository and gone from the membership list, or
//     the reader deletes a camp and watches it sit there in the picker.
//  2. **Nothing else leaves with it.** The sweep in `InMemoryRepository.deleteCamp` is hand-written
//     — memberships, blocks, inbox rows and court closures live beside the camps rather than inside
//     them, so nothing cascades for free — and a `removeAll` with the predicate left off would pass
//     every test that only looked at the camp being deleted.
//  3. **A failure changes nothing at all.** This intent is deliberately not optimistic (see
//     `AppStore.deleteCamp`), and the value of that decision is entirely in the failing case: the
//     reader must not be shown the camps list, or an emptied membership list, for a delete the
//     server refused.
//
//  The fourth test is the admin gate, and it is honest about what it can reach: the delete row is
//  built inside a `if store.isAdmin` in `CampHomeView.content(for:)`, and a test with no view
//  harness can assert the expression that guard reads and not the guard itself. It is still the
//  gate — `isAdmin` is one property and one call site drives four screens' worth of locking — but
//  it is a test of the condition, not of the drawing.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Deleting a camp")
struct AppStoreDeleteCampTests {

    // MARK: - Fixtures

    /// Alex, administering UCLA, standing on the camp page with the sibling Westside camp also on
    /// the account — which is what makes over-deletion visible at all. A store holding one camp
    /// cannot tell "removed the camp" from "removed everything".
    ///
    /// `pushedScreen` is set because that is where this intent is genuinely raised from: the delete
    /// row lives on `CampHomeView`, which `RootView` presents as `.campHome`, and that screen is
    /// presented by `MainTabView` — which goes away with the camp. A store that never set it could
    /// not catch the case where it is left standing.
    private static func adminStore(
        repository: InMemoryRepository
    ) -> (AppStore, [Membership]) {
        var mine = SampleData.uclaMembership
        mine.role = .admin
        let memberships = [mine, SampleData.westsideMembership]

        let store = AppStore(repository: repository)
        store.auth = .signedIn(SampleData.account)
        store.memberships = memberships
        store.selectedMembership = mine
        store.camp = SampleData.uclaTennisCamp
        store.selectedTab = .groups
        store.pushedScreen = .campHome
        return (store, memberships)
    }

    /// Both sample camps, both of Alex's memberships, and a third membership belonging to somebody
    /// else on the camp being deleted — a camp is not one person's, and the row that says so is the
    /// one most easily forgotten by a delete written from the deleting account's point of view.
    private static func stocked() -> (InMemoryRepository, Account.ID) {
        let otherPerson = Account(email: "nass@uclacamp.org", displayName: "Nass", emergencyPhone: nil)
        var mine = SampleData.uclaMembership
        mine.role = .admin
        let theirs = Membership(
            accountID: otherPerson.id,
            campID: SampleData.uclaTennisCamp.id,
            role: .worker,
            todayAssignment: nil,
            campName: SampleData.uclaTennisCamp.name,
            campIcon: SampleData.uclaTennisCamp.icon,
            campTint: SampleData.uclaTennisCamp.tint,
            campSummary: SampleData.uclaTennisCamp.summaryLine
        )

        let repository = InMemoryRepository(
            accounts: [SampleData.account, otherPerson],
            memberships: [mine, SampleData.westsideMembership, theirs],
            camps: SampleData.camps
        )
        return (repository, otherPerson.id)
    }

    private static func block(at venueID: Venue.ID, titled title: String) -> ScheduleBlock {
        ScheduleBlock(
            venueID: venueID,
            day: .mon,
            startsAt: TimeOfDay(9, 0),
            endsAt: TimeOfDay(10, 0),
            title: title
        )
    }

    // MARK: - It leaves

    @Test("The camp is gone from the repository, not merely gone from the screen")
    func theCampLeavesTheRepository() async throws {
        let (repository, _) = Self.stocked()
        let (store, _) = Self.adminStore(repository: repository)

        await store.deleteCamp()

        #expect(store.errorMessage == nil)
        await #expect(throws: SycamoreError.unknownCamp) {
            _ = try await repository.camp(id: SampleData.uclaTennisCamp.id)
        }
    }

    /// The store's own list, and the repository's answer for *both* people who were in the camp.
    /// A delete that only unhooked the deleting account would leave the other member holding a
    /// membership pointing at nothing — which is a camp in their picker that cannot be opened.
    @Test("Every membership of it goes, not just the deleting account's")
    func everyMembershipGoes() async throws {
        let (repository, otherPersonID) = Self.stocked()
        let (store, _) = Self.adminStore(repository: repository)

        await store.deleteCamp()

        #expect(!store.memberships.contains { $0.campID == SampleData.uclaTennisCamp.id })
        let mine = try await repository.memberships(forAccount: SampleData.account.id)
        #expect(!mine.contains { $0.campID == SampleData.uclaTennisCamp.id })
        let theirs = try await repository.memberships(forAccount: otherPersonID)
        #expect(theirs.isEmpty)
    }

    // MARK: - The reader is put somewhere that exists

    /// `camp == nil` is a routing decision in `RootView.stage`, so this one assertion is the whole
    /// of "sent back to the camps list". The rest is what would otherwise be left pointing at the
    /// camp that no longer exists.
    @Test("The active camp is cleared and the camp page goes with it")
    func theActiveCampIsCleared() async {
        let (repository, _) = Self.stocked()
        let (store, _) = Self.adminStore(repository: repository)

        await store.deleteCamp()

        #expect(store.camp == nil)
        #expect(store.selectedMembership == nil)
        // Left set, this reopens over the *next* camp the reader picks — the bug `signOut()`
        // records in its own comment, arriving by a second route.
        #expect(store.pushedScreen == nil)
        #expect(store.activeSheet == nil)
    }

    /// The sibling camp is the control. Every line of the sweep is a `removeAll` or a `filter` with
    /// a predicate on it, and the failure mode of all four is the same: the predicate is wrong and
    /// takes the neighbours too. Westside keeps its camp, its membership and its schedule.
    @Test("The camp next door is untouched — its graph, its membership and its schedule")
    func theSiblingCampSurvives() async throws {
        let (repository, _) = Self.stocked()
        let westside = SampleData.westsideSwim
        let survivor = Self.block(at: westside.venues[0].id, titled: "Warm-up")
        _ = try await repository.addScheduleBlock(survivor, campID: westside.id)

        let (store, _) = Self.adminStore(repository: repository)
        await store.deleteCamp()

        let stillThere = try await repository.camp(id: westside.id)
        #expect(stillThere.id == westside.id)
        #expect(store.memberships.contains { $0.campID == westside.id })

        let blocks = try await repository.scheduleBlocks(
            forVenue: westside.venues[0].id, day: .mon, campID: westside.id
        )
        #expect(blocks.contains { $0.id == survivor.id })
    }

    // MARK: - A failure changes nothing

    /// The repository has no camps in it at all, so the delete throws before it touches anything —
    /// which is the shape of every real failure here too, because `deleteCamp` is a single
    /// statement that either takes the whole graph or takes none of it.
    ///
    /// Every assertion is the same claim from a different angle: the reader is still standing
    /// exactly where they were, and the only thing that changed is that the app said so.
    @Test("A refused delete leaves the reader in the camp, and says why")
    func aFailureLeavesEverythingStanding() async {
        let repository = InMemoryRepository(
            accounts: [SampleData.account], memberships: SampleData.memberships, camps: []
        )
        let (store, memberships) = Self.adminStore(repository: repository)

        await store.deleteCamp()

        #expect(store.errorMessage == SycamoreError.unknownCamp.errorDescription)
        #expect(store.camp?.id == SampleData.uclaTennisCamp.id)
        #expect(store.selectedMembership != nil)
        #expect(store.memberships.count == memberships.count)
        #expect(store.pushedScreen == .campHome)
    }

    /// The guard, not the drawing. `CampHomeView.content(for:)` builds `deleteCard` inside
    /// `if store.isAdmin`, which is the same one property that locks "Name & season" and hides
    /// "Roll a new code" on the screens either side of it.
    @Test("A coach has no delete — the card is built behind isAdmin, and isAdmin is false")
    func aCoachHasNoDelete() {
        let (repository, _) = Self.stocked()
        let store = AppStore(repository: repository)
        store.auth = .signedIn(SampleData.account)
        // The sample membership's own role, untouched: Alex coaches at UCLA.
        store.selectedMembership = SampleData.uclaMembership
        store.camp = SampleData.uclaTennisCamp

        #expect(SampleData.uclaMembership.role == .worker)
        #expect(store.isAdmin == false)
    }

    /// The store refuses on its own account rather than relying on a screen to be careful. Nothing
    /// draws this row without a camp, but "nothing draws it" is a claim about today's views, and
    /// the intent is public.
    @Test("A store holding no camp deletes nothing and reports nothing")
    func noCampIsNoOp() async {
        let (repository, _) = Self.stocked()
        let store = AppStore(repository: repository)
        store.auth = .signedIn(SampleData.account)

        await store.deleteCamp()

        #expect(store.errorMessage == nil)
        let untouched = try? await repository.camp(id: SampleData.uclaTennisCamp.id)
        #expect(untouched != nil)
    }
}
