//
//  AppStore.swift
//  Sycamore
//
//  One observable object for the whole app: who is signed in, which camp they picked,
//  the loaded camp graph, which tab is up, what the Groups filters are set to, and
//  which sheet is presented. Views read the derived properties near the bottom and call
//  the intent methods; nothing else talks to the repository.
//
//  The filter and section types live at file scope rather than nested inside `AppStore`
//  so their `CaseIterable`/`Identifiable` conformances stay free of actor isolation.
//  `AppStore.Tab` is a typealias for `AppTab` if you prefer the qualified spelling.
//

import Foundation
import Observation

// MARK: - Navigation and filter vocabulary

enum AuthState: Hashable, Sendable {
    case signedOut
    case awaitingCode(email: String)
    case signedIn(Account)
}

enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview, schedule, groups, inbox

    var id: String { rawValue }

    /// The label inside the selected capsule.
    var title: String {
        switch self {
        case .overview: "Overview"
        case .schedule: "Schedule"
        case .groups: "Groups"
        case .inbox: "Inbox"
        }
    }

    /// SF Symbols standing in for the design's Phosphor set.
    var symbol: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .schedule: "calendar"
        case .groups: "person.3"
        case .inbox: "tray"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .overview: "rectangle.grid.2x2.fill"
        case .schedule: "calendar"
        case .groups: "person.3.fill"
        case .inbox: "tray.fill"
        }
    }
}

/// The screens section 8 pushes *over* the tabs instead of giving them a tab of their own.
///
/// Rank, Setup and Profile each had a tab before this. Section 8 spends all four on the things
/// you touch during a session — Overview, Schedule, Groups, Inbox — and reaches the rest from
/// the avatar in the header, which is also what finally gives that header control a
/// destination. The old bell had none.
///
/// The first three are presented as sheets rather than pushed inside a tab: the design draws no
/// tab bar on any of them, and none of them draws a back control either — they never needed one
/// as tabs. The sheet is what supplies the way out.
///
/// The last two are the opposite case and arrive as covers. See `isFullScreen`, and
/// `RootView.pushedView(for:)` for both.
///
/// No longer `String`-backed, and no longer `CaseIterable`: `8m` needs the courts it is marking
/// and `8q` needs the kid, so two of these five carry a payload and neither a raw value nor
/// `allCases` can survive that. Nothing asked for either — the raw value existed only to spell
/// `id`, which is now written out below.
enum PushedScreen: Identifiable, Hashable, Sendable {
    /// `8s` — the avatar's destination.
    case profile
    /// `8t` — admin only, reached from Profile.
    case campSettings
    /// Section 8 folds ranking into Groups (`8o` is titled "Kids in ranking order"), so this
    /// screen has no home in the new navigation. It stays reachable so the reorder logic keeps
    /// running and keeps being testable until Groups absorbs it.
    case rank
    /// `8m` — attendance for one session, reached from a block on `8l`.
    ///
    /// A block runs across courts ("Courts 1–3"), so this carries the whole list rather than one,
    /// and the block itself so the header can name the session. The block is optional because the
    /// screen is legible without one: a coach marking their own court off the clock has courts but
    /// no session.
    case attendance([Group.ID], ScheduleBlock?)
    /// `8q` — a kid.
    case player(Player.ID)

    /// Written out rather than derived, because two of these cases carry a payload and the
    /// payload is what makes them different screens. An `id` that ignored it would leave `8q`
    /// showing the first kid when a second was asked for — SwiftUI reads `.sheet(item:)` as
    /// "still the same presentation" and never rebuilds the content.
    var id: String {
        switch self {
        case .profile: return "profile"
        case .campSettings: return "camp-settings"
        case .rank: return "rank"
        case .attendance(let groupIDs, let block):
            let courts = groupIDs.map(\.uuidString).joined(separator: "+")
            return "attendance-\(courts)-\(block?.id.uuidString ?? "no-block")"
        case .player(let id): return "player-\(id.uuidString)"
        }
    }

    /// Whether the screen supplies its own way out, and so wants the whole frame.
    ///
    /// `8m` draws a ✕ and `8q` a back caret; both run a white header up under the status bar and
    /// pin a bar to the bottom edge. A sheet would inset the header behind rounded corners, put
    /// its own dismissal chrome beside a control that already exists, and float a grabber over a
    /// screen that draws a mock status bar. The other three have none of that and stay sheets.
    var isFullScreen: Bool {
        switch self {
        case .attendance, .player: true
        case .profile, .campSettings, .rank: false
        }
    }
}

/// What is left of stage 3 that the root still presents. Both slide up over whichever tab is
/// showing.
///
/// `8n` and `8q` were the other two, and each left for its own reason. `8q` is a pushed screen in
/// the design — serif title, back caret, pinned bar — and it now arrives that way through
/// `PushedScreen.player`. `8n` is reached only from `8m` or `8q`, and a presented screen cannot
/// ask the root underneath it to present over it, so both of those present their own copy.
enum ActiveSheet: Identifiable, Hashable, Sendable {
    case venue(Venue.ID)
    case staff(StaffMember.ID)

    var id: String {
        switch self {
        case .venue(let id): "venue-\(id.uuidString)"
        case .staff(let id): "staff-\(id.uuidString)"
        }
    }

    /// The detent fractions transcribed from the design's sheet heights over 700pt.
    var detentFraction: Double {
        switch self {
        case .venue: 0.87
        case .staff: 0.73
        }
    }
}

/// The first chip row on Groups.
enum VenueFilter: Hashable, Sendable {
    case all
    case venue(Venue.ID)
}

/// The second, divided chip row on Groups.
enum PlayerFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case everyone, boys, girls, leavingEarly, away

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyone: "Everyone"
        case .boys: "Boys"
        case .girls: "Girls"
        case .leavingEarly: "Leaving early"
        case .away: "Away"
        }
    }
}

/// The chip row above Setup's staff card.
enum StaffFilter: Hashable, Sendable {
    case all
    case venue(Venue.ID)
    case unassigned
}

// MARK: - Derived shapes the screens draw

struct VenueChip: Identifiable, Hashable, Sendable {
    let id: String
    let filter: VenueFilter
    /// The venue emoji, or nil for the "All" chip.
    let icon: String?
    let title: String
    let count: Int
}

struct StaffChip: Identifiable, Hashable, Sendable {
    let id: String
    let filter: StaffFilter
    let icon: String?
    /// Empty for a venue chip — Setup writes those as just `🌳 6`.
    let title: String
    let count: Int
}

struct PlayerRow: Identifiable, Hashable, Sendable {
    let id: Player.ID
    let player: Player
    /// Court rank inside a coach card, overall rank inside a Rank section.
    let rank: Int
    let isAway: Bool
    let leavesAt: TimeOfDay?

    var isLeavingEarly: Bool { leavesAt != nil }
}

struct GroupsCoachCard: Identifiable, Hashable, Sendable {
    let id: Group.ID
    let group: Group
    let coach: StaffMember?
    let rows: [PlayerRow]
}

struct GroupsVenueSection: Identifiable, Hashable, Sendable {
    let id: Venue.ID
    let venue: Venue
    /// The venue's whole roster, not the filtered count — the header reads "50 kids".
    let playerCount: Int
    let cards: [GroupsCoachCard]
}

/// Everything `AppStore.groupsSections` looks at, boiled down to something cheap to
/// compare. `campRevision` stands in for the graph — it changes on every write to
/// `AppStore.camp` and on nothing else. At file scope so its `Hashable` conformance
/// stays free of actor isolation, like the filter types above.
struct GroupsSectionsKey: Hashable, Sendable {
    let campRevision: Int
    let venueFilter: VenueFilter
    let playerFilter: PlayerFilter
    let searchText: String
}

/// The same for `AppStore.rankSections`, which reads less: Rank shows the whole ladder and takes
/// none of the Groups filters, so the graph and the day are all of it.
struct RankSectionsKey: Hashable, Sendable {
    let campRevision: Int
    let day: Weekday
}

struct RankSection: Identifiable, Hashable, Sendable {
    let id: Venue.ID
    let venue: Venue
    /// `1–50`
    let rangeLabel: String
    let rows: [PlayerRow]
}

// MARK: - Store

@MainActor
@Observable
final class AppStore {

    typealias Tab = AppTab

    /// Fixed for the life of the process in a release build — the only writer is the debug
    /// sign-in bypass below, which swaps Postgres for the offline store so the app it drops you
    /// into is one you can actually use.
    @ObservationIgnored private(set) var repository: SycamoreRepository

    // MARK: Auth

    var auth: AuthState = .signedOut
    /// Screen 1's email field.
    var emailInput: String = ""
    /// Screen 2's six cells, held as one string of digits.
    var codeInput: String = ""
    /// Seconds left on `Resend in 0:42`.
    var resendSeconds: Int = 0

    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    // MARK: Camp selection

    var memberships: [Membership] = []
    var selectedMembership: Membership?

    /// The graph itself, held outside observation, plus the counter that stands in for
    /// it. Every write to `camp` bumps the counter, so a cheap `Int` identifies the
    /// state of a hundred players — which is what lets `groupsSections` memoise.
    @ObservationIgnored private var campStorage: Camp?
    private var campRevision: Int = 0

    /// The loaded graph. Nil means we are still on the camp picker.
    ///
    /// Computed rather than stored so no mutation can slip past the revision counter:
    /// reading it registers a dependency on `campRevision`, and writing it drops both
    /// section memos. Observation behaves exactly as it did when this was a plain stored
    /// property.
    ///
    /// Dropping them is belt and braces — `campRevision` is part of both keys, so a stale entry
    /// could never be returned — but a superseded graph has no business staying alive in a cache
    /// until the next read happens to evict it.
    var camp: Camp? {
        get {
            _ = campRevision
            return campStorage
        }
        set {
            campStorage = newValue
            campRevision &+= 1
            groupsSectionsMemo = nil
            rankSectionsMemo = nil
        }
    }

    /// Screen 3's code field and screen 4's two answers.
    var joinCodeInput: String = ""
    var campDraft = CampDraft()

    // MARK: Navigation

    /// Overview rather than Groups: section 8 orders the tabs by what you open the app to see,
    /// and "every court, its coach and its kids" is the answer to that on a camp morning.
    var selectedTab: Tab = .overview
    var activeSheet: ActiveSheet?
    /// Profile, Camp settings, Manage camps and (for now) Rank. One at a time — the design
    /// never stacks two of them.
    var pushedScreen: PushedScreen?

    // MARK: Section 8's three reads
    //
    // Held here rather than in each screen's `@State` so that a write on one tab is visible on
    // another: resolving an Inbox item that reassigns a court has to change what Overview draws,
    // and two views each owning their own copy is how those quietly disagree.
    //
    // Loaded lazily by the screens that need them — `camp(id:)` already pulls the whole camp
    // graph on open, and folding three more round-trips into that would slow the one load a
    // person actually waits on.

    var courts: [CourtCard] = []
    var scheduleBlocks: [ScheduleBlock] = []
    var inboxItems: [InboxItem] = []

    /// What `8r`'s "Needs you · 2" counts, and the badge Inbox shows on the tab bar.
    ///
    /// Deliberately not filtered by the chip selection: the count is about what is waiting, and
    /// tapping "Notes" must not make the app claim nothing needs you while two things do.
    var openInboxCount: Int {
        inboxItems.count { $0.kind == .needsAction && !$0.resolved }
    }

    // MARK: Groups filters

    var venueFilter: VenueFilter = .all
    var playerFilter: PlayerFilter = .everyone
    var searchText: String = ""
    /// Coach cards start expanded; this holds the ones the user folded away.
    var collapsedGroupIDs: Set<Group.ID> = []

    // MARK: Setup filter

    var staffFilter: StaffFilter = .all

    // MARK: Early pick-up draft (screen 10)

    /// What the "New pick-up" card on `8n` is currently offering. Nothing primes these before the
    /// sheet opens: `8n` seeds itself, loading a day's saved time as that day is picked, and the
    /// pick-ups already on the books are read from `camp` rather than from here.
    var pickupDay: Weekday = .today
    var pickupTime: TimeOfDay = TimeOfDay(14, 30)

    // MARK: Status

    var isWorking = false
    var errorMessage: String?

    // MARK: Memo

    /// Last result of `groupsSections` and the inputs that produced it. Outside
    /// observation: filling it in during a `body` pass must not itself invalidate the
    /// view that is reading it.
    @ObservationIgnored
    private var groupsSectionsMemo: (key: GroupsSectionsKey, sections: [GroupsVenueSection])?

    /// The same, for `rankSections`. Its key is smaller because Rank takes no filters — it is
    /// always the complete ladder — so the graph and the day are the whole of what it reads.
    @ObservationIgnored
    private var rankSectionsMemo: (key: RankSectionsKey, sections: [RankSection])?

    init(repository: SycamoreRepository = InMemoryRepository()) {
        self.repository = repository
    }
}

// MARK: - Reads

extension AppStore {

    var today: Weekday { .today }

    var account: Account? {
        if case .signedIn(let account) = auth { return account }
        return nil
    }

    var isSignedIn: Bool { account != nil }

    /// The initials in every tab header's avatar. Empty rather than nil when signed out, so the
    /// header has one less state to reason about — `ScreenHeader` hides an empty disc anyway.
    var avatarInitials: String { account?.initials ?? "" }

    /// The address screen 2 prints in "We sent a code to …".
    var pendingEmail: String? {
        if case .awaitingCode(let email) = auth { return email }
        return nil
    }

    var role: Role? { selectedMembership?.role }
    var isAdmin: Bool { role?.isAdmin == true }

    /// The signed-in person's own staff row in the current camp — the Profile header
    /// and "ON TODAY" card read from it.
    var myStaffRecord: StaffMember? {
        guard let camp, let account else { return nil }
        return camp.staff.first { $0.accountID == account.id }
    }

    var todayAssignment: TodayAssignment? { selectedMembership?.todayAssignment }

    /// `2 camps on this account`
    var switchCampDetail: String {
        "\(memberships.count) camp\(memberships.count == 1 ? "" : "s") on this account"
    }

    // MARK: Sign-in derived

    /// Six entries, empty string for a cell with no digit yet.
    var codeDigits: [String] {
        let digits = Array(codeInput.filter(\.isNumber).prefix(6))
        return (0..<6).map { $0 < digits.count ? String(digits[$0]) : "" }
    }

    /// The cell with the blinking caret; 6 once every digit is in.
    var focusedCodeIndex: Int { min(codeInput.filter(\.isNumber).count, 5) }
    var isCodeComplete: Bool { codeInput.filter(\.isNumber).count == 6 }
    var canResend: Bool { resendSeconds <= 0 }

    /// `Resend in 0:42`, then `Resend code` once the window closes.
    ///
    /// `Duration`'s format style rather than `String(format:)`: the C-style version hard-coded
    /// a colon and Western digits, which is not what every locale writes a duration with.
    var resendLabel: String {
        guard resendSeconds > 0 else { return "Resend code" }
        let remaining = Duration.seconds(resendSeconds)
        return "Resend in \(remaining.formatted(.time(pattern: .minuteSecond)))"
    }

    /// Whether screen 1's "Email me a code" is live. Shares `EmailAddress` with the rule
    /// `requestSignInCode` enforces, so the button cannot be enabled for an address the
    /// repository is certain to reject — the two used to state the rule separately and were
    /// only equal by coincidence.
    var canSubmitEmail: Bool {
        EmailAddress.isValid(emailInput)
    }

    // MARK: Graph lookups

    func player(_ id: Player.ID) -> Player? { camp?.player(id) }
    func venue(_ id: Venue.ID) -> Venue? { camp?.venue(id) }
    func group(_ id: Group.ID) -> Group? { camp?.group(id) }
    func staffMember(_ id: StaffMember.ID) -> StaffMember? { camp?.staff(id) }
    func coach(forGroup id: Group.ID) -> StaffMember? { camp?.coach(forGroup: id) }

    func isAway(_ id: Player.ID) -> Bool { camp?.isAway(id, on: today) == true }
    func leavesAt(_ id: Player.ID) -> TimeOfDay? { camp?.leavesAt(id, on: today) }
    func history(for id: Player.ID) -> [HistoryEvent] { camp?.history(for: id) ?? [] }

    func isCollapsed(_ id: Group.ID) -> Bool { collapsedGroupIDs.contains(id) }

    // MARK: Chips

    /// `All 100` · `🌳 Sycamore 50` · `🎾 LATC 50`
    var venueChips: [VenueChip] {
        guard let camp else { return [] }
        var chips = [
            VenueChip(id: "all", filter: .all, icon: nil, title: "All", count: camp.playerCount)
        ]
        for venue in camp.orderedVenues {
            chips.append(
                VenueChip(
                    id: venue.id.uuidString,
                    filter: .venue(venue.id),
                    icon: venue.icon,
                    title: venue.name,
                    count: camp.players(in: venue.id).count
                )
            )
        }
        return chips
    }

    /// `All 14` · `🌳 6` · `🎾 4` · `Unassigned 4`
    var staffChips: [StaffChip] {
        guard let camp else { return [] }
        var chips = [
            StaffChip(id: "all", filter: .all, icon: nil, title: "All", count: camp.staffCount)
        ]
        for venue in camp.orderedVenues {
            chips.append(
                StaffChip(
                    id: venue.id.uuidString,
                    filter: .venue(venue.id),
                    icon: venue.icon,
                    title: "",
                    count: camp.coachCount(in: venue.id)
                )
            )
        }
        chips.append(
            StaffChip(
                id: "unassigned",
                filter: .unassigned,
                icon: nil,
                title: "Unassigned",
                count: camp.unassignedStaff().count
            )
        )
        return chips
    }

    // MARK: Groups tab

    /// Venue sections, each holding one card per coached court, filtered by the venue
    /// chips, the attribute chips and the search field together.
    ///
    /// Memoised: building this walks all hundred players once per court, and `body`
    /// asks for it on every pass — including passes caused by a scroll, which change
    /// none of its inputs. The key is read in full before the cache is consulted so a
    /// hit still registers the same observation dependencies as a miss.
    var groupsSections: [GroupsVenueSection] {
        let key = GroupsSectionsKey(
            campRevision: campRevision,
            venueFilter: venueFilter,
            playerFilter: playerFilter,
            searchText: searchText
        )
        if let memo = groupsSectionsMemo, memo.key == key { return memo.sections }
        let sections = computeGroupsSections()
        groupsSectionsMemo = (key, sections)
        return sections
    }

    private func computeGroupsSections() -> [GroupsVenueSection] {
        guard let camp else { return [] }
        let term = searchText.trimmingCharacters(in: .whitespaces)
        let isNarrowing = !term.isEmpty || playerFilter != .everyone

        return camp.orderedVenues.compactMap { venue -> GroupsVenueSection? in
            if case .venue(let selected) = venueFilter, selected != venue.id { return nil }

            let cards: [GroupsCoachCard] = camp.groups(in: venue.id).compactMap { group in
                let coach = camp.coach(forGroup: group.id)
                // A coach's name matching the search keeps their whole card intact.
                let coachMatches = !term.isEmpty && (coach?.matches(search: term) ?? false)
                let rows = camp.players(inGroup: group.id)
                    .filter { passes(playerFilter, $0) }
                    .filter { term.isEmpty || coachMatches || $0.matches(search: term) }
                    .map { row(for: $0, rank: $0.courtRank) }

                if rows.isEmpty && isNarrowing && !coachMatches { return nil }
                if rows.isEmpty && coach == nil { return nil }
                return GroupsCoachCard(id: group.id, group: group, coach: coach, rows: rows)
            }

            if cards.isEmpty && isNarrowing { return nil }
            return GroupsVenueSection(
                id: venue.id,
                venue: venue,
                playerCount: camp.players(in: venue.id).count,
                cards: cards
            )
        }
    }

    // MARK: Rank tab

    /// One section per venue, in venue order, holding the whole 1…N ladder. The Groups
    /// filters deliberately do not apply here — Rank is always the complete list.
    ///
    /// Memoised, and for a sharper reason than `groupsSections` is. `RankView` writes its drag
    /// state on every gesture callback, so its `body` re-runs at display rate for the whole of a
    /// drag — and this property sat directly in it. Unmemoised it filtered and sorted the venue's
    /// players *twice* per venue (once here, once inside `rankRangeLabel`) and then scanned the
    /// entire attendance table twice per player, which is the one place in the app where a
    /// recompute per frame was costing real work rather than a few microseconds.
    var rankSections: [RankSection] {
        let key = RankSectionsKey(campRevision: campRevision, day: today)
        if let memo = rankSectionsMemo, memo.key == key { return memo.sections }
        let sections = computeRankSections()
        rankSectionsMemo = (key, sections)
        return sections
    }

    private func computeRankSections() -> [RankSection] {
        guard let camp else { return [] }

        // The day's attendance, indexed once, rather than `isAway` and `leavesAt` each walking
        // the whole table per kid. Same first-row-wins reading as `Camp.attendance(for:on:)`,
        // for the same reason `TodayCourts.rosters` gives: two readings of one table that differ
        // quietly are how they drift.
        var attendance: [Player.ID: Attendance] = [:]
        for record in camp.attendance where record.day == today {
            if attendance[record.playerID] == nil { attendance[record.playerID] = record }
        }

        return camp.orderedVenues.map { venue in
            // Asked for once and used twice. `rankRangeLabel` filters and sorts the roll on its
            // own, so calling it here would have been the second of two identical walks.
            let players = camp.players(in: venue.id)
            let ranks = players.map(\.overallRank)
            let rangeLabel = ranks.min().map { "\($0)–\(ranks.max() ?? $0)" } ?? "—"

            return RankSection(
                id: venue.id,
                venue: venue,
                rangeLabel: rangeLabel,
                rows: players.map { player in
                    PlayerRow(
                        id: player.id,
                        player: player,
                        rank: player.overallRank,
                        isAway: attendance[player.id]?.present == false,
                        leavesAt: attendance[player.id]?.leavesAt
                    )
                }
            )
        }
    }

    /// The order to hand back to `commitRankOrder` after a drag, with `moved` inserted
    /// at `offset` inside `venueID`'s section.
    func rankAssignments() -> [RankAssignment] {
        rankSections.map { RankAssignment(venueID: $0.id, playerIDs: $0.rows.map(\.id)) }
    }

    // MARK: Setup tab

    var filteredStaff: [StaffMember] {
        guard let camp else { return [] }
        return camp.staff.filter { member in
            switch staffFilter {
            case .all: true
            case .venue(let id): member.assignment?.venueID == id
            case .unassigned: member.isUnassigned
            }
        }
    }

    /// Every court in the camp, for the staff sheet's "ON TODAY" chip row.
    var allCourts: [Group] {
        guard let camp else { return [] }
        return camp.orderedVenues.flatMap { camp.groups(in: $0.id) }
    }

    /// `🌳 C1` for the staff sheet's court chips.
    func courtChipLabel(_ group: Group) -> String {
        guard let icon = camp?.venue(group.venueID)?.icon else { return group.courtCode }
        return "\(icon) \(group.courtCode)"
    }

    /// `Leaves Wed at 14:30` — reflects the live selection in the pick-up sheet.
    var pickupConfirmLabel: String {
        "Leaves \(pickupDay.shortName) at \(pickupTime.formatted)"
    }

    // MARK: Helpers

    private func passes(_ filter: PlayerFilter, _ player: Player) -> Bool {
        switch filter {
        case .everyone: true
        case .boys: player.gender == .m
        case .girls: player.gender == .f
        case .leavingEarly: camp?.isLeavingEarly(player.id, on: today) == true
        case .away: camp?.isAway(player.id, on: today) == true
        }
    }

    private func row(for player: Player, rank: Int) -> PlayerRow {
        PlayerRow(
            id: player.id,
            player: player,
            rank: rank,
            isAway: camp?.isAway(player.id, on: today) == true,
            leavesAt: camp?.leavesAt(player.id, on: today)
        )
    }
}

// MARK: - Intents: getting in

extension AppStore {

    func submitEmail() async {
        await perform {
            let challenge = try await self.repository.requestSignInCode(email: self.emailInput)
            self.auth = .awaitingCode(email: challenge.email)
            self.codeInput = ""
            self.startResendCountdown(from: challenge.resendAfter)
        }
    }

    func submitCode() async {
        guard case .awaitingCode(let email) = auth else { return }
        await perform {
            let account = try await self.repository.verifySignInCode(self.codeInput, email: email)
            try await self.finishSignIn(account)
        }
    }

    /// Screen 1's "Continue with Apple". `SignInView` runs the system sheet and arrives here with
    /// what Apple signed. No default token any more: a caller holding nothing has nothing to sign
    /// in with, and the empty string only ever reached GoTrue to be told `id_token required`.
    ///
    /// `fullName` is a one-shot. Apple releases the name on the first authorisation this Apple ID
    /// ever gives the app and never again, so it is written the moment it lands rather than left
    /// for a settings screen to ask for later. Only into an empty `displayName`, though — a second
    /// sign-in cannot carry a name, so anything already there was typed on Profile by the person
    /// whose name it is, and Apple's version of it is not an improvement.
    func continueWithApple(identityToken: String, fullName: String?) async {
        await perform {
            var account = try await self.repository.signInWithApple(identityToken: identityToken)
            if let fullName, account.displayName.isEmpty {
                account.displayName = fullName
                account = try await self.repository.updateAccount(account)
            }
            try await self.finishSignIn(account)
        }
    }

    #if DEBUG

    /// "Continue with Apple" with the Apple part taken out, for as long as the provider is not
    /// configured. Debug builds only — a release build cannot reach this, so the shipped app has
    /// no way in but a real authorisation.
    ///
    /// It swaps the repository as well as the account, and that is the whole point. Faking the
    /// signed-in state against Postgres would get you past screen 1 and no further: RLS is strict
    /// and there would be no session behind the requests, so the picker would be empty and every
    /// screen after it blank. Handing the store the offline repository instead gives a bypass you
    /// can walk end to end, writes included.
    ///
    /// `-offline` does the same swap at launch (see `SycamoreApp.repository()`). This is that
    /// switch behind a button, for when you are already running and did not think to pass a flag.
    func bypassSignIn() async {
        repository = InMemoryRepository(
            accounts: [SampleData.account],
            memberships: SampleData.memberships,
            camps: SampleData.camps
        )
        await perform { try await self.finishSignIn(SampleData.account) }
    }

    #endif

    /// The Apple sheet failing before there is a token to send.
    ///
    /// `perform` cannot wrap that work — it happens out in `SignInView`, which is where
    /// `ASAuthorizationController` and its window live — so the one place screen 1 has to say
    /// anything is filled in by hand. A cancelled sheet never gets here; see `AppleSignIn`.
    func signInFailed(_ error: any Error) {
        errorMessage = error.localizedDescription
    }

    func resendCode() async {
        guard case .awaitingCode(let email) = auth, canResend else { return }
        await perform {
            let challenge = try await self.repository.requestSignInCode(email: email)
            self.codeInput = ""
            self.startResendCountdown(from: challenge.resendAfter)
        }
    }

    /// Screen 2's back circle.
    func backToEmail() {
        stopResendCountdown()
        codeInput = ""
        auth = .signedOut
    }

    private func finishSignIn(_ account: Account) async throws {
        stopResendCountdown()
        auth = .signedIn(account)
        codeInput = ""
        memberships = try await repository.memberships(forAccount: account.id)
        selectedMembership = nil
        camp = nil
    }

    // MARK: Countdown

    func startResendCountdown(from seconds: Int = 42) {
        stopResendCountdown()
        resendSeconds = seconds
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.resendSeconds > 0 else { return }
                self.resendSeconds -= 1
            }
        }
    }

    func stopResendCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}

// MARK: - Intents: picking a camp

extension AppStore {

    func loadMemberships() async {
        guard let account else { return }
        await perform {
            self.memberships = try await self.repository.memberships(forAccount: account.id)
        }
    }

    func select(_ membership: Membership) async {
        await perform {
            let loaded = try await self.repository.camp(id: membership.campID)
            self.selectedMembership = membership
            self.camp = loaded
            self.selectedTab = .overview
            self.resetFilters()
        }
    }

    func joinCamp() async {
        guard let account else { return }
        let code = joinCodeInput
        await perform {
            let membership = try await self.repository.joinCamp(
                inviteCode: code, accountID: account.id
            )
            self.memberships = try await self.repository.memberships(forAccount: account.id)
            self.joinCodeInput = ""
            await self.select(membership)
        }
    }

    func createCamp() async {
        guard let account else { return }
        let draft = campDraft
        await perform {
            let membership = try await self.repository.createCamp(draft, accountID: account.id)
            self.memberships = try await self.repository.memberships(forAccount: account.id)
            self.campDraft = CampDraft()
            await self.select(membership)
        }
    }

    /// Profile's "Switch camp" — back to the picker without signing out.
    func switchCamp() {
        camp = nil
        selectedMembership = nil
        activeSheet = nil
        resetFilters()
    }

    func signOut() async {
        stopResendCountdown()
        try? await repository.signOut()
        auth = .signedOut
        memberships = []
        selectedMembership = nil
        camp = nil
        activeSheet = nil
        // Signing out from Profile leaves Profile itself on screen otherwise — a pushed screen
        // full of a camp that is no longer loaded, sitting over the sign-in form.
        pushedScreen = nil
        emailInput = ""
        codeInput = ""
        resetFilters()
    }

    func deleteAccount() async {
        guard let account else { return }
        await perform {
            try await self.repository.deleteAccount(id: account.id)
            await self.signOut()
        }
    }

    func resetFilters() {
        venueFilter = .all
        playerFilter = .everyone
        staffFilter = .all
        searchText = ""
        collapsedGroupIDs = []
    }
}

// MARK: - Intents: running the day

extension AppStore {

    func setAway(_ playerID: Player.ID, _ away: Bool) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.setAttendance(
                playerID: playerID, day: self.today, present: !away, campID: campID
            )
        }
    }

    /// Screen 5's swipe action and the player sheet's first row.
    func toggleAway(_ playerID: Player.ID) async {
        await setAway(playerID, !isAway(playerID))
    }

    func setEarlyPickup(playerID: Player.ID, day: Weekday, at time: TimeOfDay?) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.setEarlyPickup(
                playerID: playerID, day: day, leavesAt: time, campID: campID
            )
        }
    }

    func clearEarlyPickup(playerID: Player.ID, day: Weekday? = nil) async {
        await setEarlyPickup(playerID: playerID, day: day ?? today, at: nil)
    }

    func reorder(group groupID: Group.ID, playerIDs: [Player.ID]) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.reorderGroup(
                groupID, playerIDs: playerIDs, campID: campID
            )
        }
    }

    /// Commits a Rank-tab drag. Pass the sections exactly as they now read top to
    /// bottom; a kid that crossed a venue rule is simply in a different section.
    func commitRankOrder(_ assignments: [RankAssignment]) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.reorderCamp(assignments, campID: campID)
        }
    }

    func movePlayer(_ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID? = nil) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.movePlayer(
                playerID, toVenue: venueID, group: groupID, campID: campID
            )
        }
    }

    /// The player sheet's "Move up a court" — one court better inside the same venue.
    func moveUpACourt(_ playerID: Player.ID) async {
        guard let camp,
              let player = camp.player(playerID),
              let venueID = player.venueID,
              let current = player.groupID,
              let index = camp.groups(in: venueID).firstIndex(where: { $0.id == current }),
              index > 0
        else { return }
        let target = camp.groups(in: venueID)[index - 1]
        await movePlayer(playerID, toVenue: venueID, group: target.id)
    }

    func partitionCamp() async {
        guard let campID = camp?.id else { return }
        await perform { self.camp = try await self.repository.partitionCamp(campID) }
    }

    func evenOut() async {
        guard let campID = camp?.id else { return }
        await perform { self.camp = try await self.repository.evenOut(campID) }
    }
}

// MARK: - Intents: the shape of the camp

extension AppStore {

    func updateVenue(_ venue: Venue) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.updateVenue(venue, campID: campID)
        }
    }

    func addVenue() async {
        guard let campID = camp?.id else { return }
        await perform { self.camp = try await self.repository.addVenue(campID: campID) }
    }

    func setRole(_ role: Role, forStaff staffID: StaffMember.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.updateStaffRole(
                staffID, role: role, campID: campID
            )
        }
    }

    func assignStaff(_ staffID: StaffMember.ID, toGroup groupID: Group.ID?) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.assignStaff(
                staffID, toGroup: groupID, campID: campID
            )
        }
    }

    func removeStaff(_ staffID: StaffMember.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.removeStaff(staffID, campID: campID)
            self.activeSheet = nil
        }
    }

    func updateAccount(_ updated: Account) async {
        await perform {
            let saved = try await self.repository.updateAccount(updated)
            self.auth = .signedIn(saved)
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        guard var account else { return }
        account.notificationsEnabled = enabled
        await updateAccount(account)
    }
}

// MARK: - Intents: presentation

extension AppStore {

    func present(_ sheet: ActiveSheet) { activeSheet = sheet }
    func dismissSheet() { activeSheet = nil }

    func toggleCollapsed(_ groupID: Group.ID) {
        collapsedGroupIDs.toggle(groupID)
    }

    /// Dismisses the error banner. `perform` also clears `errorMessage` the moment the
    /// next intent succeeds, so this is only for the user waving the banner away.
    func clearError() { errorMessage = nil }

    /// Every intent funnels through here so a failure lands in one place — and so the
    /// last failure is cleared the moment something succeeds.
    /// Internal rather than private since the store grew past one file: `AppStore+SectionEight`
    /// needs the same in-flight-and-error handling, and a second copy of it is how two halves of
    /// one store start reporting failure differently.
    func perform(_ work: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

extension AppStore {

    /// Signed in as Alex, UCLA Tennis Camp loaded, Groups showing. What most previews
    /// want.
    static var preview: AppStore {
        let store = AppStore()
        store.auth = .signedIn(SampleData.account)
        store.memberships = SampleData.memberships
        store.selectedMembership = SampleData.uclaMembership
        store.camp = SampleData.uclaTennisCamp
        store.selectedTab = .groups
        return store
    }

    /// Screen 1.
    static var previewSignedOut: AppStore { AppStore() }

    /// Screen 2, mid-code, with the countdown parked at 0:42.
    static var previewAwaitingCode: AppStore {
        let store = AppStore()
        store.auth = .awaitingCode(email: SampleData.account.email)
        store.codeInput = "4192"
        store.resendSeconds = 42
        return store
    }

    /// Screen 3 — signed in, no camp chosen yet.
    static var previewCampPicker: AppStore {
        let store = AppStore()
        store.auth = .signedIn(SampleData.account)
        store.memberships = SampleData.memberships
        return store
    }

    /// The same person as an admin, so admin-only affordances show.
    static var previewAdmin: AppStore {
        let store = AppStore()
        store.auth = .signedIn(SampleData.account)
        store.memberships = SampleData.memberships
        store.selectedMembership = SampleData.westsideMembership
        store.camp = SampleData.westsideSwim
        return store
    }
}
