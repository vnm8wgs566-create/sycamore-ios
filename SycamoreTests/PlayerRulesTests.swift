//
//  PlayerRulesTests.swift
//  SycamoreTests
//
//  The two bounds on a kid's row, and the three places that now consult them.
//
//  They were statics on `IntakePlayer` — the shape of a line in a spreadsheet — so the file path
//  checked them and neither of the two paths that do not go through a file did. The failure that
//  made this urgent is specific and quiet: `importPlayers` sends a whole roster in **one** insert,
//  so one kid typed as 25 on `8e` rejects every other kid in the same batch, with a raw PostgREST
//  message and no row to point at.
//
//  The tests below are therefore mostly about the *refusals* rather than the acceptances: what a
//  free-text numpad must not be allowed to write, and what a file must not be allowed to propose.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("PlayerRules mirrors the columns")
struct PlayerRulesTests {

    @Test("The bounds are the CHECKs, not a rounder number somebody liked")
    func bounds() {
        #expect(PlayerRules.ageLimits == 4...19)
        #expect(PlayerRules.surnameLimit == 60)
    }

    @Test("An age inside the range comes back unchanged", arguments: [4, 12, 19])
    func legalAge(years: Int) {
        #expect(PlayerRules.age(years) == years)
    }

    @Test("An age the column would refuse comes back as nothing", arguments: [0, 3, 20, 25, 120, -1])
    func illegalAge(years: Int) {
        #expect(PlayerRules.age(years) == nil)
    }

    @Test("No age at all stays no age — the filter does not invent one")
    func missingAge() {
        #expect(PlayerRules.age(nil) == nil)
    }

    @Test("A surname is trimmed on the way through, which is the form that gets sent")
    func surnameTrimmed() {
        #expect(PlayerRules.surname("  Chu  ") == "Chu")
    }

    @Test("An empty cell is nothing rather than an empty string — the column admits null or 1…60")
    func surnameEmpty() {
        #expect(PlayerRules.surname("") == nil)
        #expect(PlayerRules.surname("   ") == nil)
    }

    @Test("Sixty characters pass and sixty-one do not")
    func surnameCeiling() {
        #expect(PlayerRules.surname(String(repeating: "a", count: 60)) != nil)
        #expect(PlayerRules.surname(String(repeating: "a", count: 61)) == nil)
    }

    /// The reason `CharLength` exists, restated where it bites. A three-person family emoji is one
    /// `Character` and five scalars, so thirteen of them are sixty-five to Postgres and thirteen
    /// to `String.count` — a rule written with `.count` waves this through and then fails at the
    /// insert it was guarding.
    @Test("Counted the way Postgres counts, so a surname of emoji cannot slip past on grapheme count")
    func surnameCountedAsPostgresCounts() {
        let emoji = String(repeating: "👩‍👩‍👧", count: 13)
        #expect(emoji.count == 13)
        #expect(emoji.unicodeScalars.count == 65)
        #expect(PlayerRules.surname(emoji) == nil)
    }
}

// MARK: - Who consults them

@Suite("A row's issue tells a gap apart from a refusal")
struct IntakeIssueTests {

    private func row(age: Int? = 12, surname: String = "Chu") -> IntakePlayer {
        IntakePlayer(firstName: "Serene", lastName: surname, age: age, gender: .f)
    }

    @Test("A legal row has nothing to ask about")
    func clean() {
        #expect(row().issue == nil)
    }

    /// The distinction the constants exist for, and the reason `issue` reads them rather than
    /// `PlayerRules.age(_:)`: the filter folds both of these into the same nil.
    @Test("No age is a gap and twenty-five is a refusal, and they are different questions")
    func gapVersusRefusal() {
        #expect(row(age: nil).issue == .noAge)
        #expect(row(age: 25).issue == .impossibleAge)
    }

    @Test("A surname past the column's ceiling is caught before the insert is attempted")
    func longSurname() {
        #expect(row(surname: String(repeating: "a", count: 61)).issue == .longSurname)
    }
}

@Suite("asPlayer refuses what the column would refuse")
struct AsPlayerTests {

    /// The failure this closes. `commit` deliberately keeps rows with an open issue, and neither
    /// review screen's button refuses one — so without the filter a single 25 reaches
    /// `importPlayers`, which sends the roster as **one** array, and forty-one innocent kids are
    /// rejected with it.
    @Test("An age the roster will not take is dropped rather than sent, so the batch survives")
    func impossibleAgeDropped() {
        let kid = IntakePlayer(firstName: "Rafe", lastName: "Osei", age: 25, gender: .m).asPlayer()
        #expect(kid.age == nil)
        #expect(kid.firstName == "Rafe")
        #expect(kid.lastName == "Osei")
    }

    @Test("A legal age comes across untouched", arguments: [4, 12, 19])
    func legalAgeKept(years: Int) {
        let kid = IntakePlayer(firstName: "Serene", lastName: "Chu", age: years, gender: .f)
        #expect(kid.asPlayer().age == years)
    }

    @Test("A surname past sixty characters is dropped, and takes its initial with it")
    func longSurnameDropped() {
        let kid = IntakePlayer(
            firstName: "Serene", lastName: String(repeating: "a", count: 61), age: 12, gender: .f
        ).asPlayer()

        #expect(kid.lastName == nil)
        // Half of a rejected value is not a name — a "Serene A" here would be a surname the camp
        // invented out of a merged cell.
        #expect(kid.lastInitial == "")
        #expect(kid.displayName == "Serene")
    }

    @Test("A surname the column takes keeps its whole self and derives its initial")
    func surnameKept() {
        let kid = IntakePlayer(firstName: "Serene", lastName: "  Chu  ", age: 12, gender: .f).asPlayer()
        #expect(kid.lastName == "Chu")
        #expect(kid.lastInitial == "C")
    }

    /// The three coercions that were already here, pinned so the two new ones cannot be read as
    /// having changed them.
    @Test("A blank cell is still nil, no gender is still X, and no returning column is still false")
    func existingCoercionsUnchanged() {
        let kid = IntakePlayer(firstName: "Walk-in", lastName: "", age: nil, gender: nil).asPlayer()
        #expect(kid.lastName == nil)
        #expect(kid.age == nil)
        #expect(kid.gender == .x)
        #expect(kid.isReturning == false)
    }
}

@Suite("A value the column would refuse is the file saying nothing")
struct RosterReconciliationRefusalTests {

    private static func kid(age: Int?, surname: String) -> Player {
        Player(
            firstName: "Serene",
            lastInitial: "C",
            lastName: surname,
            age: age,
            gender: .f,
            isReturning: false,
            overallRank: 1,
            courtRank: 1
        )
    }

    private static func row(age: Int?, surname: String = "Chu") -> IntakePlayer {
        IntakePlayer(firstName: "Serene", lastName: surname, age: age, gender: .f)
    }

    /// The one that matters. Without the filter this row lands in Changed, **pre-ticked** by
    /// `RosterSelection.opening(for:)`, and the reader agrees to a batch that `updatePlayers` then
    /// fails at the CHECK — taking the other forty legitimate updates down with it.
    @Test("An age outside 4…19 proposes no change at all")
    func impossibleAgeIsSilence() {
        let reconciliation = RosterReconciliation(
            file: [Self.row(age: 25)],
            camp: [Self.kid(age: 12, surname: "Chu")]
        )

        #expect(reconciliation.changed.isEmpty)
        #expect(reconciliation.alreadyHere.count == 1)
        #expect(reconciliation.arriving.isEmpty)
        #expect(reconciliation.absent.isEmpty)
    }

    /// The long surname has to start with the letter the camp holds, or this is testing the
    /// *matcher* rather than the rule: a name whose first letter differs is a different child as
    /// far as the loose key can tell, and the row would land in New with the kid in Not-in-this-
    /// file. Keeping the initial makes the two the same person and leaves only the question this
    /// is about — what a refusable value proposes.
    @Test("A surname past sixty characters proposes no change either")
    func longSurnameIsSilence() {
        let long = "C" + String(repeating: "h", count: 60)
        let reconciliation = RosterReconciliation(
            file: [Self.row(age: 12, surname: long)],
            camp: [Self.kid(age: 12, surname: "Chu")]
        )

        #expect(reconciliation.changed.isEmpty)
        #expect(reconciliation.alreadyHere.count == 1)
        #expect(reconciliation.alreadyHere.first?.player.lastName == "Chu")
    }

    /// Silence, not a *clearing*: the kid keeps what the camp already knew about them.
    @Test("The kid keeps the age the camp holds, rather than losing it to a bad cell")
    func refusalDoesNotClear() {
        let reconciliation = RosterReconciliation(
            file: [Self.row(age: 25)],
            camp: [Self.kid(age: 12, surname: "Chu")]
        )
        #expect(reconciliation.alreadyHere.first?.player.age == 12)
    }

    /// The rule is about *legality*, not about refusing to change anything — a re-import that
    /// stopped correcting ages would have lost its whole point.
    @Test("A legal age that differs is still a change, which is what a re-import is for")
    func legalAgeStillChanges() {
        let reconciliation = RosterReconciliation(
            file: [Self.row(age: 13)],
            camp: [Self.kid(age: 12, surname: "Chu")]
        )

        #expect(reconciliation.changed.count == 1)
        #expect(reconciliation.changed.first?.updated.age == 13)
    }
}
