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
//  Nothing here is a commitment. The header says so, and it is true: venues, courts and both
//  per-court numbers are all editable from Camp settings any day of the week. The venue emoji is
//  editable there too, but it is chosen here — this is where the venues come into existence, and
//  a tile picked at setup is a tile that was never wrong.
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

    /// The shape as the design draws it — a row per venue with its own court count, plus the
    /// two numbers that describe one court. `CampDraft` can hold none of that (one uniform
    /// `groupsPerVenue`, nothing about court size), so it is held here and written into the
    /// camp the moment there is one. See `CampShape`.
    @State private var shape = CampShape.initial()
    @State private var isBringingInTheWeek = false

    var body: some View {
        // `fullScreenCover` on the phone, where bringing in the week is the whole job and a card
        // that can be swiped away mid-import is not; `sheet` on the Mac, which has no cover.
        #if os(iOS)
        return screen
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $isBringingInTheWeek) { flow }
        #else
        return screen
            .sheet(isPresented: $isBringingInTheWeek) { flow }
        #endif
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
                block("Per \(courtNoun)") { perCourtCard }

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
            ForEach($shape.venues) { venue in
                venueRow(venue)
            }
            addVenueRow
            summaryRow
        }
    }

    private func venueRow(_ venue: Binding<VenueShape>) -> some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            iconMenu(venue)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(venue.wrappedValue.name)
                    .typeStyle(.intakeRowTitle, color: Theme.ink)
                Text(venue.wrappedValue.subtitle ?? "Name it later")
                    .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
            }

            Spacer(minLength: 0)

            IntakeStepper(
                value: venue.courts,
                range: CampShape.courtRange,
                label: "\(courtNoun)s at \(venue.wrappedValue.name)",
                valueWidth: 28
            )
        }
        // The design draws no way to take a venue back off the list — Camp settings owns that
        // once the camp exists. But nothing exists yet here, so an accidental "Add a venue"
        // would otherwise follow you into the camp. The context menu keeps the row exactly as
        // drawn and is in the VoiceOver actions rotor for free.
        //
        // It still is, now that the tile in the row is a menu of its own: the tile opens on a
        // tap and this opens on a long press, so the two never contend for the same gesture, and
        // by ear the tile is a labelled control on the row rather than an action of it.
        .contextMenu {
            if shape.venues.count > CampShape.venueRange.lowerBound {
                Button(role: .destructive) {
                    shape.removeVenue(venue.wrappedValue.id)
                } label: {
                    Label("Remove \(venue.wrappedValue.name)", systemImage: "trash")
                }
            }
        }
    }

    /// The venue's emoji on the venue's tint, and the six the design offers behind it.
    ///
    /// The tile used to be a generic pin: "the tile says 'a place'; the row's own name says which
    /// one." Two things changed. The design draws a venue's own emoji everywhere it draws a
    /// venue (`design/Sycamore Flow.dc.html:276`, `:281`, `:357`) and no pin anywhere — the pin
    /// came from `8t.html`, which is not in this repository and never has been. And a camp is set
    /// up here, so this is the screen on which choosing the emoji is worth anything at all; by
    /// the time Camp settings can change it the person has already looked at the wrong tile all
    /// week.
    ///
    /// Why a menu and not the design's grid: screen 11 draws the picker as six 52pt tiles
    /// (`:480-485`), which is a card's worth of height. Two or three of those stacked down a card
    /// that also holds a name, a subtitle and a stepper is not the card the design draws. Making
    /// the tile itself the control keeps the row exactly as drawn and still offers the same six,
    /// in the same order. `Menu` wrapped round a `Picker` is what `8g`'s "Leaves at" field
    /// already does (`EarlyPickupSheet.swift:196`) — it draws the selected mark and carries the
    /// VoiceOver "selected" trait without either being hand-drawn, and it is a plain button, so
    /// it is reachable by swipe rather than only in the actions rotor. The row's `.contextMenu`
    /// keeps "Remove": a long press and a tap are different gestures and both survive.
    ///
    /// The selection binds straight to `venue.icon` and nothing else is written. `VenueShape.tint`
    /// is computed from the emoji, so the plate is already the right colour by the time this
    /// returns — no second write to keep in step, and no `onChange` leaving one frame in which
    /// the tree sits on citron.
    private func iconMenu(_ venue: Binding<VenueShape>) -> some View {
        Menu {
            Picker("Icon", selection: venue.icon) {
                ForEach(Venue.iconOptions, id: \.self) { icon in
                    Text(icon).tag(icon)
                }
            }
        } label: {
            IntakeIconTile(
                emoji: venue.wrappedValue.icon,
                size: 40,
                // 21-on-44 is the design's ratio (`:276`); on this 40pt plate that is 19.
                glyphSize: 19,
                fill: Theme.color(for: venue.wrappedValue.tint)
            )
            // The plate is drawn at 40 and the design keeps it there; only what takes the touch
            // grows to 44, the same call the camp picker's Switch button makes.
            .intakeTouchTarget(inset: 2)
        }
        .buttonStyle(.plain)
        // The tile inside is hidden, so this is the only thing spoken here — and "Venue 1" is
        // already the next thing read, so the label names what the control changes rather than
        // repeating the venue.
        .accessibilityLabel("Icon for \(venue.wrappedValue.name)")
        .accessibilityValue(venue.wrappedValue.icon)
        .sensoryFeedback(.selection, trigger: venue.wrappedValue.icon)
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

    // MARK: Per court

    private var perCourtCard: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            perCourtRow(
                "Kids per \(courtNoun)",
                detail: "Auto-partition keeps inside this",
                value: $shape.kidsPerCourt,
                range: CampShape.kidsRange
            )
            perCourtRow(
                "Coaches per \(courtNoun)",
                detail: "Flags a \(courtNoun) as short",
                value: $shape.coachesPerCourt,
                range: CampShape.coachRange
            )
        }
    }

    private func perCourtRow(
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
