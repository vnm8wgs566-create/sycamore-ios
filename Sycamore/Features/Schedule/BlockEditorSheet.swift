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
        SheetChrome(
            title: draft.isCreating ? "New block" : "Edit block",
            subtitle: subtitle,
            detentFraction: ScheduleMetrics.editorDetent,
            onClose: onClose
        ) {
            SheetSectionHeader("What it is", bottomPadding: Spacing.small)
            titleField
            descriptionField
                .padding(.top, ScheduleMetrics.editorFieldGap)

            SheetSectionHeader("When", topPadding: ScheduleMetrics.editorSectionGap)
            dayChips
            timeFields
                .padding(.top, ScheduleMetrics.editorFieldGap)
            endBeforeStartNote

            SheetSectionHeader("Coaches", topPadding: ScheduleMetrics.editorSectionGap)
            BlockCoachPicker(people: coachPool, selection: $draft.coachIDs)

            commitButton
                .padding(.top, ScheduleMetrics.editorSectionGap)

            deleteButton
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
        // is why this is a separate type from `FormField` rather than a flag on it.
        #if os(iOS)
        return field.textInputAutocapitalization(.sentences)
        #else
        return field
        #endif
    }

    // MARK: When

    /// The five-chip Mon–Fri row, exactly as `ScheduleView.dayChips` draws it: `.day` metrics
    /// carry no horizontal padding by design, so the width comes from `fillsWidth`, and the frame
    /// outside the chip carries the tap to 44pt without moving a pixel of what is drawn.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
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

    /// The one state the menus cannot design away: moving the *start* past an end that was already
    /// chosen. Saying so beats silently rewriting somebody's end time, and beats a disabled button
    /// with no explanation next to it.
    @ViewBuilder
    private var endBeforeStartNote: some View {
        if !BlockRules.endsAfterStart(startsAt: draft.startsAt, endsAt: draft.endsAt) {
            Text("A block has to end after it starts. Pick a later end, or no end time.")
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.small)
        }
    }

    // MARK: Coaches

    private var coachPool: [StaffMember] {
        BlockCoachPicker.pool(in: store.camp, venueID: draft.venueID)
    }

    // MARK: Committing

    /// Disabled until every CHECK the insert will apply already passes — refusing before the tap
    /// rather than after it, which is the rule `SetupView`'s rename row states: the alternative is
    /// a banner over a sheet that has already been dismissed.
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
    /// over, and `AppStore.perform` owns both the spinner and the banner — which are floated by
    /// whichever screen presented this one, not by this one.
    private func commit() {
        guard draft.isValid else { return }
        let block = draft.block()
        let isCreating = draft.isCreating
        onClose()
        Task {
            if isCreating {
                await store.addScheduleBlock(block)
            } else {
                await store.updateScheduleBlock(block)
            }
        }
    }

    /// Closes before the write for a reason beyond tidiness on the edit path: `8l` closes itself
    /// when `store.scheduleBlocks` comes back without this block, and dismissing a sheet at the
    /// same moment as the cover presenting it is how a presentation gets stuck.
    private func delete() {
        let blockID = draft.id
        onClose()
        Task { await store.deleteScheduleBlock(blockID) }
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
