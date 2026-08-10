//
//  ScheduleLiveConflictTests.swift
//  SycamoreTests
//
//  The amber flag while a finger is still down: what it says, and whether it says the same thing a
//  moment later when the store has caught up.
//
//  `ScheduleResizeTests` pins the arithmetic of the drag and `BlockEditorDraftTests` pins the rule
//  that decides what a clash is. Neither covers the seam this file is about, which is the one 5c
//  added: the card asks that rule about times **nobody has written down yet**. Two ways for that to
//  be wrong look right on a device — a flag that never appears until the finger lifts, and one that
//  appears and then contradicts itself the instant the write lands — and both are invisible in a
//  screenshot, which is what puts them here.
//
//  The copy is pinned character-for-character rather than described. It is the same sentence in
//  four places now (`8k`'s card, `8l`, a rotor's reading of the card, and the block editor's advice
//  built from the same clause), and the way a design string drifts is one of the four being
//  retyped.
//

import Foundation
import Testing

@testable import Sycamore

@Suite("The overlap flag, live")
struct ScheduleLiveConflictTests {

    private let venue = SampleData.sycamore.id

    private func block(
        _ title: String,
        _ startsAt: TimeOfDay,
        _ endsAt: TimeOfDay?,
        kind: ScheduleBlockKind = .regular,
        courtIDs: [Group.ID] = []
    ) -> ScheduleBlock {
        ScheduleBlock(
            venueID: venue, day: .tue, startsAt: startsAt, endsAt: endsAt, title: title,
            kind: kind, courtIDs: courtIDs
        )
    }

    // MARK: What it says

    @Test("The line is the design's, word for word")
    func theSentenceIsTheDesigns() {
        // `design/rebuild/section-t5.html:169`, on a card whose bottom edge has been pulled from
        // 12:00 to 12:15: `Runs into Cool-down at 12:00pm`.
        let matchPlay = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 15))
        let coolDown = block("Cool-down", TimeOfDay(12, 0), TimeOfDay(12, 30))

        #expect(coolDown.runsIntoLine(from: matchPlay.startsAt) == "Runs into Cool-down at 12:00pm")
    }

    @Test("The minute quoted is where the overlap begins, not where the other block begins")
    func theMinuteIsTheOverlapsOwn() {
        // A block *carried down* onto one already running. The neighbour started at ten without
        // it, so the minute the two are on top of each other is the dragged block's own new start
        // — which is the half of this the `max` exists for.
        let neighbour = block("Free play", TimeOfDay(10, 0), TimeOfDay(11, 0))

        #expect(neighbour.runsIntoLine(from: TimeOfDay(10, 15)) == "Runs into Free play at 10:15am")
        // …and from above it, the neighbour's own start is still the answer.
        #expect(neighbour.runsIntoLine(from: TimeOfDay(9, 30)) == "Runs into Free play at 10:00am")
    }

    @Test("The property and the method are one sentence, so the four screens cannot drift")
    func clashLineIsTheSameSentence() {
        let lunch = block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0))

        #expect(lunch.clashLine == "Runs into Lunch at 12:00pm")
        #expect(lunch.clashLine == lunch.runsIntoLine(from: lunch.startsAt))
    }

    @Test("A rotor hears the flag rather than only seeing it")
    func theSpokenLineCarriesIt() {
        let matchPlay = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 15))
        let lunch = block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0))

        let spoken = matchPlay.accessibilityLine(isCurrent: false, conflict: lunch)

        #expect(spoken.contains("Runs into Lunch at 12:00pm"))
        // Amber is the whole of the warning on screen and a colour is not available to somebody
        // listening, which is the argument on `accessibilityLine` itself.
        #expect(spoken == "10:45am, Match play, Runs into Lunch at 12:00pm")
    }

    // MARK: When it is asked

    @Test("A drag creates a flag the day's own index cannot see yet")
    func theLiveFlagLeadsTheStore() {
        // The design's case, on the app's own Tuesday: `Match play` runs 10:45–12:00 with `Lunch`
        // starting exactly where it ends, so the morning is in order and nothing is flagged.
        let day = ScheduleSampleDay.blocks(venueID: venue)
        let matchPlay = day[3]
        #expect(matchPlay.title == "Match play")
        #expect(ScheduleConflicts(day: day)[matchPlay.id] == nil)

        // A quarter-hour of drag later, and before any write at all:
        let live = ScheduleConflicts.live(
            matchPlay, startsAt: matchPlay.startsAt, endsAt: TimeOfDay(12, 15), in: day
        )

        #expect(live?.title == "Lunch")
        #expect(live?.runsIntoLine(from: matchPlay.startsAt) == "Runs into Lunch at 12:00pm")
    }

    @Test("A drag back out of a clash clears it, which the store's index cannot do either")
    func theLiveFlagAlsoGoesAway() {
        // The state the old line got backwards: a block that *is* clashing, being dragged out of
        // it. The card used to hold the pre-drag answer for the whole gesture, so it went on
        // naming a block the finger had already left.
        let lunch = block("Lunch", TimeOfDay(12, 0), TimeOfDay(13, 0))
        var matchPlay = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 30))
        let day = [matchPlay, lunch]

        #expect(ScheduleConflicts(day: day)[matchPlay.id]?.title == "Lunch")

        let live = ScheduleConflicts.live(
            matchPlay, startsAt: matchPlay.startsAt, endsAt: TimeOfDay(12, 0), in: day
        )
        #expect(live == nil)

        // …and the stored day is untouched by having been asked. A live question that edited the
        // day would be a drag that wrote per frame, which is the one thing the commit is guarded
        // to prevent.
        matchPlay.endsAt = TimeOfDay(12, 30)
        #expect(day[0] == matchPlay)
    }

    @Test("The block's own stale twin in the day is not something it can run into")
    func aBlockNeverClashesWithItself() {
        // The day handed down always still holds this block at the times the store has for it, so
        // the very first thing a live question could get wrong is flagging the copy of itself.
        let matchPlay = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0))
        let day = [matchPlay]

        #expect(
            ScheduleConflicts.live(
                matchPlay, startsAt: matchPlay.startsAt, endsAt: TimeOfDay(13, 0), in: day
            ) == nil
        )
    }

    @Test("A move asks about both times, so carrying a block up flags what is above it")
    func aMoveFlagsInBothDirections() {
        let warmUp = block("Warm-up", TimeOfDay(9, 0), TimeOfDay(10, 0))
        let matchPlay = block("Match play", TimeOfDay(10, 45), TimeOfDay(12, 0))
        let day = [warmUp, matchPlay]

        // Carried up by three quarters of an hour: both times move together, and what it lands on
        // is the block *before* it — which a resize could never reach.
        let live = ScheduleConflicts.live(
            matchPlay, startsAt: TimeOfDay(9, 45), endsAt: TimeOfDay(11, 0), in: day
        )

        #expect(live?.title == "Warm-up")
        #expect(live?.runsIntoLine(from: TimeOfDay(9, 45)) == "Runs into Warm-up at 9:45am")
    }

    @Test("The live question is the same rule, so disjoint courts are still not a clash")
    func itDoesNotSecondGuessTheRule() {
        // The distinction the whole court model turns on (`BlockRules.sharesSpace`): two blocks on
        // courts that do not touch may run at the same time. A live flag with its own idea of what
        // an overlap is would stop a finger on Court 1's edge with a warning about Court 4.
        let one = Group.ID()
        let two = Group.ID()
        let drills = block(
            "Drills", TimeOfDay(9, 0), TimeOfDay(10, 0), kind: .assigned, courtIDs: [one]
        )
        let rally = block(
            "Rally", TimeOfDay(10, 0), TimeOfDay(11, 0), kind: .assigned, courtIDs: [two]
        )
        let day = [drills, rally]

        #expect(
            ScheduleConflicts.live(
                drills, startsAt: drills.startsAt, endsAt: TimeOfDay(11, 0), in: day
            ) == nil
        )

        // …and the same drag against a block that *does* share the court is flagged, so the case
        // above is the rule biting rather than the question never being asked.
        let sameCourt = block(
            "Match play", TimeOfDay(10, 0), TimeOfDay(11, 0), kind: .assigned, courtIDs: [one, two]
        )
        #expect(
            ScheduleConflicts.live(
                drills, startsAt: drills.startsAt, endsAt: TimeOfDay(11, 0), in: [drills, sameCourt]
            )?.title == "Match play"
        )
    }

    @Test("A block with no stated end is flagged by neither half of the question")
    func anOpenEndedDragFlagsNothing() {
        // `BlockRules.overlaps` refuses both directions for a block with no `ends_at`, and a move
        // is the one drag that can be started on one. Reading it as running until midnight is the
        // reading that would flag every block after every drop-off in the app.
        let dropOff = block("Drop-off", TimeOfDay(8, 30), nil)
        let skills = block("Skills rotation", TimeOfDay(9, 0), TimeOfDay(10, 30))
        let day = [dropOff, skills]

        #expect(
            ScheduleConflicts.live(dropOff, startsAt: TimeOfDay(9, 15), endsAt: nil, in: day) == nil
        )
    }

    // MARK: The two answers, either side of the write

    @Test("What the finger was told is what the day says once the write lands")
    func theLiveAndSettledAnswersAgree() {
        // The failure this is really about is not a wrong flag but a *changing* one: an amber line
        // naming Lunch under the finger and naming something else — or nothing — a round trip
        // later would be the app contradicting itself across a single lift of a hand. Both sides
        // go through `BlockRules.overlap(with:in:)`, and this is what says they cannot part.
        let day = ScheduleSampleDay.blocks(venueID: venue)
        let dragged = day[1]
        #expect(dragged.title == "Skills rotation")

        for minutes in stride(from: 0, through: 180, by: 15) {
            let end = TimeOfDay((600 + minutes) / 60, (600 + minutes) % 60)

            let live = ScheduleConflicts.live(
                dragged, startsAt: dragged.startsAt, endsAt: end, in: day
            )

            var written = dragged
            written.endsAt = end
            let after = day.map { $0.id == written.id ? written : $0 }

            #expect(live == ScheduleConflicts(day: after)[written.id])
        }
    }

    @Test("Every quarter-hour a ±400pt drag can reach is asked and answered the same way")
    func theWholeReachOfADragAgrees() {
        // The sweep `ScheduleResizeTests.settlesOnTheEditorsGrid` runs, asked of the flag instead
        // of the grid: the plan and the rule are driven together, so nothing in the reachable
        // range of one gesture can produce a flag the day would then disown.
        let day = ScheduleSampleDay.blocks(venueID: venue)
        let dragged = day[3]
        var plan = ScheduleResizePlan(
            startsAt: dragged.startsAt,
            endsAt: dragged.endsAt ?? TimeOfDay(12, 0),
            travelPerStep: ScheduleResizePlan.travel
        )

        for points in stride(from: CGFloat(-400), through: 400, by: 11) {
            plan.drag(by: points)

            let live = ScheduleConflicts.live(
                dragged, startsAt: plan.startsAt, endsAt: plan.endsAt, in: day
            )

            var written = dragged
            written.endsAt = plan.endsAt
            let after = day.map { $0.id == written.id ? written : $0 }

            #expect(live == ScheduleConflicts(day: after)[written.id])
            // …and the flag never blocks: the plan settles on the grid whatever it has run into.
            #expect(BlockClock.options.contains(plan.endsAt))
        }
    }
}
