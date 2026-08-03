//
//  CreateCampView.swift
//  Sycamore
//
//  Screen 4 — New camp. Two answers now: what it is called and what sport it plays. The
//  shape (venues, groups per venue) is a starting point, not a commitment — Setup owns it
//  from here on.
//

import SwiftUI

struct CreateCampView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        let view = VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)
            content
        }
        .background(Theme.grouped)
        .navigationBarBackButtonHidden(true)

        #if os(iOS)
        return view.toolbar(.hidden, for: .navigationBar)
        #else
        return view
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                CircleIconButton(systemName: "chevron.left", size: 40, tone: .filled) {
                    dismiss()
                }
                .padding(.bottom, Spacing.large)

                Text("New camp")
                    .typeStyle(.title2, color: Theme.ink)

                Text("Two answers now. Everything else lives in Setup and can change any day.")
                    .typeStyle(.bodyAlt, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.header)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    private var content: some View {
        @Bindable var store = store

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Name")
                nameField
                    .padding(.bottom, Spacing.section)

                SectionHeader("Sport")
                sportChips
                    .padding(.bottom, Spacing.section)

                SectionHeader("Shape")
                shapeCard
                    .padding(.bottom, Spacing.gutterWide)

                PrimaryButton("Create camp", height: 54, font: .button) {
                    isNameFocused = false
                    Task { await store.createCamp() }
                }
                .opacity(store.campDraft.isValid ? 1 : 0.45)
                .disabled(!store.campDraft.isValid)

                if let message = store.errorMessage {
                    Text(message)
                        .typeStyle(.footnote, color: Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Spacing.medium)
                }

                Text("You get an invite code to hand to your staff.")
                    .typeStyle(.footnote, color: Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.medium)
            }
            .padding(.horizontal, Spacing.gutterWide)
            .padding(.top, 20)
            .padding(.bottom, Spacing.hero)
        }
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
        .contentShape(Rectangle())
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

    // MARK: Shape

    private var shapeCard: some View {
        @Bindable var store = store

        return Card {
            CardRow(spacing: 10, horizontalPadding: Spacing.gutterWide, verticalPadding: Spacing.gutterWide) {
                stepperLabel("Venues", detail: "Sites or skill levels")
                Spacer(minLength: 0)
                StepperControl(value: $store.campDraft.venueCount, range: CampDraft.venueRange)
            }
            CardRow(spacing: 10, horizontalPadding: Spacing.gutterWide, verticalPadding: Spacing.gutterWide) {
                stepperLabel("Groups per venue", detail: "Courts, fields, lanes")
                Spacer(minLength: 0)
                StepperControl(value: $store.campDraft.groupsPerVenue, range: CampDraft.groupRange)
            }
        }
    }

    private func stepperLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .typeStyle(.bodyStrong, color: Theme.ink)
            Text(detail)
                .typeStyle(.meta, color: Theme.inkMuted)
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

#Preview("New camp") {
    let store = AppStore.previewCampPicker
    store.campDraft = CampDraft(name: "UCLA Tennis Camp", sport: .tennis, venueCount: 2, groupsPerVenue: 6)
    return NavigationStack {
        CreateCampView()
            .environment(store)
    }
    .showsMockStatusBar()
}

#Preview("New camp — empty") {
    NavigationStack {
        CreateCampView()
            .environment(AppStore.previewCampPicker)
    }
    .showsMockStatusBar()
}
