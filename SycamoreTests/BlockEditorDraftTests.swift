//
//  BlockEditorDraftTests.swift
//  SycamoreTests
//
//  The four CHECKs on `schedule_blocks` (and, for a note, on `inbox_items`), the rule about a
//  block's neighbours that no column holds, and the draft that has to answer all five.
//
//  Written for the same reason `CampNameTests` is: the four are enforced *at the write*, and on a
//  create the write happens after the sheet has been dismissed and the draft thrown away. A rule
//  the client does not mirror is a rule that costs somebody their typing.
//
//  Two of the five get a suite each. `endsAfterStart` is the one a two-time-field editor walks into
//  constantly — every drag of the start past the end is a draft the column would refuse. And the
//  clash rule is the one that is not a constraint at all: it is about the row *and the day around
//  it*, no column enforces it, and it refuses nothing. `BlockRules.overlap(with:in:)` carries the
//  argument, including the Postgres EXCLUDE that was written and dropped; what is asserted here is
//  the shape it leaves behind.
//
//  `ScheduleConflictsTests` is here rather than in a file of its own because that type is a cache
//  of exactly these answers, and the thing worth testing about it is that it has not invented a
//  sixth rule on the way.
//

import Testing
@testable import Sycamore

@Suite("BlockRules")
struct BlockRulesTests {

    // MARK: Title — `check (char_length(title) between 1 and 80)`

    @Test("Refuses a title the column would refuse")
    func rejectsTitleOutOfRange() {
        #expect(!BlockRules.isValidTitle(""))
        #expect(!BlockRules.isValidTitle(String(repeating: "a", count: 81)))
    }

    @Test("Accepts both ends of the range the column allows")
    func acceptsTitleBounds() {
        #expect(BlockRules.isValidTitle("a"))
        #expect(BlockRules.isValidTitle(String(repeating: "a", count: 80)))
        #expect(BlockRules.isValidTitle("Skills rotation"))
    }

    /// The reason every count in `BlockRules` is in unicode scalars and not `String.count`.
    ///
    /// Postgres' `char_length` counts characters of the UTF-8 string; Swift's `count` counts
    /// grapheme clusters, and one cluster can be many scalars. Counted the way Swift reads a
    /// string, eighty family emoji are "80 characters" and sail through the client — then land on
    /// a column that sees several hundred and refuses them, after the sheet has closed.
    @Test("Counts the way Postgres counts, not the way Swift reads")
    func countsScalars() {
        let family = "👩‍👩‍👧"
        #expect(family.count == 1)
        #expect(family.unicodeScalars.count > 1)

        // Comfortably inside 80 `Character`s, comfortably outside 80 scalars.
        let manyFamilies = String(repeating: family, count: 20)
        #expect(manyFamilies.count == 20)
        #expect(!BlockRules.isValidTitle(manyFamilies))
    }

    // MARK: Detail — `check (detail is null or char_length(detail) <= 160)`

    @Test("A description has a ceiling but no floor")
    func detailRange() {
        // No lower bound: the column is nullable, and an empty description is stored as null
        // rather than as an empty string.
        #expect(BlockRules.isValidDetail(""))
        #expect(BlockRules.isValidDetail(String(repeating: "a", count: 160)))
        #expect(!BlockRules.isValidDetail(String(repeating: "a", count: 161)))
        #expect(!BlockRules.isValidDetail(String(repeating: "👩‍👩‍👧", count: 40)))
    }

    // MARK: Note — `check (detail is null or char_length(detail) <= 200)` on `inbox_items`

    @Test("A note has both, and the ceiling is the inbox column's rather than the block's")
    func noteRange() {
        #expect(!BlockRules.isValidNote(""))
        #expect(BlockRules.isValidNote("shade tent is up"))
        // 200, not 160: a note is a row of `inbox_items`, not a column on `schedule_blocks`.
        #expect(BlockRules.isValidNote(String(repeating: "a", count: 200)))
        #expect(!BlockRules.isValidNote(String(repeating: "a", count: 201)))
    }
}

@Suite("BlockRules — ends after starts")
struct BlockEndsAfterStartsTests {

    /// `check (ends_at is null or ends_at > starts_at)` — `20260805074039:38-39`.
    @Test("No end time is always allowed")
    func nilEndIsFine() {
        // The design's 8:30 "Drop-off · done" has no stated end, and the column is nullable so it
        // does not have to invent one.
        #expect(BlockRules.endsAfterStart(startsAt: TimeOfDay(8, 30), endsAt: nil))
    }

    @Test("An end after the start is allowed")
    func laterEndIsFine() {
        #expect(BlockRules.endsAfterStart(startsAt: TimeOfDay(9, 0), endsAt: TimeOfDay(10, 30)))
        // Fifteen minutes apart, which is one step of `BlockClock`.
        #expect(BlockRules.endsAfterStart(startsAt: TimeOfDay(10, 30), endsAt: TimeOfDay(10, 45)))
    }

    @Test("An end before the start is refused")
    func earlierEndIsRefused() {
        #expect(!BlockRules.endsAfterStart(startsAt: TimeOfDay(10, 30), endsAt: TimeOfDay(9, 0)))
    }

    /// Strictly greater, like the constraint. A block that ends when it starts is not a block, and
    /// `>=` here would let one through the client and onto a column that uses `>`.
    @Test("An end equal to the start is refused")
    func equalEndIsRefused() {
        #expect(!BlockRules.endsAfterStart(startsAt: TimeOfDay(9, 0), endsAt: TimeOfDay(9, 0)))
    }

    /// The hour crossing, because `TimeOfDay` compares on `hour * 60 + minute` rather than on the
    /// two fields in turn — 9:45 to 10:00 is later, and a comparison written the naive way would
    /// have to be told so.
    @Test("Later across an hour boundary is still later")
    func crossesTheHour() {
        #expect(BlockRules.endsAfterStart(startsAt: TimeOfDay(9, 45), endsAt: TimeOfDay(10, 0)))
        #expect(!BlockRules.endsAfterStart(startsAt: TimeOfDay(10, 0), endsAt: TimeOfDay(9, 45)))
    }
}

/// One venue and three courts, and one way to build a block on them.
///
/// File scope so the two suites below share it, which is `OverviewNowTests`' arrangement and has a
/// sharper reason here: `SectionEight.swift:137-154` records that `ScheduleBlock`'s memberwise
/// initialiser is called positionally in three files and that the type only ever grows at the
/// tail. A second factory is a second place to fix the day a property is added, and two sets of
/// defaults are two suites that can quietly disagree about what a block *is* while testing one
/// rule about them.
private enum ClashFixture {

    static let venueID = Venue.ID()
    static let court1 = CourtGroup.ID()
    static let court2 = CourtGroup.ID()
    static let court3 = CourtGroup.ID()

    /// `courts: nil` is a `.regular` block and `courts: []` is an `.assigned` one nobody has
    /// ticked a court on — two different sentences the rule has to tell apart.
    static func block(
        from startsAt: TimeOfDay,
        to endsAt: TimeOfDay?,
        on day: Weekday = .tue,
        venueID: Venue.ID = ClashFixture.venueID,
        title: String = "Skills rotation",
        courts: [CourtGroup.ID]? = nil
    ) -> ScheduleBlock {
        ScheduleBlock(
            venueID: venueID,
            day: day,
            startsAt: startsAt,
            endsAt: endsAt,
            title: title,
            kind: courts == nil ? .regular : .assigned,
            courtIDs: courts ?? []
        )
    }

    /// A day of abutting blocks: 9:00–10:00, 10:00–10:30, 10:30–12:00.
    static func day() -> [ScheduleBlock] {
        [
            block(from: TimeOfDay(9, 0), to: TimeOfDay(10, 0)),
            block(from: TimeOfDay(10, 0), to: TimeOfDay(10, 30)),
            block(from: TimeOfDay(10, 30), to: TimeOfDay(12, 0)),
        ]
    }
}

/// The rule that is about the day and not about the row: **a clash is an overlap in time *and* a
/// claim on the same space**.
///
/// Two rules come out of it and they must not disagree. `overlap(with:in:)` is what every screen
/// flags on, and `latestEnd(for:in:)` is the minute the block editor offers back — so a morning
/// where one fires and the other stays quiet is a sentence that names a block and then suggests a
/// time that does not fix it.
///
/// The four court cases are the point of the whole suite. A venue-wide rule passes the first three
/// and fails the fourth, and the fourth is the one `ScheduleBlockKind.assigned` was added for.
@Suite("BlockRules — the day around the block")
struct BlockOverlapTests {

    // MARK: The four cases the courts produce

    /// Neither block says where it runs, so both are asking for the venue.
    @Test("Two regular blocks over the same minutes clash")
    func bothRegularClash() {
        let lunch = ClashFixture.block(
            from: TimeOfDay(12, 0), to: TimeOfDay(13, 0), title: "Lunch"
        )
        let briefing = ClashFixture.block(
            from: TimeOfDay(12, 30), to: TimeOfDay(13, 0), title: "Parents' brief"
        )

        #expect(BlockRules.overlap(with: lunch, in: [briefing])?.title == "Parents' brief")
        #expect(BlockRules.overlap(with: briefing, in: [lunch])?.title == "Lunch")
    }

    /// The regular one has claimed the venue, which contains whatever courts the other named.
    @Test("A regular block clashes with an assigned one however few courts it names")
    func regularAgainstAssigned() {
        let lunch = ClashFixture.block(
            from: TimeOfDay(12, 0), to: TimeOfDay(13, 0), title: "Lunch"
        )
        let warmUp = ClashFixture.block(
            from: TimeOfDay(12, 30), to: TimeOfDay(12, 45),
            title: "Warm-up", courts: [ClashFixture.court1]
        )

        #expect(BlockRules.overlap(with: lunch, in: [warmUp])?.title == "Warm-up")
        #expect(BlockRules.overlap(with: warmUp, in: [lunch])?.title == "Lunch")
    }

    @Test("Two assigned blocks sharing one court clash, even with others to themselves")
    func assignedSharingACourt() {
        let drills = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(10, 0),
            title: "Drills", courts: [ClashFixture.court1, ClashFixture.court2]
        )
        let ladder = ClashFixture.block(
            from: TimeOfDay(9, 30), to: TimeOfDay(10, 30),
            title: "Volley ladder", courts: [ClashFixture.court2, ClashFixture.court3]
        )

        #expect(BlockRules.overlap(with: drills, in: [ladder])?.title == "Volley ladder")
        #expect(BlockRules.overlap(with: ladder, in: [drills])?.title == "Drills")
    }

    /// The morning the whole change exists for: "Warm-up only needs 1 court and all kids", with
    /// everybody else on the other three. Same quarter of an hour, no clash.
    @Test("Two assigned blocks on different courts do not clash, however much time they share")
    func assignedOnDifferentCourtsDoNotClash() {
        let warmUp = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(9, 15),
            title: "Warm-up", courts: [ClashFixture.court1]
        )
        let freePlay = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(9, 15),
            title: "Free play", courts: [ClashFixture.court2, ClashFixture.court3]
        )

        #expect(BlockRules.overlap(with: warmUp, in: [freePlay]) == nil)
        #expect(BlockRules.overlap(with: freePlay, in: [warmUp]) == nil)
        // …and neither is a ceiling for the other, so the editor offers no minute to move to.
        #expect(BlockRules.latestEnd(for: warmUp, in: [freePlay]) == nil)
    }

    /// An `.assigned` block nobody has ticked a court on has not finished saying where it runs, so
    /// it claims the venue — the same answer a `.regular` block gets, for the same reason.
    @Test("An assigned block with no courts yet claims the whole venue")
    func assignedWithNoCourtsClaimsTheVenue() {
        var unfinished = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(10, 0), title: "Rotation"
        )
        unfinished.kind = .assigned
        let onOneCourt = ClashFixture.block(
            from: TimeOfDay(9, 30), to: TimeOfDay(10, 30),
            title: "Warm-up", courts: [ClashFixture.court1]
        )

        #expect(unfinished.courtIDs.isEmpty)
        #expect(BlockRules.overlap(with: unfinished, in: [onOneCourt])?.title == "Warm-up")
        #expect(BlockRules.overlap(with: onOneCourt, in: [unfinished])?.title == "Rotation")
    }

    // MARK: The ceiling — `latestEnd(for:in:)`

    @Test("The ceiling is the earliest start after this block, whatever order the day arrives in")
    func findsTheNeighbour() {
        let morning = ClashFixture.day()

        #expect(BlockRules.latestEnd(for: morning[0], in: morning) == TimeOfDay(10, 0))
        #expect(BlockRules.latestEnd(for: morning[0], in: morning.reversed()) == TimeOfDay(10, 0))
        // Nothing follows the last block of the day.
        #expect(BlockRules.latestEnd(for: morning[2], in: morning) == nil)
    }

    @Test("A finished block still occupies its time, whether or not it draws a card")
    func aDoneBlockStillCounts() {
        let venueID = SampleData.sycamore.id
        let sample = ScheduleSampleDay.blocks(venueID: venueID)
        // The 8:30 drop-off is `.done`, and is the only thing before nine.
        let earlier = ScheduleBlock(
            venueID: venueID, day: .tue, startsAt: TimeOfDay(8, 0), endsAt: TimeOfDay(8, 15),
            title: "Set up"
        )
        var overlapping = earlier
        overlapping.endsAt = TimeOfDay(8, 45)

        #expect(BlockRules.latestEnd(for: earlier, in: sample) == TimeOfDay(8, 30))
        #expect(BlockRules.overlap(with: overlapping, in: sample)?.title == "Drop-off")
    }

    /// The ceiling is court-aware too, and this is what says so: a block on Court 1 is not stopped
    /// by one on Court 2, so the editor never offers a minute that would fix nothing.
    @Test("The ceiling skips blocks this one does not share a court with")
    func theCeilingIsCourtAware() {
        let warmUp = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(9, 15),
            title: "Warm-up", courts: [ClashFixture.court1]
        )
        let elsewhere = ClashFixture.block(
            from: TimeOfDay(9, 30), to: TimeOfDay(10, 0),
            title: "Free play", courts: [ClashFixture.court2]
        )
        let here = ClashFixture.block(
            from: TimeOfDay(10, 0), to: TimeOfDay(11, 0),
            title: "Match play", courts: [ClashFixture.court1, ClashFixture.court3]
        )

        #expect(BlockRules.latestEnd(for: warmUp, in: [elsewhere]) == nil)
        #expect(BlockRules.latestEnd(for: warmUp, in: [elsewhere, here]) == TimeOfDay(10, 0))
    }

    /// The two rules held against each other, in the one place they used to part company. An
    /// earlier draft of this made `latestEnd` a step stricter than `overlap` so a drag would stop
    /// at an open-ended neighbour; there is no drag to stop now, and a sentence that quotes a
    /// minute the rule it names does not care about is just wrong.
    @Test("A neighbour with no stated end is neither a clash nor a ceiling")
    func openEndedNeighboursAreNeither() {
        let dropOff = ClashFixture.block(from: TimeOfDay(9, 0), to: nil, title: "Drop-off")
        let setUp = ClashFixture.block(from: TimeOfDay(8, 0), to: TimeOfDay(11, 0), title: "Set up")

        #expect(BlockRules.overlap(with: setUp, in: [dropOff]) == nil)
        #expect(BlockRules.latestEnd(for: setUp, in: [dropOff]) == nil)
    }

    @Test("A block on another day or at another venue is neither")
    func staysInsideItsOwnDay() {
        let morning = ClashFixture.day()
        let wednesday = ClashFixture.block(from: TimeOfDay(9, 30), to: TimeOfDay(11, 0), on: .wed)
        let elsewhere = ClashFixture.block(
            from: TimeOfDay(9, 30), to: TimeOfDay(11, 0), venueID: Venue.ID()
        )

        #expect(BlockRules.latestEnd(for: morning[0], in: [wednesday, elsewhere]) == nil)
        #expect(BlockRules.overlap(with: morning[0], in: [wednesday, elsewhere]) == nil)
        // The same block on the same day at the same venue is both.
        #expect(BlockRules.latestEnd(for: morning[0], in: [wednesday, elsewhere, morning[1]])
                == TimeOfDay(10, 0))
    }

    // MARK: The clash — `overlap(with:in:)`

    @Test("A day of blocks that abut is not a day of blocks that clash")
    func abuttingIsNotOverlapping() {
        let morning = ClashFixture.day()

        for block in morning {
            #expect(BlockRules.overlap(with: block, in: morning) == nil)
        }
    }

    @Test("One minute past the neighbour's start is a clash")
    func oneMinuteOver() {
        let morning = ClashFixture.day()
        // The day's own first block, lengthened — not a fresh one at the same time, which would
        // carry a new id and so clash with the block it was copied from as well as with the
        // neighbour. This is the shape a resize commit and an edit both actually produce.
        var grown = morning[0]
        grown.endsAt = TimeOfDay(10, 1)

        #expect(BlockRules.overlap(with: grown, in: morning)?.startsAt == TimeOfDay(10, 0))

        grown.endsAt = TimeOfDay(10, 0)
        #expect(BlockRules.overlap(with: grown, in: morning) == nil)
    }

    @Test("A block wholly inside another one clashes from either side")
    func containedBlocksClash() {
        let long = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(12, 0), title: "Match play"
        )
        let short = ClashFixture.block(
            from: TimeOfDay(10, 0), to: TimeOfDay(10, 30), title: "Water & regroup"
        )

        #expect(BlockRules.overlap(with: short, in: [long])?.title == "Match play")
        #expect(BlockRules.overlap(with: long, in: [short])?.title == "Water & regroup")
    }

    /// The corner `latestEnd` cannot see: two blocks with the same start have no strictly-greater
    /// neighbour between them, so neither is the other's ceiling and only the clash rule catches
    /// them. The editor's advice takes the other branch for exactly this reason.
    @Test("Two blocks sharing a start clash, though neither is the other's ceiling")
    func sharedStartsClash() {
        let first = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(10, 0), title: "Skills rotation"
        )
        let second = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(9, 30), title: "Warm-up"
        )

        #expect(BlockRules.latestEnd(for: first, in: [second]) == nil)
        #expect(BlockRules.overlap(with: first, in: [second])?.title == "Warm-up")
    }

    /// A block with no end has not said how long it runs, and reading it as running to midnight
    /// would flag every block after it — including every day a `DayShape` writes, which is all
    /// open-ended.
    @Test("A block with no end never clashes, in either direction")
    func openEndedNeverClashes() {
        let dropOff = ClashFixture.block(from: TimeOfDay(8, 30), to: nil, title: "Drop-off")
        let skills = ClashFixture.block(
            from: TimeOfDay(8, 0), to: TimeOfDay(12, 0), title: "Skills rotation"
        )

        #expect(BlockRules.overlap(with: dropOff, in: [skills]) == nil)
        #expect(BlockRules.overlap(with: skills, in: [dropOff]) == nil)
    }

    @Test("A block never clashes with itself")
    func ignoresItself() {
        let morning = ClashFixture.day()

        #expect(BlockRules.overlap(with: morning[1], in: morning) == nil)
        #expect(BlockRules.latestEnd(for: morning[1], in: morning) == TimeOfDay(10, 30))
    }

    /// The editor writes a different sentence depending on which side of the block the clash is
    /// on, so the side has to survive the array arriving in any order.
    @Test("The clash reported is the earliest-starting one, whatever order the day arrives in")
    func reportsTheEarliestClash() {
        let morning = ClashFixture.day()
        let sprawling = ClashFixture.block(from: TimeOfDay(9, 30), to: TimeOfDay(11, 0))

        #expect(BlockRules.overlap(with: sprawling, in: morning)?.startsAt == TimeOfDay(9, 0))
        #expect(BlockRules.overlap(with: sprawling, in: morning.reversed())?.startsAt
                == TimeOfDay(9, 0))
    }

    /// The property `BlockEditorSheet.overlapAdvice` leans on: when the clash starts *after* the
    /// block, the minute to end by is the minute that clash begins. Anything sharing space and
    /// starting in between would have been the earlier clash.
    @Test("When the clash is ahead, the ceiling is exactly where it begins")
    func theCeilingIsTheClashAhead() {
        let morning = ClashFixture.day()
        var sprawling = morning[0]
        sprawling.endsAt = TimeOfDay(11, 0)

        let clash = BlockRules.overlap(with: sprawling, in: morning)
        #expect(clash?.startsAt == TimeOfDay(10, 0))
        #expect(BlockRules.latestEnd(for: sprawling, in: morning) == clash?.startsAt)
    }

    // MARK: The draft asking the same question

    @Test("The editor sees the clash, and the block it names is the one that is there")
    func theDraftSeesTheClash() {
        let morning = ClashFixture.day()
        var draft = BlockEditorDraft(creatingIn: ClashFixture.venueID, day: .tue)
        draft.title = "Warm-up"
        draft.startsAt = TimeOfDay(9, 0)

        // A fresh 9:00–10:00 draft sits exactly where `morning[0]` does, so it clashes.
        let fresh = draft
        #expect(fresh.isValid)
        #expect(fresh.overlap(in: morning)?.startsAt == TimeOfDay(9, 0))

        // Ended at the ceiling instead, it is a block that runs into nothing.
        draft.startsAt = TimeOfDay(8, 0)
        draft.endsAt = TimeOfDay(9, 0)
        let abutting = draft
        #expect(BlockRules.latestEnd(for: abutting.block(), in: morning) == TimeOfDay(9, 0))
        #expect(abutting.overlap(in: morning) == nil)

        draft.endsAt = TimeOfDay(9, 15)
        let over = draft
        #expect(over.overlap(in: morning)?.startsAt == TimeOfDay(9, 0))
        // …and still saveable. Nothing about a clash touches the four CHECKs.
        #expect(over.isValid)
    }

    /// Ticking a court the other block does not use is the way out of a clash, and the draft has
    /// to see that as it is typed rather than after a round trip.
    @Test("Choosing courts clears the clash, and the draft answers before the write")
    func courtsClearTheClashInTheDraft() {
        let freePlay = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(9, 30),
            title: "Free play", courts: [ClashFixture.court2, ClashFixture.court3]
        )
        var draft = BlockEditorDraft(creatingIn: ClashFixture.venueID, day: .tue)
        draft.title = "Warm-up"
        draft.startsAt = TimeOfDay(9, 0)
        draft.endsAt = TimeOfDay(9, 15)

        let regular = draft
        #expect(regular.overlap(in: [freePlay])?.title == "Free play")

        // `.assigned` with nothing ticked yet still claims the venue.
        draft.kind = .assigned
        let unfinished = draft
        #expect(unfinished.overlap(in: [freePlay])?.title == "Free play")

        draft.courtIDs = [ClashFixture.court1]
        let onCourt1 = draft
        #expect(onCourt1.overlap(in: [freePlay]) == nil)

        // …and a court they do share puts it back.
        draft.courtIDs = [ClashFixture.court1, ClashFixture.court3]
        let onCourt3Too = draft
        #expect(onCourt3Too.overlap(in: [freePlay])?.title == "Free play")
    }

    /// `AppStore.scheduleBlocks` holds one venue and one day, so a draft moved off that day is
    /// asked about a list it is not on. A quiet "nothing" is the only honest answer.
    @Test("A draft moved to another day is checked against nothing rather than wrongly")
    func aMovedDraftIsCheckedAgainstNothing() {
        let morning = ClashFixture.day()
        var draft = BlockEditorDraft(creatingIn: ClashFixture.venueID, day: .tue)
        draft.title = "Warm-up"
        draft.startsAt = TimeOfDay(9, 0)
        draft.endsAt = TimeOfDay(10, 0)
        let onTuesday = draft
        #expect(onTuesday.overlap(in: morning) != nil)

        draft.day = .wed
        let onWednesday = draft
        #expect(onWednesday.overlap(in: morning) == nil)
    }
}

/// The index `8k` hands to its cards, which exists only so the rule above is asked once a day
/// rather than once a card on every tick of the clock. What it must not do is answer differently.
@Suite("ScheduleConflicts")
struct ScheduleConflictsTests {

    @Test("A morning in order flags nothing")
    func aTidyDayIsQuiet() {
        let day = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
        let conflicts = ScheduleConflicts(day: day)

        for block in day {
            #expect(conflicts[block.id] == nil)
        }
    }

    @Test("Both sides of a clash are flagged, each naming the other")
    func bothSidesAreFlagged() {
        let skills = ClashFixture.block(
            from: TimeOfDay(9, 0), to: TimeOfDay(10, 30), title: "Skills rotation"
        )
        let water = ClashFixture.block(
            from: TimeOfDay(10, 0), to: TimeOfDay(10, 15), title: "Water & regroup"
        )
        let lunch = ClashFixture.block(
            from: TimeOfDay(12, 0), to: TimeOfDay(13, 0), title: "Lunch"
        )
        let conflicts = ScheduleConflicts(day: [skills, water, lunch])

        #expect(conflicts[skills.id]?.title == "Water & regroup")
        #expect(conflicts[water.id]?.title == "Skills rotation")
        #expect(conflicts[lunch.id] == nil)
    }

    /// The one property the cache has to have, asserted against the rule rather than against a
    /// hand-written expectation: every block gets the answer it would have got on its own.
    @Test("Every entry is the answer the rule gives for that block")
    func agreesWithTheRule() {
        let venueID = SampleData.sycamore.id
        var day = ScheduleSampleDay.blocks(venueID: venueID)
        day[1].endsAt = TimeOfDay(11, 30)
        day[3].endsAt = nil
        let conflicts = ScheduleConflicts(day: day)

        for block in day {
            #expect(conflicts[block.id] == BlockRules.overlap(with: block, in: day))
        }
    }
}

@Suite("BlockClock")
struct BlockClockTests {

    @Test("Runs 07:00 to 20:00 in quarter-hours")
    func optionRange() {
        #expect(BlockClock.options.first == TimeOfDay(7, 0))
        #expect(BlockClock.options.last == TimeOfDay(20, 0))
        // 13 hours × 4, plus the closing 20:00 itself.
        #expect(BlockClock.options.count == 53)
        #expect(BlockClock.options.contains(TimeOfDay(10, 45)))
        #expect(!BlockClock.options.contains(TimeOfDay(10, 50)))
    }

    @Test("Options are in order and none repeats")
    func optionsAreOrdered() {
        #expect(BlockClock.options == BlockClock.options.sorted())
        #expect(Set(BlockClock.options).count == BlockClock.options.count)
    }

    /// The menu omits what the CHECK would refuse rather than offering it and rejecting the tap.
    @Test("End options start after the block does")
    func endOptionsExcludeTheStart() {
        let options = BlockClock.endOptions(after: TimeOfDay(9, 0))

        #expect(options.first == TimeOfDay(9, 15))
        #expect(!options.contains(TimeOfDay(9, 0)))
        #expect(!options.contains(TimeOfDay(8, 45)))
        #expect(options.allSatisfy { BlockRules.endsAfterStart(startsAt: TimeOfDay(9, 0), endsAt: $0) })
    }

    @Test("A block starting at the end of the day has no end to offer")
    func endOptionsCanBeEmpty() {
        #expect(BlockClock.endOptions(after: TimeOfDay(20, 0)).isEmpty)
    }
}

@Suite("BlockEditorDraft")
struct BlockEditorDraftTests {

    private static let venueID = Venue.ID()

    // MARK: Validity

    @Test("A fresh draft is invalid until it is named")
    func freshDraftNeedsATitle() {
        var draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        #expect(!draft.isValid)

        draft.title = "Skills rotation"
        #expect(draft.isValid)
    }

    /// The same rule `CampDraft` applies: a title is not its surrounding whitespace, and the
    /// column's CHECK counts every character it is given.
    @Test("A draft is judged on what will actually be stored")
    func judgesTheStoredString() {
        var draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)

        draft.title = "   "
        #expect(!draft.isValid)

        draft.title = "  Lunch  "
        #expect(draft.isValid)
        #expect(draft.trimmedTitle == "Lunch")
        #expect(draft.block().title == "Lunch")

        // 79 characters plus two spaces: over the limit as typed, inside it as stored.
        draft.title = " \(String(repeating: "a", count: 79)) "
        #expect(draft.title.count == 81)
        #expect(draft.isValid)
    }

    @Test("Every CHECK has to pass, not just the title")
    func validityIsTheConjunction() {
        var draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        draft.title = "Skills rotation"
        #expect(draft.isValid)

        draft.detail = String(repeating: "a", count: 161)
        #expect(!draft.isValid)

        draft.detail = "Courts 1–3 · 22 players"
        #expect(draft.isValid)

        // Dragging the start past an end that was already chosen — the state the menus cannot
        // design away, and the reason the editor says so in words rather than silently rewriting
        // somebody's end time.
        draft.startsAt = TimeOfDay(11, 0)
        draft.endsAt = TimeOfDay(10, 0)
        #expect(!draft.isValid)

        draft.endsAt = nil
        #expect(draft.isValid)
    }

    // MARK: What gets written

    @Test("An empty description is stored as null, not as an empty string")
    func emptyDetailBecomesNil() {
        var draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        draft.title = "Lunch"

        #expect(draft.block().detail == nil)

        draft.detail = "   "
        #expect(draft.block().detail == nil)

        draft.detail = "  Shade lawn  "
        #expect(draft.block().detail == "Shade lawn")
    }

    /// The id the sheet holds is the id the insert carries, so a create committed twice cannot
    /// become two blocks.
    @Test("A create carries one id from the first keystroke to the write")
    func createKeepsItsID() {
        var draft = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        draft.title = "Lunch"

        #expect(draft.block().id == draft.id)
        #expect(draft.block().id == draft.block().id)
        #expect(draft.block().venueID == Self.venueID)
        #expect(draft.isCreating)
    }

    @Test("An edit round-trips the block it was opened on")
    func editRoundTrips() {
        let original = ScheduleBlock(
            venueID: Self.venueID,
            day: .wed,
            startsAt: TimeOfDay(9, 0),
            endsAt: TimeOfDay(10, 30),
            title: "Skills rotation",
            detail: "Courts 1–3 · 22 players"
        )

        let draft = BlockEditorDraft(editing: original)
        #expect(!draft.isCreating)
        #expect(draft.id == original.id)
        #expect(draft.block() == original)
    }

    /// The editor asks about neither, so saving one must not reset either. `status` is written by
    /// "Mark done"; `notes` are written by `addBlockNote`.
    @Test("Editing a title leaves the status and the notes alone")
    func carriesThroughWhatItDoesNotAskAbout() {
        let note = BlockNote(id: InboxItem.ID(), text: "shade tent is up", authorName: "Nass", at: .now)
        let original = ScheduleBlock(
            venueID: Self.venueID,
            day: .wed,
            startsAt: TimeOfDay(10, 30),
            endsAt: TimeOfDay(10, 45),
            title: "Water & regroup",
            status: .done,
            notes: [note]
        )

        var draft = BlockEditorDraft(editing: original)
        draft.title = "Water break"

        let saved = draft.block()
        #expect(saved.title == "Water break")
        #expect(saved.status == .done)
        #expect(saved.notes == [note])
    }

    /// A `Set` in the draft, because picking a coach is a membership question and a double tap
    /// must not put somebody on twice — and a sorted array on the block, so two saves of the same
    /// people produce the same row and `ScheduleBlock: Equatable` sees no change where there is
    /// none.
    @Test("Coaches come out ordered, and the order does not depend on how they went in")
    func coachIDsAreStable() {
        let ids = (0..<5).map { _ in StaffMember.ID() }

        var forwards = BlockEditorDraft(creatingIn: Self.venueID, day: .tue)
        forwards.title = "Match play"
        forwards.coachIDs = Set(ids)

        var backwards = forwards
        backwards.coachIDs = Set(ids.reversed())

        #expect(forwards.block().coachIDs == backwards.block().coachIDs)
        #expect(forwards.block().coachIDs.count == ids.count)
        #expect(Set(forwards.block().coachIDs) == Set(ids))
    }
}
