//
//  CourtStatusBadge.swift
//  Sycamore
//
//  Whether a court is in play. Two states, drawn very differently on purpose: a closed court
//  is a warning on an amber plate, and your own open court is a filled accent pill.
//
//      8i: gap:6px;background:#FAF6EC;border-radius:99px;padding:4px 10px
//          ph-warning 13px #B67A16 · font:600 11.5px #8A6416   "Closed"
//      8j: padding:7px 13px;border-radius:99px;background:#1A7F55
//          font:600 12.5px #fff                                "Open"
//
//  Both were a size larger before the frames were in the repository — a 14pt glyph on 6/12 of
//  padding, and the `Open` pill at 600 13 on 9/15 — which made a badge that sits *beside* a card's
//  head-count read as heavy as the head-count itself.
//
//  A status, not a control. The design draws no way to close a court anywhere in section 8 —
//  `setCourtStatus` exists on the repository and nothing yet calls it — and a pill that looks
//  pressable but is not lies to VoiceOver as well as to the eye. It stays inert until the
//  screen that closes a court is drawn. `CircleIconButton(action: nil)` makes the same call.
//

import SwiftUI

struct CourtStatusBadge: View {

    let status: CourtStatus
    /// Your own court says its status outright. Every other open court says nothing — a page
    /// of "Open" badges is noise, and the design only badges the one court that is yours and
    /// the one court that is shut.
    var isProminent: Bool = false

    @ViewBuilder
    var body: some View {
        switch status {
        case .open:
            if isProminent { openPill }
        case .closed:
            closedBadge
        }
    }

    private var openPill: some View {
        Text(status.badge)
            .typeStyle(OverviewTheme.statusPill, color: Theme.onAccent)
            .padding(.horizontal, OverviewTheme.statusPillHorizontal)
            .padding(.vertical, OverviewTheme.statusPillVertical)
            .background(Theme.accent, in: Capsule(style: .continuous))
            .accessibilityLabel("This court is open")
    }

    /// `WarningPill`, not a second drawing of it. `CourtCapacityBadge` puts the same amber capsule
    /// on the same header row when a court is past its ceiling, and the two had already drifted by
    /// half a point of type before they were held side by side.
    ///
    /// The words stay here, and so does what VoiceOver hears: the pill draws, this says what it
    /// means. "Closed" alone, read out after a court's name and its activity, is an adjective with
    /// nothing to attach to.
    private var closedBadge: some View {
        WarningPill(label: status.badge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("This court is closed")
    }
}

// MARK: - Previews

#Preview("Court status") {
    HStack(spacing: Spacing.medium) {
        CourtStatusBadge(status: .open, isProminent: true)
        CourtStatusBadge(status: .closed(reason: "Tom is on it"))
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
