//
//  InboxNarrowedState.swift
//  Sycamore
//
//  A chip has narrowed the list to nothing while something is still waiting under another one.
//
//  Quiet, because the honest answer is "not under this chip", not "nowhere" — and it says how
//  many are hiding, because "2 things" is the difference between a reader who taps back to All
//  and one who assumes the morning is over.
//
//  The one state on this screen the design does not draw, which makes it the one place the
//  system view fits: there is no CSS to match, and `ContentUnavailableView` already knows where
//  an empty state sits, how it centres and how it behaves at the largest text sizes.
//

import SwiftUI

struct InboxNarrowedState: View {

    let filter: InboxFilter
    /// Unresolved asks, whatever the chips say.
    let waitingCount: Int

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Nothing under \(filter.title.lowercased())")
                    .typeStyle(InboxType.narrowedTitle, color: Theme.ink)
            } icon: {
                Image(systemName: "tray")
                    .foregroundStyle(Theme.glyph)
            }
        } description: {
            Text("^[\(waitingCount) thing](inflect: true) still waiting under All.")
                .typeStyle(InboxType.allClearBody, color: Theme.inkTertiary)
        }
    }
}

// MARK: - Previews

#Preview("Narrowed to nothing") {
    VStack(spacing: Spacing.section) {
        InboxNarrowedState(filter: .notes, waitingCount: 1)
        InboxNarrowedState(filter: .notes, waitingCount: 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.surfaceWarm)
}
