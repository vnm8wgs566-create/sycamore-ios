//
//  RosterAgeFit.swift
//  Sycamore
//
//  Which venue each arriving kid actually lands at, once the venues' age bands have had their say
//  — and who nobody will take.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT A BAND IS FOR
//  ---------------------------------------------------------------------------------------------
//
//  `AgeBand`'s own header says it: *"What this does not do is filter a list. It decides where an
//  imported kid lands."* Until now nothing decided anything with it. A venue could be set to
//  `12 & up` and a forty-row sign-up list would still deal every eight-year-old onto it, because
//  the import path never asked. This is the asking.
//
//  ---------------------------------------------------------------------------------------------
//  THE RULE, IN ORDER
//  ---------------------------------------------------------------------------------------------
//
//  For each row, in this order and stopping at the first that answers:
//
//  1. **The venue they were answered into.** `AppStore.applyRoster` resolves `IntakePlayer
//     .venueIndex` as `venues[min(index, count - 1)]`, and that arithmetic is repeated here rather
//     than approximated — a preview that resolved the venue differently from the write would name
//     the wrong venue in every sentence on the review screen. A file's rows all carry 0, so in
//     practice this is "the first venue" for an import and "the chip you tapped" for a walk-in.
//  2. **Any venue that will take them**, in the camp's own order, when the first will not. A camp
//     with an `11 & under` site and a `12 & up` site is a camp that has already written down where
//     its twelve-year-olds go; making somebody re-file forty rows by hand afterwards would be the
//     app refusing to read its own configuration.
//  3. **Nobody.** They are still created — they signed up, they belong to the camp — and they stay
//     at the venue from step 1 with a reason attached, so a screen can say out loud that four kids
//     did not land and why.
//
//  `AgeBand.admits(_:)` is the only judge at every step. Nothing here re-derives what an age band
//  means, and in particular nothing here decides what a **missing age** means: that method already
//  refuses a nil age at a restricted band and its comment gives the whole argument for it
//  (`Models.swift:534-551`). This type's only job on that point is to keep the two apart in the
//  *copy* — "outside the ages" and "no age on file" are different sentences to read next to a
//  child's name, and only one of them is about the child.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT THIS CANNOT DO, STATED RATHER THAN FUDGED
//  ---------------------------------------------------------------------------------------------
//
//  The design leaves a refused kid with `venueId` **and** `group` nil (`state1.js:507-509`). Half
//  of that is already true here and always was — `Repository.importPlayers` sets `groupID = nil`
//  on every arrival on purpose, so nobody is dealt onto a court by an import. The venue half is
//  not reachable from this layer: every write path into the roster (`importPlayers`, `addPlayer`,
//  `movePlayer`) takes a non-optional `toVenue:`, so there is no way to create a kid who belongs
//  to no venue. Step 3 above is the closest honest thing — they land somewhere, and the screen
//  says nobody chose it. Closing the gap properly means a repository that can insert a kid with no
//  venue, which is a change to files this unit does not own.
//

import Foundation

// MARK: - A venue, as a roster needs to see it

/// The two things about a venue that decide where an arriving kid goes.
///
/// Not `Venue` itself, for the reason `VenueShapeAdapter` gives about `VenueShape`: the callers
/// are the enrolment screens, one of which (`AddPlayerView`) runs at onboarding where no `Venue`
/// exists yet and only ever had a name and an id to work with. A two-field value both call sites
/// can build means the rule below is written once for the file path and the by-hand path, rather
/// than once each with a chance of disagreeing.
struct RosterVenue: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let band: AgeBand

    init(id: UUID, name: String, band: AgeBand) {
        self.id = id
        self.name = name
        self.band = band
    }
}

extension Venue {
    /// This venue as the enrolment screens need it.
    var rosterVenue: RosterVenue { RosterVenue(id: id, name: name, band: ageBand) }
}

extension VenueShape {

    /// This sketched venue as the enrolment screens need it.
    ///
    /// The onboarding flow reaches `AddPlayerView` and `ImportReviewView` while the camp is still
    /// `8b`'s sketch — there are no `Venue` rows yet, because the camp is written at the *end* of
    /// that flow — so the band has to travel on the shape or not at all. It used to not at all:
    /// both screens took the band through an optional parameter the onboarding call sites omitted,
    /// so a venue narrowed on `8b` admitted everybody two screens later, in silence.
    ///
    /// Same shape and same name as `Venue.rosterVenue` above, so the rule reads one type whichever
    /// side of camp creation the caller is standing on.
    var rosterVenue: RosterVenue { RosterVenue(id: id, name: name, band: ageBand) }
}

// MARK: - Where the roster lands

struct RosterAgeFit: Equatable, Sendable {

    /// Why a venue would not take a kid. Two cases because they are two different sentences, and
    /// putting the second one under the first would tell a parent their child was the wrong age
    /// when what actually happened is that a spreadsheet had a blank cell.
    enum Refusal: Hashable, Sendable {
        /// They have an age and no venue's band admits it.
        case outsideTheAges
        /// They have no age at all, and every venue that might have taken them is asking.
        case noAgeOnFile
    }

    /// One row, answered.
    struct Landing: Identifiable, Equatable, Sendable {
        let row: IntakePlayer
        /// Where they go — a position, because that is the only thing `IntakePlayer` can carry and
        /// the only thing `AppStore.applyRoster` reads. See `IntakePlayer.venueIndex`.
        let venueIndex: Int
        /// The venue at that position, named, for the sentence on screen.
        let venueName: String
        /// Nil when a venue took them, which includes every venue that was not asking.
        let refusal: Refusal?

        var id: IntakePlayer.ID { row.id }
        var isPlaced: Bool { refusal == nil }

        /// The row with `venueIndex` rewritten to where it is actually going.
        ///
        /// **This is the only thing that makes the routing real.** The screens draw off `Landing`;
        /// the write reads `IntakePlayer.venueIndex`. A commit built from the untouched rows would
        /// show one answer and write another.
        var routed: IntakePlayer {
            var copy = row
            copy.venueIndex = venueIndex
            return copy
        }
    }

    /// The venues in the order `applyRoster` resolves an index against — the camp's own order.
    let venues: [RosterVenue]
    /// Every row, in the order the file gave them.
    let landings: [Landing]

    /// Works out where each row goes. See the header for the rule.
    ///
    /// An empty `venues` means the caller has none to offer — onboarding before the camp is
    /// written, most often — and every row comes back placed at index 0 with the venue unnamed.
    /// That is the honest answer: nothing is asking, so nothing is refused.
    init(_ rows: [IntakePlayer], venues: [RosterVenue]) {
        self.venues = venues
        self.landings = rows.map { row in
            guard !venues.isEmpty else {
                return Landing(row: row, venueIndex: 0, venueName: "", refusal: nil)
            }

            // `applyRoster`'s own arithmetic, deliberately repeated. See the header.
            let homeIndex = min(max(0, row.venueIndex), venues.count - 1)
            if venues[homeIndex].band.admits(row.age) {
                return Landing(
                    row: row, venueIndex: homeIndex,
                    venueName: venues[homeIndex].name, refusal: nil
                )
            }

            if let takerIndex = venues.firstIndex(where: { $0.band.admits(row.age) }) {
                return Landing(
                    row: row, venueIndex: takerIndex,
                    venueName: venues[takerIndex].name, refusal: nil
                )
            }

            return Landing(
                row: row, venueIndex: homeIndex, venueName: venues[homeIndex].name,
                // Not a judgement about the age — `AgeBand.admits` has already made the only one
                // there is. This is a judgement about which sentence to print.
                refusal: row.age == nil ? .noAgeOnFile : .outsideTheAges
            )
        }
    }
}

// MARK: - Reading the answer

extension RosterAgeFit {

    var placed: [Landing] { landings.filter(\.isPlaced) }
    var unplaced: [Landing] { landings.filter { !$0.isPlaced } }

    /// Nothing to warn anybody about — either every kid found a venue, or no venue was asking.
    var isEverybodyPlaced: Bool { landings.allSatisfy(\.isPlaced) }

    /// Whether any venue narrows its ages at all. When nothing is asking there is no rule to
    /// explain and no section to draw, which is the ordinary case and has to stay silent.
    var anyVenueAsks: Bool { venues.contains { $0.band != .all } }

    /// Every row with its `venueIndex` rewritten to where this fit sends it — what a commit must
    /// be built from.
    var routedRows: [IntakePlayer] { landings.map(\.routed) }

    /// `38 go to Sycamore · 4 need someone to place them`, and just the first half when everybody
    /// landed.
    ///
    /// -----------------------------------------------------------------------------------------
    /// WHY NOT THE DESIGN'S SENTENCE
    /// -----------------------------------------------------------------------------------------
    ///
    /// The design's toast reads `"{n} dealt into {g} groups · {m} unassigned"` (`state1.js:721`).
    /// Both halves of it would be false here. Nothing is *dealt into groups* by an import in this
    /// app — `Repository.importPlayers` leaves `groupID` nil on every arrival, deliberately, so
    /// that nobody is dropped onto court 1 ahead of kids already standing there; the first sort is
    /// what places them. And "unassigned" describes a kid with no venue, which this layer cannot
    /// produce (see the header). Printing the design's words over behaviour the app does not have
    /// would be a screen lying about a decision somebody is taking on behalf of forty children.
    ///
    /// So the sentence says what will actually happen. It is deliberately about *venues* rather
    /// than groups, and its second half names the thing that needs a person rather than a state.
    var outcomeLine: String {
        let landed = placed.count
        let venuePart = venueSummary(for: landed)
        guard !isEverybodyPlaced else { return venuePart }
        let stranded = unplaced.count
        return "\(venuePart) · \(stranded) need\(stranded == 1 ? "s" : "") someone to place them"
    }

    /// `38 go to Sycamore` when one venue took them all, `38 go to their venues` when the split
    /// crossed more than one — naming three sites in a summary line is a list, not a summary.
    private func venueSummary(for landed: Int) -> String {
        let names = Set(placed.map(\.venueName)).subtracting([""])
        guard let only = names.first, names.count == 1 else {
            return "\(landed) go to their venues"
        }
        return "\(landed) go to \(only)"
    }

    /// The line under a name in the "Not placed" section.
    ///
    /// Both readings name the band that turned them away, because "outside the ages" on its own
    /// leaves the reader to go and look up which ages the venue takes — and this section exists
    /// precisely for the reader who has not.
    func reason(for landing: Landing) -> String {
        guard let refusal = landing.refusal else { return landing.row.detail }
        let band = bandLabel(atIndex: landing.venueIndex)
        switch refusal {
        case .outsideTheAges:
            return "\(landing.row.detail) · no venue takes that age"
        case .noAgeOnFile:
            // Not "the wrong age" — nobody knows what their age is. The fix is a number, and `8e`
            // is one tap away on this very row.
            return "No age on file · \(band) needs one"
        }
    }

    private func bandLabel(atIndex index: Int) -> String {
        guard venues.indices.contains(index) else { return "This venue" }
        return venues[index].band.label
    }
}

// MARK: - What actually gets written

extension RosterReconciliation.Commit {

    /// The same commit with every **arrival** sent to a venue that will take their age.
    ///
    /// The one place the rule stops being a drawing and becomes a write. `RosterReviewView` shows
    /// the reader where each new kid is going; this is what makes the button agree with it, and it
    /// runs the identical `RosterAgeFit` over the identical rows so the two cannot part company.
    ///
    /// **`updating` and `removing` are left exactly as they are, and that is the whole point of
    /// naming only the first.** `Repository.updatePlayers`' contract is explicit that a file has no
    /// opinion about venue, court or rank — "a re-import that silently reseated everybody would
    /// undo a week of somebody's judgement". A child already at the camp who has a birthday does
    /// not get moved across town by a spreadsheet; the age band decides where an **arrival** lands,
    /// once, and after that where a kid stands is a decision the camp made on Groups.
    func routed(by venues: [RosterVenue]) -> Self {
        Self(
            inserting: RosterAgeFit(inserting, venues: venues).routedRows,
            updating: updating,
            removing: removing
        )
    }
}

// MARK: - One kid at a time

extension RosterAgeFit {

    /// What `8e` should say under its venue chips, or nil when there is nothing to say.
    ///
    /// The by-hand path asks the same question as the file path about exactly one kid, so it goes
    /// through the same rule rather than through a second copy of it. A walk-in is **never
    /// refused** — the person holding the phone is standing in front of the child and can see how
    /// old they are — so this warns and names where they would otherwise go, and the screen saves
    /// them either way.
    ///
    /// - Parameter venueIndex: the chip that is lit.
    static func note(
        forAge age: Int?, atVenue venueIndex: Int, among venues: [RosterVenue]
    ) -> String? {
        guard venues.indices.contains(venueIndex) else { return nil }
        let chosen = venues[venueIndex]
        guard !chosen.band.admits(age) else { return nil }

        let taker = venues.first { $0.band.admits(age) }

        guard age != nil else {
            // The venue is asking and the field is empty. Said as a missing number rather than as
            // a rejection, because that is what it is.
            return taker.map {
                "\(chosen.name) takes \(chosen.band.label), so this needs an age. Without one they go to \($0.name)."
            } ?? "\(chosen.name) takes \(chosen.band.label). Add an age, or they join with no group."
        }

        return taker.map {
            "\(chosen.name) takes \(chosen.band.label), so they go to \($0.name) instead."
        } ?? "\(chosen.name) takes \(chosen.band.label). They join the camp with no group until someone places them."
    }
}
