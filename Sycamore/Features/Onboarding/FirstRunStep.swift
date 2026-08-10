//
//  FirstRunStep.swift
//  Sycamore
//
//  What is still unanswered between signing in and standing in a camp.
//
//  Three questions, and only the third was ever asked. Signing in leaves `AppStore.finishSignIn`
//  with an account, a list of memberships and no camp, and `RootView` went straight to the camp
//  picker from there — so a brand-new account met a list headed "Your camps" with nothing in it,
//  a code field for a code nobody had given them, and a dashed card at the bottom. Every one of
//  those is the right control; none of them is the question a person who has just signed up is
//  actually holding, which is "am I setting this up, or was I sent a code?"
//
//  And nothing had ever asked for a name. `Account.displayName` is written on exactly one
//  occasion — the first authorisation an Apple ID ever gives the app (`AppStore.swift:766-772`)
//  — so everybody who signed in by email arrived with an empty one, showed up in the staff list
//  as a blank, and had nowhere to put it right. Profile can now edit it, and Profile is behind a
//  camp you may not have yet, so it is asked here too.
//
//  ---------------------------------------------------------------------------------------------
//  A RULE RATHER THAN A SEQUENCE
//  ---------------------------------------------------------------------------------------------
//
//  This is a function of the store's state and one local answer, not a cursor that walks forward.
//  A cursor would have to be reset — signing out, switching camps, an account whose write failed
//  — and each of those is a place to forget. Derived, the steps cannot disagree with the account
//  they are about: the name question is on screen exactly while the name is empty, so a successful
//  write moves the flow on and a **failed** one leaves it where it was, under the banner
//  `RootView` hangs over the whole flow. That is the correct behaviour and nothing writes it down.
//
//  The one thing that has to be remembered is which way in somebody chose, because nothing in the
//  store changes when they answer it. That is `Path`, and it is `@State` on the view.
//
//  ---------------------------------------------------------------------------------------------
//  WHY THE PATH QUESTION IS GATED ON HAVING NO CAMPS
//  ---------------------------------------------------------------------------------------------
//
//  `store.camp == nil` is not only the first run. Profile's "Switch camp" clears it
//  (`AppStore.switchCamp()`), and so does deleting the camp you were in. Somebody with three
//  camps tapping Switch is asking for the list, and a screen asking whether they are starting a
//  camp would be an ambush. Belonging to no camp at all is the honest reading of "new here", and
//  it is the same condition `CampPickerView` already draws its "No camps yet" state for.
//
//  ---------------------------------------------------------------------------------------------
//  AND A THIRD ANSWER: NOT YET
//  ---------------------------------------------------------------------------------------------
//
//  "Belonging to no camp" is read off an empty membership list, and an empty list means two
//  different things: this account belongs to no camp, or nobody has asked yet.
//  `AppStore.finishSignIn` sets `auth` to `.signedIn` and *then* awaits the memberships, both
//  inside the same `perform`, so for that moment an account with three camps is indistinguishable
//  from an account with none — and one of those readings is the ambush above.
//
//  A full-screen seed fall used to lie over the whole flow while that resolved, so what was on
//  screen was seeds rather than the wrong question. It was a curtain over a bug, and it has gone
//  (`RootView.swift:55-78`): a rule that guesses and corrects itself a moment later would now be
//  watched doing it, by a coach of three years seeing "Running a camp, or joining one?" flick past
//  on the way to their own list.
//
//  So the rule declines rather than guesses. `CampList` is how far the fetch has got, and while it
//  is `.pending` the answer is `.notYet` — which `FirstRunView` draws as its own page with no
//  question on it. Only the *empty* branch consults it: a camp in hand is its own proof that the
//  list arrived, and the name question is answered off the account, which came with the sign-in.
//  Nothing waits that does not have to.
//
//  `CampList` is three states rather than a `Bool` because a fetch has three outcomes and the
//  third one is the dangerous one. `AppStore.loadMemberships` reports a failure through the shared
//  banner rather than by throwing, so a fetch that fails leaves `hasLoadedMemberships` down for
//  good — and a rule reading a two-state flag would either hold an empty page for ever or, worse,
//  treat "we never found out" as "you belong to nothing" and ask the ambush anyway. Named, it can
//  be answered: see `.failed` below.
//

import Foundation

/// Which of the getting-started questions is on screen.
enum FirstRunStep: Hashable, Sendable {

    /// Which way in somebody chose. Deliberately not a role: `memberships.role` is decided by
    /// which of these two they take — creating a camp makes you its admin, a code makes you
    /// whatever the camp granted — so this steers the route and writes nothing.
    enum Path: Hashable, Sendable {
        case creatingACamp
        case joiningOne
    }

    /// How far the account's camp list has got, which is not the same question as what is in it.
    ///
    /// The empty array that `AppStore.memberships` starts every session as is all three of these
    /// until something says otherwise, and the rule needs to tell them apart before it can read
    /// "belongs to no camp" off it. See the header.
    enum CampList: Hashable, Sendable {
        /// Still coming, or not asked for yet. Nothing can be said about belonging.
        case pending
        /// It came. Whatever is in it is now a fact about the account.
        case arrived
        /// The asking is over and nothing came back. Belonging is still unknown and nothing left
        /// on this screen is going to settle it, so the flow has to move on without the answer.
        case failed
    }

    /// No question at all — the account's camps have not arrived, so which one comes next is not
    /// something anybody can say yet. `FirstRunView` holds its frame on this and draws nothing.
    /// See the header: this is the state the seed fall used to cover.
    case notYet
    /// "What should the camp call you?"
    case name
    /// "Are you running a camp, or joining one?"
    case runningOrJoining
    /// `8b Shape the camp`, pushed so it keeps its own way back.
    case createCamp
    /// Screen 3 — the picker, which is where the code field lives and where somebody with camps
    /// already has always landed.
    case camps

    /// The next unanswered question, or `.notYet` while there is no saying which that is.
    ///
    /// - Parameters:
    ///   - displayName: the account's, as stored. Trimmed here rather than by the caller, because
    ///     a name of three spaces is the same absence as a name of none and the rule is the place
    ///     that should know it.
    ///   - isNameSkipped: whether "Not now" was tapped. The name question is otherwise unskippable
    ///     — it is derived from the account, so it would come back on the next pass — and an
    ///     unskippable question in front of the only way into the app is a trap. It is not
    ///     remembered past the session on purpose: a name is worth asking for twice.
    ///   - campList: how far the fetch behind `hasCamps` has got. See the header, and `CampList`
    ///     for why a fetch's third outcome is worth a name.
    ///   - hasCamps: whether the account belongs to any camp at all. See the header for why the
    ///     path question turns on this and not on `camp == nil`.
    ///   - path: the answer to the path question, once there is one.
    static func resolve(
        displayName: String,
        isNameSkipped: Bool,
        campList: CampList,
        hasCamps: Bool,
        path: Path?
    ) -> FirstRunStep {
        // First, and without waiting for anything: the name is read off the account, which arrived
        // with the sign-in. Asking for it while the camps are still in the air costs the flow
        // nothing and usually spends the whole wait.
        if !isNameSkipped, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .name
        }
        switch path {
        case .creatingACamp: return .createCamp
        case .joiningOne: return .camps
        case nil:
            // Somebody who already belongs to a camp is not new, whatever cleared the current one
            // — and a camp in hand is its own proof that the list arrived. So `campList` is
            // consulted on the empty case alone, which is the only one that is ambiguous.
            guard !hasCamps else { return .camps }

            switch campList {
            case .pending:
                return .notYet
            case .arrived:
                return .runningOrJoining
            // The list never came, so "belongs to nothing" is a guess and the ambush is back on
            // the table. Screen 3 is the safe answer to a question nobody can answer: it draws
            // "No camps yet" for an empty list, prints `errorMessage` under it
            // (`CampPickerView.swift:140`), tries the fetch again on its own `.task`, and offers
            // both ways forward — the code field and "Create a camp" — without asking which one
            // this person is. `.runningOrJoining` would be right for one of the two readings and
            // an interrogation for the other.
            case .failed:
                return .camps
            }
        }
    }
}
