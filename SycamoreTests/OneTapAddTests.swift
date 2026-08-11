//
//  OneTapAddTests.swift
//  SycamoreTests
//
//  The `Add` pill on an unassigned row, and the sentence it raises.
//
//  Placing a kid with no group used to mean long-pressing a handle and dragging them onto a card —
//  a pointer gesture, on the one card whose whole job is a list of work to clear. The design draws
//  a pill (`showApp.html:58-69`) and the app now draws one too, with two differences that are the
//  subject of most of what is below: it lands them in the emptiest group rather than the last, and
//  it is absent on the rows where the model would take the kid straight back out.
//

import Foundation
import Testing
@testable import Sycamore

@MainActor
@Suite("One tap places a kid with no group")
struct OneTapAddTests {

    /// A camp with kids standing at a venue and no court, arrived at the way the app arrives at it:
    /// a group is removed and leaves its kids behind.
    ///
    /// **Set up through the model rather than by nilling a `groupID` on `store.camp`.** That was the
    /// first attempt and it silently tests nothing: `store.camp` is a local copy, every write goes
    /// through the repository's own graph, and `perform` overwrites the local one with what comes
    /// back — so a kid taken off a court here is still standing on it where the write can see, and
    /// `movePlayer` takes the "already at this venue, keep their group" branch. The test passed a
    /// stale assertion about a kid who never moved.
    private func loaded(courts: Int, players: Int) -> (AppStore, Camp, Venue) {
        var camp = Fixture.camp([.init("Home", courts: courts)], players: players)
        camp.evenOut()
        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp
        return (store, camp, camp.orderedVenues[0])
    }

    // MARK: Where they land

    /// The pill asks for no particular group, and the model answers with the emptiest one — which
    /// is the whole argument for not transcribing the design's `venue.groups - 1`.
    ///
    /// Arranged so the two answers disagree: court 1 holds one kid, court 2 holds three, and the
    /// kid with no court goes to court 1. The design would have sent them to court 2.
    @Test("A kid with no group lands on the emptiest court, not the last one")
    func landsOnTheEmptiestCourt() async throws {
        let (store, camp, venue) = loaded(courts: 3, players: 6)
        let courts = camp.groups(in: venue.id)

        // 2/2/2 becomes 1/3/2 …
        let moving = try #require(camp.players(inGroup: courts[0].id).first)
        await store.movePlayer(moving.id, toVenue: venue.id, group: courts[1].id)
        // … and then the third court goes, leaving its two kids at the venue with nowhere to stand.
        await store.removeGroup(courts[2].id, from: venue.id)

        let waiting = try #require(store.camp?.players(in: venue.id).first { $0.groupID == nil })
        await store.movePlayer(waiting.id, toVenue: venue.id)

        #expect(store.errorMessage == nil)
        #expect(store.camp?.player(waiting.id)?.groupID == courts[0].id)
        // Stated the other way round as well, because "the emptiest" and "the last" only differ
        // while the sizes do — a later change that evened them out would make the line above pass
        // for the wrong reason.
        #expect(store.camp?.groups(in: venue.id).last?.id != courts[0].id)
    }

    // MARK: What it says afterwards

    /// The regression this file exists for.
    ///
    /// `movePlayer`'s toast used to be built from the `groupID` **argument**, and a one-tap Add
    /// passes none — so a kid who had just been put on court 1 was announced as "Ellis → Home",
    /// naming the venue they had been standing at the whole time. The sentence is now read off the
    /// graph that came back.
    @Test("The toast names the court they landed on, not the venue they were already at")
    func theToastNamesTheCourt() async throws {
        let (store, camp, venue) = loaded(courts: 2, players: 6)
        let courts = camp.groups(in: venue.id)
        await store.removeGroup(courts[1].id, from: venue.id)

        let kid = try #require(store.camp?.players(in: venue.id).first { $0.groupID == nil })
        await store.movePlayer(kid.id, toVenue: venue.id)

        let landed = try #require(store.camp?.player(kid.id)?.groupID)
        let label = try #require(store.camp?.group(landed)?.label)
        #expect(store.toast?.message == "\(kid.displayName) → \(label)")
        #expect(store.toast?.message.contains(venue.name) == false)
    }

    /// And it uses the camp's own word for a court. A camp whose sport calls them lanes was told
    /// "Group 3", because the sentence spelled the noun out rather than reading `Group.label`.
    ///
    /// The relabelling is done by `removeGroup`, which is the only thing that rewrites a label
    /// after the venue was shaped — `Fixture.camp` is a tennis camp, so setting `sport` afterwards
    /// leaves three groups still called courts until something renumbers them.
    @Test("The sentence uses the sport's word for a court")
    func theSentenceUsesTheSportsWord() async throws {
        var camp = Fixture.camp([.init("Home", courts: 3)], players: 6)
        camp.evenOut()
        camp.sport = .swim
        let venue = camp.orderedVenues[0]
        camp.removeGroup(camp.groups(in: venue.id)[2].id, from: venue.id)

        let store = AppStore(repository: InMemoryRepository(camps: [camp]))
        store.camp = camp

        let kid = try #require(camp.players(in: venue.id).first { $0.groupID == nil })
        await store.movePlayer(kid.id, toVenue: venue.id)

        let landed = try #require(store.camp?.player(kid.id)?.groupID)
        let label = try #require(store.camp?.group(landed)?.label)
        #expect(label.hasPrefix(Sport.swim.groupNoun))
        #expect(store.toast?.message.hasSuffix(label) == true)
    }

    /// A move to a *named* group still says that group, which is the drag's path and the one this
    /// change had to leave alone.
    @Test("A named group is still named")
    func aNamedGroupIsStillNamed() async throws {
        let (store, camp, venue) = loaded(courts: 2, players: 6)
        let target = try #require(camp.groups(in: venue.id).last)
        let kid = try #require(camp.orderedPlayers.first)

        await store.movePlayer(kid.id, toVenue: venue.id, group: target.id)

        #expect(store.toast?.message == "\(kid.displayName) → \(target.label)")
    }
}

// MARK: - Which rows get one

@Suite("Which unassigned rows offer one tap")
struct OneTapEligibilityTests {

    /// A kid whose group was removed is a kid the venue still wants, so the pill can keep its
    /// promise.
    @Test("A kid whose group went can be added back in one tap")
    func aRemovedGroupOffersOneTap() {
        #expect(UnassignedReason.groupRemoved.admitsOneTap)
    }

    /// A kid the band refuses cannot. `Camp.admit(_:at:)` runs on every venue upsert and nils the
    /// `groupID` of everybody outside the band — so the tap would appear to work and then quietly
    /// undo itself the next time somebody renamed the venue.
    @Test("A kid the band refuses is offered no pill")
    func anOutsideBandRowOffersNone() {
        #expect(UnassignedReason.outsideBand(.from(12)).admitsOneTap == false)
        #expect(UnassignedReason.outsideBand(.upTo(11)).admitsOneTap == false)
    }

    /// The claim underneath that rule, asserted against the model rather than restated: place a kid
    /// the band refuses, write the venue, and they are standing in no group again.
    @Test("The model takes a band-refused kid straight back out of a group")
    func theModelUndoesIt() throws {
        var camp = Fixture.camp([.init("Home", courts: 2)], players: 4)
        camp.evenOut()
        var venue = camp.orderedVenues[0]
        let kid = try #require(camp.orderedPlayers.first)

        // Nine years old at a venue about to become 12 & up.
        let index = try #require(camp.players.firstIndex { $0.id == kid.id })
        camp.players[index].age = 9
        venue.ageBand = .from(12)
        camp.upsert(venue)
        #expect(camp.player(kid.id)?.groupID == nil)

        // Placed by hand anyway — which the drag can still do.
        let court = try #require(camp.groups(in: venue.id).first)
        camp.movePlayer(kid.id, toVenue: venue.id, group: court.id)
        #expect(camp.player(kid.id)?.groupID == court.id)

        // And then any ordinary write to the venue — a rename — puts them back.
        var renamed = try #require(camp.venue(venue.id))
        renamed.name = "Home Courts"
        camp.upsert(renamed)
        #expect(camp.player(kid.id)?.groupID == nil)
    }
}
