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
//  `PushedScreen.isFullScreen` (`AppStore.swift:138-158`) states the rule: full screen is for a
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
//  ── The ✕ stays, and the design does not draw one ─────────────────────────────────────────────
//
//  `4e` and `5a` both draw a grabber and no close button. It is kept anyway, and this is the one
//  place these three frames are read as a drawing rather than as an instruction.
//
//  It is the only non-gestural way out of a sheet that can be dismissed by nothing else: every
//  other exit here commits or deletes. A drag is the way out you find by accident, and VoiceOver
//  has no drag — dropping the ✕ would leave a screen reader with two buttons, both of which write.
//  `SheetChrome` has provided it on all four sheets since they were built (`:138-145`), so removing
//  it here would also make this the one sheet in the app that closes differently from the others.
//
//  ── Presented by its caller, not by the root ──────────────────────────────────────────────────
//
//  Each caller holds its own `@State private var editing: BlockEditorDraft?` and its own
//  `.sheet(item:)`. No case is added to `ActiveSheet`, because `MainTabView` owns that
//  (`RootView.swift:138`) and sits *beneath* `8l`'s cover — asking it to present would open this
//  sheet behind the screen that asked for it. `PlayerScreen.swift:39-43` names that trap in as
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
        // The same `me` on both, and it has to be: the pool sorts your row to the top and the
        // picker is what writes "· you" on it, so two different answers would put the suffix on
        // the wrong row.
        let people = coachPool(me: me)
        // Resolved once for the same reason. The Courts label counts it and the picker draws it,
        // and `Camp.groups(in:)` is a walk of the venue either way round.
        let courts = courtPool

        return SheetChrome(
            title: draft.isCreating ? "New block" : "Edit block",
            subtitle: subtitle,
            subtitlePlacement: .eyebrow,
            titleStyle: ScheduleType.editorTitle,
            detentFraction: ScheduleMetrics.editorDetent,
            onClose: dismiss
        ) {
            // A label per field, in `SheetFieldLabel`'s flat sentence case, where this sheet used
            // to run six tracked-uppercase `SheetSectionHeader`s — "WHAT IT IS", "WHEN". The
            // design names the *box* rather than heading a group of them
            // (`design/rebuild/section-t5.html:65-88`), and the two are not the same claim: "When"
            // over a row of day chips and two menus asks the reader to work out which of the three
            // controls under it the heading was about, where "Day", "Starts" and "Ends" each stand
            // over the one thing they name. `SheetFieldLabel` carries the design's own `14` above
            // and `7` below, so the gaps between fields are no longer this file's to state.
            //
            // The first one is spaced from a title rather than from a field, and the design gives
            // that one `16`.
            SheetFieldLabel("Block name", topPadding: Spacing.large)
            titleField

            SheetFieldLabel("Description")
            descriptionField

            SheetFieldLabel("Type")
            kindPicker

            SheetFieldLabel("Day")
            dayChips
            closedDayNote

            timeFields
            endBeforeStartNote
            overlapNote
            endsHint

            if draft.kind == .assigned {
                courtsLabel(courts)
                // No `closures:`. The picker reads `Group.closedReason` off the courts it is
                // already handed — see `BlockCourtPicker.detail(_:)` — which is the same answer
                // for every venue rather than only for the one `store.courts` was loaded for.
                BlockCourtPicker(
                    courts: courts,
                    selection: $draft.courtIDs,
                    coachNames: courtCoachNames
                )

                kidsSection
            }

            SheetFieldLabel("Coaches")
            BlockCoachPicker(
                people: people,
                selection: $draft.coachIDs,
                myID: me,
                availability: coachAvailability(among: people)
            )

            commitButton
                .padding(.top, Spacing.large)

            deleteButton
            deleteHint
        }
        // One bar for both fields, because `placement: .keyboard` belongs to the sheet rather than
        // to a field in it — `FormTextArea.keyboardDoneBar` argues that out. Both focus states are
        // cleared rather than the description's alone: the reader can be in either box when they
        // reach for it, and the bar cannot tell which.
        //
        // The description is why it exists. The title has a Return key that means something
        // (`submitLabel(.next)` at `:223`), where Return in a vertical field types a newline — so
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

    /// `Tuesday · Sycamore` — which day the block is currently on, and where it hangs. The day is
    /// in the eyebrow *and* in the chips below because the eyebrow is what a person reads first
    /// and the chips are what they change.
    ///
    /// Day first, which is the way round the design writes it
    /// (`design/rebuild/section-t5.html:61`) and the reverse of what this said. Drawn over the
    /// title rather than under it, an eyebrow is a place-marker — where am I — and the day is the
    /// half of that answer somebody can be wrong about. The venue they came from; the day they may
    /// have scrolled past.
    private var subtitle: String? {
        let venue = store.venue(draft.venueID)?.name
        return [draft.day.fullName, venue].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: What it is

    /// `.sheetBoxLarge` with no glyph, at the design's field weights — a placeholder is one step
    /// lighter than a value here, so the two read apart before the colour difference lands.
    ///
    /// The box and the value both grew: `5a` draws every field on this sheet at `600 16` inside a
    /// `1.5px` rule at radius 15 (`design/rebuild/section-t5.html:66`), against the `500 14` in a
    /// `1px` rule at radius 13 that the pick-up sheet uses. `FormFieldMetrics.sheetBoxLarge` is
    /// that box, and it is a second preset rather than a retune of `.sheetBox` — nine other call
    /// sites take the smaller one and the design has not redrawn them.
    private var titleField: some View {
        let field = FormField(
            "Skills rotation",
            text: $draft.title,
            label: "Block name",
            metrics: .sheetBoxLarge,
            type: ScheduleType.editorFieldValue,
            promptType: ScheduleType.editorFieldPlaceholder,
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
    ///
    /// The one field on the sheet whose value is *not* `editorFieldValue`. Everything else here is
    /// an answer — a name, a start, an end — and is set at the weight the block's own card will
    /// draw it at; this is a paragraph, and `5a` sets it as one: `400 14.5/1.5`
    /// (`design/rebuild/section-t5.html:68`), with the leading every other paragraph in the app
    /// takes. Three lines of `600 16` in the same box would read as a title that had overflowed.
    ///
    /// It also **supersedes `4e`'s separate `Note` field**, which is not built and will not be.
    /// `5a` puts Description in that slot and `t5`'s own caption lists description among what the
    /// sheet keeps. A real note is not a column on this row at all — it is an `inbox_items` insert
    /// with `kind = 'note'` (`BlockNote`, `SectionEight.swift:386-390`) — so it would be a second
    /// write after the block lands, with its own failure mode, arriving after this sheet has
    /// dismissed. `BlockNotesCard` on `8l` is where a note is written, beside the notes it joins.
    private var descriptionField: some View {
        let field = FormTextArea(
            "What happens in this block",
            text: $draft.detail,
            label: "Description",
            metrics: .sheetBoxLarge,
            type: ScheduleType.editorDescription,
            // The warm ink, not `Theme.ink`. 5a sets this paragraph `#3F4A44`, which is the
            // design system's body colour — `ink` is reserved for titles and names, and a block
            // description is prose about what happens on the court. `FormTextArea` drew every
            // field in `ink` until this one asked otherwise; see its `valueColor`.
            valueColor: Theme.inkWarm,
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
        HStack(spacing: ScheduleMetrics.editorDayGap) {
            ForEach(draft.dayOptions(in: store.camp)) { day in
                Button {
                    draft.day = day
                } label: {
                    // `.dark`, not `.accent`. 5a draws the selected day `#0B0B0C` on white — the
                    // black half of the design system's "selection is a fill change, black or
                    // green" rule. Green is spent on *affirmation* in this sheet (the ticks down
                    // the Courts and Coaches cards, the commit bar), and a day is neither an
                    // approval nor a yes: it is which of five columns you are editing. Two
                    // greens on one screen, one meaning "chosen" and one meaning "agreed", is
                    // the ambiguity the black selection exists to avoid.
                    Chip(
                        day.shortName,
                        isSelected: day == draft.day,
                        selectedTone: .dark,
                        metrics: .dayPill,
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
    /// `EarlyPickupSheet.swift:196-205`, which `FormField.swift:170-172` names as the reason
    /// `formFieldChrome` is exposed rather than private: a menu is not a `TextField`, so it
    /// borrows the chrome rather than the component, and the two stop being two drawings of one
    /// thing that have to be kept in step.
    private var timeFields: some View {
        HStack(alignment: .bottom, spacing: ScheduleMetrics.editorFieldGap) {
            startsAtField
            endsAtField
        }
        .padding(.top, Spacing.gutterWide)
    }

    /// A label over a menu, twice, in two equal columns.
    ///
    /// The labels are inside the columns rather than in a row of their own above them, because
    /// that is where the design puts them (`design/rebuild/section-t5.html:82`) and because it is
    /// the arrangement that survives a text size: at `.accessibility1` "Starts" wraps and "Ends"
    /// does not, and two labels sharing a row would then leave one menu hanging half a line below
    /// the other. `.bottom` alignment on the `HStack` is what keeps the two boxes on one line when
    /// that happens.
    private var startsAtField: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetFieldLabel("Starts", topPadding: 0)
            startsAtMenu
        }
    }

    private var startsAtMenu: some View {
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
                .typeStyle(ScheduleType.editorFieldValue, color: Theme.ink)
                .formFieldChrome(.sheetBoxLarge, icon: "clock")
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
        VStack(alignment: .leading, spacing: 0) {
            SheetFieldLabel("Ends", topPadding: 0)
            endsAtMenu
        }
    }

    private var endsAtMenu: some View {
        Menu {
            Picker("Ends at", selection: $draft.endsAt) {
                Text("No end time").tag(TimeOfDay?.none)
                ForEach(BlockClock.endOptions(after: draft.startsAt)) { time in
                    Text(time.clockLabel).tag(TimeOfDay?.some(time))
                }
            }
        } label: {
            Text(endsAtLabel)
                .typeStyle(
                    ScheduleType.editorFieldValue,
                    color: draft.endsAt == nil ? Theme.inkFaint : Theme.ink
                )
                .formFieldChrome(.sheetBoxLarge, icon: "clock")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ends at")
        .accessibilityValue(endsAtLabel)
    }

    private var endsAtLabel: String { draft.endsAt?.clockLabel ?? "No end time" }

    /// What is inside the Ends menu, said outside it.
    ///
    /// **Documentation of behaviour that already shipped, not a request for new behaviour.** Both
    /// halves are true today and were before this line was drawn: `BlockClock.options` is 07:00 to
    /// 20:00 in fifteen-minute steps and `endOptions(after:)` keeps only what is strictly past the
    /// start, and the `Picker` above opens with `No end time` as its first entry.
    ///
    /// It is worth saying out loud because both are *absences*, and an absence explains nothing on
    /// its own. Somebody who wanted 10:20 finds no 10:20 and cannot tell whether the menu is
    /// coarse or broken; somebody who wants a block with no stated end — the 8:30 drop-off,
    /// everything `DayShape` writes — has no reason to open a menu called "Ends" looking for it.
    /// One line under the two fields answers both without adding a control.
    ///
    /// The quotation marks are the design's own (`design/rebuild/section-t5.html:90`) and they are
    /// load-bearing: the sentence names an entry in a menu, and without them "plus no end time"
    /// reads as a description of the block rather than as the words to look for.
    private var endsHint: some View {
        hintLine("Ends menu offers quarter-hours after the start, plus \"No end time\".")
    }

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
            .typeStyle(ScheduleType.assigneeMeta.lineHeight(1.5), color: Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, ScheduleMetrics.editorFieldGap)
    }

    /// The sheet's one spelling of a grey line that explains a control rather than warning about
    /// one — `400 12` in `inkFaint`, 8 under whatever it follows
    /// (`design/rebuild/section-t5.html:90, 128`).
    ///
    /// Two of them: what the Ends menu contains, and what Delete will do. Quieter than
    /// `warningNote` on every axis the design has — half a point smaller, two steps lighter in
    /// colour, and no amber — because the distinction is the whole point. Amber is about *this*
    /// draft and goes away when the draft changes; these two are about the controls and are true
    /// every time the sheet is opened. A reader who cannot tell them apart at a glance has to read
    /// both every time to find out which one is about them.
    ///
    /// The Kids card's "Runs when you save…" is drawn by `kidsSection` rather than through here,
    /// and deliberately: it is a footnote to a card and takes that card's gutter, where these two
    /// sit on the sheet's own.
    private func hintLine(_ copy: String) -> some View {
        Text(copy)
            .typeStyle(.meta, color: Theme.inkFaint)
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
    /// The opening clause names the block and the minute it starts — `Runs into Cool-down at
    /// 12:00pm` (`design/rebuild/section-t5.html:89`) — and it is `ScheduleBlock.clashLine`, the
    /// sentence `8k`'s card and `5d`'s header both draw.
    ///
    /// It was written out longhand here, under a note saying it would go back to being that
    /// property the day the two agreed on the words. They agreed the day `clashLine` became
    /// `runsIntoLine(from: startsAt)`, whose `max(startsAt, startsAt)` collapses to exactly the
    /// expression this line was spelling — so the two were character-for-character identical and
    /// only one of them was a property. Three screens now quote one property rather than three
    /// strings that happened to match.
    ///
    /// "Runs into" and not "Clashes with", which is what both used to say. A clash is a state the
    /// app has decided you are in; running into something is what the block does, in the order a
    /// morning happens — and the sentence that follows offers the minute to stop at, which only
    /// makes sense after a verb of motion.
    ///
    /// Only the way out is this screen's, because only this screen has the controls.
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
        let ranInto = clash.clashLine
        if clash.startsAt > draft.startsAt {
            let ceiling = BlockRules.latestEnd(for: draft.block(), in: store.scheduleBlocks)
                ?? clash.startsAt
            return "\(ranInto). Save it anyway, or end it by \(ceiling.clockLabel)."
        }
        return "\(ranInto). Save it anyway, or start it later."
    }

    // MARK: Courts, and the kids on them

    private var courtPool: [CourtGroup] {
        BlockCourtPicker.pool(in: store.camp, venueID: draft.venueID)
    }

    private var courtCoachNames: [Group.ID: String] {
        BlockCourtPicker.coachNames(in: store.camp, venueID: draft.venueID)
    }

    /// `Courts` on the left, `3 of 6` on the right.
    ///
    /// The count is the one thing this label knows that the card below it does not say in one
    /// glance: six rows of ticks have to be counted, and a block with three courts on it is a
    /// different block from one with all six. It is drawn where the design draws it — right of the
    /// label, on the same baseline, in the same faint grey as the two hint lines
    /// (`design/rebuild/section-t5.html:100`), which is what keeps it a reading rather than a
    /// control.
    ///
    /// `SheetFieldLabel` already runs to full width, so it is what pushes the count to the trailing
    /// edge — no `Spacer`. `.firstTextBaseline` sits the count on the label's baseline rather than
    /// in the middle of its 14-above-7-below gutters, and the two are combined for VoiceOver so it
    /// reads "Courts, 3 of 6" rather than announcing a stray number after the heading.
    ///
    /// Only ever drawn for an `.assigned` block: the whole Courts section is behind that test, so
    /// a whole-camp lunch never shows a count of the courts it is deliberately not on.
    private func courtsLabel(_ courts: [CourtGroup]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            SheetFieldLabel("Courts")
            Text("\(draft.courtIDs.count) of \(courts.count)")
                .typeStyle(.rowDetail, color: Theme.inkFaint)
        }
        .accessibilityElement(children: .combine)
    }

    // `courtClosures` used to sit here: a `[Group.ID: String]` built out of `store.courts`,
    // filtered to `draft.venueID`, handed to the picker as `closures:`. Its own comment conceded
    // the hole — `store.courts` is loaded for `readVenueID`, this sheet is scoped to the *block's*
    // venue, and the two differ whenever the editor is reached from Overview on a two-venue camp,
    // at which point the dictionary "would come back empty" and a shut court drew as an ordinary
    // one. The route around it is gone rather than documented again: `Group.closedReason` is on
    // the camp graph now, `BlockCourtPicker` is already handed `[CourtGroup]`, and a court that
    // knows why it is shut needs nothing threaded alongside it.

    /// Only once a court has been ticked.
    ///
    /// Progressive disclosure rather than three disabled rows: "Spread every kid over these
    /// courts" with no courts chosen is not a control waiting to be enabled, it is a sentence with
    /// a hole in it. The section appears the moment there is somewhere to put them, which also
    /// makes the order of operations obvious — courts first, then the kids that go on them.
    ///
    /// `5b` draws two of the three rows and `.evenly` is not among them. It stays. Nothing in the
    /// frame says to drop it — a frame is a photograph of one state — and it is the one spread that
    /// levels a block's own courts without emptying the courts it does not use, which is what a
    /// three-court block on a six-court venue wants. Dropping a behaviour on the strength of a
    /// drawing that simply did not have it open is the wrong direction to read a frame in.
    @ViewBuilder
    private var kidsSection: some View {
        if !draft.courtIDs.isEmpty {
            // Spelled once, above the loop that used to spell it three times. `tickedCourtSummary`
            // builds a whole `ScheduleBlock` and walks every group in the camp, and two of the
            // three rows then throw the answer away — `detail(across:)` ignores its argument for
            // `.leaveThem` and `.evenly` (`SectionEightRepository.swift:304-306`). This body
            // re-runs on every keystroke in the title field, which is the whole reason `me`,
            // `people` and `courts` are bound at the top of `body`. A local `let` inside a
            // `@ViewBuilder` block is fine and already done: `ScheduleBlockCard.copy` opens with
            // two (`ScheduleBlockCard.swift:428-430`).
            let ticked = tickedCourtSummary

            SheetFieldLabel("Kids")
            Card(radius: ScheduleMetrics.cardRadius) {
                ForEach(BlockKidSpread.allCases, id: \.self) { spread in
                    BlockPickRow(
                        title: spread.displayName,
                        detail: spread.detail(across: ticked),
                        isOn: draft.spread == spread
                    ) {
                        draft.spread = spread
                    }
                }
            }

            // Says the one thing the rows cannot: that nothing has happened yet. A tick here looks
            // exactly like a tick on a court, and a court is stored where this is an instruction.
            //
            // On the card's own 13pt gutter rather than the sheet's `rowInset`, so it starts under
            // the copy in the row above it and reads as a footnote to that card
            // (`design/rebuild/section-t5.html:120`). It is drawn here rather than through
            // `hintLine` for exactly that reason — see that method.
            Text("Runs when you save, over the courts you saved.")
                .typeStyle(.meta, color: Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.small)
                .padding(.horizontal, ScheduleMetrics.editorHintInset)
        }
    }

    /// `Courts 1, 2 and 5` — the ticked courts, in the sentence under "Spread every kid over these
    /// courts".
    ///
    /// `ScheduleBlock.courtSummary(in:)` and not a phrase built here. That speller collapses a run
    /// to `Courts 1–3`, follows the camp's sport so a swim camp reads `Lanes`, and drops an id that
    /// no longer resolves — three decisions already argued on the model, and a second copy of them
    /// would be a second answer to the same question two inches from the first.
    ///
    /// Asked of `draft.block()` rather than of `draft.courtIDs`, so it is the courts that will
    /// actually be *written* — which on a `.regular` block is none, whatever is ticked. The Kids
    /// card only appears under `.assigned` so that branch is unreachable from here, and asking the
    /// value that gets stored is what keeps it unreachable if that ever changes.
    private var tickedCourtSummary: String? {
        guard let camp = store.camp else { return nil }
        return draft.block().courtSummary(in: camp)
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

    /// What each of them is doing at the minute this block starts — `Free now · roaming`,
    /// `Free at 10:30`, `On Court 3 · Skills stations`.
    ///
    /// `CoachAvailability` and not a rule of this sheet's, because `4d` asks the identical question
    /// about the identical people and two spellings of it would be two answers — the failure this
    /// codebase keeps recording. Its header argues the one thing worth knowing from out here: it
    /// reads a block with no stated end as *occupying* its coaches, where the clash flag reads the
    /// same block as clashing with nothing. Both readings are deliberate and neither is the
    /// other's bug.
    ///
    /// Built once per body pass and handed down as a dictionary, through `CoachAvailability.map`
    /// rather than a `reduce` over `CoachAvailability.of` written out here. Both spell the same
    /// six lines and give the same answer; the difference is that `map` resolves the
    /// member-independent half — the day's running blocks, filtered and sorted — once instead of
    /// once per coach, and that half is the expensive one. This sheet's `body` redraws on every
    /// keystroke in the title field, so the old shape ran a day-wide walk per character typed, per
    /// coach at the venue. See that function's own doc for what it costs.
    ///
    /// Asked about `draft.block()`, so it moves with the two menus: change the start to nine and
    /// every row re-answers for nine o'clock. `store.scheduleBlocks` is one venue and one day, and
    /// `CoachAvailability.of` re-checks both before it believes anything in it — so a draft dragged
    /// onto Wednesday quietly reports everybody free rather than confidently reporting Tuesday.
    ///
    /// Empty while the camp is still loading, and the picker falls back to where each person
    /// stands. A row that said nothing would look like a line that had failed.
    private func coachAvailability(among people: [StaffMember]) -> [StaffMember.ID: CoachAvailability] {
        guard let camp = store.camp else { return [:] }
        return CoachAvailability.map(
            for: people, staffing: draft.block(), day: store.scheduleBlocks, camp: camp
        )
    }

    // MARK: Committing

    /// `Add to Tuesday` on a create, `Save changes` on an edit — and disabled until every CHECK
    /// the insert will apply already passes.
    ///
    /// ── WHAT IT SAYS ──────────────────────────────────────────────────────────────────────────
    ///
    /// The create label names its day (`design/rebuild/section-t4.html:302`), where it read
    /// "Add block". Every button in this app is meant to name its object, and "Add block" names the
    /// *kind* of thing rather than what is about to happen — which on this sheet is exactly the
    /// fact somebody can be wrong about. The day is a row of chips half a screen up, it defaults to
    /// whichever day the caller was standing on, and nothing else at the foot of the sheet repeats
    /// it. The eyebrow says it too, at the top, before any of the fields were filled in.
    ///
    /// `Weekday.fullName` and not `shortName`: the chips are already `Tue` and a bar reading "Add
    /// to Tue" would read as the chip rather than as a sentence.
    ///
    /// ── WHAT DISABLES IT ──────────────────────────────────────────────────────────────────────
    ///
    /// Refusing before the tap rather than after it, which is the rule `SetupView`'s rename row
    /// states: the alternative is a banner over a sheet that has already been dismissed.
    ///
    /// `draft.isValid` and deliberately not `draft.overlap(in:)`. Every rule this button holds is
    /// a rule the *write* holds, so a save it lets through is a save that lands; an overlap is a
    /// row Postgres is perfectly happy to hold, and disabling the button on one would be the app
    /// inventing a lock — stranding somebody who opened this sheet to fix a typo in the title of a
    /// block that has been double-booked since seven. `overlapNote` above is the whole of what
    /// happens instead.
    private var commitButton: some View {
        PrimaryButton(
            draft.isCreating ? "Add to \(draft.day.fullName)" : "Save changes",
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
            .padding(.top, ScheduleMetrics.editorDeleteGap)
        }
    }

    /// What the red bar will actually do, under it, centred.
    ///
    /// Documentation of behaviour that already ships, like `endsHint` — `deleteButton` raises a
    /// `.confirmationDialog` and `delete()` dismisses before it writes, and `8l` closes itself when
    /// the block stops coming back. What was missing is that none of that is visible *before* the
    /// tap, and this is the one control on the sheet where finding out afterwards is too late.
    ///
    /// Both halves earn their words. "Asks once" is the promise that the bar is not the deletion —
    /// a full-width destructive control under a thumb that is already resting near it. "Then closes
    /// the block's page behind it" is the part nobody could guess: the editor is often reached from
    /// `8l`'s `⋯`, so a delete takes away *two* screens, and a reader who expected to be dropped
    /// back onto the block's page would think the app had lost its place.
    ///
    /// Only on the edit path, because it describes a button that is only there — `deleteButton`
    /// above draws nothing on a create, and a lone sentence about a bar that is not on screen is a
    /// sentence about nothing.
    @ViewBuilder
    private var deleteHint: some View {
        if !draft.isCreating {
            hintLine("Delete asks once, then closes the block's page behind it.")
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
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
