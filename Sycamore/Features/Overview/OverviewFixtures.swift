//
//  OverviewFixtures.swift
//  Sycamore
//
//  The design's own morning, so `8i` and `8j` can be drawn exactly in a preview.
//
//  `SampleData` cannot supply this on its own: the section 8 tables were created empty, and
//  `AppStore.preview` resolves against a repository with no rows in them at all. So the four
//  courts the design draws are written out here — over the real camp, with the real group and
//  staff identifiers, so the rosters underneath them come from the same graph the app reads
//  and every count still adds up.
//
//  Previews only. Nothing in the app builds a court from this file.
//

import Foundation

enum OverviewFixtures {

    // MARK: The camp underneath

    static let camp = SampleData.uclaTennisCamp

    /// The design's day is a Wednesday, which is the day `SampleData` writes its attendance
    /// for — pinned rather than taken from the clock so a preview reads the same on a Sunday.
    static let day: Weekday = .wed

    private static var sycamoreCourts: [Group] { camp.groups(in: SampleData.sycamore.id) }

    // MARK: The four courts

    /// `Drills · Court 1 – 8 players · Nass`. Nine kids on the roll, one away, which is what
    /// makes the headcount 8 and the list below it run 1 to 5 then `+3 more`.
    static let drills = court(index: 0, activity: "Drills", coach: "Nass")
    /// `Match play · Court 2 – 6 players · Alina`.
    static let matchPlay = court(index: 1, activity: "Match play", coach: "Alina", here: 6)
    /// `Skills rotation · Court 3 – 8 players · Tom`.
    static let skillsRotation = court(index: 2, activity: "Skills rotation", coach: "Tom", here: 8)
    /// `Net down · Court 4 – Tom is on it`, closed.
    static let netDown = court(
        index: 3, activity: "Net down", coach: nil, here: 0,
        status: .closed(reason: "Tom is on it")
    )
    /// Not in the design. The state the design never draws — a court nobody has yet.
    static let unassigned = court(index: 4, activity: "Free play", coach: nil, here: 7)

    static let courts = [drills, matchPlay, skillsRotation, netDown]

    // MARK: The rest of the screen

    /// The pinned note the design banners above the courts.
    static let pinnedNote = InboxItem(
        venueID: SampleData.sycamore.id,
        kind: .note,
        title: "Nass pinned a note",
        detail: "Court 4 net is loose — keep the little ones off it."
    )

    /// The note under your own court's header on `8j`.
    static let blockNote = "Cross-court forehand feeds, then a volley ladder. Cones on the service line."

    /// The line under the screen's title.
    static let nowLine = "Skills rotation · until 10:30"

    static func roster(for card: CourtCard, limit: Int) -> CourtRoster {
        TodayCourts.roster(forCourt: card.id, in: camp, day: day, limit: limit)
    }

    // MARK: Who is reading

    /// `8i` — an admin, so no court is theirs. A fresh identifier rather than
    /// `SampleData.account`, whose account *is* one of the coaches on this camp.
    static let adminAccount = Account(email: "alex@uclacamp.org", displayName: "Alex Ramos")

    /// `8j` — Nass, who has Court 1. `SampleData` gives its staff no accounts, so this hands
    /// Nass one and signs in as it.
    static let coachAccount = Account(email: "nass@uclacamp.org", displayName: "Nass Ahmed")

    static let coachCamp: Camp = {
        var camp = SampleData.uclaTennisCamp
        if let index = camp.staff.firstIndex(where: { $0.name == "Nass" }) {
            camp.staff[index].accountID = coachAccount.id
        }
        return camp
    }()

    @MainActor
    static var adminStore: AppStore { store(as: adminAccount, role: .admin, in: camp) }

    @MainActor
    static var coachStore: AppStore { store(as: coachAccount, role: .worker, in: coachCamp) }

    // MARK: Builders

    private static func court(
        index: Int,
        activity: String?,
        coach: String?,
        here: Int? = nil,
        status: CourtStatus = .open
    ) -> CourtCard {
        let group = sycamoreCourts[index]
        return CourtCard(
            id: group.id,
            venueID: group.venueID,
            groupName: group.label,
            courtLabel: group.label,
            rankOrder: group.rankOrder,
            coachID: camp.coach(forGroup: group.id)?.id,
            coachName: coach,
            playersHere: here ?? camp.players(inGroup: group.id).count { !camp.isAway($0.id, on: day) },
            activity: activity,
            status: status
        )
    }

    @MainActor
    private static func store(as account: Account, role: Role, in camp: Camp) -> AppStore {
        let membership = Membership(
            accountID: account.id,
            campID: camp.id,
            role: role,
            todayAssignment: nil,
            campName: camp.name,
            campIcon: camp.icon,
            campTint: camp.tint,
            campSummary: camp.summaryLine
        )
        let store = AppStore()
        store.auth = .signedIn(account)
        store.memberships = [membership]
        store.selectedMembership = membership
        store.camp = camp
        store.selectedTab = .overview
        return store
    }
}
