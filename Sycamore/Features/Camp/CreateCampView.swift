//
//  CreateCampView.swift
//  Sycamore
//
//  `8b` — Shape the camp. The places you run and the courts inside each, before anything else.
//
//  The design asks two questions this screen has to ask first: what the camp is called, and
//  what it plays. Neither can be deferred — a camp is created by name, and the sport decides
//  whether the rest of the screen says courts, fields or lanes. So they sit above the shape,
//  in the order you would say them out loud, and the shape below is the design's, unchanged.
//
//  Nothing here is a commitment. The header says so, and it is true: venues, courts, both rates
//  and everything in the venue editor are editable from Camp settings any day of the week. They
//  are edited *here* because this is where the venues come into existence — a venue named, tinted
//  and bounded at setup is a venue that was never wrong, and by the time Camp settings can correct
//  it somebody has looked at the wrong row all week.
//
//  Tapping a venue opens `VenueShapeSheet`; swiping one left offers to take it back off the list.
//  Both are new and both replace something: the tile used to be a `Menu` of six emoji because a
//  grid "would not fit the row", and the row used to carry a `.contextMenu` "Remove" because a
//  long press was the only gesture going spare. The editor is where the grid fits, and a swipe is
//  the gesture the design has been drawing since screen 5 (`SwipeToDelete.swift:17-20`).
//
//  Saving does not create the camp. It hands the shape to `OnboardingFlowView`, which brings in
//  the week and writes the camp at the end of it — see that file for why the order is that way
//  round.
//

import SwiftUI

struct CreateCampView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    /// The shape as the design draws it — a row per venue with its own name, emoji, court count
    /// and head-count limits, plus the two camp-wide rates those limits are seeded from.
    /// `CampDraft` can hold none of that (one uniform `groupsPerVenue`, nothing per venue at all),
    /// so it is held here and written into the camp the moment there is one. See `CampShape`.
    @State private var shape = CampShape.initial()
    @State private var isBringingInTheWeek = false

    /// The venue whose editor is open. Presented from here rather than through `store.activeSheet`
    /// — see `VenueShapeSheet.swift:12-21` for why that slot is unreachable from this screen.
    @State private var editingVenue: VenueShape?

    /// Which row is showing its Remove, and which has a finger on it. One value shared by every
    /// row, so only one can be open (`SwipeToDelete.swift:56-64`).
    @State private var swipe = SwipeRevealState<VenueShape.ID>()

    var body: some View {
        // The whole frame on the phone, where bringing in the week is the whole job and a card
        // that can be swiped away mid-import is not; a sheet on the Mac, which has no cover. Both
        // halves of that, and the navigation bar this screen draws its own header instead of, are
        // `FullScreenPresentation`'s — the same two modifiers `RootView`, `ScheduleView` and the
        // enrolment flow reach for.
        screen
            .hidesNavigationBar()
            .fullScreenPresentation(isPresented: $isBringingInTheWeek) { flow }
    }

    private var screen: some View {
        VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)
            content
        }
        // `#F8F9F8`, which section 8 puts behind every screen in it — warmer than the `#F6F7F9`
        // the design this app shipped with used, and the reason its white cards read as paper.
        .background(Theme.surfaceWarm)
        .navigationBarBackButtonHidden(true)
    }

    /// What a group is called in this sport — "court", "field", "lane".
    private var courtNoun: String { store.campDraft.sport.groupNoun.lowercased() }

    private var flow: some View {
        OnboardingFlowView(shape: shape)
            // Sheets and covers are presented outside this view's hierarchy, so the store is
            // handed over explicitly — the same thing `MainTabView` does for its own sheets.
            .environment(store)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled) {
                    dismiss()
                }
                // The shared control draws a glyph and nothing else, so the label belongs to
                // whoever knows where the button goes.
                .accessibilityLabel("Back to your camps")
                // The disc is 36 and the button around it is 44, which would otherwise push the
                // title 4pt down and the disc 4pt right of where the design puts them. Saying
                // how big the row is leaves the touch overflowing and nothing moved.
                .frame(width: 36, height: 36)
                .padding(.bottom, Spacing.large)

                IntakeTitle("Shape the camp")

                Text("How many places you run, and how many \(courtNoun)s inside each. Both change any day from Camp settings.")
                    .typeStyle(.intakeLead, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, 20)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            // `gap:13px` between blocks, which is what the design's flex column runs on.
            VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
                block("Name") { nameField }
                block("Sport") { sportChips }
                block("Venues") { venuesCard }
                block("Every venue") { everyVenueCard }

                PrimaryButton(
                    "Save the shape",
                    height: OnboardingMetrics.ctaHeight,
                    radius: OnboardingMetrics.cardRadius,
                    font: .intakeButton
                ) {
                    saveTheShape()
                }
                .opacity(store.campDraft.isValid ? 1 : 0.45)
                .disabled(!store.campDraft.isValid)
                // `margin:2px 2px 0` — the button is inset a touch from the cards above it.
                .padding(.horizontal, Spacing.hairGap)
                .padding(.top, Spacing.hairGap)

                // No failure line here any more. This screen calls nothing that can fail —
                // creating the camp moved to the end of the flow, and the flow carries the
                // banner for it.
                Text("Next: add kids, then hand out the code.")
                    .typeStyle(.intakeFootnote, color: Theme.inkGhost)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, OnboardingMetrics.contentBottom)
        }
        // The name field has a return key, but a thumb already on the list is the faster way out.
        .scrollDismissesKeyboard(.interactively)
        // A row travelling sideways under a finger must not also have the list slide out from
        // under it. `GroupsView.swift:140` and `RankView.swift:116` make the same call for their
        // own drags.
        .scrollDisabled(swipe.isTracking)
        .sheet(item: $editingVenue) { venue in
            venueEditor(venue)
        }
    }

    /// Attached to the scroll view rather than to `screen`, which already carries the
    /// `fullScreenCover`: two presentation modifiers on one view is a shape SwiftUI has never
    /// promised to honour, and there is a whole view here to hang the second one on.
    private func venueEditor(_ venue: VenueShape) -> some View {
        VenueShapeSheet(
            venue: venue,
            shape: shape,
            courtNoun: courtNoun,
            onSave: { saved in
                if let index = shape.venues.firstIndex(where: { $0.id == saved.id }) {
                    shape.venues[index] = saved
                }
                editingVenue = nil
            },
            onRemove: canRemoveVenues
                ? {
                    shape.removeVenue(venue.id)
                    editingVenue = nil
                }
                : nil,
            onClose: { editingVenue = nil }
        )
    }

    /// A header and the card under it — one child of the design's 13pt column.
    private func block<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            IntakeSectionHeader(title)
            content()
        }
    }

    private func saveTheShape() {
        isNameFocused = false
        // Nothing may be on screen when the cover goes up. An editor still presented would meet
        // `fullScreenCover` mid-flight and the runtime would refuse the pair — "attempt to present
        // while already presenting" — leaving the button dead and no way to find out why.
        editingVenue = nil
        // The draft carries what it can of the shape now, so a failure to reach the end of the
        // flow still leaves the camp creatable from what was drawn here.
        store.campDraft = shape.applied(to: store.campDraft)
        isBringingInTheWeek = true
    }

    // MARK: Name

    private var nameField: some View {
        @Bindable var store = store

        let field = FormField(
            "UCLA Tennis Camp",
            text: $store.campDraft.name,
            label: "Camp name",
            metrics: .intakeCard,
            type: .intakeFieldTitle,
            focus: $isNameFocused
        )
        .autocorrectionDisabled()

        // Every one of these travels down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            .textContentType(.organizationName)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return field
        #endif
    }

    // MARK: Sport

    private var sportChips: some View {
        WrappingRow(spacing: 7) {
            ForEach(Sport.selectable, id: \.self) { sport in
                let isSelected = store.campDraft.sport.matchesChip(sport)
                Chip(sport.chipTitle, isSelected: isSelected, metrics: .sport) {
                    store.campDraft.sport = sport
                }
                // The shared chip draws the selection but does not say so, and "which sport"
                // is unanswerable by ear without it.
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: store.campDraft.sport)
    }

    // MARK: Venues

    private var venuesCard: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            ForEach(shape.venues) { venue in
                venueRow(venue)
            }
            addVenueRow
            summaryRow
        }
    }

    /// One venue is the fewest a camp can have, so the last row keeps both its swipe and its
    /// editor's Remove switched off rather than offering an action that would refuse.
    private var canRemoveVenues: Bool {
        shape.venues.count > CampShape.venueRange.lowerBound
    }

    /// Tile, name, subtitle, caret and a stepper — the design's row, plus the two ways in it
    /// never had.
    ///
    /// The `Button` deliberately ends before the stepper, which is exactly `SetupView.venueRow`'s
    /// shape (`:204-215`): the left of the row opens the editor, the stepper on the right is its
    /// own control and does not. The caret is where "opens the editor" stops.
    ///
    /// Three gestures were two too many. The tile used to be a `Menu` and the row used to carry a
    /// `.contextMenu`, so a tap, a long press and now a swipe would all have landed on the same
    /// 68pt of card — and a `.contextMenu`'s lift preview begins under a finger that is about to
    /// swipe. Both are gone: the six emoji live in the editor, where the design's grid actually
    /// fits, and `SwipeToDelete` puts "Remove" in the VoiceOver actions rotor exactly where the
    /// context menu had it. Keeping both would have offered "Remove Venue 1" in the rotor twice.
    private func venueRow(_ venue: VenueShape) -> some View {
        SwipeToDelete(
            id: venue.id,
            state: $swipe,
            actionLabel: "Remove \(venue.name)",
            onDelete: canRemoveVenues ? { shape.removeVenue(venue.id) } : nil
        ) {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
                Button {
                    editingVenue = venue
                } label: {
                    venueRowFace(venue)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the venue editor")

                IntakeStepper(
                    value: courtsBinding(for: venue.id),
                    range: CampShape.courtRange,
                    label: "\(courtNoun)s at \(venue.name)",
                    valueWidth: 28
                )
            }
        }
    }

    /// Everything the row's `Button` covers.
    ///
    /// The tile is a plain `IntakeIconTile` again. It was a `Menu` of six emoji on the argument
    /// that screen 11's grid "is a card's worth of height and would not fit the row" — which was
    /// true, and stopped being the question the moment the row grew an editor with room for it.
    /// The tile hides itself from VoiceOver because the name is read on the very next line.
    private func venueRowFace(_ venue: VenueShape) -> some View {
        HStack(spacing: Spacing.row) {
            IntakeIconTile(
                emoji: venue.icon,
                size: 40,
                // 21-on-44 is the design's ratio (`:276`); on this 40pt plate that is 19.
                glyphSize: 19,
                fill: Theme.color(for: venue.tint)
            )

            // Both lines hold to one. A name is eighty characters at most and the stepper on the
            // right is not giving any of its width up, so an unlimited row would grow to four
            // lines of it and push the card open. `SetupView.venueRow` clips the same two lines
            // for the same reason.
            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(venue.name)
                    .typeStyle(.intakeRowTitle, color: Theme.ink)
                    .lineLimit(1)
                Text(venue.subtitle ?? "Tap to name it")
                    .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.small)

            // `ph-caret-right` at `font-size:16px;color:#C7CBD2` (`design/Sycamore Flow.dc.html:278`),
            // which is `DisclosureChevron`'s own default twice over. Decorative: it says the row
            // opens something, and the hint on the button says what.
            DisclosureChevron()
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }

    /// A court count is a write to the whole row, not just to one field: `setCourts(_:for:)`
    /// re-derives that venue's ceiling and floor from the camp-wide rates, so a venue taken from
    /// six courts to eight does not keep a 48-kid ceiling it only ever had because it had six.
    private func courtsBinding(for id: VenueShape.ID) -> Binding<Int> {
        Binding(
            // The row this belongs to is on screen, so the lookup cannot miss; the fallback is
            // there because a `Binding` must return something, and the lower bound is the only
            // number that is in range whatever went wrong.
            get: { shape.venues.first { $0.id == id }?.courts ?? CampShape.courtRange.lowerBound },
            set: { shape.setCourts($0, for: id) }
        )
    }

    private var addVenueRow: some View {
        Button {
            shape.addVenue()
        } label: {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
                IntakeIconTile(
                    "plus",
                    size: 40,
                    glyphSize: 17,
                    fill: Theme.accentSurface,
                    border: Theme.accentBorder,
                    isDashed: true,
                    glyphColor: Theme.accent
                )

                Text("Add a venue")
                    .typeStyle(.intakeRowTitle, color: Theme.accent)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(shape.venues.count >= CampShape.venueRange.upperBound)
        .opacity(shape.venues.count >= CampShape.venueRange.upperBound ? 0.45 : 1)
    }

    /// `2 venues · 10 courts` and, until there is a roster, the honest right-hand side of it.
    private var summaryRow: some View {
        CardRow(spacing: 9, horizontalPadding: 13, verticalPadding: Spacing.row) {
            Text(shape.summaryLine(noun: courtNoun))
                .typeStyle(.intakeOverline, color: Theme.inkMuted)
            Spacer(minLength: 0)
            Text("no kids yet")
                .typeStyle(.intakeRowMeta, color: Theme.inkFaint)
        }
        // A row inside the card, one step warmer than the white above it.
        .background(Theme.surfaceRaised)
        .accessibilityElement(children: .combine)
    }

    // MARK: Every venue

    /// The two camp-wide rates, which write into every row rather than being read at the end.
    ///
    /// They used to be read: `venue(applying:)` multiplied them by each row's courts on the way to
    /// the camp, so a venue could not have a ceiling of its own. Now that it can, a rate nobody
    /// reads would be a card that quietly did nothing — so moving either stepper writes the number
    /// it implies into every venue, and the block is titled for what that does.
    ///
    /// That is what keeps the common case (every venue the same) at one stepper, leaves a
    /// per-venue override standing until somebody deliberately moves a camp-wide stepper whose own
    /// subtitle says it does this, and needs no third piece of state to remember which is which.
    private var everyVenueCard: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            rateRow(
                "Kids per \(courtNoun)",
                detail: "Sets every venue's ceiling",
                value: kidsPerCourtBinding,
                range: CampShape.kidsRange
            )
            rateRow(
                "Coaches per \(courtNoun)",
                detail: "Sets every venue's floor",
                value: coachesPerCourtBinding,
                range: CampShape.coachRange
            )
        }
    }

    /// Through the mutator rather than straight at `$shape.kidsPerCourt`: the write into every
    /// venue is the whole point of the row, and a binding that skipped it would leave the rate and
    /// the venues disagreeing with nothing on screen to say so.
    private var kidsPerCourtBinding: Binding<Int> {
        Binding(get: { shape.kidsPerCourt }, set: { shape.setKidsPerCourt($0) })
    }

    private var coachesPerCourtBinding: Binding<Int> {
        Binding(get: { shape.coachesPerCourt }, set: { shape.setCoachesPerCourt($0) })
    }

    private func rateRow(
        _ title: String,
        detail: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(title)
                    .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                Text(detail)
                    .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
            }

            Spacer(minLength: 0)

            IntakeStepper(value: value, range: range, label: title, valueWidth: 34)
        }
    }
}

// MARK: - Wrapping row

/// `flex-wrap: wrap` for a row of chips. At 402pt the five sport chips do not fit on one
/// line, and the design lets them break rather than shrink. File-private so it cannot
/// collide with a sibling feature's own flow layout.
private struct WrappingRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let rows = rows(of: subviews, in: width)
        guard !rows.isEmpty else { return CGSize(width: width, height: 0) }
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(rows.count - 1)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var y = bounds.minY
        for row in rows(of: subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var height: CGFloat = 0
    }

    private func rows(of subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.indices.isEmpty, x + size.width > width {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.indices.append(index)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Previews

#Preview("Shape the camp") {
    let store = AppStore.previewCampPicker
    store.campDraft = CampDraft(name: "UCLA Tennis Camp", sport: .tennis, venueCount: 2, groupsPerVenue: 6)
    return NavigationStack {
        CreateCampView()
            .environment(store)
    }
    .showsMockStatusBar()
}

#Preview("Shape the camp — empty") {
    NavigationStack {
        CreateCampView()
            .environment(AppStore.previewCampPicker)
    }
    .showsMockStatusBar()
}
