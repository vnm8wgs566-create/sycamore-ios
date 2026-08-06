//
//  CampFixture.swift
//  SycamoreTests
//
//  Camps built to order.
//
//  `SampleData` is the design's camp and the tests below use it where the question is about
//  the real shape — 100 kids, two venues, six courts apiece. But a partition test needs to
//  choose its own player limits to reach a particular branch, and a reindex test needs to
//  choose its own court ranks. Deriving those from the design's fixture would mean asserting
//  against numbers that exist to make a screenshot look right.
//

import Foundation
@testable import Sycamore

enum Fixture {

    /// A venue's shape, minus the parts no test cares about.
    struct VenueSpec {
        var name: String
        var courts: Int
        var playerMin: Int
        var playerMax: Int

        init(_ name: String, courts: Int, min playerMin: Int = 0, max playerMax: Int = 999) {
            self.name = name
            self.courts = courts
            self.playerMin = playerMin
            self.playerMax = playerMax
        }
    }

    /// A camp of `playerCount` kids ranked 1…N, all parked on the first venue's first court.
    ///
    /// Everyone starts in one place on purpose: a test that asserts where `partition()` or
    /// `evenOut()` *put* someone is worthless if they were already there.
    static func camp(_ specs: [VenueSpec], players playerCount: Int) -> Camp {
        var camp = Camp(
            name: "Test Camp",
            sport: .tennis,
            inviteCode: "TST-0001",
            icon: "🌳",
            tint: .moss
        )

        for (index, spec) in specs.enumerated() {
            camp.upsert(
                Venue(
                    name: spec.name,
                    subtitle: nil,
                    icon: "🌳",
                    tint: .moss,
                    groupCount: spec.courts,
                    // Coach limits are irrelevant to every test in this file, and a range wide
                    // enough to never fire keeps `staffingStatus` out of the way.
                    coachMin: 0,
                    coachMax: 99,
                    playerMin: spec.playerMin,
                    playerMax: spec.playerMax,
                    sortIndex: index
                )
            )
        }

        let home = camp.orderedVenues.first
        let court = home.flatMap { camp.groups(in: $0.id).first }
        for rank in stride(from: 1, through: playerCount, by: 1) {
            camp.players.append(
                Player(
                    firstName: "Kid\(rank)",
                    lastInitial: "T",
                    age: 12,
                    gender: .x,
                    isReturning: false,
                    venueID: home?.id,
                    groupID: court?.id,
                    overallRank: rank,
                    courtRank: rank
                )
            )
        }

        camp.reindex()
        return camp
    }

    /// The camp-wide ladder, top to bottom, as the names the fixture gave the kids.
    static func ladder(_ camp: Camp) -> [String] {
        camp.orderedPlayers.map(\.firstName)
    }

    /// How many kids are on each court of `venue`, in the courts' own order.
    static func courtSizes(_ camp: Camp, in venueID: Venue.ID) -> [Int] {
        camp.groups(in: venueID).map { camp.players(inGroup: $0.id).count }
    }

    /// How many kids each venue ended up with, in the venues' own order.
    static func venueSizes(_ camp: Camp) -> [Int] {
        camp.orderedVenues.map { camp.players(in: $0.id).count }
    }
}
