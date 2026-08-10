//
//  BlockEditorDraft.swift
//  Sycamore
//
//  What the block editor holds while somebody is typing, the four rules the columns behind it will
//  enforce whether or not this file states them, and one rule no column holds at all.
//
//  The four CHECKs are mirrors: the write refuses them, and stating them here is what keeps the
//  refusal from arriving after the sheet has closed. The fifth — whether two blocks are asking for
//  the same court at the same time — has no column behind it and never will, and is a *warning*
//  rather than a refusal. `BlockRules.overlap(with:in:)` says why, at length, because the obvious
//  alternative was built once already and is the wrong shape for this app.
//
//  Here rather than in `Models.swift` or `SectionEight.swift`. `SectionEight.swift:8-10` gives the
//  reason for the split it made — `Models.swift` "is the one place every feature touches; adding
//  three more to it makes it the merge conflict for every screen built from here on" — and it
//  applies with more force to a draft, which is not a domain shape at all. A `ScheduleBlock` is
//  what the camp has; a `BlockEditorDraft` is what one sheet is in the middle of doing to one.
//
//  `BlockRules` follows the `CampName` precedent (`Models.swift:939-955`) exactly: the CHECK
//  quoted, the count taken in unicode scalars, and one place that states it so every screen
//  testing it is testing the same thing.
//

import Foundation

// MARK: - The CHECKs, in Swift

/// The four constraints `schedule_blocks` (and, for a note, `inbox_items`) will apply at `insert`,
/// and the one rule about a block's neighbours that nothing but this file states.
///
/// The four are mirrored on this side of the wire for the reason `CampName` gives: a value that
/// fails a CHECK fails *at the write*, which on a create is after the sheet has been dismissed and
/// the draft thrown away. Refusing before the tap costs one disabled button; refusing after it
/// costs the whole draft and produces a banner pointing at no field in particular.
///
/// Every count goes through `CharLength`, which counts the way Postgres does rather than the way
/// Swift reads a string. The bounds stay here, beside the SQL each one cites.
///
/// The fifth is a different kind of thing and is grouped apart below. It is answerable only with
/// the whole day in hand, no column enforces it, and it refuses nothing — see
/// `overlap(with:in:)`, which is where the reasoning for all three of those lives.
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
    /// `TimeOfDay` is `Comparable` (`Models.swift:289`), so this is the comparison and not a
    /// re-derivation of one from hours and minutes.
    static func endsAfterStart(startsAt: TimeOfDay, endsAt: TimeOfDay?) -> Bool {
        guard let endsAt else { return true }
        return endsAt > startsAt
    }

    // MARK: The rule that is about the day and not about the row

    /// The block `block` clashes with, or nil when it clashes with nothing.
    ///
    /// **A clash is an overlap in time *and* a claim on the same space.** Two blocks whose minutes
    /// overlap are only a problem if they are also asking for the same courts — which is why this
    /// takes the day rather than a pair of times, and why it is the one rule here that cannot be
    /// answered from one row. See `sharesSpace(_:_:)` for the four cases that produces.
    ///
    /// ── WHY THIS IS A WARNING AND NOT A REFUSAL ───────────────────────────────────────────────
    ///
    /// Recorded at length rather than left to be rediscovered. This was built once as a refusal,
    /// in the only place a refusal is airtight — a Postgres constraint:
    ///
    ///     exclude using gist (site_id with =, tsrange(day + starts_at, day + ends_at) with &&)
    ///       where (ends_at is not null)
    ///
    /// with `23P01` mapped to a sentence and the editor's commit button disabled behind it. The
    /// construction is right for the rule it states — a CHECK cannot see another row, and a
    /// trigger races two concurrent writes where an index does not — so anybody reaching for this
    /// problem will reach for it again. It was never committed, and the reasons are these.
    ///
    /// **It states the wrong rule.** An EXCLUDE keyed on `site_id` says "two blocks at one venue
    /// may not claim the same minute", and `ScheduleBlockKind.assigned` with `courtIDs`
    /// (`SectionEight.swift:183-186`) exists precisely so that they may. "Warm-up 9:00–9:15 on
    /// Court 1" beside "Free play 9:00–9:15 on Courts 2–4" is a morning the schedule is now meant
    /// to be able to write down, and a venue-wide constraint makes it unsayable **at the
    /// database** — the one layer the app cannot work around.
    ///
    /// **A court-aware EXCLUDE is not the repair.** The courts live in `schedule_block_courts`, a
    /// table of their own, so an overlap keyed on courts spans two rows in two tables. That is a
    /// trigger again, which is the construction the EXCLUDE was chosen over.
    ///
    /// **And a camp may legitimately double-book.** Two coaches on one court for ten minutes of
    /// handover is a thing that happens, and somebody wants to *see* it rather than be stopped
    /// from writing it down at seven in the morning with a car park filling up. So this answers a
    /// question and the screens draw a flag; nothing anywhere refuses a save, and
    /// `ScheduleResize.swift` records the same decision for the finger on a card's bottom edge.
    ///
    /// ── WHICH ONE IT REPORTS ──────────────────────────────────────────────────────────────────
    ///
    /// The **earliest-starting** clash rather than whichever the array holds first. `8k`'s list is
    /// only sorted by convention — `scheduleBlocks(forVenue:day:campID:)` returns whatever order
    /// the query gives — and `BlockEditorSheet` writes a different sentence depending on which
    /// side of the block the clash is on, so the side has to be the same answer whichever order
    /// the day arrives in. Two clashes starting at the same minute are on the same side and get
    /// the same sentence, so the tie between them is left to the array; only the name in it moves.
    static func overlap(with block: ScheduleBlock, in day: [ScheduleBlock]) -> ScheduleBlock? {
        day.filter { $0.id != block.id && overlaps($0, block) }
            .min { $0.startsAt < $1.startsAt }
    }

    /// Same space, and two half-open spans that meet.
    ///
    /// Half-open, so a block that ends exactly when the next begins is an ordinary camp morning
    /// and one that ends a minute later is two blocks claiming the same minute.
    ///
    /// **A block with no stated end clashes with nothing, in either direction.** `ends_at` is
    /// nullable by design — `20260805074039:27-28` says the design's 8:30 "Drop-off · done" has no
    /// stated end and "inventing one would put a time on screen that nobody entered" — and reading
    /// it as running until midnight would put a warning on every block after it. Every block
    /// `DayShape` writes is open-ended (`SupabaseRepository.applyDayShape` sends no `ends_at` at
    /// all), so that reading would flag the whole of every day built from a shape. A flag that
    /// fires on the app's own output is a flag nobody reads.
    private static func overlaps(_ a: ScheduleBlock, _ b: ScheduleBlock) -> Bool {
        guard let aEnd = a.endsAt, let bEnd = b.endsAt else { return false }
        // Minutes before courts, and the order is not arbitrary: `sharesSpace` builds up to two
        // sets and the comparisons either side of it are two integer compares. On a day that is
        // simply in order — which is most days — no set is ever built.
        return a.startsAt < bEnd && b.startsAt < aEnd && sharesSpace(a, b)
    }

    /// Whether two blocks are asking for the same space — the half of a clash that is not about
    /// time at all.
    ///
    /// One rule: **two blocks share space unless both name courts and the two lists are
    /// disjoint.** The four cases the app can produce fall out of it.
    ///
    ///   - Both `.regular`. Neither says where it runs, so both claim the venue: they contend.
    ///   - One of each. The regular one claims the venue, which contains the other's courts.
    ///   - Both `.assigned` with a court in common. They contend over that court.
    ///   - Both `.assigned` with disjoint courts. **Not a clash**, however much their minutes
    ///     overlap. This is the case the whole change turns on.
    ///
    /// An `.assigned` block with no courts ticked yet claims the venue too, and that is deliberate
    /// rather than an oversight about empty sets: the rule is about what a block has *said*, and
    /// that one has not finished saying it. Treating "no courts" as "no claim" would make an
    /// unfinished block silently compatible with everything, which is the reverse of what somebody
    /// mid-edit needs. `block()` already guarantees the other direction — a `.regular` block is
    /// written with no courts whatever is ticked — so the two kinds cannot disagree on the wire.
    ///
    /// Venue and day first, because `AppStore.scheduleBlocks` holds one of each and a block moved
    /// off them must be compared against nothing rather than wrongly.
    ///
    /// **Internal rather than private**, which it was when this rule only had one reader. The
    /// clash flag was the first question asked of it and it is no longer the only one:
    /// `ScheduleBlock.running(in:at:)` (`SectionEight.swift:459-467`) asks the identical question —
    /// *do these two contend for the same courts* — to decide whether one block ends another. Two
    /// spellings of that would be two answers to it, and a morning where the editor flagged a
    /// clash the "On now" highlight did not believe in.
    static func sharesSpace(_ a: ScheduleBlock, _ b: ScheduleBlock) -> Bool {
        guard a.venueID == b.venueID, a.day == b.day else { return false }
        guard let aCourts = claim(of: a), let bCourts = claim(of: b) else { return true }
        return !aCourts.isDisjoint(with: bCourts)
    }

    /// Whether `block` claims `court` — the same rule as `sharesSpace(_:_:)` asked of one court
    /// rather than of another block.
    ///
    /// A block that claims the whole venue claims every court in it, which is what makes the nil
    /// case `true` here and `true` there: "Lunch" is on your court, and so is an `.assigned`
    /// block nobody has finished picking courts for. Built on `claim(of:)` rather than reading
    /// `courtIDs.contains` directly, so the two questions cannot drift on what an empty list of
    /// courts means.
    ///
    /// Note it says nothing about venue or day — it cannot, having only a court to go on. Every
    /// caller reaches it through `running(in:at:)`, which is handed one venue's day; a caller that
    /// is not should filter first.
    static func claims(_ block: ScheduleBlock, court: CourtGroup.ID) -> Bool {
        claim(of: block).map { $0.contains(court) } ?? true
    }

    /// The courts a block claims, or nil for "the whole venue".
    private static func claim(of block: ScheduleBlock) -> Set<CourtGroup.ID>? {
        guard block.kind == .assigned, !block.courtIDs.isEmpty else { return nil }
        return Set(block.courtIDs)
    }

    /// The latest end `block` could be given before it runs into something it shares space with,
    /// or nil when nothing after it shares space with it.
    ///
    /// The minute `BlockEditorSheet` offers back under its two time menus — "end it by 10:30" —
    /// and nothing else. It is **advice and not a wall**: it used to be `ScheduleResizePlan`'s
    /// ceiling, and that clamp is gone for the reason `overlap(with:in:)` gives above and
    /// `ScheduleResize.swift`'s header restates.
    ///
    /// Exactly as strict as `overlap(with:in:)` and not a step stricter, which is a change from
    /// the version of this that walled a drag. Both filters are `sharesSpace`, and both skip a
    /// neighbour with no stated end — so the minute this offers is the minute at which the clash
    /// the sheet has just *named* begins, rather than some tighter number belonging to a block the
    /// sentence never mentions. A wall could afford to be stricter than the rule; a sentence
    /// cannot, because a reader can check it.
    ///
    /// Finished blocks count. A `.done` drop-off draws as one grey line rather than as a card, but
    /// it still occupies its courts from eight-thirty to nine.
    ///
    /// Two blocks sharing a start do not follow each other, so neither is the other's ceiling.
    /// They already overlap, and `overlap(with:in:)` is what sees those.
    static func latestEnd(for block: ScheduleBlock, in day: [ScheduleBlock]) -> TimeOfDay? {
        // Same ordering as `overlaps`, and for the same reason: the two cheap comparisons rule out
        // everything before this block before a set is built for anything after it.
        day.lazy
            .filter {
                $0.startsAt > block.startsAt && $0.id != block.id && $0.endsAt != nil
                    && sharesSpace($0, block)
            }
            .map(\.startsAt)
            .min()
    }
}

// MARK: - The clock the editor offers

/// The times a block may start or end at.
///
/// 07:00 to 20:00 in fifteen-minute steps — fifty-three entries, which is a menu rather than a
/// wheel, and a camp day that starts before seven or runs past eight is not a thing these screens
/// draw. Built with `stride` the way `TimeOfDay.pickupOptions` is (`Models.swift:342-343`), so the
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
    ///
    /// Nor is the overlap, and for the same reason twice over: no column holds it either, and it
    /// is a warning by decision rather than by accident. See `overlap(in:)`.
    var isValid: Bool {
        BlockRules.isValidTitle(trimmedTitle)
            && BlockRules.isValidDetail(trimmedDetail)
            && BlockRules.endsAfterStart(startsAt: startsAt, endsAt: endsAt)
    }

    /// The block on `day` this draft clashes with, if any — asked of the values the write will
    /// carry, so ticking a court the other block does not use makes it go away.
    ///
    /// Warned about rather than refused, which is the same call `dayOptions(in:)` makes for a
    /// closed day and for a related reason: neither is a row the database objects to, so refusing
    /// either would be the app inventing a lock and stranding somebody fixing a typo. The longer
    /// argument — including the constraint that was written and dropped — is on
    /// `BlockRules.overlap(with:in:)`.
    ///
    /// Nothing at all when the draft has been moved to a day other than the one the store is
    /// holding. `AppStore.scheduleBlocks` is one venue and one day at a time
    /// (`AppStore+SectionEight.swift:182-189`), so a block dragged onto Wednesday is asked about
    /// Tuesday's list, and the venue-and-day filter inside `BlockRules.sharesSpace(_:_:)` is what
    /// makes that a quiet "nothing" rather than a confident wrong answer.
    func overlap(in day: [ScheduleBlock]) -> ScheduleBlock? {
        BlockRules.overlap(with: block(), in: day)
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
