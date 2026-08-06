//
//  CourtStatusBadge.swift
//  Sycamore
//
//  Whether a court is in play. Two states, drawn very differently on purpose: a closed court
//  is a warning on an amber plate, and your own open court is a filled accent pill.
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

    /// 14 sits in the body band of the type table, so the glyph grows at the same rate as the
    /// `Closed` beside it.
    @ScaledMetric(relativeTo: .body) private var glyphSize = OverviewTheme.badgeGlyph

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

    private var closedBadge: some View {
        HStack(spacing: OverviewTheme.badgeGap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(Theme.warning)
            Text(status.badge)
                .typeStyle(.chipSoft, color: Theme.warningDark)
        }
        .padding(.horizontal, OverviewTheme.badgeHorizontal)
        .padding(.vertical, OverviewTheme.badgeVertical)
        .background(Theme.warningTint, in: Capsule(style: .continuous))
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
