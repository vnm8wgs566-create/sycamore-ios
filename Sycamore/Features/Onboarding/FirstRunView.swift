//
//  FirstRunView.swift
//  Sycamore
//
//  Everything between signing in and standing in a camp.
//
//  `RootView` used to put screen 3 here directly, which was right for the only case it knew about
//  — a returning coach choosing which of their camps they are working today — and wrong for
//  everybody arriving for the first time. What is asked now, and in this order:
//
//      no name on the account   -> `YourNameView`
//      camps not arrived yet    -> nothing at all, on a held frame
//      no camps on the account  -> `RunningOrJoiningView`, and then whichever way they chose
//      otherwise                -> screen 3, exactly as before
//
//  Which of those is on screen is `FirstRunStep`'s decision, and it is a rule read off the store
//  rather than a cursor this view walks. See that file: the short of it is that a derived step
//  cannot get out of step with the account it is about, so a name that failed to save leaves the
//  question up — with `RootView`'s banner over it (`RootView.swift:80-86`) — and nothing here has
//  to know that.
//
//  The second line is the new one, and it is the whole reason this branch no longer needs a
//  loading screen over it. See `HeldFrame` at the foot of this file.
//
//  ---------------------------------------------------------------------------------------------
//  THE TWO WAYS OUT ARE NOT PRESENTED THE SAME WAY, AND THAT IS ON PURPOSE
//  ---------------------------------------------------------------------------------------------
//
//  "I've been given a code" lands on screen 3, which owns its own `NavigationStack` and is
//  presented bare. "I'm running one" pushes `8b Shape the camp`, which draws a back disc and
//  calls `dismiss()` (`CreateCampView.swift:122-127`) — so it has to be *pushed* onto a stack
//  belonging to something, or that disc is a control that does nothing. The stack is here, the
//  question is its root, and backing out of `8b` lands on the question again.
//
//  Presenting `8b` as the root of a stack of its own was the alternative and it is the trap: a
//  root has nothing to pop to, so the back disc would draw and refuse.
//
//  One wart, recorded rather than papered over: that disc's VoiceOver label reads "Back to your
//  camps", which is screen 3's name for where it came from and is not where it goes from here.
//  It belongs to `CreateCampView` and is not this branch's file to edit.
//

import SwiftUI

struct FirstRunView: View {

    @Environment(AppStore.self) private var store

    /// Which way in they chose. The one answer nothing in the store records — creating and
    /// joining both leave the account exactly as it was until the camp exists — so it is the one
    /// thing here that has to be remembered rather than derived.
    ///
    /// Discarded when this view goes away, which is the correct lifetime: the moment a camp
    /// loads, `RootView` swaps in the tabs and there is no first run left to be in the middle of.
    /// "Not now" on the name question. Session-only, deliberately — see `FirstRunStep`.
    @State private var isNameSkipped = false

    /// Whether the load below has been and gone. Not a copy of anything the store holds: it is
    /// this view's record of its own task finishing, which is the one thing the store cannot
    /// report — see `campList`.
    @State private var hasStoppedWaiting = false

    private var step: FirstRunStep {
        FirstRunStep.resolve(
            displayName: store.account?.displayName ?? "",
            isNameSkipped: isNameSkipped,
            campList: campList,
            hasCamps: !store.memberships.isEmpty
        )
    }

    /// How far the memberships have got, in the three states the rule is written against.
    ///
    /// `store.hasLoadedMemberships` supplies the first two on its own: it is raised by a fetch that
    /// returned, so while it is down the list is still coming. The third it cannot supply.
    /// `loadMemberships()` reports a failed fetch through `errorMessage` rather than by throwing,
    /// so a fetch that fails leaves the flag down exactly as a fetch still in the air does — and a
    /// flow that could not tell those apart would hold an empty page for ever, under a banner the
    /// reader is free to dismiss.
    ///
    /// So the task below records that it has been and gone, and that is what turns "still coming"
    /// into "did not come". Checked in this order on purpose: a late success still wins, so a
    /// failed retry racing a good fetch from `finishSignIn` settles on the good one.
    ///
    /// The store is the right home for this and cannot have it here — `hasLoadedMemberships` is
    /// raised on success rather than on conclusion, and `AppStore` belongs to another change in
    /// flight. Recorded as a bandaid: a three-state on the store would delete this property, the
    /// `@State` behind it, and the retry it times.
    private var campList: FirstRunStep.CampList {
        if store.hasLoadedMemberships { return .arrived }
        return hasStoppedWaiting ? .failed : .pending
    }

    var body: some View {
        // `SwiftUI.Group` because `Group` is this app's own model type. It is here so the task
        // below belongs to the flow rather than to whichever question is currently drawn — a task
        // on the `.name` case would be cancelled the moment the name was answered.
        SwiftUI.Group {
            switch step {
            case .notYet:
                HeldFrame()

            case .name:
                YourNameView(
                    currentName: store.account?.displayName ?? "",
                    email: store.account?.email ?? "",
                    onSave: save,
                    onSkip: { isNameSkipped = true }
                )

            case .camps:
                // Bare, without a stack of ours: screen 3 owns one and pushes `8b` onto it itself.
                CampPickerView()
            }
        }
        // The one attempt this flow makes on its own behalf, and the thing that ends the hold.
        //
        // `finishSignIn` fetches the memberships itself, on the line after it sets `auth`
        // (`AppStore.swift:886-893`). If that throws, `perform` catches it into the banner and
        // `hasLoadedMemberships` stays down — so without this the rule would decline for ever and
        // the held frame would be a screen with nothing on it and no way off. This retries, and
        // then reports that the asking is over whichever way the retry went, which is what turns
        // `campList` from `.pending` into `.failed`.
        //
        // Guarded on the empty case so the common path costs nothing: a list that already has
        // camps in it is not in doubt, and `CampPickerView` loads again on its own behalf when
        // the flow reaches it. It does mean that during a normal sign-in this fetch and
        // `finishSignIn`'s overlap — the view is on screen before that await returns — which is
        // one wasted request against the alternative of a first run with no way to recover from a
        // failed one.
        .task {
            guard store.memberships.isEmpty else { return }
            await store.loadMemberships()
            hasStoppedWaiting = true
        }
    }

    /// The name, straight onto the account. There is no local copy of it to keep in step — the
    /// question is on screen exactly while `displayName` is empty, so a successful write is what
    /// moves the flow on and a rejected one leaves it where it was.
    private func save(_ name: String) {
        guard var account = store.account else { return }
        account.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await store.updateAccount(account) }
    }
}

// MARK: - Nothing asked yet

/// The frame, held, with no question in it.
///
/// On screen for `FirstRunStep.notYet` — the moment between `auth` becoming `.signedIn` and the
/// memberships arriving, when an account with three camps and an account with none are the same
/// empty array.
///
/// **Deliberately nothing.** There is no loading indicator anywhere in this app and this is not
/// the place to introduce the first one. The "Working…" capsule went for the reason written up at
/// `Components.swift:1092-1104` — a wait too short to read is a wait not worth drawing, and one
/// drawn at random reads as a fault — and the full-screen seed fall went with it. A mark parked in
/// the middle here would be `SeedLoadingView` under a new name, which `FallingSeeds.swift` argues
/// against in its own words: the logo used as a progress indicator is the fastest way to stop
/// people seeing it.
///
/// So what is held is the page, and only the page: `surfaceWarm`, which is what all three
/// questions and screen 3 are drawn on. Nothing appears and then moves — the question simply
/// arrives on the surface it was always going to be on. The header plate would have been the other
/// candidate and is the wrong one twice over: it is the header *of a question*, and drawing it
/// here means a fourth copy of the three literals `FirstRunHeader` exists to stop being copied
/// (`FirstRunHeader.swift:4-13`).
private struct HeldFrame: View {
    var body: some View {
        Theme.surfaceWarm
            // Nothing is drawn, and for VoiceOver nothing drawn is indistinguishable from an app
            // that has stopped. `FallingSeeds` named itself while it fell for exactly this reason
            // and this inherits the job — as a label, which costs the screen nothing.
            .accessibilityElement()
            .accessibilityLabel("Loading your camps")
    }
}

// MARK: - Previews

/// The held frame, drawn on its own. Reaching it through `FirstRunView` would take a repository
/// that never answers — a stub the size of the whole protocol, for a page with nothing on it.
///
/// No `showsMockStatusBar()`, unlike every other preview in this file: there is no header here to
/// draw one, which is rather the point of the preview.
#Preview("First run — nothing to ask yet") {
    HeldFrame()
}

/// A brand-new account: no name, no camps. The first of the three questions.
#Preview("First run — no name") {
    let store = AppStore(repository: InMemoryRepository(memberships: []))
    var account = SampleData.account
    account.displayName = ""
    store.auth = .signedIn(account)

    return FirstRunView()
        .environment(store)
        .showsMockStatusBar()
}

/// Named, and belonging to nothing yet — the question screen 3 never asked.
#Preview("First run — which way in") {
    let store = AppStore(repository: InMemoryRepository(memberships: []))
    store.auth = .signedIn(SampleData.account)

    return FirstRunView()
        .environment(store)
        .showsMockStatusBar()
}

/// Somebody who has been here before, arriving through Profile's "Switch camp". Neither question
/// is asked and this is screen 3, unchanged.
#Preview("First run — a returning coach") {
    FirstRunView()
        .environment(AppStore.previewCampPicker)
        .showsMockStatusBar()
}
