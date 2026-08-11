//
//  AvatarPersistenceTests.swift
//  SycamoreTests
//
//  The profile photo, from the picker to the next launch.
//
//  It used to go nowhere: `loadPhoto` wrote bytes into `Account.avatarImageData` and
//  `SupabaseRepository.updateAccount` carried them straight back without saving, because
//  `profiles.avatar_url` wants a URL into Storage and there was no bucket to put one in. There is
//  now, so the round trip has two halves and this pins the seam between them.
//
//  Driven against `InMemoryRepository`, which keeps the bytes on the account rather than splitting
//  them across a row and an object — and that is the whole reason `avatarData(for:)` is a separate
//  verb rather than something folded into `account(id:)`. A screen that works against one
//  repository has to work against the other, and the only way to hold them to that is to make the
//  seam a thing both implement.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("The profile photo survives")
struct AvatarPersistenceTests {

    private static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])

    /// Signed in **through the repository**, not by assigning `store.auth`.
    ///
    /// The first draft did the latter and every store test in it failed with "We couldn't find
    /// that account": `InMemoryRepository` only knows the people it has issued, so a store holding
    /// an account the repository never minted can read it and never write it. The same shape as
    /// the setup mistake in `OneTapAddTests` — a local copy that the write cannot see.
    private func signedIn() async throws -> (AppStore, InMemoryRepository, Account) {
        let repository = InMemoryRepository()
        let store = AppStore(repository: repository)
        let account = try await repository.signInWithApple(identityToken: "test")
        store.auth = .signedIn(account)
        return (store, repository, account)
    }

    // MARK: The write

    @Test("Saving a photo keeps it on the account that comes back")
    func savingKeepsIt() async throws {
        let repository = InMemoryRepository()
        var account = try await repository.signInWithApple(identityToken: "test")
        account.avatarImageData = Self.jpeg

        let saved = try await repository.updateAccount(account)

        #expect(saved.avatarImageData == Self.jpeg)
    }

    /// The seam. A repository that split the bytes off the row — which the Postgres one does —
    /// must still answer for them when asked by the verb written for that question.
    @Test("The photo is readable back through avatarData")
    func readableBack() async throws {
        let repository = InMemoryRepository()
        var account = try await repository.signInWithApple(identityToken: "test")
        account.avatarImageData = Self.jpeg
        _ = try await repository.updateAccount(account)

        let fetched = try await repository.avatarData(for: account.id)

        #expect(fetched == Self.jpeg)
    }

    /// Nil means **remove**, not "leave it alone". Treating it as no-change would make the photo
    /// the one thing on the profile screen that cannot be taken back.
    @Test("Clearing the photo clears it")
    func clearingClearsIt() async throws {
        let repository = InMemoryRepository()
        var account = try await repository.signInWithApple(identityToken: "test")
        account.avatarImageData = Self.jpeg
        _ = try await repository.updateAccount(account)

        account.avatarImageData = nil
        _ = try await repository.updateAccount(account)

        #expect(try await repository.avatarData(for: account.id) == nil)
    }

    @Test("Somebody who never set one has none, and that is not a failure")
    func neverSetIsNotAFailure() async throws {
        let repository = InMemoryRepository()
        let account = try await repository.signInWithApple(identityToken: "test")

        #expect(try await repository.avatarData(for: account.id) == nil)
    }

    // MARK: The store

    @Test("Editing a name does not drop the photo")
    func editingANameKeepsThePhoto() async throws {
        let (store, _, _) = try await signedIn()
        var account = try #require(store.account)
        account.avatarImageData = Self.jpeg
        await store.updateAccount(account)

        var renamed = try #require(store.account)
        renamed.displayName = "Alex Rivera"
        await store.updateAccount(renamed)

        #expect(store.errorMessage == nil)
        #expect(store.account?.displayName == "Alex Rivera")
        #expect(store.account?.avatarImageData == Self.jpeg)
    }

    /// A photo that will not download must not stop anybody signing in — it is decoration on one
    /// screen, and the memberships behind it are what decide whether there is an app at all.
    /// `loadAvatar` swallows its own failure for that reason; this is the shape of it.
    @Test("A camp is reachable whether or not a photo comes back")
    func aFailedPhotoDoesNotBlockSignIn() async throws {
        let (store, _, _) = try await signedIn()

        #expect(store.account != nil)
        #expect(store.errorMessage == nil)
        // Never set one, so `loadAvatar` found nothing — and said nothing about it.
        #expect(store.account?.avatarImageData == nil)
    }
}
