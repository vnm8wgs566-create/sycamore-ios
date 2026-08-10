//
//  VenuePickerSheet.swift
//  Sycamore
//
//  `4b` — "Where are you today?". The sheet behind Overview's venue pill.
//
//  ── This is not `VenueSheet` ────────────────────────────────────────────────────────────────
//
//  `Features/Sheets/VenueSheet.swift` is screen 11: the venue **editor**, reached from Setup, where
//  an admin renames a venue, picks its emoji and sets its coach and player limits. It is presented
//  through `ActiveSheet.venue(Venue.ID)` and is about *one* venue's shape.
//
//  This is a picker. It is about which venue the reader is standing in, it writes
//  `AppStore.chosenVenueID`, and it names every venue in the camp. The two share a noun and nothing
//  else — folding them together would put "Where are you today?" above a form of steppers.
//
//  ── And it is the screen's own state, not an `ActiveSheet` case ─────────────────────────────
//
//  Held as `@State` on `OverviewScreen`, beside `assigningCoachTo` and `addingBlock`, and for the
//  argument those two already make (`OverviewScreen.swift`): `ActiveSheet` lives in the file every
//  feature merges, and a slot there is for a presentation the *root* owns — one screen's control
//  reached from one screen's header is not that. It also carries no id: it is about the camp rather
//  than about a venue, so `Identifiable` would need a literal id string, which is the shape of a
//  case that did not want to be one.
//
//  ── A bespoke plate rather than `SheetChrome` ───────────────────────────────────────────────
//
//  `SheetChrome` draws a ✕, a title row and an 18pt gutter. 4b draws none of the three: no close
//  disc (the grabber and the scrim are the ways out), a serif *question* rather than a title beside
//  a control, and a 16pt gutter. What it does share is the presentation — `sheetPresentation`'s
//  detent, hidden drag indicator and 24pt top radius — so this sheet arrives on screen exactly like
//  the four that already exist.
//
//      padding:10px 16px 28px;border-radius:24px 24px 0 0
//      box-shadow:0 -12px 40px rgba(11,11,12,.18)      -> `Shadows.sheetLift`
//      grabber: 36 × 5, #E4E5E9, margin:0 auto 14px    -> `Theme.stroke`
//
//  The grabber is drawn here rather than through `SheetGrabber`, which is `38 × 4` in
//  `Theme.grabber` with 9/2 of padding. Every other sheet in the app is calibrated on that one and
//  4b states its own; a shared primitive changed for one caller is how the other four drift.
//

import SwiftUI

struct VenuePickerSheet: View {

    let store: AppStore
    let onClose: () -> Void
    /// `8t`, for an admin. Nil draws the row locked — see `footer`.
    var onCampSettings: (() -> Void)?
    /// `8u` — "Your camps".
    let onYourCamps: () -> Void

    /// 20 sits in the title band, which is the largest thing on the row it closes.
    @ScaledMetric(relativeTo: .title3) private var checkSize = OverviewTheme.venueCheckGlyph

    private var camp: Camp? { store.camp }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber

            // `UCLA Tennis Camp · Tuesday`. The camp above the question, because the question is
            // about a venue and the camp is the thing that makes the list of them mean anything —
            // and because a reader with two camps on the account needs to know which one they are
            // switching venue inside before the footer offers to switch camp.
            if let camp {
                Text("\(camp.name) · \(store.today.fullName)")
                    .typeStyle(.rowDetail, color: Theme.inkMuted)
            }

            Text("Where are you today?")
                .typeStyle(OverviewTheme.sheetQuestion, color: Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.tight)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    venues
                    footer.padding(.top, OverviewTheme.sheetFooterGap)
                }
                .padding(.top, OverviewTheme.sheetListGap)
                .padding(.bottom, OverviewTheme.sheetBottom)
            }
            // A camp with two venues does not scroll and must not bounce as though it might.
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, OverviewTheme.sheetTop)
        // `padding:… 16px …`, not `Spacing.sheet`'s 18. Stated because the design states it: the
        // rows inside are cards with 13pt of their own, and two more points of gutter would push
        // the letter tiles off the rhythm the header block above sets at 22.
        .padding(.horizontal, OverviewTheme.sheetHorizontal)
        .background(Theme.surface)
        .clipShape(.rect(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet))
        // Invisible under a system sheet, which casts its own edge — drawn anyway, because this
        // plate is the design's own and the day it is presented some other way the cast is part of
        // it rather than something to work out again.
        .shadow(Shadows.sheetLift)
        .sheetPresentation(fraction: OverviewTheme.venueSheetDetent)
    }

    // MARK: The grabber

    /// `36 × 5` in `Theme.stroke`, centred, with 14 under it.
    private var grabber: some View {
        Capsule(style: .continuous)
            .fill(Theme.stroke)
            .frame(width: OverviewTheme.sheetGrabberWidth, height: OverviewTheme.sheetGrabberHeight)
            .frame(maxWidth: .infinity)
            .padding(.bottom, OverviewTheme.sheetGrabberGap)
            .accessibilityHidden(true)
    }

    // MARK: The venues

    /// Every venue in the camp, in the camp's own order.
    ///
    /// `orderedVenues` rather than `venues`, which carries no guaranteed order — the same trap
    /// `AppStore.readVenueID` records five screens having fallen into separately.
    private var venues: some View {
        VStack(spacing: OverviewTheme.cardGap) {
            ForEach(camp?.orderedVenues ?? []) { venue in
                VenueChoiceRow(
                    name: venue.name,
                    meta: meta(for: venue),
                    badge: shortfall(at: venue),
                    isSelected: venue.id == store.readVenueID,
                    checkSize: checkSize,
                    action: { select(venue.id) }
                )
            }
        }
    }

    /// `6 courts · 50 kids`, and `· you're on Court 1` where the reader has one here.
    ///
    /// The third clause only on the venue the reader is standing in, which is what the design
    /// draws and is also the only place it is true: `myCourtID` is one court at one venue, and
    /// naming it under a venue that does not contain it would be a sentence about somewhere else.
    /// It is nil for an admin, who is standing on all of them, so an admin's row is two clauses —
    /// exactly the unselected row's line, told apart by the tick and the border rather than by the
    /// copy.
    private func meta(for venue: Venue) -> String {
        guard let camp else { return "" }
        let summary = camp.venueSummary(for: venue.id)
        guard
            let courtID = store.myCourtID,
            let court = camp.group(courtID),
            court.venueID == venue.id
        else { return summary }
        return "\(summary) · you're on \(court.label)"
    }

    /// `2 short` — the amber badge beside a venue that is under its coach minimum.
    ///
    /// `StaffingStatus.badgeText` writes "2 coaches short", which is right on Setup's venue row
    /// where the badge is the only thing saying what is short. Here it sits inside a picker whose
    /// every row is a venue and whose whole subject is staffing this morning, and the design drops
    /// the noun. Composed here rather than adding a second speller to `StaffingStatus`, which lives
    /// in `Models.swift` and has a caller that wants the long form.
    ///
    /// Only the short case. `.coachesOver` is not somebody's problem before eight in the morning,
    /// and a picker that badged it would be spending amber — section 8's colour for "this needs
    /// looking at" — on a venue that is fine.
    private func shortfall(at venue: Venue) -> String? {
        guard case .coachesShort(let count) = camp?.staffingStatus(for: venue.id) else { return nil }
        return "\(count) short"
    }

    // MARK: The footer

    /// "Camp settings" and "Your camps" — the design's "camps behind the footer".
    ///
    /// `Card` divides its own rows, so the `border-top:1px solid #F2F3F6` between them arrives free
    /// and never above the first.
    ///
    /// **Camp settings stays locked for a non-admin**, where 4b draws it plain. That is not the
    /// design being overruled on a look: `8t` is admin-only and the enforcement that counts is the
    /// RLS policy behind it, so an unlocked row here would be a row that opens a screen the reader
    /// cannot write to. `ProfileView.swift:485-497` draws the same row the same way, and the two
    /// entrances to one screen must not disagree about who may use it.
    private var footer: some View {
        Card(radius: OverviewTheme.cardRadius) {
            SettingsRow(
                "Camp settings",
                icon: "slider.horizontal.3",
                subtitle: onCampSettings == nil ? store.adminsOnlyDetail : nil,
                accessory: onCampSettings == nil ? .lock : .chevron,
                action: onCampSettings
            )

            SettingsRow(
                "Your camps",
                icon: "arrow.left.arrow.right",
                // The verb, not the count. Profile writes "2 on this account" under "Manage &
                // switch camps"; 4b shortens the title to the destination's own name
                // (`CampPickerView.swift:102`) and spends the second line saying what may be done
                // there, which is the half a reader who has one camp still needs.
                subtitle: "Switch, join or start a camp",
                accessory: .chevron,
                action: onYourCamps
            )
        }
    }

    // MARK: Intents

    /// Picks the venue and closes.
    ///
    /// Closed first, then written. `selectVenue` empties `courts` and `scheduleBlocks` outright
    /// (`AppStore+SectionEight.swift:57-96`) and Overview's own `.task(id:)` is what reads the new
    /// venue back, so leaving the sheet up over the switch would hold a picker open above a screen
    /// visibly emptying itself.
    ///
    /// No `Task` around the write any more. It used to need one because `selectVenue` awaited a
    /// reload it no longer owns; a synchronous call puts the choice in on this turn of the runloop,
    /// which is the turn the dismissal above is on.
    private func select(_ venueID: Venue.ID) {
        onClose()
        store.selectVenue(venueID)
    }
}

// MARK: - One venue

/// A venue you might be standing in: a letter tile, its name, what is on it, and either a tick or
/// the word `Switch`.
///
/// Selected, it takes the treatment 4a moved off the court cards — `1.5px accentBorder` and
/// `OverviewTheme.yourCourtLift` — which is the same border meaning the same thing in both frames:
/// *this is the one*.
private struct VenueChoiceRow: View {

    let name: String
    /// `6 courts · 50 kids · you're on Court 1`.
    let meta: String
    /// `2 short`, or nil.
    var badge: String?
    let isSelected: Bool
    let checkSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            row
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The tick and the word `Switch` are the same fact drawn twice, so neither is spoken: the
    /// selected trait carries it, and a row that also said "Switch" out loud would offer VoiceOver
    /// a verb the row it is on has already performed.
    private var spokenLabel: String {
        [name, badge, meta].compactMap { $0 }.joined(separator: ". ")
    }

    private var row: some View {
        Card(
            radius: OverviewTheme.cardRadius,
            borderColor: isSelected ? Theme.accentBorder : Theme.hairline,
            borderWidth: isSelected ? BorderWidth.input : BorderWidth.hairline,
            isDivided: false
        ) {
            CardRow(
                spacing: OverviewTheme.venueRowGap,
                horizontalPadding: OverviewTheme.venueRowPadding,
                verticalPadding: OverviewTheme.venueRowPadding
            ) {
                VenueLetterTile(name)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: OverviewTheme.venueBadgeGap) {
                        Text(name)
                            .typeStyle(OverviewTheme.venueName, color: Theme.ink)
                            .lineLimit(1)

                        if let badge {
                            shortfallBadge(badge)
                        }
                    }

                    Text(meta)
                        // `#5C7A68` on the venue you are in, plain `inkMuted` on the ones you are
                        // not. The green-tinted grey is the border bleeding a fifth of the way into
                        // the line under it; on a row with no green border there is nothing for it
                        // to be following.
                        .typeStyle(.rowDetail, color: isSelected ? Theme.accentMeta : Theme.inkMuted)
                        .lineLimit(1)
                        .padding(.top, OverviewTheme.venueMetaGap)
                }

                Spacer(minLength: Spacing.small)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: checkSize, weight: .regular))
                        .foregroundStyle(Theme.accent)
                } else {
                    // A word, not a caret. The row does not open anything — it changes what every
                    // section-8 tab is about — and a caret would promise a screen behind it.
                    Text("Switch")
                        .typeStyle(OverviewTheme.statusPill, color: Theme.accent)
                }
            }
        }
        .shadow(
            color: isSelected ? OverviewTheme.yourCourtLift.color : .clear,
            radius: OverviewTheme.yourCourtLift.radius,
            y: OverviewTheme.yourCourtLift.y
        )
    }

    /// `600 11` in `warningDark` on `warningTint`, `padding:3px 8px`, pill.
    ///
    /// Deliberately not `Badge`, which is `700 9.5` uppercase and tracked (`Components.swift:1001`)
    /// — the one thing this section removes. `OverviewTheme.capacityPill` is already the `600 11`
    /// cut, drawn a card away in the same feature.
    private func shortfallBadge(_ text: String) -> some View {
        Text(text)
            .typeStyle(OverviewTheme.capacityPill, color: Theme.warningDark)
            .lineLimit(1)
            .padding(.horizontal, OverviewTheme.venueBadgeHorizontal)
            .padding(.vertical, OverviewTheme.venueBadgeVertical)
            .background(Theme.warningTint, in: Capsule(style: .continuous))
    }
}

// MARK: - Previews

#Preview("4b — venue sheet") {
    VenuePickerSheet(
        store: OverviewFixtures.adminStore,
        onClose: {},
        onCampSettings: {},
        onYourCamps: {}
    )
}

/// A coach, who is posted to a court — so the selected row gains its third clause — and who may
/// not open camp settings.
#Preview("4b — a coach reading it") {
    VenuePickerSheet(
        store: OverviewFixtures.coachStore,
        onClose: {},
        onYourCamps: {}
    )
}

#Preview("4b — accessibility1") {
    VenuePickerSheet(
        store: OverviewFixtures.adminStore,
        onClose: {},
        onCampSettings: {},
        onYourCamps: {}
    )
    .environment(\.dynamicTypeSize, .accessibility1)
}
