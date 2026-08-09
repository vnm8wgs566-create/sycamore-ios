//
//  WarningPill.swift
//  Sycamore
//
//  A warning triangle and a word on an amber capsule — `Closed`, and `1 over`.
//
//  `8i`'s own, transcribed:
//
//      display:flex;align-items:center;gap:6px;background:#FAF6EC;border-radius:99px;padding:4px 10px
//      <i class="ph ph-warning" style="font-size:13px;color:#B67A16"></i>
//      <div style="font:600 11.5px 'Instrument Sans';color:#8A6416">Closed</div>
//
//  Two callers, and their own file headers each say the pair should read as siblings:
//  `CourtStatusBadge` draws it for a court out of play, and `CourtCapacityBadge` for one past its
//  ceiling. Those are the two things on this screen somebody has to do something about, and they
//  can appear on the *same header row* — a closed court that is also over — so any drift between
//  them lands side by side and an inch apart.
//
//  They had drifted already, in the half-point the design does not draw: `Closed` at `600 11.5`
//  and `1 over` at `600 11`. One row now, `OverviewTheme.closedBadge`, because the design sets one.
//
//  ── The label is the caller's, and so is what VoiceOver hears ────────────────────────────────
//
//  This draws and says nothing. `Closed` reads out as "This court is closed" and `1 over` is folded
//  into the head-count's own sentence ("9 of 8 kids. 1 over capacity") — two different claims that
//  happen to wear one plate, which is exactly the split a shared component should make. So the
//  triangle is hidden here and each caller wraps this in its own element.
//
//  Inert, both times. The design draws no way to close a court anywhere in section 8, and there is
//  no way to move a kid off an over-full one from this screen either; a pill that looks pressable
//  and is not lies to VoiceOver as well as to the eye.
//

import SwiftUI

struct WarningPill: View {

    let label: String

    /// 13 sits in the body band of the type table, so the glyph grows at the same rate as the word
    /// beside it — and, because both callers read this one metric, at the same rate as each other.
    @ScaledMetric(relativeTo: .body) private var glyphSize = OverviewTheme.badgeGlyph

    var body: some View {
        HStack(spacing: OverviewTheme.badgeGap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(Theme.warning)

            Text(label)
                .typeStyle(OverviewTheme.closedBadge, color: Theme.warningDark)
                .lineLimit(1)
        }
        .padding(.horizontal, OverviewTheme.badgeHorizontal)
        .padding(.vertical, OverviewTheme.badgeVertical)
        .background(Theme.warningTint, in: Capsule(style: .continuous))
    }
}

// MARK: - Previews

#Preview("Warning pills") {
    HStack(spacing: Spacing.medium) {
        WarningPill(label: "Closed")
        WarningPill(label: "1 over")
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
