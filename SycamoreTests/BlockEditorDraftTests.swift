//
//  BlockEditorDraftTests.swift
//  SycamoreTests
//
//  The four CHECKs on `schedule_blocks` (and, for a note, on `inbox_items`), and the draft that
//  has to satisfy them before the editor will let anybody press the button.
//
//  Written for the same reason `CampNameTests` is: these rules are enforced *at the write*, and on
//  a create the write happens after the sheet has been dismissed and the draft thrown away. A rule
//  the client does not mirror is a rule that costs somebody their typing.
//
//  The end-after-start rule gets its own suite. It is the one constraint nothing on the device
//  mirrored before this change, and the one a two-time-field editor walks into constantly — every
//  drag of the start past the end is a draft the column would refuse.
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
