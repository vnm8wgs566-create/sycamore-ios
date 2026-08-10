//
//  CampRemoveGroupTests.swift
//  SycamoreTests
//
//  Removing one court from a venue, and the four things that have to happen together.
//
//  Three of them are visible and one is not, and the invisible one is the reason this file is not
//  a single test:
//
//  1. **The kids stay.** They lose their court and keep their venue, their rank and their row —
//     the same "refused, not removed" rule the age band follows, and for the same reason: a kid
//     nobody can find is worse than a kid nobody has placed.
//  2. **The remaining courts renumber.** `number` is read as "the third court here" and drawn as
//     `C3`, so a venue whose courts read 1, 2, 4 has lost one in a way no screen can explain. The
//     label follows the number, because the label *is* the number with a noun in front of it.
//  3. **A coach on the removed court comes off it.** `CourtAssignment.groupID` is not optional, so
//     an assignment pointing at a court that no longer exists is a row nothing can draw.
//  4. **`groupCount` comes down.** This is the invisible one. `syncGroups(for:)` creates courts up
//     to `groupCount` and runs on every venue upsert, so a venue still claiming four groups while
//     holding three re-creates the removed court on the next edit — and the deletion undoes itself
//     with nobody having asked for it back. The test for it removes a court and then *saves the
//     venue*, because that is the sequence in which the bug would appear.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("Camp.removeGroup")
struct CampRemoveGroupTests {

    /// One venue, `courts` courts, and `kids` kids dealt evenly across them.
    ///
    /// Built through `upsert` and `redistribute` rather than by hand so that the starting state is
    /// one the app actually produces — a court removed from a venue nobody has dealt would prove
    /// nothing about where its kids go.
    private static func camp(courts: Int, kids: Int) -> Camp {
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

        let venueID = camp.venues[0].id
        for index in 0..<kids {
            camp.players.append(
                Player(
                    firstName: "Kid\(index + 1)",
                    lastInitial: "T",
                    age: 12,
                    gender: .x,
                    isReturning: false,
                    venueID: venueID,
                    groupID: nil,
                    overallRank: index + 1,
                    courtRank: index + 1
                )
            )
        }
        camp.redistribute(in: venueID)
        camp.reindex()
        return camp
    }

    // MARK: - The kids

    @Test("The removed court's kids stay at the venue with no group")
    func kidsAreUnassignedAndStay() {
        var camp = Self.camp(courts: 3, kids: 9)
        let venueID = camp.venues[0].id
        let doomed = camp.groups(in: venueID)[1]
        let standing = camp.players(inGroup: doomed.id).map(\.id)
        #expect(standing.count == 3)

        camp.removeGroup(doomed.id, from: venueID)

        let orphaned = camp.players.filter { standing.contains($0.id) }
        #expect(orphaned.count == 3)
        let allUnassigned = orphaned.allSatisfy { $0.groupID == nil }
        let allStillHere = orphaned.allSatisfy { $0.venueID == venueID }
        #expect(allUnassigned)
        #expect(allStillHere)

        // Nobody left the camp and nobody left the venue: the count is the same on both sides.
        #expect(camp.players.count == 9)
        #expect(camp.players(in: venueID).count == 9)
    }

    /// The kids on the *other* courts are not touched. A remove is one court's business, and a
    /// method that re-dealt the venue on the way past would move six kids to fix one.
    @Test("The kids on the other courts do not move")
    func theOtherCourtsAreUntouched() {
        var camp = Self.camp(courts: 3, kids: 9)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)
        let before = camp.players(inGroup: courts[0].id).map(\.id)

        camp.removeGroup(courts[2].id, from: venueID)

        #expect(camp.players(inGroup: courts[0].id).map(\.id) == before)
        #expect(camp.players(inGroup: courts[1].id).count == 3)
    }

    /// Deliberately *not* the court-of-last-resort rule `syncGroups(for:)` follows. That method
    /// lowers a count and says nothing about the kids; this one is somebody pointing at a court,
    /// where the kids are the substance of the decision.
    @Test("The kids are not swept onto the smallest remaining court")
    func kidsAreNotReseated() {
        var camp = Self.camp(courts: 3, kids: 9)
        let venueID = camp.venues[0].id
        let doomed = camp.groups(in: venueID)[0]

        camp.removeGroup(doomed.id, from: venueID)

        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 3])
        #expect(camp.players(in: venueID).count { $0.groupID == nil } == 3)
    }

    // MARK: - Renumbering

    @Test("The courts after the removed one renumber 1...n with no gap")
    func remainingCourtsRenumber() {
        var camp = Self.camp(courts: 4, kids: 8)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)
        #expect(courts.map(\.number) == [1, 2, 3, 4])

        camp.removeGroup(courts[1].id, from: venueID)

        #expect(camp.groups(in: venueID).map(\.number) == [1, 2, 3])
        #expect(camp.groups(in: venueID).map(\.id) == [courts[0].id, courts[2].id, courts[3].id])
    }

    /// The label follows the number, because it is the number with the sport's noun in front of
    /// it. A venue reading "Court 1, Court 2, Court 4" is the same defect as the numbers, one
    /// layer up where a person actually reads it.
    @Test("The labels follow the new numbers, in the sport's own noun")
    func labelsFollowTheNumbers() {
        var camp = Self.camp(courts: 4, kids: 8)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)

        camp.removeGroup(courts[0].id, from: venueID)

        #expect(camp.groups(in: venueID).map(\.label) == ["Court 1", "Court 2", "Court 3"])
    }

    /// A swim camp calls them lanes, and `syncGroups(for:)` names a new one from `sport.groupNoun`.
    /// A relabel that hard-coded "Court" would rename a camp's lanes on the way past.
    @Test("A swim camp's lanes are relabelled as lanes")
    func labelsUseTheSportsNoun() {
        var camp = Self.camp(courts: 3, kids: 6)
        camp.sport = .swim
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)

        camp.removeGroup(courts[0].id, from: venueID)

        #expect(camp.groups(in: venueID).map(\.label) == ["Lane 1", "Lane 2"])
    }

    // MARK: - The venue's count

    @Test("The venue's groupCount comes down by one")
    func groupCountDecrements() {
        var camp = Self.camp(courts: 4, kids: 8)
        let venueID = camp.venues[0].id
        let doomed = camp.groups(in: venueID)[2]

        camp.removeGroup(doomed.id, from: venueID)

        #expect(camp.venue(venueID)?.groupCount == 3)
        #expect(camp.groups(in: venueID).count == 3)
    }

    /// The test the decrement exists for. Without it, the next venue upsert — a rename, a target,
    /// anything — runs `syncGroups(for:)`, finds three courts where the venue claims four, and
    /// creates the fourth back. The deletion would appear to undo itself.
    @Test("Saving the venue afterwards does not resurrect the removed court")
    func syncGroupsDoesNotBringItBack() {
        var camp = Self.camp(courts: 4, kids: 8)
        let venueID = camp.venues[0].id
        let doomed = camp.groups(in: venueID)[1]

        camp.removeGroup(doomed.id, from: venueID)

        var renamed = camp.venues[0]
        renamed.name = "Sycamore North"
        camp.upsert(renamed)

        #expect(camp.groups(in: venueID).count == 3)
        let goneForGood = !camp.groups.contains { $0.id == doomed.id }
        #expect(goneForGood)
    }

    // MARK: - The coach

    @Test("A coach standing on the removed court comes off it")
    func theCoachIsUnassigned() {
        var camp = Self.camp(courts: 3, kids: 9)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)
        camp.staff.append(
            StaffMember(name: "Ada", role: .worker, phone: nil, isRoaming: false)
        )
        let coachID = camp.staff[0].id
        camp.assignStaff(coachID, toGroup: courts[0].id)
        #expect(camp.staff(coachID)?.assignment?.groupID == courts[0].id)

        camp.removeGroup(courts[0].id, from: venueID)

        #expect(camp.staff(coachID)?.assignment == nil)
        // Still on the team, still countable — the same "removed from a court, not from the camp"
        // rule the kids get.
        #expect(camp.staff.count == 1)
    }

    // MARK: - What it refuses

    /// The caller names both the group and the venue because it holds both. A mismatch is a stale
    /// id from a screen that has moved on, and it is not permission to empty a court somewhere
    /// else — which is the one way this method could do real damage.
    @Test("A court belonging to another venue is left alone")
    func aCourtAtAnotherVenueIsIgnored() {
        var camp = Self.camp(courts: 3, kids: 9)
        let first = camp.venues[0].id
        camp.upsert(
            Venue(
                name: "Westside",
                subtitle: nil,
                icon: "🌊",
                tint: .moss,
                courtCount: 2,
                groupCount: 2,
                coachMin: 0,
                coachMax: 99,
                playerMin: 0,
                playerMax: 999,
                sortIndex: 1
            )
        )
        let second = camp.venues[1].id
        let elsewhere = camp.groups(in: second)[0].id

        camp.removeGroup(elsewhere, from: first)

        #expect(camp.groups(in: second).count == 2)
        #expect(camp.groups(in: first).count == 3)
        #expect(camp.venue(first)?.groupCount == 3)
        #expect(camp.venue(second)?.groupCount == 2)
    }

    /// An id nothing matches changes nothing at all — in particular it does not decrement a count
    /// for a court that was never there.
    @Test("An unknown court id changes nothing")
    func anUnknownCourtIsIgnored() {
        var camp = Self.camp(courts: 3, kids: 9)
        let venueID = camp.venues[0].id

        camp.removeGroup(UUID(), from: venueID)

        #expect(camp.groups(in: venueID).count == 3)
        #expect(camp.venue(venueID)?.groupCount == 3)
        #expect(Fixture.courtSizes(camp, in: venueID) == [3, 3, 3])
    }

    /// The last court of a venue. Nothing special happens and that is the assertion: an empty
    /// venue holding all its kids unassigned is a state `8b` and Groups both draw.
    @Test("Removing the only court leaves a venue with its kids and no groups")
    func removingTheLastCourt() {
        var camp = Self.camp(courts: 1, kids: 4)
        let venueID = camp.venues[0].id
        let only = camp.groups(in: venueID)[0].id

        camp.removeGroup(only, from: venueID)

        #expect(camp.groups(in: venueID).isEmpty)
        #expect(camp.venue(venueID)?.groupCount == 0)
        #expect(camp.players(in: venueID).count == 4)
        let allUnassigned = camp.players(in: venueID).allSatisfy { $0.groupID == nil }
        #expect(allUnassigned)
    }

    // MARK: - The denormalised counts

    /// `Group.playerCount` is maintained by `reindex()` and read straight by every card. A remove
    /// that skipped the reindex would leave the surviving courts reporting the head counts they
    /// had before, which is a screen that is simply wrong until something else happens to touch
    /// the camp.
    @Test("The surviving courts' counts are reindexed")
    func countsAreReindexed() {
        var camp = Self.camp(courts: 3, kids: 9)
        let venueID = camp.venues[0].id
        let courts = camp.groups(in: venueID)

        camp.removeGroup(courts[0].id, from: venueID)

        let surviving = camp.groups(in: venueID)
        #expect(surviving.map(\.playerCount) == [3, 3])
        #expect(camp.players(in: venueID).map(\.overallRank) == Array(1...9))
    }
}
