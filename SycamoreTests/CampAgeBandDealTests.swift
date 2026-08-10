//
//  CampAgeBandDealTests.swift
//  SycamoreTests
//
//  Who a venue's age band actually keeps off its courts.
//
//  `AgeBand`'s header has claimed since it was written that "a kid outside the band is left
//  unassigned and counted rather than dealt somewhere they do not belong", and for a long time
//  nothing in the deal read the band at all: a venue set to `12 & up` split its nine-year-olds
//  across its courts along with everybody else. This file is the claim, written down as tests, so
//  that the next person to touch `deal` finds out immediately rather than at a camp.
//
//  The failure being guarded against has no symptom on the screen. Nothing throws, no count looks
//  wrong, every court is level — the kids are simply the wrong kids, and the only way to notice is
//  to walk onto the court and look at them. That is why the assertions here are about *names* and
//  not only about sizes: a test that checked "five kids on court 1" would have passed against the
//  old behaviour every time.
//
//  Three properties, asked in several shapes:
//
//  1. **Refused, not removed.** A kid the band will not take loses their `groupID` and nothing
//     else. They keep their venue, their rank and their row, and every count of "kids at this
//     venue" still includes them. A band that quietly deleted people from the venue would be a
//     filter, which is exactly what `AgeBand` says it is not.
//  2. **The admitted are still evened.** Removing kids from the deal must not stop it levelling
//     the ones that remain, and the levelling is measured over the admitted only — nine kids over
//     three courts is 3/3/3, not 3/3/3 with two phantom seats held for the refused.
//  3. **`.all` is untouched.** Every existing suite deals `.all` venues, so the gate has to be a
//     no-op there in the strongest sense: same courts, same kids, same order.
//
//  Setup is inline and local rather than through `Fixture.camp`, which gives every kid age 12 —
//  a fixture where nobody is ever refused cannot fail any test in this file.
//

import Testing
@testable import Sycamore

@Suite("Camp deals only the kids a venue's age band admits")
struct CampAgeBandDealTests {

    // MARK: - A camp built around ages

    /// One venue with `courts` courts and a kid per entry in `ages`, ranked in that order and all
    /// parked on court 1.
    ///
    /// Everyone starts in one place for `Fixture.camp`'s stated reason — a test that asserts where
    /// a deal *put* somebody proves nothing if they were already there — and, here, for a second:
    /// starting every kid on a court means "left unassigned" is always a thing the deal *did*, not
    /// a state it inherited.
    ///
    /// The band is written straight onto the stored venue rather than passed to `upsert`, because
    /// `upsert` runs `syncGroups(for:)` and would enforce the band on the way in. That is real
    /// behaviour with a test of its own below; every other test here wants the camp to arrive in
    /// the state the old code would have left it in, so that the deal is the only thing under
    /// examination.
    private static func camp(band: AgeBand, courts: Int, ages: [Int?]) -> Camp {
        var camp = Camp(
            name: "Test Camp",
            sport: .tennis,
            inviteCode: "TST-0001",
            icon: "🌳",
            tint: .moss
        )
        camp.upsert(
            Venue(
                name: "Sycamore",
                subtitle: nil,
                icon: "🌳",
                tint: .moss,
                courtCount: courts,
                groupCount: courts,
                coachMin: 0,
                coachMax: 99,
                playerMin: 0,
                playerMax: 999,
                sortIndex: 0
            )
        )
        camp.venues[0].ageBand = band

        let venueID = camp.venues[0].id
        let firstCourt = camp.groups(in: venueID).first?.id
        for (offset, age) in ages.enumerated() {
            camp.players.append(
                Player(
                    firstName: name(age),
                    lastInitial: "T",
                    age: age,
                    gender: .x,
                    isReturning: false,
                    venueID: venueID,
                    groupID: firstCourt,
                    overallRank: offset + 1,
                    courtRank: offset + 1
                )
            )
        }
        camp.reindex()
        return camp
    }

    /// A kid's name says their age, so an assertion that fails reads as "a nine-year-old is on
    /// court 2" rather than as two unequal arrays of UUIDs. Ranked names would be more precise
    /// about *which* nine-year-old; the tests below never need to know.
    private static func name(_ age: Int?) -> String {
        age.map { "Age\($0)" } ?? "AgeNone"
    }

    /// The kids at `venueID` with no group, by name, in ladder order.
    private static func unassigned(_ camp: Camp, in venueID: Venue.ID) -> [String] {
        camp.players(in: venueID).filter { $0.groupID == nil }.map(\.firstName)
    }

    /// The kids standing on any court of `venueID`, by name, in ladder order.
    private static func seated(_ camp: Camp, in venueID: Venue.ID) -> [String] {
        camp.players(in: venueID).filter { $0.groupID != nil }.map(\.firstName)
    }

    // MARK: - The band decides who is dealt

    /// The sentence the whole change exists to be able to say.
    @Test("A 12 & up venue deals its 12s and leaves the rest unassigned")
    func twelveUpDealsOnlyTheTwelves() {
        var camp = Self.camp(band: .from(12), courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Self.seated(camp, in: venueID) == ["Age14", "Age12", "Age13", "Age12"])
        #expect(Self.unassigned(camp, in: venueID) == ["Age9", "Age8", "Age11"])
    }

    /// The other restricted band, because a gate written around one comparison is a gate that can
    /// be inverted without any test noticing.
    @Test("An 11 & under venue deals its 11s and leaves the rest unassigned")
    func underTwelveDealsOnlyTheYoungOnes() {
        var camp = Self.camp(band: .upTo(11), courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Self.seated(camp, in: venueID) == ["Age9", "Age8", "Age11"])
        #expect(Self.unassigned(camp, in: venueID) == ["Age14", "Age12", "Age13", "Age12"])
    }

    /// Refused is not removed. The venue still holds all seven, the camp still holds all seven, and
    /// the refused three still have their ranks — everything a screen needs to say "three kids at
    /// Sycamore have no group" out loud.
    @Test("A refused kid keeps their venue, their rank and their row")
    func refusedKidsAreStillAtTheVenue() {
        var camp = Self.camp(band: .from(12), courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)
        camp.reindex()

        #expect(camp.players.count == 7)
        #expect(camp.players(in: venueID).count == 7)
        #expect(camp.players(in: venueID).map(\.overallRank) == [1, 2, 3, 4, 5, 6, 7])
        #expect(camp.players.allSatisfy { $0.venueID == venueID })
    }

    // MARK: - The admitted are still evened out

    /// Nine admitted over three courts is 3/3/3. The refused hold no seats: if the deal counted
    /// them the courts would come out 4/4/3 with a gap, or 3/3/3 with two kids left over, and
    /// either shows up here.
    @Test("The admitted kids are levelled to within one, ignoring the refused")
    func admittedKidsAreStillEven() {
        let ages: [Int?] = [12, 8, 13, 9, 14, 15, 12, 16, 12, 17, 18]
        var camp = Self.camp(band: .from(12), courts: 3, ages: ages)
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 3, 3])
        #expect(Self.unassigned(camp, in: venueID).count == 2)
    }

    /// The remainder still goes to the courts that come first — the deal's own rule, which the
    /// filtering must not disturb. Eight admitted over three courts is 3/3/2.
    @Test("The leftovers still land on the first courts")
    func remainderStillFillsFromTheTop() {
        let ages: [Int?] = [12, 8, 13, 9, 14, 7, 15, 16, 17, 18, 19]
        var camp = Self.camp(band: .from(12), courts: 3, ages: ages)
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 3, 2])
    }

    /// Top of the ladder to the first court, still. The band removes people from the ladder; it
    /// does not reorder the ones left on it.
    @Test("The admitted keep their ladder order into the courts")
    func admittedFillTopDownByRank() {
        var camp = Self.camp(band: .from(12), courts: 2, ages: [15, 9, 14, 8, 13, 12])
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)

        camp.redistribute(in: venueID)

        #expect(camp.players(inGroup: courts[0].id).map(\.firstName) == ["Age15", "Age14"])
        #expect(camp.players(inGroup: courts[1].id).map(\.firstName) == ["Age13", "Age12"])
    }

    // MARK: - A missing age

    /// `admits(_:)` refuses a nil age at a restricted band on purpose and its comment carries the
    /// argument. This pins the consequence the deal is responsible for: unassigned, not crashed
    /// and not quietly dealt onto a court whose sign says twelve.
    @Test("A kid with no age is unassigned at a restricted venue")
    func nilAgeIsRefusedByARestrictedBand() {
        var camp = Self.camp(band: .from(12), courts: 2, ages: [13, nil, 14, nil])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Self.seated(camp, in: venueID) == ["Age13", "Age14"])
        #expect(Self.unassigned(camp, in: venueID) == ["AgeNone", "AgeNone"])
    }

    /// The same kid at a venue that is not asking. `.all` admits the unknowns, so a camp that never
    /// collected ages is not a camp with nobody on any court.
    @Test("A kid with no age is dealt at an all-ages venue")
    func nilAgeIsAdmittedByAll() {
        var camp = Self.camp(band: .all, courts: 2, ages: [13, nil, 14, nil])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Self.unassigned(camp, in: venueID).isEmpty)
        #expect(Fixture.courtSizes(camp, in: venueID) == [2, 2])
    }

    /// A whole venue of unknowns at a restricted band: everybody unassigned, no courts, no crash,
    /// and — the part worth pinning — no division by an empty ladder inside the deal.
    @Test("A venue whose kids all lack ages ends with nobody on a court")
    func everyKidRefusedLeavesEveryCourtEmpty() {
        var camp = Self.camp(band: .upTo(11), courts: 3, ages: [nil, nil, nil])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [0, 0, 0])
        #expect(Self.unassigned(camp, in: venueID).count == 3)
    }

    // MARK: - `.all` is untouched

    /// The regression guard for every other suite in this project: an all-ages venue deals exactly
    /// as it always did, ages present, absent and wildly mixed.
    @Test("An all-ages venue deals everybody, as before")
    func allAgesDealsEverybody() {
        var camp = Self.camp(band: .all, courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id

        camp.redistribute(in: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 2, 2])
        #expect(Self.unassigned(camp, in: venueID).isEmpty)
    }

    /// Same camp, both bands, one assertion: the gate is the only difference between them. Written
    /// as a comparison because "`.all` behaves as before" is a claim about two runs, and a hard-
    /// coded expectation only ever describes one.
    @Test("The gate is the whole difference between .all and a restricted band")
    func onlyTheRefusedKidsMove() {
        let ages: [Int?] = [14, 9, 12, 8, 13, 11, 12]
        var open = Self.camp(band: .all, courts: 3, ages: ages)
        var closed = Self.camp(band: .from(12), courts: 3, ages: ages)

        open.redistribute(in: open.venues[0].id)
        closed.redistribute(in: closed.venues[0].id)

        // The admitted four sit in the same order in both camps; only their court sizes differ,
        // because the refused three are no longer taking up seats between them.
        #expect(Self.seated(open, in: open.venues[0].id).count == 7)
        #expect(Self.seated(closed, in: closed.venues[0].id) == ["Age14", "Age12", "Age13", "Age12"])
    }

    // MARK: - Narrowing a band turns out the kids already standing there

    /// The band is a statement about who may stand on these courts, not only about who may walk
    /// onto them next. Saving a venue is where that statement is made, and `upsert` is the path the
    /// venue sheet takes.
    @Test("Narrowing a venue's band turns out the kids who no longer qualify")
    func narrowingTheBandEmptiesTheCourts() {
        var camp = Self.camp(band: .all, courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id
        camp.redistribute(in: venueID)
        #expect(Self.unassigned(camp, in: venueID).isEmpty)

        var narrowed = camp.venues[0]
        narrowed.ageBand = .from(12)
        camp.upsert(narrowed)

        #expect(Self.unassigned(camp, in: venueID) == ["Age9", "Age8", "Age11"])
        #expect(Self.seated(camp, in: venueID) == ["Age14", "Age12", "Age13", "Age12"])
    }

    /// And the turned-out kids stay turned out. `syncGroups(for:)` ends by parking anyone without a
    /// court on the smallest one, which — left ungated — would hand every refused kid straight back
    /// a court within the same call that removed it.
    @Test("The court-of-last-resort does not re-seat a refused kid")
    func syncGroupsDoesNotUndoTheBand() {
        var camp = Self.camp(band: .from(12), courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id
        camp.redistribute(in: venueID)

        // Any venue edit at all re-enters `syncGroups(for:)`; a rename is the least related one
        // that could plausibly be made while the refused kids are sitting there unassigned.
        var renamed = camp.venues[0]
        renamed.name = "Sycamore North"
        camp.upsert(renamed)

        #expect(Self.unassigned(camp, in: venueID) == ["Age9", "Age8", "Age11"])
    }

    /// The other half of that gate, so it is not written as "never seat anybody". An *admitted* kid
    /// with no court is still parked on the smallest one, which is the behaviour a court trim has
    /// always relied on.
    @Test("An admitted kid with no court is still parked on the smallest one")
    func syncGroupsStillSeatsAnAdmittedKid() {
        var camp = Self.camp(band: .from(12), courts: 2, ages: [14, 13, 15])
        let venueID = camp.venues[0].id
        camp.redistribute(in: venueID)

        // Take a court away: its kids fall back to the remaining one rather than into limbo.
        var trimmed = camp.venues[0]
        trimmed.groupCount = 1
        trimmed.courtCount = 1
        camp.upsert(trimmed)

        #expect(Self.unassigned(camp, in: venueID).isEmpty)
        #expect(Fixture.courtSizes(camp, in: venueID) == [3])
    }

    // MARK: - Every other spelling of the deal

    /// A schedule block dealing the venue across a subset of its courts asks the band the same
    /// question. It has to: this is the path `SectionEightRepository` takes for "all kids", and a
    /// gate that only covered the whole-venue verb would leave the band off on the screen where
    /// courts are assigned by hand.
    @Test("Dealing across a court subset refuses the same kids")
    func courtSubsetDealRefusesTheSameKids() {
        var camp = Self.camp(band: .from(12), courts: 4, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID).map(\.id)

        camp.redistribute(in: venueID, across: [courts[0], courts[1]])

        #expect(Fixture.courtSizes(camp, in: venueID) == [2, 2, 0, 0])
        #expect(Self.unassigned(camp, in: venueID) == ["Age9", "Age8", "Age11"])
    }

    /// Levelling a handful of courts turns out the refused kids standing on *those* courts and
    /// nobody else's — the promise `evenOut(_:in:)` has always made about who it touches, now with
    /// the band inside it.
    @Test("Evening out a court subset turns out only the refused kids on those courts")
    func courtSubsetEvenOutRefusesOnlyItsOwn() {
        var camp = Self.camp(band: .from(12), courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)
        // Everyone is on court 1 from the fixture; move three of them to court 3 by hand so that
        // there are refused kids both inside and outside the subset being levelled.
        for id in [camp.players[3].id, camp.players[4].id, camp.players[5].id] {
            guard let index = camp.players.firstIndex(where: { $0.id == id }) else { continue }
            camp.players[index].groupID = courts[2].id
        }

        camp.evenOut([courts[0].id, courts[1].id], in: venueID)

        // Age9 was on court 1 and is turned out. Age8 and Age11 were on court 3, which this verb
        // was told not to touch, so they stay exactly where they were put.
        #expect(Self.unassigned(camp, in: venueID) == ["Age9"])
        #expect(camp.players(inGroup: courts[2].id).map(\.firstName) == ["Age8", "Age13", "Age11"])
    }

    /// The camp-wide verbs go through the same deal, so they inherit the gate. `partition()` is the
    /// one worth pinning: it fills venues by rank without consulting the band — which is the right
    /// division of labour, since a venue's floor still has to be met — and then the per-venue deal
    /// is what refuses to seat the kids who should not be there.
    @Test("Camp-wide even out and partition leave the refused unassigned")
    func campWideVerbsRespectTheBand() {
        var camp = Self.camp(band: .from(12), courts: 3, ages: [14, 9, 12, 8, 13, 11, 12])
        let venueID = camp.venues[0].id

        camp.evenOut()
        #expect(Self.unassigned(camp, in: venueID) == ["Age9", "Age8", "Age11"])

        camp.partition()
        #expect(Self.unassigned(camp, in: venueID) == ["Age9", "Age8", "Age11"])
        #expect(camp.players(in: venueID).count == 7)
    }

    /// A venue with nowhere to put anybody is mid-edit, and the deal has always answered that by
    /// leaving it exactly as it found it. The band does not change what "leave it alone" means:
    /// turning kids out of their courts on the way past would be a second, silent edit.
    @Test("A venue with no courts is left alone, refused kids included")
    func noCourtsChangesNothing() {
        var camp = Self.camp(band: .from(12), courts: 1, ages: [14, 9, 13])
        let venueID = camp.venues[0].id
        let court = camp.groups(in: venueID)[0].id
        camp.groups.removeAll { $0.id == court }

        camp.redistribute(in: venueID)

        #expect(camp.players(in: venueID).allSatisfy { $0.groupID == court })
    }
}
