//
//  Models.swift
//  Sycamore
//
//  The whole domain, as value types. Nothing here imports SwiftUI or UIKit, so the
//  model compiles and can be exercised on any platform.
//
//  NOTE ON `Group`: this module declares `Group`, which shadows `SwiftUI.Group` for
//  unqualified lookup inside the app target. Feature files that want SwiftUI's view
//  builder must write `SwiftUI.Group { … }`. `CourtGroup` is a typealias for the
//  domain type if you prefer the unambiguous spelling.
//

import Foundation

// MARK: - Small shared vocabulary

/// The design writes people as the first two letters of the name they go by:
/// "Alex Ramos" → `AL`, "Nass" → `NA`, "Renée" → `RE`.
enum Initials {
    static func make(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        return String(trimmed.prefix(2)).uppercased()
    }
}

/// A kid's gender, and the three ways the app says it.
///
/// The raw values are load-bearing and must not be renamed: Postgres stores `M` / `F` / `X`, and
/// both directions of the wire go through `PostgresEnum` — `gender(_:)` in, `text(_:)` out —
/// which upper- and lower-cases the raw value the same way it does for every other enum.
/// `Codable` rides the same raw values. Every display string below is free to change.
///
/// The write path used to send `symbol`, which produced the identical letter and so looked
/// correct, but it made a display property into a column encoding: restyling the meta line
/// would have corrupted `players.gender` on the next write, with no test in between.
///
/// **What `.x` means, and why the strings pick a side.** It is two things at once and this type
/// cannot tell them apart: a camp that chose the third answer on `8e`, and a row whose gender
/// column was blank — `IntakePlayer.asPlayer()` coerces `gender ?? .x` because `Player.gender`
/// cannot be nil. The strings below say the *answer*, not the absence, for two reasons:
///
/// - The absence is already modelled properly one layer up. `IntakePlayer.gender` is optional,
///   a nil raises `IntakeIssue.noGender`, and `8d` asks about it by name. The coercion only
///   happens after somebody has been shown that gap and imported the row anyway.
/// - The input claims a choice. `8e` offers "Other" as a chip you tap, so reading it back as
///   "gender not recorded" tells a user their answer did not land — which is what the roster
///   row used to do, in the same breath as the chip that had just accepted it.
///
/// Both readings cannot be right, so this is a choice about which mistake to make. Calling a
/// blank column "Other" under-claims; calling a deliberate answer "not recorded" contradicts
/// the person who gave it. The first is the cheaper of the two.
enum Gender: String, Codable, Hashable, CaseIterable, Sendable {
    case m, f, x

    /// The middle field of a player's meta line: `13 · F · returning`.
    ///
    /// Deliberately still a letter, and deliberately the only display string that is. Every
    /// screen that draws gender now draws `GenderMark` instead — but `Player.metaLine` is a
    /// `String`, interpolated into one run of text by `GroupsLockedState`, and a `Shape` cannot
    /// go in a `String`. Contorting the model into returning a view for the sake of one line
    /// would cost more than the divergence does; this is the divergence, written down.
    var symbol: String {
        switch self {
        case .m: "M"
        case .f: "F"
        case .x: "X"
        }
    }

    /// The answer, as `8e` offers it and as VoiceOver reads it back wherever the app draws a
    /// mark instead of a word: `Girl` / `Boy` / `Other`.
    ///
    /// One string serving both directions on purpose. It was five strings across four files —
    /// `Girl`/`Boy`/`Prefer not to say` on the chip, `Girl`/`Boy`/`Gender not recorded` on
    /// Groups, `Female`/`Male`/`Unspecified` on Overview — and the third column disagreed with
    /// itself three ways. A reader who taps "Other" and then hears "gender not recorded" has
    /// been told their answer was a gap.
    var label: String {
        switch self {
        case .m: "Boy"
        case .f: "Girl"
        case .x: "Other"
        }
    }

    /// The kid, in prose: `Girl · 13 years` under a name on `8q`.
    ///
    /// Deliberately not `label`. "Other · 13 years" categorises a child where the sentence is
    /// meant to describe one, and `8q` is a page about that single kid. `Kid` makes the same
    /// refusal to gender them that `Other` does, in the register the line is written in.
    ///
    /// Written as the one case that differs rather than a second three-case switch, so that
    /// "the prose noun is the chip's answer except for `.x`" is the shape of the code and not
    /// a fact a test has to assert.
    var noun: String { self == .x ? "Kid" : label }
}

/// Camp weeks run Monday to Friday; the early pick-up sheet offers exactly these five.
enum Weekday: Int, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case mon = 1, tue, wed, thu, fri

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .mon: "Mon"
        case .tue: "Tue"
        case .wed: "Wed"
        case .thu: "Thu"
        case .fri: "Fri"
        }
    }

    /// Written out, for prose rather than a chip — Schedule's empty state says
    /// "Friday is empty." Spelled here rather than at the call site so the two spellings of a
    /// day can never drift apart.
    var fullName: String {
        switch self {
        case .mon: "Monday"
        case .tue: "Tuesday"
        case .wed: "Wednesday"
        case .thu: "Thursday"
        case .fri: "Friday"
        }
    }

    /// The app has no clock of its own yet — the offline build is always "Wednesday",
    /// which is the day the design's screens depict. Swap this for a real calendar
    /// lookup when the backend lands.
    static var today: Weekday { .wed }
}

/// A wall-clock time with no date attached. Early pick-up only ever needs `14:30`.
struct TimeOfDay: Codable, Hashable, Comparable, Identifiable, Sendable {
    var hour: Int
    var minute: Int

    init(_ hour: Int, _ minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    var id: Int { hour * 60 + minute }
    var formatted: String { String(format: "%02d:%02d", hour, minute) }

    /// The 12-hour spelling the design uses for a moment rather than a deadline:
    /// `9:12am`, `2:30pm`. Deliberately locale-independent — this is the camp's own
    /// clock, and the design writes it exactly this way.
    var clockLabel: String {
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d%@", hour12, minute, hour < 12 ? "am" : "pm")
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.id < rhs.id }

    /// The wall clock, as the camp's own time-of-day.
    ///
    /// Here rather than in whichever screen wanted it first: two things now need to know which
    /// block is running, and a clock the model cannot read is a rule the model cannot own.
    /// `Weekday.today` is still a stub returning Wednesday — this is not, so the two disagree
    /// until that one is given a real calendar.
    static func now(_ date: Date = .now, calendar: Calendar = .current) -> TimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(parts.hour ?? 0, parts.minute ?? 0)
    }

    /// 12:00 → 15:30 in half-hour steps, exactly the eight pills in the design.
    static let pickupOptions: [TimeOfDay] = stride(from: 12 * 60, through: 15 * 60 + 30, by: 30)
        .map { TimeOfDay($0 / 60, $0 % 60) }
}

// MARK: - Role

/// Permissions live on the membership, never on the account: the same login can be an
/// admin at one camp and a worker at another.
enum Role: Codable, Hashable, Sendable {
    case admin
    case worker
    case trainer
    case other(label: String)

    /// Badge and chip text: "Admin", "Worker", "Trainer", or the custom label.
    var displayName: String {
        switch self {
        case .admin: "Admin"
        case .worker: "Worker"
        case .trainer: "Trainer"
        case .other(let label):
            label.trimmingCharacters(in: .whitespaces).isEmpty ? "Other" : label
        }
    }

    /// The four fixed chips in the staff sheet — a custom label still selects "Other".
    var chipTitle: String {
        switch self {
        case .other: "Other"
        default: displayName
        }
    }

    /// Setup's staff card qualifies a custom role: `Other · front desk`.
    var staffRowLabel: String {
        switch self {
        case .other(let label) where !label.trimmingCharacters(in: .whitespaces).isEmpty:
            "Other · \(label)"
        default:
            displayName
        }
    }

    /// How the camp picker names the role. On a court a worker is a coach, which is why
    /// the design's membership row reads `Coach · Sycamore, Court 3` while the profile
    /// badge for the same person reads `Worker`.
    var membershipName: String {
        switch self {
        case .worker: "Coach"
        default: displayName
        }
    }

    var isAdmin: Bool { self == .admin }

    /// A trainer roams by default; nobody else does.
    var roamsByDefault: Bool { self == .trainer }

    /// The order the role chips appear in, in the staff sheet.
    static let selectable: [Role] = [.admin, .worker, .trainer, .other(label: "")]

    /// Chip equality has to ignore the custom label so "Other · front desk" still
    /// lights up the "Other" chip.
    func matchesChip(_ chip: Role) -> Bool {
        switch (self, chip) {
        case (.other, .other): true
        default: self == chip
        }
    }
}

// MARK: - Sport

enum Sport: Codable, Hashable, Sendable {
    case tennis
    case soccer
    case basketball
    case swim
    case other(label: String)

    var displayName: String {
        switch self {
        case .tennis: "Tennis"
        case .soccer: "Soccer"
        case .basketball: "Basketball"
        case .swim: "Swim"
        case .other(let label):
            label.trimmingCharacters(in: .whitespaces).isEmpty ? "Other" : label
        }
    }

    var chipTitle: String {
        switch self {
        case .other: "Other"
        default: displayName
        }
    }

    /// What a group is called in this sport — courts, fields, lanes.
    var groupNoun: String {
        switch self {
        case .tennis, .basketball: "Court"
        case .soccer: "Field"
        case .swim: "Lane"
        case .other: "Group"
        }
    }

    static let selectable: [Sport] = [.tennis, .soccer, .basketball, .swim, .other(label: "")]

    func matchesChip(_ chip: Sport) -> Bool {
        switch (self, chip) {
        case (.other, .other): true
        default: self == chip
        }
    }
}

// MARK: - Venue

/// The tint behind a venue's emoji tile — a semantic token, not a colour. The model
/// layer never spells a hex: the design system owns the values and resolves a case
/// through `Theme.color(for:)`. `Venue.tint` is the single source of truth for which
/// tile a venue gets; nothing should re-derive it from the emoji.
enum VenueTint: String, Codable, Hashable, CaseIterable, Sendable {
    case moss    // 🌳 Sycamore
    case sky     // 🏊 Westside
    case citron  // 🎾 LATC

    /// The design pairs a tint with an emoji; new venues inherit that pairing.
    static func suggested(for icon: String) -> VenueTint {
        switch icon {
        case "🌳", "🏆", "⭐": .moss
        case "🎾", "🔥": .citron
        default: .sky
        }
    }
}

/// `In range` when the venue has between `coachMin` and `coachMax` coaches on site,
/// otherwise the badge names the gap.
enum StaffingStatus: Hashable, Sendable {
    case inRange
    case coachesShort(Int)
    case coachesOver(Int)

    /// The badge on Setup's venue row.
    var badgeText: String {
        switch self {
        case .inRange: "In range"
        case .coachesShort(let n): "\(n) coach\(n == 1 ? "" : "es") short"
        case .coachesOver(let n): "\(n) over"
        }
    }

    /// The banner at the top of the venue sheet.
    var bannerText: String {
        switch self {
        case .inRange: "Within range"
        case .coachesShort(let n): "\(n) coach\(n == 1 ? "" : "es") short"
        case .coachesOver(let n): "\(n) coach\(n == 1 ? "" : "es") over the limit"
        }
    }

    /// Grey when in range, blue-tinted when it needs someone's attention.
    var needsAttention: Bool { self != .inRange }
}

struct Venue: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    /// "Higher level" — optional, shown uppercased next to the venue heading.
    var subtitle: String?
    var icon: String
    var tint: VenueTint
    var groupCount: Int
    var coachMin: Int
    var coachMax: Int
    var playerMin: Int
    var playerMax: Int
    /// Display order inside the camp; also the order the rank ladder runs in.
    var sortIndex: Int = 0

    func staffingStatus(coachCount: Int) -> StaffingStatus {
        if coachCount < coachMin { return .coachesShort(coachMin - coachCount) }
        if coachCount > coachMax { return .coachesOver(coachCount - coachMax) }
        return .inRange
    }

    /// The `4 – 7` reading in the venue sheet's limits card.
    var coachRangeLabel: String { "\(coachMin) – \(coachMax)" }
    var playerRangeLabel: String { "\(playerMin) – \(playerMax)" }

    /// The six tiles in the venue sheet's icon grid.
    static let iconOptions = ["🌳", "🎾", "🏆", "🔥", "⭐", "🌊"]
}

// MARK: - Group

/// A court, field or lane. One coach, one slice of the venue's kids.
struct Group: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var venueID: Venue.ID
    /// 1-based position inside the venue — renders as `C3` in a court chip.
    var number: Int
    /// "Court 1" / "Lane 2" — the sport's noun plus the number.
    var label: String
    /// Where this group sits in the venue's rank ladder; equals `number` until someone
    /// reorders the courts.
    var rankOrder: Int
    var coachID: StaffMember.ID?
    /// Working head-count ceiling for one court. Derived from the venue at seed time —
    /// see `SampleData` — and stored so the over-capacity banner is a pure read.
    var capacity: Int
    /// What this court is doing, when that is not what the running block says. `8i` titles four
    /// cards "Drills", "Match play", "Skills rotation" and "Net down" while the header reads
    /// "Skills rotation · until 10:30" — three of the four disagree with the block, so a court
    /// that has gone its own way needs somewhere to say so. Nil means it has not: follow the
    /// schedule, which is what every seeded court does.
    var activity: String?

    /// Denormalised counts. Maintained by `Camp.reindex()`; never set these by hand
    /// outside the model layer.
    var playerCount: Int = 0
    var presentCount: Int = 0

    var courtCode: String { "C\(number)" }

    /// The coach card's second line: `Court 1 · 8 here`.
    var headcountLine: String { "\(label) · \(presentCount) here" }

    /// Over-capacity is measured against who is actually on the court today, which is
    /// why a court with an away kid can sit at nine on paper and still read "in range".
    var isOverCapacity: Bool { presentCount > capacity }
    var overCapacityBy: Int { max(0, presentCount - capacity) }

    /// The inline blue banner on a coach card: `1 over — move one kid down`.
    var capacityBanner: String? {
        let over = overCapacityBy
        guard over > 0 else { return nil }
        return over == 1
            ? "1 over — move one kid down"
            : "\(over) over — move \(over) kids down"
    }
}

/// Unambiguous spelling for files that also use `SwiftUI.Group`.
typealias CourtGroup = Group

// MARK: - Player

struct Player: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var firstName: String
    /// A single letter. Camps write kids as "Serene C" so two Liams stay apart.
    var lastInitial: String
    /// The whole surname, once a camp has collected one. It sits beside `lastInitial` rather than
    /// replacing it: the initial is all every existing row holds, and "Chu" cannot be recovered
    /// from "C", so the two have to coexist while imports fill this in.
    var lastName: String?
    /// Nil for a roster row that arrived without an age — `8d` ("Check the import") is the screen
    /// for exactly those. The column has always been nullable and 41 of the 100 seeded kids are
    /// null in it; the zero this used to stand in reads as a real age *and* is rejected by the
    /// column's own CHECK, which admits 4…19 and nothing else.
    var age: Int?
    var gender: Gender
    var isReturning: Bool
    var venueID: Venue.ID?
    var groupID: Group.ID?
    /// Position in the camp-wide 1…N ladder shown on the Rank tab.
    var overallRank: Int
    /// Position inside the court, which a coach can reorder independently.
    var courtRank: Int

    /// "Serene Chu" once there is a surname, "Serene C" while there is only the initial.
    ///
    /// The design writes the full name on every screen that names a kid, so the surname wins when
    /// there is one. The fallback is not a courtesy — it is what keeps all 100 existing rows, and
    /// the ~21 files that read this, rendering unchanged while `last_name` fills in. A kid with
    /// neither is their first name alone, rather than a name with a space hung off the end.
    /// A whole name is ordered by `PersonNameComponents` rather than glued together with a space:
    /// given-then-family is an English convention, not a fact about names, and the formatter reads
    /// "Serene Chu" in the design's locale while still ordering it correctly in one that puts the
    /// family name first. The initial keeps the plain spelling — "C" is not a family name, and
    /// there is nothing for the formatter to order.
    var displayName: String {
        let surname = lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !surname.isEmpty else {
            return lastInitial.isEmpty ? firstName : "\(firstName) \(lastInitial)"
        }
        var components = PersonNameComponents()
        components.givenName = firstName
        components.familyName = surname
        return components.formatted(.name(style: .medium))
    }

    /// `13 years` under a name that read cleanly, and `Age unknown` for one that did not — the
    /// two readings `8d` puts side by side.
    var ageLabel: String {
        guard let age else { return "Age unknown" }
        return "\(age) year\(age == 1 ? "" : "s")"
    }

    /// `13 · F · returning`, or `12 · M` for a first-timer.
    ///
    /// An unknown age drops out of the line rather than showing as a gap: the meta line is read at
    /// a glance beside a name, and `· F ·` with nothing in front of it says "not recorded" more
    /// plainly than a dash would.
    var metaLine: String {
        var parts: [String] = []
        if let age { parts.append("\(age)") }
        parts.append(gender.symbol)
        if isReturning { parts.append("returning") }
        return parts.joined(separator: " · ")
    }

    /// Matches the search field, which looks at kids and coaches together.
    ///
    /// `localizedStandardContains` rather than a lowercased `contains`: it folds case *and*
    /// diacritics the way the reader's locale expects, so searching "jose" finds José and
    /// "muller" finds Müller. Lowercasing alone leaves the accent in place and misses both.
    /// It handles the folding itself, so the needle is only trimmed.
    func matches(search term: String) -> Bool {
        let needle = term.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return displayName.localizedStandardContains(needle)
            || firstName.localizedStandardContains(needle)
    }
}

// MARK: - Staff

/// Where a staff member stands today. Carries the venue's emoji and the group's number
/// so a court chip renders without walking back to the camp graph.
struct CourtAssignment: Hashable, Codable, Sendable {
    var venueID: Venue.ID
    var venueName: String
    var venueIcon: String
    var groupID: Group.ID
    var groupNumber: Int
    var groupLabel: String

    var courtCode: String { "C\(groupNumber)" }
    /// `🌳 C1`
    var chip: String { "\(venueIcon) \(courtCode)" }
    /// `Sycamore · Court 1`
    var pathLabel: String { "\(venueName) · \(groupLabel)" }
    /// `Sycamore, Court 3` — the comma form used in the camp picker.
    var pickerLabel: String { "\(venueName), \(groupLabel)" }
}

struct StaffMember: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    /// Set once the person has actually signed in; nil for someone who has been invited
    /// but never opened the app.
    var accountID: Account.ID?
    var name: String
    var role: Role
    var phone: String?
    /// A trainer with no fixed court. Renders as `Roaming` instead of a court chip.
    var isRoaming: Bool = false
    var assignment: CourtAssignment?

    var initials: String { Initials.make(from: name) }
    var venueID: Venue.ID? { assignment?.venueID }
    var groupID: Group.ID? { assignment?.groupID }
    /// Unassigned staff are a filter in Setup, not a run of grey rows.
    var isUnassigned: Bool { assignment == nil }

    /// The trailing column of Setup's staff row: `🌳 C1`, `Roaming`, or `—`.
    var courtChip: String {
        if let assignment { return assignment.chip }
        return isRoaming ? "Roaming" : "—"
    }

    /// The staff sheet's subtitle: `Worker · Sycamore · Court 3`.
    var detailLine: String {
        if let assignment { return "\(role.displayName) · \(assignment.pathLabel)" }
        if isRoaming { return "\(role.displayName) · Roaming" }
        return role.staffRowLabel
    }

    /// See `Player.matches(search:)` for why this folds through `localizedStandardContains`.
    func matches(search term: String) -> Bool {
        let needle = term.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return name.localizedStandardContains(needle)
    }
}

// MARK: - The day

/// Sparse: a row only exists when something differs from "here all day", so the absence
/// of a record means present and staying to the end.
struct Attendance: Identifiable, Hashable, Codable, Sendable {
    var playerID: Player.ID
    var day: Weekday
    var present: Bool
    var leavesAt: TimeOfDay?

    var id: String { "\(playerID.uuidString)-\(day.rawValue)" }

    /// `Leaves Wed at 14:30` — also the label on the early pick-up confirm bar.
    var leavingEarlyLabel: String? {
        guard let leavesAt else { return nil }
        return "Leaves \(day.shortName) at \(leavesAt.formatted)"
    }
}

struct HistoryEvent: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var playerID: Player.ID
    var title: String
    var detail: String
    /// The blue dot. Marks the event worth noticing, not necessarily the newest one.
    var isAccent: Bool
    var at: Date
}

// MARK: - Account and membership

struct Account: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var email: String
    var displayName: String
    /// The profile photo well writes back here; nil shows the initials placeholder.
    var avatarImageData: Data?
    var emergencyPhone: String?
    var notificationsEnabled: Bool = true

    var initials: String { Initials.make(from: displayName) }

    /// `(310) 555-0106 · visible to admins`
    var emergencyPhoneDetail: String {
        guard let emergencyPhone, !emergencyPhone.isEmpty else {
            return "Add one · visible to admins"
        }
        return "\(emergencyPhone) · visible to admins"
    }
}

/// What the person is doing at a camp today. Denormalised for the camp picker and the
/// profile header, which both need it before the camp graph is loaded.
struct TodayAssignment: Hashable, Codable, Sendable {
    var venueID: Venue.ID
    var venueName: String
    var venueIcon: String
    /// The venue's own tint token — what Profile's icon tile reads. Never re-derive this
    /// from `venueIcon`.
    var venueTint: VenueTint
    var groupID: Group.ID
    var groupLabel: String
    var kidCount: Int
    var presentCount: Int
    /// When the coach last committed an order, as a wall-clock time. `summaryLine`
    /// spells it `9:12am`; nothing stores that string.
    var rankedAt: TimeOfDay?

    /// `Sycamore · Court 3`
    var pathLabel: String { "\(venueName) · \(groupLabel)" }
    /// `Sycamore, Court 3`
    var pickerLabel: String { "\(venueName), \(groupLabel)" }

    /// `8 kids · 7 here · ranked 9:12am`
    var summaryLine: String {
        var parts = ["\(kidCount) kids", "\(presentCount) here"]
        if let rankedAt { parts.append("ranked \(rankedAt.clockLabel)") }
        return parts.joined(separator: " · ")
    }
}

/// The join between a person and a camp. Role lives here, not on the account.
struct Membership: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var accountID: Account.ID
    var campID: Camp.ID
    var role: Role
    var todayAssignment: TodayAssignment?

    // Projections of the camp, so the picker can draw a row without loading the graph.
    var campName: String
    var campIcon: String
    var campTint: VenueTint
    /// `3 venues · 74 kids` — used when there is no court to name.
    var campSummary: String?

    /// The camp picker's second line: `Coach · Sycamore, Court 3`
    /// or `Admin · 3 venues · 74 kids`.
    var subtitle: String {
        if let todayAssignment {
            return "\(role.membershipName) · \(todayAssignment.pickerLabel)"
        }
        if let campSummary {
            return "\(role.membershipName) · \(campSummary)"
        }
        return role.membershipName
    }
}

// MARK: - Camp

/// One camp-shaped block of rank order, used when the Rank tab commits a drag. Each
/// entry is a venue section in top-to-bottom order; a kid dragged across a venue rule
/// simply arrives in a different entry.
struct RankAssignment: Hashable, Sendable {
    var venueID: Venue.ID
    var playerIDs: [Player.ID]
}

/// What the "New camp" screen collects. Two answers now, the rest lives in Setup.
struct CampDraft: Hashable, Sendable {
    var name: String = ""
    var sport: Sport = .tennis
    var venueCount: Int = 2
    var groupsPerVenue: Int = 6

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    static let venueRange = 1...8
    static let groupRange = 1...16
}

/// The whole graph for one camp. Loaded in one shot, mutated in one shot.
struct Camp: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var sport: Sport
    /// `SYC-4821`
    var inviteCode: String
    var icon: String
    var tint: VenueTint
    var venues: [Venue] = []
    var groups: [Group] = []
    var players: [Player] = []
    var staff: [StaffMember] = []
    /// Sparse — only kids who are away or leaving early.
    var attendance: [Attendance] = []
    var history: [HistoryEvent] = []
}

// MARK: - Camp reads

extension Camp {
    var orderedVenues: [Venue] { venues.sorted { $0.sortIndex < $1.sortIndex } }
    var orderedPlayers: [Player] { players.sorted { $0.overallRank < $1.overallRank } }

    var playerCount: Int { players.count }
    var venueCount: Int { venues.count }
    var staffCount: Int { staff.count }

    /// `3 venues · 74 kids`
    var summaryLine: String {
        "\(venueCount) venue\(venueCount == 1 ? "" : "s") · \(playerCount) kids"
    }

    func venue(_ id: Venue.ID) -> Venue? { venues.first { $0.id == id } }
    func group(_ id: Group.ID) -> Group? { groups.first { $0.id == id } }
    func player(_ id: Player.ID) -> Player? { players.first { $0.id == id } }
    func staff(_ id: StaffMember.ID) -> StaffMember? { staff.first { $0.id == id } }

    func groups(in venueID: Venue.ID) -> [Group] {
        groups.filter { $0.venueID == venueID }.sorted { $0.rankOrder < $1.rankOrder }
    }

    func players(in venueID: Venue.ID) -> [Player] {
        players.filter { $0.venueID == venueID }.sorted { $0.overallRank < $1.overallRank }
    }

    func players(inGroup groupID: Group.ID) -> [Player] {
        players.filter { $0.groupID == groupID }.sorted { $0.courtRank < $1.courtRank }
    }

    /// Anyone standing on a court in this venue. Roamers belong to no venue and are not
    /// counted against its coach limits.
    func coaches(in venueID: Venue.ID) -> [StaffMember] {
        staff.filter { $0.assignment?.venueID == venueID }
    }

    func coachCount(in venueID: Venue.ID) -> Int { coaches(in: venueID).count }

    func coach(forGroup groupID: Group.ID) -> StaffMember? {
        staff.first { $0.assignment?.groupID == groupID }
    }

    func unassignedStaff() -> [StaffMember] { staff.filter(\.isUnassigned) }

    func staffingStatus(for venueID: Venue.ID) -> StaffingStatus? {
        venue(venueID).map { $0.staffingStatus(coachCount: coachCount(in: venueID)) }
    }

    /// Setup's venue row: `6 groups · 50 kids · 6 coaches`.
    func rowSummary(for venueID: Venue.ID) -> String {
        guard let venue = venue(venueID) else { return "" }
        let kids = players(in: venueID).count
        let coaches = coachCount(in: venueID)
        return "\(venue.groupCount) groups · \(kids) kids · \(coaches) coaches"
    }

    /// The venue sheet's subtitle: `50 kids · 6 coaches · 6 groups`.
    func sheetSummary(for venueID: Venue.ID) -> String {
        guard let venue = venue(venueID) else { return "" }
        return "\(players(in: venueID).count) kids · \(coachCount(in: venueID)) coaches · \(venue.groupCount) groups"
    }

    /// `1–50` — where this venue's block sits in the camp-wide ladder.
    func rankRange(for venueID: Venue.ID) -> ClosedRange<Int>? {
        let ranks = players(in: venueID).map(\.overallRank)
        guard let low = ranks.min(), let high = ranks.max() else { return nil }
        return low...high
    }

    func rankRangeLabel(for venueID: Venue.ID) -> String {
        guard let range = rankRange(for: venueID) else { return "—" }
        return "\(range.lowerBound)–\(range.upperBound)"
    }

    /// `45 more in Sycamore` — the collapsed run in the middle of a Rank section.
    func collapsedRunLabel(for venueID: Venue.ID, hidden: Int) -> String {
        "\(hidden) more in \(venue(venueID)?.name ?? "this venue")"
    }

    // MARK: The day

    func attendance(for playerID: Player.ID, on day: Weekday = .today) -> Attendance? {
        attendance.first { $0.playerID == playerID && $0.day == day }
    }

    func isAway(_ playerID: Player.ID, on day: Weekday = .today) -> Bool {
        attendance(for: playerID, on: day)?.present == false
    }

    func leavesAt(_ playerID: Player.ID, on day: Weekday = .today) -> TimeOfDay? {
        attendance(for: playerID, on: day)?.leavesAt
    }

    func isLeavingEarly(_ playerID: Player.ID, on day: Weekday = .today) -> Bool {
        leavesAt(playerID, on: day) != nil
    }

    /// Events in authored order — the design leads Austin Z's timeline with the move he
    /// made on Tuesday, not with this morning's ranking.
    func history(for playerID: Player.ID) -> [HistoryEvent] {
        history.filter { $0.playerID == playerID }
    }

    /// `Sycamore · Court 1 · Nass` — the player sheet's subtitle.
    func placementLine(for playerID: Player.ID) -> String {
        guard let player = player(playerID) else { return "" }
        var parts: [String] = []
        if let venueID = player.venueID, let venue = venue(venueID) { parts.append(venue.name) }
        if let groupID = player.groupID, let group = group(groupID) {
            parts.append(group.label)
            if let coach = coach(forGroup: groupID) { parts.append(coach.name) }
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Camp mutations

extension Camp {
    /// Renumbers both ladders and refreshes the denormalised group counts. Every
    /// mutation below ends here, so the counts a view reads are never stale.
    ///
    /// `presentCount` describes **today** and nothing else, so this takes no day
    /// argument: a court's "8 here" is a statement about the kids standing on it right
    /// now, not about whichever day an attendance row happens to have been written for.
    /// Letting a caller pass its own day is what made a Monday pick-up recount all
    /// twelve courts against a Monday with no away-records and report every court full.
    mutating func reindex() {
        players.sort { $0.overallRank < $1.overallRank }
        for index in players.indices {
            players[index].overallRank = index + 1
        }

        // Court order is the coach's business: keep the existing sequence and just close
        // the gaps left by whoever moved out.
        var indicesByGroup: [Group.ID: [Int]] = [:]
        for index in players.indices {
            guard let groupID = players[index].groupID else { continue }
            indicesByGroup[groupID, default: []].append(index)
        }

        for indices in indicesByGroup.values {
            let sorted = indices.sorted {
                let a = players[$0], b = players[$1]
                return a.courtRank == b.courtRank ? a.overallRank < b.overallRank : a.courtRank < b.courtRank
            }
            for (offset, index) in sorted.enumerated() {
                players[index].courtRank = offset + 1
            }
        }

        for index in groups.indices {
            let members = players.filter { $0.groupID == groups[index].id }
            groups[index].playerCount = members.count
            groups[index].presentCount = members.count { !isAway($0.id, on: .today) }
            groups[index].coachID = coach(forGroup: groups[index].id)?.id
        }
    }

    /// `day` says which row to write. It deliberately does not reach the reindex —
    /// head-counts are always recomputed against `today`, whatever day was edited.
    mutating func setAttendance(playerID: Player.ID, day: Weekday, present: Bool) {
        upsertAttendance(playerID: playerID, day: day) { record in
            record.present = present
            if !present { record.leavesAt = nil }
        }
        reindex()
    }

    /// Same rule as `setAttendance`: a pick-up scheduled for Friday changes Friday's
    /// row, and leaves every court's "N here" reading today's attendance.
    mutating func setEarlyPickup(playerID: Player.ID, day: Weekday, leavesAt: TimeOfDay?) {
        upsertAttendance(playerID: playerID, day: day) { record in
            record.leavesAt = leavesAt
        }
        reindex()
    }

    private mutating func upsertAttendance(
        playerID: Player.ID,
        day: Weekday,
        _ edit: (inout Attendance) -> Void
    ) {
        if let index = attendance.firstIndex(where: { $0.playerID == playerID && $0.day == day }) {
            edit(&attendance[index])
            // Drop the row again once it says nothing: present, staying to the end.
            if attendance[index].present, attendance[index].leavesAt == nil {
                attendance.remove(at: index)
            }
        } else {
            var record = Attendance(playerID: playerID, day: day, present: true, leavesAt: nil)
            edit(&record)
            if !(record.present && record.leavesAt == nil) { attendance.append(record) }
        }
    }

    /// Commits a drag inside one court.
    mutating func reorder(group groupID: Group.ID, playerIDs: [Player.ID]) {
        let venueID = group(groupID)?.venueID
        for (offset, playerID) in playerIDs.enumerated() {
            guard let index = players.firstIndex(where: { $0.id == playerID }) else { continue }
            players[index].groupID = groupID
            players[index].courtRank = offset + 1
            if let venueID { players[index].venueID = venueID }
        }
        reindex()
    }

    /// Commits a drag on the Rank tab. Venue membership follows the section a kid
    /// landed in, which is how crossing a venue rule reassigns them.
    mutating func applyRankOrder(_ assignments: [RankAssignment]) {
        var rank = 0
        for assignment in assignments {
            for playerID in assignment.playerIDs {
                guard let index = players.firstIndex(where: { $0.id == playerID }) else { continue }
                rank += 1
                players[index].overallRank = rank
                if players[index].venueID != assignment.venueID {
                    players[index].venueID = assignment.venueID
                    players[index].groupID = smallestGroupID(in: assignment.venueID)
                    players[index].courtRank = Int.max / 2
                }
            }
        }
        reindex()
    }

    mutating func movePlayer(_ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].venueID = venueID
        if let groupID {
            players[index].groupID = groupID
        } else if players[index].groupID.flatMap({ group($0)?.venueID }) != venueID {
            players[index].groupID = smallestGroupID(in: venueID)
        }
        players[index].courtRank = Int.max / 2  // sinks to the bottom of the court
        reindex()
    }

    /// "Partition the camp" — fills each venue by rank, inside its player limits, then
    /// deals each venue's block evenly across its courts.
    mutating func partition() {
        reindex()
        let ladder = orderedPlayers
        let venuesInOrder = orderedVenues
        guard !venuesInOrder.isEmpty else { return }

        var cursor = 0
        for (offset, venue) in venuesInOrder.enumerated() {
            let rest = venuesInOrder.dropFirst(offset + 1)
            let remaining = ladder.count - cursor
            let floorForRest = rest.reduce(0) { $0 + $1.playerMin }
            let ceilingForRest = rest.reduce(0) { $0 + $1.playerMax }

            // Take an even share, but never so many that the venues below cannot reach
            // their floor, nor so few that they would blow past their ceiling.
            var take = rest.isEmpty
                ? remaining
                : Int((Double(remaining) / Double(rest.count + 1)).rounded())
            let low = max(0, max(venue.playerMin, remaining - ceilingForRest))
            let high = min(remaining, min(venue.playerMax, remaining - floorForRest))
            take = high >= low ? min(max(take, low), high) : min(max(take, 0), remaining)

            for player in ladder[cursor..<(cursor + take)] {
                guard let index = players.firstIndex(where: { $0.id == player.id }) else { continue }
                players[index].venueID = venue.id
            }
            cursor += take
        }

        for venue in venuesInOrder { redistribute(in: venue.id) }
        reindex()
    }

    /// "Even out" — same venues, but every court inside a venue ends within one kid of
    /// every other, filled top-down by rank.
    mutating func evenOut() {
        reindex()
        for venue in orderedVenues { redistribute(in: venue.id) }
        reindex()
    }

    /// Deals a venue's players across its courts in rank order.
    mutating func redistribute(in venueID: Venue.ID) {
        let courts = groups(in: venueID)
        guard !courts.isEmpty else { return }
        let ladder = players(in: venueID)
        let base = ladder.count / courts.count
        let remainder = ladder.count % courts.count

        var cursor = 0
        for (offset, court) in courts.enumerated() {
            let size = base + (offset < remainder ? 1 : 0)
            for seat in 0..<size {
                let player = ladder[cursor + seat]
                guard let index = players.firstIndex(where: { $0.id == player.id }) else { continue }
                players[index].groupID = court.id
                players[index].courtRank = seat + 1
            }
            cursor += size
        }
    }

    mutating func upsert(_ venue: Venue) {
        if let index = venues.firstIndex(where: { $0.id == venue.id }) {
            venues[index] = venue
        } else {
            venues.append(venue)
        }
        syncGroups(for: venue.id)
        reindex()
    }

    /// Adds or trims courts so the venue has exactly `groupCount` of them. Kids on a
    /// removed court fall back to the venue's remaining courts.
    mutating func syncGroups(for venueID: Venue.ID) {
        guard let venue = venue(venueID) else { return }
        var courts = groups(in: venueID)

        while courts.count > venue.groupCount, let last = courts.last {
            groups.removeAll { $0.id == last.id }
            for index in players.indices where players[index].groupID == last.id {
                players[index].groupID = nil
            }
            for index in staff.indices where staff[index].assignment?.groupID == last.id {
                staff[index].assignment = nil
            }
            courts.removeLast()
        }

        while courts.count < venue.groupCount {
            let number = courts.count + 1
            let court = Group(
                venueID: venueID,
                number: number,
                label: "\(sport.groupNoun) \(number)",
                rankOrder: number,
                coachID: nil,
                capacity: max(1, venue.playerMax / max(1, venue.groupCount))
            )
            groups.append(court)
            courts.append(court)
        }

        // Anyone left without a court after a trim lands on the smallest one.
        for index in players.indices where players[index].venueID == venueID && players[index].groupID == nil {
            players[index].groupID = smallestGroupID(in: venueID)
            players[index].courtRank = Int.max / 2
        }
    }

    mutating func setRole(_ role: Role, forStaff staffID: StaffMember.ID) {
        guard let index = staff.firstIndex(where: { $0.id == staffID }) else { return }
        staff[index].role = role
        if role.roamsByDefault, staff[index].assignment == nil { staff[index].isRoaming = true }
    }

    mutating func assignStaff(_ staffID: StaffMember.ID, toGroup groupID: Group.ID?) {
        guard let index = staff.firstIndex(where: { $0.id == staffID }) else { return }
        guard let groupID, let court = group(groupID), let venue = venue(court.venueID) else {
            staff[index].assignment = nil
            staff[index].isRoaming = staff[index].role.roamsByDefault
            reindex()
            return
        }
        // One coach per court: whoever was there is bumped to no court.
        for other in staff.indices where other != index && staff[other].assignment?.groupID == groupID {
            staff[other].assignment = nil
        }
        staff[index].assignment = CourtAssignment(
            venueID: venue.id,
            venueName: venue.name,
            venueIcon: venue.icon,
            groupID: court.id,
            groupNumber: court.number,
            groupLabel: court.label
        )
        staff[index].isRoaming = false
        reindex()
    }

    mutating func removeStaff(_ staffID: StaffMember.ID) {
        staff.removeAll { $0.id == staffID }
        reindex()
    }

    /// The smallest court in a venue — where a kid with no better claim goes.
    func smallestGroupID(in venueID: Venue.ID) -> Group.ID? {
        groups(in: venueID)
            .min { lhs, rhs in
                lhs.playerCount == rhs.playerCount ? lhs.rankOrder < rhs.rankOrder : lhs.playerCount < rhs.playerCount
            }?
            .id
    }
}

// MARK: - Building a camp from scratch

extension Camp {
    /// Screen 4's output: N venues, M courts each, no kids and no staff yet.
    static func make(from draft: CampDraft, inviteCode: String) -> Camp {
        var camp = Camp(
            name: draft.name.trimmingCharacters(in: .whitespaces),
            sport: draft.sport,
            inviteCode: inviteCode,
            icon: Venue.iconOptions[0],
            tint: .moss
        )
        for index in 0..<max(1, draft.venueCount) {
            let icon = Venue.iconOptions[index % Venue.iconOptions.count]
            let venue = Venue(
                name: "Venue \(index + 1)",
                subtitle: nil,
                icon: icon,
                tint: .suggested(for: icon),
                groupCount: max(1, draft.groupsPerVenue),
                coachMin: max(1, draft.groupsPerVenue - 2),
                coachMax: draft.groupsPerVenue + 1,
                playerMin: 0,
                playerMax: draft.groupsPerVenue * 10,
                sortIndex: index
            )
            camp.venues.append(venue)
            camp.syncGroups(for: venue.id)
        }
        camp.reindex()
        return camp
    }

    /// `SYC-4821` — three letters off the name, four digits. The digits come from an
    /// FNV-1a fold rather than `hashValue`, which is seeded per process and would hand
    /// the same camp a different code on every launch.
    static func inviteCode(for name: String) -> String {
        let letters = name.uppercased().filter { $0.isLetter }
        let prefix = letters.isEmpty ? "CMP" : String(letters.prefix(3))
        var digest: UInt32 = 2_166_136_261
        for byte in name.utf8 {
            digest = (digest ^ UInt32(byte)) &* 16_777_619
        }
        let digits = String(format: "%04d", Int(digest % 10_000))
        return "\(prefix.padding(toLength: 3, withPad: "X", startingAt: 0))-\(digits)"
    }
}
