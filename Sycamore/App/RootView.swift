//
//  RootView.swift
//  Sycamore
//
//  Routing, and nothing else. The three stages of the design map one-to-one onto the
//  store's auth state:
//
//      signedOut                  -> screen 1, Sign in
//      awaitingCode               -> screen 2, Verify
//      signedIn, no camp picked   -> screen 3, Which camp? (which pushes screen 4)
//      signedIn, camp loaded      -> screens 5–8 behind the floating tab bar
//
//  An account is a person, not a camp, so the camp is chosen *after* identity — which is
//  why `camp == nil` is a routing decision here and not a state inside the tabs.
//

import SwiftUI

// MARK: - Root

struct RootView: View {

    let store: AppStore

    var body: some View {
        stage
            // Half the feature views take the store through the environment
            // (`@Environment(AppStore.self)`) and half take it as an init argument, so the
            // root supplies both.
            .environment(store)
            .tint(Theme.accent)
    }

    @ViewBuilder
    private var stage: some View {
        switch store.auth {
        case .signedOut:
            SignInView()

        case .awaitingCode:
            VerifyView()

        case .signedIn:
            // Loading a camp is the one wait in the app big enough to fill the screen —
            // everything else is a row toggling. The seeds fall here rather than a spinner
            // sitting in the middle of nothing.
            if store.camp == nil && store.isWorking {
                SeedLoadingView(label: "Loading your camp")
                    .transition(.opacity)
            } else if store.camp == nil {
                // `CampPickerView` owns its own `NavigationStack` and pushes `CreateCampView`,
                // so it is presented bare rather than wrapped in a stack of ours.
                CampPickerView()
            } else {
                MainTabView(store: store)
            }
        }
    }
}

// MARK: - Tabs

/// Screens 5–8. Not a `TabView`: the design's tab bar is a pill that *floats over* the
/// content with the list scrolling underneath it, which a system tab bar cannot do. So the
/// selected tab's view fills the frame and `FloatingTabBar` sits on top of it.
///
/// Each tab pads its own scrolling content by `Spacing.tabBarClearance` (92pt — the bar's
/// height plus its 22pt inset plus a margin), so the last row always clears the pill. That
/// padding deliberately lives in the tabs rather than here: adding it again at this level
/// would double it, and `RankView` needs it inside its own coordinate space anyway.
struct MainTabView: View {

    @Bindable var store: AppStore

    var body: some View {
        ZStack(alignment: .bottom) {
            tab
            FloatingTabBar(selection: $store.selectedTab)
                .padding(.bottom, Spacing.tabBarInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.grouped)
        // Failure and in-flight state are surfaced once, here, rather than in each of the
        // four tabs. Everything behind the tabs — marking a kid away, committing a rank
        // order, partitioning, even-out, editing a venue or a staff member — reports through
        // `errorMessage`, and without this the row simply snapped back and said nothing.
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
        .storeWorkingIndicator(store.isWorking)
        .sheet(item: $store.activeSheet) { sheet in
            // A presented sheet covers the overlay above, so it carries its own copy.
            sheetView(for: sheet)
                .environment(store)
                .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
                .storeWorkingIndicator(store.isWorking)
        }
    }

    // MARK: The selected tab

    @ViewBuilder
    private var tab: some View {
        switch store.selectedTab {
        case .groups:
            GroupsView()
        case .rank:
            RankView(store: store)
        case .setup:
            SetupView(store: store)
        case .profile:
            // The design labels this tab "You"; `AppTab.title` does that translation.
            ProfileView(store: store)
        }
    }

    // MARK: Sheets

    /// Stage 3. Every sheet carries its own detent through `SheetChrome`, so there is
    /// nothing to configure at the presentation site.
    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .player(let playerID):
            PlayerSheet(store: store, playerID: playerID)
        case .earlyPickup(let playerID):
            EarlyPickupSheet(store: store, playerID: playerID)
        case .venue(let venueID):
            VenueSheet(store: store, venueID: venueID)
        case .staff(let staffID):
            StaffSheet(store: store, staffID: staffID)
        }
    }
}

// MARK: - Previews

#Preview("Root — sign in") {
    RootView(store: .previewSignedOut)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Root — verify") {
    RootView(store: .previewAwaitingCode)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Root — which camp?") {
    RootView(store: .previewCampPicker)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Root — signed in") {
    RootView(store: .preview)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Tabs — Setup") {
    let store = AppStore.preview
    store.selectedTab = .setup

    return MainTabView(store: store)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}
