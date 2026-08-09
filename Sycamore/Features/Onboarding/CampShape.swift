//
//  CampShape.swift
//  Sycamore
//
//  What `8b` actually asks for: a row per venue with its own name, emoji, court count and the two
//  head counts that bound it. `CampDraft` carries almost none of that — it has a single
//  `venueCount` and a single `groupsPerVenue` for the whole camp, and nothing at all about how
//  many people belong in one.
//
//  So the screen holds this instead, and the camp is reshaped to match the moment it exists:
//  `createCamp` builds the venues from the draft (uniform), then `venue(applying:)` below
//  writes each row's real values back through `updateVenue`, which re-syncs the courts. The
//  round trip is invisible and the saved camp is the shape the person drew.
//
//  A venue's name, subtitle and emoji ride the same round trip. `Camp.make(from:)` gives every new
//  venue the name and icon its position implies, which is the right guess and the wrong answer
//  once somebody has edited one — so the edits are stored on the row here and written over the
//  seeded values a moment later. Nothing in `Models.swift` or `Store/` had to change for that: the
//  correction path the court counts already take was the path the rest needed.
//
//  Fold this into `CampDraft` when the store can take it — see the PR body.
//

import Foundation

/// One row of `8b`'s VENUES card.
struct VenueShape: Identifiable, Hashable, Sendable {
    var id = UUID()
    /// What this venue is called. Seeded positionally — `Camp.make(from:)` would name it the same
    /// way — and typed over in `VenueShapeSheet`, which `venue(applying:)` then writes through.
    ///
    /// A name that still matches `Venue <digits>` is one nobody has typed, and `removeVenue`
    /// renumbers exactly those. `CampShape.isPositionalName` is the whole of that rule.
    var name: String
    /// "Higher level" — the design's second line. Nil reads as the placeholder.
    var subtitle: String?
    /// One of `Venue.iconOptions`. Seeded from the row's position and then chosen from the
    /// editor's six tiles; `venue(applying:)` writes it into the created venue.
    ///
    /// This used to be computed at the two places a row is made and thrown away again, with only
    /// the tint it implied surviving — so the screen knew which emoji a venue was going to get
    /// and drew a pin instead. Storing it is what makes it choosable.
    var icon: String
    /// The tile's colour, which on this screen is always the emoji's own.
    ///
    /// Computed rather than stored, which is the whole reason the editor needs no tint binding of
    /// its own: `8b` and screen 11's grid draw no tint control, so there is nothing here that
    /// could make the two disagree, and a stored copy would only be a second field to forget to
    /// write — a citron plate under a tree, one tap after choosing the tree. `Venue.tint` stays
    /// stored because screen 11 genuinely can separate them ("unless someone has said otherwise",
    /// `VenueSheet.swift:94`).
    var tint: VenueTint { .suggested(for: icon) }
    /// Courts, fields or lanes, depending on the sport.
    var courts: Int
    /// The ceiling the auto-partition works under — `sites.player_max`.
    ///
    /// An absolute rather than a rate, because that is what the column is and what the editor
    /// edits. Seeded from `courts * kidsPerCourt` and re-derived whenever either of those moves;
    /// between those moments it is whatever somebody typed.
    var maxKids: Int
    /// The floor a venue is measured against — `sites.coach_min`. Below it the venue reads short.
    var minCoaches: Int
}

extension VenueShape {

    /// A one-line reading of the two limits, for the row that cannot show both fields.
    var limitsLine: String {
        "up to \(maxKids) kids · \(minCoaches)+ coaches"
    }

    /// The court count and everything that follows from it.
    ///
    /// Changing the courts always re-derives this row's ceiling and floor from the camp-wide
    /// rates. One rule and no flag: a venue taken from six courts to eight otherwise keeps a
    /// 48-kid ceiling it was only ever given because it had six. The cost is that a per-venue
    /// override is dropped by a stepper somebody deliberately moved on that venue's own row,
    /// which is the moment they are looking at it.
    ///
    /// On the row rather than on `CampShape`, even though the shape is where the rates live,
    /// because two steppers set it and only one of them has a shape to hand:
    /// `CampShape.setCourts(_:for:)` forwards here for `8b`'s row, and `VenueShapeSheet` calls it
    /// directly on a draft that has not been committed to the shape yet. A third consequence of
    /// changing the courts is then added once.
    mutating func setCourts(_ courts: Int, kidsPerCourt: Int, coachesPerCourt: Int) {
        self.courts = CampShape.clamp(courts, into: CampShape.courtRange)
        maxKids = CampShape.kidsCeiling(forCourts: self.courts, at: kidsPerCourt)
        minCoaches = CampShape.coachFloor(forCourts: self.courts, at: coachesPerCourt)
    }
}

struct CampShape: Hashable, Sendable {

    var venues: [VenueShape]
    /// The rate every venue's ceiling is seeded from, and re-derived from whenever this moves.
    ///
    /// `8b` draws 8. `Camp.make(from:)` implies 10 (`playerMax = courts * 10`), which is not a
    /// number anybody chose — it is what falls out of the seed. The design's 8 wins.
    ///
    /// Not read by `venue(applying:)` any more. Once a row carries its own absolutes the rate is
    /// only ever a *writer* of them, which is why the card it sits in is titled "Every venue" and
    /// its steppers go through `setKidsPerCourt(_:)` rather than binding straight here.
    var kidsPerCourt: Int = CampShape.defaultKidsPerCourt
    /// The rate every venue's floor is seeded from. The floor is what "flags a venue as short"
    /// means.
    var coachesPerCourt: Int = CampShape.defaultCoachesPerCourt

    /// The two rates a camp starts on, as statics so `initial` can seed a row from them — it
    /// builds the venues before there is a `CampShape` to read them off.
    static let defaultKidsPerCourt = 8
    static let defaultCoachesPerCourt = 1

    /// Bounds. The two venue-facing ones are `CampDraft`'s, so a shape can never describe a
    /// camp the draft cannot then create.
    static let venueRange = CampDraft.venueRange
    static let courtRange = CampDraft.groupRange
    static let kidsRange = 1...24
    /// Zero is allowed and means "never flag a venue as short" — a camp with one roaming coach
    /// for the whole site is a real way to run a week.
    static let coachRange = 0...4

    /// What a venue's own ceiling may be: nothing at all, up to the biggest venue the two rate
    /// steppers can describe. Derived rather than written down, the way `venueRange` is — `0...384`
    /// is `16 × 24`, and typing it here is how it would come to disagree with the steppers.
    static let venueKidsRange = 0...(courtRange.upperBound * kidsRange.upperBound)

    /// The same, for the coach floor: `0...64` is `16 × 4`.
    static let venueCoachRange = 0...(courtRange.upperBound * coachRange.upperBound)

    /// How far over its floor a venue may be staffed and still read as in range.
    ///
    /// One, which is the slack `Camp.make(from:)` already allows (`coachMax = groupsPerVenue + 1`,
    /// `Models.swift:1198`). It is also what makes `coach_min <= coach_max` hold by construction
    /// rather than by branch — see `venue(applying:)`.
    static let coachSlack = 1

    /// `value`, brought inside `range`. Named here rather than spelled `min(max(…))` at six call
    /// sites, because every one of them is guarding the same two Postgres CHECKs.
    static func clamp(_ value: Int, into range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The ceiling a row of `courts` implies at the camp-wide rate, already inside range.
    static func kidsCeiling(forCourts courts: Int, at kidsPerCourt: Int) -> Int {
        clamp(courts * kidsPerCourt, into: venueKidsRange)
    }

    /// The floor a row of `courts` implies at the camp-wide rate, already inside range.
    static func coachFloor(forCourts courts: Int, at coachesPerCourt: Int) -> Int {
        clamp(courts * coachesPerCourt, into: venueCoachRange)
    }

    /// Two venues, six courts each — the app's own `CampDraft()` defaults, so opening `8b` and
    /// saving without touching anything creates exactly what it did before.
    static func initial(
        venueCount: Int = CampDraft().venueCount,
        courts: Int = CampDraft().groupsPerVenue,
        kidsPerCourt: Int = defaultKidsPerCourt,
        coachesPerCourt: Int = defaultCoachesPerCourt
    ) -> CampShape {
        CampShape(
            venues: (0..<max(1, venueCount)).map { index in
                // The same rotation `Camp.make(from:)` seeds with, so a camp saved without
                // opening the editor once is exactly the camp this screen drew — same name, same
                // emoji, same tint, in the same order.
                VenueShape(
                    name: positionalName(for: index),
                    subtitle: nil,
                    icon: Venue.iconOptions[index % Venue.iconOptions.count],
                    courts: courts,
                    maxKids: kidsCeiling(forCourts: courts, at: kidsPerCourt),
                    minCoaches: coachFloor(forCourts: courts, at: coachesPerCourt)
                )
            },
            kidsPerCourt: kidsPerCourt,
            coachesPerCourt: coachesPerCourt
        )
    }

    var totalCourts: Int { venues.reduce(0) { $0 + $1.courts } }

    /// `2 venues · 10 courts`, in the sport's own noun.
    func summaryLine(noun: String) -> String {
        let venueWord = venues.count == 1 ? "venue" : "venues"
        let courtWord = totalCourts == 1 ? noun : "\(noun)s"
        return "\(venues.count) \(venueWord) · \(totalCourts) \(courtWord)"
    }

    // MARK: - Names

    /// What setup calls the venue in position `index`, counting from zero.
    ///
    /// The same string `Camp.make(from:)` (`Models.swift:1191`) and `Repository.addVenue`
    /// (`Repository.swift:434`, `SupabaseRepository.swift:533`) each build for themselves — and
    /// this change makes the format load-bearing rather than cosmetic, because `isPositionalName`
    /// below now parses it. A fifth spelling that drifted would hand the parser a name it read as
    /// somebody's own and stop renumbering it. One of these four should own it; none can yet,
    /// because three of them are the store's and this is the form's.
    static func positionalName(for index: Int) -> String { "Venue \(index + 1)" }

    /// Whether `name` is one of ours — a number setup handed out rather than a name somebody
    /// typed.
    ///
    /// `Venue <digits>`, ignoring case and surrounding space, and that pattern is *reserved*:
    /// `VenueShapeSheet` refuses it as a typed name, so the two name-spaces are disjoint by
    /// construction and no row needs a stored "has been renamed" flag to sit alongside the name
    /// and drift out of step with it.
    ///
    /// Case-insensitive because the reservation has to be: `venue 3` and `Venue 3` cannot both be
    /// allowed to exist, or `removeVenue` would renumber one of them onto the other.
    ///
    /// `Court 4`, `Venue A`, `Venue` and `Venue 3a` are all names somebody chose, and all stay.
    static func isPositionalName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.hasPrefix("venue") else { return false }
        let afterWord = trimmed.dropFirst("venue".count)
        let digits = afterWord.drop { $0.isWhitespace }
        // A separator is required — `Venue3` is not a name setup has ever handed out, so it is
        // somebody's to keep.
        guard digits.count < afterWord.count, !digits.isEmpty else { return false }
        // `isASCII` as well as `isNumber`: `Character.isNumber` is true of `٣` and of `½`, and a
        // name made of those is a name somebody typed.
        return digits.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Whether `trimmed` is free for the row `id` to take.
    ///
    /// Case-insensitive, and deliberately stricter than the column it protects.
    /// `sites_camp_id_name_key` is `unique (camp_id, name)`
    /// (`supabase/migrations/20260808211500_fresh_start_and_camp_isolation.sql:267`), which is
    /// case-*sensitive* and would happily take "Main Courts" and "main courts" in one camp, with
    /// neither findable by ear and both drawn identically in a chip row.
    ///
    /// This is also the only place a collision can be *refused*. `insertSite` resolves one by
    /// appending four random characters (`SupabaseRepository+Enrolment.swift:109`), which is the
    /// right answer for a name the app chose for somebody and the wrong one for a name they typed
    /// — and by the time it fires the editor is gone, the whole onboarding flow has been walked,
    /// and there is nothing left to correct it from.
    func isVenueNameAvailable(_ trimmed: String, excluding id: VenueShape.ID) -> Bool {
        let folded = trimmed.lowercased()
        return !venues.contains { row in
            row.id != id && row.name.trimmingCharacters(in: .whitespaces).lowercased() == folded
        }
    }

    // MARK: - Editing

    /// The next row `Add a venue` appends. Keeps the naming, tinting and seeding rules going
    /// rather than inventing a second set.
    ///
    /// `positionalName(for: venues.count)` is free without checking, and that is by construction:
    /// every row is either at its own positional number or carries a typed name, and a typed name
    /// can never look positional.
    mutating func addVenue() {
        guard venues.count < Self.venueRange.upperBound else { return }
        let index = venues.count
        let courts = venues.last?.courts ?? CampDraft().groupsPerVenue
        venues.append(
            VenueShape(
                name: Self.positionalName(for: index),
                subtitle: nil,
                icon: Venue.iconOptions[index % Venue.iconOptions.count],
                courts: courts,
                maxKids: Self.kidsCeiling(forCourts: courts, at: kidsPerCourt),
                minCoaches: Self.coachFloor(forCourts: courts, at: coachesPerCourt)
            )
        )
    }

    /// Removing a row renumbers the names *nobody has typed*, because those are positional and a
    /// camp with a "Venue 1" and a "Venue 3" and nothing between them reads as a bug.
    ///
    /// It used to renumber every survivor, which was right for exactly as long as every name was
    /// setup's. Now that a venue can be called "Main Courts", renaming it on the way past would
    /// silently take back something typed a minute earlier — so the rule is the pattern rather
    /// than a flag: a name is positional iff it matches `Venue <digits>`, and `VenueShapeSheet`
    /// refuses that pattern as a typed name so the two sets can never overlap.
    ///
    /// The renumbering counts *absolute position in the camp*, not ordinal among the positional
    /// rows: `["Main Courts", "Venue 2", "Venue 3"]` is right, because Main Courts is venue one —
    /// it just has a name of its own. Numbering the positional rows 1, 2 among themselves would
    /// hand the camp two venue ones.
    ///
    /// The icons deliberately do not renumber, and the tints follow the icons. They used to — the
    /// icon was implied by the row's position, so position was the only thing that could carry it,
    /// and re-deriving the tint on removal was how they stayed in the design's order. Now that the
    /// emoji is chosen, re-deriving would silently take back a choice made two taps earlier and
    /// hand the row a colour nobody asked for. A number is positional; an emoji is not, and
    /// neither is a name.
    mutating func removeVenue(_ id: VenueShape.ID) {
        guard venues.count > Self.venueRange.lowerBound else { return }
        venues.removeAll { $0.id == id }
        for index in venues.indices where Self.isPositionalName(venues[index].name) {
            venues[index].name = Self.positionalName(for: index)
        }
    }

    /// One row's court count, with the camp-wide rates supplied — see
    /// `VenueShape.setCourts(_:kidsPerCourt:coachesPerCourt:)` for what follows from it and why
    /// the rule lives on the row.
    mutating func setCourts(_ courts: Int, for id: VenueShape.ID) {
        guard let index = venues.firstIndex(where: { $0.id == id }) else { return }
        venues[index].setCourts(courts, kidsPerCourt: kidsPerCourt, coachesPerCourt: coachesPerCourt)
    }

    /// The camp-wide kids rate, written into every venue.
    ///
    /// A bulk write rather than a number `venue(applying:)` reads, and that is what keeps the
    /// common case — every venue the same — at one stepper while a per-venue override survives
    /// until somebody moves the camp-wide one whose own subtitle says it does this.
    mutating func setKidsPerCourt(_ value: Int) {
        kidsPerCourt = Self.clamp(value, into: Self.kidsRange)
        for index in venues.indices {
            venues[index].maxKids = Self.kidsCeiling(forCourts: venues[index].courts, at: kidsPerCourt)
        }
    }

    /// The camp-wide coach rate, written into every venue's floor.
    mutating func setCoachesPerCourt(_ value: Int) {
        coachesPerCourt = Self.clamp(value, into: Self.coachRange)
        for index in venues.indices {
            venues[index].minCoaches = Self.coachFloor(forCourts: venues[index].courts, at: coachesPerCourt)
        }
    }

    // MARK: - Reaching the camp

    /// What the draft can carry of this. The court count is the first row's — every other row
    /// is corrected by `venue(applying:)` a moment later, and creating the camp with one of the
    /// real numbers means the common case (every venue the same) needs no correction at all.
    ///
    /// Names, subtitles and the two head counts cannot ride here any more than the icon can:
    /// `CampDraft` has one field per camp and these are one per venue. They take the same
    /// correction path.
    func applied(to draft: CampDraft) -> CampDraft {
        var draft = draft
        draft.venueCount = venues.count
        draft.groupsPerVenue = venues.first?.courts ?? draft.groupsPerVenue
        return draft
    }

    /// `existing` with row `index` written into it, or nil when the two already agree and there is
    /// nothing to send.
    ///
    /// **Every assignment is a pure function of `row`**, which is what makes this idempotent —
    /// `applyShape` runs it over every venue on every camp creation, and a second pass has to be
    /// silent. Trims are idempotent, clamps are idempotent, and `coachMax` is derived from the
    /// just-clamped `coachMin` rather than from `existing`, which is the one place that could
    /// otherwise creep by a coach per run.
    ///
    /// The four numbers are derived so that `sites_ranges_ordered`
    /// (`check (coach_min <= coach_max and player_min <= player_max)`,
    /// `supabase/migrations/20260805141707_camps_memberships_profiles.sql:94-97`) holds by
    /// construction, for every value in both ranges, with no branch:
    ///
    /// - `playerMin` is a constant 0. A venue with a floor would read as short before anybody
    ///   arrived, and `8b` has no roster to measure one against.
    /// - `playerMax` is the row's own ceiling, clamped — so it is at least 0 and the second half
    ///   of the CHECK is `0 <= playerMax`.
    /// - `coachMin` is the row's own floor, clamped.
    /// - `coachMax` is `coachMin + coachSlack`, so the first half is `n <= n + 1`. The slack is
    ///   the one-over `Camp.make(from:)` already allows, so a venue that is one coach up does not
    ///   read as over-staffed.
    ///
    /// No migration was needed for any of it: `player_max`, `player_min`, `coach_min` and
    /// `coach_max` have existed since `:78-87` of that same file.
    ///
    /// The name, subtitle, icon and tint ride the same round trip. `Camp.make(from:)` seeds the
    /// name from the venue's position and the icon from the rotation (`Models.swift:1190-1196`),
    /// which is right only for as long as nobody has edited — and editing is now the point of the
    /// row. Without the name here, anything typed into the editor would be silently discarded and
    /// the created camp would number its venues positionally after all. Tint as well as icon: a
    /// tint the design pairs with a different emoji would leave the tile the wrong colour for
    /// what is on it.
    func venue(applying index: Int, to existing: Venue) -> Venue? {
        guard venues.indices.contains(index) else { return nil }
        let row = venues[index]
        let subtitle = (row.subtitle ?? "").trimmingCharacters(in: .whitespaces)

        var updated = existing
        updated.name = row.name.trimmingCharacters(in: .whitespaces)
        updated.subtitle = subtitle.isEmpty ? nil : subtitle
        updated.icon = row.icon
        updated.tint = row.tint
        updated.groupCount = row.courts
        updated.playerMin = 0
        updated.playerMax = Self.clamp(row.maxKids, into: Self.venueKidsRange)
        updated.coachMin = Self.clamp(row.minCoaches, into: Self.venueCoachRange)
        updated.coachMax = updated.coachMin + Self.coachSlack

        return updated == existing ? nil : updated
    }
}
