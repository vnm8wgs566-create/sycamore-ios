//
//  OverviewFourATests.swift
//  SycamoreTests
//
//  The three things `4a` asks Overview to derive that nothing derived before: how long is left of
//  the block that is running, what starts after it, and what to write under its title.
//
//  Worth pinning for the reason `OverviewNowTests` gives about the block itself: none of it looks
//  wrong when it is wrong. "41 min left" counting from the wrong clock still reads as a countdown.
//  A "Next · …" naming a block that has already started still reads as a plan. A meta line that
//  printed a middot with nothing after it would be the one thing on the screen a reader *would*
//  notice, and it is exactly what three optional clauses joined carelessly produce.
//
//  The date line is here too, because "day 2 of 5" is arithmetic over a camp's own week and is the
//  half of `CampDays` nothing could previously count.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private let venueID = Venue.ID()

private func block(
    _ title: String,
    from start: TimeOfDay,
    to end: TimeOfDay? = nil,
    coaches: [StaffMember.ID] = [],
    courts: [Group.ID] = []
) -> ScheduleBlock {
    ScheduleBlock(
        venueID: venueID,
        day: .wed,
        startsAt: start,
        endsAt: end,
        title: title,
        coachIDs: coaches,
        // Naming courts is what makes a block assigned; left `.regular` it would claim the whole
        // venue and the per-court cases below would pass for the wrong reason.
        kind: courts.isEmpty ? .regular : .assigned,
        courtIDs: courts
    )
}

// MARK: - How long is left

@Suite("OverviewNow — the countdown")
struct OverviewNowCountdownTests {

    @Test("Minutes are counted from the clock the card was resolved at")
    func countsFromTheResolveClock() {
        let running = block("Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30))
        let now = OverviewNow(block: running, coaches: [], at: TimeOfDay(9, 49))

        #expect(now.minutesLeft == 41)
        #expect(now.remainingLabel == "41 min left")
        #expect(now.statusLine == "On now · 41 min left")
        #expect(now.endsLabel == "ends 10:30")
    }

    /// A block nobody gave an end has nothing to count down to. The card draws the plain label and
    /// no trailing figure rather than a middot with nothing after it.
    @Test("A block with no end says On now and stops")
    func noEndNoCountdown() {
        let running = block("Lunch", from: TimeOfDay(12, 0))
        let now = OverviewNow(block: running, coaches: [], at: TimeOfDay(12, 15))

        #expect(now.minutesLeft == nil)
        #expect(now.remainingLabel == nil)
        #expect(now.statusLine == "On now")
        #expect(now.endsLabel == nil)
    }

    /// `OverviewNow` can be built directly — the previews and these tests both do — so a value with
    /// no clock has to draw the card rather than crash it or invent a figure.
    @Test("No clock is no countdown")
    func noClockNoCountdown() {
        let running = block("Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30))
        let now = OverviewNow(block: running, coaches: [])

        #expect(now.minutesLeft == nil)
        #expect(now.statusLine == "On now")
        // The end is a fact about the block and is still drawn: 4a's trailing "ends 10:30" does not
        // depend on knowing what time it is.
        #expect(now.endsLabel == "ends 10:30")
    }

    /// `ScheduleBlock.running` will not hand back a finished block, but this type can be built with
    /// any clock at all, and "-3 min left" is the one reading that must never reach a card.
    @Test("A block already past its end reports nothing, never a negative")
    func neverNegative() {
        let running = block("Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30))

        #expect(OverviewNow(block: running, coaches: [], at: TimeOfDay(10, 33)).minutesLeft == nil)
        // And the boundary: at the stated end the block is over, not down to its last zero minutes.
        #expect(OverviewNow(block: running, coaches: [], at: TimeOfDay(10, 30)).minutesLeft == nil)
    }

    /// Minutes all the way up, matching `ScheduleDay.statusLine` on `8k`. The two screens read the
    /// same block within a tab of each other and must not spell one morning two ways.
    @Test("A long block counts in minutes, as Schedule does")
    func minutesAllTheWayUp() {
        let running = block("Free play", from: TimeOfDay(9, 0), to: TimeOfDay(11, 0))
        let now = OverviewNow(block: running, coaches: [], at: TimeOfDay(9, 2))

        #expect(now.remainingLabel == "118 min left")
        #expect(
            ScheduleDay.statusLine(for: running, isCurrent: true, now: TimeOfDay(9, 2))
                == "On now · 118 min left"
        )
    }
}

// MARK: - What is next

@Suite("OverviewNow — what follows")
struct OverviewNowNextTests {

    @Test("The next block is the earliest one still to start")
    func theEarliestStillToStart() {
        let day = [
            block("Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30)),
            block("Lunch", from: TimeOfDay(12, 0)),
            block("Water & regroup", from: TimeOfDay(10, 30), to: TimeOfDay(10, 45)),
        ]

        let now = OverviewNow.resolve(in: day, at: TimeOfDay(9, 49), staff: [])

        #expect(now?.next?.title == "Water & regroup")
        #expect(now?.nextLine == "Next · Water & regroup · 10:30")
    }

    /// The last block of the day draws no rule and no footer, rather than "Next · nothing".
    @Test("Nothing after it is nothing drawn")
    func nothingFollows() {
        let day = [block("Free play", from: TimeOfDay(15, 0), to: TimeOfDay(16, 0))]

        let now = OverviewNow.resolve(in: day, at: TimeOfDay(15, 30), staff: [])

        #expect(now?.next == nil)
        #expect(now?.nextLine == nil)
    }

    /// Strictly after the clock. A block beginning on this very minute is *running* — which is
    /// where `ScheduleBlock.running(in:at:)` draws the same line — and announcing it as next would
    /// put a block on the footer that is already on the card.
    @Test("A block starting this minute is on now, not next")
    func startingNowIsNotNext() {
        let day = [
            block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(10, 0)),
            block("Handover", from: TimeOfDay(9, 30), to: TimeOfDay(9, 40)),
            block("Lunch", from: TimeOfDay(12, 0)),
        ]

        let now = OverviewNow.resolve(in: day, at: TimeOfDay(9, 30), staff: [])

        #expect(now?.title == "Warm-up")
        #expect(now?.next?.title == "Lunch")
    }

    /// A venue running two blocks at once has two candidates for "next", and the answer follows the
    /// reader exactly as the card itself does: a coach gets what is next on their own court.
    @Test("Next follows the reader's court")
    func nextFollowsTheReader() {
        let court1 = Group.ID()
        let court2 = Group.ID()
        let day = [
            block("Warm-up", from: TimeOfDay(9, 0), to: TimeOfDay(10, 0), courts: [court1]),
            block("Free play", from: TimeOfDay(9, 0), to: TimeOfDay(10, 0), courts: [court2]),
            block("Ladder", from: TimeOfDay(10, 0), to: TimeOfDay(11, 0), courts: [court2]),
            block("Serves", from: TimeOfDay(10, 30), to: TimeOfDay(11, 0), courts: [court1]),
        ]

        let onOne = OverviewNow.resolve(in: day, at: TimeOfDay(9, 30), staff: [], onCourt: court1)
        let onTwo = OverviewNow.resolve(in: day, at: TimeOfDay(9, 30), staff: [], onCourt: court2)
        // An admin has no court and gets the next thing to start anywhere in the venue.
        let admin = OverviewNow.resolve(in: day, at: TimeOfDay(9, 30), staff: [])

        #expect(onOne?.next?.title == "Serves")
        #expect(onTwo?.next?.title == "Ladder")
        #expect(admin?.next?.title == "Ladder")
    }
}

// MARK: - The line under the title

@Suite("OverviewNow.metaLine")
struct OverviewNowMetaLineTests {

    /// The design's camp, because the question is about a real graph: which courts a block names,
    /// how many kids are standing on them, and who is running it.
    private let camp = SampleData.uclaTennisCamp

    private var sycamoreCourts: [Group] { camp.groups(in: SampleData.sycamore.id) }

    @Test("Courts, kids and coaches, in that order, separated by a middot")
    func allThreeClauses() {
        let courts = Array(sycamoreCourts.prefix(3))
        let coach = camp.coach(forGroup: courts[0].id)
        var running = block(
            "Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30),
            coaches: coach.map { [$0.id] } ?? [],
            courts: courts.map(\.id)
        )
        running.venueID = SampleData.sycamore.id
        running.day = camp.days.ordered.first ?? .mon

        let line = OverviewNow(block: running, coaches: []).metaLine(in: camp)

        let kids = courts.flatMap { camp.players(inGroup: $0.id) }
            .count { !camp.isAway($0.id, on: running.day) }
        var expected = "Courts \(courts[0].number)–\(courts[2].number) · \(kids) players"
        if let coach { expected += " · \(coach.name)" }
        #expect(line == expected)
    }

    /// A `.regular` block names no courts, so the first clause drops and the middot with it — the
    /// line reads about the venue, which is what a lunch is about.
    @Test("A block with no courts drops the courts clause, not the separator")
    func regularBlockDropsCourts() {
        var lunch = block("Lunch", from: TimeOfDay(12, 0))
        lunch.venueID = SampleData.sycamore.id
        lunch.day = camp.days.ordered.first ?? .mon

        let line = OverviewNow(block: lunch, coaches: []).metaLine(in: camp)

        #expect(line?.hasPrefix("Courts") == false)
        #expect(line?.hasPrefix(" · ") == false)
        #expect(line?.contains("players") == true)
        // One clause, so no separator at all.
        #expect(line?.contains("·") == false)
    }

    /// Every name, comma-joined — `coachLine(in:)`'s "Nass +2" is for a narrow card, and this line
    /// runs the width of the screen. Knowing three coaches are on without knowing which three is no
    /// use to somebody looking for one of them.
    @Test("Coaches are a comma list, not a count")
    func coachesAreListed() {
        let coaches = Array(camp.staff.prefix(3))
        var running = block(
            "Skills rotation", from: TimeOfDay(9, 30), to: TimeOfDay(10, 30),
            coaches: coaches.map(\.id)
        )
        running.venueID = SampleData.sycamore.id
        running.day = camp.days.ordered.first ?? .mon

        let line = OverviewNow(block: running, coaches: []).metaLine(in: camp)

        #expect(line?.hasSuffix(coaches.map(\.name).joined(separator: ", ")) == true)
    }

    /// No camp, nothing to say. The card draws its title and its button and no empty row under them.
    @Test("No camp is no line")
    func noCampNoLine() {
        let running = block("Skills rotation", from: TimeOfDay(9, 30))

        #expect(OverviewNow(block: running, coaches: []).metaLine(in: nil) == nil)
    }
}

// MARK: - The register behind the button

@Suite("OverviewNow.courtIDs")
struct OverviewNowCourtIDsTests {

    private let camp = SampleData.uclaTennisCamp

    /// A block that names its courts takes the register for exactly those, which is the whole
    /// reason `8l` stopped taking the venue's.
    @Test("A block's own courts, where it names any")
    func namedCourts() {
        let courts = Array(camp.groups(in: SampleData.sycamore.id).prefix(2)).map(\.id)
        var running = block("Warm-up", from: TimeOfDay(9, 0), courts: courts)
        running.venueID = SampleData.sycamore.id

        #expect(OverviewNow(block: running, coaches: []).courtIDs(in: camp) == courts)
    }

    /// And the venue's where it names none — a lunch happens on no court in particular. The same
    /// fallback `BlockDetailView.openAttendance` applies, so the count on the card and the roll
    /// behind the button are the same children.
    @Test("The venue's courts, where it names none")
    func venueFallback() {
        var lunch = block("Lunch", from: TimeOfDay(12, 0))
        lunch.venueID = SampleData.sycamore.id

        let ids = OverviewNow(block: lunch, coaches: []).courtIDs(in: camp)

        #expect(ids == camp.groups(in: SampleData.sycamore.id).map(\.id))
        #expect(!ids.isEmpty)
    }
}

// MARK: - The header's date line

@Suite("OverviewHeader.dateLine")
struct OverviewHeaderDateLineTests {

    private func date(_ day: Int, _ month: Int, _ year: Int = 2026) -> Date {
        DateComponents(
            calendar: .current, timeZone: .current,
            year: year, month: month, day: day, hour: 9, minute: 41
        ).date!
    }

    @Test("The design's own line")
    func theDesignsLine() {
        let line = OverviewHeader.dateLine(for: .tue, on: date(12, 8), days: .weekdays)

        #expect(line == "Tuesday, 12 August · day 2 of 5")
    }

    /// **Counted through the camp's own run, not the calendar's.** A camp running Tuesday and
    /// Thursday makes Thursday its second day; `Weekday.thu.rawValue` is 4, and a header reading
    /// "day 4 of 2" would be that confusion drawn on screen.
    @Test("The index is the camp's own, not the week's")
    func theCampsOwnRun() {
        let line = OverviewHeader.dateLine(for: .thu, on: date(14, 8), days: CampDays([.tue, .thu]))

        #expect(line == "Thursday, 14 August · day 2 of 2")
    }

    /// A day the camp does not open has no position in its run, so the clause drops whole. Never
    /// "day 0 of 5", and never a middot with nothing after it.
    @Test("A day the camp does not run drops the clause and the separator")
    func aDayTheCampIsShut() {
        let line = OverviewHeader.dateLine(for: .sat, on: date(16, 8), days: .weekdays)

        #expect(line == "Saturday, 16 August")
    }

    /// A camp that has not been read yet is the ordinary first frame of a cold open, and the date
    /// is true without it.
    @Test("No camp is still a date")
    func noCamp() {
        #expect(OverviewHeader.dateLine(for: .mon, on: date(1, 6), days: nil) == "Monday, 1 June")
    }
}
