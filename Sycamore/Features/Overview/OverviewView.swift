//
//  OverviewView.swift
//  Sycamore
//
//  `8i` / `8j` — Overview. "Every court, its coach and its kids."
//
//  The first tab, and the one the app opens on: on a camp morning the question is which courts
//  are running, who has them and how many kids are there. The design draws it two ways — an
//  admin sees every court in order, a coach sees their own court first under "Your court" with
//  the rest below under "Other courts".
//
//  Scaffolded, not built. The header and the tab are real so the four-tab shell can be walked
//  end to end; the body arrives with the rest of section 8's screens. It is deliberately honest
//  about that rather than drawing a plausible-looking fake — the court data it needs comes from
//  the `today_courts` view, and nothing in the app talks to Postgres yet.
//

import SwiftUI

struct OverviewView: View {

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            ScreenHeader(title: "Overview", initials: store.avatarInitials) {
                store.pushedScreen = .profile
            }

            Hairline(color: Theme.hairline)

            ContentUnavailableView {
                Label("Courts arrive here", systemImage: "rectangle.grid.2x2")
            } description: {
                Text("Every court, its coach and its kids — in order, with the one you are on first.")
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
    }
}

// MARK: - Previews

#Preview("Overview") {
    OverviewView()
        .environment(AppStore.preview)
        .showsMockStatusBar()
}
