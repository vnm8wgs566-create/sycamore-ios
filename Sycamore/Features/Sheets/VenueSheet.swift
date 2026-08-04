//
//  VenueSheet.swift
//  Sycamore
//
//  Screen 11 — tap a venue name. Its status, what it is called, what it looks like, and the
//  limits the auto-partition works inside.
//

import SwiftUI

struct VenueSheet: View {
    let store: AppStore
    let venueID: Venue.ID

    /// Edits land here first so typing does not race the store round-trip; every change is
    /// pushed straight back out again by `onChange` below.
    @State private var draft: Venue

    @MainActor
    init(store: AppStore, venueID: Venue.ID) {
        self.store = store
        self.venueID = venueID
        _draft = State(initialValue: store.venue(venueID) ?? .placeholder)
    }

    var body: some View {
        SheetChrome(
            title: draft.name,
            subtitle: store.camp?.sheetSummary(for: venueID),
            detentFraction: ActiveSheet.venue(venueID).detentFraction,
            onClose: { store.dismissSheet() }
        ) {
            statusBanner
                .padding(.bottom, Spacing.large)

            SheetSectionHeader("Name", bottomPadding: Spacing.small)
            nameFields
                .padding(.bottom, 18)

            SheetSectionHeader("Icon")
            iconGrid
                .padding(.bottom, 18)

            SheetSectionHeader("Limits")
            limitsCard
        }
        .onChange(of: draft) { _, updated in
            Task { await store.updateVenue(updated) }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBanner: some View {
        if let status = store.camp?.staffingStatus(for: venueID) {
            InfoBanner(status.bannerText)
        }
    }

    // MARK: - Name

    private var nameFields: some View {
        VStack(spacing: 9) {
            SheetField(text: $draft.name, placeholder: "Venue name", style: .rowTitle, color: Theme.ink)
            SheetField(
                text: subtitleBinding,
                placeholder: "Subtitle, e.g. Higher level",
                // The design gives this field a plain `500 14px` — no line-height multiple.
                // `.bodyAlt`'s 1.5 is for wrapped copy; on a one-line field it only adds 7pt
                // of leading under a single line.
                style: .bodyAlt.lineHeight(nil),
                color: Theme.inkTertiary,
                verticalPadding: 12
            )
        }
    }

    /// The model stores an absent subtitle as nil; the field wants an empty string.
    private var subtitleBinding: Binding<String> {
        Binding(
            get: { draft.subtitle ?? "" },
            set: { draft.subtitle = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Icon

    private var iconGrid: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(Venue.iconOptions, id: \.self) { icon in
                IconTile(icon: icon, isSelected: draft.icon == icon) {
                    draft.icon = icon
                    // A venue's tile tint follows its emoji unless someone has said otherwise.
                    draft.tint = .suggested(for: icon)
                }
            }
        }
    }

    // MARK: - Limits

    private var limitsCard: some View {
        Card(radius: Radius.input, borderColor: Theme.strokeAlt) {
            LimitRow(title: "Groups", detail: "Courts in this venue") {
                StepperControl(
                    value: $draft.groupCount,
                    range: CampDraft.groupRange,
                    valueWidth: 34,
                    glyphSize: 14
                )
            }
            LimitRow(title: "Coaches, min – max", detail: "On site at once") {
                Text(draft.coachRangeLabel)
                    .typeStyle(.stepperValue, color: Theme.ink)
            }
            LimitRow(title: "Players, min – max", detail: "Auto-partition floor and ceiling") {
                Text(draft.playerRangeLabel)
                    .typeStyle(.stepperValue, color: Theme.ink)
            }
        }
    }
}

// MARK: - Field

/// A 1.5px-bordered text field at radius 13 — the sheet's input, distinct from `SearchField`'s
/// filled plate.
private struct SheetField: View {
    @Binding var text: String
    let placeholder: String
    let style: TypeStyle
    let color: Color
    var verticalPadding: CGFloat = 13

    var body: some View {
        field
            .padding(.horizontal, 13)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(Theme.strokeAlt, lineWidth: BorderWidth.input)
            )
    }

    private var field: some View {
        let base = TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.inkFaint))
            .textFieldStyle(.plain)
            .typeStyle(style, color: color)
            .autocorrectionDisabled()

        #if os(iOS)
        return base
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return base
        #endif
    }
}

// MARK: - Icon tile

/// 52pt square, radius 15. Selected takes the blue border and tint; the rest are white.
private struct IconTile: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                .fill(isSelected ? Theme.accentTint : Theme.surface)
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.strokeAlt,
                            lineWidth: BorderWidth.hairline
                        )
                )
                .overlay { Text(icon).font(.system(size: 23)) }
                .contentShape(RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Limits row

private struct LimitRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        CardRow(spacing: 10, horizontalPadding: 13, verticalPadding: 11) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .typeStyle(.rowLabel, color: Theme.ink)
                Text(detail)
                    .typeStyle(.rowSubtitleSmall, color: Theme.inkMuted)
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

// MARK: - Placeholder

private extension Venue {
    /// Only reachable if a sheet outlives the venue it was opened for. Keeps the sheet from
    /// having to model "no venue" in every subview.
    static let placeholder = Venue(
        name: "",
        subtitle: nil,
        icon: Venue.iconOptions[0],
        tint: .moss,
        groupCount: 1,
        coachMin: 0,
        coachMax: 0,
        playerMin: 0,
        playerMax: 0
    )
}

// MARK: - Previews

#Preview("Venue sheet") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        VenueSheet(store: .preview, venueID: SampleData.sycamore.id)
            .frame(height: 612)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Venue sheet — short on coaches") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        VenueSheet(store: .preview, venueID: SampleData.latc.id)
            .frame(height: 612)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
