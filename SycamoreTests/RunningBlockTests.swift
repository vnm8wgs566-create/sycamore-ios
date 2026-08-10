//
//  RunningBlockTests.swift
//  SycamoreTests
//
//  What the camp is in the middle of — `ScheduleBlock.running(in:at:)` and its per-court form.
//
//  A file of its own because the rule has a history and the history is the reason for most of what
//  is pinned here. It used to return one block, chosen as *the last one to have started, unless it
//  has ended*, and that sentence was true only while a venue could be doing one thing at a time.
//  `ScheduleBlockKind.assigned` with `courtIDs` ended that, and the failure was not a near miss:
//  two blocks tied on `starts_at`, `max(by:)` keeping whichever the array held first, and the
//  "unless it has ended" then discarding the pair — so the app reported **an empty morning** with
//  twenty-two children on court. Which of the two won depended on array order, and
//  `scheduleBlocks(forVenue:day:campID:)` guarantees none.
//
//  So almost every test here goes through `titles(in:at:)`, which asks the same day twice — once
//  as given, once reversed — and fails if the two disagree. Order-independence is not a property
//  worth one test; it is the property that broke, and it should break these tests everywhere at
//  once if it breaks again.
//
//  Where two blocks tie on `startsAt` the answer is compared as a `Set`. The tie is broken on the
//  id and the ids are freshly minted here, so *which* of two tied blocks sorts first is not a fact
//  about the rule — only that the same one always does, which is what the two-orders check already
//  covers.
//
//  That tie-break is `UUID.precedes(_:)` now rather than `id.uuidString <`, which is a change to
//  how it is computed and not to what it decides. `TheTieBreak` at the foot of this file is where
//  that claim is checked instead of argued.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()
private let court1 = Group.ID()
private let court2 = Group.ID()
private let court3 = Group.ID()
private let court4 = Group.ID()

private func block(
    _ title: String,
    _ start: TimeOfDay,
    _ end: TimeOfDay? = nil,
    on courts: [Group.ID] = [],
    kind: ScheduleBlockKind? = nil,
    venue: Venue.ID = venueID,
    day: Weekday = .wed
) -> ScheduleBlock {
    ScheduleBlock(
        venueID: venue,
        day: day,
        startsAt: start,
        endsAt: end,
        title: title,
        // Named courts make it an assigned block, which is the only kind that has any — `block()`
        // on the draft drops them off a regular one. Overridable for the one case that needs to
        // say otherwise: an assigned block nobody has finished picking courts for.
        kind: kind ?? (courts.isEmpty ? .regular : .assigned),
        courtIDs: courts
    )
}

/// The running blocks' titles — asked of the day as given *and* of the day reversed.
///
/// The whole bug was an array order deciding the answer, so every test that uses this gets the
/// refutation of that for free rather than one test somewhere carrying it alone.
private func titles(
    in day: [ScheduleBlock], at time: TimeOfDay, _ location: SourceLocation = #_sourceLocation
) -> [String] {
    let forwards = ScheduleBlock.running(in: day, at: time).map(\.title)
    let backwards = ScheduleBlock.running(in: day.reversed(), at: time).map(\.title)
    #expect(forwards == backwards, "the answer moved with the array order", sourceLocation: location)
    return forwards
}

// MARK: - The morning the old rule could not describe

@Suite("ScheduleBlock.running — two courts at once")
struct RunningOnTwoCourtsTests {

    /// The design's own example, and the arrangement `BlockRules.sharesSpace` exists to permit.
    private var morning: [ScheduleBlock] {
        [
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(9, 15), on: [court1]),
            block("Free play", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court2, court3, court4]),
        ]
    }

    @Test("Two blocks on disjoint courts both run, however the day is ordered")
    func bothRun() {
        #expect(Set(titles(in: morning, at: TimeOfDay(9, 10))) == ["Warm-up", "Free play"])
    }

    /// **The bug, exactly.** The two tie on `starts_at`; the short one has finished and the long
    /// one has fifty minutes left. Asked for a single block, the old rule kept whichever the array
    /// held first and — when that was the warm-up — answered *nothing running*, so Overview's
    /// `RunningBlockCard` vanished and `8k`'s "On now" went out while free play was on.
    @Test("The short one ending does not take the long one with it")
    func theShortOneEndingLeavesTheLongOne() {
        #expect(titles(in: morning, at: TimeOfDay(9, 20)) == ["Free play"])
    }

    /// The same tie with the courts overlapping rather than disjoint. It is a clash the schedule
    /// flags — `BlockRules.overlap(with:in:)` — but a flagged morning still has to be described,
    /// and "nothing is running" is not a description of it.
    @Test("A block that has ended beside one that has not, in the same space")
    func endedBesideRunning() {
        let day = [
            block("Huddle", TimeOfDay(9, 0), TimeOfDay(9, 15)),
            block("Skills rotation", TimeOfDay(9, 0), TimeOfDay(10, 0)),
        ]

        #expect(Set(titles(in: day, at: TimeOfDay(9, 10))) == ["Huddle", "Skills rotation"])
        #expect(titles(in: day, at: TimeOfDay(9, 20)) == ["Skills rotation"])
    }

    /// The old rule's "latest start wins" was never a fact about a block — it was a proxy for
    /// *blocks do not overlap*, which held only while the app refused an overlap. PR #53 stopped
    /// refusing them, and the proxy then produced this: a warm-up with a quarter of an hour left
    /// on it reported as over, because something shorter had started and finished inside it.
    @Test("A block with a stated end runs until it, whatever starts and finishes inside it")
    func aStatedEndIsTheEnd() {
        let day = [
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court1]),
            block("Handover", TimeOfDay(9, 30), TimeOfDay(9, 40), on: [court1]),
        ]

        #expect(titles(in: day, at: TimeOfDay(9, 45)) == ["Warm-up"])
    }
}

// MARK: - What ends a block that never said

@Suite("ScheduleBlock.running — the open-ended block")
struct RunningOpenEndedTests {

    /// `ends_at` is nullable by design — the design's 8:30 "Drop-off · done" has no stated end —
    /// so something has to close it, and the honest candidate is whatever starts next where it was
    /// standing.
    @Test("It runs until the next thing in its space starts")
    func nextInSpaceEndsIt() {
        let day = [
            block("Drop-off", TimeOfDay(8, 30)),
            block("Skills rotation", TimeOfDay(9, 0), TimeOfDay(10, 0)),
        ]

        #expect(titles(in: day, at: TimeOfDay(8, 45)) == ["Drop-off"])
        #expect(titles(in: day, at: TimeOfDay(9, 30)) == ["Skills rotation"])
    }

    /// Read any other way, 8:30 "Drop-off" is the activity on every court all afternoon. The
    /// superseding block need only have *started* — it does not have to still be running — or the
    /// same bug arrives in instalments, the drop-off springing back to life at the end of every
    /// block that follows it.
    @Test("It stays ended after the block that ended it has itself ended")
    func itDoesNotComeBack() {
        let day = [
            block("Drop-off", TimeOfDay(8, 30)),
            block("Huddle", TimeOfDay(9, 0), TimeOfDay(9, 5)),
        ]

        #expect(titles(in: day, at: TimeOfDay(11, 30)).isEmpty)
    }

    /// The other half of the same rule: a block starting on courts this one never touches has no
    /// business ending it.
    @Test("A block on disjoint courts does not end it")
    func disjointCourtsDoNotEndIt() {
        let day = [
            block("Open hitting", TimeOfDay(8, 30), on: [court1]),
            block("Free play", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court2, court3]),
        ]

        #expect(Set(titles(in: day, at: TimeOfDay(9, 30))) == ["Open hitting", "Free play"])
    }

    /// Every block `DayShape` writes is open-ended — `applyDayShape` sends no `ends_at` at all —
    /// so a day built from a shape is the case this rule is most often asked about. Exactly one
    /// runs at a time, and the last one runs on to the end of the day.
    @Test("A day of open-ended blocks runs one at a time")
    func aShapeBuiltDay() {
        let day = [
            block("Drop-off", TimeOfDay(8, 30)),
            block("Warm-up", TimeOfDay(9, 0)),
            block("Skills rotation", TimeOfDay(10, 0)),
        ]

        #expect(titles(in: day, at: TimeOfDay(8, 45)) == ["Drop-off"])
        #expect(titles(in: day, at: TimeOfDay(9, 30)) == ["Warm-up"])
        #expect(titles(in: day, at: TimeOfDay(16, 0)) == ["Skills rotation"])
    }

    /// An assigned block nobody has finished picking courts for claims the venue, which is
    /// `BlockRules.sharesSpace`'s deliberate reading of an empty list: the rule is about what a
    /// block has *said*, and that one has not finished saying it.
    @Test("An assigned block with no courts picked still ends an open-ended one")
    func anUnfinishedAssignedBlockClaimsTheVenue() {
        let day = [
            block("Drop-off", TimeOfDay(8, 30)),
            block("Untitled", TimeOfDay(9, 0), TimeOfDay(10, 0), kind: .assigned),
        ]

        #expect(titles(in: day, at: TimeOfDay(9, 30)) == ["Untitled"])
    }
}

// MARK: - The edges of the day

@Suite("ScheduleBlock.running — nothing on")
struct RunningNothingTests {

    @Test("An empty day is running nothing")
    func emptyDay() {
        #expect(titles(in: [], at: TimeOfDay(9, 30)).isEmpty)
    }

    @Test("Before the first block, and after the last")
    func outsideTheDay() {
        let day = [block("Warm-up", TimeOfDay(9, 0), TimeOfDay(9, 30))]

        #expect(titles(in: day, at: TimeOfDay(8, 0)).isEmpty)
        #expect(titles(in: day, at: TimeOfDay(9, 45)).isEmpty)
    }

    /// Half-open, like `BlockRules.overlaps`: a block that ends at 9:30 is not running at 9:30,
    /// and the one starting then is.
    @Test("The boundary belongs to the block starting on it")
    func theBoundary() {
        let day = [
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(9, 30)),
            block("Skills rotation", TimeOfDay(9, 30), TimeOfDay(10, 0)),
        ]

        #expect(titles(in: day, at: TimeOfDay(9, 30)) == ["Skills rotation"])
    }

    /// `sharesSpace` guards venue and day, and this is what that guard buys here: handed a list
    /// spanning either, a block cannot end one it could never have been standing next to. Nothing
    /// in the app passes such a list today — every caller is scoped to one venue and one day — and
    /// the rule should not start depending on that.
    @Test("A block at another venue, or on another day, ends nothing here")
    func otherVenuesAndDays() {
        let day = [
            block("Drop-off", TimeOfDay(8, 30)),
            block("Elsewhere", TimeOfDay(9, 0), TimeOfDay(10, 0), venue: Venue.ID()),
            block("Tomorrow", TimeOfDay(9, 0), TimeOfDay(10, 0), day: .thu),
        ]

        #expect(titles(in: day, at: TimeOfDay(9, 30)).contains("Drop-off"))
    }

    /// Sorted by start, so a caller drawing a list of them gets the morning in the order it
    /// happened rather than the order the query returned.
    @Test("They come back earliest first")
    func sortedByStart() {
        let day = [
            block("Free play", TimeOfDay(9, 30), TimeOfDay(11, 0), on: [court3]),
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(11, 0), on: [court1]),
            block("Drills", TimeOfDay(10, 0), TimeOfDay(11, 0), on: [court2]),
        ]

        #expect(titles(in: day, at: TimeOfDay(10, 30)) == ["Warm-up", "Free play", "Drills"])
    }
}

// MARK: - What is on my court

@Suite("ScheduleBlock.running(on:in:at:)")
struct RunningOnACourtTests {

    private var morning: [ScheduleBlock] {
        [
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(9, 15), on: [court1]),
            block("Free play", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court2, court3, court4]),
        ]
    }

    private func running(on court: Group.ID, at time: TimeOfDay) -> String? {
        let forwards = ScheduleBlock.running(on: court, in: morning, at: time)?.title
        let backwards = ScheduleBlock.running(on: court, in: morning.reversed(), at: time)?.title
        #expect(forwards == backwards, "the answer moved with the array order")
        return forwards
    }

    @Test("Each court gets the block that is actually on it")
    func eachCourtItsOwn() {
        #expect(running(on: court1, at: TimeOfDay(9, 10)) == "Warm-up")
        #expect(running(on: court3, at: TimeOfDay(9, 10)) == "Free play")
    }

    /// The answer the venue-wide rule could not give, and the reason Overview asks this one. A
    /// coach on Court 1 at twenty past nine is between blocks; telling them the free play on
    /// Courts 2–4 is on would be telling them to go and run it.
    @Test("A court with nothing on it says so, while the rest of the venue is mid-session")
    func nothingOnMyCourt() {
        #expect(running(on: court1, at: TimeOfDay(9, 20)) == nil)
        #expect(running(on: court3, at: TimeOfDay(9, 20)) == "Free play")
    }

    /// One court really can have two blocks on it — a stated end is not superseded, so a warm-up
    /// and a handover inside it are both running. That is a clash the schedule flags, and the card
    /// answers with the earliest-started rather than pretending there was never a question. See
    /// `running(on:in:at:)` for why earliest and not most-recent.
    @Test("Two blocks on one court answer with the earliest, and hold still")
    func twoOnOneCourt() {
        let day = [
            block("Handover", TimeOfDay(9, 30), TimeOfDay(9, 40), on: [court1]),
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court1]),
        ]

        // Before, during and after the handover — the same answer throughout, which is the point.
        for time in [TimeOfDay(9, 20), TimeOfDay(9, 35), TimeOfDay(9, 45)] {
            #expect(ScheduleBlock.running(on: court1, in: day, at: time)?.title == "Warm-up")
            #expect(
                ScheduleBlock.running(on: court1, in: day.reversed(), at: time)?.title == "Warm-up"
            )
        }
    }

    /// A block that names no courts claims the venue, so it is on every court in it — which is
    /// what makes lunch show up on a coach's own card.
    @Test("A regular block is on every court")
    func regularBlocksAreEverywhere() {
        let day = [block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0))]

        for court in [court1, court2, court3, court4] {
            #expect(ScheduleBlock.running(on: court, in: day, at: TimeOfDay(12, 30))?.title == "Lunch")
        }
    }

    /// A court the venue does not have is a court no assigned block names, and the regular blocks
    /// claim it along with everything else. Reached in the app only by a stale assignment, which
    /// `OverviewView.viewerCourtID` filters out before it gets here — this pins what happens if
    /// one ever does.
    @Test("A court no block has heard of gets the venue-wide blocks and nothing more")
    func anUnknownCourt() {
        let stranger = Group.ID()

        #expect(ScheduleBlock.running(on: stranger, in: morning, at: TimeOfDay(9, 10)) == nil)

        let withLunch = morning + [block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0))]
        #expect(
            ScheduleBlock.running(on: stranger, in: withLunch, at: TimeOfDay(12, 30))?.title
                == "Lunch"
        )
    }
}

// MARK: - The deciding vote between two blocks that tie

/// `UUID.precedes(_:)` (`Models.swift:27-64`), which is the sort's tie-break.
///
/// It replaced `id.uuidString < id.uuidString` for cost — that spelling renders a 36-character
/// `String` on each side of every comparison, and `CoachAvailability.map` runs this sort once per
/// keystroke in the block editor's title field. The replacement is only safe if it is the *same*
/// total order, because a different one would silently reshuffle every list that ties, and nothing
/// on screen would look wrong.
///
/// It is: `uuidString` is the sixteen bytes as fixed-width upper-case hex, hex digits order the
/// way the nibbles they stand for do, both strings are the same length, and the dashes sit at the
/// same four positions in both. That is an argument, so here is the check.
@Suite("The tie-break")
struct TheTieBreak {

    /// Random ids rather than a handful of literals, because the interesting pairs are the ones
    /// that agree for the first several bytes and the digit-versus-letter boundary (`9` next to
    /// `A`) which a hand-picked pair would have to be chosen to hit.
    @Test("It is the order `uuidString` gives, over a thousand pairs")
    func uuidStringOrderMatchesBytes() {
        for _ in 0..<1_000 {
            let left = UUID()
            let right = UUID()
            #expect(left.precedes(right) == (left.uuidString < right.uuidString))
        }
    }

    /// The three laws a `sorted(by:)` predicate has to obey, and the one that bites: an id must
    /// not precede itself, or a tie between a block and itself becomes a strict ordering and the
    /// sort is free to do anything.
    @Test("Irreflexive, asymmetric, and total over distinct ids")
    func itIsAStrictTotalOrder() {
        let id = UUID()
        #expect(!id.precedes(id))

        for _ in 0..<100 {
            let left = UUID()
            let right = UUID()
            #expect(left.precedes(right) != right.precedes(left))
        }
    }

    /// The property the sort actually needs, stated where a reader of this file will look for it:
    /// two blocks tied on the minute come back in the same order however the day was handed over.
    @Test("Two blocks starting on the same minute hold their order between reads")
    func tiedBlocksDoNotSwap() {
        let day = [
            block("Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court1]),
            block("Free play", TimeOfDay(9, 0), TimeOfDay(10, 0), on: [court2]),
        ]

        let forwards = ScheduleBlock.running(in: day, at: TimeOfDay(9, 30)).map(\.id)
        let backwards = ScheduleBlock.running(in: day.reversed(), at: TimeOfDay(9, 30)).map(\.id)

        #expect(forwards == backwards)
        #expect(forwards == day.map(\.id).sorted { $0.precedes($1) })
    }
}
