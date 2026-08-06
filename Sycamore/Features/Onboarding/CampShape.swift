//
//  CampShape.swift
//  Sycamore
//
//  What `8b` actually asks for: a row per venue with its own court count, and two numbers that
//  describe one court. `CampDraft` carries neither — it has a single `venueCount` and a single
//  `groupsPerVenue` for the whole camp, and nothing at all about how big a court is.
//
//  So the screen holds this instead, and the camp is reshaped to match the moment it exists:
//  `createCamp` builds the venues from the draft (uniform), then `venue(applying:)` below
//  writes each row's real numbers back through `updateVenue`, which re-syncs the courts. The
//  round trip is invisible and the saved camp is the shape the person drew.
//
//  Fold this into `CampDraft` when the store can take it — see the PR body.
//

import Foundation

/// One row of `8b`'s VENUES card.
struct VenueShape: Identifiable, Hashable, Sendable {
    var id = UUID()
    /// Matches what `Camp.make(from:)` will name this venue, so the row is not a promise the
    /// camp then breaks. Naming happens in Camp settings, which is what the header says.
    var name: String
    /// "Higher level" — the design's second line. Nil reads as the placeholder.
    var subtitle: String?
    var tint: VenueTint
    /// Courts, fields or lanes, depending on the sport.
    var courts: Int
}

struct CampShape: Hashable, Sendable {

    var venues: [VenueShape]
    /// `8b` draws 8. `Camp.make(from:)` implies 10 (`playerMax = courts * 10`), which is not a
    /// number anybody chose — it is what falls out of the seed. The design's 8 wins.
    var kidsPerCourt: Int = 8
    /// The floor a court is measured against, which is what "flags a court as short" means.
    var coachesPerCourt: Int = 1

    /// Bounds. The two venue-facing ones are `CampDraft`'s, so a shape can never describe a
    /// camp the draft cannot then create.
    static let venueRange = CampDraft.venueRange
    static let courtRange = CampDraft.groupRange
    static let kidsRange = 1...24
    /// Zero is allowed and means "never flag a court as short" — a camp with one roaming coach
    /// for the whole site is a real way to run a week.
    static let coachRange = 0...4

    /// Two venues, six courts each — the app's own `CampDraft()` defaults, so opening `8b` and
    /// saving without touching anything creates exactly what it did before.
    static func initial(venueCount: Int = CampDraft().venueCount, courts: Int = CampDraft().groupsPerVenue) -> CampShape {
        CampShape(
            venues: (0..<max(1, venueCount)).map { index in
                // The same icon-to-tint pairing `Camp.make(from:)` uses, so the tile colour on
                // this screen is the tile colour the venue keeps.
                let icon = Venue.iconOptions[index % Venue.iconOptions.count]
                return VenueShape(
                    name: "Venue \(index + 1)",
                    subtitle: nil,
                    tint: .suggested(for: icon),
                    courts: courts
                )
            }
        )
    }

    var totalCourts: Int { venues.reduce(0) { $0 + $1.courts } }

    /// `2 venues · 10 courts`, in the sport's own noun.
    func summaryLine(noun: String) -> String {
        let venueWord = venues.count == 1 ? "venue" : "venues"
        let courtWord = totalCourts == 1 ? noun : "\(noun)s"
        return "\(venues.count) \(venueWord) · \(totalCourts) \(courtWord)"
    }

    /// The next row `Add a venue` appends. Keeps the naming and tinting rule going rather than
    /// inventing a second one.
    mutating func addVenue() {
        guard venues.count < Self.venueRange.upperBound else { return }
        let index = venues.count
        let icon = Venue.iconOptions[index % Venue.iconOptions.count]
        venues.append(
            VenueShape(
                name: "Venue \(index + 1)",
                subtitle: nil,
                tint: .suggested(for: icon),
                courts: venues.last?.courts ?? CampDraft().groupsPerVenue
            )
        )
    }

    /// Removing a row renumbers the rest, because the names are positional and a camp with a
    /// "Venue 1" and a "Venue 3" and nothing between them reads as a bug.
    mutating func removeVenue(_ id: VenueShape.ID) {
        guard venues.count > Self.venueRange.lowerBound else { return }
        venues.removeAll { $0.id == id }
        for index in venues.indices {
            venues[index].name = "Venue \(index + 1)"
            venues[index].tint = .suggested(for: Venue.iconOptions[index % Venue.iconOptions.count])
        }
    }

    /// What the draft can carry of this. The court count is the first row's — every other row
    /// is corrected by `venue(applying:)` a moment later, and creating the camp with one of the
    /// real numbers means the common case (every venue the same) needs no correction at all.
    func applied(to draft: CampDraft) -> CampDraft {
        var draft = draft
        draft.venueCount = venues.count
        draft.groupsPerVenue = venues.first?.courts ?? draft.groupsPerVenue
        return draft
    }

    /// `existing` with row `index`'s numbers written into it, or nil when the two already
    /// agree and there is nothing to send.
    ///
    /// The limits are derived rather than stored: a venue's ceiling is its courts times what
    /// fits on one, and its coach floor is its courts times what a court needs. `coachMax`
    /// keeps the one-over slack `Camp.make(from:)` already allows, so a venue that is one coach
    /// up does not read as over-staffed.
    func venue(applying index: Int, to existing: Venue) -> Venue? {
        guard venues.indices.contains(index) else { return nil }
        let row = venues[index]

        var updated = existing
        updated.groupCount = row.courts
        updated.playerMin = 0
        updated.playerMax = row.courts * kidsPerCourt
        updated.coachMin = row.courts * coachesPerCourt
        updated.coachMax = updated.coachMin + 1

        return updated == existing ? nil : updated
    }
}
