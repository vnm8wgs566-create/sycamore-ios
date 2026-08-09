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

    /// "What should the camp call you?"
    case name
    /// "Are you running a camp, or joining one?"
    case runningOrJoining
    /// `8b Shape the camp`, pushed so it keeps its own way back.
    case createCamp
    /// Screen 3 — the picker, which is where the code field lives and where somebody with camps
    /// already has always landed.
    case camps

    /// The next unanswered question.
    ///
    /// - Parameters:
    ///   - displayName: the account's, as stored. Trimmed here rather than by the caller, because
    ///     a name of three spaces is the same absence as a name of none and the rule is the place
    ///     that should know it.
    ///   - isNameSkipped: whether "Not now" was tapped. The name question is otherwise unskippable
    ///     — it is derived from the account, so it would come back on the next pass — and an
    ///     unskippable question in front of the only way into the app is a trap. It is not
    ///     remembered past the session on purpose: a name is worth asking for twice.
    ///   - hasCamps: whether the account belongs to any camp at all. See the header for why the
    ///     path question turns on this and not on `camp == nil`.
    ///   - path: the answer to the path question, once there is one.
    static func resolve(
        displayName: String,
        isNameSkipped: Bool,
        hasCamps: Bool,
        path: Path?
    ) -> FirstRunStep {
        if !isNameSkipped, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .name
        }
        switch path {
        case .creatingACamp: return .createCamp
        case .joiningOne: return .camps
        // Somebody who already belongs to a camp is not new, whatever cleared the current one.
        case nil: return hasCamps ? .camps : .runningOrJoining
        }
    }
}
