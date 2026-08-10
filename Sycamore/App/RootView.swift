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
                // ── THERE IS NO LOADING SCREEN HERE ANY MORE ──────────────────────────────────
                //
                // A full-screen seed fall used to lie over this whole branch whenever
                // `store.isWorking` was true. It was covering two different things and only one
                // of them was a wait.
                //
                // The wait is real: `AppStore.finishSignIn` sets `auth` to `.signedIn` and *then*
                // awaits the memberships, both inside the same `perform`, so for that moment the
                // account looks like it belongs to no camp — which is the condition
                // `FirstRunStep` reads as "new here". The seeds hid the wrong question rather
                // than stopping it being asked. That is fixed where it is caused now:
                // `hasLoadedMemberships` says whether the answer is known, and `FirstRunStep`
                // declines to answer until it is.
                //
                // The rest was not a wait at all. `isWorking` is raised by *every* intent
                // (`AppStore.perform`), so the seeds also fell for the write behind "That's me"
                // and for switching camps — writes that land faster than the animation starting
                // over them. That is the same reasoning that removed the "Working…" capsule
                // (`Components.swift:1092-1104`): a wait too short to read is a wait not worth
                // drawing, and one drawn at random reads as a fault.
                //
                // So the seeds are the entrance and nothing else now, which is where they came
                // from — see `SeedEntrance` and `SycamoreApp.swift:83`. Failure still speaks,
                // below; only the in-flight half went quiet.
                FirstRunView()
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            tab
            // Gone while a tab is in the middle of something a stray tap must not end — see
            // `AppStore.isFocused`. Dragging a kid down a Groups card ends the drag over the one
            // control that leaves the screen entirely, and the pill floats *over* the content
            // rather than reserving space beneath it, so there is nothing under a finger to warn
            // that it is there.
            //
            // Removed rather than disabled: a dimmed pill still says "you are on Groups, here is
            // Inbox", which is the wrong thing to be reading while aiming a row.
            if !store.isFocused {
                FloatingTabBar(selection: $store.selectedTab)
                    .padding(.bottom, Spacing.tabBarInset)
                    .transition(.opacity)
            }
        }
        .animation(Motion.fold(reduceMotion: reduceMotion), value: store.isFocused)
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

    /// ── Two tabs are held back, and their screens are still here ────────────────────────────
    ///
    /// `OverviewView` and `ScheduleView` are written, tested and passing. They are not drawn
    /// because the work they depend on — a camp whose days have a shape, blocks to hang on them —
    /// is not finished, and a tab that half-answers is worse than one that says it is not ready.
    /// So the tab bar keeps its four slots and two of them lead here.
    ///
    /// **They are not deleted, and that is the point of doing it this way.** Both screens keep
    /// compiling, keep their previews and keep their tests, so they cannot rot while they wait —
    /// which is exactly what happens to a screen parked on a branch while the model underneath it
    /// moves. Turning one back on is deleting a line. The full-fidelity state of both, before this
    /// gate, is the `parked/sections-4-5` branch.
    ///
    /// `AppTab.isReady` says the same thing in the routing enum, for anything that needs to ask
    /// without switching.
    @ViewBuilder
    private var tab: some View {
        switch store.selectedTab {
        case .overview:
            ComingSoonView(.overview) { store.selectedTab = .groups }
        case .schedule:
            ComingSoonView(.schedule) { store.selectedTab = .groups }
        case .groups:
            GroupsView()
        case .tournament:
            TournamentView()
        // Not in `AppTab.bar`, so nothing selects it — the design spends the fourth slot on
        // Tournament and reaches the inbox from a control instead. The case stays wired to the
        // real screen rather than to a plate, because `InboxView` works: it is out of the way,
        // not unfinished.
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
            case .campHome:
                // Presented bare: it owns a `NavigationStack` of its own and pushes the shape
                // page into it, the same arrangement `CampPickerView` and `CreateCampView`
                // already have. Wrapping it here would nest two stacks.
                CampHomeView(store: store)
            case .campSettings:
                SetupView(store: store)
            case .rank:
                RankView(store: store)
            case .firstSort(let venueID):
                // `4c`. The venue rides on the case rather than being read from
                // `store.readVenueID` inside the screen: the sort takes minutes and a venue chip
                // tapped on the tab underneath must not change which kids it is asking about.
                FirstSortView(venueID: venueID)
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
