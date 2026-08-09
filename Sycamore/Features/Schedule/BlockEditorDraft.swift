//
//  BlockEditorDraft.swift
//  Sycamore
//
//  What the block editor holds while somebody is typing, and the four rules the columns behind it
//  will enforce whether or not this file states them.
//
//  Here rather than in `Models.swift` or `SectionEight.swift`. `SectionEight.swift:8-10` gives the
//  reason for the split it made — `Models.swift` "is the one place every feature touches; adding
//  three more to it makes it the merge conflict for every screen built from here on" — and it
//  applies with more force to a draft, which is not a domain shape at all. A `ScheduleBlock` is
//  what the camp has; a `BlockEditorDraft` is what one sheet is in the middle of doing to one.
//
//  `BlockRules` follows the `CampName` precedent (`Models.swift:700-718`) exactly: the CHECK
//  quoted, the count taken in unicode scalars, and one place that states it so every screen
//  testing it is testing the same thing.
//

import Foundation

// MARK: - The CHECKs, in Swift

/// The four constraints `schedule_blocks` (and, for a note, `inbox_items`) will apply at `insert`.
///
/// Mirrored on this side of the wire for the reason `CampName` gives: a value that fails a CHECK
/// fails *at the write*, which on a create is after the sheet has been dismissed and the draft
/// thrown away. Refusing before the tap costs one disabled button; refusing after it costs the
/// whole draft and produces a banner pointing at no field in particular.
///
/// Every count goes through `CharLength`, which counts the way Postgres does rather than the way
/// Swift reads a string. The bounds stay here, beside the SQL each one cites.
enum BlockRules {

    /// `check (char_length(title) between 1 and 80)` — `20260805074039:30`.
    static let titleLimits = 1...80

    /// `check (detail is null or char_length(detail) <= 160)` — `20260805074039:33`. No lower
    /// bound: the column is nullable, and an empty description is stored as `null` rather than as
    /// an empty string.
    static let detailLimit = 160

    /// `check (detail is null or char_length(detail) <= 200)` — `20260805074039:60`.
    ///
    /// On `inbox_items`, not on `schedule_blocks`, because that is where a block note actually
    /// lives: there is no notes table, and a note is a row of `inbox_items` with `kind = 'note'`
    /// carrying `schedule_block_id`. See `BlockNote`. The lower bound is this side's own — the
    /// column would accept `''`, and a blank note is a row that says nothing.
    static let noteLimits = 1...200

    static func isValidTitle(_ trimmed: String) -> Bool {
        CharLength.of(trimmed, fits: titleLimits)
    }

    static func isValidDetail(_ trimmed: String) -> Bool {
        CharLength.of(trimmed, atMost: detailLimit)
    }

    static func isValidNote(_ trimmed: String) -> Bool {
        CharLength.of(trimmed, fits: noteLimits)
    }

    /// `check (ends_at is null or ends_at > starts_at)` — `20260805074039:38-39`.
    ///
    /// The one CHECK in that table nothing on the device mirrored, and the one a two-time-field
    /// editor walks into constantly: every drag of the start time past the end time is a draft
    /// the column would refuse. Strictly greater, like the constraint — a block that ends when it
    /// starts is not a block.
    ///
    /// `TimeOfDay` is `Comparable` (`Models.swift:156`), so this is the comparison and not a
    /// re-derivation of one from hours and minutes.
    static func endsAfterStart(startsAt: TimeOfDay, endsAt: TimeOfDay?) -> Bool {
        guard let endsAt else { return true }
        return endsAt > startsAt
    }
}

// MARK: - The clock the editor offers

/// The times a block may start or end at.
///
/// 07:00 to 20:00 in fifteen-minute steps — fifty-three entries, which is a menu rather than a
/// wheel, and a camp day that starts before seven or runs past eight is not a thing these screens
/// draw. Built with `stride` the way `TimeOfDay.pickupOptions` is (`Models.swift:170-171`), so the
/// two lists are recognisably the same construction at different resolutions.
///
/// Quarter-hours rather than the pick-up sheet's half-hours because the design's own Tuesday has a
/// block ending at 10:45.
enum BlockClock {
    static let options: [TimeOfDay] = stride(from: 7 * 60, through: 20 * 60, by: 15)
        .map { TimeOfDay($0 / 60, $0 % 60) }

    /// The end-time options for a block starting at `startsAt`.
    ///
    /// Anything at or before the start is omitted rather than offered and then refused. A menu
    /// that lists 8:00 under a block starting at 9:00 is a menu with a wrong answer in it, and the
    /// only thing left to do about a tap on it is put up a banner.
    static func endOptions(after startsAt: TimeOfDay) -> [TimeOfDay] {
        options.filter { $0 > startsAt }
    }
}

// MARK: - The draft

/// One block, mid-edit.
///
/// `Identifiable` because both callers present the editor with `.sheet(item:)`, and the id is the
/// block's own: the one being edited, or the one a create is going to insert. Minting it here
/// rather than letting `ScheduleBlock`'s default do it means the id in the sheet and the id in the
/// row are the same value, so a create that is committed twice cannot become two blocks.
///
/// Deliberately a held draft committed once, rather than `VenueSheet`'s live `.onChange(of: draft)`
/// write (`VenueSheet.swift:47-49`). That sheet edits a venue that already exists and none of its
/// fields crosses a NOT NULL floor mid-typing. A new block does not exist and
/// `schedule_blocks.title` is `check (char_length(title) between 1 and 80)` — so a live write
/// would insert a nameless block on the first keystroke and be refused on the eighty-first. The
/// *field* patterns below are `VenueSheet`'s; the write model is not.
struct BlockEditorDraft: Identifiable, Hashable, Sendable {

    /// Which of the two things the sheet is doing.
    ///
    /// `.create` carries the venue because a block that does not exist yet has nowhere else to get
    /// one. `.edit` carries nothing: the draft was built from a block that already knows.
    enum Mode: Hashable, Sendable {
        case create(venueID: Venue.ID)
        case edit
    }

    let id: ScheduleBlock.ID
    let mode: Mode
    /// The venue this block hangs off — from `mode` on a create, from the block on an edit. Not
    /// editable: moving a block between venues is a different operation from editing one, and the
    /// editor is reached from a screen that is already scoped to a venue.
    let venueID: Venue.ID
    var day: Weekday
    var startsAt: TimeOfDay
    var endsAt: TimeOfDay?
    var title: String
    /// The description, held as `""` rather than `nil` because a `TextField` binds to a `String`.
    /// `block()` puts the nil back.
    var detail: String
    var coachIDs: Set<StaffMember.ID>
    /// What kind of thing this block is, and therefore whether the sheet asks about courts at all.
    var kind: ScheduleBlockKind
    /// The courts it runs on. A `Set` for the same reason `coachIDs` is one — picking a court is a
    /// membership question, and a double tap must not add it twice — and `block()` orders it.
    ///
    /// Held across a switch back to `.regular` rather than cleared on the spot: somebody who taps
    /// the wrong kind and taps back has not asked to lose four ticks. `block()` is where the
    /// courts are dropped, because that is the value that gets written.
    var courtIDs: Set<Group.ID>
    /// What to do with the kids when this is saved. Never read off the block — see
    /// `BlockKidSpread`.
    var spread: BlockKidSpread = .leaveThem

    /// Carried through untouched so that saving an edit does not quietly reset the two things this
    /// sheet does not ask about. `status` is written by "Mark done" and by the seed; `notes` are
    /// written by `addBlockNote`. An editor that rebuilt the block from its own fields alone would
    /// undo both every time somebody fixed a typo in the title.
    private var status: ScheduleBlockStatus
    private var notes: [BlockNote]

    // MARK: Building one

    /// A block that does not exist yet, on the day the caller is standing on.
    ///
    /// 9:00 to 10:00 rather than empty. The old `ScheduleView.addFirstBlock` wrote a hardcoded
    /// 9:00 "New block" because there was no composer to ask; the hour survives as the *default*
    /// in the composer that replaced it, which is a different claim — it is now a value somebody
    /// is looking at and can change before it is written.
    init(creatingIn venueID: Venue.ID, day: Weekday) {
        self.id = UUID()
        self.mode = .create(venueID: venueID)
        self.venueID = venueID
        self.day = day
        self.startsAt = TimeOfDay(9, 0)
        self.endsAt = TimeOfDay(10, 0)
        self.title = ""
        self.detail = ""
        self.coachIDs = []
        self.kind = .regular
        self.courtIDs = []
        self.status = .planned
        self.notes = []
    }

    init(editing block: ScheduleBlock) {
        self.id = block.id
        self.mode = .edit
        self.venueID = block.venueID
        self.day = block.day
        self.startsAt = block.startsAt
        self.endsAt = block.endsAt
        self.title = block.title
        self.detail = block.detail ?? ""
        self.coachIDs = Set(block.coachIDs)
        self.kind = block.kind
        self.courtIDs = Set(block.courtIDs)
        self.status = block.status
        self.notes = block.notes
    }

    var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    // MARK: What will actually be stored

    /// A title is not its surrounding whitespace, and the column's CHECK counts every character it
    /// is given — so `"  Lunch  "` spends four of its eighty on nothing. The same reasoning
    /// `CampDraft.trimmedName` records.
    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDetail: String { detail.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Every CHECK the insert will apply, asked of the values the insert will carry.
    ///
    /// `day` is deliberately not among them, even though the editor can now show a day the camp
    /// has stopped running. See `dayOptions(in:)` — that is a warning, not a refusal, and there is
    /// no column to mirror.
    var isValid: Bool {
        BlockRules.isValidTitle(trimmedTitle)
            && BlockRules.isValidDetail(trimmedDetail)
            && BlockRules.endsAfterStart(startsAt: startsAt, endsAt: endsAt)
    }

    /// The days this block may be moved to: the ones the camp actually runs, plus — when it is not
    /// one of them — the day the block is already on.
    ///
    /// The camp's days, because Schedule now draws a chip per *camp* day rather than one per day
    /// of the week and opens on `CampDays.openingDay(from:)`. An editor offering all seven could
    /// therefore write a block onto a Saturday that the screen it came from cannot display: the
    /// row would be saved, and then be invisible.
    ///
    /// Plus the block's own day, because a camp's days are editable after the fact. Drop Saturday
    /// from a camp that had blocks on it and those blocks do not go anywhere — they simply stop
    /// being drawn, and this sheet is the only screen left that can reach them. Showing the day
    /// they are on is what makes them movable; leaving it out would present a row of five chips
    /// with none of them selected, which reads as a bug rather than as a problem to fix.
    ///
    /// It is a warning and not a refusal (`isValid` says nothing about the day). Blocking the
    /// commit would strand the block completely: somebody fixing a typo in its title would be made
    /// to move it first, and "Delete block" would be the only way out of the sheet that worked.
    ///
    /// The stray day removes itself. Tap Monday and the Saturday chip is gone on the next pass,
    /// because `draft.day` no longer names it.
    func dayOptions(in camp: Camp?) -> [Weekday] {
        guard let days = camp?.days else { return [day] }
        return Weekday.allCases.filter { days.contains($0) || $0 == day }
    }

    /// True while the block sits on a day its camp has stopped running.
    func isOnAClosedDay(in camp: Camp?) -> Bool {
        guard let days = camp?.days else { return false }
        return !days.contains(day)
    }

    /// The block to write. Trimmed, nil-ed where the column is nullable, and ordered.
    ///
    /// `coachIDs` is a `Set` in the draft — picking a coach is a membership question and a set is
    /// what stops a double tap adding somebody twice — and an ordered array on the block, because
    /// that is the contract's shape. Sorted rather than left in hash order so two saves of the
    /// same selection produce the same row and `ScheduleBlock: Equatable` does not see a change
    /// where there is none.
    ///
    /// `courtIDs` is sorted the same way and for the same reason, and deliberately *not* put into
    /// the venue's rank order here. That order is a fact about the venue, not about the block, and
    /// pinning it into the stored row would mean a court reordered in Setup left every block
    /// listing them the old way round. Every screen that draws them resolves through
    /// `BlockCourtPicker.courts(on:in:)`, which asks the camp — the same shape
    /// `BlockAssigneeList.coaches(on:in:)` already uses for people.
    ///
    /// Empty on a `.regular` block whatever is ticked. The kind is the question "does this block
    /// say where it runs", and a regular one answers no — so the ticks stay in the draft, where
    /// somebody who taps the wrong kind and taps back does not lose them, and are dropped here at
    /// the write.
    func block() -> ScheduleBlock {
        ScheduleBlock(
            id: id,
            venueID: venueID,
            day: day,
            startsAt: startsAt,
            endsAt: endsAt,
            title: trimmedTitle,
            detail: trimmedDetail.isEmpty ? nil : trimmedDetail,
            status: status,
            notes: notes,
            coachIDs: coachIDs.sorted { $0.uuidString < $1.uuidString },
            kind: kind,
            courtIDs: kind == .assigned ? courtIDs.sorted { $0.uuidString < $1.uuidString } : []
        )
    }
}
