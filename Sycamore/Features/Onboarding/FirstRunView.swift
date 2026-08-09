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
//      no camps on the account  -> `RunningOrJoiningView`, and then whichever way they chose
//      otherwise                -> screen 3, exactly as before
//
//  Which of those is on screen is `FirstRunStep`'s decision, and it is a rule read off the store
//  rather than a cursor this view walks. See that file: the short of it is that a derived step
//  cannot get out of step with the account it is about, so a name that failed to save leaves the
//  question up — with `RootView`'s banner over it (`RootView.swift:80-86`) — and nothing here has
//  to know that.
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
    @State private var path: FirstRunStep.Path?

    /// "Not now" on the name question. Session-only, deliberately — see `FirstRunStep`.
    @State private var isNameSkipped = false

    private var step: FirstRunStep {
        FirstRunStep.resolve(
            displayName: store.account?.displayName ?? "",
            isNameSkipped: isNameSkipped,
            hasCamps: !store.memberships.isEmpty,
            path: path
        )
    }

    var body: some View {
        // `SwiftUI.Group` because `Group` is this app's own model type. It is here so the task
        // below belongs to the flow rather than to whichever question is currently drawn — a task
        // on the `.name` case would be cancelled the moment the name was answered.
        SwiftUI.Group {
            switch step {
            case .name:
                YourNameView(
                    currentName: store.account?.displayName ?? "",
                    email: store.account?.email ?? "",
                    onSave: save,
                    onSkip: { isNameSkipped = true }
                )

            case .runningOrJoining, .createCamp:
                NavigationStack {
                    RunningOrJoiningView(email: store.account?.email ?? "", onChoose: choose)
                        // The screen draws its own header, so the stack's bar stays hidden —
                        // applied here, to the root inside the stack, because it is this stack
                        // that creates the need for it. `CampPickerView.swift:74` does the same.
                        .hidesNavigationBar()
                        .navigationDestination(isPresented: isCreatingACamp) {
                            CreateCampView()
                        }
                }

            case .camps:
                // Bare, without a stack of ours: screen 3 owns one and pushes `8b` onto it itself.
                CampPickerView()
            }
        }
        // Makes the rule's input true rather than assuming it.
        //
        // `hasCamps` is `memberships.isEmpty`, and an empty list means two different things:
        // this account belongs to no camp, or the list has not arrived. `finishSignIn` sets
        // `auth` to `.signedIn` on the line *before* it awaits the memberships
        // (`AppStore.swift:838-845`), so if that fetch throws, `perform` clears `isWorking`, the
        // list stays empty, and a coach with three camps is asked whether they are starting one
        // — the exact ambush this flow is written to avoid.
        //
        // Guarded on the empty case so the common path costs nothing: a list that already has
        // camps in it is not in doubt, and `CampPickerView` loads again on its own behalf when
        // the flow reaches it.
        .task {
            guard store.memberships.isEmpty else { return }
            await store.loadMemberships()
        }
    }

    /// `path` seen as the one thing `navigationDestination(isPresented:)` can take.
    ///
    /// A projection rather than a second `@State` `Bool`, because two pieces of state for one
    /// fact is how a screen ends up pushed with no answer recorded — or an answer recorded with
    /// nothing pushed. Reading it is a comparison of two enum cases; setting it is SwiftUI
    /// reporting a pop, and clearing `path` there is what puts the question back rather than
    /// leaving the flow pointing at a screen that is no longer on it.
    ///
    /// The usual objection to `Binding(get:set:)` does not apply. It is aimed at bindings that do
    /// *work* on write — the ones that should be `@State` plus an `onChange` — and at fields that
    /// rebuild one on every keystroke (`ProfileView.swift:49-52` and `CampPickerView.swift:334-336`
    /// each argue that case). There is no effect here to move: it is a pure view of the answer,
    /// read once per pass of a body that is a four-way switch.
    ///
    /// `navigationDestination(item:)` was the other option and is worse: `path` also holds the
    /// answer that does *not* push, so the destination closure would have to be handed a value it
    /// must refuse to draw anything for.
    private var isCreatingACamp: Binding<Bool> {
        Binding(
            // Off the step rather than off `path` directly, so `FirstRunStep` stays the one
            // authority on what is showing and `path` is read in exactly one place.
            get: { step == .createCamp },
            set: { isPushed in path = isPushed ? .creatingACamp : nil }
        )
    }

    private func choose(_ chosen: FirstRunStep.Path) {
        path = chosen
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

// MARK: - Previews

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
