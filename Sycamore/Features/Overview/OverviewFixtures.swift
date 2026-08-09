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

    /// The day these fixtures are built for, which is now simply today.
    ///
    /// **A stopgap, not a decision.** It was pinned to Wednesday — the design's own day, and the
    /// only day `SampleData` writes attendance for — "so a preview reads the same on a Sunday".
    /// That held while `Weekday.today` was itself stubbed to Wednesday. It is real now, and
    /// `OverviewScreen` builds its rosters with `store.today`: a pinned fixture day means six days
    /// out of seven the cards say "8 players" from Wednesday's register while the list under them
    /// is drawn from today's, so `+N more` stops adding up to the head-count above it. That
    /// arithmetic is the one thing `OverviewRosterTests` exists to protect, and a preview quietly
    /// breaking it is a preview teaching the wrong shape.
    ///
    /// This trades a preview that was wrong six days a week for one that is *different* seven days
    /// a week, and what it loses is the thing the frame exists to show: nine on the roll, one away,
    /// "8 players" over a list and a `+3 more`. That now only appears on a Wednesday.
    ///
    /// The real fix is upstairs and one line: `AppStore.clock` is `let clock = AppClock()` with no
    /// injection point, even though `AppClock.init(now:)` already takes a date for exactly this
    /// purpose. Make the store's clock settable and this returns to `.wed`, the store is pinned to
    /// a Wednesday morning, and `runningBlock`'s fixed 9:30–10:30 becomes honest rather than merely
    /// unused. `AppStore.swift` belongs to another unit; until it moves, this.
    static var day: Weekday { .today }

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
        detail: "Court 4 net is loose — keep the little ones off it.",
        pinned: true
    )

    /// A second pin, which the design never draws and the screen has to survive.
    ///
    /// The whole point of the fixture: Overview used to banner `inboxItems.first { $0.pinned }` and
    /// silently drop everything behind it, so the state this makes visible is the one that had no
    /// way of being seen.
    static let pinnedNotes: [InboxItem] = [
        pinnedNote,
        InboxItem(
            venueID: SampleData.sycamore.id,
            kind: .note,
            title: "Dana pinned a note",
            detail: "Shade tent is up on the lawn — water breaks there, not by the fence.",
            pinned: true,
            createdAt: .now.addingTimeInterval(-31 * 60)
        ),
    ]

    /// The notes written against Court 1 — what the court screen lists under its own heading.
    ///
    /// Scoped by `groupID`, which is what puts a note on a court. Deliberately *not* scoped by
    /// `pinned`: that column is not backfilled, so every row written before it existed arrives
    /// `false`, and a court whose notes are all unpinned is the ordinary case rather than an edge
    /// one. Hence one of each here — the screen has to read correctly with nothing pinned at all,
    /// which is what the second note on its own would show.
    static let courtNotes: [InboxItem] = [
        InboxItem(
            venueID: SampleData.sycamore.id,
            kind: .note,
            title: "Nass · Court 1",
            detail: "Two in sandals, benched until their shoes turn up.",
            groupID: drills.id,
            pinned: true,
            createdAt: .now.addingTimeInterval(-52 * 60)
        ),
        InboxItem(
            venueID: SampleData.sycamore.id,
            kind: .note,
            title: "Dana · Court 1",
            detail: "Ball machine is on this court until 11 — keep the far tramlines clear.",
            groupID: drills.id,
            createdAt: .now.addingTimeInterval(-9 * 60)
        ),
    ]

    /// What the running block says to do — the block's own `detail`.
    ///
    /// It used to be the note drawn under your own court's header on `8j`, which is where the
    /// design puts it and where `OverviewCourtCard` no longer draws anything: a block runs across
    /// the venue, so what it says to do is not a fact about one court. It is the instruction on
    /// `RunningBlockCard` now, above all four of them.
    private static let blockNote = "Cross-court forehand feeds, then a volley ladder. Cones on the service line."

    /// The block the design's morning is inside — `8i`'s "Skills rotation · until 10:30", with the
    /// three things the header line has nowhere to put: who is on it, what it says, and the notes.
    ///
    /// Its times are fixed rather than arranged around the clock, and that is safe because nothing
    /// resolves this: `OverviewNow` is built from the block directly, and the previews hand the
    /// result to `OverviewScreen` as an argument. `OverviewView` is the half that asks
    /// `ScheduleBlock.running(in:at:)` what time it is, and it has a repository behind it.
    private static let runningBlock = ScheduleBlock(
        venueID: SampleData.sycamore.id,
        day: day,
        startsAt: TimeOfDay(9, 30),
        endsAt: TimeOfDay(10, 30),
        title: "Skills rotation",
        detail: blockNote,
        notes: [
            BlockNote(
                id: UUID(),
                text: "Two nut allergies in the group — nothing shared from the snack table.",
                authorName: "Nass",
                at: .now.addingTimeInterval(-24 * 60)
            ),
            BlockNote(
                id: UUID(),
                text: "Ball machine is on Court 1 until 11 — keep the far tramlines clear.",
                authorName: "Dana",
                at: .now.addingTimeInterval(-9 * 60)
            ),
        ],
        coachIDs: blockCoachIDs
    )

    /// The two the block names, resolved out of the camp so the pills draw real people.
    ///
    /// The people first and their ids from them, rather than the other way round: written as ids
    /// this resolved two coaches, threw the coaches away, and then rebuilt an index over the whole
    /// staff list to find the same two again.
    private static var blockCoaches: [StaffMember] {
        [sycamoreCourts.first, sycamoreCourts.dropFirst().first]
            .compactMap { $0.flatMap { camp.coach(forGroup: $0.id) } }
    }

    private static var blockCoachIDs: [StaffMember.ID] { blockCoaches.map(\.id) }

    /// `8i`'s morning, unpacked — the card's full state.
    static var now: OverviewNow {
        OverviewNow(block: runningBlock, coaches: blockCoaches)
    }

    /// The other end of the card: a block that is only a title and a time. Every camp has these —
    /// a lunch, a briefing — and the card has to read as a card without a single optional filled in.
    static var bareNow: OverviewNow {
        OverviewNow(
            block: ScheduleBlock(
                venueID: SampleData.sycamore.id,
                day: day,
                startsAt: TimeOfDay(12, 0),
                endsAt: nil,
                title: "Lunch"
            ),
            coaches: []
        )
    }

    /// What the header says on a day with nothing running — `OverviewView.venueLine`'s answer,
    /// which is what an unscheduled day and a finished one both get. The running block's own line
    /// is `now.headerLine` and `OverviewScreen` composes it where it draws it, so there is no
    /// fixture for that half to drift from.
    static let venueLine = "Sycamore · 4 courts"

    static func roster(for card: CourtCard, limit: Int) -> CourtRoster {
        TodayCourts.roster(forCourt: card.id, in: camp, day: day, limit: limit)
    }

    /// The `8 of 8` at the head of a card, read out of the same camp the roster comes from.
    ///
    /// Resolved rather than written out, so a preview cannot show a denominator the graph does not
    /// have. `SampleData` derives every court's ceiling from its venue's limits
    /// (`Models.swift:1377`), and the figure the design happens to draw is what that arithmetic
    /// produces for Sycamore — which is worth seeing rather than asserting.
    ///
    /// Expressed through `TodayCourts.capacities(in:)` rather than `camp.group(_:)?.capacity`, for
    /// the reason `roster(for:limit:)` directly above gives about its own read: one implementation
    /// of "how full is this court", so a preview cannot draw a figure the screen would not.
    static func capacity(for card: CourtCard) -> CourtCapacity? {
        CourtCapacity.reading(for: card, capacity: TodayCourts.capacities(in: camp)[card.id])
    }

    /// A court's whole list, as the screen holds it before folding — so a preview can draw the
    /// open state without a `@State` set behind it.
    static func fullRoster(for card: CourtCard) -> CourtRoster {
        TodayCourts.rosters(in: camp, day: day)[card.id] ?? .none
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

    /// The same morning, with the two section-8 lists already in the store.
    ///
    /// `OverviewScreen` takes its courts and its note as arguments and so needs none of this; the
    /// court screen reads both off the store, because it is opened over a tab that has already
    /// loaded them and re-reading on the way in would issue the same query twice to draw one
    /// screen. Its own store, rather than seeding the two above, so the Overview previews keep
    /// showing what their arguments say and nothing else.
    @MainActor
    static var courtStore: AppStore {
        let store = store(as: adminAccount, role: .admin, in: camp)
        store.courts = courts
        store.inboxItems = courtNotes + [pinnedNote]
        return store
    }

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
