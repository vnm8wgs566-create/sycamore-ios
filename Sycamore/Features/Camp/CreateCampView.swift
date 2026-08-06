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
//  per-court numbers are all editable from Camp settings any day of the week.
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
        .background(Theme.grouped)
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
                .padding(.bottom, Spacing.large)

                Text("Shape the camp")
                    .typeStyle(.title2, color: Theme.ink)

                Text("How many places you run, and how many \(courtNoun)s inside each. Both change any day from Camp settings.")
                    .typeStyle(.bodySmall, color: Theme.inkTertiary)
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
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Name")
                nameField
                    .padding(.bottom, Spacing.medium)

                SectionHeader("Sport")
                sportChips
                    .padding(.bottom, Spacing.medium)

                SectionHeader("Venues")
                venuesCard
                    .padding(.bottom, Spacing.medium)

                SectionHeader("Per \(courtNoun)")
                perCourtCard
                    .padding(.bottom, Spacing.gutterWide)

                PrimaryButton("Save the shape", height: 52, font: .button) {
                    saveTheShape()
                }
                .opacity(store.campDraft.isValid ? 1 : 0.45)
                .disabled(!store.campDraft.isValid)

                // No failure line here any more. This screen calls nothing that can fail —
                // creating the camp moved to the end of the flow, and the flow carries the
                // banner for it.
                Text("Next: add kids, then hand out the code.")
                    .typeStyle(.footnote, color: Theme.inkGhost)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.medium)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, Spacing.hero)
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

        return ZStack(alignment: .leading) {
            if store.campDraft.name.isEmpty {
                Text("UCLA Tennis Camp")
                    .typeStyle(.fieldTitle, color: Theme.inkFaint)
            }
            textField($store.campDraft.name)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: BorderWidth.input)
        }
        .contentShape(.rect)
        .onTapGesture { isNameFocused = true }
    }

    private func textField(_ text: Binding<String>) -> some View {
        let base = TextField("", text: text)
            .textFieldStyle(.plain)
            .typeStyle(.fieldTitle, color: Theme.ink)
            .focused($isNameFocused)
            .autocorrectionDisabled()

        #if os(iOS)
        return base
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return base
        #endif
    }

    // MARK: Sport

    private var sportChips: some View {
        WrappingRow(spacing: 7) {
            ForEach(Array(Sport.selectable.enumerated()), id: \.offset) { _, sport in
                Chip(
                    sport.chipTitle,
                    isSelected: store.campDraft.sport.matchesChip(sport),
                    metrics: .sport
                ) {
                    store.campDraft.sport = sport
                }
            }
        }
    }

    // MARK: Venues

    private var venuesCard: some View {
        Card {
            ForEach($shape.venues) { venue in
                venueRow(venue)
            }
            addVenueRow
            summaryRow
        }
    }

    private func venueRow(_ venue: Binding<VenueShape>) -> some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(Theme.color(for: venue.wrappedValue.tint))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "mappin")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.inkSecondary)
                }
                // The tile says "a place"; the row's own name says which one.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(venue.wrappedValue.name)
                    .typeStyle(.rowLabel, color: Theme.ink)
                Text(venue.wrappedValue.subtitle ?? "Name it later")
                    .typeStyle(.meta, color: Theme.inkMuted)
            }

            Spacer(minLength: 0)

            StepperControl(value: venue.courts, range: CampShape.courtRange, valueWidth: 28)
        }
        // The design draws no way to take a venue back off the list — Camp settings owns that
        // once the camp exists. But nothing exists yet here, so an accidental "Add a venue"
        // would otherwise follow you into the camp. The menu keeps the row exactly as drawn and
        // is in the VoiceOver actions rotor for free.
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

    private var addVenueRow: some View {
        Button {
            shape.addVenue()
        } label: {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Theme.accentTint)
                    .frame(width: 40, height: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .strokeBorder(
                                Theme.accentBorder,
                                style: StrokeStyle(lineWidth: BorderWidth.hairline, dash: [4, 3])
                            )
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Theme.accent)
                    }

                Text("Add a venue")
                    .typeStyle(.rowLabel, color: Theme.accent)

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
                .typeStyle(.sectionHeader, color: Theme.inkMuted)
            Spacer(minLength: 0)
            Text("no kids yet")
                .typeStyle(.meta, color: Theme.inkFaint)
        }
        .background(Theme.grouped)
    }

    // MARK: Per court

    private var perCourtCard: some View {
        Card {
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
                    .typeStyle(.bodyStrong, color: Theme.ink)
                Text(detail)
                    .typeStyle(.meta, color: Theme.inkMuted)
            }

            Spacer(minLength: 0)

            StepperControl(value: value, range: range, valueWidth: 34)
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
