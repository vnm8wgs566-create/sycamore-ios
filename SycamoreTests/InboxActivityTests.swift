//
//  InboxActivityTests.swift
//  SycamoreTests
//
//  The four things a camp does during a day, and the four rows they leave on `8r`.
//
//  Before this, `8r`'s feed had two writers — a note against a block and a pinned message, both
//  of them `.note` — so **not one `.activity` row in the shipped app came from anywhere but a
//  `#Preview`**. The Inbox was reported as broken and was not: it was starved, and the section a
//  reader could not make appear was a section nothing could fill.
//
//  Driven end to end through `AppStore` and `InMemoryRepository` rather than by calling the row
//  builders, because the thing worth pinning is not the sentence — it is that the camp write and
//  the feed row happen together. Each intent makes two writes with no transaction across them, so
//  a test that composed a row without moving the kid would pass while the two halves drifted
//  apart, which is exactly the failure the pairing exists to prevent.
//
//  `logActivity` and not `addInboxItem`, and the difference is `created_at`: Postgres stamps it
//  and throws the client's value away, so the offline build stamps it too. The last suite here is
//  what holds those two together — see `SectionEightRepository.logActivity`.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("AppStore — what the day's work writes to the Inbox")
struct InboxActivityTests {

    /// The design's camp, loaded into a store that shares it with the repository. It is the only
    /// fixture with staff and courts on it, and the rows below are made of both.
    private static func loaded() -> (AppStore, Camp) {
        let camp = SampleData.uclaTennisCamp
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        store.auth = .signedIn(SampleData.account)
        store.selectedMembership = SampleData.uclaMembership
        return (store, camp)
    }

    /// The rows the day wrote, newest first — which is the order the repository answers in.
    private static func activity(_ store: AppStore) -> [InboxItem] {
        store.inboxItems.filter { $0.kind == .activity }
    }

    private static func firstPlayer(_ camp: Camp) throws -> Player {
        try #require(camp.orderedPlayers.first { $0.venueID != nil && $0.groupID != nil })
    }

    // MARK: Marked away

    @Test("Marking a kid away writes the row the design draws")
    func awayWritesARow() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)
        // Bound out rather than nested inside the `#require` below — a `#require` inside a
        // `#require` is a recursive macro expansion and does not compile.
        let groupID = try #require(player.groupID)
        let court = try #require(camp.group(groupID))

        await store.setAway(player.id, true)

        #expect(store.errorMessage == nil)
        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(player.displayName) marked away")
        #expect(row.kind == .activity)
        #expect(row.playerID == player.id)
        #expect(row.groupID == player.groupID)
        #expect(row.venueID == player.venueID)
        // The court is what a reader needs to know where to look; the row carries it in words as
        // well as in `groupID`, because the feed draws text and not ids.
        #expect(row.detail?.contains(court.label) == true)
        // Only `needsAction` rows carry a button, and the column's own CHECK says so.
        #expect(row.actionLabel == nil)
        // History, not a decision — so it stays in the feed rather than landing on `8h`'s
        // cleared list.
        #expect(!row.resolved)
        #expect(!row.pinned)
    }

    /// The camp write and the feed row are one intent, so the graph has to agree with the
    /// sentence. A row saying "marked away" beside a kid who is present is the whole failure this
    /// pairing exists to make impossible.
    @Test("The row and the camp graph say the same thing")
    func rowMatchesTheGraph() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setAway(player.id, true)

        #expect(store.isAway(player.id))
        #expect(Self.activity(store).first?.title.hasSuffix("marked away") == true)
    }

    /// A correction is news too. Left out, "marked away" would stand as the last word on a kid
    /// who came back thirty seconds later, and the next coach would go looking for them.
    @Test("Marking a kid back writes its own row rather than deleting the first")
    func comingBackIsAlsoARow() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setAway(player.id, true)
        await store.setAway(player.id, false)

        #expect(Self.activity(store).map(\.title) == [
            "\(player.displayName) marked here",
            "\(player.displayName) marked away",
        ])
    }

    /// The answer to "do not make the feed noisy": a swipe onto a kid who is already away has
    /// changed nothing, and nothing is not news.
    @Test("Marking a kid away twice writes one row, not two")
    func unchangedWritesNothing() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setAway(player.id, true)
        await store.setAway(player.id, true)

        #expect(Self.activity(store).count == 1)
    }

    // MARK: Early pick-up

    @Test("An early pick-up writes the time the app spells everywhere else")
    func pickupWritesARow() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setEarlyPickup(playerID: player.id, day: .thu, at: TimeOfDay(14, 30))

        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(player.displayName) leaves at 2:30pm")
        #expect(row.playerID == player.id)
        // The day is written out, because a pick-up set for Thursday from a Wednesday is not
        // "today" and would read as a lie the moment it was stored.
        #expect(row.detail?.contains("Thursday") == true)
    }

    /// The one row here that deliberately names no actor. `InboxIconTile` reads an activity row
    /// with a player and no actor as a standing arrangement about that kid and gives it the amber
    /// clock — the glyph the design draws on exactly this row.
    @Test("An early pick-up names no actor, so it keeps the design's amber clock")
    func pickupIsUnattributed() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setEarlyPickup(playerID: player.id, day: .thu, at: TimeOfDay(14, 30))

        // Asserted as the *shape* the tile reads rather than by building a tile and checking its
        // glyph: the symbol is a drawing decision and belongs to `InboxIconTile`, while "a player
        // and no actor" is the promise this row is making to it.
        let row = try #require(Self.activity(store).first)
        #expect(row.actorID == nil)
        #expect(row.playerID != nil)
    }

    @Test("Clearing an early pick-up says so rather than saying nothing")
    func clearingAPickupWritesARow() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setEarlyPickup(playerID: player.id, day: .thu, at: TimeOfDay(14, 30))
        await store.setEarlyPickup(playerID: player.id, day: .thu, at: nil)

        #expect(Self.activity(store).first?.title == "\(player.displayName) staying to the end")
    }

    @Test("Setting the same pick-up time again writes nothing")
    func unchangedPickupWritesNothing() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.setEarlyPickup(playerID: player.id, day: .thu, at: TimeOfDay(14, 30))
        await store.setEarlyPickup(playerID: player.id, day: .thu, at: TimeOfDay(14, 30))

        #expect(Self.activity(store).count == 1)
    }

    // MARK: Moved

    @Test("Moving a kid writes where they went and where they came from")
    func moveWritesARow() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)
        let venueID = try #require(player.venueID)
        let groupID = try #require(player.groupID)
        let from = try #require(camp.group(groupID))
        let to = try #require(camp.groups(in: venueID).first { $0.id != from.id })

        await store.movePlayer(player.id, toVenue: venueID, group: to.id)

        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(player.displayName) → \(to.label)")
        #expect(row.groupID == to.id)
        #expect(row.playerID == player.id)
        // Where they came from is the one fact the title cannot carry, and the only thing that
        // tells a reader whether this is the move they asked for.
        #expect(row.detail?.contains("from \(from.label)") == true)
        // And the graph agrees with the sentence.
        #expect(store.player(player.id)?.groupID == to.id)
    }

    @Test("Moving a kid onto the court they are already on writes nothing")
    func unchangedMoveWritesNothing() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)

        await store.movePlayer(
            player.id, toVenue: try #require(player.venueID), group: player.groupID
        )

        #expect(Self.activity(store).isEmpty)
    }

    /// A move across venues with no court named lands the kid on the venue's smallest court,
    /// chosen inside the graph after this row is composed — so the row names the venue, which is
    /// what is actually known.
    @Test("A move with no court named says which venue instead")
    func moveNamesTheVenue() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)
        let elsewhere = try #require(camp.orderedVenues.first { $0.id != player.venueID })

        await store.movePlayer(player.id, toVenue: elsewhere.id)

        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(player.displayName) → \(elsewhere.name)")
        #expect(row.groupID == nil)
    }

    // MARK: Coaches

    @Test("Putting a coach on a court writes the row the design draws")
    func assignmentWritesARow() async throws {
        let (store, camp) = Self.loaded()
        let staff = try #require(camp.staff.first { $0.groupID == nil })
        let venue = try #require(camp.orderedVenues.first)
        let court = try #require(camp.groups(in: venue.id).first)

        await store.assignStaff(staff.id, toGroup: court.id)

        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(staff.name) → \(court.label)")
        #expect(row.groupID == court.id)
        #expect(row.venueID == venue.id)
        // No kid, so `InboxIconTile` draws the camp-wide tick rather than a person glyph.
        #expect(row.playerID == nil)
        #expect(row.detail?.contains(venue.name) == true)
    }

    /// One tap moves two people. `Camp.assignStaff` runs one coach per court and bumps the
    /// incumbent off it (`Models.swift:1341-1343`), so a row naming only the arrival would leave
    /// the feed silently wrong about the person who came off — and the coach whose court has gone
    /// quiet would find nothing in it.
    @Test("Putting a coach on a taken court names the one coming off it")
    func assignmentNamesTheCoachItReplaces() async throws {
        let (store, camp) = Self.loaded()
        let held = try #require(camp.staff.first { $0.groupID != nil })
        let heldGroupID = try #require(held.groupID)
        let court = try #require(camp.group(heldGroupID))
        let arriving = try #require(camp.staff.first { $0.groupID == nil })

        await store.assignStaff(arriving.id, toGroup: court.id)

        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(arriving.name) → \(court.label)")
        #expect(row.detail?.contains("replaces \(held.name)") == true)
        // And the graph did what the row says it did.
        #expect(store.staffMember(held.id)?.groupID == nil)
    }

    @Test("Taking a coach off a court says so")
    func unassignmentWritesARow() async throws {
        let (store, camp) = Self.loaded()
        let staff = try #require(camp.staff.first { $0.groupID != nil })

        await store.assignStaff(staff.id, toGroup: nil)

        let row = try #require(Self.activity(store).first)
        #expect(row.title == "\(staff.name) off court")
        #expect(row.groupID == nil)
    }

    @Test("Assigning a coach to the court they already have writes nothing")
    func unchangedAssignmentWritesNothing() async throws {
        let (store, camp) = Self.loaded()
        let staff = try #require(camp.staff.first { $0.groupID != nil })

        await store.assignStaff(staff.id, toGroup: staff.groupID)

        #expect(Self.activity(store).isEmpty)
    }

    // MARK: The feed they land in

    /// The whole point of the unit, asserted once: a morning's work reaches `8r` as rows the
    /// screen can bucket, under the heading for the part of the day it is.
    @Test("A morning's work turns up in the feed under today's own heading")
    func rowsReachTheFeed() async throws {
        let (store, camp) = Self.loaded()
        let player = try Self.firstPlayer(camp)
        let staff = try #require(camp.staff.first { $0.groupID == nil })
        let venueID = try #require(player.venueID)
        let court = try #require(camp.groups(in: venueID).first)

        await store.setAway(player.id, true)
        await store.assignStaff(staff.id, toGroup: court.id)

        let contents = InboxContents(items: store.inboxItems, filter: .all)
        let titles = contents.feed.flatMap(\.items).map(\.title)
        #expect(titles.contains("\(player.displayName) marked away"))
        #expect(titles.contains("\(staff.name) → \(court.label)"))
        // Both were written moments ago, so they share one heading — and it is one of the three
        // the design names rather than a date.
        #expect(contents.feed.count == 1)
        let heading = try #require(contents.feed.first?.title)
        #expect(["This morning", "This afternoon", "This evening"].contains(heading))
    }
}

// MARK: - The timestamp the two builds have to agree about

@Suite("InMemoryRepository — logActivity stamps like Postgres")
struct LogActivityStampTests {

    private static func loaded() -> (InMemoryRepository, Camp) {
        let camp = SampleData.uclaTennisCamp
        return (InMemoryRepository(camps: [camp]), camp)
    }

    private static func row(_ camp: Camp, at moment: Date) -> InboxItem {
        InboxItem(
            venueID: camp.orderedVenues[0].id,
            kind: .activity,
            title: "Jonah Reyes marked away",
            createdAt: moment
        )
    }

    /// `inboxRow(_:)` omits `created_at`, so Postgres' `now()` is what a real row carries and the
    /// client's value is discarded on the way past. This build has to answer the same way, or a
    /// phone an hour out files its own morning under everybody else's afternoon — `8r` cuts its
    /// headings on this value.
    @Test("A backdated row is stamped on arrival, the way Postgres would stamp it")
    func stampsOnArrival() async throws {
        let (repo, camp) = Self.loaded()
        let lastYear = Date(timeIntervalSince1970: 1_700_000_000)
        let before = Date.now

        let items = try await repo.logActivity(Self.row(camp, at: lastYear), forCamp: camp.id)

        let stored = try #require(items.first)
        #expect(stored.createdAt != lastYear)
        #expect(stored.createdAt >= before)
    }

    /// And the one door that still takes a caller at their word, because there is a caller that
    /// means it: `InboxView`'s preview harness seeds the design's morning at fixed times, and a
    /// seeding door that stamped everything `.now` would collapse `8r` into a single heading.
    @Test("The seeding door still keeps the timestamp it was given")
    func seedingKeepsItsTimestamp() async throws {
        let (repo, camp) = Self.loaded()
        let lastYear = Date(timeIntervalSince1970: 1_700_000_000)

        let items = try await repo.addInboxItem(Self.row(camp, at: lastYear), forCamp: camp.id)

        #expect(items.first?.createdAt == lastYear)
    }
}
