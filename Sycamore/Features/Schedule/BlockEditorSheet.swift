//
//  BlockEditorSheet.swift
//  Sycamore
//
//  The block composer. What a block is called, what happens in it, when it runs and who is on it.
//
//  There was none. `ScheduleView.addFirstBlock` wrote a hardcoded 9:00 "New block" and said so in
//  its own comment, and nothing in the app edited a block's title, description or times ever. This
//  is the screen that was missing, and it is reached from both places a block can be started or
//  changed: the empty day's "Add the first block" and the foot of a populated one, and `8l`'s `⋯`.
//
//  ── A sheet, not a cover ──────────────────────────────────────────────────────────────────────
//
//  `PushedScreen.isFullScreen` (`AppStore.swift:117-126`) states the rule: full screen is for a
//  screen that draws its own way out and runs its own header up under the status bar. This one
//  draws neither. `SheetChrome` already gives it a grabber, a title, a subtitle and a 32pt ✕, so a
//  cover would put a second dismissal control beside one that already exists.
//
//  Three more reasons, none of them decorative. `BlockDetailView.openAttendance` (`:216-219`)
//  records the house position that a cover cannot be presented over a cover — and `8l` *is* a
//  cover, so an editor reached from its `⋯` could not be one. `fullScreenCover` is iOS-only, so a
//  cover would need the `#if os(iOS)` shim `ScheduleView` already writes once written twice more,
//  and everything under `Sycamore/` has to typecheck for macOS. And the app's other three editors
//  — `VenueSheet`, `StaffSheet`, `EarlyPickupSheet` — are all `SheetChrome`.
//
//  ── Presented by its caller, not by the root ──────────────────────────────────────────────────
//
//  Each caller holds its own `@State private var editing: BlockEditorDraft?` and its own
//  `.sheet(item:)`. No case is added to `ActiveSheet`, because `MainTabView` owns that
//  (`RootView.swift:95`) and sits *beneath* `8l`'s cover — asking it to present would open this
//  sheet behind the screen that asked for it. `PlayerScreen.swift:30-35` names that trap in as
//  many words and `EarlyPickupSheet.swift:13-17` restates it. The detent fraction lives on
//  `ScheduleMetrics` for the same reason: `ActiveSheet.detentFraction` is a property of a slot
//  this sheet does not occupy.
//
//  ── Committed once, not on every keystroke ────────────────────────────────────────────────────
//
//  See `BlockEditorDraft`. The field patterns below are `VenueSheet`'s; its live
//  `.onChange(of: draft)` write is not.
//

import SwiftUI

struct BlockEditorSheet: View {

    @Environment(AppStore.self) private var store

    /// The caller hands a value, not a binding — `.sheet(item:)` has no binding to give — so the
    /// sheet takes its own copy to type into. The same shape `VenueSheet.init` takes.
    @State private var draft: BlockEditorDraft
    /// How the sheet gets out of the way: it clears the draft the caller is holding. The state
    /// holding the sheet open belongs to the caller, so the caller is the only one who can put it
    /// down — `EarlyPickupSheet` takes `onClose` for the same reason.
    private let onClose: () -> Void

    @FocusState private var titleFocus: Bool
    @FocusState private var detailFocus: Bool
    @State private var isConfirmingDelete = false

    init(draft: BlockEditorDraft, onClose: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onClose = onClose
    }

    var body: some View {
        // Resolved once and handed to both readers below. `myStaffRecord` is a walk of
        // `camp.staff`, the pool asks for it and so does the picker that draws the pool, and this
        // body re-runs on every keystroke in the title field. `CourtCoachPicker.body` binds the
        // same value for the same reason.
        let me = myID

        return SheetChrome(
            title: draft.isCreating ? "New block" : "Edit block",
            subtitle: subtitle,
            detentFraction: ScheduleMetrics.editorDetent,
            onClose: dismiss
        ) {
            SheetSectionHeader("What it is", bottomPadding: Spacing.small)
            titleField
            descriptionField
                .padding(.top, ScheduleMetrics.editorFieldGap)

            SheetSectionHeader("Type", topPadding: ScheduleMetrics.editorSectionGap)
            kindPicker

            SheetSectionHeader("When", topPadding: ScheduleMetrics.editorSectionGap)
            dayChips
            closedDayNote
            timeFields
                .padding(.top, ScheduleMetrics.editorFieldGap)
            endBeforeStartNote
            overlapNote

            if draft.kind == .assigned {
                SheetSectionHeader("Courts", topPadding: ScheduleMetrics.editorSectionGap)
                BlockCourtPicker(
                    courts: courtPool,
                    selection: $draft.courtIDs,
                    coachNames: courtCoachNames
                )

                kidsSection
            }

            SheetSectionHeader("Coaches", topPadding: ScheduleMetrics.editorSectionGap)
            // The same `me` on both, and it has to be: the pool sorts your row to the top and the
            // picker is what writes "· you" on it, so two different answers would put the suffix
            // on the wrong row.
            BlockCoachPicker(people: coachPool(me: me), selection: $draft.coachIDs, myID: me)

            commitButton
                .padding(.top, ScheduleMetrics.editorSectionGap)

            deleteButton
        }
        // One bar for both fields, because `placement: .keyboard` belongs to the sheet rather than
        // to a field in it — `FormTextArea.keyboardDoneBar` argues that out. Both focus states are
        // cleared rather than the description's alone: the reader can be in either box when they
        // reach for it, and the bar cannot tell which.
        //
        // The description is why it exists. The title has a Return key that means something
        // (`submitLabel(.next)` at `:166`), where Return in a vertical field types a newline — so
        // before this the keyboard came up on "What happens in this block" and did not go down,
        // over a Save button sitting below it.
        .keyboardDoneBar {
            titleFocus = false
            detailFocus = false
        }
        // The precedent is `StaffSheet.swift:41-52`: a destructive, irreversible write behind a
        // full-width button inside a sheet asks first. `8l`'s `⋯` deletes without one and stays
        // that way — a `Button(role: .destructive)` inside a `Menu` is already two deliberate taps
        // with a red word between them, where this is one tap on a bar the thumb is resting near.
        .confirmationDialog(
            "Delete \"\(draft.trimmedTitle.isEmpty ? "this block" : draft.trimmedTitle)\"?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete block", role: .destructive, action: delete)
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its notes go with it. Nothing else on the day moves.")
        }
    }

    /// `Sycamore · Tuesday` — where the block hangs and which day it is currently on. The day is
    /// in the subtitle *and* in the chips below because the subtitle is what a person reads first
    /// and the chips are what they change.
    private var subtitle: String? {
        let venue = store.venue(draft.venueID)?.name
        return [venue, draft.day.fullName].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: What it is

    /// `.sheetBox` with no glyph, at the pick-up sheet's value/placeholder weights — a placeholder
    /// is one step lighter than a value in this design, so the two read apart before the colour
    /// difference lands.
    private var titleField: some View {
        let field = FormField(
            "Skills rotation",
            text: $draft.title,
            label: "Block name",
            metrics: .sheetBox,
            type: ScheduleType.editorValue,
            promptType: ScheduleType.editorPlaceholder,
            focus: $titleFocus
        )

        // Both travel down the environment to the `TextField` inside `FormField`. A block name is
        // a phrase the camp made up ("Water & regroup"), so autocorrect stays on for the same
        // reason the pick-up sheet's "who collects" keeps it: this is not an address or a code.
        #if os(iOS)
        return field
            .textInputAutocapitalization(.sentences)
            .submitLabel(.next)
            .onSubmit { detailFocus = true }
        #else
        return field
        #endif
    }

    /// The first multi-line input in the app — see `FormTextArea`. A description is prose, and
    /// prose typed into a one-line field is read through a letterbox.
    private var descriptionField: some View {
        let field = FormTextArea(
            "What happens in this block",
            text: $draft.detail,
            label: "Description",
            metrics: .sheetBox,
            type: ScheduleType.editorValue,
            promptType: ScheduleType.editorPlaceholder,
            focus: $detailFocus
        )

        // No `submitLabel` and no `onSubmit`: Return inserts a newline in a vertical field, which
        // is why this is a separate type from `FormField` rather than a flag on it. The way out of
        // this one is therefore not its own Return key but the sheet's `keyboardDoneBar` above,
        // and the drag `SheetChrome` now takes.
        #if os(iOS)
        return field.textInputAutocapitalization(.sentences)
        #else
        return field
        #endif
    }

    // MARK: Type

    /// The two kinds, a row each, with the sentence that says what each one means underneath.
    ///
    /// Rows in a `Card` rather than the two-chip segment `dayChips` draws below. A segment has to
    /// put its explanation somewhere, and there is only room for one line under a pair of chips —
    /// so the reader would see the description of whichever option was already selected, which is
    /// the one they least need explaining. `ScheduleBlockKind.detail` was written as "the one line
    /// under each option in the editor's picker" and this is that picker.
    ///
    /// `BlockPickRow` is the row, shared with the two multi-select cards below — see that file for
    /// why single- and multi-select wear the same tick.
    private var kindPicker: some View {
        Card(radius: ScheduleMetrics.cardRadius) {
            ForEach(ScheduleBlockKind.allCases, id: \.self) { kind in
                BlockPickRow(
                    title: kind.displayName,
                    detail: kind.detail,
                    isOn: draft.kind == kind
                ) {
                    draft.kind = kind
                }
            }
        }
    }

    // MARK: When

    /// A chip per day the camp runs, exactly as `ScheduleView.dayChips` draws it: `.day` metrics
    /// carry no horizontal padding by design, so the width comes from `fillsWidth`, and the frame
    /// outside the chip carries the tap to 44pt without moving a pixel of what is drawn.
    ///
    /// The camp's days rather than all seven — see `BlockEditorDraft.dayOptions(in:)`, which holds
    /// the rule and the reason a block already sitting on a closed day keeps its chip.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(draft.dayOptions(in: store.camp)) { day in
                Button {
                    draft.day = day
                } label: {
                    Chip(
                        day.shortName,
                        isSelected: day == draft.day,
                        selectedTone: .accent,
                        metrics: .day,
                        fillsWidth: true
                    )
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(day == draft.day ? .isSelected : [])
            }
        }
    }

    /// Two menus wearing the same box as every field on the sheet. The precedent is
    /// `EarlyPickupSheet.swift:196-205`, which `FormField.swift:110-112` names as the reason
    /// `formFieldChrome` is exposed rather than private: a menu is not a `TextField`, so it
    /// borrows the chrome rather than the component, and the two stop being two drawings of one
    /// thing that have to be kept in step.
    private var timeFields: some View {
        HStack(spacing: Spacing.small) {
            startsAtField
            endsAtField
        }
    }

    private var startsAtField: some View {
        Menu {
            Picker("Starts at", selection: $draft.startsAt) {
                ForEach(BlockClock.options) { time in
                    Text(time.clockLabel).tag(time)
                }
            }
        } label: {
            // No `.lineLimit(1)`. At an accessibility text size "10:45am" no longer fits across
            // half a sheet, and a truncated time is a time nobody can read — the box grows instead.
            Text(draft.startsAt.clockLabel)
                .typeStyle(ScheduleType.editorValue, color: Theme.ink)
                .formFieldChrome(.sheetBox, icon: "clock")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Starts at")
        .accessibilityValue(draft.startsAt.clockLabel)
    }

    /// Carries a "No end time" entry, because `ends_at` is nullable by design —
    /// `20260805074039:27-28` says the design's 8:30 "Drop-off · done" has no stated end, "and
    /// inventing one would put a time on screen that nobody entered".
    ///
    /// The times themselves stop at the start: `BlockClock.endOptions(after:)` omits anything the
    /// `ends_after_starts` CHECK would refuse rather than offering it and then rejecting the tap.
    private var endsAtField: some View {
        Menu {
            Picker("Ends at", selection: $draft.endsAt) {
                Text("No end time").tag(TimeOfDay?.none)
                ForEach(BlockClock.endOptions(after: draft.startsAt)) { time in
                    Text(time.clockLabel).tag(TimeOfDay?.some(time))
                }
            }
        } label: {
            Text(endsAtLabel)
                .typeStyle(ScheduleType.editorValue, color: draft.endsAt == nil ? Theme.inkFaint : Theme.ink)
                .formFieldChrome(.sheetBox, icon: "clock")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ends at")
        .accessibilityValue(endsAtLabel)
    }

    private var endsAtLabel: String { draft.endsAt?.clockLabel ?? "No end time" }

    /// A block left behind when its camp stopped running that day.
    ///
    /// Drawn in the same amber, at the same size, in the same place as the note below, because it
    /// is the same kind of thing: a state the controls cannot design away, explained in words next
    /// to the control that fixes it. What it must not do is refuse the save — see
    /// `BlockEditorDraft.dayOptions(in:)` for why moving the block has to stay optional.
    @ViewBuilder
    private var closedDayNote: some View {
        if draft.isOnAClosedDay(in: store.camp) {
            warningNote("The camp doesn't run on \(draft.day.fullName) any more, so this block won't show on the schedule. Move it, or leave it here for now.")
        }
    }

    /// The sheet's one spelling of an amber line under a field.
    ///
    /// Three of them now — a closed day, an end before a start, and a clash — and the third is
    /// what made this worth having. Two copies of a three-modifier chain is a coincidence; three
    /// is three places to miss the day the design moves the gap or the weight. Each caller keeps
    /// its own words and its own condition, which are the parts that differ; this is only how
    /// they read.
    ///
    /// `.fixedSize(horizontal: false, vertical: true)` on all three, because every one of them is
    /// a sentence rather than a label and a warning that truncates is a warning nobody can act on.
    private func warningNote(_ copy: String) -> some View {
        Text(copy)
            .typeStyle(ScheduleType.assigneeMeta, color: Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Spacing.small)
    }

    /// The one state the menus cannot design away: moving the *start* past an end that was already
    /// chosen. Saying so beats silently rewriting somebody's end time, and beats a disabled button
    /// with no explanation next to it.
    @ViewBuilder
    private var endBeforeStartNote: some View {
        if !BlockRules.endsAfterStart(startsAt: draft.startsAt, endsAt: draft.endsAt) {
            warningNote("A block has to end after it starts. Pick a later end, or no end time.")
        }
    }

    /// The other thing the two menus can produce that somebody should know about: a block laid on
    /// top of one that is already on the morning.
    ///
    /// Words rather than a shorter menu, which is a deliberate break from the line directly above
    /// this one. `BlockClock.endOptions(after:)` omits every end the `ends_after_starts` CHECK
    /// would refuse instead of offering it — "a menu that lists 8:00 under a block starting at
    /// 9:00 is a menu with a wrong answer in it" — and stopping the end menu at the clash was the
    /// obvious first answer here too.
    ///
    /// It was rejected twice over. A menu cannot say *why*: the end rule's reason is two inches to
    /// the left, in the start field, so a menu that stops at it explains itself, where this one's
    /// reason is a different block somewhere else on the day and a menu silently stopping at 10:45
    /// would leave somebody guessing which of the morning's eight cards they had run into. And a
    /// missing option is a refusal wearing a disguise — the whole of this change is that a camp
    /// may double-book and be told, not stopped.
    ///
    /// So the block is named, the minute is offered, and the button below saves either way.
    @ViewBuilder
    private var overlapNote: some View {
        // Only once the two menus say something coherent. A draft whose end is before its start is
        // not a span yet, and the rule will still cheerfully report what its inverted minutes run
        // into — a second amber sentence stacked under the first, about a block nobody has managed
        // to place. The note above is the one to fix first.
        if BlockRules.endsAfterStart(startsAt: draft.startsAt, endsAt: draft.endsAt),
           let clash = draft.overlap(in: store.scheduleBlocks) {
            warningNote(overlapAdvice(clash))
        }
    }

    /// Which half of the block is in the wrong place, and the way out of it.
    ///
    /// `clash` is the *earliest-starting* collision (`BlockRules.overlap(with:in:)`), so one that
    /// starts after this block means nothing before this block collides at all — and the only half
    /// that can be moved is the end.
    ///
    /// The opening clause is `ScheduleBlock.clashLine`, which is the same sentence the card on
    /// `8k` draws. Only the way out is this screen's, because only this screen has the controls.
    ///
    /// The minute quoted is `BlockRules.latestEnd`'s. On this branch it is the same number as
    /// `clash.startsAt` — anything sharing space and starting between the two would itself be an
    /// earlier clash — and it is asked for by name anyway, because the sentence means "the latest
    /// end that runs into nothing" and that is the function that says so. The fallback is what the
    /// compiler needs rather than a value that is ever reached.
    ///
    /// The other branch offers no minute, deliberately. The symmetric advice would be "start it
    /// when that one ends", and that can be advice nobody can take: a clash that *contains* this
    /// block ends after this block does, so following it would push the start past the end and
    /// trip the note directly above. "Start it later" is vaguer and is always true.
    ///
    /// "Save it anyway, or …" is `closedDayNote`'s cadence ("Move it, or leave it here for now.")
    /// and is doing the same work: the note has to say that this is allowed, because an amber line
    /// under a field reads as a refusal until it says otherwise.
    private func overlapAdvice(_ clash: ScheduleBlock) -> String {
        if clash.startsAt > draft.startsAt {
            let ceiling = BlockRules.latestEnd(for: draft.block(), in: store.scheduleBlocks)
                ?? clash.startsAt
            return "\(clash.clashLine). Save it anyway, or end it by \(ceiling.clockLabel)."
        }
        return "\(clash.clashLine). Save it anyway, or start it later."
    }

    // MARK: Courts, and the kids on them

    private var courtPool: [CourtGroup] {
        BlockCourtPicker.pool(in: store.camp, venueID: draft.venueID)
    }

    private var courtCoachNames: [Group.ID: String] {
        BlockCourtPicker.coachNames(in: store.camp, venueID: draft.venueID)
    }

    /// Only once a court has been ticked.
    ///
    /// Progressive disclosure rather than three disabled rows: "put every kid on these courts"
    /// with no courts chosen is not a control waiting to be enabled, it is a sentence with a hole
    /// in it. The section appears the moment there is somewhere to put them, which also makes the
    /// order of operations obvious — courts first, then the kids that go on them.
    @ViewBuilder
    private var kidsSection: some View {
        if !draft.courtIDs.isEmpty {
            SheetSectionHeader("Kids", topPadding: ScheduleMetrics.editorSectionGap)
            Card(radius: ScheduleMetrics.cardRadius) {
                ForEach(BlockKidSpread.allCases, id: \.self) { spread in
                    BlockPickRow(
                        title: spread.displayName,
                        detail: spread.detail,
                        isOn: draft.spread == spread
                    ) {
                        draft.spread = spread
                    }
                }
            }

            // Says the one thing the rows cannot: that nothing has happened yet. A tick here looks
            // exactly like a tick on a court, and a court is stored where this is an instruction.
            Text("Runs when you save, over the courts you saved.")
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.small)
                .padding(.horizontal, ScheduleMetrics.rowInset)
        }
    }

    // MARK: Coaches

    /// The pool needs to know who is reading it — an admin the camp has posted nowhere is in it on
    /// the strength of their role, and *you* are in it unconditionally. Read here and handed down
    /// rather than reached for from inside the `static`: this is the view with the store, and a
    /// pure function of a camp is what makes the pool testable without one.
    private var myID: StaffMember.ID? { store.myStaffRecord?.id }

    private func coachPool(me: StaffMember.ID?) -> [StaffMember] {
        BlockCoachPicker.pool(in: store.camp, venueID: draft.venueID, me: me)
    }

    // MARK: Committing

    /// Disabled until every CHECK the insert will apply already passes — refusing before the tap
    /// rather than after it, which is the rule `SetupView`'s rename row states: the alternative is
    /// a banner over a sheet that has already been dismissed.
    ///
    /// `draft.isValid` and deliberately not `draft.overlap(in:)`. Every rule this button holds is
    /// a rule the *write* holds, so a save it lets through is a save that lands; an overlap is a
    /// row Postgres is perfectly happy to hold, and disabling the button on one would be the app
    /// inventing a lock — stranding somebody who opened this sheet to fix a typo in the title of a
    /// block that has been double-booked since seven. `overlapNote` above is the whole of what
    /// happens instead.
    private var commitButton: some View {
        PrimaryButton(
            draft.isCreating ? "Add block" : "Save changes",
            tone: .accent,
            height: ScheduleMetrics.editorButtonHeight,
            radius: Radius.button,
            font: ScheduleType.cta,
            action: commit
        )
        .opacity(draft.isValid ? 1 : 0.45)
        .disabled(!draft.isValid)
    }

    /// Only on the edit path, so `8l`'s `⋯` does not need a third entry for something this sheet
    /// is already holding the block for.
    @ViewBuilder
    private var deleteButton: some View {
        if !draft.isCreating {
            PrimaryButton(
                "Delete block",
                tone: .danger,
                height: ScheduleMetrics.editorButtonHeight,
                radius: Radius.button,
                font: ScheduleType.cta,
                action: { isConfirmingDelete = true }
            )
            .padding(.top, ScheduleMetrics.editorFieldGap)
        }
    }

    // MARK: Writes

    /// Closes first, then writes. The sheet has nothing left to show once the values are handed
    /// over, and `AppStore.perform` owns the banner — floated by whichever screen presented this
    /// one, not by this one. No spinner goes with it: the capsule that used to is gone.
    ///
    /// The kid spread runs after the block, not beside it, because it is about the block's saved
    /// courts: `block.courtIDs` is the list that was committed, and dealing against the draft's
    /// ticks would be dealing against a value the server has not agreed to yet.
    ///
    /// It is one call, and the reasoning for that lives with the write — see
    /// `SupabaseRepository.spreadKids`. What is worth saying here is that this view does not
    /// arrange the deal at all: it hands over the instruction and the courts, and the repository
    /// runs it as a single mutation of the camp. An earlier version of this method copied
    /// `store.camp`, dealt it locally and posted the result court by court, which was three things
    /// wrong — a half-dealt venue if one of those failed, a whole-graph round trip per court, and
    /// the only untested code in the feature, because nothing can reach a private method on a
    /// `View`.
    private func commit() {
        guard draft.isValid else { return }
        let block = draft.block()
        let isCreating = draft.isCreating
        let spread = draft.spread
        dismiss()
        Task {
            if isCreating {
                await store.addScheduleBlock(block)
            } else {
                await store.updateScheduleBlock(block)
            }
            // Only if the block actually landed. `AppStore.perform` clears `errorMessage` before
            // it starts and sets it on the way out, so reading it here is asking "did that write
            // succeed" — and a spread that ran anyway would reseat a whole venue for a block the
            // server refused, leaving the camp rearranged for a timetable that does not exist.
            guard store.errorMessage == nil else { return }
            await store.spreadKids(spread, over: block.courtIDs, atVenue: block.venueID)
        }
    }

    /// Closes before the write for a reason beyond tidiness on the edit path: `8l` closes itself
    /// when `store.scheduleBlocks` comes back without this block, and dismissing a sheet at the
    /// same moment as the cover presenting it is how a presentation gets stuck.
    private func delete() {
        let blockID = draft.id
        dismiss()
        Task { await store.deleteScheduleBlock(blockID) }
    }

    /// Puts the keyboard down, then hands back to the caller.
    ///
    /// Every way out goes through here — the ✕, "Save changes" and "Delete block" — because a sheet
    /// that slides away with a field still first responder takes the keyboard down in a second
    /// animation behind the first. `AddPlayerView.save()` drops focus for the same reason before it
    /// hands its player over; the difference is that this sheet has three exits rather than one, so
    /// the two lines live in one place instead of three.
    ///
    /// `onClose` is still the caller's and still does the closing: the state holding this sheet open
    /// belongs to them, which is the whole argument in the header. This only adds what they cannot
    /// reach — a `@FocusState` declared in here.
    private func dismiss() {
        titleFocus = false
        detailFocus = false
        onClose()
    }
}

// MARK: - Previews

private struct BlockEditorPreview: View {
    var draft: BlockEditorDraft

    @State private var store = AppStore.preview

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.scrim.ignoresSafeArea()
            BlockEditorSheet(draft: draft, onClose: {})
                .environment(store)
                .frame(height: 640)
        }
        .frame(height: 700)
        .background(Theme.canvas)
    }
}

#Preview("Block editor — new") {
    BlockEditorPreview(draft: BlockEditorDraft(creatingIn: SampleData.sycamore.id, day: .tue))
}

#Preview("Block editor — editing") {
    BlockEditorPreview(
        draft: BlockEditorDraft(
            editing: ScheduleSampleDay.blocks(
                venueID: SampleData.sycamore.id,
                coachIDs: [SampleData.nass.id]
            )[1]
        )
    )
}

/// The warm-up the whole change exists for: one court, everybody on it. Scroll to the Courts and
/// Kids sections — they are the two the other previews above deliberately do not draw.
#Preview("Block editor — courts & coaches") {
    let camp = SampleData.uclaTennisCamp
    let courts = camp.groups(in: SampleData.sycamore.id)
    var draft = BlockEditorDraft(
        editing: ScheduleSampleDay.blocks(
            venueID: SampleData.sycamore.id,
            coachIDs: [SampleData.nass.id]
        )[1]
    )
    draft.kind = .assigned
    draft.courtIDs = Set(courts.prefix(1).map(\.id))
    return BlockEditorPreview(draft: draft)
}
