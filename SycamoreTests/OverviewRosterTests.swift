//
//  OverviewRosterTests.swift
//  SycamoreTests
//
//  The list under a court card on Overview: who is on it, in what order, and how much of that
//  list the card actually draws.
//
//  Worth pinning because nothing on screen looks wrong when it is wrong. A card that folded the
//  last kid away behind a "1 more" still reads as a card; a `+N more` that counted the roll
//  rather than the kids who turned up still reads as a number; an away child listed among the
//  present ones still reads as a name. The only thing that catches any of it is arithmetic, and
//  all of the arithmetic is out of the view and in here.
//
//  Five questions, in the order the screen asks them:
//
//      rosters(in:day:)              -> who is on every court today
//      CourtRoster.folded(to:…)      -> how much of one court the card draws
//      roster(for:from:preview:…)    -> and whether this card draws anything at all
//      spokenLabel(for:)             -> what one of those lines says to a reader who cannot see it
//      the row's own identity        -> and whether tapping it can reach the right kid
//
//  The last two arrived with the rows becoming controls. A tapped name opens `8q` through
//  `PushedScreen.player(row.id)` and there is nothing else in between, so what is left to check is
//  the two things a button cannot be asked about directly: that the sentence VoiceOver reads off a
//  line is the right one for the state the line is in, and that the identifier the row hands the
//  route is the kid whose name is drawn on it.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

/// A camp with one venue, `courts` courts, and `players` kids dealt across them.
///
/// Built rather than taken from `SampleData` wherever the question is about an exact number of
/// rows: the fold turns on `preview` and `preview + 1`, and asserting those against a fixture
/// sized to make a screenshot look right would be asserting against a coincidence. The tests
/// about *the day* use `SampleData` instead, because that is where the attendance lives.
private func dealtCamp(courts: Int, players: Int) -> Camp {
    var camp = Fixture.camp([.init("Sycamore", courts: courts)], players: players)
    camp.partition()
    return camp
}

private func courts(of camp: Camp) -> [Group] {
    camp.groups(in: camp.orderedVenues[0].id)
}

/// One court's whole list, unfolded.
private func wholeRoster(of camp: Camp, _ court: Group, day: Weekday = .today) -> CourtRoster {
    TodayCourts.rosters(in: camp, day: day)[court.id] ?? .none
}

/// One line of a court's list, in whichever of the three states a row can be drawn in.
///
/// Built by hand rather than lifted out of a camp, because two of the three cannot come out of
/// `TodayCourts.rosters` at all — Overview drops away kids before a card ever sees them. They are
/// still real: `CourtDetailRoster` keeps them and the court screen draws them with this same row,
/// so the sentence has to be right for a state Overview itself never produces.
///
/// `lastInitial` and no surname, deliberately. `Player.displayName` runs a whole name through
/// `PersonNameComponents`, which orders it by locale; the initial takes the plain spelling, so
/// "Serene C" is the same string on every machine the suite runs on and the assertions below can
/// be the literal sentence rather than an interpolation of it.
private func rosterLine(
    _ firstName: String,
    rank: Int = 1,
    gender: Gender = .f,
    isAway: Bool = false,
    leavesAt: TimeOfDay? = nil
) -> PlayerRow {
    let player = Player(
        firstName: firstName,
        lastInitial: "C",
        age: 12,
        gender: gender,
        isReturning: false,
        overallRank: rank,
        courtRank: rank
    )
    return PlayerRow(id: player.id, player: player, rank: rank, isAway: isAway, leavesAt: leavesAt)
}

/// The card the screen would draw for a court, carrying the head-count the roster has to agree
/// with.
private func card(
    for court: Group, in camp: Camp, day: Weekday = .today, status: CourtStatus = .open
) -> CourtCard {
    CourtCard(
        id: court.id,
        venueID: court.venueID,
        groupName: court.label,
        courtLabel: court.label,
        rankOrder: court.rankOrder,
        coachID: nil,
        coachName: nil,
        playersHere: camp.players(inGroup: court.id).count { !camp.isAway($0.id, on: day) },
        activity: nil,
        status: status
    )
}

// MARK: - Who is on every court

@Suite("TodayCourts.rosters")
struct TodayCourtsRostersTests {

    /// The defect this whole change is about. The screen used to name a single "detailed" court
    /// and hand `.none` to every other card, so eleven courts out of twelve listed nobody at all.
    @Test("Every court with kids on it gets a roster")
    func everyCourtGetsARoster() {
        let camp = dealtCamp(courts: 6, players: 50)

        let rosters = TodayCourts.rosters(in: camp)

        for court in courts(of: camp) {
            #expect(rosters[court.id] != nil)
            #expect(rosters[court.id]?.rows.count == camp.players(inGroup: court.id).count)
        }
    }

    @Test("A court with nobody on it is absent rather than empty")
    func anEmptyCourtIsAbsent() {
        // Six courts, two kids: the deal gives one apiece to the first two and leaves the rest
        // standing empty.
        let camp = dealtCamp(courts: 6, players: 2)

        let rosters = TodayCourts.rosters(in: camp)

        #expect(courts(of: camp).map { rosters[$0.id]?.rows.count ?? 0 } == [1, 1, 0, 0, 0, 0])
        #expect(rosters.count == 2)
    }

    @Test("Each court is numbered from 1, in court order")
    func ranksRunFromOne() {
        let camp = dealtCamp(courts: 3, players: 20)

        for court in courts(of: camp) {
            let rows = wholeRoster(of: camp, court).rows
            #expect(rows.map(\.rank) == rows.indices.map { $0 + 1 })
            // Court order, not camp order: the numeral is the kid's place on this court.
            #expect(rows.map(\.player.courtRank) == rows.indices.map { $0 + 1 })
        }
    }

    @Test("A camp with no kids yields no rosters at all")
    func anEmptyCamp() {
        #expect(TodayCourts.rosters(in: dealtCamp(courts: 3, players: 0)).isEmpty)
    }

    // MARK: Narrowing to the courts that will draw one

    /// `8j` draws exactly one roster — your own court — and every other court as a one-line row
    /// with no kids on it. Narrowing is what stops the other eleven being built, sorted and
    /// allocated on every tick of the clock for nobody to read; see `OverviewScreen.body`.
    @Test("Asking for one court builds one court")
    func narrowedToOneCourt() {
        let camp = dealtCamp(courts: 6, players: 50)
        let mine = courts(of: camp)[2]

        let rosters = TodayCourts.rosters(in: camp, courts: [mine.id])

        #expect(rosters.count == 1)
        #expect(rosters[mine.id] != nil)
    }

    /// The narrowed answer has to be the *same* answer, not a differently-ordered one — the card
    /// draws identically whichever path built it, and a screen that renumbered its kids when the
    /// reader happened to be standing on a court would be very hard to see and impossible to
    /// explain.
    @Test("A narrowed roster is exactly the roster the whole-camp pass would have built")
    func narrowingChangesNothingElse() {
        let camp = SampleData.uclaTennisCamp
        let all = TodayCourts.rosters(in: camp, day: .wed)

        for court in camp.groups {
            let one = TodayCourts.rosters(in: camp, day: .wed, courts: [court.id])
            #expect(one[court.id]?.rows == all[court.id]?.rows)
        }
    }

    @Test("Asking for no courts at all builds nothing")
    func narrowedToNothing() {
        #expect(TodayCourts.rosters(in: dealtCamp(courts: 6, players: 50), courts: []).isEmpty)
    }

    /// Nil is every court, which is `8i` — an admin sees a list under each of them.
    @Test("Nil is still the whole venue")
    func nilIsEverything() {
        let camp = dealtCamp(courts: 6, players: 50)

        #expect(TodayCourts.rosters(in: camp, courts: nil).count == courts(of: camp).count)
    }

    // MARK: The day

    /// Overview answers "who is on this court right now", so an away child is left out of the
    /// list entirely rather than greyed the way Groups draws them. The design's own frame bears
    /// it out: the list runs 1 to 5 with no gap where the away kid sits.
    @Test("Away kids are left out entirely, and the numbers close over the gap")
    func awayKidsAreLeftOut() {
        let camp = SampleData.uclaTennisCamp
        let court = SampleData.nassCourt
        let roll = camp.players(inGroup: court.id)
        let away = roll.filter { camp.isAway($0.id, on: .wed) }
        #expect(!away.isEmpty, "the fixture has to have somebody away for this to be a test")

        let rows = wholeRoster(of: camp, court, day: .wed).rows

        #expect(rows.count == roll.count - away.count)
        for kid in away {
            #expect(!rows.contains { $0.id == kid.id })
        }
        #expect(rows.map(\.rank) == rows.indices.map { $0 + 1 })
    }

    /// `PlayerRow.isAway` is the flag Groups greys a name with. Overview has already dropped
    /// those kids, so every row it draws is somebody who is here — and a row claiming otherwise
    /// would grey a child standing on the court.
    @Test("No drawn row is marked away")
    func nobodyDrawnIsAway() {
        let rosters = TodayCourts.rosters(in: SampleData.uclaTennisCamp, day: .wed)

        #expect(rosters.values.allSatisfy { $0.rows.allSatisfy { !$0.isAway } })
    }

    @Test("A kid going home early carries their time")
    func earlyPickupIsCarried() {
        let camp = SampleData.uclaTennisCamp
        let rosters = TodayCourts.rosters(in: camp, day: .wed)
        let leaving = camp.players.filter { camp.leavesAt($0.id, on: .wed) != nil }
        #expect(!leaving.isEmpty)

        for kid in leaving {
            guard let courtID = kid.groupID else { continue }
            let row = rosters[courtID]?.rows.first { $0.id == kid.id }
            #expect(row?.leavesAt == camp.leavesAt(kid.id, on: .wed))
        }
    }

    /// The day is a parameter, not the clock. `SampleData` writes its attendance for Wednesday
    /// alone, so a preview pinned to it and a Monday morning must not agree.
    @Test("Attendance written for one day does not touch another")
    func attendanceIsPerDay() {
        let camp = SampleData.uclaTennisCamp
        let court = SampleData.nassCourt

        let wednesday = wholeRoster(of: camp, court, day: .wed)
        let monday = wholeRoster(of: camp, court, day: .mon)

        #expect(monday.rows.count == camp.players(inGroup: court.id).count)
        #expect(wednesday.rows.count < monday.rows.count)
    }

    // MARK: Against the older read

    /// `roster(forCourt:in:day:limit:)` is expressed through `rosters(in:day:)` so there is one
    /// implementation of "who is on a court" rather than two that can quietly drift. This is the
    /// assertion that keeps it so.
    @Test("The single-court read is the same answer as the whole-camp one")
    func theSingleCourtReadAgrees() {
        let camp = SampleData.uclaTennisCamp
        let all = TodayCourts.rosters(in: camp, day: .wed)

        for court in camp.groups {
            let one = TodayCourts.roster(forCourt: court.id, in: camp, day: .wed, limit: 100)
            #expect(one.rows == (all[court.id]?.rows ?? []))
        }
    }
}

// MARK: - How much of it the card draws

@Suite("CourtRoster.folded")
struct CourtRosterFoldTests {

    private let preview = 3

    private func roster(of size: Int) -> CourtRoster {
        let camp = dealtCamp(courts: 1, players: size)
        return wholeRoster(of: camp, courts(of: camp)[0])
    }

    /// `GroupsRules.visibleCount`'s `+ 1`, which is the whole reason the fold is not a plain
    /// `prefix`: hiding a single row behind a row that says "1 more" saves nothing and costs the
    /// reader a tap.
    @Test("A court one kid over the preview is drawn whole")
    func onePastThePreviewDoesNotFold() {
        let folded = roster(of: preview + 1).folded(to: preview)

        #expect(folded.rows.count == preview + 1)
        #expect(folded.overflow == 0)
    }

    @Test("A court two kids over the preview folds")
    func twoPastThePreviewFolds() {
        let folded = roster(of: preview + 2).folded(to: preview)

        #expect(folded.rows.count == preview)
        #expect(folded.overflow == 2)
    }

    @Test("A court under the preview is drawn whole")
    func underThePreview() {
        let folded = roster(of: 2).folded(to: preview)

        #expect(folded.rows.count == 2)
        #expect(folded.overflow == 0)
    }

    @Test("Expanded draws every kid and folds nobody away")
    func expandedDrawsEverybody() {
        let folded = roster(of: 9).folded(to: preview, isExpanded: true)

        #expect(folded.rows.count == 9)
        #expect(folded.overflow == 0)
    }

    @Test("The folded rows are the top of the court, in order")
    func theFoldKeepsTheTop() {
        let whole = roster(of: 9)

        #expect(whole.folded(to: preview).rows == Array(whole.rows.prefix(preview)))
    }

    /// The invariant the type exists to keep: `+N more` counts the kids who are *here*, so it
    /// has to add up to the head-count in the line above the list whichever way the fold is
    /// turned.
    @Test("Drawn plus folded away is always the head-count", arguments: 0...12)
    func theHeadcountHolds(size: Int) {
        let whole = roster(of: size)

        #expect(whole.folded(to: preview).headcount == size)
        #expect(whole.folded(to: preview, isExpanded: true).headcount == size)
    }

    @Test("Folding an already folded roster does not double-count")
    func foldingTwiceIsStable() {
        let once = roster(of: 9).folded(to: preview)
        let twice = once.folded(to: preview)

        #expect(twice.rows.count == once.rows.count)
        #expect(twice.overflow == once.overflow)
    }

    // MARK: Whether the control is offered at all

    /// `isFoldable` decides whether the card gets a control. It has to answer exactly the
    /// question the fold answers, or the card offers a "+0 more" that does nothing — or, worse,
    /// opens with no way back.
    @Test("Foldable means the fold would actually hide somebody", arguments: 0...12)
    func foldableAgreesWithTheFold(size: Int) {
        let whole = roster(of: size)

        #expect(whole.isFoldable(to: preview) == (whole.folded(to: preview).overflow > 0))
    }

    @Test("A court stays foldable once it is open, so Show less is reachable")
    func staysFoldableWhileExpanded() {
        let open = roster(of: 9).folded(to: preview, isExpanded: true)

        #expect(open.isFoldable(to: preview))
        #expect(open.overflow == 0)
    }
}

// MARK: - Whether this card draws anything

@Suite("TodayCourts.roster(for:from:)")
struct TodayCourtsCardRosterTests {

    private let preview = 3

    @Test("An open court lists its kids, folded")
    func anOpenCourtLists() {
        let camp = dealtCamp(courts: 1, players: 9)
        let court = courts(of: camp)[0]

        let roster = TodayCourts.roster(
            for: card(for: court, in: camp),
            from: TodayCourts.rosters(in: camp),
            preview: preview,
            isExpanded: false
        )

        #expect(roster.rows.count == preview)
        #expect(roster.overflow == 9 - preview)
    }

    @Test("Expanding a card lists the rest of the court")
    func expandingListsTheRest() {
        let camp = dealtCamp(courts: 1, players: 9)
        let court = courts(of: camp)[0]

        let roster = TodayCourts.roster(
            for: card(for: court, in: camp),
            from: TodayCourts.rosters(in: camp),
            preview: preview,
            isExpanded: true
        )

        #expect(roster.rows.count == 9)
        #expect(roster.overflow == 0)
    }

    /// A closed court lists nobody — there is nobody on it. The kids are still on it in the
    /// graph, which is what makes this a rule rather than an accident of the data.
    @Test("A closed court lists nobody, however many kids the graph has on it")
    func aClosedCourtListsNobody() {
        let camp = dealtCamp(courts: 1, players: 9)
        let court = courts(of: camp)[0]
        let rosters = TodayCourts.rosters(in: camp)
        #expect(rosters[court.id]?.rows.count == 9)

        let roster = TodayCourts.roster(
            for: card(for: court, in: camp, status: .closed(reason: "Net down")),
            from: rosters,
            preview: preview,
            isExpanded: false
        )

        #expect(roster.isEmpty)
        #expect(roster.overflow == 0)
    }

    @Test("A card for a court the pass never saw lists nobody")
    func anUnknownCourtListsNobody() {
        let camp = dealtCamp(courts: 6, players: 2)
        let empty = courts(of: camp)[5]

        let roster = TodayCourts.roster(
            for: card(for: empty, in: camp),
            from: TodayCourts.rosters(in: camp),
            preview: preview,
            isExpanded: false
        )

        #expect(roster.isEmpty)
    }

    /// `+N more` has to agree with "Court 1 – 8 players" directly above it, folded or open. The
    /// two come from different places — the card's `playersHere` off the `today_courts` row, the
    /// roster off the camp graph — so this is the seam where they could drift.
    @Test("The list adds up to the head-count on the card, folded and open")
    func theListAddsUpToTheHeadcount() {
        let camp = SampleData.uclaTennisCamp
        let rosters = TodayCourts.rosters(in: camp, day: .wed)

        for court in camp.groups {
            let subject = card(for: court, in: camp, day: .wed)

            for isExpanded in [false, true] {
                let roster = TodayCourts.roster(
                    for: subject, from: rosters, preview: preview, isExpanded: isExpanded
                )
                #expect(roster.headcount == subject.playersHere)
            }
        }
    }
}

// MARK: - What one of those lines says out loud

/// The sentence under a name, which two screens now hang a button on.
///
/// It is asserted here rather than left to a screenshot because it is the half of the row nobody
/// looks at. The drawn line says "away" with a grey name and a glyph and "leaves early" with a
/// clock; a reader who cannot see either gets only this string, and the three facts it carries
/// arrive from three different places on `PlayerRow`. A missing clause reads as a perfectly
/// ordinary line.
///
/// It is `static` for the buttons — `CourtScreen.kidRow` and `OverviewCourtCard.kidRow` both set
/// it outright rather than trusting SwiftUI to lift the label off the row inside their own — so
/// this is also what pins the two screens to one spelling of a roster line.
@Suite("CourtRosterRow.spokenLabel")
struct CourtRosterRowSpokenLabelTests {

    @Test("A kid who is here is announced with their place on the court")
    func aKidWhoIsHere() {
        #expect(CourtRosterRow.spokenLabel(for: rosterLine("Serene")) == "1. Serene C. Girl")
    }

    /// The numeral goes, and not merely because the row draws no numeral. The column runs 1…n over
    /// the kids who turned up, so a place read out beside a child who is not standing in it names
    /// somebody else's.
    @Test("A kid who is away is announced without a place, and said to be away")
    func aKidWhoIsAway() {
        let row = rosterLine("Liam", rank: 4, gender: .m, isAway: true)

        #expect(CourtRosterRow.spokenLabel(for: row) == "Liam C. Boy. Away")
    }

    /// The one fact a coach comes to the row for, and the one the marks at the end of the line
    /// cannot say on their own — the clock glyph carries no label of its own by design.
    @Test("A kid going home early carries the time at the end of the sentence")
    func aKidLeavingEarly() {
        let row = rosterLine("Serene", rank: 2, leavesAt: TimeOfDay(12, 30))

        #expect(CourtRosterRow.spokenLabel(for: row) == "2. Serene C. Girl. Leaves at 12:30")
    }

    /// Both clauses, in the order the row's own doc writes them. Only the court screen reaches
    /// this — Overview has already dropped the kid — and it is exactly the sort of pairing that
    /// gets tested by neither screen because each believes the other owns it.
    @Test("A kid who is away and leaving early says both, in that order")
    func awayAndLeavingEarly() {
        let row = rosterLine("Ari", rank: 3, gender: .x, isAway: true, leavesAt: TimeOfDay(12, 30))

        #expect(CourtRosterRow.spokenLabel(for: row) == "Ari C. Other. Away. Leaves at 12:30")
    }

    /// `Gender.label`, not the `Female` / `Male` / `Unspecified` this row used to spell privately.
    /// Three screens each had their own three cases and the third column disagreed with itself
    /// everywhere; a row drifting back to a local spelling is what this catches.
    @Test("The gender is said in the app's one spelling of it", arguments: Gender.allCases)
    func genderUsesTheSharedSpelling(gender: Gender) {
        let spoken = CourtRosterRow.spokenLabel(for: rosterLine("Ari", gender: gender))

        #expect(spoken == "1. Ari C. \(gender.label)")
    }

    /// Over the real camp rather than a hand-built line: every row a card actually draws is
    /// somebody who turned up, so every one of them is announced with the numeral drawn beside it.
    /// That numeral is what lets a reader who cannot see the list match a name against the
    /// head-count in the line above it.
    @Test("Every line an Overview card draws is announced with its numeral")
    func everyDrawnLineIsNumbered() {
        let rosters = TodayCourts.rosters(in: SampleData.uclaTennisCamp, day: .wed)
        #expect(!rosters.isEmpty)

        for roster in rosters.values {
            for row in roster.rows {
                let spoken = CourtRosterRow.spokenLabel(for: row)

                // The numeral alone. "Nobody drawn is away" is a fact about the *flag*, and
                // `nobodyDrawnIsAway` above already holds it against the same camp and day —
                // asserting it again through the sentence would be the same claim read out of a
                // string, and a suffix check could not see the away kid who also leaves early.
                #expect(spoken.hasPrefix("\(row.rank). \(row.player.displayName). "))
            }
        }
    }
}

// MARK: - And whether tapping it can reach the right kid

/// The route from a name on a card to `8q`, which is `PushedScreen.player(row.id)` and nothing
/// else. There is no view under test here and deliberately so: what a `Button` does is not
/// checkable from a test, but everything the button is handed is.
@Suite("Opening a kid from Overview")
struct OverviewOpenKidTests {

    /// Why nothing had to be plumbed for the row to become a control: `PlayerRow.id` already *is*
    /// the kid's. The two are separate stored properties declared next to each other
    /// (`AppStore.swift:220-221`), so any builder of a row is free to hand them different values —
    /// and a card whose names opened the wrong child would look entirely correct.
    ///
    /// **Watched here rather than made impossible, which is the better fix.** `PlayerRow.id` could
    /// be `var id: Player.ID { player.id }` and then no builder could disagree with itself; all
    /// six construction sites in the app already write `id: player.id` verbatim. That is a change
    /// to `AppStore.swift`, which this unit does not own. Until it lands, a walk over one camp is
    /// what there is — and it can only see the builders that camp exercises.
    @Test("Every row a card draws is identified by the kid it names")
    func rowsCarryThePlayersOwnID() {
        let camp = SampleData.uclaTennisCamp
        let rosters = TodayCourts.rosters(in: camp, day: .wed)
        #expect(!rosters.isEmpty)
        // Indexed once rather than scanned per row: the loop below is every row of every court,
        // and `contains` inside it is the roll walked once per kid on it.
        let playerIDs = Set(camp.players.map(\.id))

        for roster in rosters.values {
            for row in roster.rows {
                #expect(row.id == row.player.id)
                #expect(playerIDs.contains(row.id))
            }
        }
    }

    // That the fold keeps the kids it draws pointing at the same children is `theFoldKeepsTheTop`
    // above, which compares whole `PlayerRow`s — `Hashable`, so identity is inside the comparison
    // it already makes. A second test asserting the ids alone would be that one weakened, which is
    // the trade the note at the foot of this suite refuses for `8j`'s narrowing.

    /// Two kids are two screens.
    ///
    /// `pushedScreen` is a `.fullScreenCover(item:)` slot that these rows *replace* rather than
    /// stack on — see `CourtScreen.openKid` — so SwiftUI only re-presents when the item's identity
    /// changes. A route whose identity ignored its payload would leave `8q` showing the first kid
    /// tapped however many names were tapped after it.
    ///
    /// Two ids and no camp behind them: this is a property of `PushedScreen.id` and of nothing
    /// else, and a failure should say so rather than leaving a reader to work out whether the
    /// enum broke or a child turned up on two courts.
    @Test("Two kids are two different pushed screens")
    func twoKidsAreTwoPushedScreens() {
        let first = Player.ID()
        let second = Player.ID()

        #expect(PushedScreen.player(first).id != PushedScreen.player(second).id)
        #expect(PushedScreen.player(first).id == PushedScreen.player(first).id)
    }

    /// And the other half of "every name is its own tap", which is a fact about the roster walk
    /// rather than about the route: a child standing on two courts at once would put the same kid
    /// behind two names on one screen.
    @Test("No kid is drawn on two cards at once")
    func nobodyIsOnTwoCourts() {
        let rows = TodayCourts.rosters(in: SampleData.uclaTennisCamp, day: .wed)
            .values
            .flatMap(\.rows)
        #expect(rows.count > 1)

        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    // `8j`'s half — that a coach's Overview can only open the kids on their own court — is not
    // asserted here, deliberately. It is entirely a property of the narrowing
    // `OverviewScreen.body` passes to `rosters(in:day:venueID:courts:)`, and the suite at the top
    // of this file already pins that four ways. A fifth test rebuilding the same dealt camp and
    // asking the same call the same question would look like coverage of the route and be
    // coverage of `courts:`, which is worse than not having it.
}
