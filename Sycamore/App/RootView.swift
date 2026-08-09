//
//  RootView.swift
//  Sycamore
//
//  Routing, and nothing else. The three stages of the design map one-to-one onto the
//  store's auth state:
//
//      signedOut                  -> screen 1, Sign in
//      awaitingCode               -> screen 2, Verify
//      signedIn, no camp picked   -> the first run, ending at screen 3 (which pushes screen 4)
//      signedIn, camp loaded      -> screens 5–8 behind the floating tab bar
//
//  An account is a person, not a camp, so the camp is chosen *after* identity — which is
//  why `camp == nil` is a routing decision here and not a state inside the tabs.
//
//  That third line used to read "screen 3, Which camp?" and went straight there. It is
//  `FirstRunView` now, because `camp == nil` covers two people who need different things:
//  somebody switching between camps they already have, and somebody who has just signed up and
//  has neither a camp nor a name on their account. The first still gets screen 3 and nothing
//  else; the second is asked for a name and then which way in. Which of those it is stays a
//  decision made from the store rather than a flag — see `FirstRunStep`.
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
            if store.camp == nil {
                // `FirstRunView` ends at `CampPickerView`, which owns its own `NavigationStack`
                // and pushes `CreateCampView`, so neither is wrapped in a stack of ours.
                //
                // The seeds go *over* it, never in place of it. `CampPickerView` owns
                // `.task { loadMemberships() }`, so swapping it out for the loading view
                // unmounts the view whose task is doing the loading — the task is cancelled,
                // `isWorking` never clears, and the app sits on the seed screen for ever.
                // Overlaying keeps it mounted and the load runs to completion.
                //
                // The overlay covers the whole of the first run rather than only the picker, and
                // that turns out to be load-bearing twice over. `AppStore.finishSignIn` sets
                // `auth` to `.signedIn` and *then* awaits the memberships, both inside the same
                // `perform` — so for that moment the account looks like it belongs to no camp,
                // which is the condition `FirstRunStep` reads as "new here". `isWorking` is true
                // for the whole of it, so what is on screen is the seed fall and not a flash of
                // the wrong question. It also covers the write behind the name question.
                //
                // The "Working…" capsule that used to float over every write is gone; this
                // overlay is not, and neither is the flag behind it. Waiting for a whole camp
                // to arrive is the one wait long enough to be worth drawing.
                FirstRunView()
                    .overlay {
                        if store.isWorking {
                            SeedLoadingView(label: "Loading your camp")
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: store.isWorking)
                    // The first run asks for a name, and asking for a name means a write that can
                    // fail. Screen 3 prints `errorMessage` inline in its own content
                    // (`CampPickerView.swift:140`), which covered this branch for as long as it
                    // *was* screen 3 — and screen 3 is the one step of the three that asks for
                    // nothing. Without this, "That's me" on a bad connection leaves the screen
                    // sitting still and saying nothing, so the person taps it again.
                    .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
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
        // Failure is surfaced once, here, rather than in each of the four tabs. Everything
        // behind the tabs — marking a kid away, committing a rank order, partitioning,
        // even-out, editing a venue or a staff member — reports through `errorMessage`, and
        // without this the row simply snapped back and said nothing.
        //
        // Failure only: a "Working…" capsule used to hang beside this for the in-flight half.
        // `perform` still sets `isWorking`; nothing floats it — see `storeErrorBanner`.
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
        .sheet(item: $store.activeSheet) { sheet in
            // A presented sheet covers the overlay above, so it carries its own copy.
            sheetView(for: sheet)
                .environment(store)
                .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
        }
        // One slot, two presentations — see `Binding.presenting(fullScreen:)`. The cover half goes
        // through `fullScreenPresentation`, which is where the iOS-only `fullScreenCover` and its
        // macOS stand-in now live for all three of the app's covers.
        .sheet(item: $store.pushedScreen.presenting(fullScreen: false), content: pushedView)
        .fullScreenPresentation(item: $store.pushedScreen.presenting(fullScreen: true), content: pushedView)
    }

    // MARK: The selected tab

    @ViewBuilder
    private var tab: some View {
        switch store.selectedTab {
        case .overview:
            OverviewView()
        case .schedule:
            ScheduleView()
        case .groups:
            GroupsView()
        case .inbox:
            InboxView()
        }
    }

    // MARK: Pushed screens

    /// `8m`, `8q`, `8s`, `8t`, the court a caret on `8i`/`8j` opens — and Rank until Groups
    /// absorbs it.
    ///
    /// A `NavigationStack` push is wrong for all of them: this app's tab bar is an overlay in this
    /// view rather than a `TabView`'s own chrome, so a push slides underneath it and leaves the
    /// pill floating over Profile.
    ///
    /// Which modal each gets is `PushedScreen.isFullScreen`'s call, and it turns on one thing —
    /// whether the screen draws its own way out. Profile, Camp settings and Rank were tabs and a
    /// tab needs no way out of itself, so as covers they would be screens you cannot leave; the
    /// sheet is what supplies their dismissal. `8m` and `8q` draw a ✕ and a back caret, and the
    /// court screen draws `8q`'s, so all three take the whole frame the design gives them.
    ///
    /// The store and the banner are carried in here rather than at each presentation site: a
    /// modal covers the one `MainTabView` floats, so it needs a copy of its own.
    @ViewBuilder
    private func pushedView(for screen: PushedScreen) -> some View {
        SwiftUI.Group {
            switch screen {
            case .profile:
                ProfileView(store: store)
            case .campSettings:
                SetupView(store: store)
            case .rank:
                RankView(store: store)
            case .attendance(let groupIDs, let block):
                AttendanceView(groupIDs: groupIDs, block: block) { store.pushedScreen = nil }
            case .player(let playerID):
                PlayerScreen(store: store, playerID: playerID)
            case .court(let groupID):
                CourtScreen(store: store, groupID: groupID)
            }
        }
        .environment(store)
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
    }

    // MARK: Sheets

    /// Stage 3. Every sheet carries its own detent through `SheetChrome`, so there is
    /// nothing to configure at the presentation site.
    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .venue(let venueID):
            VenueSheet(store: store, venueID: venueID)
        case .staff(let staffID):
            StaffSheet(store: store, staffID: staffID)
        }
    }
}

// MARK: - Presenting `8m` and `8q`

private extension Binding where Value == PushedScreen? {
    /// One half of `store.pushedScreen`, for one of the two modifiers that present it.
    ///
    /// `8m` and `8q` want the whole frame and the other three want a sheet, but there is a single
    /// slot to drive both from — and `.sheet(item:)` and `.fullScreenCover(item:)` each insist on
    /// an optional of their own. Handing both the same one presents two screens for one value.
    ///
    /// So each takes a filtered view of the slot: it reads only the screens it is responsible for,
    /// and on dismissal it empties the slot only when what is in there is still its own. Written as
    /// a `Binding` transform rather than a pair of mirrored `@State` properties, which would be two
    /// more places for "which screen is up" to be wrong.
    func presenting(fullScreen: Bool) -> Binding<PushedScreen?> {
        Binding<PushedScreen?>(
            get: {
                guard let screen = wrappedValue, screen.isFullScreen == fullScreen else {
                    return nil
                }
                return screen
            },
            set: { screen in
                if screen != nil || wrappedValue?.isFullScreen == fullScreen {
                    wrappedValue = screen
                }
            }
        )
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

/// The other half of the same auth state, and the one the root used to draw as screen 3: an
/// account with no name and no camps, which is everybody on their first run.
#Preview("Root — first run") {
    let store = AppStore(repository: InMemoryRepository(memberships: []))
    var account = SampleData.account
    account.displayName = ""
    store.auth = .signedIn(account)

    return RootView(store: store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Root — signed in") {
    RootView(store: .preview)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Tabs — Schedule") {
    let store = AppStore.preview
    store.selectedTab = .schedule

    return MainTabView(store: store)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Pushed — Camp settings") {
    let store = AppStore.preview
    store.pushedScreen = .campSettings

    return MainTabView(store: store)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

/// The other half of the split: a screen that takes the whole frame rather than a sheet. Worth a
/// preview of its own — the two are driven by one optional and a filter between them, so "the
/// right one presented" is the thing that can break.
#Preview("Pushed — A kid") {
    let store = AppStore.preview
    store.pushedScreen = .player(SampleData.austinZ.id)

    return MainTabView(store: store)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

/// The newest of the covers, and the one reached by a control rather than by an avatar: the caret
/// on an Overview card. Worth its own preview for the same reason the kid's is — one optional
/// drives two modifiers, and "the right one presented" is what breaks.
#Preview("Pushed — A court") {
    let store = OverviewFixtures.courtStore
    store.pushedScreen = .court(OverviewFixtures.drills.id)

    return MainTabView(store: store)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}
