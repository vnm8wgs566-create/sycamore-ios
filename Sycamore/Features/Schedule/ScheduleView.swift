//
//  ScheduleView.swift
//  Sycamore
//
//  `8k` — Schedule, and `8f` — its empty state. "One card per block."
//
//  The day chips run Mon–Fri and the blocks below them are the camp's morning in time order.
//  Which of the two screens draws is not a mode: it is whether `schedule_blocks` has anything
//  for the day you are standing on. An empty Friday is a real answer, not a loading state.
//
//  The design is careful about the empty day in a way worth preserving: it does not get a shrug,
//  it gets one obvious action ("Add the first block") and three shapes to start from. Somebody
//  setting up a camp at 7am should not have to invent a timetable from nothing.
//
//  The blocks live on `AppStore`, not here. They used to be local `@State` filled straight from
//  `store.repository`, which meant Schedule and Overview could hold two different answers to
//  "what is on today" and neither could see the other's writes.
//

import SwiftUI

struct ScheduleView: View {

    @Environment(AppStore.self) private var store
    /// Opens on today rather than on the design's Friday. `8f` happens to depict a Friday, but
    /// the day a person wants when they open Schedule is the one they are standing in.
    @State private var selectedDay: Weekday = .today
    /// Which day `store.scheduleBlocks` is currently holding, so a day's blocks are never drawn
    /// under another day's chip. Nil until the first read lands, which is what keeps an empty
    /// Tuesday from flashing `8f` on its way to `8k`.
    @State private var loadedDay: Weekday?

    /// The block `8l` is showing. Re-resolved from the store after every write, so the cover
    /// survives its own edits and closes itself when the block is deleted.
    @State private var openedBlock: ScheduleBlock?

    /// The block editor, held here rather than on `store.activeSheet`.
    ///
    /// `BlockDetailView` holds a second, independent one of these — it has to, being a cover that
    /// the root's sheet slot sits underneath — and two callers each owning their own state is
    /// simpler than one slot they take turns in. Nothing is added to `ActiveSheet`.
    @State private var editing: BlockEditorDraft?

    private var blocks: [ScheduleBlock] {
        loadedDay == selectedDay ? store.scheduleBlocks : []
    }

    /// The block the camp is in the middle of, by the clock rather than by which one somebody
    /// remembered to mark done. Shared with Overview and the repository so the two tabs cannot
    /// name different blocks as current.
    private var currentBlockID: ScheduleBlock.ID? {
        ScheduleBlock.running(in: blocks, at: .now())?.id
    }

    /// `5 blocks`, and nothing at all on a day with none — the design only draws the count on
    /// `8k`, and "0 blocks" beside the title would be a second way of saying the empty state.
    private var blockCount: String? {
        guard !blocks.isEmpty else { return nil }
        return "\(blocks.count) block\(blocks.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()

                ScreenHeader(title: "Schedule", count: blockCount, initials: store.avatarInitials) {
                    store.pushedScreen = .profile
                }

                dayChips
                    .padding(.top, ScheduleMetrics.chipRowTop)
                    .padding(.bottom, ScheduleMetrics.headerBottom)
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                day
                    .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .task(id: ScheduleLoad(campID: store.camp?.id, venueID: store.readVenueID, day: selectedDay)) {
            await store.loadScheduleBlocks(day: selectedDay)
            loadedDay = selectedDay
        }
        // Failure and in-flight state are `MainTabView`'s, floated once over all four tabs.
        .sheet(item: $editing) { draft in
            BlockEditorSheet(draft: draft, onClose: { editing = nil })
                .environment(store)
        }
        .blockDetailCover(item: $openedBlock) { block in
            BlockDetailView(
                block: block,
                isCurrent: block.id == currentBlockID,
                onClose: { openedBlock = nil }
            )
            .environment(store)
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

    /// Five equal chips, the same row Early pick-up draws. `.day` metrics carry no horizontal
    /// padding by design — the width is meant to come from `fillsWidth`, and without it the
    /// chips shrink-wrap their labels and the row reads as five different-sized buttons.
    ///
    /// The chip is drawn by `Chip` and pressed by the button around it: `.day` stands about
    /// 39pt tall, so the frame outside it carries the tap up to the 44pt minimum without moving
    /// a pixel of what is drawn.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
                Button {
                    selectedDay = day
                } label: {
                    Chip(
                        day.shortName,
                        isSelected: day == selectedDay,
                        selectedTone: .accent,
                        metrics: .day,
                        fillsWidth: true
                    )
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(day == selectedDay ? .isSelected : [])
            }
        }
        // `Spacing.header`, so the picker keeps its edges under the title's. Both are inside the
        // one white block `8k` insets by 22.
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
        } else if loadedDay != selectedDay {
            // Nothing, deliberately. The read is one hop and a spinner for that length is a
            // flicker rather than information — but drawing `8f` in the meantime would tell
            // somebody their day is empty before anybody has looked, and leaving the last day's
            // blocks up would put them under the wrong chip.
            EmptyView()
        } else if blocks.isEmpty {
            emptyDay
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, ScheduleMetrics.emptyListTop)
        } else {
            LazyVStack(spacing: ScheduleMetrics.blockGap) {
                ForEach(blocks) { block in
                    ScheduleBlockCard(block: block, isCurrent: block.id == currentBlockID) {
                        openedBlock = block
                    }
                }

                addBlockRow
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, ScheduleMetrics.listTop)
        }
    }

    /// "Add a block" at the foot of a day that already has some.
    ///
    /// `8f` gives an empty day one obvious action and this is its equivalent for a day that is
    /// already written: until now a camp could start a day and never add a sixth block to it. It
    /// is drawn as a card row rather than as a floating button because the tab bar already floats
    /// over this scroll, and two things pinned to the bottom edge is one too many.
    ///
    /// Not gated on `store.isAdmin`, which is deliberate and matches what is already here: "Add
    /// the first block", the three day shapes and "Copy Monday instead" are all ungated, and RLS
    /// on `schedule_blocks` is the gate that decides. Gating one entrance to the composer and not
    /// the other four would be a lock on a door standing beside an open one.
    private var addBlockRow: some View {
        Button(action: addBlock) {
            Card(radius: ScheduleMetrics.cardRadius) {
                CardRow(spacing: ScheduleMetrics.rowGap, verticalPadding: Spacing.medium) {
                    DisclosureChevron(systemName: "plus", size: 15, color: Theme.accent)
                        .accessibilityHidden(true)

                    Text("Add a block")
                        .typeStyle(ScheduleType.inlineAction, color: Theme.accent)

                    Spacer(minLength: Spacing.small)
                }
                .frame(minHeight: HitTarget.minimum)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the block editor on \(selectedDay.fullName)")
    }

    // MARK: Empty state

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: ScheduleMetrics.sectionGap) {
            ScheduleEmptyDayHero(day: selectedDay, onAdd: addBlock)

            ScheduleShapesCard(day: selectedDay, onApply: apply, onCopyMonday: copyMonday)
        }
    }

    // MARK: Writes

    /// Opens the composer on this day. Both entrances land here — `8f`'s "Add the first block" and
    /// the row at the foot of a populated day — because they are the same act on days that differ
    /// only in how many blocks are already on them.
    ///
    /// This used to *be* the write: it inserted a hardcoded 9:00 "New block" and said so, because
    /// there was no composer to send anybody to. There is one now, so nothing is written until
    /// somebody has said what the block is called.
    ///
    /// A day can be changed inside the editor, and a block saved onto another day will not appear
    /// in this list — the chips stay where they were. That is the honest outcome: the sheet says
    /// which day it is writing to in its own subtitle, and silently dragging the day picker after
    /// somebody deliberately moved a block would be worse.
    private func addBlock() {
        guard let venueID = store.readVenueID else { return }
        editing = BlockEditorDraft(creatingIn: venueID, day: selectedDay)
    }

    private func apply(_ shape: DayShape) {
        Task { await store.applyDayShape(shape, day: selectedDay) }
    }

    private func copyMonday() {
        Task { await store.copySchedule(from: .mon, to: selectedDay) }
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

// MARK: - Presenting `8l`

private extension View {
    /// A cover on iOS, a sheet everywhere else. `fullScreenCover` is iOS-only, and everything
    /// under `Sycamore/` has to typecheck for macOS as well — see `Package.swift`.
    @ViewBuilder
    func blockDetailCover<Content: View>(
        item: Binding<ScheduleBlock?>,
        @ViewBuilder content: @escaping (ScheduleBlock) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}

// MARK: - Previews

/// Seeds the day through the repository before showing the screen — `InMemoryRepository`'s
/// storage is actor-isolated, so the blocks have to be written before the first read.
private struct SchedulePreview: View {
    var day: Weekday = .today
    var seeded: Bool = true

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
                for block in ScheduleSampleDay.blocks(venueID: venueID, day: day) {
                    _ = try? await store.repository.addScheduleBlock(block, campID: campID)
                }
            }
            isReady = true
        }
    }
}

#Preview("Schedule — populated") {
    SchedulePreview(day: .today)
}

#Preview("Schedule — empty") {
    SchedulePreview(seeded: false)
}
