//
//  TournamentHeader.swift
//  Sycamore
//
//  The white block at the top of the Tournament tab: the screen's name, the avatar, the line that
//  says which ladder is being drawn from, and a chip per venue.
//
//  ── WHY CHIPS AND NOT THE DESIGN'S PILL ───────────────────────────────────────────────────────
//
//  The design draws one pill carrying the current venue's name with a caret on it, and `venueNext`
//  behind it cycles to the next venue on each tap (`showApp.html:158`). That is a control whose
//  destination is unreadable: at a three-venue camp, reaching LATC from Sycamore means tapping a
//  button labelled "Sycamore" twice and watching what happens. Groups solved the same problem with
//  an exclusive chip row and this is that row — every venue visible, one tap to any of them, the
//  selected one lit.
//
//  Exclusive rather than a toggle, and with no "All", for `GroupsHeader`'s reason and one of its
//  own: a tournament is struck from *one* venue's ladder, so "every venue at once" is not a pool
//  anything here could draw from.
//
//  ── WHY IT WRITES `selectVenue` AND NOT `venueFilter` ─────────────────────────────────────────
//
//  `venueFilter` is Groups' chip row and carries an `.all` case this tab cannot answer.
//  `AppStore+SectionEight.swift:31-36` already argues that section 8's per-venue reads must not be
//  keyed off it — tapping a chip on one tab would silently retarget the others — and the draws
//  loaded here are keyed off `readVenueID`, which is what `selectVenue(_:)` writes. One venue, one
//  answer, and `.task(id:)` on `readVenueID` is the sole owner of the reload that follows.
//

import SwiftUI

struct TournamentHeader: View {

    @Bindable var store: AppStore

    /// The venue whose chip is lit, resolved by the screen from `store.readVenueID`. Nil at a camp
    /// with no venues, where the chip row draws nothing and the empty state does the talking.
    var selectedVenueID: Venue.ID?

    /// `Sycamore · 50 kids on the ladder`.
    ///
    /// The design writes the venue name in its pill and `tMeta` beside it. With the pill replaced
    /// by a row of chips, the venue name is already on screen — but it is on screen as one of
    /// several, and the sentence under the title is what says which of them the rest of the screen
    /// is about. `GroupsHeader` writes the same shape ("5 kids added · Sycamore") for the same
    /// reason.
    var subtitle: String?

    private var venues: [Venue] { store.camp?.orderedVenues ?? [] }

    /// One chip is not a choice.
    ///
    /// A camp with a single venue gets no row: the chip would be permanently selected, pressing it
    /// would change nothing, and the subtitle above already names the place. A control that cannot
    /// alter anything is worse than no control — the same call `GroupCard.isHeaderActive` makes
    /// about a chevron on a card with nothing to fold.
    private var showsChips: Bool { venues.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Tournament", subtitle: subtitle, initials: store.avatarInitials) {
                store.pushedScreen = .campHome
            }

            if showsChips {
                venueChips
                    .padding(.bottom, Spacing.gutterWide)
            }
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    /// A horizontal scroller with the gutter on its *content* rather than on itself, so chips
    /// slide out under the screen edge instead of stopping short of it. `GroupsHeader.venueChips`
    /// is the template, down to the metrics preset.
    private var venueChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.tight) {
                ForEach(venues) { venue in
                    let isSelected = venue.id == selectedVenueID

                    Chip(venue.name, isSelected: isSelected, selectedTone: .dark, metrics: .groupsVenue) {
                        store.selectVenue(venue.id)
                    }
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Spacing.header)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Previews

#Preview("Tournament header") {
    VStack(spacing: 0) {
        TournamentHeader(
            store: .preview,
            selectedVenueID: SampleData.sycamore.id,
            subtitle: "Sycamore · 50 kids on the ladder"
        )
        Spacer(minLength: 0)
    }
    .background(Theme.surfaceWarm)
    .showsMockStatusBar()
    .frame(width: 402, height: 320)
}

#Preview("Tournament header — accessibility1") {
    VStack(spacing: 0) {
        TournamentHeader(
            store: .preview,
            selectedVenueID: SampleData.sycamore.id,
            subtitle: "Sycamore · 50 kids on the ladder"
        )
        Spacer(minLength: 0)
    }
    .background(Theme.surfaceWarm)
    .frame(width: 402, height: 420)
    .environment(\.dynamicTypeSize, .accessibility1)
}
