//
//  TournamentEmptyCard.swift
//  Sycamore
//
//  The three states this tab has before it has a draw: nowhere to seed one, nobody to seed, and
//  nothing seeded yet.
//
//  The design draws all three identically — a white card with the app mark bled off its bottom
//  corner, a serif line, a paragraph, and one green button — and varies only the words. So they
//  are one component taking three sets of words rather than three cards that would drift apart the
//  first time one of them was retouched. `TournamentState` is what names the three.
//
//  They are **exclusive**, in the design's own order: no venue beats no kids beats no draws. That
//  ordering is not arbitrary — each state is the answer to "what is the earliest thing missing" —
//  and it lives in `TournamentState.resolve(…)` so the screen cannot draw two of them at once.
//

import SwiftUI

// MARK: - Which of the four

/// What the tab is showing. The design's four `sc-if` blocks, made exclusive by construction.
///
/// `tHasList` carries no payload: the cards come from the store and the screen reads them there.
enum TournamentState: Hashable, Sendable {
    /// `tNoVenue` — the camp has no venue, so there is no ladder to seed from.
    case noVenue
    /// `tNoKids` — a venue with nobody on its ladder.
    case noKids(venueName: String)
    /// `tEmpty` — a ladder, and nothing drawn from it yet.
    case empty
    /// `tHasList` — the cards, then the "Add a tournament" row.
    case hasList
    /// Not one of the design's four. The store has never been asked about this venue, so an empty
    /// list means "nobody has asked" rather than "there are none" — see
    /// `AppStore.loadedTournamentVenueID`, whose whole reason for existing is this distinction.
    /// Drawing "No draws yet." over a venue whose draws are still in flight is how a screen invites
    /// somebody to build one that already exists.
    case loading

    /// The earliest thing missing, which is what decides the state.
    static func resolve(
        venue: Venue?,
        ladderCount: Int,
        tournamentCount: Int,
        hasLoaded: Bool
    ) -> TournamentState {
        guard let venue else { return .noVenue }
        guard ladderCount > 0 else { return .noKids(venueName: venue.name) }
        guard hasLoaded else { return .loading }
        return tournamentCount > 0 ? .hasList : .empty
    }
}

// MARK: - The card

struct TournamentEmptyCard: View {

    /// "No draws yet." Serif, and short — the design lets it break onto two lines rather than
    /// shrinking it.
    let heading: String
    /// The paragraph under it, held to `emptyCopyWidth` so it breaks where the design breaks it.
    ///
    /// Named `message` and not `body`, which is what it says on the page: a `View` already has a
    /// `body`, and a stored property of that name shadows the one SwiftUI needs.
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Card(radius: TournamentMetrics.cardRadius, isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(heading)
                    .typeStyle(TournamentType.emptyHeading, color: Theme.ink)
                    // The heading is two words at 24pt and a reader on `.accessibility1` gets it
                    // at 40; without this it clips its own descenders rather than taking a second
                    // line.
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .typeStyle(TournamentType.emptyBody, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: TournamentMetrics.emptyCopyWidth, alignment: .leading)
                    .padding(.top, TournamentMetrics.emptyCopyGap)

                PrimaryButton(
                    actionTitle,
                    height: TournamentMetrics.emptyActionHeight,
                    radius: Radius.tile,
                    font: .buttonSmall,
                    action: action
                )
                .padding(.top, TournamentMetrics.emptyActionGap)
            }
            .padding(.vertical, TournamentMetrics.emptyPaddingVertical)
            .padding(.horizontal, TournamentMetrics.emptyPaddingHorizontal)
            // The mark bled off the bottom-right corner at 18%, `right:-8px;bottom:-14px;width:96px`.
            // Behind the content rather than over it, and hidden from VoiceOver: it is a watermark,
            // and a reader who cannot see it has lost nothing.
            .background(alignment: .bottomTrailing) {
                SycamoreMark(variant: .pair)
                    .frame(width: TournamentMetrics.watermark, height: TournamentMetrics.watermark)
                    .opacity(TournamentMetrics.watermarkOpacity)
                    .offset(x: TournamentMetrics.watermarkInsetX, y: TournamentMetrics.watermarkInsetY)
                    .accessibilityHidden(true)
            }
        }
        // The mark is drawn past two edges of the card, so the card has to clip it. `Card` clips
        // its content already; this is the `overflow:hidden` the design writes on the same rule.
        .clipShape(RoundedRectangle(cornerRadius: TournamentMetrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#Preview("Empty states") {
    ScrollView {
        VStack(spacing: TournamentMetrics.cardGap) {
            TournamentEmptyCard(
                heading: "Nowhere to seed a draw yet.",
                message: "Tournaments draw from a venue's ladder — start with the place you run.",
                actionTitle: "Add a venue"
            ) {}

            TournamentEmptyCard(
                heading: "No one to seed yet.",
                message: "Tournaments draw from Sycamore's ladder. Bring in the kids first.",
                actionTitle: "Bring in the kids"
            ) {}

            TournamentEmptyCard(
                heading: "No draws yet.",
                message: "Pick the groups, a format and the days — the order of play draws itself and plans around who's away.",
                actionTitle: "New tournament"
            ) {}
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, TournamentMetrics.listTop)
    }
    .background(Theme.surfaceWarm)
}

#Preview("Empty state — accessibility1") {
    ScrollView {
        TournamentEmptyCard(
            heading: "No draws yet.",
            message: "Pick the groups, a format and the days — the order of play draws itself and plans around who's away.",
            actionTitle: "New tournament"
        ) {}
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, TournamentMetrics.listTop)
    }
    .background(Theme.surfaceWarm)
    .environment(\.dynamicTypeSize, .accessibility1)
}
