//
//  ScheduleView.swift
//  Sycamore
//
//  `8k` — Schedule, and `8f` — its empty state. A day drawn to scale.
//
//  The day chips are the days the *camp* runs — `Camp.days`, not the calendar's five — and below
//  them is that day ruled from seven in the morning to eight at night, with each block drawn at the
//  height its own length earns and blocks that run at once drawn side by side.
//
//  ── WHY IT IS NOT A LIST ──────────────────────────────────────────────────────────────────────
//
//  It was one: `LazyVStack` of equal cards in time order, one card per block. That shape could not
//  say the two things a timetable is for. A fifteen-minute water break and a two-hour match session
//  drew the same height, and a block with three notes on it drew taller than either — so the card
//  heights were about the cards. And two blocks running at once on different courts drew one under
//  the other, which is exactly how a reader reads "one after the other".
//
//  So the day is a canvas. `ScheduleTimeline` owns every number in it and argues for each;
//  `LazyVStack`'s laziness is gone with the stack, which costs nothing — a camp day holds a handful
//  of blocks, not a feed, and the canvas has to measure all of them to pack them anyway.
//
//  Which of the two screens draws is still not a mode: it is whether `schedule_blocks` has anything
//  for the day you are standing on. An empty Friday is a real answer, not a loading state — and it
//  now gets its hero *over* the day's own grid rather than instead of it, because a day with
//  nothing on it still has a shape waiting for something.
//
//  The blocks live on `AppStore`, not here. They used to be local `@State` filled straight from
//  `store.repository`, which meant Schedule and Overview could hold two different answers to
//  "what is on today" and neither could see the other's writes.
//

import SwiftUI

struct ScheduleView: View {

    @Environment(AppStore.self) private var store

    /// The day the chips have been tapped onto, and nil until one has been.
    ///
    /// Nil rather than `.today` seeded at init, which is what this was and what made the screen
    /// open on Wednesday forever: `Weekday.today` was a stub, and even once it was not, a `@State`
    /// initialiser runs before the camp has landed — so the opening day would have been decided
    /// without the one fact that decides it. Held as "what somebody picked" and resolved in
    /// `selectedDay` instead, so no effect has to keep the two in step.
    @State private var pickedDay: Weekday?

    /// Which day `store.scheduleBlocks` is currently holding, so a day's blocks are never drawn
    /// under another day's chip. Nil until the first read lands.
    @State private var loadedDay: Weekday?

    /// The block with a finger on it — either edge or body. The canvas stops scrolling while there
    /// is one: both drags are vertical, and the scroll view would otherwise take them.
    @State private var draggingID: ScheduleBlock.ID?

    /// Which of the day's blocks are laid over which — held rather than computed in `body`,
    /// because it depends on exactly one value and that value is what re-derives it.
    /// `ScheduleConflicts` argues the cost; the `.onChange` below is what keeps it honest.
    ///
    /// The honest cost of holding it is one pass: a write lands, `body` draws the new day against
    /// the index built for the old one, and `.onChange` then rebuilds and draws again. A block
    /// added a moment ago is flagged one frame late, which is the same frame the block itself
    /// appears in and is not a thing anybody has seen.
    ///
    /// **`ScheduleTimeline` is deliberately not held beside it**, though it is the same shape of
    /// index over the same day. A clash arriving a frame late is a warning line appearing a frame
    /// late — invisible, which is the whole of the argument above. A *placement* arriving a frame
    /// late is a block drawn at the wrong minute and a newly-added block not drawn at all, because
    /// the layer indexes by id and would find nothing. So the timeline is packed in `canvas`,
    /// from the very blocks being drawn, and handed down — see the note where it is built. This
    /// `@State` is the *conflict* index, which is the opposite case: it changes only when somebody
    /// writes a block, so holding it is what stops a day of pair comparisons every clock tick.
    @State private var conflicts = ScheduleConflicts(day: [])

    /// The block `8l` is showing. Re-resolved from the store after every write, so the cover
    /// survives its own edits and closes itself when the block is deleted.
    @State private var openedBlock: ScheduleBlock?

    /// The block editor, held here rather than on `store.activeSheet`.
    ///
    /// `BlockDetailView` holds a second, independent one of these — it has to, being a cover that
    /// the root's sheet slot sits underneath — and two callers each owning their own state is
    /// simpler than one slot they take turns in. Nothing is added to `ActiveSheet`.
    @State private var editing: BlockEditorDraft?

    /// The design draws the gutter 52 wide against a 13pt time. At `.accessibility1` that time
    /// is half again as tall and a fixed column clips it, so the column grows with the type it
    /// is holding.
    ///
    /// It lives here rather than on the card now. On a list the gutter was part of every row; on a
    /// canvas it is one column drawn once, and it is also the offset every block is placed after —
    /// so the screen that draws it is the screen that has to know how wide it came out.
    @ScaledMetric(relativeTo: .callout) private var timeColumn = ScheduleMetrics.timeColumn

    /// The days this camp actually opens, and the chips the row draws.
    ///
    /// Falls back to Monday–Friday twice over — for a camp that has not loaded yet, and for one
    /// holding the empty set. `CampDays.isValid` is what the camp editor refuses on
    /// (`Models.swift:212-214`), but nothing stops a row written before that check existed, and a
    /// chip row with nothing in it is a screen with no way back into itself.
    private var campDays: CampDays {
        let days = store.camp?.days ?? .weekdays
        return days.isValid ? days : .weekdays
    }

    /// The day being shown: what somebody picked, or the day to open on.
    ///
    /// A tap wins — unless the camp has since stopped running that day, in which case the chip it
    /// selected is no longer drawn and the day underneath would be one nobody can see or leave.
    /// Resolving it here rather than correcting `pickedDay` in an `onChange` is what keeps this a
    /// question with one answer instead of two `@State`s that must never disagree.
    private var selectedDay: Weekday {
        if let pickedDay, campDays.contains(pickedDay) { return pickedDay }
        // Today when the camp runs today, otherwise the next day it does — see
        // `CampDays.openingDay(from:)`. The fallback is unreachable, `campDays` never being the
        // empty set, but that method is honest about a camp with no days and this is the only
        // honest answer to it.
        return campDays.openingDay(from: store.today) ?? store.today
    }

    private var blocks: [ScheduleBlock] {
        loadedDay == selectedDay ? store.scheduleBlocks : []
    }

    /// `5 blocks`, and nothing at all on a day with none — the design only draws the count on
    /// `8k`, and "0 blocks" beside the title would be a second way of saying the empty state.
    private var blockCount: String? {
        guard !blocks.isEmpty else { return nil }
        return "\(blocks.count) block\(blocks.count == 1 ? "" : "s")"
    }

    /// Whether the canvas is showing a real answer yet: a venue to schedule against, and this
    /// day's own blocks rather than the last day's. Both things that follow it need both halves.
    private var hasLanded: Bool {
        store.readVenueID != nil && loadedDay == selectedDay
    }

    private var isEmptyDay: Bool { hasLanded && blocks.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()

                ScreenHeader(title: "Schedule", count: blockCount, initials: store.avatarInitials) {
                    store.pushedScreen = .profile
                }

                dayChips
                    .padding(.top, ScheduleMetrics.chipRowTop)

                addBlockAction
                    .padding(.bottom, ScheduleMetrics.headerBottom)
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollViewReader { proxy in
                ScrollView {
                    day
                        .padding(.bottom, Spacing.tabBarClearance)
                        // Named on the canvas's own content, so it moves with the blocks rather
                        // than with the screen: a `.local` drag is measured against a view inside a
                        // scroll view and is only trustworthy while nothing moves it.
                        // `RankView.swift:106` and `:353` are the template. The name belongs to
                        // `ScheduleResizePlan`, whose `drag(by:)` is what assumes it. Spelled
                        // `.named(_:)` rather than `name:`, which is `GroupsView.swift:174`'s
                        // spelling and the one that is not deprecated.
                        .coordinateSpace(.named(ScheduleResizePlan.listSpace))
                }
                .scrollIndicators(.hidden)
                // Both drags are vertical drags on a vertical scroll. The 0.2s hold in front of
                // each is what wins the arbitration; this is what stops the canvas sliding for the
                // rest of the gesture. `RankView.swift:116` does both for the same reason.
                //
                // …and on an empty day, where the hero floats over the grid rather than in it:
                // thirteen empty hours sliding behind a card that does not move reads as a screen
                // that has come apart, and there is nothing down there to scroll to.
                .scrollDisabled(draggingID != nil || isEmptyDay)
                // Thirteen hours is about a screen and a half, so where the day opens is a
                // decision rather than a default. On today it opens on the hour you are in; on any
                // other day, on the hour its first block is in. Keyed on the day that has *landed*
                // rather than on the day selected, so the scroll happens once the canvas has
                // something to scroll to.
                .onChange(of: loadedDay, initial: true) { _, _ in
                    guard let hour = openingHour else { return }
                    proxy.scrollTo(hour, anchor: .top)
                }
            }
            // Over the canvas rather than in place of it, and pinned to the frame rather than to
            // the day: centred inside 1560pt of grid it would be half a screen below the fold on a
            // day whose whole point is that there is nothing to scroll to.
            .overlay {
                if isEmptyDay { emptyDay }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .task(id: ScheduleLoad(campID: store.camp?.id, venueID: store.readVenueID, day: selectedDay)) {
            await store.loadScheduleBlocks(day: selectedDay)
            // Guarded, because `.task(id:)` cancels the run it is replacing rather than waiting
            // for it: a slow Tuesday landing after a fast Wednesday would otherwise write Tuesday
            // back into `loadedDay`, which now decides whether the day is empty *and* re-fires the
            // opening scroll.
            guard !Task.isCancelled else { return }
            loadedDay = selectedDay
        }
        // Failure and in-flight state are `MainTabView`'s, floated once over all four tabs.
        .sheet(item: $editing) { draft in
            BlockEditorSheet(draft: draft, onClose: { editing = nil })
                .environment(store)
        }
        // `8l` takes the whole frame and draws its own way out. The iOS-only `fullScreenCover` and
        // its macOS stand-in are in `fullScreenPresentation`, shared with the app's two other
        // covers rather than restated here.
        .fullScreenPresentation(item: $openedBlock) { block in
            BlockDetailView(
                block: block,
                // The one place this screen still reads the clock in its own `body`, and only
                // while a cover is open — which is a screen that wants the minute anyway.
                isCurrent: ScheduleBlock.running(in: blocks, at: store.timeOfDay)
                    .contains { $0.id == block.id },
                conflict: conflicts[block.id],
                onClose: { openedBlock = nil }
            )
            .environment(store)
        }
        // Re-derived from the day and from nothing else, which is what makes a held value safe
        // here rather than a second source of truth: a morning that has not changed cannot have
        // changed which of its blocks clash. `initial: true` because the first day to land arrives
        // as a change from nothing, and a screen that only flagged its *second* day would be a bug
        // nobody could reproduce twice.
        //
        // The second half is the last way a drag can be left half-torn-down. `ScheduleBlockCard`
        // nets its own cancelled gestures, but a card that is *removed* mid-drag never runs that
        // net at all — a second finger on a day chip, or the block being deleted from `8l` — and
        // the id it left behind would hold `.scrollDisabled` on for the rest of the session.
        // `blocks` is the drawn day rather than the store's, so switching day empties it
        // immediately. One `.onChange` for both, because each costs a deep comparison of the day.
        .onChange(of: blocks, initial: true) { _, day in
            conflicts = ScheduleConflicts(day: day)
            if let dragging = draggingID, !day.contains(where: { $0.id == dragging }) {
                draggingID = nil
            }
        }
        // The cover reads its block from this binding rather than from the store, so a write
        // made inside it has to come back out: re-resolving redraws the cover after "Mark done"
        // and closes it after "Delete block".
        .onChange(of: store.scheduleBlocks) { _, day in
            guard let open = openedBlock else { return }
            openedBlock = day.first { $0.id == open.id }
        }
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    // MARK: Day chips

    /// One equal chip per day the camp runs, in the row Early pick-up draws. `.day` metrics carry
    /// no horizontal padding by design — the width is meant to come from `fillsWidth`, and without
    /// it the chips shrink-wrap their labels and the row reads as a set of different-sized buttons.
    ///
    /// This drew all seven weekdays' worth of calendar — `Weekday.allCases` — which was five chips
    /// while `Weekday` stopped at Friday and became seven the day it did not. Neither number was
    /// ever the right one: a swim club that runs Saturday mornings was being offered a Wednesday
    /// it does not open on, and had no chip for the day it does.
    ///
    /// Deliberately not a horizontal `ScrollView` for the seven-day case. Seven chips is the
    /// widest this row goes and they fit at the default text sizes; a scrolling row would have to
    /// give up `fillsWidth`, which is the thing keeping the days a row of equal chips rather than
    /// a ragged line, and it would put a horizontal pan inside a screen that also owns a vertical
    /// one.
    ///
    /// The chip is drawn by `Chip` and pressed by the button around it: `.day` stands about
    /// 39pt tall, so the frame outside it carries the tap up to the 44pt minimum without moving
    /// a pixel of what is drawn.
    private var dayChips: some View {
        // Resolved once for the row rather than twice per chip. `selectedDay` walks the camp's
        // days and can reach the clock, and the loop below asked it fourteen times to draw seven
        // chips.
        let selected = selectedDay

        return HStack(spacing: Spacing.tight) {
            ForEach(campDays.ordered) { day in
                Button {
                    pickedDay = day
                } label: {
                    Chip(
                        day.shortName,
                        isSelected: day == selected,
                        selectedTone: .accent,
                        metrics: .day,
                        fillsWidth: true
                    )
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(day == selected ? .isSelected : [])
            }
        }
        // `Spacing.header`, so the picker keeps its edges under the title's. Both are inside the
        // one white block `8k` insets by 22.
        .padding(.horizontal, Spacing.header)
    }

    /// "Add a block", in the header.
    ///
    /// The canvas's own way of making one is a tap on empty grid, which is the calendar idiom and
    /// which replaced the "Add a block" row that used to sit at the foot of the day — a row has no
    /// place on a canvas, and a day two hours long would have put it two hours down. But a gesture
    /// that is the *only* route to an action is an action nobody discovers and nobody using
    /// VoiceOver can reach at all, so it also lives here, where it does not move and does not have
    /// to be scrolled to.
    ///
    /// A row of its own rather than a `+` at the end of the chips, which was tried and is worse:
    /// a plus at the end of a row of days reads as "add a day". The copy is the row's, unchanged,
    /// so the two entrances say the same words.
    ///
    /// Not gated on `store.isAdmin`, which is deliberate and matches what is already here: "Add
    /// the first block", the three day shapes and "Copy Monday instead" are all ungated, and RLS
    /// on `schedule_blocks` is the gate that decides. Gating one entrance to the composer and not
    /// the other four would be a lock on a door standing beside an open one.
    private var addBlockAction: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Button(action: addBlock) {
                HStack(spacing: Spacing.tight) {
                    DisclosureChevron(systemName: "plus", size: 13, color: Theme.accent)
                        .accessibilityHidden(true)

                    Text("Add a block")
                        .typeStyle(ScheduleType.inlineAction, color: Theme.accent)
                }
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the block editor on \(selectedDay.fullName)")
        }
        .padding(.horizontal, Spacing.header)
    }

    // MARK: The day

    @ViewBuilder
    private var day: some View {
        if store.readVenueID == nil {
            // Not `8f`. That screen's every affordance writes against a venue, so offering
            // "Add the first block" to somebody whose camp has none is three buttons that
            // cannot work.
            ContentUnavailableView {
                Label("No venue to schedule", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text("Add a venue in Camp settings, then the week can have a shape.")
            }
            .padding(.top, Spacing.section)
        } else {
            canvas
        }
    }

    /// The day, ruled.
    ///
    /// Drawn before the blocks have landed too, which is a change and an improvement. This used to
    /// draw nothing at all while a day was in flight, on the grounds that a spinner is a flicker
    /// and that `8f` would claim a day was empty before anybody had looked. Both are still true and
    /// neither applies to the grid: an hour rule says nothing about whether anything is on that
    /// hour, so the day's frame can be up immediately and the blocks can arrive into it.
    /// Four layers, and the order they are stacked in is load-bearing.
    ///
    /// The grid is the base. `createSurface` sits on it as a **sibling** of the blocks rather than
    /// as an ancestor, which is the whole reason it is a layer of its own instead of a gesture on
    /// the grid: a gesture on the grid would also be offered to every touch that lands on a block,
    /// the blocks being drawn in an overlay *of* the grid, so tapping a card would open the block
    /// and propose a new one at the same minute. As siblings, a touch goes to whichever layer is on
    /// top of it — a block if there is one there, the create surface if there is not.
    ///
    /// The now-line is last so it crosses over the cards, which is where every calendar puts it.
    private var canvas: some View {
        ScheduleHourGrid(timeColumn: timeColumn)
            .overlay(alignment: .topLeading) { createSurface }
            .overlay(alignment: .topLeading) {
                ScheduleBlockLayer(
                    blocks: blocks,
                    // Packed here rather than inside the layer, which is where it started. The
                    // layer reads the clock, so a timeline built in its body was repacked every
                    // minute for an answer the clock has nothing to do with — the very bill
                    // `ScheduleConflicts.swift:10-14` was written to argue this screen must not
                    // pay. Built out here it is rebuilt when the day is, which is what it depends
                    // on, and it is still never a frame behind the blocks beside it.
                    timeline: ScheduleTimeline(day: blocks),
                    conflicts: conflicts,
                    timeColumn: timeColumn,
                    draggingID: $draggingID,
                    onOpen: { openedBlock = $0 },
                    onResize: resize,
                    onMove: shift
                )
            }
            .overlay(alignment: .topLeading) {
                ScheduleNowLine(isToday: selectedDay == store.today, timeColumn: timeColumn)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, ScheduleMetrics.listTop)
    }

    /// The calendar idiom, and the thing a canvas can offer that a list could not: a block is made
    /// where you point at it.
    ///
    /// Hidden from VoiceOver. A tap whose entire meaning is *where* it landed has nothing to offer
    /// a rotor — `addBlockAction` in the header is that route, which is why it exists.
    private var createSurface: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture(coordinateSpace: .local) { point in
                addBlock(at: point.y)
            }
            .accessibilityHidden(true)
    }

    /// The hour the day opens on, or nil while there is nothing to open onto.
    ///
    /// Read at the moment a day lands rather than continuously, which is why it is a function of
    /// `store.timeOfDay` and still does not re-scroll every minute: the `.onChange` above is keyed
    /// on `loadedDay`. A canvas that pulled itself back to the current hour once a minute would
    /// take the screen away from whoever was reading it.
    private var openingHour: TimeOfDay? {
        guard hasLanded else { return nil }
        let target =
            selectedDay == store.today
            ? store.timeOfDay
            : (blocks.map(\.startsAt).min() ?? ScheduleTimeline.dayStart)
        // The last ruled hour at or before it — the grid stops at 19:00, so an evening block and
        // an eight o'clock clock both land on the last row rather than on nothing.
        return ScheduleTimeline.hours.last { $0 <= target } ?? ScheduleTimeline.hours.first
    }

    // MARK: Empty state

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: ScheduleMetrics.sectionGap) {
            ScheduleEmptyDayHero(day: selectedDay, onAdd: addBlock)

            ScheduleShapesCard(day: selectedDay, onApply: apply, onCopyMonday: copyMonday)
        }
        .padding(.horizontal, Spacing.gutter)
        // Centred in what is on screen, less the tab bar floating over the bottom of it.
        .padding(.bottom, Spacing.tabBarClearance)
    }

    // MARK: Writes

    /// Opens the composer on this day, at the hour the composer already defaults to.
    ///
    /// Both header entrances land here — `8f`'s "Add the first block" and the action beside the
    /// chips — because they are the same act on days that differ only in how many blocks are
    /// already on them. The canvas's own entrance goes through `addBlock(at:)`, which is this with
    /// a time attached.
    ///
    /// This used to *be* the write: it inserted a hardcoded 9:00 "New block" and said so, because
    /// there was no composer to send anybody to. There is one now, so nothing is written until
    /// somebody has said what the block is called.
    ///
    /// A day can be changed inside the editor, and a block saved onto another day will not appear
    /// on this canvas — the chips stay where they were. That is the honest outcome: the sheet says
    /// which day it is writing to in its own subtitle, and silently dragging the day picker after
    /// somebody deliberately moved a block would be worse.
    private func addBlock() {
        editing = newDraft()
    }

    /// A tap on empty canvas: the composer, pre-filled at the minute that was pointed at.
    ///
    /// `ScheduleTimeline.draftSpan(atY:)` decides both times, snapped to the same quarter-hour grid
    /// everything else on this screen lands on — so a tap two thirds of the way down the ten
    /// o'clock hour opens a block at 10:45 rather than at 10:41.
    private func addBlock(at y: CGFloat) {
        guard var draft = newDraft() else { return }
        let span = ScheduleTimeline.draftSpan(atY: y)
        draft.startsAt = span.startsAt
        draft.endsAt = span.endsAt
        editing = draft
    }

    /// The composer's own default block, on this day. Nil for a camp with no venue, which is the
    /// state `day` draws `ContentUnavailableView` for — every entrance is off the screen there, so
    /// this is a guard against a race rather than a case anybody can reach by tapping.
    private func newDraft() -> BlockEditorDraft? {
        guard let venueID = store.readVenueID else { return nil }
        return BlockEditorDraft(creatingIn: venueID, day: selectedDay)
    }

    /// A dragged bottom edge, written once.
    ///
    /// The whole block goes back, not a patch of it: `updateScheduleBlock` takes a `ScheduleBlock`
    /// and the repository writes the row, so anything dropped here would be cleared on the server.
    /// The same reasoning `BlockEditorDraft` carries `status` and `notes` through for.
    private func resize(_ block: ScheduleBlock, to endsAt: TimeOfDay) {
        var updated = block
        updated.endsAt = endsAt
        Task { await store.updateScheduleBlock(updated) }
    }

    /// A carried block, written once, on the same terms.
    ///
    /// Both times together and never one at a time. `ScheduleMovePlan` is what keeps them a fixed
    /// distance apart; writing the start and letting the end follow in a second call would put a
    /// block of the wrong length on the server for the length of a round trip, and leave one there
    /// for good if the second call failed.
    private func shift(_ block: ScheduleBlock, to startsAt: TimeOfDay, endingAt endsAt: TimeOfDay?) {
        var updated = block
        updated.startsAt = startsAt
        updated.endsAt = endsAt
        Task { await store.updateScheduleBlock(updated) }
    }

    private func apply(_ shape: DayShape) {
        Task { await store.applyDayShape(shape, day: selectedDay) }
    }

    private func copyMonday() {
        Task { await store.copySchedule(from: .mon, to: selectedDay) }
    }
}

// MARK: - The layers

/// One rule and one label per hour, thirteen of them, seven in the morning to seven at night.
///
/// Each row is exactly `ScheduleTimeline.hourHeight`, so the stack comes to `dayHeight` without
/// anything being told twice — and each carries `.id`, which is what `ScrollViewReader` scrolls to.
/// That is the reason the grid is a `VStack` of rows rather than rules placed by `.offset` like the
/// blocks above it: an offset is a render-time transform and leaves the layout frame where it was,
/// so every anchor would have reported the top of the canvas.
///
/// Its own `View` rather than a computed property on the screen, which is the rule this codebase
/// keeps for a reason it has already paid for once (`AppClock.swift:32-37` names `ScheduleView` as
/// the screen that rebuilt every minute): thirteen rows of static content have no business being
/// rebuilt because the clock moved.
///
/// Hidden from VoiceOver: thirteen readings of "9am" is thirteen elements to swipe past to reach
/// the day, and the day is what the screen is.
private struct ScheduleHourGrid: View {

    let timeColumn: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ScheduleTimeline.hours) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(Self.label(hour))
                        .typeStyle(ScheduleType.blockTime, color: Theme.inkFaint)
                        .lineLimit(1)
                        .frame(width: timeColumn, alignment: .leading)
                        // Under its own rule rather than straddling it. Straddling would mean a
                        // negative offset, and the seven o'clock label would then hang above the
                        // top of the canvas where the scroll view cannot reach it.
                        .padding(.top, Spacing.hairGap)

                    Hairline(color: Theme.hairline)
                }
                .frame(height: ScheduleTimeline.hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .accessibilityHidden(true)
    }

    /// `7am`, `12pm`, `7pm`.
    ///
    /// A third spelling of the twelve-hour clock beside `TimeOfDay.clockLabel` and
    /// `ScheduleBlock.gutterLabel`, and it earns the third: those two label a *moment*, which
    /// always has minutes on it, and this labels an hour band, where `:00` thirteen times over is
    /// thirteen repetitions of the same two characters down a 52pt column. It keeps the meridiem
    /// that `gutterLabel` drops, because a gutter of whole hours has no neighbouring minutes to
    /// establish which half of the day it is in.
    private static func label(_ hour: TimeOfDay) -> String {
        let hour12 = hour.hour % 12 == 0 ? 12 : hour.hour % 12
        return "\(hour12)\(hour.hour < 12 ? "am" : "pm")"
    }
}

/// Every block, placed.
///
/// A `GeometryReader` because a lane's width is a share of whatever is left after the gutter, and
/// that is a number only the layout knows. Positioned with `.offset` rather than `.position`, which
/// is the ordinary reading of "put this here" and leaves each card's own frame the size the packing
/// asked for.
///
/// Its own `View` so that the clock reaches no further than this. It is the only layer that needs
/// the minute — to mark the block running now — and as a computed property on the screen it took
/// the header, the chips, the grid and the scroll view down with it once a minute.
private struct ScheduleBlockLayer: View {

    @Environment(AppStore.self) private var store

    let blocks: [ScheduleBlock]
    let timeline: ScheduleTimeline
    let conflicts: ScheduleConflicts
    let timeColumn: CGFloat
    @Binding var draggingID: ScheduleBlock.ID?
    let onOpen: (ScheduleBlock) -> Void
    let onResize: (ScheduleBlock, TimeOfDay) -> Void
    let onMove: (ScheduleBlock, TimeOfDay, TimeOfDay?) -> Void

    var body: some View {
        // Asked once for the canvas rather than once per card, which is where it was: it reads the
        // clock and walks the day twice over — `hasFinished` asks each open-ended block what
        // started after it — so a twelve-block morning paid for twelve walks to mark one card.
        //
        // **All of them, and this screen is the one that wants all of them.** `8k` is the whole
        // morning at one venue, so a warm-up on Court 1 running beside free play on Courts 2–4 is
        // two cards that are both true and both get the highlight — and, since the day became a
        // canvas, two cards drawn side by side saying so. Overview asks the narrower question,
        // `ScheduleBlock.running(on:in:at:)`, because its card is about the reader and not the
        // venue.
        //
        // `store.timeOfDay`, not `TimeOfDay.now()`. Reading the wall clock directly gives an answer
        // that is correct once and then held: nothing tells a view to look again, so the highlight
        // stayed on the 11:00 block into the afternoon until something else happened to invalidate
        // the screen.
        let currentIDs = Set(ScheduleBlock.running(in: blocks, at: store.timeOfDay).lazy.map(\.id))
        let gap = ScheduleMetrics.blockGap

        GeometryReader { proxy in
            let origin = ScheduleMetrics.laneOrigin(after: timeColumn)
            let lanes = max(0, proxy.size.width - origin)

            // A `ZStack` rather than the `GeometryReader`'s own implicit stacking, which is not
            // documented to honour `zIndex` — and the lift below is load-bearing in exactly the
            // case the lanes exist for.
            ZStack(alignment: .topLeading) {
                ForEach(blocks) { block in
                    if let placement = timeline[block.id] {
                        ScheduleBlockCard(
                            block: block,
                            isCurrent: currentIDs.contains(block.id),
                            height: placement.height,
                            draggingID: $draggingID,
                            // Looked up rather than worked out: the clash question is a walk of
                            // the day with a set intersection inside it, so it happens once a day
                            // in `ScheduleConflicts`.
                            conflict: conflicts[block.id],
                            onOpen: { onOpen(block) },
                            onResize: { end in onResize(block, end) },
                            onMove: { start, end in onMove(block, start, end) }
                        )
                        .frame(
                            width: placement.width(in: lanes, gap: gap),
                            height: placement.height
                        )
                        .offset(x: origin + placement.x(in: lanes, gap: gap), y: placement.y)
                        // A card being dragged draws over its neighbours rather than under them,
                        // which matters most in the case the lanes exist for: a block carried
                        // across a column would otherwise slide behind whatever it is passing.
                        .zIndex(draggingID == block.id ? 1 : 0)
                        // The cards are placed by geometry, so without this VoiceOver walks them
                        // in the order they sit down the screen and zig-zags between columns.
                        // Negated, because a higher priority is read first and an earlier block is
                        // a smaller number of minutes.
                        .accessibilitySortPriority(-Double(placement.startsAt.id))
                    }
                }
            }
        }
    }
}

/// Where the camp is up to, on a day that is today.
///
/// The dot is `ScheduleMetrics.statusDot`, which is what `8l` puts beside "On now" — the same mark
/// for the same fact rather than a second one at a second size. It sits on the seam between the
/// gutter and the first lane, so it reads as belonging to the rule rather than to any one block.
///
/// Drawn at `BorderWidth.rule` rather than at a hairline, and that is a decision about how much
/// green is on this screen rather than about the line. `Theme.accent` is already spent on the
/// running block's border, the live grabber, the drag readout, the pinned-note pin and "Add a
/// block"; a one-pixel rule in that same hue, crossing cards outlined in it, is the faintest mark
/// on the screen carrying the strongest fact. Apple spends a colour nothing else uses on this line;
/// the nearest this palette has to that is weight.
///
/// **Nothing at all outside camp hours.** `ScheduleTimeline.y(for:)` clamps into the day, so a
/// screen open at half past six would otherwise pin the line to the seven o'clock rule and a screen
/// open at nine in the evening would pin it to the foot of the canvas — both asserting the camp is
/// at a minute it is not.
private struct ScheduleNowLine: View {

    @Environment(AppStore.self) private var store

    let isToday: Bool
    let timeColumn: CGFloat

    var body: some View {
        let now = store.timeOfDay
        let dot = ScheduleMetrics.statusDot

        if isToday, now >= ScheduleTimeline.dayStart, now <= ScheduleTimeline.dayEnd {
            HStack(spacing: 0) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: dot, height: dot)

                Rectangle()
                    .fill(Theme.accent)
                    .frame(height: BorderWidth.rule)
            }
            .padding(.leading, max(0, ScheduleMetrics.laneOrigin(after: timeColumn) - dot / 2))
            .offset(y: ScheduleTimeline.y(for: now) - dot / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Reload key

/// What a day's blocks depend on. `.task(id:)` re-reads when any of the three moves — switching
/// day, switching camp, or being posted somewhere else mid-session.
private struct ScheduleLoad: Equatable {
    let campID: Camp.ID?
    let venueID: Venue.ID?
    let day: Weekday
}

// MARK: - Previews

/// Seeds the day through the repository before showing the screen — `InMemoryRepository`'s
/// storage is actor-isolated, so the blocks have to be written before the first read.
private struct SchedulePreview: View {
    /// The day the screen will actually open on for the preview camp, rather than `.today` — a
    /// preview run at a weekend seeded Saturday, opened Monday and drew an empty state that has
    /// nothing to do with the code being looked at.
    var day: Weekday = CampDays.weekdays.openingDay() ?? .mon
    var seeded: Bool = true
    /// The busier morning, for the packing. See `ScheduleSampleDay.overlappingBlocks(venueID:day:)`.
    var overlapping: Bool = false

    @State private var store = AppStore.preview
    @State private var isReady = false

    var body: some View {
        SwiftUI.Group {
            if isReady {
                ScheduleView()
                    .environment(store)
                    .showsMockStatusBar()
            }
        }
        .task {
            if seeded, let campID = store.camp?.id, let venueID = store.readVenueID {
                let day =
                    overlapping
                    ? ScheduleSampleDay.overlappingBlocks(venueID: venueID, day: day)
                    : ScheduleSampleDay.blocks(venueID: venueID, day: day)
                for block in day {
                    _ = try? await store.repository.addScheduleBlock(block, campID: campID)
                }
            }
            isReady = true
        }
    }
}

#Preview("Schedule — populated") {
    SchedulePreview()
}

#Preview("Schedule — overlapping") {
    SchedulePreview(overlapping: true)
}

#Preview("Schedule — empty") {
    SchedulePreview(seeded: false)
}
