//
//  VenueSheet.swift
//  Sycamore
//
//  Screen 11 — tap a venue name. Its status, what it is called, what it looks like, and the
//  limits the auto-partition works inside.
//
//  Three of the pieces below it are no longer private, because "Shape the camp" grew an editor for
//  the same venue one screen earlier (`VenueShapeSheet`) and draws the same blocks of the same
//  drawing: `VenueNameFields` and `VenueLimitRow` live at the foot of this file, and the icon tile
//  moved out to `VenueIconTile.swift`. The box round the two fields went further still, to
//  `FormFieldMetrics.venueBox`, because that is where every other box in the app lives.
//
//  What is left here is what only a *created* venue has: a staffing banner, a stored tint to keep
//  in step with the emoji, and a live write on every keystroke. `VenueShapeSheet` has none of the
//  three, and its own header says why.
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
            VenueNameFields(name: $draft.name, subtitle: $draft.subtitle)
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

    // MARK: - Icon

    private var iconGrid: some View {
        VenueIconGrid(selected: draft.icon) { icon in
            draft.icon = icon
            // A venue's tile tint follows its emoji unless someone has said otherwise. This is
            // the whole of what `VenueShapeSheet` does not have to do — a `VenueShape`'s tint is
            // computed from the emoji, so there is no second field there to keep in step.
            draft.tint = .suggested(for: icon)
        }
    }

    // MARK: - Limits

    private var limitsCard: some View {
        Card(radius: Radius.input, borderColor: Theme.strokeAlt) {
            VenueLimitRow(title: "Groups", detail: "Courts in this venue") {
                StepperControl(
                    value: $draft.groupCount,
                    range: CampDraft.groupRange,
                    valueWidth: 34,
                    glyphSize: 14
                )
            }
            VenueLimitRow(title: "Coaches, min – max", detail: "On site at once") {
                Text(draft.coachRangeLabel)
                    .typeStyle(.stepperValue, color: Theme.ink)
            }
            VenueLimitRow(title: "Players, min – max", detail: "Auto-partition floor and ceiling") {
                Text(draft.playerRangeLabel)
                    .typeStyle(.stepperValue, color: Theme.ink)
            }
        }
    }
}

// MARK: - Name fields

/// A venue's name over its subtitle, 9pt apart, in the box screen 11 draws round both:
/// `1.5px #EAEBEE` at radius 13 (`design/Sycamore Flow.dc.html:477-478`).
///
/// Shared by the two venue editors — this one and `VenueShapeSheet`, which edits the same venue
/// one screen before it exists. Three pieces of that block were hoisted out of this file at once
/// (the box became `FormFieldMetrics.venueBox`, the tiles `VenueIconTile`, the limit rows
/// `VenueLimitRow`); leaving what they compose *into* duplicated would have kept the 9pt gap, the
/// subtitle's grey, the capitalisation rule and the empty-string-to-nil rule in two files each.
///
/// It owns its own focus, unlike `FormField`, which deliberately does not
/// (`FormField.swift:180-183`): the two screens that put a keyboard down before they act do it to
/// a field they hold themselves, and neither of them is this block.
struct VenueNameFields: View {
    @Binding var name: String
    /// Absent is nil in the model and "" in the field; the conversion is here so both callers
    /// cannot disagree about which an empty box means.
    @Binding var subtitle: String?

    @FocusState private var isNameFocused: Bool
    @FocusState private var isSubtitleFocused: Bool

    var body: some View {
        // The keyboard travels down the environment to both fields, which is why `FormField` does
        // not own it (`FormField.swift:20-25`). Capitalised words and no autocorrect: a venue is
        // a proper noun, and "LATC" is not a typo.
        let fields = VStack(spacing: 9) {
            FormField(
                "Venue name",
                text: $name,
                label: "Venue name",
                metrics: .venueBox,
                type: .rowTitle,
                focus: $isNameFocused
            )
            FormField(
                "Subtitle, e.g. Higher level",
                text: subtitleText,
                label: "Subtitle",
                metrics: .venueBox,
                // The design gives this field a plain `500 14px` — no line-height multiple.
                // `.bodyAlt`'s 1.5 is for wrapped copy; on a one-line field it only adds 7pt
                // of leading under a single line.
                type: .bodyAlt.lineHeight(nil),
                valueColor: Theme.inkTertiary,
                focus: $isSubtitleFocused
            )
        }
        .autocorrectionDisabled()

        #if os(iOS)
        return fields
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return fields
        #endif
    }

    private var subtitleText: Binding<String> {
        Binding(
            get: { subtitle ?? "" },
            set: { subtitle = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Limits row

/// A row of a venue's LIMITS card: what the number is, what it means, and the control that sets
/// it. `padding:11px 13px` with the title `700 14.5` over a `500 11.5` grey line
/// (`design/Sycamore Flow.dc.html:488`).
///
/// Shared with `VenueShapeSheet` rather than drawn twice, for the reason `Motion.swift:12` gives:
/// two features needing the same thing. Both are editors for the same venue drawn from the same
/// block of screen 11 — one before the camp exists and one after — so a row that drifted between
/// them would be the same card in two shapes.
///
/// Named `VenueLimitRow` rather than `LimitRow` on the way out of `private`, the same reason
/// `IconTile` became `VenueIconTile`: a bare `LimitRow` is a name three features could each want.
struct VenueLimitRow<Trailing: View>: View {
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
