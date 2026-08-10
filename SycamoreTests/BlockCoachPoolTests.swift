//
//  BlockCoachPoolTests.swift
//  SycamoreTests
//
//  Who the app is willing to put on a block, and on a court.
//
//  `BlockCoachPicker.pool(in:venueID:me:)` is a pure function of a camp, and it is the only thing
//  standing between "assign a coach" and "assign *anybody*" — the block editor and Overview's
//  "who has this court?" sheet both offer exactly what it returns and nothing else. So these are
//  not tests of a helper; they are the specification of a permission the screens have no other
//  statement of.
//
//  The case that started it is `theAdminWhoSetTheCampUp` below. `adoptStaffRow`
//  (`SupabaseRepository+Enrolment.swift:44-73`) mints every new member's `coaches` row with
//  `site_id` and `group_id` NULL, and `Role.roamsByDefault` is trainer-only — so a fresh admin
//  matched neither arm of the old venue predicate and could not be assigned to anything, including
//  by themselves. A camp of one admin was a camp where the schedule could not be staffed.
//
//  The other half of these tests is the boundary that must not move with it: a coach standing at
//  the camp's *other* venue is still not offered here, and no widening may list anybody twice.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("BlockCoachPicker — who can be put on a block")
struct BlockCoachPoolTests {

    // MARK: A camp built to order

    private static let sycamore = UUID()
    private static let latc = UUID()

    /// A post to a numbered court. The court's own id is minted per call because nothing here reads
    /// it back — what the sort cares about is `groupNumber`.
    private static func post(_ venueID: Venue.ID, court number: Int) -> CourtAssignment {
        CourtAssignment(
            venueID: venueID,
            venueName: venueID == sycamore ? "Sycamore" : "LATC",
            venueIcon: "🌳",
            groupID: UUID(),
            groupNumber: number,
            groupLabel: "Court \(number)"
        )
    }

    private static func member(
        _ name: String,
        _ role: Role,
        roaming: Bool = false,
        at assignment: CourtAssignment? = nil
    ) -> StaffMember {
        StaffMember(name: name, role: role, isRoaming: roaming, assignment: assignment)
    }

    /// `Fixture`'s camp with nothing in it but the staff.
    ///
    /// No venues and no players: the pool takes a `Venue.ID` and never looks it up, so the courts
    /// these people are posted to exist only on their own `CourtAssignment`. Building the shell by
    /// hand would be a fourth copy of the four literals `Fixture.camp` already chooses.
    private static func camp(_ staff: [StaffMember]) -> Camp {
        var camp = Fixture.camp([], players: 0)
        camp.staff = staff
        return camp
    }

    /// The cast, near enough `SampleData`'s shape without its fifty kids.
    private static let nass = member("Nass", .admin, at: post(sycamore, court: 1))
    private static let alex = member("Alex", .worker, at: post(sycamore, court: 3))
    private static let dana = member("Dana", .trainer, roaming: true)
    private static let kai = member("Kai", .worker, at: post(latc, court: 1))
    /// Nobody has posted her anywhere, and her role does not roam. The invisible case.
    private static let hubert = member("Hubert", .admin)
    private static let yusuf = member("Yusuf", .worker)
    private static let marisol = member("Marisol", .other(label: "front desk"))

    private static let everyone = camp([nass, alex, dana, kai, hubert, yusuf, marisol])

    private static func names(_ people: [StaffMember]) -> [String] { people.map(\.name) }

    private static func pool(me: StaffMember.ID? = nil, at venueID: Venue.ID = sycamore) -> [StaffMember] {
        BlockCoachPicker.pool(in: everyone, venueID: venueID, me: me)
    }

    // MARK: The bug

    /// The whole reason the predicate was widened: somebody makes a camp, is written down as an
    /// admin standing on no court at no venue, opens the block editor and finds themselves absent
    /// from the list of people who could run it.
    @Test("The admin who set the camp up can be put on its blocks")
    func theAdminWhoSetTheCampUp() {
        let camp = Self.camp([Self.hubert])
        let pool = BlockCoachPicker.pool(in: camp, venueID: Self.sycamore, me: Self.hubert.id)

        #expect(Self.names(pool) == ["Hubert"])
    }

    /// And the same person on the same day, before they have signed in anywhere the app can see —
    /// role alone is enough. This is the "assign the *other* admins" half of the same request.
    @Test("An admin with no court is offered whether or not they are the one reading")
    func anAdminWithNoCourt() {
        #expect(Self.names(Self.pool()).contains("Hubert"))
        #expect(Self.names(Self.pool(me: Self.alex.id)).contains("Hubert"))
    }

    // MARK: The boundary that stays put

    @Test("A coach standing at the camp's other venue is not offered here")
    func anotherVenuesCoach() {
        #expect(!Self.names(Self.pool()).contains("Kai"))
        // And the mirror, so this is a fact about the venue asked for rather than about Kai.
        #expect(Self.names(Self.pool(at: Self.latc)).contains("Kai"))
    }

    @Test("A coach posted to this venue is offered, which is what the list was always for")
    func thisVenuesCoach() {
        #expect(Self.names(Self.pool()).contains("Alex"))
    }

    @Test("A roaming trainer belongs to no venue, so every venue may claim them")
    func theRoamer() {
        #expect(Self.names(Self.pool()).contains("Dana"))
        #expect(Self.names(Self.pool(at: Self.latc)).contains("Dana"))
    }

    /// The widening is by role, not by absence. A worker nobody has posted anywhere has a venue the
    /// app does not know, and guessing at it would put them under both venues of a two-venue camp.
    @Test("A worker nobody has posted anywhere stays out until somebody posts them")
    func theUnpostedWorker() {
        #expect(!Self.names(Self.pool()).contains("Yusuf"))
        #expect(!Self.names(Self.pool()).contains("Marisol"))
    }

    // MARK: You

    @Test("You are offered with no court, no venue and no roaming flag")
    func youAreAlwaysOffered() {
        #expect(Self.names(Self.pool(me: Self.yusuf.id)).contains("Yusuf"))
        // At the other venue too — "where I am" is not a question this row has to answer.
        #expect(Self.names(Self.pool(me: Self.yusuf.id, at: Self.latc)).contains("Yusuf"))
    }

    @Test("Your own row comes first, ahead of the coach on court 1")
    func youSortFirst() {
        #expect(Self.names(Self.pool(me: Self.alex.id)).first == "Alex")
        #expect(Self.names(Self.pool(me: Self.yusuf.id)).first == "Yusuf")
        // Nass is on court 1 and would otherwise lead, which is what makes the two above a move.
        #expect(Self.names(Self.pool()).first == "Nass")
    }

    @Test("Nobody is listed twice, however many ways they qualify")
    func noDuplicates() {
        // A roaming admin who is also the person reading satisfies three arms of the predicate.
        let both = Self.member("Ada", .admin, roaming: true)
        let camp = Self.camp([both, Self.nass])
        let pool = BlockCoachPicker.pool(in: camp, venueID: Self.sycamore, me: both.id)

        #expect(Self.names(pool) == ["Ada", "Nass"])
    }

    /// An admin looking at a venue they do not work at has no staff row here, which is the nil
    /// `me` the two views pass down. It must not narrow the list or crash the sort.
    @Test("With no staff record of your own, the rest of the list is unchanged")
    func noStaffRecord() {
        #expect(Self.names(Self.pool(me: nil)) == ["Nass", "Alex", "Dana", "Hubert"])
    }

    // MARK: The order

    @Test("Courts run in order, and the people on none of them come last by name")
    func courtsThenNames() {
        #expect(Self.names(Self.pool()) == ["Nass", "Alex", "Dana", "Hubert"])
    }

    /// `camp.staff` arrives from Postgres in whatever order the read produced, and the same list
    /// drawn two ways round would be a picker whose rows move under a thumb.
    ///
    /// Reversed rather than a second cast written out by hand: the whole cast is covered, and
    /// somebody adding a fourteenth person to `everyone` does not have to remember this test.
    @Test("The order does not depend on the order the camp lists its staff")
    func orderIsIndependentOfInput() {
        let backwards = BlockCoachPicker.pool(
            in: Self.camp(Self.everyone.staff.reversed()),
            venueID: Self.sycamore,
            me: Self.alex.id
        )

        #expect(Self.names(backwards) == Self.names(Self.pool(me: Self.alex.id)))
        #expect(Self.names(backwards) == ["Alex", "Nass", "Dana", "Hubert"])
    }

    @Test("Without a camp there is nobody to offer")
    func noCamp() {
        #expect(BlockCoachPicker.pool(in: nil, venueID: Self.sycamore, me: Self.alex.id).isEmpty)
    }

    // MARK: What the rows say

    /// The same three words `BlockAssigneeList.name(for:)` puts on the logistics card, so the
    /// screen that states who is on a block and the two that choose them agree.
    @Test("Your own row says '· you' after your name, and nobody else's does")
    func theYouSuffix() {
        #expect(BlockCoachPicker.rowTitle(for: Self.alex, me: Self.alex.id) == "Alex · you")
        #expect(BlockCoachPicker.rowTitle(for: Self.nass, me: Self.alex.id) == "Nass")
        // Signed in as nobody the camp knows: every row is a plain name.
        #expect(BlockCoachPicker.rowTitle(for: Self.alex, me: nil) == "Alex")
    }

    @Test("Somebody standing on no court has that said out loud rather than left blank")
    func theNoCourtLine() {
        #expect(BlockCoachPicker.rowDetail(for: Self.hubert) == "Admin · No court")
        #expect(BlockCoachPicker.rowDetail(for: Self.marisol) == "Other · front desk · No court")
    }

    /// Anybody the camp *has* placed keeps the model's own sentence — a court, or "Roaming" for a
    /// trainer, who is standing somewhere on purpose rather than waiting to be posted.
    @Test("A posted coach and a roamer keep the line the model already spells")
    func thePostedLine() {
        #expect(BlockCoachPicker.rowDetail(for: Self.alex) == "Worker · Sycamore · Court 3")
        #expect(BlockCoachPicker.rowDetail(for: Self.dana) == "Trainer · Roaming")
    }
}
