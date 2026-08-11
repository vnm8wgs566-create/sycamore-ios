//
//  CampShapePage.swift
//  Sycamore
//
//  "Shape the camp" — the page the Camp page's first row opens.
//
//  `showApp.html`'s `pageShape` block, drawn from `campTabVals().shapeVenues`
//  (`state1.js:950-961`): a card per venue carrying its initial, its name and the five facts that
//  are its shape — courts, groups, the target per group, the ages it takes, and who is coaching
//  it. Then a dashed card that adds another, and — while there are venues but no kids — the one
//  thing left to do about it.
//
//  **The chips are the screen.** Everything else here is a way to get at them: the whole point of
//  a shape page is that a person can see, at a glance and without opening anything, that LATC has
//  four courts split three ways with nobody standing on them. That is why the no-coach state is
//  the one thing drawn in amber (`#FBF2E2` / `#8A5E0F`, read through `Theme.warningTint` and
//  `Theme.warningDark`) — it is the only chip that is a problem rather than a fact.
//
//  Editing a venue goes through `store.present(.venue(id))` — `VenueSheet`, which is where a
//  venue's shape is already collected. This screen deliberately grows no editor of its own: two
//  places to set a court count is two places for it to be wrong.
//

import SwiftUI

struct CampShapePage: View {

    let store: AppStore

    /// What the back disc does. Nil dismisses whatever presented this — which, pushed onto
    /// `CampHomeView`'s stack, pops back to the camp page.
    private let onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// The enrolment flow, presented locally for the reason `SetupView.isImportingRoster`
    /// records: this screen is itself presented, so asking the presenter to raise the flow would
    /// open it behind this one.
    @State private var isImportingRoster = false

    /// Whether the add-a-venue sheet is up.
    ///
    /// The sheet, rather than a write followed by an editor. This used to call `store.addVenue()`
    /// first and present the *edit* sheet over whatever came back, which meant a mis-tap left a
    /// venue named "Venue 4" on the camp permanently — copying the previous venue's courts, groups
    /// and age band, showing up in the Groups chips, the Tournament chips and `venueSummary` — and
    /// there is no delete path for a created venue anywhere in the app. Closing that sheet with ✕
    /// discarded nothing, which is the one thing a ✕ is for.
    ///
    /// `VenueSheet`'s add mode exists precisely for this and writes once, on Add.
    @State private var isAddingVenue = false

    /// The design's `padding:14px 22px 18px`, less the 4pt the back disc's 44pt hit frame hangs
    /// above its 36pt circle.
    private let headerTop: CGFloat = 10
    private let headerBottom: CGFloat = 18

    /// The design's 44pt venue tile. Scaled, because it sits beside a name and a subtitle that
    /// are half again as tall at the reader's larger sizes, and a pinned tile reads as stuck to
    /// the top of the row.
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 44

    init(store: AppStore, onBack: (() -> Void)? = nil) {
        self.store = store
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let camp = store.camp {
                content(for: camp)
                if showsImportCTA(camp) { importCTA }
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .hidesNavigationBar()
        .fullScreenPresentation(isPresented: $isImportingRoster) { enrolmentFlow }
        .sheet(isPresented: $isAddingVenue) {
            VenueSheet(store: store) { isAddingVenue = false }
                .environment(store)
        }
    }

    // MARK: - Importing a roster

    @ViewBuilder
    private var enrolmentFlow: some View {
        if let venueID = store.camp?.orderedVenues.first?.id {
            EnrolmentFlowView(venueID: venueID) { isImportingRoster = false }
                .environment(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.small) {
                    CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled, action: goBack)
                        .accessibilityLabel("Back to the camp")
                        .frame(width: 36, height: 36)

                    // The camp's name as a caption beside the disc — the design's `campName`,
                    // saying what you are going back to rather than naming a control.
                    Text(store.camp?.name ?? "")
                        .typeStyle(.headerDetail, color: Theme.inkTertiary)
                        .lineLimit(1)
                        .accessibilityHidden(true)

                    Spacer(minLength: 0)
                }

                IntakeTitle("Shape the camp", style: .campPageTitle)
                    .padding(.top, Spacing.row)

                Text("Venues, courts and groups — change any of it later")
                    .typeStyle(.headerDetail, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.tight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, headerTop)
            .padding(.bottom, headerBottom)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    // MARK: - Body

    private func content(for camp: Camp) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                // No empty state. `Sycamore App.dc.html` draws zero venues as the empty list
                // plus the dashed card and nothing else (`showApp.html:391-411`) — the venue
                // rows are an `sc-for` that simply produces nothing, and the pinned CTA is
                // hidden too because `shapeCta` requires a venue.
                //
                // `VenueEmptyState` was transcribed faithfully from `Sycamore App Rebuild.dc.html`,
                // which draws a headline and a "what a venue holds" card here. The two design
                // documents disagree and the App file is the one of record, so the plate goes:
                // the dashed card already says "Add a venue · Name, courts, groups and coaches —
                // one sheet", which is the whole of what the teaching card was teaching.
                ForEach(camp.orderedVenues) { venue in
                    venueCard(venue, in: camp)
                }
                addVenueCard
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, Spacing.sheetFoot)
        }
    }

    // MARK: A venue

    private func venueCard(_ venue: Venue, in camp: Camp) -> some View {
        Card(radius: Radius.settingsCard, isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.medium) {
                    // The venue's initial rather than its emoji, which is `VenueLetterTile`'s
                    // whole argument: three tennis venues all choose 🎾, and a column of distinct
                    // letters is what makes this list scannable.
                    VenueLetterTile(venue.name, size: tileSize)

                    VStack(alignment: .leading, spacing: Spacing.hairGap) {
                        Text(venue.name)
                            .typeStyle(.intakeCampName, color: Theme.ink)
                            .lineLimit(1)
                        if let subtitle = venue.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .typeStyle(.intakeRowDetail, color: Theme.inkTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: Spacing.small)

                    Button {
                        store.present(.venue(venue.id))
                    } label: {
                        Text("Edit")
                            .typeStyle(.chipMedium, color: Theme.accent)
                            // Drawn with the design's 6pt of padding; only the region a thumb has
                            // to find grows to 44, and the negative padding puts the word back
                            // where the design has it.
                            .padding(Spacing.tight)
                            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                            .contentShape(.rect)
                            .padding(-Spacing.tight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(venue.name)")
                }

                Hairline(color: Theme.hairlineSoft)
                    .padding(.top, Spacing.row)

                chips(for: venue, in: camp)
                    .padding(.top, Spacing.row)
            }
            .padding(13)
        }
        // The card is one thing to a reader and should be one stop to VoiceOver: name, then its
        // shape, then the way to change it. Six separate chips swiped through one at a time is
        // the same information at six times the cost.
        .accessibilityElement(children: .contain)
    }

    /// Courts, groups, the target, the age band, and who is on it — the design's order, wrapped.
    ///
    /// `FlowLayout` rather than an `HStack`: five chips do not fit across a card inset by the
    /// 12pt gutter at the default type size, let alone the reader's larger ones.
    private func chips(for venue: Venue, in camp: Camp) -> some View {
        FlowLayout(horizontalSpacing: Spacing.tight, verticalSpacing: Spacing.tight) {
            // The noun follows the sport — a swim club reads "8 lanes".
            CampMetaChip(venue.courtCountLabel(noun: camp.sport.groupNoun.lowercased()))
            CampMetaChip(venue.groupCountLabel)
            CampMetaChip(venue.ageBand.label)
            if let target = venue.targetLabel {
                CampMetaChip(target)
            }
            coachChip(for: venue, in: camp)
        }
    }

    /// `Dana R + Maya K`, or the amber that is the only warning on this screen.
    ///
    /// Amber rather than red on purpose: a venue with no coach is somebody's problem this
    /// morning, not a thing that is broken — which is the whole reason `Theme.warning` exists as
    /// a step between "fine" and "destructive".
    @ViewBuilder
    private func coachChip(for venue: Venue, in camp: Camp) -> some View {
        let coaches = camp.coaches(in: venue.id).map(\.name)
        if coaches.isEmpty {
            CampMetaChip("No coaches yet", tone: .warning)
        } else {
            CampMetaChip(coaches.joined(separator: " + "))
        }
    }

    // MARK: Adding one

    /// `background:#fff;border:1.5px dashed #C3DFCF;border-radius:16px` — the same dashed plate
    /// `CampPickerView`'s "Start a camp" and `RunningOrJoiningView` draw, down to the dash
    /// pattern: CSS renders a 1.5px dash at roughly three times its width per dash and gap.
    private var addVenueCard: some View {
        Button(action: addVenue) {
            HStack(spacing: Spacing.medium) {
                IntakeIconTile(
                    "plus",
                    size: 44,
                    glyphSize: 19,
                    fill: Theme.accentSurface,
                    border: Theme.accentSurfaceBorder,
                    glyphColor: Theme.accent
                )

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text("Add a venue")
                        .typeStyle(.intakeCampNameSm, color: Theme.accent)
                    Text("Name, courts, groups and coaches — one sheet.")
                        .typeStyle(.intakeRowMeta, color: OnboardingTheme.startCampSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, Spacing.gutterWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Radius.settingsCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.settingsCard, style: .continuous)
                    .strokeBorder(
                        Theme.accentBorder,
                        style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Opens the editor. Nothing is written until Add is pressed inside it.
    ///
    /// This used to `await store.addVenue()` and *then* present the edit sheet over the row that
    /// came back — a venue on the camp before the reader had seen a single field, named by its
    /// position and seeded from the previous venue's numbers. Backing out of that sheet left it
    /// there for good: `grep removeVenue` finds only `CampShape.removeVenue`, which is form state
    /// on the create-a-camp screen and never touches a camp that exists.
    ///
    /// `VenueSheet`'s add mode seeds the same defaults from the same template, so pressing Add
    /// without touching a stepper still produces exactly the venue the old path produced — it just
    /// asks first. See `VenueSheet.init(store:onClose:)`.
    private func addVenue() {
        isAddingVenue = true
    }

    // MARK: The one thing left to do

    /// `shapeCta` — venues but no kids. The camp has a shape and nothing to put in it, so the
    /// screen says the next thing out loud rather than leaving it to be found.
    ///
    /// Admin besides, which the prototype has no notion of: an import deals every kid in the camp
    /// onto courts, and `8t` gates the same control on the same permission.
    private func showsImportCTA(_ camp: Camp) -> Bool {
        !camp.venues.isEmpty && camp.playerCount == 0 && store.isAdmin
    }

    private var importCTA: some View {
        VStack(spacing: Spacing.small) {
            PrimaryButton("Bring in the kids") { isImportingRoster = true }
                // `box-shadow:0 10px 26px rgba(26,127,85,.24)` — the same accent-tinted lift `8d`
                // and `8e` give their pinned call to action, and the same token.
                .shadow(OnboardingShadows.pinnedCTA)

            Text("Import deals every kid into your groups.")
                .typeStyle(.intakeRowMeta, color: Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.gutter)
        // `padding:0 12px 24px`. Pinned under the scroll view rather than floating over it — the
        // design draws it as a `flex:none` sibling, and a button laid over a list of cards would
        // cover the last venue's chips, which are the thing this screen exists to show.
        .padding(.bottom, Spacing.hero)
        .padding(.top, Spacing.small)
        .background(Theme.surfaceWarm)
    }

    private func goBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Shape the camp") {
    let store = AppStore.previewUCLAAdmin

    return CampShapePage(store: store)
        .environment(store)
        .showsMockStatusBar()
}

/// A camp with venues and nobody in them: the amber chip on every card, and the pinned
/// "Bring in the kids" underneath. Both states this screen has that the populated one does not.
#Preview("Shape the camp — no kids, no coaches") {
    let store = AppStore.previewUCLAAdmin
    store.camp?.players = []
    store.camp?.staff = []

    return CampShapePage(store: store)
        .environment(store)
        .showsMockStatusBar()
}

/// No venues at all — `8b Shape the camp — empty`, which `VenueEmptyState` draws.
#Preview("Shape the camp — no venues") {
    let store = AppStore.previewUCLAAdmin
    store.camp?.venues = []
    store.camp?.groups = []
    store.camp?.players = []

    return CampShapePage(store: store)
        .environment(store)
        .showsMockStatusBar()
}
