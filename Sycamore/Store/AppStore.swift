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
    case overview, schedule, groups, tournament, inbox

    var id: String { rawValue }

    /// The four the tab bar draws, in the design's own order.
    ///
    /// **`allCases` has five and the bar has four, and the odd one out is Inbox.** The design
    /// spends its fourth slot on Tournament and reaches the inbox from a control instead — see
    /// `navVals.tabs` in `design/app/state1.js:44`, which names exactly these four.
    ///
    /// `.inbox` stays a case rather than being deleted because it is still a place the app can
    /// be: `InboxView` is written, `OverviewScreen` has two controls that go there, and none of
    /// that is wrong — it is early. Deleting the case would mean deleting those call sites and
    /// writing them again later from memory. Leaving it out of *this* list is the whole of the
    /// change, and putting it back is one element.
    ///
    /// Written out rather than `allCases.filter { $0 != .inbox }` so that adding a case later
    /// does not silently put a half-built screen in front of somebody.
    static let bar: [AppTab] = [.overview, .schedule, .groups, .tournament]

    /// Whether this tab draws its own screen yet, or the "coming soon" plate.
    ///
    /// The list is stated positively — what *is* ready — because the failure that matters is a
    /// tab going live before its screen does, and that failure needs someone to have typed the
    /// tab's name here.
    var isReady: Bool {
        switch self {
        case .groups, .tournament: true
        case .overview, .schedule, .inbox: false
        }
    }

    /// The label inside the selected capsule.
    var title: String {
        switch self {
        case .overview: "Overview"
        case .schedule: "Schedule"
        case .groups: "Groups"
        case .tournament: "Tournament"
        case .inbox: "Inbox"
        }
    }

    /// SF Symbols standing in for the design's Phosphor set.
    var symbol: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .schedule: "calendar"
        case .groups: "person.3"
        // `ph-trophy`. The one tab whose glyph is the same word in both sets.
        case .tournament: "trophy"
        case .inbox: "tray"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .overview: "rectangle.grid.2x2.fill"
        case .schedule: "calendar"
        case .groups: "person.3.fill"
        case .tournament: "trophy.fill"
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
/// No longer `String`-backed, and no longer `CaseIterable`: `8m` needs the courts it is marking,
/// `8q` needs the kid and the court screen needs the court, so three of these six carry a payload
/// and neither a raw value nor `allCases` can survive that. Nothing asked for either — the raw
/// value existed only to spell `id`, which is now written out below.
enum PushedScreen: Identifiable, Hashable, Sendable {
    /// `8s` — the avatar's destination.
    case profile
    /// The camp page: what this camp holds, who staffs it, the code, and the way into its shape.
    ///
    /// **This is what a tab header's avatar opens now, and Profile is one step further in.** The
    /// design inverts the old order — `openProfile` in `design/app/state1.js:41` sets
    /// `page: 'camp'`, not a profile — because the thing somebody taps that disc looking for is
    /// almost always the camp: which venues it has, how many kids, the invite code to read out.
    /// Their own name and phone number are the rarer errand, so they moved behind the commoner
    /// one rather than in front of it.
    ///
    /// It is a separate case from `.profile` rather than a redirect, because `CampHomeView`'s own
    /// header avatar pushes `.profile`. Pointing `.profile` at the camp page would make that
    /// control open the screen it was tapped on.
    case campHome
    /// `8t` — admin only, reached from Profile.
    case campSettings
    /// The drag-to-reorder ladder, one row per kid, every kid at once.
    ///
    /// This used to say the screen "has no home in the new navigation … until Groups absorbs it".
    /// 4c is that home, and it arrived from the other direction than the comment expected: Groups
    /// does not swallow this screen, it opens `firstSort` beside it. The two are different jobs on
    /// the same order — this one edits a ladder that already exists, `firstSort` builds the first
    /// one there has ever been — so both stay, and `commitRankOrder(_:)` is what they share.
    case rank
    /// `4c` — the first sort. One venue's kids, two at a time, until there is an order.
    ///
    /// Carries the venue rather than reading `readVenueID`, and that is the same call
    /// `PushedScreen.court` and `.player` make: the sort runs over `camp.players(in:)` for one
    /// venue and takes minutes, and a venue pill tapped on the tab underneath must not change
    /// which kids the question on screen is about.
    case firstSort(Venue.ID)
    /// `8m` — attendance for one session, reached from a block on `8l`.
    ///
    /// A block runs across courts ("Courts 1–3"), so this carries the whole list rather than one,
    /// and the block itself so the header can name the session. The block is optional because the
    /// screen is legible without one: a coach marking their own court off the clock has courts but
    /// no session.
    case attendance([Group.ID], ScheduleBlock?)
    /// `8q` — a kid.
    case player(Player.ID)
    /// One court: its roster, its coach, its status and the notes written against it.
    ///
    /// The one screen in this enum the design does not draw. Section 8 draws a caret on every
    /// court card on `8i`/`8j` and no frame for where it goes, so the screen behind it is
    /// composed from the parts the design *does* draw — `8q`'s header shape, Overview's own coach
    /// pill, status badge and roster rows.
    ///
    /// Carries the court rather than the whole `CourtCard`: the card is a row of `today_courts`
    /// that the store re-reads on every load, and holding a copy of it in the navigation state
    /// would leave the screen drawing a headcount from whenever it was opened.
    case court(Group.ID)

    /// Written out rather than derived, because three of these cases carry a payload and the
    /// payload is what makes them different screens. An `id` that ignored it would leave `8q`
    /// showing the first kid when a second was asked for — SwiftUI reads `.sheet(item:)` as
    /// "still the same presentation" and never rebuilds the content.
    var id: String {
        switch self {
        case .profile: return "profile"
        case .campSettings: return "camp-settings"
        case .campHome: return "camp-home"
        case .rank: return "rank"
        case .firstSort(let id): return "first-sort-\(id.uuidString)"
        case .attendance(let groupIDs, let block):
            let courts = groupIDs.map(\.uuidString).joined(separator: "+")
            return "attendance-\(courts)-\(block?.id.uuidString ?? "no-block")"
        case .player(let id): return "player-\(id.uuidString)"
        case .court(let id): return "court-\(id.uuidString)"
        }
    }

    /// Whether the screen supplies its own way out, and so wants the whole frame.
    ///
    /// `8m` draws a ✕ and `8q` a back caret; both run a white header up under the status bar and
    /// pin a bar to the bottom edge. A sheet would inset the header behind rounded corners, put
    /// its own dismissal chrome beside a control that already exists, and float a grabber over a
    /// screen that draws a mock status bar. The other three have none of that and stay sheets.
    ///
    /// The court screen draws `8q`'s header — mock status bar, back caret, serif title — so it
    /// answers the question the same way and for the same reason.
    ///
    /// `firstSort` is the strongest case of all and takes the frame for a second reason besides
    /// its own ✕: it is a question asked over and over until an order exists, and a sheet leaves
    /// the tab bar and a slice of the screen behind it live under the reader's thumb. A stray tap
    /// on Groups halfway through a hundred kids would lose the sort — there is no draft of it
    /// anywhere, `firstSort` is store state and nothing writes it down.
    var isFullScreen: Bool {
        switch self {
        case .attendance, .player, .court, .firstSort: true
        // The camp page draws its own back control and owns a `NavigationStack` it pushes the
        // shape page into, so it could take the frame. It stays a sheet because it is reached
        // from a tab and returned from constantly — the same errand Profile and Camp settings
        // are, and they are sheets for that reason.
        case .profile, .campHome, .campSettings, .rank: false
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

/// What a reader can say about the two kids `4c` puts in front of them.
///
/// Four controls, one vocabulary. The screen draws two cards and two buttons under them, and each
/// of the four maps onto exactly one of `FirstSort`'s mutating methods — so this enum is the store
/// naming the *taps* while `FirstSort` names the arithmetic, and neither has to know the other's
/// spelling. The alternative, four intents on `AppStore`, would put the same `guard`, the same
/// reassignment and the same doc comment in four places.
///
/// `candidate` is the top card and `incumbent` the bottom one, which is the order
/// `FirstSort.pair` returns them in.
enum FirstSortAnswer: Hashable, Sendable {
    /// The kid being placed is stronger.
    case candidate
    /// The kid already on the ladder is stronger.
    case incumbent
    /// "About even" — seats the candidate directly below the incumbent and asks nothing further.
    case aboutEven
    /// Set this kid aside. They land at the foot of the venue and the sort moves on.
    case skip
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

    /// `player.displayName`, spelled once when the row is built rather than once every time it
    /// is drawn.
    ///
    /// `Player.displayName` (`Models.swift:549-558`) short-circuits on an empty surname, which is
    /// why `SampleData` never showed the cost — but a kid off a real roster has one, and then it
    /// builds a `PersonNameComponents` and runs a `FormatStyle` over it. A Groups drag now unfolds
    /// the whole venue, so it draws around fifty rows, each asking twice: once for the name it
    /// shows and once for the accessibility label it assembles whether or not anybody is
    /// listening. At display rate that is roughly twelve thousand ICU passes a second to render
    /// text that cannot change while a finger is down.
    ///
    /// Rows are built inside `computeGroupsSections`, which is memoised on `campRevision`, so this
    /// runs once per camp write instead. It is the same repair `Player.matches(search:)` took when
    /// the search field turned out to be formatting every kid's name on every keystroke — the
    /// formatter is fine, asking it per frame is not.
    let name: String

    var isLeavingEarly: Bool { leavesAt != nil }

    /// Spelled out rather than left to the memberwise synthesis, so `name` is derived here and
    /// cannot be passed in disagreeing with `player`. The signature is deliberately the one the
    /// synthesised init had, so no call site changes.
    init(id: Player.ID, player: Player, rank: Int, isAway: Bool, leavesAt: TimeOfDay?) {
        self.id = id
        self.player = player
        self.rank = rank
        self.isAway = isAway
        self.leavesAt = leavesAt
        self.name = player.displayName
    }
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
    /// The kids who are **at this venue and in no group**, in ladder order.
    ///
    /// The model produces these two ways and neither of them used to reach a screen. A venue whose
    /// age band refuses a kid leaves them here — `Camp.admit(_:at:)` sets `groupID = nil` and its
    /// own comment promises "the screen says so out loud and somebody can place them by hand" —
    /// and `Camp.removeGroup(_:from:)` leaves a deleted group's kids here too. Between them, the
    /// one screen whose whole job is who-is-where could hold a child it never drew.
    ///
    /// Beside `cards` rather than smuggled in as a thirteenth card, because it is not a group: it
    /// has no `Group.ID` to be a drop target with, no coach, no number and no band of the ladder.
    /// `UnassignedCard` draws it, and `GroupsView` treats it as a drag *source* only.
    ///
    /// Filtered by the same search and the same chips as `cards`, so a search that narrows the
    /// cards narrows this too — a screen showing "Liam" should not also show eleven kids called
    /// something else because they happen to have no group.
    ///
    /// Ordered by `overallRank`, which `Camp.players(in:)` already sorts by. Court rank means
    /// nothing to a kid with no court: `Camp.movePlayer` and `Camp.admit` both sink one to
    /// `Int.max / 2`, so sorting by it would be sorting by a placeholder.
    let unassigned: [PlayerRow]
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
    /// Screen 2's cells, held as one string of digits. How many there are is
    /// `SupabaseConfig.codeLength`.
    var codeInput: String = ""
    /// Seconds left on `Resend in 0:42`.
    var resendSeconds: Int = 0

    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    // MARK: Camp selection

    var memberships: [Membership] = []
    var selectedMembership: Membership?

    /// True once `repository.memberships(forAccount:)` has answered at least once for the account
    /// that is signed in now.
    ///
    /// The distinction it draws is between *no camps* and *not asked yet*, and those are the same
    /// empty array. `finishSignIn` sets `auth` to `.signedIn` and then awaits the memberships, so
    /// for that moment an account with three camps looks exactly like an account with none — which
    /// is the condition `FirstRunStep` reads as "new here". The first run used to be covered by a
    /// full-screen seed fall while that resolved; it is not any more, so the question has to be
    /// one the store can decline to answer rather than one it answers wrongly and corrects.
    ///
    /// `private(set)`: every write is a fetch returning, and the four of them are in this file.
    private(set) var hasLoadedMemberships = false

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
    var pushedScreen: PushedScreen? {
        didSet {
            // **Any assignment that is not `push(_:)` forgets what was underneath.**
            //
            // Thirty-odd sites assign this directly — a tab opening a screen, one screen replacing
            // another, a sign-out or a camp switch clearing it, or SwiftUI writing `nil` back on
            // an interactive dismissal. None of them maintained `previousPushedScreen`, so a
            // later `popPushed()` could restore a screen that had not been underneath anything
            // for several navigations: open the camp page, push Profile, swipe it away, then open
            // Camp settings from a *tab* and its back arrow would land on the camp page.
            //
            // `push(_:)` sets both in one step and is the only thing that may leave a value here,
            // which is what `isPushing` guards.
            if !isPushing { previousPushedScreen = nil }
        }
    }

    /// True only for the duration of `push(_:)`'s own assignment. See `pushedScreen`'s `didSet`.
    private var isPushing = false

    /// What was showing before `pushedScreen`, so a back control can put it back.
    ///
    /// **One level, and that is the design's depth rather than a shortcut.** `closePage`
    /// (`state1.js:41`) is literally `page: s.page === 'shape' ? 'camp' : null` — the shape page
    /// returns to the camp page and everything else returns to the tabs. Nothing in the design
    /// stacks two of these, so a general stack would be machinery for a case that does not exist.
    ///
    /// It exists because the single slot was silently destructive in two directions. Camp
    /// settings' back arrow hardcoded `.profile` — "which is where this screen was opened from",
    /// true of one of its four entry points and wrong for the other three, so a coach who opened
    /// it from Tournament or from the camp page landed on a Profile they had never asked for. And
    /// the camp page → Profile → close sequence landed on a tab rather than back on the camp
    /// page, because opening the second screen overwrote the first.
    private(set) var previousPushedScreen: PushedScreen?

    /// A tab is in the middle of something a stray tap must not end. While this is true
    /// `MainTabView` does not draw the tab bar.
    ///
    /// Groups sets it while a kid is in the air. Dragging a row towards the bottom of the screen
    /// ends the drag over the one control that leaves the screen entirely, and the cost of hitting
    /// it is a half-finished move — so the pill goes away for as long as the finger is down.
    ///
    /// A store flag rather than something Groups owns, because the bar is drawn by `MainTabView`
    /// and Groups is its sibling: there is no view in between for a preference to travel through.
    /// It is not `@ObservationIgnored` — the whole point is that the root redraws.
    var isFocused = false

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

    /// The venue the reader has *asked* for, ahead of the one they are posted to.
    ///
    /// The stored half of `readVenueID` (`AppStore+SectionEight.swift:37-48`), which was a
    /// computed three-step fallback with no setter — and 4a's venue pill and 4b's venue sheet both
    /// write which venue the reader is looking at. Nil is the ordinary state and means "whatever
    /// the fallback says", so a coach who never touches the pill still opens on their own posting.
    ///
    /// Not `venueFilter`. That is Groups' chip row, it carries an `.all` case no per-venue relation
    /// can answer, and `readVenueID`'s own doc records the decision not to key section 8's reads
    /// off it. This is the second stored venue in the store and deliberately so: they answer
    /// different questions on different tabs.
    ///
    /// Session-only, like every other selection in this store, and cleared by `resetFilters()` —
    /// see the argument there — because a venue id from one camp names nothing in the next.
    var chosenVenueID: Venue.ID?

    /// `4c`'s sort in flight, or nil when nobody is sorting.
    ///
    /// Held here rather than in the screen's `@State` for one reason, and it is the same reason
    /// the three reads above are: a sort is a hundred questions long, and `@State` on a screen
    /// presented from `pushedScreen` is discarded the moment anything dismisses it. The store is
    /// what makes the answer to question forty still there at question forty-one.
    ///
    /// Nothing about it is written down. `FirstSort` is a pure value over `Player.ID`s
    /// (`Models/FirstSort.swift`) and the ladder it builds is committed once, at the end, through
    /// `commitRankOrder(_:)` — so a relaunch mid-sort loses the sort and not the camp.
    var firstSort: FirstSort?

    /// The draws at `readVenueID`, oldest first. Empty until something loads them.
    ///
    /// Venue-scoped like `courts` and `scheduleBlocks` above, and for the same reason: a
    /// tournament is struck from one venue's ladder, so "every tournament in the camp" is a list
    /// nothing on the Tournament tab ever wants. `loadedTournamentVenueID` is what says whether
    /// this list is about the venue currently being read or the one before it — the same guard
    /// `ScheduleView` learned to make after its canvas drew the wrong day.
    var tournaments: [Tournament] = []

    /// Which venue `tournaments` was last filled for, or nil if never.
    ///
    /// Read it before trusting `tournaments`. An empty list means two different things —
    /// "this venue has no draws" and "nobody has asked yet" — and only this can tell them apart.
    /// Drawing "No draws yet" over a venue whose draws are still in flight is how a screen invites
    /// somebody to build one that already exists.
    var loadedTournamentVenueID: Venue.ID?

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
    // `collapsedGroupIDs` used to sit here, with `isCollapsed` and `toggleCollapsed` beside it,
    // holding which coach cards the user had folded away. Groups took its folding back into the
    // screen — `GroupsView.expandedGroupIDs` — because the design's default is the *folded* card
    // and a set of exceptions to the wrong default is a set that starts out lying. Nothing has
    // read these three since; they are gone rather than left as a second answer to "is this card
    // open" for the next person to find first.

    // MARK: Setup filter

    var staffFilter: StaffFilter = .all

    // MARK: Early pick-up draft (screen 10)

    /// What the "New pick-up" card on `8n` is currently offering. Nothing primes these before the
    /// sheet opens: `8n` seeds itself, loading a day's saved time as that day is picked, and the
    /// pick-ups already on the books are read from `camp` rather than from here.
    var pickupDay: Weekday = .today
    var pickupTime: TimeOfDay = TimeOfDay(14, 30)

    // MARK: The clock

    /// The app's one clock, ticking once a minute. See `AppClock` for why it is here rather than
    /// behind its own environment key, and why every screen reads this instead of `Date.now`.
    let clock = AppClock()

    // MARK: Status

    var isWorking = false
    var errorMessage: String?

    /// What just happened, for the pill at the foot of the screen. See `Toast`.
    ///
    /// On the store rather than on a screen because the writes that deserve one mostly finish
    /// *as their sheet closes* — "Venue added", "42 dealt into 6 groups" — so an overlay owned by
    /// the sheet would leave with it before anybody read a word.
    var toast: Toast?

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

    /// The day it is, read off the app's clock, and moving when the *day* does.
    ///
    /// This was `Weekday.today`, which was stubbed to Wednesday. Going through `clock` does two
    /// things the static could not: it reads the real calendar, and — because `AppClock` is
    /// `@Observable` — a view that draws today's date redraws when midnight passes under it
    /// rather than holding yesterday until somebody switches tabs.
    ///
    /// This line read "so it changes when the clock ticks", which was true and was the bug: the
    /// clock ticks every minute, this answer moves once a day, and every screen reading it —
    /// Schedule, Overview, Attendance, a court, a player — rebuilt 1440 times for each time it
    /// changed. `AppClock.today` is stored and written only on the rollover now, so a reader of
    /// this is back to a day-granularity dependency. See `AppClock.swift`.
    var today: Weekday { clock.today }

    /// The wall clock, for the two screens that ask which block is running.
    var timeOfDay: TimeOfDay { clock.timeOfDay }

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

    /// `Admins only · ask Nass or Hubert` — the sentence a locked row wears.
    ///
    /// Here rather than on the screens, because it is a sentence with a policy in it: two names
    /// and not three, "or" and not "and", and a fallback for a camp whose admins have all left.
    /// Profile and the Inbox each wrote it out privately and identically, which is how the third
    /// screen that locks a row ends up wording it differently.
    var adminsOnlyDetail: String {
        let names = (camp?.staff ?? []).filter(\.role.isAdmin).map(\.name)
        // Two, because a row is one line and a camp can have a dozen admins.
        let asked = Array(names.prefix(2))
        guard !asked.isEmpty else { return "Admins only" }
        return "Admins only · ask \(asked.formatted(.list(type: .or)))"
    }

    /// The signed-in person's own staff row in the current camp — the Profile header
    /// and "ON TODAY" card read from it.
    var myStaffRecord: StaffMember? {
        guard let camp, let account else { return nil }
        return camp.staff.first { $0.accountID == account.id }
    }

    var todayAssignment: TodayAssignment? { selectedMembership?.todayAssignment }

    /// The court the person reading is standing on. Nil for an admin, and for a coach nobody has
    /// given a court to.
    ///
    /// Their staff row first and today's assignment second, which is the order `OverviewScreen`
    /// established when it was the only place asking: the camp graph is the fuller record, and the
    /// membership's assignment is what a person carries when they are working a camp their staff
    /// row has not caught up with.
    ///
    /// Hoisted here because it has a second reader. `OverviewScreen` uses it to decide whose card
    /// goes under "Your court"; `OverviewView` now needs the same court to ask
    /// `ScheduleBlock.running(on:in:at:)` which block that card is about — and the one thing worse
    /// than duplicating the fallback would be duplicating it and having the two disagree, which
    /// would put a coach's own court at the top of the screen under somebody else's block.
    var myCourtID: Group.ID? {
        myStaffRecord?.groupID ?? todayAssignment?.groupID
    }

    /// `2 camps on this account`
    var switchCampDetail: String {
        "\(memberships.count) camp\(memberships.count == 1 ? "" : "s") on this account"
    }

    // MARK: Sign-in derived

    /// One entry per cell, empty string for a cell with no digit yet.
    var codeDigits: [String] {
        let length = SupabaseConfig.codeLength
        let digits = Array(codeInput.filter(\.isNumber).prefix(length))
        return (0..<length).map { $0 < digits.count ? String(digits[$0]) : "" }
    }

    /// The cell with the blinking caret; the last index once every digit is in.
    var focusedCodeIndex: Int {
        min(codeInput.filter(\.isNumber).count, SupabaseConfig.codeLength - 1)
    }
    var isCodeComplete: Bool {
        codeInput.filter(\.isNumber).count == SupabaseConfig.codeLength
    }
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

            // The kids this venue is holding and has not placed. Walked over the venue's roll
            // rather than over `camp.players`, so it is the same scope — and the same sort — the
            // section's `playerCount` is counted from.
            //
            // `rank:` is `overallRank` and not `courtRank`, unlike the cards above. A card's rows
            // are a court's own sequence; these kids are on no court, and the only number that is
            // true about them is their place in the camp ladder — which is also the numeral the
            // row draws.
            let unassigned = camp.players(in: venue.id)
                .filter { $0.groupID == nil }
                .filter { passes(playerFilter, $0) }
                .filter { term.isEmpty || $0.matches(search: term) }
                .map { row(for: $0, rank: $0.overallRank) }

            // A venue narrowed to nothing still disappears — but "nothing" now has to mean no
            // cards *and* nobody waiting, or a search matching only an unplaced kid would take the
            // venue off the screen and with it the one card that could say where they are.
            if cards.isEmpty && unassigned.isEmpty && isNarrowing { return nil }
            return GroupsVenueSection(
                id: venue.id,
                venue: venue,
                playerCount: camp.players(in: venue.id).count,
                cards: cards,
                unassigned: unassigned
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

    /// "Continue with Apple" with the Apple part taken out. Debug builds only — a release build
    /// cannot reach this, so the shipped app has no way in but a real authorisation.
    ///
    /// It used to stand in for the whole provider, which was not configured. It is now reached
    /// only from a debug *simulator* build, where the entitlement is stripped before the app is
    /// installed and no configuration on either side can make Apple work. `SignInView` carries
    /// the argument.
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
        try await fetchMemberships(for: account.id)
        selectedMembership = nil
        camp = nil
    }

    /// The one place memberships arrive.
    ///
    /// Four intents need them — signing in, the picker's own load, joining and creating — and each
    /// used to make the call itself. That was fine while the answer was only an array; it stopped
    /// being fine when `hasLoadedMemberships` had to be raised alongside it, because a flag set at
    /// three of four sites is a flag that is wrong exactly once and silently. Here it cannot be.
    private func fetchMemberships(for accountID: Account.ID) async throws {
        memberships = try await repository.memberships(forAccount: accountID)
        hasLoadedMemberships = true
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
            try await self.fetchMemberships(for: account.id)
        }
    }

    /// Opens a camp and lands on the tab that can do something about it.
    ///
    /// **Not always Overview.** This set `.overview` unconditionally, and Overview is a Coming
    /// Soon placeholder — so creating a camp, or joining one, or switching to one, dropped the
    /// reader on a card explaining that the tab is not built yet. On a camp with no venues that
    /// is the second dead end in a row, because there is nothing on any tab to do until the camp
    /// is shaped.
    ///
    /// The design routes on exactly this question (`state1.js:58`): a camp with no venues opens
    /// on the page that can give it some, and a camp that has them opens on Groups. Groups is
    /// also the one tab of the four that is actually built, which makes it the honest default
    /// until Overview and Schedule land.
    func select(_ membership: Membership) async {
        await perform {
            let loaded = try await self.repository.camp(id: membership.campID)
            self.selectedMembership = membership
            self.camp = loaded
            self.selectedTab = .groups
            // A camp with nowhere to put anybody opens on the screen that fixes that, over the
            // top of the tabs — the same route the camp page's own "Shape the camp" row takes.
            self.pushedScreen = loaded.venues.isEmpty ? .campSettings : nil
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
            try await self.fetchMemberships(for: account.id)
            self.joinCodeInput = ""
            await self.select(membership)
        }
    }

    func createCamp() async {
        guard let account else { return }
        let draft = campDraft
        await perform {
            let membership = try await self.repository.createCamp(draft, accountID: account.id)
            try await self.fetchMemberships(for: account.id)
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

    /// The camp page's last row. The camp, its venues, its kids and every tournament and block in
    /// it, gone for good.
    ///
    /// **Deliberately not optimistic, which is the one place this store departs from `land(_:in:)`
    /// and its siblings.** Optimism buys latency back on a gesture somebody makes forty times an
    /// afternoon, and it is paid for by a rollback that has to restore state the reader is still
    /// looking at. Neither half applies here. This is a once-ever action already behind two
    /// confirmations, so nobody is waiting on it impatiently; and the "optimistic" state is not a
    /// reordered ladder but *a different screen* — `camp = nil` routes the whole app back to the
    /// picker (`RootView.stage`). A failed write would then have to push the reader back into a
    /// camp they had just watched disappear, which is a worse thing to be wrong about than a
    /// hundred milliseconds. So the write goes first, and until it answers nothing moves.
    ///
    /// **The membership is dropped here rather than refetched.** The server has just confirmed the
    /// row is gone; asking it again is a second call that can fail on its own, and a failure *after*
    /// a successful delete would put an error banner over a delete that in fact worked. The picker
    /// re-asks on its own anyway — `CampPickerView` runs `loadMemberships()` in a `.task` — so the
    /// list this leaves behind is right immediately and refreshed a moment later regardless.
    ///
    /// `pushedScreen` is cleared for the reason `signOut()` clears it: this intent is raised *from*
    /// a pushed screen, and `MainTabView` — which presents it — goes away with the camp. Left set,
    /// it would reappear over the next camp the reader opens, showing them the camp page of a camp
    /// they never asked about.
    func deleteCamp() async {
        guard let camp else { return }
        let campID = camp.id
        await perform {
            try await self.repository.deleteCamp(id: campID)
            self.memberships.removeAll { $0.campID == campID }
            self.switchCamp()
            self.pushedScreen = nil
        }
    }

    func signOut() async {
        stopResendCountdown()
        try? await repository.signOut()
        auth = .signedOut
        memberships = []
        // The array and the flag go back together, or the next person to sign in on this device
        // inherits the last one's answer to "have we asked yet?" and gets the wrong first run.
        hasLoadedMemberships = false
        selectedMembership = nil
        camp = nil
        activeSheet = nil
        isFocused = false
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

    /// Everything the reader had narrowed the last camp down to.
    ///
    /// `chosenVenueID` joined the list when 4a's venue pill made it writable. It is not a filter in
    /// the sense the other four are — nothing calls it one on screen — but it holds a `Venue.ID`,
    /// and a venue id belongs to exactly one camp: carried across a switch it would name a venue
    /// the new camp does not have, and `readVenueID` would answer it anyway, because its fallback
    /// only runs when the chosen one is nil. Overview would then read a venue with no courts in it
    /// and draw an empty morning. Every caller of this method is a camp boundary — `select(_:)`,
    /// `switchCamp()`, `signOut()` — which is exactly where that has to be cleared.
    func resetFilters() {
        venueFilter = .all
        playerFilter = .everyone
        staffFilter = .all
        searchText = ""
        chosenVenueID = nil
    }
}

// MARK: - Intents: running the day

extension AppStore {

    func setAway(_ playerID: Player.ID, _ away: Bool) async {
        guard let campID = camp?.id else { return }
        // Composed *before* the write, because the sentence is about the camp as it stands plus
        // the change being asked for — and afterwards there is nothing left to compare against.
        // See `awayActivity` and the extension it sits in.
        let row = awayActivity(playerID, away: away)
        await perform {
            self.camp = try await self.repository.setAttendance(
                playerID: playerID, day: self.today, present: !away, campID: campID
            )
            try await self.log(row, forCamp: campID)
        }
    }

    /// Screen 5's swipe action and the player sheet's first row.
    func toggleAway(_ playerID: Player.ID) async {
        await setAway(playerID, !isAway(playerID))
    }

    func setEarlyPickup(playerID: Player.ID, day: Weekday, at time: TimeOfDay?) async {
        guard let campID = camp?.id else { return }
        let row = pickupActivity(playerID, day: day, at: time)
        await perform {
            self.camp = try await self.repository.setEarlyPickup(
                playerID: playerID, day: day, leavesAt: time, campID: campID
            )
            try await self.log(row, forCamp: campID)
        }
    }

    func clearEarlyPickup(playerID: Player.ID, day: Weekday? = nil) async {
        await setEarlyPickup(playerID: playerID, day: day ?? today, at: nil)
    }

    // `reorder(group:playerIDs:)` stood here — one court's sequence, written and awaited on its
    // own. `land` below replaced its only caller and there is deliberately nothing left in its
    // place: it was the *non*-optimistic spelling of exactly the write this screen just made
    // optimistic, and leaving it as live-looking API is how the next person reaching for the
    // obvious-sounding name gets back the snap-and-wait the change existed to remove. A court's
    // order is never written without the ladder that numbers it, so there is no caller it could
    // serve honestly.

    /// One drop on the Groups screen, applied here first and written afterwards.
    ///
    /// **One intent, because the screen made one decision.** This was two awaited calls at the
    /// call site — `commitRankOrder(plan.assignments)` and then `reorder(group:playerIDs:)` —
    /// and that is what made a drag "not intuitive/responsive": the row snapped back to where it
    /// started, the screen sat still for two serialised network round trips (`SupabaseRepository`
    /// reads, edits and writes the whole ladder for each), and the kid finally reappeared
    /// somewhere else. Nothing on screen was wrong; it simply happened a second and a half after
    /// the gesture that asked for it. `GroupsLandingPlan` already holds both halves of the
    /// answer, so both halves belong to one intent.
    ///
    /// **Applied locally before the write, and put back if the write fails.** The two model
    /// methods are the same ones the repositories call — `InMemoryRepository.reorderGroup` and
    /// its Postgres twin do exactly this pair to their own copy of the graph — so the optimistic
    /// state is not an approximation of what the server will say, it is the same arithmetic run
    /// a round trip earlier. The snapshot is the whole `Camp`, which is a value type: restoring
    /// it is one assignment and cannot half-succeed.
    ///
    /// A failure lands in `perform`'s `errorMessage` and so in `MainTabView`'s banner, which is
    /// the only place this app reports a failed write. The rollback goes first and the error is
    /// rethrown, so the banner and the restored ladder arrive in the same frame.
    ///
    /// **Still two repository calls, deliberately, and only for now.** `SycamoreRepository` has
    /// no "land a kid" verb — the ladder and the court sequence are separate writes — and adding
    /// one is a change to `Store/Repository.swift` and both of its implementations. Worth making:
    /// it would also close the half-failure this leaves, where the ladder lands and the court
    /// order does not. Nobody waits on either call now, which is what the complaint was about.
    func land(_ plan: GroupsLandingPlan, in groupID: Group.ID) async {
        guard let campID = camp?.id, var optimistic = camp else { return }

        let rollback = optimistic
        optimistic.applyRankOrder(plan.assignments)
        optimistic.reorder(group: groupID, playerIDs: plan.courtOrder)
        camp = optimistic

        await perform {
            do {
                // The first result is deliberately discarded. Assigning it would replace a graph
                // that already holds the whole drop with one that holds half of it, and the kid
                // would visibly bounce through the intermediate ladder on their way to the place
                // they were already standing in.
                _ = try await self.repository.reorderCamp(plan.assignments, campID: campID)
                let settled = try await self.repository.reorderGroup(
                    groupID, playerIDs: plan.courtOrder, campID: campID
                )
                // Compared before assigning, which is not a micro-optimisation: the setter bumps
                // `campRevision` and drops both section memos, so an unconditional write re-derives
                // `groupsSections` and `rankSections` — twelve courts each filtering and sorting a
                // hundred players — to arrive at the graph already on screen. The optimistic
                // mutation ran the same model methods the repository did, so equal is the ordinary
                // case rather than the lucky one.
                if settled != self.camp { self.camp = settled }
            } catch {
                self.camp = rollback
                throw error
            }
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

    // MARK: The first sort — `4c`

    /// Opens `4c` over one venue's roll.
    ///
    /// Seeded from the camp the store is already holding, so the screen costs no round trip: the
    /// order it starts from is `overallRank`, which every read of the camp already carries.
    ///
    /// Replaces any sort in flight rather than resuming one. Two venues cannot be sorted at once —
    /// `pushedScreen` is a single slot and `firstSort` is a single value — and a half-finished
    /// sort of *another* venue is not something this screen could draw, so the honest thing is to
    /// start the one that was asked for.
    func beginFirstSort(in venueID: Venue.ID) {
        guard let camp else { return }
        firstSort = .seeded(venueID: venueID, players: camp.players(in: venueID))
        pushedScreen = .firstSort(venueID)
    }

    /// One tap on `4c`. Synchronous and local: nothing is written until `finishFirstSort()`.
    ///
    /// The whole point of the sort living on the store rather than in the screen's `@State` is
    /// that it survives what a `@State` would not, so this reassigns the value back rather than
    /// mutating in place through a computed property — `firstSort` is an ordinary stored optional
    /// and `@Observable` only notices the write.
    func answerFirstSort(_ answer: FirstSortAnswer) {
        guard var sort = firstSort else { return }
        switch answer {
        case .candidate: sort.chooseCandidate()
        case .incumbent: sort.chooseIncumbent()
        case .aboutEven: sort.tie()
        case .skip: sort.skip()
        }
        firstSort = sort
    }

    /// Finishes `4c`: writes the sorted venue back into the camp-wide ladder, deals its courts, and
    /// closes the screen.
    ///
    /// **The invariant is enforced here, and that is the change worth recording.** This used to
    /// guard only `firstSort != nil` and bless "a caller finishing early" in this very comment,
    /// while `FirstSortView.split()` — the only caller — guarded `isSettled` itself and called that
    /// same early finish "the one mistake on `4c` that costs a child their place". Both cannot be
    /// right. The screen is right: `FirstSort.playerIDs()` is `ladder + skipped`, an in-flight
    /// candidate is in **neither**, and so a finish taken mid-question hands `commitRankOrder` an
    /// assignment with the child on screen missing from it. A rule a view can break by being
    /// rewritten is not a rule; it lives on the store now, where the write is, and the view's guard
    /// is a second statement of it rather than the only one.
    ///
    /// **No new verb, and no new column.** Every insertion leaves a complete ladder, so what comes
    /// out of the sort is exactly the shape `commitRankOrder(_:)` already takes: the camp's
    /// sections as they read top to bottom, with one venue's rows replaced. `overallRank` *is* the
    /// ladder, and `skipped` is the one piece of state it cannot carry — those kids fall to the
    /// foot of their venue keeping their relative order, and the count of them is session-local
    /// and gone at relaunch. That is stated rather than fixed: persisting a skip would need a
    /// column for a fact that means nothing once the sort is over.
    ///
    /// **Anyone the sort did not place is still appended, not dropped.** The guard above makes a
    /// settled sort's `playerIDs()` the whole roll *as the sort saw it*, which is not the same as
    /// the roll now: a kid enrolled at the desk while the questions were being answered is in the
    /// camp and not in the sort. Without the tail below they would be absent from the assignment,
    /// `applyRankOrder` skips what it is not given (`Models.swift:1323-1338`), and `reindex()`
    /// would thread them back in on a rank nobody meant.
    ///
    /// **Two writes, and the second is what makes the first mean anything.** `applyRankOrder`
    /// renumbers `overallRank` and moves nobody between courts, so a ladder committed and left
    /// there gives the venue a brand new order with its courts still holding whoever they held this
    /// morning — every band on `8o` reading a range with holes in it. `spreadKids(.allKids, …)`
    /// (`AppStore+SectionEight.swift:243`) is the venue-scoped deal: this venue's roll across this
    /// venue's courts, touching nothing else. `evenOut()` (`:1364`) is the other candidate and is
    /// wrong here for exactly that reason — it re-deals *every* venue in the camp, rearranging
    /// courts nobody asked about as a side effect of ranking one.
    ///
    /// It was the view making that second call. It is here because it is not a drawing decision:
    /// a ladder without the deal is a half-finished write, and which half ran should not depend on
    /// what a screen remembered to do next.
    ///
    /// **The second write is skipped when the first failed.** `perform` clears `errorMessage`
    /// before it starts and sets it on failure (`:1694-1708`), so a nil there means the ladder
    /// landed; dealing courts against a ladder that did not would deepen one refusal into two.
    ///
    /// **The screen closes before the write, not after.** That is the call `CourtCoachPicker.assign`
    /// already makes, and for its reason: a refusal belongs in the tab's banner, not inside a
    /// screen that is still asking which of two kids is stronger about an order already decided.
    /// A refused write leaves the ladder exactly as it was, and a first sort is repeatable — the
    /// seed is the same roll in the same order.
    func finishFirstSort() async {
        guard let sort = firstSort, sort.isSettled else { return }
        let sorted = sort.playerIDs()
        // Hashed once, above the `map`, because it is the same set every time round: `sorted` is
        // fixed before the loop starts. Inside the closure it was being rebuilt per venue — a walk
        // of the whole sorted roll for each section of a camp, to serve the one section the guard
        // below lets through.
        let placed = Set(sorted)
        let assignments = rankAssignments().map { assignment -> RankAssignment in
            guard assignment.venueID == sort.venueID else { return assignment }
            return RankAssignment(
                venueID: assignment.venueID,
                playerIDs: sorted + assignment.playerIDs.filter { !placed.contains($0) }
            )
        }
        firstSort = nil
        pushedScreen = nil
        await commitRankOrder(assignments)

        guard errorMessage == nil, let camp else { return }
        await spreadKids(
            .allKids, over: camp.groups(in: sort.venueID).map(\.id), atVenue: sort.venueID
        )
    }

    func movePlayer(_ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID? = nil) async {
        guard let campID = camp?.id else { return }
        let row = moveActivity(playerID, toVenue: venueID, group: groupID)

        // Read *before* the write, because undoing means putting them back where they were and
        // afterwards there is no record of that anywhere: the graph that comes back is the new
        // one. A kid with no court to return to gets no Undo rather than a button that would
        // move them somewhere they have never been.
        let wasAt = camp?.player(playerID).map { ($0.venueID, $0.groupID) }
        let name = camp?.player(playerID)?.displayName

        await perform {
            self.camp = try await self.repository.movePlayer(
                playerID, toVenue: venueID, group: groupID, campID: campID
            )
            try await self.log(row, forCamp: campID)
        }

        guard errorMessage == nil, let name else { return }
        let landed = groupID.flatMap { camp?.group($0) }.map { "Group \($0.number)" }
            ?? camp?.venue(venueID)?.name
            ?? "the venue"
        say("\(name) → \(landed)", undo: undoMove(playerID, to: wasAt))
    }

    /// The way back from a move, or nil when there is nowhere to go back to.
    ///
    /// Rebuilt as a closure over the *previous* placement rather than as a saved camp: restoring
    /// a whole graph would also undo anything else that happened in the 3.2 seconds the pill was
    /// up, and on a camp morning that is somebody else's write on somebody else's phone.
    private func undoMove(
        _ playerID: Player.ID, to previous: (Venue.ID?, Group.ID?)?
    ) -> (@Sendable @MainActor () -> Void)? {
        guard let previous, let venueID = previous.0 else { return nil }
        let groupID = previous.1
        return { [weak self] in
            guard let self else { return }
            Task { await self.movePlayer(playerID, toVenue: venueID, group: groupID) }
        }
    }

    // `moveUpACourt` used to sit here: resolve the court one better inside the same venue, and
    // delegate to `movePlayer`. It was `8q`'s pinned bar's only caller, and that bar now opens
    // `PlayerCourtPicker` — every court in the camp, in either direction, across venues — so the
    // one direction it could go is a question nothing asks any more. Deleted rather than left
    // standing: an intent with no caller is a claim about the app that nobody is checking.

    func partitionCamp() async {
        guard let campID = camp?.id else { return }
        await perform { self.camp = try await self.repository.partitionCamp(campID) }
    }

    func evenOut() async {
        guard let campID = camp?.id else { return }
        await perform { self.camp = try await self.repository.evenOut(campID) }
    }
}

// MARK: - What the day's work tells the feed

/// The four `.activity` rows the running camp writes into the Inbox.
///
/// `8r` had exactly two writers before this — `addBlockNote` and `addPinnedMessage`, both of them
/// notes — so **every activity row in the app existed only inside a `#Preview`**. The screen was
/// reported as broken and was not: `InboxBucket` splits today into morning, afternoon and evening
/// on each row's own `createdAt` and does it correctly, but the section could not appear because
/// no shipped code path had ever written a row for it to hold. A feed with no writers is a
/// starved screen, not a broken rule, and the fix belongs on this side.
///
/// Composed here in `AppStore`, one method per intent, rather than inside the repository. Two
/// reasons, and the second is the load-bearing one:
///
/// - The sentence needs names. "Austin Zheng → Court 2" is a `Player.displayName` and a
///   `Group.label`; the repository is handed ids and would have to re-read the graph to spell
///   either. The store is already holding it.
/// - Every one of them is written inside the *same* `perform` as the camp write it describes
///   (see `setAway` above and its three siblings), so the graph and the feed cannot drift apart
///   in a later edit — the two calls are four lines from each other, and a change to one is in
///   front of whoever changes the other.
///
/// Each returns nil when the tap changed nothing, which is the whole of the answer to "do not
/// make the feed noisy": a swipe onto a kid who is already away, or a court chip tapped twice,
/// is not news and writes nothing. That guard earns its keep in the busiest path in the app —
/// `AttendanceView.answer(_:away:)` calls `setAway` for *every* kid a coach taps through a
/// register, and a court where everybody turned up would otherwise write eight rows saying
/// nothing happened.
///
/// The row goes second, inside the same `perform`, and a failure to write it raises. The camp
/// write is what the reader asked for and it stands either way; a feed that quietly lost the row
/// would be worse than a banner, because `8r` is where the next coach in catches up on what they
/// missed and there is nothing on screen to show them a line is absent. The two are not
/// transactional and cannot be from here — the same position `applyRoster` is in, and it settles
/// it the same way: order the writes so the survivable half fails first.
///
/// **Four intents and not fourteen, and the line is drawn at one decision about one person.**
/// Every method here narrates a thing a coach did to somebody during a session, which is what
/// `8r`'s feed is a record of. Three other families deliberately write nothing:
///
/// - `reorderGroup`, `commitRankOrder`, `partitionCamp` and `evenOut` move the whole ladder at
///   once. A row each would bury the morning under forty lines nobody asked for, and one row for
///   the batch is a different feature — the design draws it ("Rank order published · 6 groups")
///   and nothing writes that either.
/// - `addPlayer`, `importPlayers`, `updatePlayers` and `removePlayers` are enrolment. A roster
///   arriving is not a thing that happened during the session, and `8d` is already the screen
///   for reviewing it.
/// - `setCourtStatus` closes a court, which genuinely is a moment in the day — but it is drawn
///   on the court card with its reason still on it and is not stored at all yet
///   (`SupabaseRepository+SectionEight.swift:91-93`). It should join this list once it is.
///
/// The guard reads the *local* `camp`, which a second coach can have moved under it — there is no
/// realtime sync in this app. That is the right trade at this altitude: the failure is a row
/// written or skipped against a graph a few seconds stale, and both are recoverable by looking at
/// the camp. The alternative is asking the server what changed, which is the round trip this
/// guard exists to avoid.
///
/// **Deliberately not `resolved`, and deliberately never expired.** `resolved` moves a row onto
/// `8h`'s "Cleared today" list, which is the history of *things that were waiting on you and now
/// are not* — an activity row was never waiting on anybody, has no button and no decision behind
/// it, so filing it there would misdescribe it and pad a list a reader opens to check what they
/// dealt with. Ageing is already handled and needs no clock of its own: the feed buckets by day,
/// so this morning's rows fall under "This morning", drop to "Yesterday" at midnight and to
/// "12 Mar" a week later, sinking down the screen on their own.
extension AppStore {

    /// Writes one of the rows below, if there is one to write, and takes the camp's Inbox back.
    ///
    /// The nil case is not a failure and is why this swallows it rather than making four call
    /// sites unwrap: "nothing changed, so there is nothing to say" is the ordinary answer, and
    /// four copies of the same `if let` around the same two lines is how the fourth one ends up
    /// spelled differently.
    ///
    /// Answers with the whole camp's rows rather than the one just written, which is what every
    /// other Inbox write already does — so an intent on Groups leaves the Inbox tab correct
    /// without it having to re-read on appearance.
    private func log(_ row: InboxItem?, forCamp campID: Camp.ID) async throws {
        guard let row else { return }
        inboxItems = try await repository.logActivity(row, forCamp: campID)
    }

    /// "Jonah Reyes marked away", and its correction.
    ///
    /// The correction is written too, which is one more row on a feed asked to stay quiet. The
    /// alternative is worse: a mis-swipe undone thirty seconds later would leave "marked away"
    /// standing as the last thing the feed ever said about that kid, and the next coach reading
    /// it at half nine would go looking for someone who is on court. A feed that cannot take
    /// something back is not quieter, it is wrong.
    private func awayActivity(_ playerID: Player.ID, away: Bool) -> InboxItem? {
        guard isAway(playerID) != away,
              let player = player(playerID),
              let venueID = player.venueID ?? readVenueID
        else { return nil }

        return InboxItem(
            venueID: venueID,
            kind: .activity,
            title: "\(player.displayName) marked \(away ? "away" : "here")",
            detail: activityDetail([player.groupID.flatMap { group($0)?.label }, byMe]),
            actorID: myStaffRecord?.id,
            playerID: playerID,
            groupID: player.groupID
        )
    }

    /// "Serene Chu leaves at 2:30pm", and the row that takes it back off the books.
    ///
    /// **Names no actor, on purpose.** `InboxIconTile` reads an activity row carrying a player and
    /// no actor as "a standing arrangement about that kid rather than something a coach just did"
    /// and gives it the amber clock, naming early pick-up as the case it means
    /// (`InboxIconTile.swift:62-64`, `:89-92`). That rule was written for this row before this row
    /// existed, so filling `actorID` in would swap the design's amber countdown for the grey
    /// person-removed glyph on the one row the tile was shaped around. The detail line stays
    /// silent about who set it for the same reason — an attribution in words beside a field left
    /// empty is two answers to one question.
    ///
    /// The day is spelled out rather than written "today". A pick-up can be set for Friday from
    /// Wednesday, and "today" would be a lie the moment it was written; it also goes stale
    /// overnight on the row that *was* about today, while the feed's own heading already says
    /// which day the row was written on.
    ///
    /// `TimeOfDay.clockLabel` — "2:30pm" — rather than the design's bare "2:30". That is the
    /// spelling every other early-pick-up line in the app already uses
    /// (`AttendanceEntry.swift:31`, `EarlyPickupSheet.swift:121`, `PlayerScreen.swift:198`), and
    /// a feed row is read hours after the sheet that set it, with no picker beside it to say
    /// which half of the day was meant.
    private func pickupActivity(
        _ playerID: Player.ID, day: Weekday, at time: TimeOfDay?
    ) -> InboxItem? {
        guard camp?.leavesAt(playerID, on: day) != time,
              let player = player(playerID),
              let venueID = player.venueID ?? readVenueID
        else { return nil }

        let title = time.map { "\(player.displayName) leaves at \($0.clockLabel)" }
            ?? "\(player.displayName) staying to the end"
        return InboxItem(
            venueID: venueID,
            kind: .activity,
            title: title,
            detail: activityDetail([day.fullName, player.groupID.flatMap { group($0)?.label }]),
            playerID: playerID,
            groupID: player.groupID
        )
    }

    /// "Austin Zheng → Court 2".
    ///
    /// Names the venue instead when there is no court to name. `movePlayer` with a nil group
    /// lands the kid on the venue's smallest court, chosen inside `Camp.movePlayer` from a graph
    /// this row is composed before — so "→ LATC" is what is actually known here, and a court name
    /// would be a guess that a reindex could make wrong.
    private func moveActivity(
        _ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?
    ) -> InboxItem? {
        guard let player = player(playerID),
              player.venueID != venueID || (groupID != nil && player.groupID != groupID)
        else { return nil }

        let destination = groupID.flatMap { group($0)?.label } ?? venue(venueID)?.name
        guard let destination else { return nil }

        return InboxItem(
            venueID: venueID,
            kind: .activity,
            title: "\(player.displayName) → \(destination)",
            // Where they came from, which is the one fact the title cannot carry and the only
            // thing a reader needs to know whether this move is the one they asked for.
            detail: activityDetail([
                player.groupID.flatMap { group($0)?.label }.map { "from \($0)" }, byMe,
            ]),
            actorID: myStaffRecord?.id,
            playerID: playerID,
            groupID: groupID
        )
    }

    /// "Nass → Court 1", and the row for taking them back off it.
    ///
    /// `actorID` is the person who made the change, not the person being moved — which is the
    /// same way round every other row here reads it, and the way `addBlockNote` and
    /// `addPinnedMessage` already store it. There is no second staff field, so the coach being
    /// assigned is named in the title, where the design puts them.
    ///
    /// **Names whoever is coming off, because one tap moves two people.** `Camp.assignStaff` runs
    /// one coach per court and bumps the incumbent to no court on its way past
    /// (`Models.swift:1341-1343`), so putting Dana on Court 1 takes Nass off it. A row reading
    /// only "Dana → Court 1" would be true and would leave the feed silently wrong about Nass:
    /// somebody scanning it for why their court has no coach would find nothing. Said in the
    /// detail line rather than as a second row, because it is one tap and one decision — the same
    /// shape `moveActivity` uses to carry "from Court 4".
    private func assignmentActivity(
        _ staffID: StaffMember.ID, toGroup groupID: Group.ID?
    ) -> InboxItem? {
        guard let staff = staffMember(staffID), staff.groupID != groupID else { return nil }

        let court = groupID.flatMap { group($0) }
        // The court's venue when there is one, the person's own otherwise — an unassignment names
        // no court and so has no venue of its own to sit at.
        guard let venueID = court?.venueID ?? staff.venueID ?? readVenueID else { return nil }

        let bumped = groupID.flatMap { coach(forGroup: $0) }
        return InboxItem(
            venueID: venueID,
            kind: .activity,
            title: court.map { "\(staff.name) → \($0.label)" } ?? "\(staff.name) off court",
            detail: activityDetail([
                venue(venueID)?.name, bumped.map { "replaces \($0.name)" }, byMe,
            ]),
            actorID: myStaffRecord?.id,
            groupID: groupID
        )
    }

    /// `by Dana` — the attribution every row above shares, or nothing at all when the reader has
    /// no staff row in this camp to sign with.
    private var byMe: String? {
        myStaffRecord.map { "by \($0.name)" }
    }

    /// The row's second line: the facts first, the person who did it last, `·` between them.
    ///
    /// That is how the design writes a detail line everywhere else on the screen — "Skills
    /// rotation · net on 4 is loose", "Sycamore · 6 groups · by Nass" — and doing it here rather
    /// than at four call sites is what stops the fourth row from being punctuated differently.
    /// Nil rather than an empty string when nothing survives: `InboxActivityRow` draws the line
    /// only when there is one, and an empty `String` is not nothing to a `if let`.
    private func activityDetail(_ parts: [String?]) -> String? {
        let kept = parts.compactMap { $0 }
        return kept.isEmpty ? nil : kept.joined(separator: " · ")
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

    /// The Groups tab's "Remove" — one group off a venue, its kids left standing at the venue with
    /// no group.
    ///
    /// **The arithmetic is `Camp.removeGroup(_:from:)` and nothing here restates it.** It takes the
    /// group out, renumbers the survivors so `number` still runs 1…n with no gap, decrements the
    /// venue's `groupCount` so the next `upsert` does not re-create what was just deleted, and
    /// leaves the kids at the venue with `groupID = nil` — the same state `syncGroups(for:)`
    /// already leaves a trimmed court's kids in, and the same one an age band leaves a refused kid
    /// in. `GroupsView` shows them; see `GroupsVenueSection.unassigned`.
    ///
    /// **Optimistic, in the shape `land(_:in:)` established**: mutate the local graph, then write,
    /// then put the snapshot back if the write throws. A deletion is one tap on a destructive
    /// control and waiting a round trip to see it happen is the complaint `land` was written to
    /// answer.
    ///
    /// **The write is `repository.deleteGroup`, and the whole of the deletion now survives it.**
    /// This used to go out as `updateVenue` with a lower `groupCount`, because that was the only
    /// door the protocol had onto a venue's courts — and `Camp.upsert(_:)` → `syncGroups(for:)`
    /// reconciles a count rather than honouring a choice: it trimmed the venue's **last** court and
    /// re-seated whoever that orphaned onto the smallest remaining one. So deleting anything but
    /// the last group deleted a *different* group as soon as anything reloaded, and the kids this
    /// method had just stood down were quietly put back on a court by the next write to return a
    /// camp. `UnassignedReason.groupRemoved` was, in consequence, a state that only existed until
    /// the next round trip. `SycamoreRepository.deleteGroup(_:campID:)` carries the reasoning; both
    /// implementations run the same `Camp.removeGroup(_:from:)` this line does.
    ///
    /// **The returned camp is assigned rather than discarded**, which is the one thing here that
    /// differs from `land(_:in:)`'s otherwise identical shape. `land` discards its *first* answer
    /// because that call is half of a two-call intent and the intermediate graph is visibly wrong;
    /// this is one call, and the graph it returns is the same arithmetic run a round trip later.
    /// Where it does differ it is more right, not less: against Postgres it comes back with the
    /// labels, the court ranks and the ladder re-derived from rows, and with anything another
    /// device wrote in between. Discarding that would leave the screen holding a camp nothing else
    /// agrees with.
    ///
    /// Compared before assigning, for the reason `land` compares: the setter bumps `campRevision`
    /// and drops the section memos, so an unconditional write re-derives every court's rows to
    /// arrive at the graph already on screen. Equal is the ordinary case, not the lucky one.
    ///
    /// Guarded on the group actually belonging to the venue named. A caller that has the two out of
    /// step is a caller whose screen has already gone stale, and deleting *something* would be
    /// worse than deleting nothing. The repository takes no venue at all — a row knows its own —
    /// so this guard is the only place the pairing is checked, and here is where it belongs.
    func removeGroup(_ groupID: Group.ID, from venueID: Venue.ID) async {
        guard let campID = camp?.id, var optimistic = camp else { return }
        guard optimistic.group(groupID)?.venueID == venueID else { return }

        let rollback = optimistic
        optimistic.removeGroup(groupID, from: venueID)
        camp = optimistic

        let number = rollback.group(groupID)?.number
        let stranded = rollback.players(inGroup: groupID).count

        await perform {
            do {
                let settled = try await self.repository.deleteGroup(groupID, campID: campID)
                if settled != self.camp { self.camp = settled }
            } catch {
                self.camp = rollback
                throw error
            }
        }

        // No Undo. A deleted group cannot be written back — `deleteGroup` is a delete, not a
        // soft one — so the honest button is none. The count of who is now standing about is the
        // useful half anyway: it is the thing a coach has to act on next.
        guard errorMessage == nil, let number else { return }
        if stranded > 0 {
            say("Group \(number) removed · \(stranded) \(stranded == 1 ? "kid" : "kids") to place")
        } else {
            say("Group \(number) removed")
        }
    }

    /// Adds a venue and immediately gives it the shape somebody just typed.
    ///
    /// **Two writes, and they are two writes on purpose rather than by neglect.**
    /// `Repository.addVenue(campID:)` takes no arguments — it appends a positionally-named venue
    /// copying the last one's numbers — so every caller that wanted a *named* venue has been
    /// following it with `updateVenue` by hand. `OnboardingFlowView.applyShape()` does exactly
    /// this in a loop, and Camp settings' "Add" does not, which is why a venue created there is
    /// always "Venue 4" until somebody opens it again.
    ///
    /// Widening the repository call to take a whole `Venue` would be the better shape and is not
    /// this change: `addVenue` is on both the protocol and its two implementations, and the
    /// Postgres one inserts a row whose defaults the CHECK constraints are written against.
    /// Putting the two-step behind one intent means the *callers* stop having to know, and the
    /// widening — when it happens — happens here and nowhere else.
    ///
    /// The shape is applied by `transform`, which receives the venue the repository actually
    /// created. That is what carries its `id` and `sortIndex`, neither of which the caller can
    /// know in advance, so a caller that built a whole `Venue` value would have to have them
    /// overwritten anyway.
    ///
    /// A failed first write leaves nothing behind; a failed second leaves a default venue named
    /// "Venue N", which is visible, editable, and the same thing "Add" has always produced.
    func addVenue(shapedBy transform: (Venue) -> Venue) async {
        guard let campID = camp?.id else { return }
        let before = Set((camp?.venues ?? []).map(\.id))

        await perform { self.camp = try await self.repository.addVenue(campID: campID) }

        guard errorMessage == nil,
              let created = camp?.venues.first(where: { !before.contains($0.id) })
        else { return }

        let shaped = transform(created)
        await updateVenue(shaped)

        // After the second write, not the first: until `updateVenue` lands, the venue is still
        // the positionally-named "Venue 4" the repository appends, and a toast naming that would
        // be announcing something the reader did not ask for.
        guard errorMessage == nil else { return }
        say("\(shaped.name) added")
    }

    /// The kid's one line, saved once the typing settles.
    ///
    /// **Bounded here, not by the field.** `players_notes_length` is a 280-character CHECK, and a
    /// longer string is a write Postgres refuses rather than one it shortens — so a coach pasting
    /// a paragraph would get an error banner over a note they thought they had written. Trimmed
    /// too: whitespace typed and abandoned is not a note, and "" is what the column defaults to.
    ///
    /// Silent on success. Every write in this app that a reader can see the result of stays
    /// silent, and a note appears in the field as it is typed — a toast saying "Note saved" would
    /// be the app congratulating itself for the thing already on screen.
    func setPlayerNotes(_ playerID: Player.ID, to notes: String) async {
        guard let campID = camp?.id else { return }
        let trimmed = String(
            notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Player.notesLimit)
        )
        guard camp?.player(playerID)?.notes != trimmed else { return }

        await perform {
            self.camp = try await self.repository.setPlayerNotes(
                playerID, notes: trimmed, campID: campID
            )
        }
    }

    /// Takes one kid off the camp for good.
    ///
    /// Through `removePlayers`, which existed but was reachable only from roster reconciliation
    /// (`AppStore+Enrolment.swift`) — so a child who left camp on Tuesday could not be taken off
    /// the list until somebody re-imported the whole spreadsheet without them.
    ///
    /// **No Undo on the toast, and that is not laziness.** `removePlayers` is a delete. Putting
    /// them back would mint a new row with a new id, at the foot of the ladder, with their court
    /// and their rank and their note gone — which is a different child wearing the same name. The
    /// two-tap on the row is where the caution lives instead.
    func removePlayer(_ playerID: Player.ID) async {
        guard let campID = camp?.id else { return }
        let name = camp?.player(playerID)?.displayName

        await perform {
            self.camp = try await self.repository.removePlayers([playerID], campID: campID)
        }

        guard errorMessage == nil, let name else { return }
        say("\(name) removed")
    }

    /// Takes a venue off the camp, with its courts and its kids.
    ///
    /// Optimistic, in the shape `removeGroup` established: mutate the local graph, write, put the
    /// snapshot back if the write throws. A venue leaving is the largest single edit this app
    /// makes and waiting a round trip to watch it happen is the complaint that shape answers.
    ///
    /// **No Undo**, for the reason `removePlayer` has none and more so: the kids are deleted, not
    /// unassigned, and putting a venue back would mint new rows for every one of them at the foot
    /// of the ladder with their courts, ranks and notes gone. The two-tap on the button is the
    /// caution.
    ///
    /// Clears the *chosen* venue when it was this one, so the tabs fall back through
    /// `readVenueID`'s own chain to a venue that still exists rather than holding an id nothing
    /// can resolve. `readVenueID` is derived and cannot be assigned; `chosenVenueID` is the only
    /// link in that chain a reader sets by hand, so it is the only one that can be stale.
    func removeVenue(_ venueID: Venue.ID) async {
        guard let campID = camp?.id, var optimistic = camp else { return }
        guard let leaving = optimistic.venue(venueID) else { return }

        let rollback = optimistic
        let kids = optimistic.players(in: venueID).count
        optimistic.removeVenue(venueID)
        camp = optimistic
        if chosenVenueID == venueID { chosenVenueID = nil }

        await perform {
            do {
                let settled = try await self.repository.deleteVenue(venueID, campID: campID)
                if settled != self.camp { self.camp = settled }
            } catch {
                self.camp = rollback
                throw error
            }
        }

        guard errorMessage == nil else { return }
        if kids > 0 {
            say("\(leaving.name) removed · \(kids) \(kids == 1 ? "kid" : "kids") with it")
        } else {
            say("\(leaving.name) removed")
        }
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
        let row = assignmentActivity(staffID, toGroup: groupID)
        await perform {
            self.camp = try await self.repository.assignStaff(
                staffID, toGroup: groupID, campID: campID
            )
            try await self.log(row, forCamp: campID)
            // The courts are re-read here rather than by each caller, and that is the whole of
            // this addition. `CourtCard.coachName` is not a stored field — the repository derives
            // it from `today_courts` at read time — so the camp graph coming back from the write
            // above does not carry it. Without this the write lands and the pill goes on saying
            // "Needs a coach", which is the screen lying about something it just did.
            //
            // Overview's picker had worked around it locally and its own comment says the reload
            // belongs in here, naming `StaffSheet.swift:141` and `:151` as the two callers that
            // do not have one. They do now. A fact this write invalidates is this write's to
            // refresh — a caller that forgets is a screen that goes quietly stale.
            // Skipped rather than guessed when there is no venue to read: `courts` is scoped to
            // one, and there is no sensible stand-in for "which one".
            if let venueID = self.readVenueID {
                self.courts = try await self.repository.courts(
                    forVenue: venueID, campID: campID
                )
            }
        }
    }

    func removeStaff(_ staffID: StaffMember.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.removeStaff(staffID, campID: campID)
            self.activeSheet = nil
        }
    }

    /// Saves the profile, then brings this camp's copy of it along.
    ///
    /// **`coaches.name` and `coaches.phone` are a denormalisation, and nothing was maintaining
    /// it.** They are written once, out of the profile, at the moment somebody joins or creates a
    /// camp. Editing your name here wrote `profiles` and stopped — so the Staff list, every staff
    /// sheet and every coach chip went on showing the name you signed up with, and to everybody
    /// else in the camp the rename had simply not happened. The one person who could not see the
    /// bug was the one who caused it.
    ///
    /// Only the camp in hand. A person in four camps has four staff rows, and reaching into the
    /// other three would mean loading three graphs to patch a row in each — on the main actor,
    /// while somebody waits for a name field to settle. The others come right the next time each
    /// camp is opened, which is the same moment their own screens would have shown the stale
    /// value anyway.
    ///
    /// Second write, not folded into the first: `updateAccount` is `profiles` and this is
    /// `coaches`, and a profile that saved while the camp write failed should still be saved.
    func updateAccount(_ updated: Account) async {
        await perform {
            let saved = try await self.repository.updateAccount(updated)
            self.auth = .signedIn(saved)
        }

        guard errorMessage == nil,
              let campID = camp?.id,
              let mine = camp?.staff.first(where: { $0.accountID == updated.id }),
              mine.name != updated.displayName || mine.phone != updated.emergencyPhone
        else { return }

        await perform {
            self.camp = try await self.repository.updateStaffIdentity(
                mine.id,
                name: updated.displayName,
                phone: updated.emergencyPhone,
                campID: campID
            )
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

    /// Opens a pushed screen, remembering what it covered.
    ///
    /// Assigning `pushedScreen` directly is still fine — and is what the thirty-odd call sites
    /// that *replace* one screen with another, or open one from a tab, go on doing. This is for
    /// the handful that open a screen from another screen and owe it a way back.
    func push(_ screen: PushedScreen) {
        let covered = pushedScreen
        isPushing = true
        pushedScreen = screen
        isPushing = false
        previousPushedScreen = covered
    }

    /// The way back: whatever `push` covered, or the tabs if it covered nothing.
    func popPushed() {
        pushedScreen = previousPushedScreen
        previousPushedScreen = nil
    }

    func present(_ sheet: ActiveSheet) { activeSheet = sheet }
    func dismissSheet() { activeSheet = nil }

    /// Says what happened. Replaces whatever was up: two writes in a row means the second is
    /// the one worth reading, and a queue would make a person wait 3.2 seconds to be told
    /// something about a screen they have already left.
    func say(_ message: String, undo: (@Sendable @MainActor () -> Void)? = nil) {
        toast = Toast(message, undo: undo)
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
        // Guarded. `@Observable` does not compare before it fires, so clearing an
        // `errorMessage` that was already nil still announces a mutation — and `errorMessage`
        // is read by `MainTabView.body`, by every sheet and by every pushed screen
        // (`RootView.swift:100`, `:105`, `:166`). Unguarded, *every* intent in the app
        // invalidated the whole tab tree before it had done any work at all.
        if errorMessage != nil { errorMessage = nil }
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

    /// The same person and camp as `preview`, with the UCLA membership promoted to admin.
    ///
    /// Section 8 draws a handful of things only an admin sees — the note composer, the per-note
    /// delete, the "Assign" on an uncovered block, the pinned-message field — and neither
    /// existing fixture could show them. `preview` is Alex, a *worker* at UCLA; `previewAdmin` is
    /// an admin of Westside Swim, which has none of the venues or staff those screens are built
    /// from, so its previews would draw an empty screen for the opposite reason. Two features
    /// each patched the hole locally before this existed.
    ///
    /// Promoting the membership is the smallest change that keeps the camp: `role` lives on the
    /// membership and never on the account, which is `Role`'s own argument — the same login can
    /// be an admin at one camp and a worker at another.
    static var previewUCLAAdmin: AppStore {
        let store = preview
        var membership = SampleData.uclaMembership
        membership.role = .admin
        store.selectedMembership = membership
        return store
    }
}
