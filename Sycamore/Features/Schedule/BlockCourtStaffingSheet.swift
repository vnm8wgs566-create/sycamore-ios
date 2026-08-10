//
//  BlockCourtStaffingSheet.swift
//  Sycamore
//
//  `4d` — "Who takes Court 2?". The sheet the amber flag opens.
//
//  Two screens open it and neither of them owns it. `5d`'s per-court card reaches it through
//  `Reassign` and `Add a coach`; `8k`'s block card reaches it through the amber `Needs a coach`
//  line, which is the design's own claim about the entry point — "the amber flag is the button"
//  (`design/rebuild/section-t4.html:205`). So the type is named and shaped for two callers rather
//  than lifted out of one of them, and its initialiser takes the three things either caller has:
//  the block, the court being staffed, and the way out.
//
//  ── The store arrives through the environment ────────────────────────────────────────────────
//
//  `CourtCoachPicker` takes its `AppStore` as a `let`, and this one does not. That is the price of
//  having two callers: the shape above is a contract with a card in another file, and adding a
//  fourth argument to it would make every caller restate what `@Environment` already carries.
//  Both presenters must therefore re-inject it — `.environment(store)` on the `.sheet` content —
//  for the reason `BlockDetailView` already gives about the editor: this sheet is presented from
//  inside a cover, and a cover is not somewhere the root's environment can be relied on to reach.
//
//  ── Single-select, and it commits on the tap ─────────────────────────────────────────────────
//
//  `BlockCoachPicker` is a checklist because a block can be run by three people. A *court* of a
//  block is one slot, the same way `CourtCoachPicker` argues about `coaches.group_id`, so a row
//  here is a commit and not a toggle. There is no Done button, because there is nothing to
//  confirm.
//
//  ── What it writes ───────────────────────────────────────────────────────────────────────────
//
//  `ScheduleBlock.staffing`, through `store.updateScheduleBlock`. Deliberately **not**
//  `store.assignStaff(_:toGroup:)`, which moves a coach's *standing* posting — where the camp
//  keeps them all day — and is a different fact from who runs Court 2 for the ninety minutes this
//  block lasts. `CourtCoachPicker` writes the first; this writes the second; the two screens look
//  alike and must not be folded together.
//

import SwiftUI

struct BlockCourtStaffingSheet: View {

    /// Handed in rather than re-read from the store by id.
    ///
    /// Both callers already hold the block — `5d` was opened on it and `8k`'s card is drawn from
    /// it — and the sheet is open for a moment over a day nobody is editing from the other side.
    /// The one thing it must not do is go stale in a way that matters, and it cannot: the write
    /// below amends this value and hands the whole block back, so a copy is exactly what the
    /// commit needs.
    let block: ScheduleBlock
    /// The court being staffed, or nil for the block as a whole.
    ///
    /// Nil is not an error case. A `.regular` block names no courts — a lunch happens on none of
    /// them in particular — so "this block needs somebody" is the only question there is to ask
    /// about it, and the title falls back to `Who takes Match play?`. The write follows the same
    /// fork: a court gets `staffing`, the block gets `coachIDs`.
    let courtID: Group.ID?
    /// How the sheet gets out of the way: it clears the state its caller is holding. The shape
    /// `CourtCoachPicker`, `BlockEditorSheet` and `EarlyPickupSheet` all take, and for the reason
    /// the first of those gives — the caller owns the state, so the caller is the only one who can
    /// put it down.
    let onDismiss: () -> Void

    /// Spelled out rather than left to the memberwise one, because it is a contract with a file in
    /// another unit. The synthesised initialiser would carry the two property wrappers below as
    /// trailing defaulted arguments and would grow a third the day somebody adds a `@ScaledMetric`
    /// — silently, and only breaking the *other* caller. Three arguments, in this order, is what
    /// both presenters were told they could rely on.
    init(block: ScheduleBlock, courtID: Group.ID?, onDismiss: @escaping () -> Void) {
        self.block = block
        self.courtID = courtID
        self.onDismiss = onDismiss
    }

    @Environment(AppStore.self) private var store

    /// `4d`'s 34pt disc, which is a size larger than the block editor's picker rows draw. The
    /// design sets this sheet's rows at `12px 13px` with a 34 avatar where `BlockPickRow` sits at
    /// 30; the difference is that this list is the whole screen and that one is a card inside a
    /// long form.
    @ScaledMetric(relativeTo: .body) private var avatarSize = BlockCourtStaffingSheet.avatar

    var body: some View {
        // Resolved once, in `body`, and handed down. `SheetChrome` builds its content eagerly, so
        // a computed `people` would be a filter and a sort of the camp's whole staff list twice in
        // one pass — and `availability` walks the day's blocks once per person, which is the last
        // thing to put behind a `var`. `CourtCoachPicker` binds its pool for the same reason.
        let me = store.myStaffRecord?.id
        let people = BlockCoachPicker.pool(in: store.camp, venueID: block.venueID, me: me)
        let availability = self.availability(for: people)
        let ordered = Self.ordered(people, by: availability)
        let taken = Set(currentCoachIDs)

        return SheetChrome(
            title: "Who takes \(objectLabel)?",
            // The eyebrow, above the title rather than under it — `Match play · 10:45–12:00 ·
            // Sycamore`. It is a place-marker and not a continuation: somebody reaching this sheet
            // from `8k` has tapped one line on a card and needs to be told which block they are
            // now staffing before they are asked a question about it.
            subtitle: eyebrow,
            subtitlePlacement: .eyebrow,
            // `400 26/1.05` serif (`design/rebuild/section-t4.html:222`). That is the block
            // editor's title style to the point, and it is reached by its name rather than
            // restated here — `ScheduleTokens.swift` is not this unit's file, so a `pickerTitle`
            // row beside `editorTitle` is a change to somebody else's table for a value that
            // already exists in it. If the two ever part, this is the call site to split.
            titleStyle: ScheduleType.editorTitle,
            // The same fraction `CourtCoachPicker` uses, because it is the same question at the
            // same length: a card of people over a footnote.
            detentFraction: OverviewTheme.coachPickerDetent,
            onClose: onDismiss
        ) {
            // 13 under the title where the design draws 16. `SheetChrome` owns the gap under its
            // header and every other sheet in the app takes that value; three points bought by
            // padding one sheet's first child is three points of drift in a scaffold eight files
            // share.
            if ordered.isEmpty {
                emptyCard
            } else {
                Card(radius: ScheduleMetrics.cardRadius) {
                    ForEach(ordered) { member in
                        row(member, availability[member.id], isOn: taken.contains(member.id), me: me)
                    }
                }
            }

            footnote
        }
    }

    // MARK: What the sheet is about

    /// `Court 2`, or the block's own title when no court was named.
    ///
    /// Resolved from the graph per pass rather than handed in, so a court renamed in camp settings
    /// while this is open retitles instead of lying — the argument `CourtCoachPicker.courtLabel`
    /// makes about the same string.
    private var objectLabel: String {
        guard let courtID else { return block.title }
        return store.group(courtID)?.label ?? "this court"
    }

    /// `Match play · 10:45–12:00 · Sycamore`.
    ///
    /// Assembled from segments and joined once, so a block with no venue resolved prints two
    /// segments rather than a trailing middot. Never an empty middot is the rule
    /// `CoachAvailability.subtitle` states for the line under each name; it is the same rule here.
    ///
    /// The block's title leads even though the sheet is opened *from* that block, because one of
    /// the two callers is a card on a list of five of them and the tap that got here was on a
    /// single grey line.
    private var eyebrow: String? {
        let parts = [block.title, block.shortTimeLabel, store.venue(block.venueID)?.name]
        let joined = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return joined.isEmpty ? nil : joined.joined(separator: " · ")
    }

    /// Who is on this court — or on this block — right now, so their row can be marked.
    ///
    /// `coachIDs(onCourt:)` and not `staffing` read by hand: that method carries the fallback
    /// argued at `SectionEight.swift:293-318`, where a court with no entry of its own is staffed
    /// by whoever runs the block. A picker that ignored it would offer `Add a coach` on a court
    /// that visibly has one.
    private var currentCoachIDs: [StaffMember.ID] {
        guard let courtID else { return block.coachIDs }
        return block.coachIDs(onCourt: courtID)
    }

    /// `Only staff at Sycamore today are shown` — the footnote is a claim about the pool, and the
    /// pool is `BlockCoachPicker.pool`, whose own header calls it "everybody who could plausibly
    /// run something at this venue". The two have to say the same thing or the list looks short.
    ///
    /// The venue is interpolated, and the sentence has a form for the camp that has not resolved
    /// one — a footnote reading "Only staff at  today are shown" is worse than a vaguer true one.
    private var footnote: some View {
        Text(footnoteText)
            .typeStyle(.rowDetail, color: Theme.inkFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.medium)
    }

    private var footnoteText: String {
        guard let venue = store.venue(block.venueID)?.name, !venue.isEmpty else {
            return "Only staff at this venue today are shown"
        }
        return "Only staff at \(venue) today are shown"
    }

    /// A camp with nobody in it to offer, worded as `CourtCoachPicker.emptyCard` and
    /// `BlockCoachPicker.emptyRow` word theirs: the pool carries every admin and your own row, so
    /// an empty list means the camp has no staff at all rather than none posted here.
    private var emptyCard: some View {
        Card(radius: ScheduleMetrics.cardRadius, isDivided: false) {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                Text("There is nobody to put on this yet. Add staff in camp settings and they show up here.")
                    .typeStyle(.rowDetail, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: A row

    /// Avatar, name, the one grey line that says whether you can have them, and the control.
    ///
    /// The fourth drawing of this row in the app, and it is one too many —
    /// `CourtCoachPicker.swift:27-42` already records that three is the point at which a shared
    /// `StaffPickRow` is owed. It is not built here for the reason that note gives: the shared row
    /// belongs beside `BlockCoachPicker` or in the design system, and retrofitting the other three
    /// is a change to two folders this unit does not own. What the four do share is their
    /// *words* — `BlockCoachPicker.rowTitle(for:me:)` spells "· you" once, and
    /// `CoachAvailability.subtitle` spells the grey line once for this sheet and the editor's.
    private func row(
        _ member: StaffMember,
        _ free: CoachAvailability?,
        isOn: Bool,
        me: StaffMember.ID?
    ) -> some View {
        let isConflict = free?.isConflict == true

        return CardRow(
            spacing: Spacing.row,
            horizontalPadding: Self.rowInset,
            verticalPadding: Spacing.medium
        ) {
            InitialsAvatar(member.initials, size: avatarSize)
                // The dim lands here and on the trailing word, not on the row. See below.
                .opacity(isConflict ? Self.conflictDim : 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(BlockCoachPicker.rowTitle(for: member, me: me))
                    .typeStyle(.rowLabel, color: Theme.ink)

                if let subtitle = free?.subtitle {
                    // Allowed to wrap. "Free at 10:30 · Court 2 until then" truncated at an
                    // accessibility size loses the half that says which court you would be
                    // emptying, which is the only part of the line that is a warning.
                    Text(subtitle)
                        .typeStyle(.rowDetail, color: Self.subtitleColour(free))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: Spacing.small)

            trailing(member, free, isOn: isOn)
        }
        // The design dims the whole conflicted row to `.55`. Drawn here as a dim on the *disc*
        // and on the trailing `Conflict` — the two runs that carry no information a reader needs
        // to act — and never on the name or the availability line.
        //
        // Applied to the row it composites the text as well, and the arithmetic against
        // `Theme.surface` is not close: the availability line (`rowDetail` 12.5 in `inkMuted`)
        // lands at **1.81:1** and `Conflict` (`metaStrong` in `warning`) at 1.93:1, against a
        // 4.5:1 floor. The name scrapes 4.36:1. So the row-wide version failed the one reader the
        // paragraph that used to sit here said it was for: it argued, correctly, that "the reason
        // a coach cannot be had is the most useful sentence on the screen for somebody who cannot
        // see the dimming" — and then dimmed that exact sentence to the least legible thing on it.
        // VoiceOver was never the reader at risk here; low vision was.
        //
        // The greying still reads, because it does not depend on the text being faint: the disc
        // is the largest mark in the row, `Conflict` is already amber where its neighbours are
        // green, and the subtitle is already `inkMuted` where a free coach's is `accent`. Three
        // signals, none of them contrast.
    }

    /// The filled `Assign`, the outlined one, the word `Conflict`, and the tick on whoever already
    /// has this court.
    ///
    /// Four states and only two of them are buttons. `Conflict` is a statement — amber warns and
    /// never blocks, which is the rule this app applies everywhere, and it is inert here only
    /// because there is genuinely nothing to press on a coach who is on something else for the
    /// whole of this block. The tick is inert for the mirror-image reason: they are already on it.
    @ViewBuilder
    private func trailing(_ member: StaffMember, _ free: CoachAvailability?, isOn: Bool) -> some View {
        if isOn {
            // `CourtCoachPicker`'s mark, for the same reason it gives: on a list that commits on
            // the first tap a tick is a statement about the court, not an unchecked box.
            Image(systemName: "checkmark")
                .font(.system(size: Self.mark, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("\(member.name) already has \(objectLabel)")
        } else if free?.isConflict == true {
            Text("Conflict")
                .typeStyle(.metaStrong, color: Theme.warning)
                // Dimmed here rather than by the row, so the two lines of copy beside it keep
                // their contrast. The word is a restatement of the subtitle, so it is the one
                // run on the row that can afford to go quiet.
                .opacity(Self.conflictDim)
                .accessibilityLabel("\(member.name) is not free. \(free?.subtitle ?? "")")
        } else {
            // One control at two strengths, not two controls. `.accent` for a coach who is free
            // now, `.accentOutline` for one who frees up part way through — the tap does the same
            // thing either way, and the tiers differ by *when*.
            Pill(
                "Assign",
                tone: free?.isFreeNow == false ? .accentOutline : .accent,
                font: .chip,
                horizontalPadding: Spacing.large,
                verticalPadding: Self.pillPadding,
                borderWidth: BorderWidth.input
            ) {
                assign(member.id)
            }
            // The drawn word names no object, because beside a named person inside a sheet titled
            // "Who takes Court 2?" it does not have to. The spoken one does — a screen reader
            // arrives at this button having read the name, and "Assign" alone is a verb with two
            // missing halves.
            .accessibilityLabel("Assign \(member.name) to \(objectLabel)")
        }
    }

    /// Accent for a coach who is free now, grey for one who frees up part way through.
    ///
    /// The design's own two (`design/rebuild/section-t4.html:229`, `:234`), and there is no third:
    /// a `.busy` row's grey line is the same grey, because the amber on that row is spent on the
    /// word `Conflict` beside it. `BlockCoachPicker.detailColor` makes the opposite call for the
    /// editor — amber on the line, nothing in the trailing slot — and the two are right for their
    /// own screens rather than in disagreement: each puts the warning in the one place its row
    /// has for one.
    private static func subtitleColour(_ free: CoachAvailability?) -> Color {
        switch free {
        case .free: Theme.accent
        case .freesAt, .busy, nil: Theme.inkMuted
        }
    }

    // MARK: The write

    /// Close, then write — `CourtCoachPicker.assign`'s order, and the reasoning is that file's.
    ///
    /// A sheet that sits open through a round trip with nothing moving on it reads as a tap that
    /// missed, and a refusal belongs on the banner over the tab rather than inside a sheet still
    /// claiming to be picking somebody. `AppStore.perform` owns `errorMessage`; this screen only
    /// has to be somewhere it can be seen from, and it is not.
    ///
    /// ── Replace on a court, add on a block ───────────────────────────────────────────────────
    ///
    /// A court's list is *set* to the one name. `Reassign` means replace, and `Add a coach` on an
    /// empty court has nothing to replace, so both are one statement. `BlockCourtStaffing.coachIDs`
    /// stays a list because the ten-minute handover is a thing the model must be able to write
    /// down (`SectionEight.swift:130-133`) — `4d` is the one-tap reassignment and writes one name;
    /// nothing here forbids a second being written from somewhere else.
    ///
    /// The block-wide arm appends instead, and the asymmetry is the honest one: a block is run by
    /// however many people run it, and this sheet is opened on a block that has nobody. Replacing
    /// there would quietly take the other two coaches off a lunch.
    private func assign(_ staffID: StaffMember.ID) {
        onDismiss()

        var updated = block
        if let courtID {
            if let index = updated.staffing.firstIndex(where: { $0.courtID == courtID }) {
                updated.staffing[index].coachIDs = [staffID]
            } else {
                updated.staffing.append(BlockCourtStaffing(courtID: courtID, coachIDs: [staffID]))
            }
        } else if !updated.coachIDs.contains(staffID) {
            updated.coachIDs.append(staffID)
        }

        Task { await store.updateScheduleBlock(updated) }
    }

    // MARK: Availability

    /// One `CoachAvailability` per person, resolved before the rows are built.
    ///
    /// `CoachAvailability.map` and not a `reduce` over `CoachAvailability.of` written out here,
    /// which is what stood and what the editor's own copy stood as too. The one-member spelling
    /// resolves the day's running blocks from scratch each time it is asked, and everything in
    /// that half depends on the block and the day rather than on the person — so a loop over a
    /// venue's coaches ran it once per coach to build one dictionary. `map` runs it once and
    /// answers identically; both are written in terms of the same two helpers.
    ///
    /// Resolving it inside `row` would be worse again: that is the same walk once per *row*, which
    /// is the mistake this sheet was written to avoid and the editor had already made once.
    ///
    /// Empty while the camp is still loading, and every row then draws its name with no grey line
    /// under it rather than a line that has guessed. `4d` cannot fall back to "where they stand"
    /// the way the editor's picker does: this sheet's entire question is *when*.
    private func availability(for people: [StaffMember]) -> [StaffMember.ID: CoachAvailability] {
        guard let camp = store.camp else { return [:] }
        return CoachAvailability.map(
            for: people, staffing: block, day: store.scheduleBlocks, camp: camp
        )
    }
}

// MARK: - The order of the list

extension BlockCourtStaffingSheet {

    /// Free first, then the ones who free up part way through, then the ones who cannot be had.
    ///
    /// `BlockCoachPicker.pool` returns the design's order for a list of people at a venue and lifts
    /// *you* to the very top of it. That is right on a checklist, where the row somebody is hunting
    /// for is their own. It is wrong here unqualified: a reader who is booked solid would sit above
    /// three coaches who are free, and the first thing this sheet is for is answering "who can I
    /// have". So the tiers sort first and the pool's order — including its "you first" — survives
    /// **inside** each tier.
    ///
    /// Sorted through `enumerated()` rather than by calling `sorted` on the people directly, because
    /// `Array.sorted` is not documented stable and the whole value of this sort is that it does not
    /// disturb what the pool already decided. The original index is the tiebreak, which makes it
    /// stable by construction rather than by luck.
    ///
    /// A person with no entry — the camp had not loaded when the rows were built — ranks with the
    /// free, which is the only tier that does not make a claim the app cannot back up.
    nonisolated static func ordered(
        _ people: [StaffMember], by availability: [StaffMember.ID: CoachAvailability]
    ) -> [StaffMember] {
        people.enumerated()
            .sorted { left, right in
                let lhs = tier(availability[left.element.id])
                let rhs = tier(availability[right.element.id])
                return lhs == rhs ? left.offset < right.offset : lhs < rhs
            }
            .map(\.element)
    }

    private nonisolated static func tier(_ free: CoachAvailability?) -> Int {
        switch free {
        case .free, nil: 0
        case .freesAt: 1
        case .busy: 2
        }
    }
}

// MARK: - Metrics

/// The design's own numbers for this sheet, kept beside the view rather than added to
/// `ScheduleMetrics`. `ScheduleTokens.swift` is not this unit's file, and four private constants
/// used by one view are not a vocabulary anything else has to share; the day a second screen wants
/// them is the day they move.
private extension BlockCourtStaffingSheet {
    /// `width:34px;height:34px` (`design/rebuild/section-t4.html:227`).
    static let avatar: CGFloat = 34
    /// `padding:12px 13px` — the vertical half is `Spacing.medium`, the horizontal is the card
    /// gutter `CardRow` already defaults to and is restated so the row cannot drift if that
    /// default moves.
    static let rowInset: CGFloat = 13
    /// `padding:9px 16px` on the pill.
    static let pillPadding: CGFloat = 9
    /// The tick on whoever already has the court, at `CourtCoachPicker`'s size.
    static let mark: CGFloat = 17
    /// `opacity:.55` on the conflicted row (`design/rebuild/section-t4.html:239`).
    static let conflictDim: Double = 0.55
}

// The two spellings this sheet needs and the model owns are no longer written here.
// `CoachAvailability.isFreeNow` is beside `isConflict` (`CoachAvailability.swift:118-133`) and
// `ScheduleBlock.shortTimeLabel` beside `timeLabel` (`SectionEight.swift:210-234`), which is where
// both of their own comments said they belonged and where they went the day those files were this
// wave's to edit. The call sites at `:153` and `:283` are unchanged: a member declared on the type
// resolves the same whichever file it is written in.

// MARK: - Previews

private struct BlockCourtStaffingPreview: View {
    var courtIndex: Int?

    @State private var store = AppStore.previewUCLAAdmin

    var body: some View {
        let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
        let block = blocks[1]
        let courts = BlockCourtPicker.courts(on: block, in: SampleData.uclaTennisCamp)

        ZStack(alignment: .bottom) {
            Theme.scrim.ignoresSafeArea()

            BlockCourtStaffingSheet(
                block: block,
                courtID: courtIndex.flatMap { courts.indices.contains($0) ? courts[$0].id : nil },
                onDismiss: {}
            )
            .environment(store)
            .frame(height: 620)
        }
        .frame(height: 848)
        .background(Theme.canvas)
    }
}

#Preview("Who takes this court") {
    BlockCourtStaffingPreview(courtIndex: 1)
}

/// The block-wide question, which is what a `.regular` block can ask and the only thing the amber
/// flag on one of those can mean.
#Preview("Who takes this block") {
    BlockCourtStaffingPreview(courtIndex: nil)
}
