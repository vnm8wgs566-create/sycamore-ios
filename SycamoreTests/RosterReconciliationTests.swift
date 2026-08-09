//
//  RosterReconciliationTests.swift
//  SycamoreTests
//
//  A second file read against a camp that already has kids in it.
//
//  This is the arithmetic that decides whether a child is created, updated, left alone or offered
//  for removal, and every wrong answer it can give is a quiet one — a duplicate in New beside the
//  real child in "Not in this file" looks exactly as reasonable on screen as the right answer
//  does. So the sentences below are mostly about the failures rather than the successes: what a
//  blank cell must never propose, which of two identical Liams a row takes, and who is left over.
//
//  `RosterReconciliation` is pure `Foundation`, so every one of them is a plain synchronous call
//  with no store, no camp graph and no view in the way — the same reason `GroupsLandingPlan` was
//  lifted out of a `@MainActor` view to be tested.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private enum Roster {

    /// Ids that sort the way a test needs them to.
    ///
    /// Two kids a file cannot tell apart are separated by `id.uuidString`, so a test about that
    /// tie has to choose which id is lower rather than hope.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", number))")!
    }

    /// A kid the camp already holds.
    ///
    /// `surname` defaults to nil because that is what all 100 seeded rows are: an initial and
    /// nothing more. Supplying one is the camp that has already been through an import.
    static func kid(
        _ firstName: String,
        _ lastInitial: String,
        surname: String? = nil,
        age: Int? = nil,
        gender: Gender = .x,
        isReturning: Bool = false,
        id: UUID = UUID(),
        venue: UUID? = nil,
        group: UUID? = nil,
        overallRank: Int = 0,
        courtRank: Int = 0
    ) -> Player {
        Player(
            id: id,
            firstName: firstName,
            lastInitial: lastInitial,
            lastName: surname,
            age: age,
            gender: gender,
            isReturning: isReturning,
            venueID: venue,
            groupID: group,
            overallRank: overallRank,
            courtRank: courtRank
        )
    }

    /// A row in the office's file. Every optional defaults to nil, which is the file staying quiet.
    static func row(
        _ firstName: String,
        _ lastName: String = "",
        age: Int? = nil,
        gender: Gender? = nil,
        isReturning: Bool? = nil,
        venueIndex: Int = 0
    ) -> IntakePlayer {
        IntakePlayer(
            firstName: firstName,
            lastName: lastName,
            age: age,
            gender: gender,
            isReturning: isReturning,
            venueIndex: venueIndex
        )
    }
}

// MARK: - Which bucket a row lands in

@Suite("Reconciling a roster — the four buckets")
struct RosterReconciliationBucketTests {

    @Test("A file row that matches a kid by name and age lands in Changed, not New")
    func aMatchingRowLandsInChanged() {
        let camp = [Roster.kid("Serene", "C", age: 13, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", "Chu", age: 13, gender: .f)], camp: camp)

        #expect(plan.arriving.isEmpty)
        #expect(plan.absent.isEmpty)
        #expect(plan.changed.count == 1)
        #expect(plan.changed.first?.player.id == camp[0].id)
    }

    @Test("A file row nobody at the camp answers to lands in New")
    func anUnknownRowLandsInNew() {
        let camp = [Roster.kid("Serene", "C", age: 13, gender: .f)]
        let file = [Roster.row("Serene", "Chu", age: 13, gender: .f), Roster.row("Theo", "Vance", age: 14, gender: .m)]

        let plan = RosterReconciliation(file: file, camp: camp)

        #expect(plan.arriving.count == 1)
        #expect(plan.arriving.first?.row.firstName == "Theo")
        #expect(plan.absent.isEmpty)
    }

    @Test("A kid at the camp no row names lands in Not in this file, with nothing ticked")
    func anUnnamedKidLandsInNotInThisFile() {
        let mia = Roster.kid("Mia", "K", age: 12, gender: .f)
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f), mia]

        let plan = RosterReconciliation(file: [Roster.row("Serene", "Chu", age: 13, gender: .f)], camp: camp)
        let opening = RosterSelection.opening(for: plan)

        #expect(plan.absent.map(\.id) == [mia.id])
        #expect(plan.absent.first?.isAmbiguous == false)
        #expect(opening.removing.isEmpty)
    }

    @Test("A row that matches and says nothing different lands in Already here")
    func aRowThatSaysNothingNewLandsInAlreadyHere() {
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f, isReturning: true)]
        let file = [Roster.row("Serene", "Chu", age: 13, gender: .f, isReturning: true)]

        let plan = RosterReconciliation(file: file, camp: camp)

        #expect(plan.alreadyHere.count == 1)
        #expect(plan.changed.isEmpty)
        #expect(plan.arriving.isEmpty)
        #expect(plan.absent.isEmpty)
    }

    @Test("An empty camp puts every row in New and nothing anywhere else — which is what onboarding is")
    func anEmptyCampIsAllNew() {
        let file = [Roster.row("Serene", "Chu", age: 13), Roster.row("Liam", "Prior", age: 12)]

        let plan = RosterReconciliation(file: file, camp: [])

        #expect(plan.arriving.count == 2)
        #expect(plan.alreadyHere.isEmpty)
        #expect(plan.changed.isEmpty)
        #expect(plan.absent.isEmpty)
        #expect(plan.summary == "2 in the file · 2 new")
    }

    @Test("The same file reconciled against the camp it just built has nothing in New and nothing in Changed")
    func aRoundTripProposesNothing() {
        let file = IntakeImport.preview.players
        let camp = file.map { $0.asPlayer() }

        let plan = RosterReconciliation(file: file, camp: camp)

        #expect(plan.alreadyHere.count == file.count)
        #expect(plan.arriving.isEmpty)
        #expect(plan.changed.isEmpty)
        #expect(plan.absent.isEmpty)
        #expect(plan.summary == "42 in the file · nothing has changed")
    }
}

// MARK: - The key

@Suite("Reconciling a roster — matching on a name")
struct RosterReconciliationKeyTests {

    @Test("Case, accents and punctuation fold together, so \"Séréne O'Chu\", \"serene ochu\" and \"Serene-O-Chu\" are one kid")
    func theFoldIgnoresCaseAccentsAndPunctuation() {
        #expect(RosterReconciliation.fold("Séréne O'Chu") == "sereneochu")
        #expect(RosterReconciliation.fold("serene ochu") == "sereneochu")
        #expect(RosterReconciliation.fold("Serene-O-Chu") == "sereneochu")

        let camp = [Roster.kid("Séréne", "O", surname: "O'Chu", age: 13, gender: .f)]
        for spelling in [("serene", "ochu"), ("SERENE", "O'CHU"), ("Sérène", "o-chu")] {
            let plan = RosterReconciliation(
                file: [Roster.row(spelling.0, spelling.1, age: 13, gender: .f)],
                camp: camp
            )
            #expect(plan.alreadyHere.count == 1, "\(spelling) should be the same child")
            #expect(plan.arriving.isEmpty)
        }
    }

    /// The alternative is demonstrated rather than argued about: a Turkish fold of "I" is "ı", so
    /// a locale-aware key would put "IRIS" and "Iris" in two different buckets on a phone set to
    /// Turkish and one bucket on a phone set to English — and the same roster would reconcile two
    /// ways depending on who was holding it.
    @Test("The fold does not move with the reader's language, so a phone set to Turkish buckets the same kid as one set to English")
    func theFoldIsNotLocalised() {
        #expect("IRIS".lowercased(with: Locale(identifier: "tr_TR")) != "iris")
        #expect(RosterReconciliation.fold("IRIS") == RosterReconciliation.fold("Iris"))

        let camp = [Roster.kid("Iris", "H", surname: "Haddad", age: 11, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("IRIS", "HADDAD", age: 11, gender: .f)], camp: camp)

        #expect(plan.alreadyHere.count == 1)
        #expect(plan.arriving.isEmpty)
    }

    @Test("A kid the camp knows only by an initial matches the file's whole surname")
    func anInitialMatchesAWholeSurname() {
        let camp = [SampleData.sereneC]
        #expect(camp[0].lastName == nil, "the design's camp is the initial-only case this tier exists for")

        let plan = RosterReconciliation(
            file: [Roster.row("Serene", "Chu", age: 13, gender: .f, isReturning: true)],
            camp: camp
        )

        #expect(plan.arriving.isEmpty)
        #expect(plan.absent.isEmpty)
        #expect(plan.changed.first?.player.id == SampleData.sereneC.id)
    }

    @Test("A surname the file supplies where the camp has none is a fill, and the only field that changed")
    func aSuppliedSurnameIsTheOnlyChange() throws {
        let camp = [Roster.kid("Serene", "C", age: 13, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", "Chu", age: 13, gender: .f)], camp: camp)

        let change = try #require(plan.changed.first)
        #expect(change.fields.map(\.field) == [.surname])
        #expect(change.fields.first?.before == "C")
        #expect(change.fields.first?.after == "Chu")
        #expect(change.updated.lastName == "Chu")
        #expect(change.updated.lastInitial == "C")
    }

    /// The initial is where matching on a name runs out. Two spellings that start differently are
    /// two children as far as this can tell — and a fuzzier surname match would merge real
    /// siblings far more often than it would catch a typist.
    @Test("A kid whose surname is spelled differently in the two files is New and Missing, which is the limit of matching on a name")
    func aDifferentSurnameIsTwoChildren() {
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", "Zhu", age: 13, gender: .f)], camp: camp)

        #expect(plan.arriving.count == 1)
        #expect(plan.absent.count == 1)
        #expect(plan.changed.isEmpty)
        #expect(plan.alreadyHere.isEmpty)
    }
}

// MARK: - Silence

@Suite("Reconciling a roster — what the file did not say")
struct RosterReconciliationSilenceTests {

    @Test("An age the file leaves blank never proposes clearing an age the camp has")
    func aBlankAgeClearsNothing() {
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", "Chu", gender: .f)], camp: camp)

        #expect(plan.changed.isEmpty)
        #expect(plan.alreadyHere.count == 1)
    }

    /// `IntakePlayer.asPlayer()` maps a nil gender to `.x`, and `.x` is also the "Other" chip on
    /// `8e` — so reconciling through `asPlayer()` rather than off `IntakePlayer.gender` would make
    /// every file with a blank gender column propose turning every girl into an X, pre-ticked.
    @Test("A gender the file leaves blank never proposes turning a girl into an X")
    func aBlankGenderTurnsNobodyIntoAnX() {
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", "Chu", age: 13)], camp: camp)

        #expect(plan.changed.isEmpty)
        #expect(plan.alreadyHere.count == 1)
    }

    /// End to end through the parser, because the silence starts there: a four-column file has no
    /// returning column at all, and `IntakePlayer.isReturning` has to come back nil for this to
    /// hold.
    @Test("A file with no returning column proposes nothing about returning")
    func aFileWithNoReturningColumnProposesNothing() throws {
        let file = try IntakeFile.parse("First name,Last name,Age,Gender\nSerene,Chu,13,F", named: "week.csv")
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f, isReturning: true)]

        let plan = RosterReconciliation(file: file.players, camp: camp)

        #expect(plan.changed.isEmpty)
        #expect(plan.alreadyHere.count == 1)
    }

    @Test("A blank surname never proposes clearing a surname the camp has")
    func aBlankSurnameClearsNothing() {
        let camp = [Roster.kid("Serene", "C", surname: "Chu", age: 13, gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", age: 13, gender: .f)], camp: camp)

        // No surname on the row means no strict key and an empty loose mark, so this is not even
        // the same child — but whichever way it went, nothing may propose emptying "Chu".
        #expect(plan.changed.isEmpty)
    }

    @Test("An age the camp does not have and the file does is a change, which is what a re-import is for")
    func aFileCanFillAnAgeTheCampLacks() throws {
        let camp = [Roster.kid("Serene", "C", surname: "Chu", gender: .f)]
        let plan = RosterReconciliation(file: [Roster.row("Serene", "Chu", age: 13, gender: .f)], camp: camp)

        let change = try #require(plan.changed.first)
        #expect(change.fields.map(\.field) == [.age])
        #expect(change.updated.age == 13)
    }

    @Test("Before and after read as the screen draws them: \"Age unknown\" → \"13 years\"")
    func beforeAndAfterReadAsTheScreenDrawsThem() throws {
        let camp = [Roster.kid("Serene", "C", gender: .f, isReturning: false)]
        let file = [Roster.row("Serene", "Chu", age: 13, gender: .m, isReturning: true)]

        let plan = RosterReconciliation(file: file, camp: camp)
        let change = try #require(plan.changed.first)
        let read = Dictionary(uniqueKeysWithValues: change.fields.map { ($0.field, [$0.before, $0.after]) })

        #expect(read[.age] == ["Age unknown", "13 years"])
        #expect(read[.gender] == ["Girl", "Boy"])
        #expect(read[.isReturning] == ["First time", "Returning"])
        #expect(read[.surname] == ["C", "Chu"])
    }
}

// MARK: - Two of somebody

@Suite("Reconciling a roster — when a name is not enough")
struct RosterReconciliationAmbiguityTests {

    @Test("Two kids called Liam P and one Liam Prior in the file: the ages say which one it is")
    func agesTellTwoLiamsApart() throws {
        let younger = Roster.kid("Liam", "P", age: 12, id: Roster.id(1))
        let older = Roster.kid("Liam", "P", age: 14, id: Roster.id(2))

        let plan = RosterReconciliation(file: [Roster.row("Liam", "Prior", age: 14)], camp: [younger, older])

        let change = try #require(plan.changed.first)
        #expect(change.player.id == older.id)
        #expect(plan.absent.map(\.id) == [younger.id])
        #expect(plan.arriving.isEmpty)
    }

    @Test("Two kids called Liam P, both twelve, and one row: the lower id takes it and both rows are flagged")
    func theLowerIdTakesAnUnbreakableTie() throws {
        // Handed over in the wrong order on purpose: the tie is broken by `id.uuidString`, not by
        // where the caller happened to have the kid standing.
        let second = Roster.kid("Liam", "P", age: 12, id: Roster.id(2))
        let first = Roster.kid("Liam", "P", age: 12, id: Roster.id(1))

        let plan = RosterReconciliation(file: [Roster.row("Liam", "Prior", age: 12)], camp: [second, first])

        let change = try #require(plan.changed.first)
        #expect(change.player.id == first.id)
        #expect(change.isAmbiguous)
        #expect(plan.absent.first?.isAmbiguous == true)
    }

    @Test("Two kids called Liam P and one row: the one nobody claimed is offered for removal, flagged")
    func theUnclaimedTwinIsOfferedForRemoval() throws {
        let taken = Roster.kid("Liam", "P", age: 12, id: Roster.id(1))
        let left = Roster.kid("Liam", "P", age: 12, id: Roster.id(2))

        let plan = RosterReconciliation(file: [Roster.row("Liam", "Prior", age: 12)], camp: [taken, left])
        let absence = try #require(plan.absent.first)
        let opening = RosterSelection.opening(for: plan)

        #expect(plan.absent.count == 1)
        #expect(absence.player.id == left.id)
        #expect(absence.isAmbiguous)
        #expect(opening.removing.isEmpty)
        #expect(opening.changed.isEmpty, "an ambiguous change starts unticked, because it is a guess")
    }

    @Test("One kid and two rows with the same name: the first row in the file claims them and the second is New")
    func theFirstRowClaimsTheOnlyKid() throws {
        let liam = Roster.kid("Liam", "P", id: Roster.id(1))
        let file = [Roster.row("Liam", "Prior"), Roster.row("Liam", "Prior")]

        let plan = RosterReconciliation(file: file, camp: [liam])

        let change = try #require(plan.changed.first)
        #expect(change.row.id == file[0].id)
        #expect(plan.arriving.map(\.id) == [file[1].id])
        #expect(change.isAmbiguous)
    }

    @Test("One kid and two rows with the same name: the row whose age matches claims them, wherever it sits in the file")
    func theMatchingAgeClaimsTheOnlyKid() throws {
        let liam = Roster.kid("Liam", "P", age: 14, id: Roster.id(1))
        let file = [Roster.row("Liam", "Prior", age: 11), Roster.row("Liam", "Prior", age: 14)]

        let plan = RosterReconciliation(file: file, camp: [liam])

        let change = try #require(plan.changed.first)
        #expect(change.row.id == file[1].id)
        #expect(plan.arriving.map(\.id) == [file[0].id])
    }

    /// The strict key is consulted before the initial tier, so a whole surname the camp already
    /// holds beats a matching age on somebody else.
    @Test("A whole surname the camp already holds beats a Liam P with the right age")
    func aWholeSurnameBeatsTheInitialTier() throws {
        let prior = Roster.kid("Liam", "P", surname: "Prior", age: 14, id: Roster.id(1))
        let park = Roster.kid("Liam", "P", surname: "Park", age: 12, id: Roster.id(2))

        let plan = RosterReconciliation(file: [Roster.row("Liam", "Prior", age: 12)], camp: [prior, park])

        let change = try #require(plan.changed.first)
        #expect(change.player.id == prior.id)
        #expect(change.fields.map(\.field) == [.age])
        #expect(plan.absent.map(\.id) == [park.id])
    }
}

// MARK: - Invariants

@Suite("Reconciling a roster — what must always hold")
struct RosterReconciliationInvariantTests {

    /// Two Liams, a Serene the camp knows by her initial, a stranger, and a kid the file dropped.
    private static let camp = [
        Roster.kid("Serene", "C", age: 13, gender: .f, id: Roster.id(1)),
        Roster.kid("Liam", "P", age: 12, gender: .m, id: Roster.id(2)),
        Roster.kid("Liam", "P", age: 14, gender: .m, id: Roster.id(3)),
        Roster.kid("Mia", "K", age: 12, gender: .f, id: Roster.id(4)),
    ]
    private static let file = [
        Roster.row("Serene", "Chu", age: 13, gender: .f),
        Roster.row("Liam", "Prior", age: 14, gender: .m),
        Roster.row("Theo", "Vance", age: 14, gender: .m),
    ]

    /// Four orderings rather than a shuffle, for the reason `GroupsLandingPlanTests` gives: a
    /// shuffled test that fails once cannot be run again.
    @Test("Nobody appears in two buckets, whatever order the file arrives in", arguments: [0, 1, 2, 3])
    func nobodyIsInTwoBuckets(_ choice: Int) {
        let orders = [[0, 1, 2], [2, 1, 0], [1, 2, 0], [2, 0, 1]]
        let file = orders[choice].map { Self.file[$0] }

        let plan = RosterReconciliation(file: file, camp: Self.camp)

        let rowIDs = plan.arriving.map(\.id) + plan.alreadyHere.map(\.row.id) + plan.changed.map(\.row.id)
        #expect(Set(rowIDs) == Set(file.map(\.id)))
        #expect(rowIDs.count == file.count)

        let kidIDs = plan.alreadyHere.map(\.id) + plan.changed.map(\.id) + plan.absent.map(\.id)
        #expect(Set(kidIDs) == Set(Self.camp.map(\.id)))
        #expect(kidIDs.count == Self.camp.count)
    }

    /// A tick has to survive the Fix screen, which replaces a row by `IntakeImport.update(_:)` —
    /// same id, different fields. So an arrival is identified by its *row*, and everything that
    /// found a kid is identified by that *kid*; a `Change` that ticked by row id would come back
    /// from a fix as a different entry.
    @Test("Every entry carries an id the review screen can tick, and no two entries share one")
    func everyEntryHasItsOwnID() {
        let plan = RosterReconciliation(file: Self.file, camp: Self.camp)

        #expect(plan.arriving.allSatisfy { $0.id == $0.row.id })
        #expect(plan.alreadyHere.allSatisfy { $0.id == $0.player.id })
        #expect(plan.changed.allSatisfy { $0.id == $0.player.id })
        #expect(plan.absent.allSatisfy { $0.id == $0.player.id })

        let ids = plan.arriving.map(\.id) + plan.alreadyHere.map(\.id) + plan.changed.map(\.id) + plan.absent.map(\.id)
        #expect(!ids.isEmpty)
        #expect(Set(ids).count == ids.count)
    }

    @Test("The summary counts what the screen is about to show")
    func theSummaryCountsTheBuckets() {
        let plan = RosterReconciliation(file: Self.file, camp: Self.camp)

        #expect(plan.fileCount == Self.file.count)
        #expect(plan.summary == "3 in the file · 1 new · 2 changed · 2 not in this file")
    }

    /// Where a child stands was decided on Groups by somebody watching them play. A spreadsheet
    /// column that mostly holds its own default does not get to overturn that.
    @Test("Venue, court and rank are camp state, so a re-import never proposes moving a kid who is already here")
    func aReImportMovesNobody() throws {
        let venue = UUID()
        let court = UUID()
        let serene = Roster.kid(
            "Serene", "C", surname: "Chu", age: 12, gender: .f,
            venue: venue, group: court, overallRank: 7, courtRank: 3
        )

        let plan = RosterReconciliation(
            file: [Roster.row("Serene", "Chu", age: 13, gender: .f, venueIndex: 3)],
            camp: [serene]
        )
        let change = try #require(plan.changed.first)

        #expect(change.fields.map(\.field) == [.age])
        #expect(change.updated.venueID == venue)
        #expect(change.updated.groupID == court)
        #expect(change.updated.overallRank == 7)
        #expect(change.updated.courtRank == 3)
        #expect(change.updated.id == serene.id)
    }
}

// MARK: - Ticking and committing

@Suite("Reconciling a roster — what a tick writes")
struct RosterCommitTests {

    private static let camp = [
        Roster.kid("Serene", "C", age: 13, gender: .f, id: Roster.id(1), venue: Roster.id(90)),
        Roster.kid("Mia", "K", age: 12, gender: .f, id: Roster.id(2), venue: Roster.id(90)),
    ]
    private static let file = [
        Roster.row("Serene", "Chu", age: 13, gender: .f),
        Roster.row("Theo", "Vance", age: 14, gender: .m, venueIndex: 2),
    ]

    @Test("A selection nobody touched writes the arrivals and the changes and removes nobody")
    func theOpeningSelectionWritesArrivalsAndChanges() {
        let plan = RosterReconciliation(file: Self.file, camp: Self.camp)
        let commit = plan.commit(.opening(for: plan))

        #expect(commit.inserting.map(\.firstName) == ["Theo"])
        #expect(commit.updating.map(\.id) == [Self.camp[0].id])
        #expect(commit.removing.isEmpty)
        #expect(!commit.isEmpty)
    }

    @Test("A commit built from an empty selection writes nothing at all")
    func anEmptySelectionWritesNothing() {
        let plan = RosterReconciliation(file: Self.file, camp: Self.camp)
        let commit = plan.commit(RosterSelection())

        #expect(commit.inserting.isEmpty)
        #expect(commit.updating.isEmpty)
        #expect(commit.removing.isEmpty)
        #expect(commit.isEmpty)
    }

    @Test("An arrival keeps the venue it was answered into, and a change keeps the venue the camp had")
    func venuesComeFromTheRightSide() throws {
        let plan = RosterReconciliation(file: Self.file, camp: Self.camp)
        var selection = RosterSelection.opening(for: plan)
        selection.removing = [Self.camp[1].id]
        let commit = plan.commit(selection)

        #expect(commit.inserting.first?.venueIndex == 2)
        #expect(commit.updating.first?.venueID == Roster.id(90))
        #expect(commit.removing == [Self.camp[1].id])
    }

    /// A tick is held as an id rather than a value so it survives the Fix screen, which replaces
    /// a row by `IntakeImport.update(_:)` — same id, different fields. An id from a bucket it does
    /// not belong to writes nothing rather than something unexpected.
    @Test("An id the reconciliation does not hold is ignored rather than written")
    func aStrayIDWritesNothing() {
        let plan = RosterReconciliation(file: Self.file, camp: Self.camp)
        var selection = RosterSelection()
        selection.arriving = [UUID()]
        selection.changed = [UUID()]
        selection.removing = [UUID()]

        let commit = plan.commit(selection)

        #expect(commit.isEmpty)
    }
}
