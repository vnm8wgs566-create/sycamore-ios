//
//  FirstSortCopyTests.swift
//  SycamoreTests
//
//  The two sentences on `4c` that the design writes and the app cannot copy.
//
//  `FirstSort` is tested next door for whether the ladder it builds is right. This file is about
//  whether the screen's *prose* is true, which is a different failure and a quieter one: a footnote
//  promising groups of eight to a venue that will be dealt into groups of five is not a crash, it
//  is a coach planning a session around a number the app made up. Neither sentence can be caught by
//  looking at the screen, because both read perfectly well while being wrong.
//
//  The split figure is checked against the deal itself rather than against a restatement of the
//  arithmetic. `FirstSortCopy.splitSize(roll:courts:)` claims to describe what
//  `Camp.redistribute(in:across:)` will do; the only test of that claim worth writing runs the deal
//  and counts the courts, so a change to `deal(_:across:)` — a different remainder rule, a
//  different fill order — fails here rather than quietly making the footnote a lie.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()

private func kid(
    _ firstName: String = "Serene",
    initial: String = "C",
    surname: String? = "Chu",
    age: Int?,
    returning: Bool
) -> Player {
    Player(
        firstName: firstName,
        lastInitial: initial,
        lastName: surname,
        age: age,
        gender: .f,
        isReturning: returning,
        venueID: venueID,
        groupID: nil,
        overallRank: 1,
        courtRank: 1
    )
}

/// One venue's courts after the split `4c` promises, smallest first.
///
/// Through the same primitive the screen's own action reaches — `spreadKids(.allKids, …)` is
/// `redistribute(in:across:)` (`SectionEightRepository.swift:326`) — so this counts the real deal
/// rather than a reimplementation of it.
private func courtSizes(roll: Int, courts: Int) -> [Int] {
    var camp = Fixture.camp([.init("Home", courts: courts)], players: roll)
    guard let venue = camp.orderedVenues.first else { return [] }
    camp.redistribute(in: venue.id, across: camp.groups(in: venue.id).map(\.id))
    camp.reindex()
    return camp.groups(in: venue.id).map { camp.players(inGroup: $0.id).count }.sorted()
}

/// A venue shape, the sentence `4c` writes for it, and the courts the deal actually produces.
struct FirstSortSplitCase: Sendable {
    let roll: Int
    let courts: Int
    let phrase: String
    let sizes: [Int]
}

private let splitCases: [FirstSortSplitCase] = [
    // The design's own frame: 42 kids, and a venue whose six courts divide them exactly. This is
    // the one case where the derived figure and the design's literal 8 nearly agree — and they
    // still do not, which is the point.
    FirstSortSplitCase(roll: 42, courts: 6, phrase: "groups of 7", sizes: [7, 7, 7, 7, 7, 7]),
    // The seeded camp's own shape, where `playerMax / groupCount` happens to be 8.
    FirstSortSplitCase(roll: 48, courts: 6, phrase: "groups of 8", sizes: [8, 8, 8, 8, 8, 8]),
    // The ordinary case: it does not divide, and both sizes are real.
    FirstSortSplitCase(roll: 50, courts: 6, phrase: "groups of 8 and 9", sizes: [8, 8, 8, 8, 9, 9]),
    FirstSortSplitCase(roll: 43, courts: 6, phrase: "groups of 7 and 8", sizes: [7, 7, 7, 7, 7, 8]),
    // A venue with one court does not split at all.
    FirstSortSplitCase(roll: 9, courts: 1, phrase: "one group of 9", sizes: [9]),
    // And the degenerate end: fewer kids than courts, where "groups of 0 and 1" would be
    // arithmetically right and unreadable.
    FirstSortSplitCase(roll: 3, courts: 6, phrase: "one kid to a group", sizes: [0, 0, 0, 1, 1, 1]),
]

// MARK: - The meta line

@Suite("4c's meta line")
struct FirstSortMetaTests {

    @Test("A returning kid reads age then returning, and nothing about last summer")
    func returningKid() {
        #expect(FirstSortCopy.meta(for: kid(age: 13, returning: true)) == "13 · returning")
    }

    /// The half `Player.metaLine` does not write. A first-timer is the kid with no prior season
    /// behind their placing, which is exactly what somebody comparing two of them needs.
    @Test("A first-timer says so out loud")
    func newKid() {
        #expect(FirstSortCopy.meta(for: kid(age: 12, returning: false)) == "12 · new this summer")
    }

    /// The one difference from `Player.metaLine` that could be mistaken for an oversight, pinned
    /// so it cannot be "fixed" back into agreement with every other screen.
    @Test("Gender is dropped, where every other screen carries it")
    func dropsGender() {
        let player = kid(age: 13, returning: true)
        #expect(player.metaLine == "13 · F · returning")
        #expect(!FirstSortCopy.meta(for: player).contains("F"))
    }

    /// The rule `metaLine` already states: a gap reads as "not recorded" more plainly than a dash.
    @Test("An unknown age drops out rather than showing as a gap")
    func unknownAge() {
        #expect(FirstSortCopy.meta(for: kid(age: nil, returning: false)) == "new this summer")
        #expect(FirstSortCopy.meta(for: kid(age: nil, returning: true)) == "returning")
    }
}

// MARK: - The disc

/// The design draws `SC` and `CI` (`design/rebuild/section-t4.html:187`, `:194`), which the app's
/// own initials helper cannot produce for a kid — it would answer `SE`. Pinned because the two
/// look alike enough at 16pt to be missed, and because the fallback path is the one a real import
/// takes.
@Suite("4c's initials")
struct FirstSortInitialsTests {

    @Test("Two names, two letters — not the first two letters of one name")
    func givenAndFamily() {
        let serene = kid(age: 13, returning: true)
        #expect(FirstSortCopy.initials(for: serene) == "SC")
        #expect(Initials.make(from: serene.displayName) == "SE")
        #expect(FirstSortCopy.initials(for: kid("Caleb", initial: "I", surname: "Ito", age: 12, returning: false)) == "CI")
    }

    /// A roster row that arrived with a surname and no initial — which is most of what an import
    /// produces, since `lastInitial` is the field the *camp* fills in.
    @Test("A surname stands in when there is no initial")
    func fallsBackToTheSurname() {
        let imported = kid("Serene", initial: "", surname: "Chu", age: 13, returning: true)
        #expect(FirstSortCopy.initials(for: imported) == "SC")
    }

    /// One name and nothing else is one letter, and a kid with no name at all gets the same em
    /// dash every other empty disc in the app draws.
    @Test("A name that is barely a name still fills the disc")
    func thinNames() {
        #expect(FirstSortCopy.initials(for: kid("Liam", initial: "", surname: nil, age: 9, returning: false)) == "L")
        #expect(FirstSortCopy.initials(for: kid("", initial: "", surname: nil, age: nil, returning: false)) == "—")
    }

    /// **The two edges where a second copy of this rule disagreed with it.**
    ///
    /// `GroupsLockedState` — `8g`'s "Added so far" list — carried its own first-plus-last helper,
    /// with the same argument written out in the same words, and the two parted company at exactly
    /// these two inputs: it read `lastInitial` alone with no trim and no `lastName` fallback, so an
    /// imported kid drew `S` where `4c` drew `SC`, and a kid with no family name at all drew an
    /// empty disc where `4c` drew `—`. The same child, different letters, one tap apart.
    ///
    /// `8g` now calls this helper (`GroupsLockedState.swift:209`) and the copy is gone. These two
    /// expectations are what stop the pair re-forming: whichever screen a future edit is written
    /// against, both sides of the divergence are pinned here, spelled out as the answer the *deleted*
    /// helper would have given so the regression is recognisable rather than merely red.
    @Test("The same letters on every screen that draws a kid's disc")
    func theSameLettersOnEveryScreen() {
        // `8g` used to draw `S` for this one, having stopped at an empty `lastInitial`.
        let imported = kid("Serene", initial: "", surname: "Chu", age: 13, returning: true)
        #expect(FirstSortCopy.initials(for: imported) == "SC")

        // Whitespace where a camp typed a space into the field. Same kid, same disc.
        let padded = kid(" Serene ", initial: " ", surname: " Chu ", age: 13, returning: true)
        #expect(FirstSortCopy.initials(for: padded) == "SC")

        // And `8g` used to draw an empty disc for this one, which reads as a kid with no name
        // rather than as a name the app does not have.
        let nameless = kid("", initial: "", surname: nil, age: nil, returning: false)
        #expect(FirstSortCopy.initials(for: nameless) == "—")
        #expect(FirstSortCopy.initials(for: kid("", initial: "", surname: "", age: nil, returning: false)) == "—")
    }
}

// MARK: - The split figure

@Suite("4c's split figure")
struct FirstSortSplitTests {

    @Test("The phrase describes the deal that will actually run", arguments: splitCases)
    func matchesTheDeal(splitCase: FirstSortSplitCase) {
        #expect(courtSizes(roll: splitCase.roll, courts: splitCase.courts) == splitCase.sizes)
        #expect(
            FirstSortCopy.splitSize(roll: splitCase.roll, courts: splitCase.courts)
                == splitCase.phrase
        )
    }

    /// The two sentences that quote the figure share one derivation, so they cannot drift apart —
    /// the footnote promises it mid-sort and the settled state repeats it a tap before it happens.
    @Test("The footnote and the settled line quote the same figure", arguments: splitCases)
    func oneDerivation(splitCase: FirstSortSplitCase) {
        let footnote = FirstSortCopy.footnote(roll: splitCase.roll, courts: splitCase.courts)
        let detail = FirstSortCopy.settledDetail(roll: splitCase.roll, courts: splitCase.courts)

        #expect(footnote == "Splits into \(splitCase.phrase) when the ladder settles")
        #expect(detail == "Splitting now makes \(splitCase.phrase).")
    }

    /// Nothing on the screen can reach these — `4c` does not open below two kids and a venue
    /// always has at least one court — and the sentence still has to be a sentence. A footnote
    /// reading "Splits into groups of 0" would be the loudest possible way to be empty.
    @Test("An empty roll and a venue with no courts still read as English")
    func degenerateShapes() {
        #expect(FirstSortCopy.splitSize(roll: 0, courts: 6) == "groups")
        #expect(FirstSortCopy.splitSize(roll: 42, courts: 0) == "groups")
    }
}

// MARK: - The settled sentence

@Suite("4c's settled sentence")
struct FirstSortSettledTests {

    @Test("A clean sort says who has a place")
    func noSkips() {
        #expect(
            FirstSortCopy.settled(venueName: "Sycamore", skipped: 0)
                == "Everyone at Sycamore has a place on the ladder."
        )
    }

    /// Where the skipped kids went is the one fact nothing else on the screen states, and the
    /// button under this sentence is what writes them there (`Models/FirstSort.swift:235`).
    @Test("Skipped kids are named, and one of them is a kid rather than a count")
    func withSkips() {
        #expect(
            FirstSortCopy.settled(venueName: "Sycamore", skipped: 1)
                == "Everyone at Sycamore has a place, and the kid you skipped sits at the foot of the ladder."
        )
        #expect(
            FirstSortCopy.settled(venueName: "LATC", skipped: 3)
                == "Everyone at LATC has a place, and the 3 kids you skipped sit at the foot of the ladder."
        )
    }
}
