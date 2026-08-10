//
//  CoachAvailability.swift
//  Sycamore
//
//  Whether a coach can take a court, and the one sentence that says why not.
//
//  Two screens ask this. `4d` is the picker — a sheet titled "Who takes Court 2?" over a list of
//  everybody at the venue, each with a subtitle and either an `Assign` pill or the word
//  `Conflict`. `5b` is the block editor's per-court coach rows, which draw the same subtitle in
//  place. One implementation and two readers, because the alternative is the failure this
//  codebase keeps recording: three screens each with their own answer to one question is how the
//  tabs came to disagree in the first place (`SectionEight.swift:376-382`).
//
//  ── WHY `running(in:at:)` AND NOT `BlockRules.overlaps` ──────────────────────────────────────
//
//  There are two rules in this app for "are these two blocks in each other's way", and they give
//  different answers on purpose. `BlockRules.overlaps(_:_:)` (`BlockEditorDraft.swift:151-157`)
//  says **a block with no stated end clashes with nothing**, and argues it at length: `ends_at` is
//  nullable by design, every block `DayShape` writes is open-ended, and reading an open end as
//  "until midnight" would put a warning on every block after the 8:30 drop-off — a flag that
//  fires on the app's own output is a flag nobody reads.
//
//  That is right for a clash flag and wrong for availability. An open-ended block a coach is
//  standing on **does** occupy them: the drop-off has no stated end, and the person running it is
//  not free to take Court 2 at nine o'clock merely because nobody typed a finish time in.
//  `ScheduleBlock.running(in:at:)` (`SectionEight.swift:459`) is the primitive that reads it the
//  honest way — it closes an open end with `hasFinished(_:by:amongst:)`
//  (`SectionEight.swift:520`), which is "whatever starts next in the same space", and that is
//  exactly what frees a coach in practice.
//
//  So: the amber clash line on `8k` and the `Conflict` word on `4d` are answering different
//  questions and are entitled to disagree about an open-ended block. Both readings are written
//  down; neither is the other's bug.
//

import Foundation

/// What one coach is doing at the moment a block starts, in the three shapes `4d` draws.
///
/// Three cases rather than a `Bool` and a `String?`, because the trailing control, the subtitle
/// colour and whether the row is pressable all move together and a pair of independent fields
/// could contradict each other — a row saying "Free now" beside the word `Conflict` is a state
/// this type cannot express.
///
/// The strings inside are already resolved — `Court 3`, not a `Group.ID` — so the type is a
/// finished sentence and not another graph walk waiting to happen. It costs the ability to
/// re-resolve a label later, which nothing wants: the sheet is open for a moment over a camp
/// nobody is editing from the other side.
enum CoachAvailability: Hashable, Sendable {

    /// Nothing else has them when this block starts. `where` is where they normally stand, which
    /// is context rather than an obstacle: "Free now · roaming", "Free now · Court 3".
    ///
    /// Optional so the segment can genuinely be absent — `subtitle` prints "Free now" alone
    /// rather than a middot with nothing after it. `of(_:staffing:day:camp:)` always has
    /// something to say here, but a preview or a test constructing the case directly should not
    /// have to invent a whereabouts to get the plain reading.
    case free(where: String?)

    /// Busy now, free part way through this block: "Free at 10:30 · Court 2 until then".
    ///
    /// The middle tier exists because it is a real answer to a real question. Somebody staffing
    /// an eleven-o'clock match play does want to know that Nass is on a warm-up until half past —
    /// that is a coach they can have, ten minutes late, and refusing them outright would hide a
    /// workable answer behind a flat no.
    case freesAt(TimeOfDay, court: String?)

    /// Taken for the whole of this block: "On Court 3 · Skills stations".
    ///
    /// The block's title rather than a generic "busy", because the person reading knows their own
    /// morning. "Skills stations" tells them whether it is the thing they could move; "Busy" does
    /// not.
    case busy(court: String?, blockTitle: String)

    /// The one grey line under the coach's name.
    ///
    /// **Never an empty middot.** Every segment after the first is optional and each is dropped
    /// whole rather than printed blank, so a coach with no resolvable court reads "Free now" and
    /// "Skills stations" rather than "Free now · " and "On · Skills stations". The separator is
    /// the design's `·` with a space either side, the same joiner `8k` uses for "Drop-off · done"
    /// and `Role.staffRowLabel` uses for "Other · front desk".
    ///
    /// Times are `TimeOfDay.shortLabel` (`Models.swift:284`) and never `clockLabel`: the design
    /// writes "Free at 10:30", and "Free at 10:30am" is two more characters on a line that
    /// already wraps.
    ///
    /// "roaming" stays lower-case, and that is the one spelling worth flagging.
    /// `StaffMember.courtChip` (`Models.swift:719-722`) and `BlockAssigneeList.swift:125` both
    /// write `Roaming` capitalised because in both of those it stands alone in a column. Here it
    /// is mid-sentence after a middot, so it takes the case a word mid-sentence takes.
    var subtitle: String {
        switch self {
        case .free(let place):
            joined("Free now", place)
        case .freesAt(let time, let court):
            joined("Free at \(time.shortLabel)", court.map { "\($0) until then" })
        case .busy(let court, let title):
            // The court leads when there is one — "On Court 3 · Skills stations" — and the whole
            // "On …" clause goes when there is not, leaving the title to say the true thing on
            // its own. "On · Skills stations" is the empty middot; "On Skills stations" is worse,
            // because it reads as a court called Skills stations.
            joined(court.map { "On \($0)" } ?? title, court == nil ? nil : title)
        }
    }

    /// True only for `.busy` — the row goes inert and shows "Conflict" instead of "Assign".
    ///
    /// `.freesAt` is deliberately not a conflict. It is drawn quieter than `.free` — an outlined
    /// pill rather than a filled one — and it is still a tap, because a coach who arrives ten
    /// minutes in is a decision somebody is allowed to make. Amber warns and never blocks a save,
    /// which is the rule this app applies everywhere; `Conflict` is inert here only because there
    /// is genuinely nothing to press, not because the app is refusing.
    var isConflict: Bool {
        if case .busy = self { return true }
        return false
    }

    /// Whether the `Assign` beside this coach is the filled one.
    ///
    /// `isConflict` answers the far end of the same three-way question and this is the near end,
    /// which is why they are neighbours: `.free` is a filled accent pill, `.freesAt` the outlined
    /// one, `.busy` no pill at all. Written as a property rather than as `if case .free` at the
    /// call site because that call site is a ternary inside a nine-argument initialiser, which is
    /// where the type checker gives up (`BlockDetailView.swift:195` records the same failure).
    ///
    /// Declared here rather than in the sheet that reads it (`BlockCourtStaffingSheet.swift:283`),
    /// which is where it was: a predicate about a case belongs on the type, beside the predicate
    /// about the other case, and its own comment there recorded that this file was its real home
    /// and that the file did not yet exist to move it into. It does now — this change created it.
    var isFreeNow: Bool {
        if case .free = self { return true }
        return false
    }

    /// `head`, then ` · tail` when there is a tail. One place, so no case can invent a second
    /// separator or leave a trailing one.
    private func joined(_ head: String, _ tail: String?) -> String {
        guard let tail, !tail.isEmpty else { return head }
        return "\(head) · \(tail)"
    }
}

extension CoachAvailability {

    /// What `member` is doing when `block` starts, given the rest of `day`.
    ///
    /// The moment asked about is `block.startsAt` and not the wall clock. `4d` is opened to staff
    /// a block that may not have started — the question is "can this person take Court 2 at
    /// 10:45", not "are they busy right now" — and reading the clock would make the answer change
    /// under a sheet that is standing still.
    ///
    /// ── THE THREE TIERS ──────────────────────────────────────────────────────────────────────
    ///
    /// | tier | condition |
    /// |---|---|
    /// | `.free` | no other block staffs them at `block.startsAt` |
    /// | `.freesAt` | the busy block ends after this one starts **and** before this one ends |
    /// | `.busy` | otherwise — no stated end, or an end at or after this block's |
    ///
    /// The middle tier's second half is what keeps it honest. A block that ends exactly when this
    /// one does frees nobody *during* it, and one with no stated end has not said it frees them at
    /// all; both fall to `.busy`. Note that `block.endsAt == nil` collapses the tier entirely —
    /// this block runs to an unstated end, so nothing can be said to finish part way through it —
    /// which is the correct reading rather than an oversight about optionals.
    ///
    /// ── WHAT COUNTS AS STAFFED ───────────────────────────────────────────────────────────────
    ///
    /// Block-wide `coachIDs` **and** per-court `staffing`, either one. The per-court list alone
    /// would be a rule that reported the entire back catalogue as unoccupied: every block written
    /// before `BlockCourtStaffing` existed carries its coaches on `coachIDs` and nothing in
    /// `staffing`, and so does every `.regular` block written after it, since a whole-camp lunch
    /// has no courts to staff. A coach running the lunch is not free to take Court 2 during it.
    ///
    /// ── ITSELF ───────────────────────────────────────────────────────────────────────────────
    ///
    /// `block` is skipped by id. A coach already on the block being staffed is not in conflict
    /// with themselves — `4d` is where somebody goes to move them from one court to another, and
    /// a picker that greyed out the person it was opened to move would be a dead end.
    ///
    /// The venue and day guards are here rather than assumed. `AppStore.scheduleBlocks` holds one
    /// of each and `4d` will pass exactly that, but `running(in:at:)` filters on time before it
    /// filters on anything else, so a caller that handed over two days would otherwise be told a
    /// coach is busy on Wednesday because of something on Thursday. The same guard is the first
    /// line of `BlockRules.sharesSpace(_:_:)` (`BlockEditorDraft.swift:187`), for the same reason.
    ///
    /// **For a list of people, call `map(for:staffing:day:camp:)` instead.** This is the one-member
    /// spelling and it resolves the candidate blocks from scratch each time; that one resolves them
    /// once. Both are written in terms of the same two helpers below, so they cannot answer
    /// differently — the difference is only how often the member-independent half runs.
    static func of(
        _ member: StaffMember,
        staffing block: ScheduleBlock,
        day: [ScheduleBlock],
        camp: Camp
    ) -> CoachAvailability {
        reading(
            for: member, amongst: candidates(staffing: block, in: day), staffing: block, camp: camp
        )
    }

    /// The same answer for a whole list of people, with the expensive half done once.
    ///
    /// ── WHY THIS EXISTS ──────────────────────────────────────────────────────────────────────
    ///
    /// Everything to the left of `staffs($0, member.id)` in `of(_:staffing:day:camp:)` depends on
    /// `(block, day)` and not on the member at all — `running(in:at:)` plus the three guards. Both
    /// call sites *were* loops over a venue's coaches, so that work ran once per person to produce
    /// one dictionary; they are single calls to this now (`BlockEditorSheet.swift:721`,
    /// `BlockCourtStaffingSheet.swift:370`), which is what the loop was hiding, and it is not
    /// cheap work:
    ///
    ///   - `running(in:at:)` filters through `hasFinished(_:by:amongst:)`
    ///     (`SectionEight.swift:520`), which for an **open-ended** block walks the whole day again
    ///     and builds up to two `Set<UUID>`s per pair through `BlockRules.sharesSpace(_:_:)`;
    ///   - and `BlockEditorDraft.swift:148-150` records that *every* block a `DayShape` writes is
    ///     open-ended, so the O(N²) reading is not the worst case, it is the ordinary one;
    ///   - then it sorts, and that sort used to spell both ids out as `String`s per comparison
    ///     (`UUID.precedes(_:)`, `Models.swift:28-65`, is what it costs now).
    ///
    /// The block editor's `body` redraws on every keystroke in the title field, so the whole of
    /// that ran per character typed, per coach at the venue.
    ///
    /// ── WHAT IT DOES NOT CHANGE ──────────────────────────────────────────────────────────────
    ///
    /// The answer, for anybody. `candidates(staffing:in:)` is the same filter with the one
    /// member-dependent clause lifted out of it, and `first` over a list `running(in:at:)` has
    /// already sorted still picks the earliest-starting block that holds this person — which is the
    /// choice `ScheduleBlock.running(on:in:at:)` (`SectionEight.swift:490`) makes for a court and
    /// `BlockRules.overlap(with:in:)` makes for a clash. A dictionary rather than an array because
    /// both callers index it by `StaffMember.ID` while drawing rows, and both built exactly this
    /// dictionary with the identical six lines before it lived here.
    ///
    /// Two people with the same id would collapse into one entry. That is the same statement
    /// `reduce(into:)` at either call site already made, and a camp with two staff rows sharing a
    /// `UUID` has a graph problem this list cannot answer for.
    static func map(
        for members: [StaffMember],
        staffing block: ScheduleBlock,
        day: [ScheduleBlock],
        camp: Camp
    ) -> [StaffMember.ID: CoachAvailability] {
        let candidates = candidates(staffing: block, in: day)
        return members.reduce(into: [:]) { found, member in
            found[member.id] = reading(
                for: member, amongst: candidates, staffing: block, camp: camp
            )
        }
    }

    /// The blocks that could be holding *somebody* when `block` starts — everything the three tiers
    /// rest on that is not about a particular person.
    ///
    /// `block` itself is dropped here rather than at the per-member test, and the venue and day
    /// guards with it, because none of the three has anything to do with who is being asked about.
    /// See `of(_:staffing:day:camp:)` above for what each of them is for; this is that filter with
    /// the fourth clause — the only member-dependent one — left to `reading(for:amongst:…)`.
    private static func candidates(
        staffing block: ScheduleBlock, in day: [ScheduleBlock]
    ) -> [ScheduleBlock] {
        ScheduleBlock.running(in: day, at: block.startsAt).filter {
            $0.id != block.id && $0.venueID == block.venueID && $0.day == block.day
        }
    }

    /// One member's tier, given the candidates already resolved.
    ///
    /// The three-tier table in `of(_:staffing:day:camp:)`'s doc is this function; it is written once
    /// here so the single-member and the whole-list spellings are the same rule rather than two
    /// copies of it that could drift.
    private static func reading(
        for member: StaffMember,
        amongst candidates: [ScheduleBlock],
        staffing block: ScheduleBlock,
        camp: Camp
    ) -> CoachAvailability {
        guard let busy = candidates.first(where: { staffs($0, member.id) }) else {
            return .free(where: whereabouts(of: member))
        }

        let court = court(of: member, on: busy, camp: camp)

        if let ends = busy.endsAt, ends > block.startsAt, let mine = block.endsAt, ends < mine {
            return .freesAt(ends, court: court)
        }
        return .busy(court: court, blockTitle: busy.title)
    }

    /// Whether this block has `id` on it at all — on the block as a whole, or on any one of its
    /// courts. See the note above on why both halves count.
    private static func staffs(_ block: ScheduleBlock, _ id: StaffMember.ID) -> Bool {
        block.coachIDs.contains(id) || block.staffing.contains { $0.coachIDs.contains(id) }
    }

    /// Where a free coach normally stands: "roaming", "Court 3", or "no court".
    ///
    /// Roaming first, because it is a fact about the person and outranks whatever posting they
    /// may still be carrying — `Role.roamsByDefault` (`Models.swift:359`) is what makes a trainer
    /// one, and `StaffMember.courtChip` (`:719-722`) already reads the two in this order.
    ///
    /// "no court" rather than nothing, because for a *free* coach the absence is the useful part:
    /// the person with no standing posting is the one to give a court to, and a subtitle reading
    /// "Free now" alone would leave the reader wondering whether the line had failed to load.
    private static func whereabouts(of member: StaffMember) -> String {
        if member.isRoaming { return "roaming" }
        return member.assignment?.groupLabel ?? "no court"
    }

    /// Which court is holding `member` inside `busy`, in words.
    ///
    /// Three sources, narrowest first, and the order is the point — each is a weaker claim than
    /// the one above it, and the last resort is to say nothing:
    ///
    ///   1. the court they are staffed on **inside that block**, which is the only one of the
    ///      three that is actually an answer to the question asked;
    ///   2. the block's own court, when it names exactly one — a coach on a single-court block is
    ///      on that court whether or not anybody recorded it per-court. Exactly one, not the
    ///      first of several: picking one of three would be a guess drawn as a fact;
    ///   3. their standing posting, which says where that person usually is rather than where
    ///      this block has them, and is a fair guess for a `.regular` block that names no courts.
    ///
    /// Nil when none of the three answers, and `subtitle` then drops the segment whole. A wrong
    /// court on this line is worse than no court: somebody would walk to it.
    private static func court(
        of member: StaffMember, on busy: ScheduleBlock, camp: Camp
    ) -> String? {
        if let staffed = busy.staffing.first(where: { $0.coachIDs.contains(member.id) }),
           let label = camp.group(staffed.courtID)?.label {
            return label
        }
        if busy.courtIDs.count == 1, let label = camp.group(busy.courtIDs[0])?.label {
            return label
        }
        return member.assignment?.groupLabel
    }
}
