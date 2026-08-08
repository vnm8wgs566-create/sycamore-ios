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
//  A venue's emoji rides the same round trip. `Camp.make(from:)` gives every new venue the icon
//  its position implies, which is the right guess and the wrong answer once somebody has picked
//  one — so the pick is stored on the row here and written over the seeded value a moment later.
//  Nothing in `Models.swift` or `Store/` had to change for that: the correction path the court
//  counts already take was the path the icon needed.
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
    /// One of `Venue.iconOptions`. Seeded from the row's position and then chosen from the tile
    /// itself; `venue(applying:)` writes it into the created venue.
    ///
    /// This used to be computed at the two places a row is made and thrown away again, with only
    /// the tint it implied surviving — so the screen knew which emoji a venue was going to get
    /// and drew a pin instead. Storing it is what makes it choosable.
    var icon: String
    /// The tile's colour, which on this screen is always the emoji's own.
    ///
    /// Computed rather than stored, which is the whole reason the icon menu needs no binding of
    /// its own: `8b` draws no tint control, so there is nothing here that could make the two
    /// disagree, and a stored copy would only be a second field to forget to write — a citron
    /// plate under a tree, one tap after choosing the tree. `Venue.tint` stays stored because
    /// screen 11 genuinely can separate them ("unless someone has said otherwise",
    /// `VenueSheet.swift:94`).
    var tint: VenueTint { .suggested(for: icon) }
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
                // The same rotation `Camp.make(from:)` seeds with, so a camp saved without
                // opening the icon menu once is exactly the camp this screen drew — same emoji,
                // same tint, in the same order.
                VenueShape(
                    name: "Venue \(index + 1)",
                    subtitle: nil,
                    icon: Venue.iconOptions[index % Venue.iconOptions.count],
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
        venues.append(
            VenueShape(
                name: "Venue \(index + 1)",
                subtitle: nil,
                icon: Venue.iconOptions[index % Venue.iconOptions.count],
                courts: venues.last?.courts ?? CampDraft().groupsPerVenue
            )
        )
    }

    /// Removing a row renumbers the rest, because the names are positional and a camp with a
    /// "Venue 1" and a "Venue 3" and nothing between them reads as a bug.
    ///
    /// The icons deliberately do not renumber with them, and the tints follow the icons. They
    /// used to — the icon was implied by the row's position, so position was the only thing that
    /// could carry it, and re-deriving the tint on removal was how they stayed in the design's
    /// order. Now that the emoji is chosen, re-deriving would silently take back a choice made
    /// two taps earlier and hand the row a colour nobody asked for. A number is positional; an
    /// emoji is not.
    mutating func removeVenue(_ id: VenueShape.ID) {
        guard venues.count > Self.venueRange.lowerBound else { return }
        venues.removeAll { $0.id == id }
        for index in venues.indices {
            venues[index].name = "Venue \(index + 1)"
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

    /// `existing` with row `index`'s numbers and chosen emoji written into it, or nil when the
    /// two already agree and there is nothing to send.
    ///
    /// The limits are derived rather than stored: a venue's ceiling is its courts times what
    /// fits on one, and its coach floor is its courts times what a court needs. `coachMax`
    /// keeps the one-over slack `Camp.make(from:)` already allows, so a venue that is one coach
    /// up does not read as over-staffed.
    ///
    /// The icon and tint ride the same round trip. `Camp.make(from:)` seeds both from the
    /// venue's position (`Models.swift:1151`), which is right only for as long as nobody has
    /// chosen — and choosing is now the point of the tile. This writes the chosen pair over the
    /// top through `updateVenue`, the same way the court counts are corrected, so the emoji
    /// picked on `8b` is the emoji the venue keeps. Both, not just the icon: a tint the design
    /// pairs with a different emoji would leave the tile the wrong colour for what is on it.
    func venue(applying index: Int, to existing: Venue) -> Venue? {
        guard venues.indices.contains(index) else { return nil }
        let row = venues[index]

        var updated = existing
        updated.icon = row.icon
        updated.tint = row.tint
        updated.groupCount = row.courts
        updated.playerMin = 0
        updated.playerMax = row.courts * kidsPerCourt
        updated.coachMin = row.courts * coachesPerCourt
        updated.coachMax = updated.coachMin + 1

        return updated == existing ? nil : updated
    }
}
