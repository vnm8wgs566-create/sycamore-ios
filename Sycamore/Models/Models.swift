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

extension UUID {

    /// The arbitrary-but-fixed order this app breaks ties with, without spelling either id out.
    ///
    /// Three sorts in the app tie on a real key and then need *some* deciding vote that does not
    /// change between two reads of the same list: `ScheduleBlock.running(in:at:)`
    /// (`SectionEight.swift:459`), `ScheduleTimeline`'s lane assignment
    /// (`ScheduleTimeline.swift:245`) and `OverviewNow.resolve`'s `min`
    /// (`OverviewNow.swift:288`). All three wrote it as `id.uuidString < id.uuidString`, and that
    /// is not free: `uuidString` renders a fresh 36-character `String` on **each side of every
    /// comparison**, so an n·log n sort over a day's blocks allocates a few hundred short-lived
    /// strings to answer a question about sixteen bytes. `CoachAvailability.map` runs the first of
    /// those sorts once per keystroke in the block editor's title field, which is what made it
    /// worth writing down.
    ///
    /// **The same total order, not merely a stable one**, so adopting it moves nothing that was
    /// already sorted. `uuidString` is the sixteen bytes rendered as fixed-width upper-case hex
    /// with dashes at fixed positions; hex digits order `0`…`9` then `A`…`F`, which is ASCII's own
    /// order and also the numeric order of the nibbles they stand for. Both strings are the same
    /// length, so there is no prefix case, and the dashes fall in the same places, so they never
    /// decide anything. Byte order and string order are therefore the same comparison, and
    /// `uuidStringOrderMatchesBytes` in `SectionEightScheduleTests` pins that rather than leaving
    /// it as an argument.
    ///
    /// `withUnsafeBytes` over the two 16-byte tuples rather than a loop over tuple members: a
    /// homogeneous tuple has no subscript, and the alternative — `Array(…)` or `Mirror` — is the
    /// allocation this exists to remove, one heap buffer instead of two strings.
    func precedes(_ other: UUID) -> Bool {
        withUnsafeBytes(of: uuid) { mine in
            withUnsafeBytes(of: other.uuid) { theirs in
                for index in 0..<mine.count where mine[index] != theirs[index] {
                    return mine[index] < theirs[index]
                }
                return false
            }
        }
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

/// A day of the week, Monday first.
///
/// This ran Monday to Friday until camps that run at a weekend needed saying. The raw values are
/// the ISO numbering — Monday 1 … Sunday 7 — which is what `CampWeek` was already converting to
/// and from (`CampWeek.swift:63-65`), so the two new cases cost that file nothing but a comment
/// that had been describing the old limit.
///
/// Which of the seven a *particular* camp runs is `Camp.days`, not a property of the calendar.
enum Weekday: Int, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case mon = 1, tue, wed, thu, fri, sat, sun

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .mon: "Mon"
        case .tue: "Tue"
        case .wed: "Wed"
        case .thu: "Thu"
        case .fri: "Fri"
        case .sat: "Sat"
        case .sun: "Sun"
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
        case .sat: "Saturday"
        case .sun: "Sunday"
        }
    }

    /// The day it actually is.
    ///
    /// This returned `.wed` unconditionally — "the day the design's screens depict" — and every
    /// screen that asked what day it was got Wednesday, on a Tuesday, forever. Twenty call sites
    /// read it, including the Postgres query that fetches a day's schedule and the whole of
    /// attendance, so the stub was not cosmetic: a coach taking Thursday's register was writing
    /// it against Wednesday's date.
    ///
    /// Injectable rather than reading the clock inside itself, so a test can ask what happens on
    /// a Sunday without waiting for one.
    static func today(_ date: Date = .now, calendar: Calendar = .current) -> Weekday {
        // Back to ISO — Monday 1 … Sunday 7 — which is exactly this enum's raw value.
        // `Calendar.component(.weekday:)` is Sunday 1 … Saturday 7 whatever the locale's
        // `firstWeekday` is set to, so the arithmetic does not move with the reader's region.
        let iso = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        return Weekday(rawValue: iso) ?? .mon
    }

    /// `today()`, for the call sites that have no date to hand. Kept as a property because
    /// twenty of them read it that way.
    static var today: Weekday { today() }
}

// MARK: - Which days a camp runs

/// The days of the week a camp actually opens.
///
/// A camp is not the calendar: a tennis week runs Monday to Friday, a swim club runs Saturday
/// mornings, and both are ordinary. So the days are the camp's own answer, chosen when the camp
/// is shaped, and the Schedule screen draws chips for these rather than for all seven.
///
/// An `OptionSet` over one `smallint` rather than a join table or seven columns: the answer is
/// seven bits, it is read on every schedule load, and a table would be seven rows to say what a
/// number says. `rawValue` is the wire format — bit 0 is Monday, matching `Weekday`'s raw value
/// less one.
struct CampDays: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) { self.rawValue = rawValue }

    static let mon = CampDays(rawValue: 1 << 0)
    static let tue = CampDays(rawValue: 1 << 1)
    static let wed = CampDays(rawValue: 1 << 2)
    static let thu = CampDays(rawValue: 1 << 3)
    static let fri = CampDays(rawValue: 1 << 4)
    static let sat = CampDays(rawValue: 1 << 5)
    static let sun = CampDays(rawValue: 1 << 6)

    /// What a camp runs unless somebody says otherwise, and what every camp created before this
    /// column existed is taken to have meant.
    static let weekdays: CampDays = [.mon, .tue, .wed, .thu, .fri]
    static let everyDay: CampDays = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]

    init(_ days: [Weekday]) {
        self.init(rawValue: days.reduce(0) { $0 | (1 << ($1.rawValue - 1)) })
    }

    func contains(_ day: Weekday) -> Bool {
        rawValue & (1 << (day.rawValue - 1)) != 0
    }

    mutating func toggle(_ day: Weekday) {
        if contains(day) {
            self = CampDays(rawValue: rawValue & ~(1 << (day.rawValue - 1)))
        } else {
            self = CampDays(rawValue: rawValue | (1 << (day.rawValue - 1)))
        }
    }

    /// Monday first, which is the order the chips are drawn in.
    var ordered: [Weekday] { Weekday.allCases.filter(contains) }

    /// Where `day` falls in the camp's own run — 1-based — or nil when the camp does not open
    /// that day.
    ///
    /// The half of "Wednesday · day 2 of 5" that could not be counted. `ordered` gives the run
    /// and `CampDays+Rules.swift:71-73` gives its length; nothing said which of them today is.
    ///
    /// **Counted through `ordered`, not off the bit position.** A camp running Tuesday and
    /// Thursday makes Thursday its second day, and `Weekday.thu.rawValue` is 4 — the calendar's
    /// answer to a question about the camp. The whole point of `CampDays` is that a camp is not
    /// the calendar, and a header reading "day 4 of 2" would be that confusion drawn on screen.
    ///
    /// Nil rather than 0 for a day the camp does not run, because 0 is a position and this has
    /// none. `4a`'s header is drawn on a day the camp is open by construction, so the nil arm is
    /// for the caller that got there another way — a stale deep link, or a camp whose days were
    /// edited while somebody stood on Thursday — and those want to draw nothing rather than
    /// "day 0 of 5".
    func dayIndex(of day: Weekday) -> Int? {
        ordered.firstIndex(of: day).map { $0 + 1 }
    }

    /// A camp with no days is a camp nobody can schedule anything on, so the editor refuses the
    /// empty set rather than letting it reach the database. This is what it checks.
    var isValid: Bool { !ordered.isEmpty }

    /// The day to open the Schedule on: today when the camp runs today, otherwise the next day
    /// it does — wrapping into next week, so a Sunday at a Monday-to-Friday camp opens Monday
    /// rather than falling backwards into a Friday that has already happened.
    func openingDay(from today: Weekday = .today) -> Weekday? {
        guard isValid else { return nil }
        for step in 0..<7 {
            let raw = (today.rawValue - 1 + step) % 7 + 1
            if let day = Weekday(rawValue: raw), contains(day) { return day }
        }
        return nil
    }
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

    /// The same clock with the meridiem left off: `9:12`, `2:30`.
    ///
    /// Beside `clockLabel` rather than instead of it, and both are wanted. `am`/`pm` earns its
    /// two characters wherever a time stands alone in prose — "leaves at 2:30pm" — and cannot
    /// pay for them in a column of times in order, which is where this one is read.
    /// `ScheduleBlock.gutterLabel` (`ScheduleBlockPresentation.swift:30`) had already worked
    /// that out for `8k`'s 52pt gutter and spelled it by hand — it calls this now, which is the
    /// point; `4d` writes "Free at 10:30" and
    /// `4d`'s eyebrow writes "10:45–12:00", which is the same sentence in a third place. Three
    /// hand-spellings of one format is how two of them come to disagree, so the format is here.
    ///
    /// Locale-independent for the reason `clockLabel` states: this is the camp's own clock, and
    /// the design writes it exactly this way. It is a 12-hour reading with no meridiem, which is
    /// unambiguous only because a camp day does not wrap round midnight — the same assumption the
    /// gutter has been resting on since it was written.
    var shortLabel: String {
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", hour12, minute)
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

/// Which ages a venue takes: an inclusive pair of bounds, either of which may be absent.
///
/// ── Why this is not three cases any more ─────────────────────────────────────────────────────
///
/// It used to be `all / under_twelve / twelve_up`, with the pivot **welded to twelve inside the
/// type**. Three answers is not a setting, it is a guess about which camp is asking: a camp that
/// splits at ten, or at thirteen, or that runs a nine-to-twelve venue beside an open one, had no
/// way to say so and no way to ask for one. Two nullable bounds subsume all three of the old
/// values *and* every pivot a camp might actually pick, at the cost of one comparison:
///
///     minAge   maxAge    label            was
///     ---------------------------------------------------
///     nil      nil       "All ages"       .all
///     nil      11        "11 & under"     .underTwelve
///     12       nil       "12 & up"        .twelveUp
///     9        12        "9–12"           — unsayable before
///
/// A pair rather than a pivot-plus-direction, which is the shape the request literally described
/// ("over and under at a chosen age"): a pivot cannot express a band closed at both ends, and the
/// camp that has once been able to say "12 & up" asks for "9–12" the same afternoon. It is also
/// the shape `sites`' own CHECK wants — one comparison between two columns, rather than a
/// direction column that has to be read before either bound means anything. The columns are
/// `sites.age_min` and `sites.age_max`, added by
/// `20260810050000_a_venue_picks_its_own_age`, which dropped `age_band` in the same transaction.
///
/// **What this does not do is filter a list.** It decides where an *imported* kid lands. A roster
/// arriving at a venue is dealt onto its courts, and a kid outside the band is left unassigned
/// and counted rather than dealt somewhere they do not belong — see `admits(_:)`.
///
/// Two places enforce that, and between them they cover every way a kid reaches a court:
/// `RosterAgeFit` decides which venue an arrival is offered to, and `Camp.admit(_:at:)` decides
/// who the venue's own deal will seat once they are there. Both ask `admits(_:)` and nothing else,
/// which is why widening the representation cost neither of them a line.
struct AgeBand: Hashable, Codable, Sendable {

    /// The youngest age admitted, or nil for "not asking on that side". Inclusive.
    private(set) var minAge: Int?
    /// The oldest age admitted, or nil for "not asking on that side". Inclusive.
    private(set) var maxAge: Int?

    /// Three to twenty-one — `sites_age_min_sane` and `sites_age_max_sane`, mirrored.
    ///
    /// Not arbitrary and not this file's invention: below three there is no camp, and twenty-one
    /// is where a junior programme stops being one. Wide enough that no real camp meets it, narrow
    /// enough that a fat-fingered 120 is refused before it is drawn on a chip as "120 & up".
    static let range = 3...21

    /// A venue that is not asking. The default every venue is created with, and the one most of
    /// them keep.
    static let all = AgeBand()

    /// The two bounds a reader is offered first when they narrow a venue for the first time —
    /// which are, deliberately, exactly the two bands this type used to be able to express. A camp
    /// that wanted "11 & under" or "12 & up" before still reaches it in one tap and no steps.
    static let defaultCeiling = 11
    static let defaultFloor = 12

    /// **Both bounds are normalised here, and that is why they are `private(set)`.**
    ///
    /// Two invariants, and each of them is a constraint on `sites` rather than a preference. Each
    /// bound is clamped into `range`, because `sites_age_min_sane` refuses anything outside it —
    /// and a row Postgres refuses surfaces as an opaque 400 on a save button two screens from the
    /// stepper that caused it. And a pair given out of order is put back in order, because
    /// `sites_age_bounds_ordered` refuses that too; an inverted band also admits nobody, which is
    /// a venue that can never be filled and is far likelier to be a slip than an intention.
    ///
    /// The upper bound is the one that moves when they cross, not the lower: the caller who passes
    /// both is the "between" control, whose lower stepper is the one under the finger.
    init(minAge: Int? = nil, maxAge: Int? = nil) {
        let lower = minAge.map { $0.clamped(to: Self.range) }
        let upper = maxAge.map { $0.clamped(to: Self.range) }
        self.minAge = lower
        if let lower, let upper {
            self.maxAge = Swift.max(lower, upper)
        } else {
            self.maxAge = upper
        }
    }

    /// `11 & under` — a ceiling and no floor.
    static func upTo(_ age: Int) -> AgeBand { AgeBand(maxAge: age) }

    /// `12 & up` — a floor and no ceiling.
    static func from(_ age: Int) -> AgeBand { AgeBand(minAge: age) }

    /// `9–12` — the shape the three-case enum could not say at all.
    static func between(_ lower: Int, _ upper: Int) -> AgeBand {
        AgeBand(minAge: lower, maxAge: upper)
    }

    /// Whether this venue is asking about age at all. What `band != .all` used to mean, said as a
    /// question rather than as a comparison against one particular value — there are now many
    /// bands and exactly one of them is not asking.
    var isUnrestricted: Bool { minAge == nil && maxAge == nil }

    /// The chip in the venue sheet, and the chip on the venue's card.
    ///
    /// Derived from the bounds rather than stored beside them, so there is no second field that
    /// can come to disagree with the numbers it describes — which is the whole reason the enum
    /// went. The four shapes are the four combinations of "asking on that side" and nothing else;
    /// an en dash between two numbers because that is what a range is set with, and "10 only" for
    /// the degenerate closed band, because "10–10" is a puzzle where "10 only" is an answer.
    var label: String {
        switch (minAge, maxAge) {
        case (nil, nil): "All ages"
        case (nil, let ceiling?): "\(ceiling) & under"
        case (let floor?, nil): "\(floor) & up"
        case (let floor?, let ceiling?): floor == ceiling ? "\(floor) only" : "\(floor)–\(ceiling)"
        }
    }

    /// Whether a kid of this age belongs at a venue with this band.
    ///
    /// **An unknown age does not satisfy a restricted band, and that is the whole point of the
    /// method.** `Player.age` is optional — the roster importer accepts a file with no age column
    /// and hand-added kids can be saved without one — so every caller has to decide what an
    /// absent age means, and there are only two honest answers. Admitting them puts an eight
    /// year old on a 12-and-up court because a spreadsheet had a blank cell. Refusing them leaves
    /// a kid unassigned, where the screen says so out loud and somebody can place them by hand.
    ///
    /// The second is the one that fails where a person can see it, so it is the one taken. An
    /// unrestricted band admits everybody including the unknowns, because it is not asking.
    ///
    /// **The meaning is unchanged from the three-case version, deliberately.** Every caller in the
    /// app asks this and only this — the deal-gating in `Camp.admit(_:at:)`, `RosterAgeFit`, the
    /// enrolment chips — so widening the representation was allowed to add shapes and was not
    /// allowed to move the line. `nil` at a restricted band was false before and is false now.
    func admits(_ age: Int?) -> Bool {
        guard !isUnrestricted else { return true }
        guard let age else { return false }
        if let minAge, age < minAge { return false }
        if let maxAge, age > maxAge { return false }
        return true
    }
}

extension AgeBand {
    /// Decoded through the memberwise init rather than by the synthesised member-by-member
    /// assignment, which would walk straight past the clamping above — and the one place a band
    /// arrives from outside this process is exactly where an out-of-range pair is most likely.
    /// `encode(to:)` stays synthesised; there is nothing to defend on the way out.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            minAge: try container.decodeIfPresent(Int.self, forKey: .minAge),
            maxAge: try container.decodeIfPresent(Int.self, forKey: .maxAge)
        )
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}

struct Venue: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    /// "Higher level" — optional, shown uppercased next to the venue heading.
    var subtitle: String?
    var icon: String
    var tint: VenueTint
    /// How many courts the venue has on the ground.
    ///
    /// **Not the same number as `groupCount`, and the difference is the point.** This is a fact
    /// about the site: six courts exist, two are being resurfaced. `groupCount` is a decision:
    /// split the kids four ways. They agree at almost every venue and are still different
    /// questions, and until the venue sheet could ask both, asking for one more group silently
    /// claimed a court that might not be there.
    ///
    /// Nothing is created from this. Courts as *records* are `Group`s, and `Camp.syncGroups(for:)`
    /// makes exactly `groupCount` of them. This number is what the venue tells you about itself.
    var courtCount: Int
    /// How many groups the venue's kids are split into. One `Group` record each.
    var groupCount: Int
    /// Roughly how many kids a group should hold, or nil if nobody said.
    ///
    /// **Never enforced.** The design is explicit: "Optional target — over flags amber, never
    /// blocks." A group over its target draws a warning and saves anyway, because the person
    /// holding the phone can see the court and this number cannot. Nil is "not decided", which is
    /// a different claim from a target of zero — hence the optional rather than a sentinel.
    var targetPerGroup: Int?
    /// Which ages this venue takes. `.all` unless somebody narrowed it.
    var ageBand: AgeBand = .all
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

    /// `6 courts` — the venue card's first chip. Singular at one, because "1 courts" is the kind
    /// of thing that makes a person distrust the rest of the screen.
    ///
    /// The noun is the venue's own only in the sense that a camp picks one: a swim camp says
    /// "lanes". That word lives on `Sport.groupNoun` and a `Venue` does not know its camp, so the
    /// caller passes it. The default keeps the common case short at the call site.
    func courtCountLabel(noun: String = "court") -> String {
        "\(courtCount) \(noun)\(courtCount == 1 ? "" : "s")"
    }

    /// `4 groups`. Always "group" — a group is a group whatever the sport calls the ground it
    /// stands on.
    var groupCountLabel: String { "\(groupCount) group\(groupCount == 1 ? "" : "s")" }

    /// `~12/group`, or nil when no target was set.
    ///
    /// The tilde is doing real work: this is a target and not a capacity, and the screen has to
    /// stop somebody reading it as a rule they have broken.
    var targetLabel: String? { targetPerGroup.map { "~\($0)/group" } }

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

    /// Why this court is out of play, or nil while it is in play — the reason half of
    /// `CourtStatus` (`SectionEight.swift:88-110`), carried on the court itself.
    ///
    /// **It is here because the column is on `groups`.** `20260810030000_a_closed_court_stays_closed`
    /// added `groups.closed_reason`, so a closed court survives a relaunch, and the camp graph
    /// already selects every venue's `groups` rows in one request
    /// (`SupabaseRepository+Graph.swift:33`) — the reason therefore arrives with the court and
    /// costs no round trip of its own. Until it did, closure was only readable through `CourtCard`,
    /// which is a per-venue read, and `AppStore.closedCourts` (`AppStore+SectionEight.swift:175`)
    /// could answer for one venue and could not say why.
    ///
    /// **The empty string is a value, not a synonym for nil.** `""` is a court somebody shut
    /// without typing a reason, which draws as a bare "Closed"; `GroupRecord.closedReason`
    /// (`SupabaseDTOs.swift:101-111`) argues that at the column and the CHECK admits it. Nothing on
    /// this side coerces one into the other.
    ///
    /// Nil-or-not is the same test `CourtStatus.isClosed` makes one layer up — `closureReason
    /// != nil` — rather than a second boolean beside it, so the two cannot come to disagree about a
    /// court that is shut for no stated reason.
    var closedReason: String?

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

    /// This kid as a roster file would leave them: everything the file can speak to taken from
    /// `self`, and where they stand in the camp taken from `other`.
    ///
    /// The four restored fields are the whole idea, and they are named as an **exclusion** rather
    /// than the six inclusions being the short list. Venue, court and the two ranks are camp
    /// state; a file has no opinion about them, and `movePlayer` is where a change of mind about
    /// them goes. Stating it this way also fails safe: a field added to `Player` later counts as
    /// file-owned by default, and the worst that does is write a value that was already there.
    /// Naming the six instead would make a new field silently invisible — the kid would keep the
    /// old value with no sign of it.
    ///
    /// One list, two jobs, which is why it lives here rather than in either repository. Both
    /// `updatePlayers` implementations use it: offline it *is* the write, and against Postgres
    /// `patch.keepingPlacement(of: existing) != existing` is exactly "this line changes
    /// something", which is what lets a re-import skip the rows it would only rewrite with the
    /// values already in them. The two had this rule spelled out separately and in opposite
    /// polarities — six assignments offline, four exclusions online — so the one that failed
    /// unsafe was the one no test could see.
    func keepingPlacement(of other: Player) -> Player {
        var kept = self
        kept.venueID = other.venueID
        kept.groupID = other.groupID
        kept.overallRank = other.overallRank
        kept.courtRank = other.courtRank
        return kept
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
    /// Whether this kid answers to what somebody typed into the Find a player field.
    ///
    /// Deliberately **not** `displayName`, which is what this used to search. That is a
    /// *display* concern and it is expensive: it builds `PersonNameComponents` and runs a
    /// locale-aware `FormatStyle` (`:455`), so searching by it cost one formatter construction
    /// and one ICU formatting pass **per kid per keystroke** — a hundred of each, on the main
    /// actor, between the character landing and the list redrawing. The parts it formats are
    /// the three stored strings below, so searching them directly answers the same question
    /// without assembling the sentence first.
    ///
    /// The surname is searched in both spellings a camp may hold it in: `lastName` once it has
    /// been collected, and `lastInitial` for the rows that only ever had one. "Chu" therefore
    /// finds Serene whether or not anybody has typed her surname in yet, which the old
    /// `displayName` search did only by accident of what it had glued together.
    ///
    /// `localizedStandardContains` stays — it is the one that folds case and diacritics the way
    /// a reader expects, and search *is* the place a locale belongs, unlike a matching key
    /// (see `RosterReconciliation.fold`). The caller trims: `term` arrives already trimmed from
    /// `computeGroupsSections`, so this does not allocate a fresh `String` per kid.
    func matches(search term: String) -> Bool {
        guard !term.isEmpty else { return true }
        return firstName.localizedStandardContains(term)
            || (lastName?.localizedStandardContains(term) ?? false)
            || lastInitial.localizedStandardContains(term)
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

    /// See `Player.matches(search:)` for why this folds through `localizedStandardContains`,
    /// and why the caller trims rather than this doing it per candidate.
    func matches(search term: String) -> Bool {
        guard !term.isEmpty else { return true }
        return name.localizedStandardContains(term)
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
    /// Which days the camp runs. Carried on the draft because it is asked on `8b`, beside the
    /// venues and the courts, rather than discovered later in Camp settings.
    var days: CampDays = .weekdays

    /// What `camps.name` should actually hold. A name is not its surrounding whitespace, and the
    /// column's CHECK counts every character it is given — so `"  UCLA  "` spends four of its
    /// eighty on nothing.
    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var isValid: Bool { CampName.isValid(trimmedName) }

    static let venueRange = 1...8
    static let groupRange = 1...16
}

/// The one rule about what a camp may be called.
///
/// `camps.name text not null check (char_length(name) between 1 and 80)`. Both ends were being
/// checked in two places and only the near one was checked at all: "Shape the camp" and Setup's
/// rename each tested for empty and neither for long, so an eighty-one character name passed
/// every gate on the device and failed at `insert` — after the whole onboarding flow, since the
/// camp is not written until the end of it. One rule, stated once, next to the SQL it mirrors.
enum CampName {

    /// The CHECK, in Swift.
    static let lengthLimits = 1...80

    static func isValid(_ trimmed: String) -> Bool {
        CharLength.of(trimmed, fits: lengthLimits)
    }
}

/// The two rules about what a kid's row may hold, wherever that row came from.
///
/// Hoisted here for the reason `CampName` was: a second feature needed them. They were statics on
/// `IntakePlayer`, which is the shape of a line in a spreadsheet — so the file path checked them
/// and the two paths that do not go through a file did not. `AddPlayerView` took an age off a
/// free-text numpad and wrote it straight through, and `RosterReconciliation.applying` proposed
/// whatever the file said; both then failed at the insert, and `importPlayers` sends a roster as
/// **one** insert, so a single 25 rejects everybody else in the batch. That is exactly the failure
/// wave 1 closed on the file path and left open beside it.
///
/// The bounds are the columns', not this app's opinion, and they are cited beside each one.
///
/// Two shapes, because the callers ask two different questions. The constants answer "is this
/// legal", which is what a screen showing an issue needs — `IntakeIssue.impossibleAge` has to tell
/// `25` apart from *no age at all*. The filters answer "what may I write", which is what a
/// **proposal** needs: a value the column will refuse is the file saying nothing, not an
/// instruction to change something into a row Postgres will bounce.
enum PlayerRules {

    /// `players_age_check`: `check (age between 4 and 19)`,
    /// `supabase/migrations/20260805141707_camps_memberships_profiles.sql`.
    static let ageLimits = 4...19

    /// `players_last_name_len`: `check (last_name is null or char_length(last_name) between 1 and
    /// 60)`, added by `20260806031106_section8_model_gaps.sql`.
    ///
    /// A ceiling rather than a range, because the floor is kept by writing an empty cell as null —
    /// which is the branch of the CHECK that admits it.
    static let surnameLimit = 60

    /// An age the column will take, or nil for one it will not — including a nil going in.
    static func age(_ value: Int?) -> Int? {
        guard let value, ageLimits.contains(value) else { return nil }
        return value
    }

    /// A surname the column will take, or nil for one it will not — including an empty cell.
    ///
    /// Counted through `CharLength` rather than `.count`, for the reason that type exists: Postgres
    /// counts UTF-8 characters and Swift counts grapheme clusters, so a surname of emoji passes a
    /// `.count` gate and then fails the very insert the gate exists to prevent.
    static func surname(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, CharLength.of(trimmed, atMost: surnameLimit) else { return nil }
        return trimmed
    }
}

/// `char_length(x)`, counted the way Postgres counts it.
///
/// Postgres counts characters of the UTF-8 string; Swift's `String.count` counts grapheme
/// clusters, and one cluster can be many scalars — "👩‍👩‍👧" is one `Character` and seven. A rule
/// written with `.count` therefore lets a field of emoji through the client and straight into the
/// failed insert the rule exists to prevent.
///
/// Here rather than restated at each mirror, and that is the whole point: four columns are now
/// mirrored in Swift — `camps.name`, `inbox_items.title`, `schedule_blocks.title` and
/// `.detail` — and this is the part of the mirroring that fails *silently*. A fifth written with
/// `.count` compiles, passes any test built the obvious way, and diverges from the column only on
/// input nobody types during review. The bounds stay beside the features that read them, next to
/// the SQL they cite; only the counting comes here.
enum CharLength {

    static func of(_ trimmed: String, fits limits: ClosedRange<Int>) -> Bool {
        limits.contains(trimmed.unicodeScalars.count)
    }

    static func of(_ trimmed: String, atMost limit: Int) -> Bool {
        trimmed.unicodeScalars.count <= limit
    }

    /// How far past a ceiling a draft is, or zero — the number a composer asks its reader to cut.
    static func overrun(_ trimmed: String, over limit: Int) -> Int {
        max(0, trimmed.unicodeScalars.count - limit)
    }
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
    /// The days this camp opens. Chosen when the camp is shaped and editable afterwards; the
    /// Schedule screen draws a chip per day in here rather than one per day of the week.
    ///
    /// Defaulted rather than required, so every camp written before the column existed reads as
    /// Monday-to-Friday — which is what they all were.
    var days: CampDays = .weekdays
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

    /// Why one court is out of play, asked with an id rather than with the court.
    ///
    /// `group(_:)` and then the property, which is what every caller would otherwise write out —
    /// and writing it once is the point, because the callers are the ones that cannot see a
    /// `CourtCard`. `AppStore.courts` is loaded for `readVenueID`
    /// (`AppStore+SectionEight.swift:149-160`) and the block editor is scoped to `draft.venueID`,
    /// which differs whenever the editor is reached from Overview on a two-venue camp; the graph
    /// holds every venue's courts, so this answers for **any** of them.
    ///
    /// A caller already holding the `Group` reads `closedReason` off it and should. This is the
    /// id-keyed spelling of one fact, not a second source for it.
    func closedReason(for id: Group.ID) -> String? { group(id)?.closedReason }
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

    /// `4b`'s venue row: `6 courts · 50 kids`.
    ///
    /// The third speller of one venue's shape, and deliberately not a fourth reading of either
    /// neighbour. `rowSummary(for:)` writes `6 groups · 50 kids · 6 coaches` and
    /// `sheetSummary(for:)` writes `50 kids · 6 coaches · 6 groups`; both name coaches, both call
    /// a court a group, and neither is in the order `4b` draws. Both also have callers, so
    /// bending one to fit would move a line on a screen this change is not about — the same
    /// reasoning `CourtStatus.closureReason` (`SectionEight.swift:105-107`) uses in the other
    /// direction, where three longhand copies of one question were worth folding into one.
    ///
    /// Two clauses rather than three because `4b` is a picker: the row is answering "which venue",
    /// and how many coaches are on it is a fact for the screen you land on. `venue.groupCount`
    /// rather than `groups(in:).count` so all three spellers count the venue's *shape* and cannot
    /// disagree with each other on a camp mid-reindex, where the courts exist before the venue has
    /// been told how many it has.
    ///
    /// The noun follows the sport — a swim club reads `6 lanes · 50 kids` — and is lower-cased
    /// mid-line the way `CreateCampView.courtNoun` (`:144`) already does it.
    func venueSummary(for venueID: Venue.ID) -> String {
        guard let venue = venue(venueID) else { return "" }
        let noun = sport.groupNoun.lowercased()
        let courts = "\(venue.groupCount) \(noun)\(venue.groupCount == 1 ? "" : "s")"
        return "\(courts) · \(players(in: venueID).count) kids"
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

        // A court assignment carries the venue's name and emoji so a chip renders without
        // walking the graph, but it only wrote them the moment the coach was assigned. Left
        // alone, renaming a venue or picking a new emoji would keep every coach already
        // standing there on the old one until they happened to be moved. Re-reading the copies
        // here is what makes `upsert(_ venue:)` change a venue everywhere it shows.
        //
        // A venue that has gone missing leaves the snapshot as it was: a stale name still says
        // where the coach is, and blanking it would not.
        for index in staff.indices {
            guard let venueID = staff[index].assignment?.venueID,
                  let venue = venue(venueID)
            else { continue }
            staff[index].assignment?.venueName = venue.name
            staff[index].assignment?.venueIcon = venue.icon
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
    /// ── The band picks who, the arithmetic picks how many ────────────────────────────────────
    ///
    /// This used to walk one sorted ladder with a cursor and hand each venue a *contiguous* slice
    /// of it, which is correct only if every venue will take anybody. Against bands it was worse
    /// than useless: a camp split 12-&-up / 11-&-under came back with every twelve-year-old at
    /// the junior venue and every nine-year-old at the senior one, and `redistribute` — which
    /// does gate on the band — then refused all of them, leaving *the entire camp* unassigned.
    /// This is the button a coach reaches for when the courts look wrong, so it could take a
    /// merely-untidy camp and empty it.
    ///
    /// The counting is unchanged, deliberately: same even share, same floor and ceiling clamps.
    /// What changed is *which* kids a venue's share is drawn from — the top `take` of the kids
    /// still unplaced **that this venue admits**, rather than the next `take` in the ladder.
    /// Rank still decides the order within that pool, so the senior venue still gets the strongest
    /// seniors first.
    mutating func partition() {
        reindex()
        let venuesInOrder = orderedVenues
        guard !venuesInOrder.isEmpty else { return }

        // Rank order, top of the camp first; kids leave the list as they are claimed. A list
        // rather than the old cursor because a venue no longer takes a contiguous run — it reaches
        // past the kids it cannot admit, and those have to stay available to the venues below.
        var unplaced = orderedPlayers

        for (offset, venue) in venuesInOrder.enumerated() {
            let rest = venuesInOrder.dropFirst(offset + 1)
            let remaining = unplaced.count
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

            let claimed = unplaced.filter { venue.ageBand.admits($0.age) }.prefix(take)
            let claimedIDs = Set(claimed.map(\.id))
            for player in claimed {
                guard let index = players.firstIndex(where: { $0.id == player.id }) else { continue }
                players[index].venueID = venue.id
            }
            unplaced.removeAll { claimedIDs.contains($0.id) }
        }

        // A second offer, for kids the shares could not seat.
        //
        // The old code could not leave anybody behind — the last venue's `take` was all of
        // `remaining` — but a banded last venue can refuse, so the shares above can finish with
        // kids still in hand. Anyone some venue would admit goes to the first that would, past its
        // ceiling if it comes to that, which is exactly the licence the last venue always had.
        // Anyone **no** venue admits keeps the venue they already had: a kid nobody can take is
        // not a kid to be moved somewhere they will only be refused again.
        for player in unplaced {
            guard let venue = venuesInOrder.first(where: { $0.ageBand.admits(player.age) }),
                  let index = players.firstIndex(where: { $0.id == player.id })
            else { continue }
            players[index].venueID = venue.id
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
    ///
    /// Every court the venue has. `partition()` and `evenOut()` both call this and both mean the
    /// whole venue, so the no-argument spelling stays rather than becoming
    /// `across: groups(in: venueID).map(\.id)` at two call sites — and it goes straight to `deal`
    /// rather than through the subset below, which would resolve those ids back into the very list
    /// they were flattened from.
    mutating func redistribute(in venueID: Venue.ID) {
        deal(players(in: venueID), across: groups(in: venueID), at: venueID)
    }

    /// The same deal, over an explicit subset of the venue's courts.
    ///
    /// This is what a schedule block asks for. "Warm-up needs one court and all the kids" is not
    /// something the whole-venue deal can say — it would put an eighth of the camp on each of
    /// eight courts, which is the opposite instruction. Every kid at the venue lands on one of
    /// `courtIDs`, including the ones standing on a court this block does not use.
    ///
    /// The subset does not set the order. The deal follows the venue's own `rankOrder`, so the top
    /// of the ladder goes to the lowest-ranked court named whatever order the caller listed them
    /// in — a set of ids from a picker has no meaningful order, and a court's position in the
    /// venue is a fact about the venue.
    mutating func redistribute(in venueID: Venue.ID, across courtIDs: [Group.ID]) {
        deal(players(in: venueID), across: courts(courtIDs, in: venueID), at: venueID)
    }

    /// "Even out", narrowed to a handful of courts: levels the kids *already standing on*
    /// `courtIDs` across those same courts.
    ///
    /// The other half of the pair above, and the difference between them is who gets moved.
    /// `redistribute(in:across:)` pulls the venue in; this one touches nobody who was not already
    /// there. A block running on courts 1–3 while another owns 4–6 wants this one: levelling three
    /// courts should not empty the other three into them.
    mutating func evenOut(_ courtIDs: [Group.ID], in venueID: Venue.ID) {
        let courts = courts(courtIDs, in: venueID)
        let onThem = Set(courts.map(\.id))
        deal(
            players(in: venueID).filter { $0.groupID.map(onThem.contains) ?? false },
            across: courts,
            at: venueID
        )
    }

    /// The venue's own courts, narrowed to `ids` and left in the venue's rank order.
    ///
    /// Resolved through `groups(in:)` rather than trusted, and that is the whole safety of the two
    /// methods above. A block carries its court ids as data, and data goes stale: a court deleted
    /// by `syncGroups(for:)` leaves its id on every block that named it, and an id from another
    /// venue would otherwise move kids out of the venue the deal is about — which is the one thing
    /// `evenOut()` has always promised it will not do. It deduplicates for free, since a court
    /// named twice matches one row, and it is what makes the *caller's* order irrelevant.
    private func courts(_ ids: [Group.ID], in venueID: Venue.ID) -> [Group] {
        let chosen = Set(ids)
        return groups(in: venueID).filter { chosen.contains($0.id) }
    }

    /// Hands back the part of `ladder` the venue's age band will take, and turns the rest out of
    /// whatever group they were in.
    ///
    /// `AgeBand`'s own header (`:517-519`) has always claimed this behaviour — *"a kid outside the
    /// band is left unassigned and counted rather than dealt somewhere they do not belong"* — and
    /// until this method existed nothing anywhere performed it. A venue set to `12 & up` dealt its
    /// nine-year-olds onto its courts exactly like everybody else, because `deal` was handed the
    /// whole venue and never asked the venue anything.
    ///
    /// **Turned out, not dropped.** `groupID = nil` is the entire consequence: the kid keeps their
    /// venue, their rank and their row, and every count of "kids at this venue" still includes
    /// them. That is the difference between a band and a filter, and it is the difference the
    /// screens depend on — an unassigned kid is visible and complainable-about, whereas a kid
    /// quietly left off the deal would have been a kid nobody could find.
    ///
    /// **Including a kid who was already sitting there.** Narrowing a venue from `All ages` to
    /// `12 & up` does not un-place the nine-year-olds by itself, so this runs over everybody the
    /// deal was given rather than only the currently-unassigned: the band is a statement about who
    /// may stand on these courts, not about who may walk onto them next. The alternative —
    /// grandfathering whoever got there first — means the venue chip reads `12 & up` above a court
    /// with a nine-year-old on it, which is the app lying about its own configuration. Every deal
    /// therefore re-asks the question of every kid it touches, and `syncGroups(for:)` asks it too
    /// so that the upsert which *narrows* the band is itself the moment the turning-out happens.
    ///
    /// **Where the line is drawn: deals and bookkeeping ask, hand placements do not.** A refused
    /// kid has to be placeable — "they simply have no group until somebody places them" is the
    /// whole point of leaving them assigned to the venue — so `movePlayer(_:toVenue:group:)` and
    /// `applyVenueAssignments(_:)` are left alone. Those are a person naming a kid and a court,
    /// and an app that silently undid the instruction it was just given would be worse than one
    /// that lets a coach make an exception. `syncGroups(for:)` is on the other side of that line
    /// because nobody named anybody: it fires as a side effect of editing the *venue*, and its
    /// court-of-last-resort would otherwise hand a refused kid a court in the same breath as the
    /// edit that refused them.
    ///
    /// `courtRank` follows the convention `movePlayer` and `syncGroups` already use for a kid with
    /// nowhere to stand: sink them to the bottom, so that when somebody does place them by hand
    /// they arrive at the foot of that court rather than at a rank they held on a different one.
    ///
    /// A nil age is not decided here. `admits(_:)` refuses it at a restricted band and its comment
    /// carries the whole argument for that (`:534-551`); this method's only job is to make the
    /// refusal land as "unassigned" rather than as a crash or a silent admission. `.all` and a
    /// venue that cannot be found both return the ladder untouched — the second because a lookup
    /// failure is not a reason to empty a camp's courts.
    @discardableResult
    private mutating func admit(_ ladder: [Player], at venueID: Venue.ID) -> [Player] {
        guard let band = venue(venueID)?.ageBand, !band.isUnrestricted else { return ladder }

        var admitted: [Player] = []
        admitted.reserveCapacity(ladder.count)
        for player in ladder {
            guard band.admits(player.age) else {
                guard let index = players.firstIndex(where: { $0.id == player.id }) else { continue }
                players[index].groupID = nil
                players[index].courtRank = Int.max / 2
                continue
            }
            admitted.append(player)
        }
        return admitted
    }

    /// Deals `ladder` across `courts`, top-down, so every court ends within one kid of every other
    /// and the leftovers go to the courts that come first — after the venue's age band has had its
    /// say about who is dealt at all.
    ///
    /// Takes resolved courts rather than ids so the whole-venue path does not go out through
    /// `map(\.id)` and back in through a `Set` to rebuild the list it started with — `partition()`
    /// runs this once per venue.
    ///
    /// Takes `venueID` **as well as** the courts, which look redundant next to each other and are
    /// not: the courts say where the kids may land, the venue says which kids may land at all, and
    /// `evenOut(_:in:)` hands over a strict subset of one venue's courts where neither answers the
    /// other's question. Resolving the band here rather than at each of the three call sites is
    /// what makes the gate impossible to forget on the next deal somebody writes.
    ///
    /// Evenness is measured over the *admitted* kids and nobody else. A venue holding eleven kids
    /// two of whom the band refuses deals nine across its courts and ends 5/4, not 6/5 with two
    /// phantom seats — the refused pair are not on a court to be counted, so counting them would
    /// only make the courts that are real less even.
    ///
    /// Deliberately no `reindex()`, matching the shape this was extracted from: `partition()` and
    /// `evenOut()` both reindex once at the end rather than once per venue. A caller that reads
    /// `players(inGroup:)` straight afterwards needs none — that read filters and sorts the
    /// players themselves, and it is only the denormalised counts on `Group` that go stale.
    private mutating func deal(_ ladder: [Player], across courts: [Group], at venueID: Venue.ID) {
        // No courts, no deal, and no turning-out either. A venue with nowhere to put anybody is
        // mid-edit — `syncGroups(for:)` trimming to zero, a block naming courts that no longer
        // exist — and emptying its kids out of groups on the way past would be a second, silent
        // edit nobody asked for. `redistribute(in:)` has always answered this case by leaving the
        // venue exactly as it found it, and the band does not change what "leave it alone" means.
        guard !courts.isEmpty else { return }

        let ladder = admit(ladder, at: venueID)
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
            // `number` counts positions, so it is dense; `rankOrder` is an *order* and after a
            // `removeGroup` it is sparse — delete Group 1 of three and the survivors keep ranks 2
            // and 3. Minting at `courts.count + 1` would then hand the new court rank 3, tying it
            // with a court already holding that rank, and `groups(in:)` sorts on `rankOrder`: the
            // venue would draw as "Group 3, Group 1, Group 2" offline, and against Postgres the
            // rename upsert would collide on `unique (site_id, name)`.
            //
            // Allocated past the highest rank in use instead, which is the only value that cannot
            // tie whatever the gaps look like.
            let rank = (courts.map(\.rankOrder).max() ?? 0) + 1
            let court = Group(
                venueID: venueID,
                number: number,
                label: "\(sport.groupNoun) \(number)",
                rankOrder: rank,
                coachID: nil,
                capacity: max(1, venue.playerMax / max(1, venue.groupCount))
            )
            groups.append(court)
            courts.append(court)
        }

        // Whoever the band no longer takes comes off their court first.
        //
        // This is the upsert that *narrows* a venue — `VenueSheet` writes `ageBand` onto the draft
        // and saves through `upsert(_ venue:)`, which lands here — so it is the one moment at which
        // "12 & up" stops being a fact about arrivals and becomes a fact about the kids already
        // standing there. Leaving them until the next `evenOut()` would mean the change a coach
        // just made appeared to do nothing, and the courts would read as compliant while holding
        // the very kids the band was set to exclude.
        admit(players(in: venueID), at: venueID)

        // Anyone left without a court after a trim lands on the smallest one — unless the band is
        // the reason they have no court, which is the whole of the previous paragraph undone if
        // this loop is allowed to run over them. `admits(_:)` is asked twice on purpose rather than
        // this loop being narrowed to "kids the trim just displaced": the honest invariant is that
        // nothing in this method ever seats a kid the venue refuses, whatever put them in reach.
        for index in players.indices
        where players[index].venueID == venueID
            && players[index].groupID == nil
            && venue.ageBand.admits(players[index].age) {
            players[index].groupID = smallestGroupID(in: venueID)
            players[index].courtRank = Int.max / 2
        }
    }

    /// Removes one group from a venue. Its kids stay at the venue with `groupID = nil`; the groups
    /// after it renumber so `number` stays 1…n with no gap.
    ///
    /// ── Why the kids are turned out rather than moved ────────────────────────────────────────
    ///
    /// `syncGroups(for:)` trims courts too, and it ends by parking anyone left standing on the
    /// smallest remaining court. That is right for a trim, which is a *count* being lowered and
    /// says nothing about the kids. This is not that: somebody has pointed at one court and said
    /// remove it, and the kids on it are the substance of the decision. Sweeping them onto the
    /// court next door in the same breath would place eight kids nobody named, silently, at ranks
    /// they did not hold — and Groups already draws an unassigned band for exactly this, where
    /// they are visible, countable and one drag from where they belong.
    ///
    /// `courtRank` sinks to `Int.max / 2`, which is the convention `movePlayer(_:toVenue:group:)`
    /// and `admit(_:at:)` already use for a kid with nowhere to stand: when somebody does place
    /// them by hand they arrive at the foot of that court rather than at a rank they held on a
    /// different one.
    ///
    /// ── Why `groupCount` comes down with it ──────────────────────────────────────────────────
    ///
    /// **This is the line that makes the deletion stick.** `groupCount` is what `syncGroups(for:)`
    /// creates courts up to, and it runs on every `upsert(_ venue:)` — so a venue left claiming
    /// four groups while holding three would re-create the removed court on the next venue edit,
    /// and the deletion would appear to undo itself with nobody having asked for it back.
    ///
    /// ── What is renumbered and what is not ───────────────────────────────────────────────────
    ///
    /// `number` and `label` follow the new position, because both are read as "the third court
    /// here" — a venue whose courts read 1, 2, 4 has lost a court in a way the screen cannot
    /// explain. `rankOrder` is left sparse on purpose: it is the coach's ordering of the courts,
    /// `Group.rankOrder`'s own note says it is free to be sparse after a reorder, and
    /// `SupabaseRepository.courts(from:)` re-derives `number` from the rank order's *sequence* on
    /// the next load — so the two agree without this method having to overwrite a decision.
    ///
    /// A coach standing on the removed court is taken off it and returned to whatever their role
    /// does by default, for the same reason `syncGroups` does it: `CourtAssignment.groupID` is not
    /// optional, so an assignment pointing at a court that no longer exists is a dangling row that
    /// no screen can draw.
    ///
    /// ── Why a venue's last group stays ───────────────────────────────────────────────────────
    ///
    /// **A venue keeps at least one group, and the floor is a column rather than a scruple.**
    /// `sites_group_count_range` is `check (group_count between 1 and 40)`
    /// (`20260810040000_a_venue_knows_its_own_shape.sql:82`), so the decrement below reaching 0 is
    /// a write Postgres refuses — and refused before there was a `deleteGroup` to be called from,
    /// because `updateVenue` posts the same column. Clamping to 0 here and letting the database
    /// say no produces the worst version of it: the group leaves the screen optimistically, the
    /// write throws, `AppStore.removeGroup` puts it back, and the reader has watched a group
    /// vanish and return under an error banner.
    ///
    /// **Relaxing the CHECK to `0…40` was the alternative, and it is a bigger change than it
    /// looks.** A venue with no groups *draws* — Groups has its unassigned band, its "nothing
    /// here" state and its "Add a group" row, and `BlockCourtPicker` has an empty row written for
    /// exactly this. What it cannot be is *set*, or *kept*: `CampDraft.groupRange` is `1...16` and
    /// floors Setup's stepper (`VenueCourtStepper`), `CampShape.groupRange` is `1...12` and
    /// `VenueSheet.shaped(_:)` clamps into it — so opening the venue sheet on such a venue and
    /// pressing Save silently puts a group back. And `PlayerCourtChoices` drops a venue with no
    /// courts from the move list, so the kids it stranded could not be moved from their own
    /// screen. Zero is a state three screens would each need work to hold, which is what the
    /// migration's own note is saying in one line: a venue with no groups is indistinguishable
    /// from one that does not exist.
    ///
    /// So the floor is *here*, in the one piece of arithmetic both repositories run, which is what
    /// makes the offline build and Postgres agree about it instead of diverging.
    /// `SycamoreRepository.deleteGroup(_:campID:)` carries the rest and is where the refusal gets
    /// a name: both implementations throw `SycamoreError.lastGroupAtVenue` rather than calling
    /// this and handing back a camp nothing happened to.
    ///
    /// ── The two ids that are ignored ─────────────────────────────────────────────────────────
    ///
    /// A group id that is not at `venueID` is ignored rather than removed from wherever it really
    /// lives. The caller names both because it holds both, and a mismatch is a stale id from a
    /// screen that has moved on — not permission to empty a court at another venue. A venue's only
    /// group is ignored for the reason above. Both are silent because both callers ask first: the
    /// repositories name the refusal, and `GroupsView` does not offer the swipe at all.
    mutating func removeGroup(_ groupID: Group.ID, from venueID: Venue.ID) {
        guard groups.contains(where: { $0.id == groupID && $0.venueID == venueID }) else { return }
        // Against the groups actually held, not against `groupCount` — that field is the
        // denormalised claim this method exists to bring back into line, so asking it whether
        // there is a group to spare would be asking the number being corrected.
        guard groups.contains(where: { $0.venueID == venueID && $0.id != groupID }) else { return }

        groups.removeAll { $0.id == groupID }

        for index in players.indices where players[index].groupID == groupID {
            players[index].groupID = nil
            players[index].courtRank = Int.max / 2
        }

        for index in staff.indices where staff[index].assignment?.groupID == groupID {
            staff[index].assignment = nil
            staff[index].isRoaming = staff[index].role.roamsByDefault
        }

        for (offset, remaining) in groups(in: venueID).enumerated() {
            guard let index = groups.firstIndex(where: { $0.id == remaining.id }) else { continue }
            let number = offset + 1
            groups[index].number = number
            groups[index].label = "\(sport.groupNoun) \(number)"
        }

        if let index = venues.firstIndex(where: { $0.id == venueID }) {
            // `max(1, …)` and not `max(0, …)`: 1 is where `sites_group_count_range` holds this
            // column, so a 0 written here is a row Postgres will not take. The guard above already
            // means a venue whose count agrees with its groups cannot reach the clamp; this is for
            // one whose count has drifted below them, where rounding up to the floor is the only
            // answer that is still writable.
            venues[index].groupCount = max(1, venues[index].groupCount - 1)
        }

        reindex()
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
    ///
    /// **Counted off `players`, not off `Group.playerCount`, and that is the whole point of the
    /// method.** `playerCount` is denormalised (`:784`) and has exactly one writer, `reindex()`
    /// (`:1448`). Every caller here is a *loop* that seats one kid per turn and reindexes at the
    /// end — `syncGroups(for:)` at `:1828`, `applyRankOrder(_:)` at `:1530` — so a stored count
    /// read mid-loop is the count from before the loop began. It does not move as kids are
    /// seated, `min` returns the same court on every iteration, and the entire queue is parked on
    /// one court. On a fresh venue every count is 0, the tie falls to the lowest `rankOrder`, and
    /// that court is always Court 1.
    ///
    /// That was the "all the kids in one group" bug, and it was reachable without an import at
    /// all: any ordinary venue write — a rename — runs `upsert` → `syncGroups` and parks the lot.
    ///
    /// Refreshing `reindex()` before the loop would not fix it. One refresh is a snapshot, and the
    /// loop invalidates it on its first pass; the count has to be re-derived per call, which is
    /// what this now does.
    ///
    /// `Group.playerCount` is deliberately left alone. It is what the cards read, `reindex()`
    /// stays its only writer, and nothing outside a mid-mutation loop needs it fresher than that.
    /// The cost here is groups × players per call — a hundred kids over twelve courts, inside a
    /// loop that runs once per unseated kid, which at camp scale is nothing.
    func smallestGroupID(in venueID: Venue.ID) -> Group.ID? {
        groups(in: venueID)
            .min { lhs, rhs in
                let left = players.count { $0.groupID == lhs.id }
                let right = players.count { $0.groupID == rhs.id }
                return left == right ? lhs.rankOrder < rhs.rankOrder : left < right
            }?
            .id
    }
}

// MARK: - Building a camp from scratch

extension Camp {
    /// Screen 4's output: N venues, M courts each, no kids and no staff yet.
    static func make(from draft: CampDraft, inviteCode: String) -> Camp {
        var camp = Camp(
            // The trimmed value, which is also what `isValid` measured — so the string that
            // passed the gate is the string that reaches the column.
            name: draft.trimmedName,
            sport: draft.sport,
            inviteCode: inviteCode,
            icon: Venue.iconOptions[0],
            tint: .moss,
            // Falls back rather than passing an empty set on. `camps_camp_days_check` is
            // `check (camp_days > 0 and camp_days <= 127)`
            // (`supabase/migrations/20260809030000_camp_days_and_block_assignment.sql:37-38`) and
            // fires at `insert` — which is at the *end* of the onboarding flow, five screens
            // after the picker that should have refused it. A camp created without a day is a bug
            // upstream, and the column's own DEFAULT is the same 31 this substitutes.
            //
            // Deliberately not the rule an *edit* follows: Camp settings is one tap from an
            // editor that has already refused the empty set, so there the CHECK is allowed to
            // speak rather than have a week nobody chose written in its place.
            days: draft.days.isValid ? draft.days : .weekdays
        )
        for index in 0..<max(1, draft.venueCount) {
            let icon = Venue.iconOptions[index % Venue.iconOptions.count]
            let venue = Venue(
                name: "Venue \(index + 1)",
                subtitle: nil,
                icon: icon,
                tint: .suggested(for: icon),
                courtCount: max(1, draft.groupsPerVenue),
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
