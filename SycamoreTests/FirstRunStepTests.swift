//
//  FirstRunStepTests.swift
//  SycamoreTests
//
//  Which question is asked, and — more to the point — which is *not*.
//
//  `FirstRunStep.resolve` sits in front of the only way into the app, so both of its failure
//  modes are bad in a way a screenshot would not catch. Ask too little and a brand-new account
//  lands on a list of camps it does not have, which is what it did before. Ask too much and a
//  coach of three years tapping "Switch camp" is interrogated about whether they are starting a
//  camp — an ambush, in the middle of a working day, on a screen they have used a hundred times.
//
//  The rule is a pure function of five values precisely so that both can be written down.
//
//  Which makes this file the whole of the end-to-end check on the third failure mode, the one
//  added last: asking *too early*. The memberships arrive a moment after `auth` does, and for that
//  moment an account with three camps looks exactly like an account with none. A seed fall used to
//  cover it; nothing does now, so the ordering is the test — signed in, name present or not, list
//  still coming or arrived or never arriving, in every combination a real sign-in can produce.
//
//  The last of those three is the one worth reading twice. A fetch that failed leaves the list as
//  empty as a fetch still in the air, and the two are *not* the same screen: one is worth holding
//  for, and the other has to be moved on from without ever being taken as an answer.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("The first run — which question is asked")
struct FirstRunStepTests {

    /// `list` defaults to `.arrived` — the settled state, which is what every question in the
    /// first two sections is about. The tests that unsettle it are gathered below them.
    private func step(
        name: String = "Alex Ramos",
        skipped: Bool = false,
        list: FirstRunStep.CampList = .arrived,
        hasCamps: Bool = true,
        path: FirstRunStep.Path? = nil
    ) -> FirstRunStep {
        FirstRunStep.resolve(
            displayName: name,
            isNameSkipped: skipped,
            campList: list,
            hasCamps: hasCamps,
            path: path
        )
    }

    // MARK: The name

    @Test("An account with no name is asked for one before anything else")
    func anEmptyNameIsAsked() {
        #expect(step(name: "", hasCamps: false) == .name)
        #expect(step(name: "", hasCamps: true) == .name)
    }

    /// Whitespace is absence. A name of three spaces draws as a gap the size of a missing name,
    /// which is exactly what the question exists to stop.
    @Test("A name of nothing but whitespace is no name", arguments: ["", " ", "   ", "\n", "\t "])
    func whitespaceIsNoName(_ name: String) {
        #expect(step(name: name, hasCamps: false) == .name)
    }

    @Test("An account that has a name is never asked for one")
    func aNamedAccountIsNotAsked() {
        #expect(step(name: "Alex Ramos", hasCamps: true) == .camps)
        #expect(step(name: "Alex Ramos", hasCamps: false) == .runningOrJoining)
    }

    /// The question is derived from the account rather than stepped through, so without this it
    /// would return on the very next pass and the app would have no way past it.
    @Test("\"Not now\" gets past the name question without answering it")
    func skippingTheName() {
        #expect(step(name: "", skipped: true, hasCamps: false) == .runningOrJoining)
        #expect(step(name: "", skipped: true, hasCamps: true) == .camps)
    }

    // MARK: Which way in

    @Test("An account belonging to no camp is asked which way in")
    func noCampsAsksTheWayIn() {
        #expect(step(hasCamps: false) == .runningOrJoining)
    }

    /// The ambush this rule exists to prevent. `store.camp == nil` is also what Profile's "Switch
    /// camp" produces (`AppStore.switchCamp()`), and somebody with camps who taps it is asking
    /// for the list — not to be asked whether they are starting a camp.
    @Test("Somebody who already belongs to a camp goes straight to the list, as they always did")
    func havingCampsSkipsTheQuestion() {
        #expect(step(hasCamps: true) == .camps)
    }

    @Test("Choosing to run a camp routes to Shape the camp")
    func creatingRoutesToTheShape() {
        #expect(step(hasCamps: false, path: .creatingACamp) == .createCamp)
    }

    @Test("Choosing a code routes to the camps list, which is where the code field is")
    func joiningRoutesToTheList() {
        #expect(step(hasCamps: false, path: .joiningOne) == .camps)
    }

    /// An answer outlives the state it was given in. Nothing writes to the account when the
    /// question is answered — `Membership.role` is decided by what happens next, not here — so if
    /// the answer were not remembered the question would simply be asked again.
    @Test("An answer holds, whatever else is true", arguments: [true, false])
    func theAnswerHolds(_ hasCamps: Bool) {
        #expect(step(hasCamps: hasCamps, path: .creatingACamp) == .createCamp)
        #expect(step(hasCamps: hasCamps, path: .joiningOne) == .camps)
    }

    /// Order, stated as a rule: the name comes first even for somebody who has already chosen a
    /// way in, so a nameless account cannot slip past by tapping quickly.
    @Test("The name is asked before the way in, and before an answer to it is honoured")
    func theNameComesFirst() {
        #expect(step(name: "", hasCamps: false, path: .creatingACamp) == .name)
        #expect(step(name: "", hasCamps: true, path: .joiningOne) == .name)
    }

    // MARK: Before the answer is in

    /// The three things the fetch behind `hasCamps` can be doing, for the rules that have to hold
    /// across all of them.
    private static let everyCampList: [FirstRunStep.CampList] = [.pending, .arrived, .failed]

    /// The flash the seed fall used to cover. An empty list this early is not "no camps", it is
    /// "nobody has said yet", and the two must not resolve to the same screen.
    @Test("Nothing at all is asked while the account's camps are still coming")
    func nothingIsAskedBeforeTheCampsArrive() {
        #expect(step(list: .pending, hasCamps: false) == .notYet)
    }

    @Test("The same empty list, once it has arrived, is the question a new account gets")
    func anArrivedEmptyListIsBelieved() {
        #expect(step(list: .arrived, hasCamps: false) == .runningOrJoining)
    }

    /// The third outcome, and the reason the input is not a `Bool`. A fetch that failed leaves the
    /// list as empty as one still in the air, so reading "belongs to nothing" off it is the same
    /// ambush by another route. Screen 3 asks nobody anything, prints the failure, offers both
    /// ways forward and retries the fetch itself — which is the whole case for sending them there.
    @Test("A list that never arrived sends nobody to the way-in question")
    func aFailedFetchIsNotTakenAsAnAnswer() {
        #expect(step(list: .failed, hasCamps: false) == .camps)
    }

    /// The list is consulted on the empty case alone. A membership in hand could only have come
    /// from a fetch that returned, so it settles the question by itself — and a rule that held
    /// anyway would hold a blank page in front of somebody whose camps are already here.
    @Test(
        "A camp in hand settles it, whatever the fetch behind it did",
        arguments: everyCampList
    )
    func campsInHandNeedNoFetch(_ list: FirstRunStep.CampList) {
        #expect(step(list: list, hasCamps: true) == .camps)
    }

    /// The name lives on the account, which arrives with the sign-in — so the one question that
    /// can be asked immediately is asked immediately, and the wait for the camps is usually spent
    /// answering it rather than looking at a held frame.
    @Test(
        "A nameless account is asked for a name whatever its camps are doing",
        arguments: everyCampList, [true, false]
    )
    func theNameDoesNotWait(_ list: FirstRunStep.CampList, _ hasCamps: Bool) {
        #expect(step(name: "", list: list, hasCamps: hasCamps) == .name)
    }

    @Test("\"Not now\" hands back to the hold, not past it")
    func skippingTheNameStillWaits() {
        #expect(step(name: "", skipped: true, list: .pending, hasCamps: false) == .notYet)
    }

    /// An answer already given outranks the hold: to have chosen a way in you were shown the
    /// question, which the rule only asks once the list is in. Un-drawing the screen they are
    /// standing on because a second fetch is in flight would be the flash again, backwards.
    @Test("A way in already chosen is honoured while the camps are still coming")
    func anAnswerOutranksTheHold() {
        #expect(step(list: .pending, hasCamps: false, path: .creatingACamp) == .createCamp)
        #expect(step(list: .pending, hasCamps: false, path: .joiningOne) == .camps)
    }

    // MARK: The orderings a real sign-in produces

    /// The whole complaint, walked through in order. `finishSignIn` sets `auth` and *then* awaits
    /// the memberships, so this coach is signed in, named, and momentarily indistinguishable from
    /// somebody who belongs to nothing. `.runningOrJoining` must not appear at any point on the
    /// way to their own list.
    @Test("A coach with three camps is never asked whether they are starting one")
    func aReturningCoachIsNeverAmbushed() {
        // Signed in; the fetch has not come back.
        #expect(step(list: .pending, hasCamps: false) == .notYet)
        // It comes back, with their camps in it.
        #expect(step(list: .arrived, hasCamps: true) == .camps)
    }

    /// The same coach on a connection that dies mid sign-in. Both fetches fail, the list stays
    /// empty and nothing is ever going to say otherwise — and they still must not be asked whether
    /// they are starting a camp, because tapping "I'm running one" would give them a second one.
    @Test("Nor is that coach ambushed when the list simply never comes")
    func aReturningCoachIsNotAmbushedByAFailureEither() {
        #expect(step(list: .pending, hasCamps: false) == .notYet)
        #expect(step(list: .failed, hasCamps: false) == .camps)
    }

    /// The other ordering, which the hold must not slow down: a brand-new account meets the name
    /// question first, and by the time it is answered the empty list is a fact rather than a gap.
    @Test("A brand-new account is asked for a name, then which way in, and holds only between them")
    func aNewAccountWalksTheFlow() {
        #expect(step(name: "", list: .pending, hasCamps: false) == .name)
        // Saved, and the fetch is somehow still out.
        #expect(step(name: "Priya Nandan", list: .pending, hasCamps: false) == .notYet)
        // It lands, empty, which for this account is the truth.
        #expect(step(name: "Priya Nandan", list: .arrived, hasCamps: false) == .runningOrJoining)
    }

    /// Every combination of the three things a sign-in settles in its own time — a name or none,
    /// the list's three states, camps or none — with the answer stated for each. `path` is nil
    /// throughout, and the rule has no other inputs, so this is the whole of it.
    @Test(
        "Every ordering of name, arrival and belonging has exactly one right answer",
        arguments: [
            (name: "", list: FirstRunStep.CampList.pending, camps: false, asks: FirstRunStep.name),
            (name: "", list: .pending, camps: true, asks: .name),
            (name: "", list: .arrived, camps: false, asks: .name),
            (name: "", list: .arrived, camps: true, asks: .name),
            (name: "", list: .failed, camps: false, asks: .name),
            (name: "", list: .failed, camps: true, asks: .name),
            (name: "Alex", list: .pending, camps: false, asks: .notYet),
            (name: "Alex", list: .pending, camps: true, asks: .camps),
            (name: "Alex", list: .arrived, camps: false, asks: .runningOrJoining),
            (name: "Alex", list: .arrived, camps: true, asks: .camps),
            (name: "Alex", list: .failed, camps: false, asks: .camps),
            (name: "Alex", list: .failed, camps: true, asks: .camps),
        ]
    )
    func theWholeTruthTable(
        _ row: (name: String, list: FirstRunStep.CampList, camps: Bool, asks: FirstRunStep)
    ) {
        #expect(step(name: row.name, list: row.list, hasCamps: row.camps) == row.asks)
    }
}
