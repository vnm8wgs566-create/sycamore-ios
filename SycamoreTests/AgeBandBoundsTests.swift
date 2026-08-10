//
//  AgeBandBoundsTests.swift
//  SycamoreTests
//
//  `AgeBand` after it stopped being three cases with the pivot welded to twelve.
//
//  The change it guards is a **representation** change with an explicit promise attached: the set
//  of expressible bands got wider, and `admits(_:)` did not move an inch. Every caller in the app
//  asks `admits(_:)` and nothing else — the deal gate in `Camp.admit(_:at:)`, `RosterAgeFit`, the
//  enrolment chips — so a rewrite that quietly changed what a band *means* would have shown up as
//  kids on the wrong courts and nowhere else. `CampAgeBandDealTests` pins the consequence at the
//  camp; this file pins the rule itself, exhaustively, at the type.
//
//  Four things are asked here and nothing else is:
//
//  1. **`admits(_:)` across every combination**, including a nil age at each shape and the pair
//     of nulls. The old three cases are checked in their new spelling, so "12 & up admits 12 and
//     refuses 11" is still a written-down fact rather than an inference from two integers.
//  2. **The derived label**, for all four shapes plus the degenerate closed one. Derived and not
//     stored is the whole reason the enum went, so the four readings are the only place the old
//     enum's words still live.
//  3. **The bounds survive the wire**, out through `siteRow` and back in through `SiteRecord`.
//     Two nullable columns replaced one `not null` text, and a band that reads back differently
//     from the way it was written is a venue that changes its mind on relaunch.
//  4. **The pair is normalised**, because `sites` has two CHECKs about it and a row Postgres
//     refuses surfaces as an opaque 400 on a save button two screens from the stepper.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("AgeBand — a venue picks its own age")
struct AgeBandBoundsTests {

    // MARK: - admits(_:)

    /// The band that is not asking. Everybody, including the kid with no age on file — which is
    /// the asymmetry `admits(_:)`'s own comment argues for at length, and the reason a camp that
    /// never collected ages is not a camp with nobody on any court.
    @Test("An unrestricted band admits every age and every unknown")
    func unrestrictedAdmitsEverybody() {
        let band = AgeBand.all

        #expect(band.isUnrestricted)
        for age in 3...21 {
            #expect(band.admits(age))
        }
        #expect(band.admits(nil))
    }

    /// A ceiling and no floor — the old `.underTwelve`, said in the new shape. The boundary is
    /// inclusive, so eleven is in and twelve is out.
    @Test("A ceiling admits up to and including itself, and refuses an unknown age")
    func ceilingAdmitsUpToItself() {
        let band = AgeBand.upTo(11)

        #expect(!band.isUnrestricted)
        #expect(band.admits(3))
        #expect(band.admits(10))
        #expect(band.admits(11))
        #expect(!band.admits(12))
        #expect(!band.admits(21))
        #expect(!band.admits(nil))
    }

    /// A floor and no ceiling — the old `.twelveUp`. Same inclusivity from the other side.
    @Test("A floor admits from itself upwards, and refuses an unknown age")
    func floorAdmitsFromItselfUp() {
        let band = AgeBand.from(12)

        #expect(!band.isUnrestricted)
        #expect(!band.admits(3))
        #expect(!band.admits(11))
        #expect(band.admits(12))
        #expect(band.admits(21))
        #expect(!band.admits(nil))
    }

    /// The shape the three-case enum could not say at all, and the reason for the change: a venue
    /// closed at both ends. Both bounds inclusive, so 9 and 12 are both in.
    @Test("A closed band admits its ends and nothing outside them")
    func closedBandAdmitsItsEnds() {
        let band = AgeBand.between(9, 12)

        #expect(!band.admits(8))
        #expect(band.admits(9))
        #expect(band.admits(10))
        #expect(band.admits(12))
        #expect(!band.admits(13))
        #expect(!band.admits(nil))
    }

    /// An arbitrary pivot, which is the other half of what was unsayable. Ten, not twelve, and
    /// nothing in the type knows the difference.
    @Test("The pivot is wherever the camp puts it")
    func thePivotIsNotWeldedToTwelve() {
        #expect(AgeBand.upTo(9).admits(9))
        #expect(!AgeBand.upTo(9).admits(10))
        #expect(AgeBand.from(13).admits(13))
        #expect(!AgeBand.from(13).admits(12))
    }

    /// Every shape against every age in one sweep, stated as arithmetic rather than as a list, so
    /// a boundary quietly moving by one has nowhere to hide. The nil age is asked separately
    /// because it is a rule and not a comparison.
    @Test("admits(_:) is exactly `inside both bounds`, over every combination")
    func admitsIsExactlyInsideBothBounds() {
        let bounds: [Int?] = [nil, 3, 9, 11, 12, 21]

        for lower in bounds {
            for upper in bounds {
                let band = AgeBand(minAge: lower, maxAge: upper)
                for age in AgeBand.range {
                    let expected = (band.minAge.map { age >= $0 } ?? true)
                        && (band.maxAge.map { age <= $0 } ?? true)
                    #expect(band.admits(age) == expected, "age \(age) at \(band.label)")
                }
                #expect(band.admits(nil) == band.isUnrestricted, "nil age at \(band.label)")
            }
        }
    }

    // MARK: - The label

    /// The four shapes, in the words the chips and the venue cards draw. Three of them are the old
    /// enum's own strings, kept to the letter: a camp that read "12 & up" yesterday reads it today.
    @Test("The label is derived from the bounds, in all four shapes")
    func labelCoversAllFourShapes() {
        #expect(AgeBand.all.label == "All ages")
        #expect(AgeBand.upTo(11).label == "11 & under")
        #expect(AgeBand.from(12).label == "12 & up")
        #expect(AgeBand.between(9, 12).label == "9–12")
    }

    /// The degenerate closed band. "10–10" is a puzzle; "10 only" is an answer.
    @Test("A band closed on one age reads as that age only")
    func labelForASingleAge() {
        #expect(AgeBand.between(10, 10).label == "10 only")
    }

    // MARK: - Normalising the pair

    /// `sites_age_min_sane` and `sites_age_max_sane` are `between 3 and 21`. A stepper cannot
    /// produce anything outside that, but an import, a stale row or a typo in a fixture can — and
    /// the failure would be a 400 from Postgres on a save button, three screens from the cause.
    @Test("Bounds outside the sane range are clamped rather than sent")
    func boundsAreClampedIntoTheSaneRange() {
        #expect(AgeBand.from(120).minAge == 21)
        #expect(AgeBand.upTo(0).maxAge == 3)
        #expect(AgeBand(minAge: -5, maxAge: 99) == AgeBand.between(3, 21))
    }

    /// `sites_age_bounds_ordered` refuses `12–9`, and so does a reader: a band that admits nobody
    /// is a venue that can never be filled. The upper bound is the one that moves.
    @Test("An inverted pair is put back in order")
    func invertedBoundsAreOrdered() {
        let band = AgeBand(minAge: 15, maxAge: 9)

        #expect(band.minAge == 15)
        #expect(band.maxAge == 15)
        #expect(band.admits(15))
        #expect(band.label == "15 only")
    }

    /// The normalising lives in the memberwise init, which the synthesised `Decodable` conformance
    /// would have walked straight past — and decoding is exactly where an out-of-range pair is
    /// most likely to arrive.
    @Test("A decoded band is normalised like a constructed one")
    func decodingGoesThroughTheSameGate() throws {
        let json = Data(#"{"minAge":40,"maxAge":2}"#.utf8)
        let band = try JSONDecoder().decode(AgeBand.self, from: json)

        #expect(band == AgeBand.between(21, 21))
    }

    /// A round trip through `Codable`, which is how a `Venue` travels whenever anything encodes
    /// one. Four shapes, because the pair of nulls is the one a naive encoding loses.
    @Test("A band survives its own Codable round trip")
    func codableRoundTrip() throws {
        for band in [AgeBand.all, .upTo(11), .from(12), .between(9, 12)] {
            let data = try JSONEncoder().encode(band)
            // Hoisted out of `#expect` for the reason `RosterAgeFitTests` records: the macro
            // decomposes a call into a closure and then refuses the `try` it moved.
            let decoded = try JSONDecoder().decode(AgeBand.self, from: data)
            #expect(decoded == band)
        }
    }
}

// MARK: - The wire

/// Out through `siteRow` and back in through `SiteRecord`, which is the pair of columns
/// `20260810050000_a_venue_picks_its_own_age` added.
///
/// The two halves are written by different files and were previously one column with one spelling
/// each way; a band that reads back differently from the way it was written is a venue that
/// changes its mind on relaunch, and nothing on the screen would say why.
@Suite("AgeBand — through the DTO")
struct AgeBandDTOTests {

    /// `PostgresValue` back to something a decoder can read. Only the two cases these columns can
    /// hold, because anything else arriving in an age column is the test's own bug.
    private static func age(_ value: PostgresValue?) throws -> Int? {
        switch value {
        case .none, .some(.null): nil
        case .some(.int(let number)): number
        default: throw AgeColumnMisread()
        }
    }

    private struct AgeColumnMisread: Error {}

    /// `SiteRecord` decodes from the same snake-cased JSON PostgREST returns, so the round trip
    /// goes through the real key mapping rather than through a memberwise init that would agree
    /// with anything.
    private static func readBack(minAge: Int?, maxAge: Int?) throws -> AgeBand {
        var row: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Sycamore",
            "court_count": 6,
            "icon": "🌳",
            "tint": "moss",
            "coach_min": 1,
            "coach_max": 8,
            "player_min": 0,
            "player_max": 60,
            "sort_index": 0,
            "group_count": 6,
        ]
        row["age_min"] = minAge ?? NSNull()
        row["age_max"] = maxAge ?? NSNull()

        let data = try JSONSerialization.data(withJSONObject: row)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return Venue(try decoder.decode(SiteRecord.self, from: data)).ageBand
    }

    @Test("Every shape of band round-trips through the site row and back")
    func boundsRoundTripThroughTheRow() throws {
        for band in [AgeBand.all, .upTo(11), .from(12), .between(9, 12)] {
            var venue = SampleData.sycamore
            venue.ageBand = band

            let row = SupabaseRepository.siteRow(venue, campID: UUID())
            let minAge = try Self.age(row["age_min"])
            let maxAge = try Self.age(row["age_max"])

            #expect(minAge == band.minAge)
            #expect(maxAge == band.maxAge)

            let readBack = try Self.readBack(minAge: minAge, maxAge: maxAge)
            #expect(readBack == band)
        }
    }

    /// An all-ages venue writes two NULLs rather than a sentinel, which is what makes
    /// `sites_age_bounds_ordered` have nothing to compare and what makes "not asking on that side"
    /// a thing the column itself can say.
    @Test("An unrestricted venue writes two nulls")
    func unrestrictedWritesNulls() {
        var venue = SampleData.sycamore
        venue.ageBand = .all

        let row = SupabaseRepository.siteRow(venue, campID: UUID())

        #expect(row["age_min"] == PostgresValue.null)
        #expect(row["age_max"] == PostgresValue.null)
    }

    /// A database one migration behind has neither column. The decode has to survive it, and the
    /// venue it produces has to be the *permissive* one: dealing every kid is the safe direction
    /// to be wrong in, where a venue that silently narrowed itself would refuse kids nobody
    /// excluded.
    @Test("A row with no age columns at all reads as all ages")
    func missingColumnsReadAsAllAges() throws {
        let band = try Self.readBack(minAge: nil, maxAge: nil)
        #expect(band == .all)
    }
}

// MARK: - InMemoryRepository

/// The offline repository has to carry the bounds too. It is what every preview, every test and
/// the whole of onboarding runs against, so a band it dropped would be a band that worked in the
/// app and vanished everywhere the app is examined.
@Suite("AgeBand — through the in-memory repository")
struct AgeBandInMemoryRepositoryTests {

    @Test("A band written through updateVenue reads back whole")
    func updateVenueRoundTripsTheBand() async throws {
        let camp = SampleData.uclaTennisCamp
        let repository = InMemoryRepository(camps: [camp])

        var venue = camp.orderedVenues[0]
        venue.ageBand = .between(9, 12)

        let updated = try await repository.updateVenue(venue, campID: camp.id)

        #expect(updated.venue(venue.id)?.ageBand == .between(9, 12))
        #expect(updated.venue(venue.id)?.ageBand.label == "9–12")

        // And again from a fresh read, so it is the store that kept it rather than the return
        // value of the write.
        let reread = try await repository.camp(id: camp.id)
        #expect(reread.venue(venue.id)?.ageBand == .between(9, 12))
    }

    /// A venue added beside a narrowed one inherits its band, which is the rule `addVenue` already
    /// states for every other number on a venue. The bounds have to travel with it, not just the
    /// fact that it was narrowed.
    @Test("A new venue inherits the template venue's bounds")
    func addVenueInheritsTheBounds() async throws {
        var camp = SampleData.uclaTennisCamp
        for index in camp.venues.indices {
            camp.venues[index].ageBand = .between(9, 12)
        }
        let repository = InMemoryRepository(camps: [camp])

        let before = Set(camp.venues.map(\.id))
        let grown = try await repository.addVenue(campID: camp.id)
        let created = try #require(grown.venues.first { !before.contains($0.id) })

        #expect(created.ageBand == .between(9, 12))
    }
}
