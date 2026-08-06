//
//  PlayerHeader.swift
//  Sycamore
//
//  `8q`'s white header block: the way back, where the kid stands, the serif name, and who they are.
//
//  Its own view for the same reason `AttendanceHeader` is — it redraws on a different beat from the
//  list below it. Marking a kid away or booking a pick-up rebuilds the content column; up here only
//  the placement line can move, and it rarely does.
//

import SwiftUI

struct PlayerHeader: View {

    /// `Sycamore · Court 1 · Nass` — where the design writes `Group 1 · Court 1`. Same line, one
    /// more fact: this app's camps run several venues, so which one the kid is at is the part a
    /// coach cannot infer from the court number alone.
    let placement: String
    let name: String
    /// `Boy · 13 years`. Nil for a kid the camp has since dropped, which is the only way the name
    /// above is empty too.
    let whoTheyAre: String?
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The design closes this row with a pencil. Nothing in the app edits a kid — there is
            // no update-player intent and no screen to send one to — and a control with no
            // destination is the bell this navigation was built to replace.
            HStack(spacing: Spacing.tight) {
                backButton
                Text(placement)
                    .typeStyle(.onTheDayCrumb, color: Theme.inkMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            // The caret is drawn at the design's 20pt and centred in a 44pt frame, so 8pt here puts
            // it on the design's 22pt gutter without the hit region eating into the title below.
            // Same construction as `AttendanceHeader`, which is the same row on the same unit's
            // other screen.
            .padding(.horizontal, Spacing.small)

            OnTheDayTitle(name)
                .padding(.horizontal, Spacing.header)
                .padding(.top, OnTheDayTokens.headerTop)

            if let whoTheyAre {
                Text(whoTheyAre)
                    .typeStyle(.onTheDayLede, color: Theme.inkMuted)
                    .padding(.horizontal, Spacing.header)
                    .padding(.top, Spacing.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, OnTheDayTokens.headerBottom)
    }

    private var backButton: some View {
        Button(action: onBack) {
            DisclosureChevron(systemName: "chevron.left", size: 20, color: Theme.inkSecondary)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - Previews

#Preview("Header") {
    VStack(spacing: 0) {
        PlayerHeader(
            placement: "Sycamore · Court 1 · Nass",
            name: "Austin Z",
            whoTheyAre: "Boy · 13 years",
            onBack: {}
        )
        Hairline(color: Theme.hairline)
        Spacer(minLength: 0)
    }
    .background(Theme.surface)
    .frame(maxHeight: 260)
}
