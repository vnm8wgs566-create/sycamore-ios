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
//  The rule is a pure function of four values precisely so that both can be written down.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("The first run — which question is asked")
struct FirstRunStepTests {

    private func step(
        name: String = "Alex Ramos",
        skipped: Bool = false,
        hasCamps: Bool = true,
        path: FirstRunStep.Path? = nil
    ) -> FirstRunStep {
        FirstRunStep.resolve(
            displayName: name, isNameSkipped: skipped, hasCamps: hasCamps, path: path
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
}
