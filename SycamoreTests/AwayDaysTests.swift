//
//  AwayDaysTests.swift
//  SycamoreTests
//
//  A kid can be out on a day that is not today.
//
//  `8q` drew one toggle — "Mark away today" — over `store.today`, so a parent telling a coach on
//  Monday that their daughter is out on Thursday had nowhere to put it. Every layer underneath was
//  already ready: `attendance` holds one row per kid per day, `Camp.isAway(_:on:)` takes a day, and
//  `repository.setAttendance` takes one. `AppStore.setAway` was the single place the week was
//  collapsed to a day.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("Away, on any day of the camp's week")
struct AwayDaysTests {

    private func loaded() throws -> (AppStore, Player) {
        let camp = SampleData.uclaTennisCamp
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        store.auth = .signedIn(SampleData.account)
        store.selectedMembership = SampleData.uclaMembership
        let player = try #require(camp.orderedPlayers.first { $0.venueID != nil && $0.groupID != nil })
        return (store, player)
    }

    // MARK: The day that is written

    @Test("A day that is not today is the day that gets written")
    func anotherDayIsWritten() async throws {
        let (store, player) = try loaded()
        let other = Weekday.notToday

        await store.setAway(player.id, true, on: other)

        #expect(store.errorMessage == nil)
        #expect(store.isAway(player.id, on: other))
        // And today is untouched, which is the whole point: the kid is on court this morning.
        #expect(store.isAway(player.id) == false)
    }

    @Test("Each day is its own answer")
    func daysAreIndependent() async throws {
        let (store, player) = try loaded()
        let other = Weekday.notToday

        await store.setAway(player.id, true, on: other)
        await store.setAway(player.id, true, on: store.today)
        await store.setAway(player.id, false, on: other)

        #expect(store.isAway(player.id, on: other) == false)
        #expect(store.isAway(player.id))
    }

    /// The toggle reads the day it is about. Before the day was a parameter this could only ever
    /// flip today, so a chip for Thursday would have set Thursday's state from today's.
    @Test("Toggling reads the state of the day it is toggling")
    func togglingReadsItsOwnDay() async throws {
        let (store, player) = try loaded()
        let other = Weekday.notToday

        // Away today, here on the other day. A toggle on the other day must turn it *on*.
        await store.setAway(player.id, true, on: store.today)
        await store.toggleAway(player.id, on: other)

        #expect(store.isAway(player.id, on: other))
        #expect(store.isAway(player.id))
    }

    // MARK: What the feed says about it

    private func activity(_ store: AppStore) -> [InboxItem] {
        store.inboxItems.filter { $0.kind == .activity }
    }

    /// A feed row sits under a heading that already says which day it was written on, so "marked
    /// away" is unambiguous for today and would be a trap for anything else.
    @Test("The row names the day when the day is not today")
    func theRowNamesTheDay() async throws {
        let (store, player) = try loaded()
        let other = Weekday.notToday

        await store.setAway(player.id, true, on: other)

        let row = try #require(activity(store).first)
        #expect(row.title == "\(player.displayName) marked away on \(other.fullName)")
    }

    @Test("Today is still left unsaid")
    func todayIsUnsaid() async throws {
        let (store, player) = try loaded()

        await store.setAway(player.id, true, on: store.today)

        #expect(activity(store).first?.title == "\(player.displayName) marked away")
    }

    /// Unchanged is not news, per day. Two taps on Thursday's chip that land on the same answer
    /// write one row, exactly as two swipes on today's roster already did.
    @Test("Writing the same answer twice on one day writes one row")
    func unchangedWritesNothing() async throws {
        let (store, player) = try loaded()
        let other = Weekday.notToday

        await store.setAway(player.id, true, on: other)
        await store.setAway(player.id, true, on: other)

        #expect(activity(store).count == 1)
    }

    /// And the guard is per day rather than per kid: away on Thursday does not silence the row
    /// saying they are also away today. This is the bug the old `isAway(playerID)` guard would
    /// have had the moment a second day became writable.
    @Test("Away on one day does not silence the row for another")
    func oneDayDoesNotSilenceAnother() async throws {
        let (store, player) = try loaded()

        await store.setAway(player.id, true, on: Weekday.notToday)
        await store.setAway(player.id, true, on: store.today)

        #expect(activity(store).count == 2)
    }
}
