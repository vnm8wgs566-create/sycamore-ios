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
//  The blocks are held here in `@State` rather than on `AppStore`, which does not expose the
//  section 8 repository yet. That is the one deliberate departure from "nothing else talks to
//  the repository" — see the PR for the store surface this wants instead.
//

import SwiftUI

struct ScheduleView: View {

    @Environment(AppStore.self) private var store
    /// Opens on today rather than on the design's Friday. `8f` happens to depict a Friday, but
    /// the day a person wants when they open Schedule is the one they are standing in.
    @State private var selectedDay: Weekday = .today
    @State private var blocks: [ScheduleBlock] = []
    /// The block `8l` is showing. Refreshed rather than dropped after a write, so the cover
    /// survives its own edits.
    @State private var openedBlock: ScheduleBlock?
    /// Held until the first read lands, so an empty day never flashes `8f` on its way to `8k`.
    @State private var hasLoaded = false
    @State private var failure: String?

    /// The venue whose day this is: the one you are standing in, or the camp's first for
    /// somebody with no post of their own.
    private var venueID: Venue.ID? {
        store.myStaffRecord?.venueID ?? store.camp?.orderedVenues.first?.id
    }

    private var currentBlockID: ScheduleBlock.ID? { ScheduleDay.currentBlockID(in: blocks) }

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
                    .padding(.bottom, Spacing.medium)
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                day
                    .padding(.top, ScheduleMetrics.listTop)
                    .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.grouped)
        .task(id: ScheduleLoad(campID: store.camp?.id, venueID: venueID, day: selectedDay)) {
            await load()
        }
        .storeErrorBanner(message: failure) { failure = nil }
        .blockDetailCover(item: $openedBlock) { block in
            BlockDetailView(
                block: block,
                isCurrent: block.id == currentBlockID,
                onBlocksChanged: absorb,
                onClose: { openedBlock = nil }
            )
            .environment(store)
        }
    }

    // MARK: Day chips

    /// Five equal chips, the same row Early pick-up draws. `.day` metrics carry no horizontal
    /// padding by design — the width is meant to come from `fillsWidth`, and without it the
    /// chips shrink-wrap their labels and the row reads as five different-sized buttons.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
                Chip(
                    day.shortName,
                    isSelected: day == selectedDay,
                    selectedTone: .accent,
                    metrics: .day,
                    fillsWidth: true
                ) {
                    selectedDay = day
                }
            }
        }
        .padding(.horizontal, Spacing.bar)
    }

    // MARK: The day

    @ViewBuilder
    private var day: some View {
        if !hasLoaded {
            // Nothing, deliberately. The read is one hop and a spinner for that length is a
            // flicker rather than information — but drawing `8f` in the meantime would tell
            // somebody their day is empty before anybody has looked.
            EmptyView()
        } else if blocks.isEmpty {
            emptyDay
                .padding(.horizontal, Spacing.gutter)
        } else {
            LazyVStack(spacing: ScheduleMetrics.blockGap) {
                ForEach(blocks) { block in
                    ScheduleBlockCard(block: block, isCurrent: block.id == currentBlockID) {
                        openedBlock = block
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
        }
    }

    // MARK: Empty state

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: 0) {
            emptyDayHero
                .padding(.bottom, Spacing.large)

            Text("Or start from a shape")
                .typeStyle(.sectionHeader, color: Theme.inkMuted)
                .padding(.bottom, Spacing.medium)

            Card {
                ForEach(DayShape.allCases) { shape in
                    shapeRow(shape)
                }

                // Not offered on Monday, where it would copy the day onto itself.
                if selectedDay != .mon {
                    copyMondayRow
                }
            }
        }
    }

    /// The card the design gives an empty day: the mark held back to a watermark, the day named,
    /// one sentence saying what a block is for, and the one thing to do about it.
    private var emptyDayHero: some View {
        Card(isDivided: false) {
            VStack(spacing: 0) {
                SycamoreMark(variant: .ringed)
                    .frame(width: ScheduleMetrics.emptyMark, height: ScheduleMetrics.emptyMark)
                    .opacity(0.18)
                    .accessibilityHidden(true)

                Text("\(selectedDay.fullName) is empty.")
                    .typeStyle(.profileName, color: Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.large)

                Text("Blocks are how the day gets its shape — one per activity, with who runs it.")
                    .typeStyle(.body, color: Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: ScheduleMetrics.emptyCopyWidth)
                    .padding(.top, ScheduleMetrics.blockGap)

                PrimaryButton(
                    "Add the first block",
                    systemImage: "plus",
                    height: ScheduleMetrics.ctaHeight,
                    radius: Radius.input,
                    font: .buttonSmall
                ) {
                    Task { await addFirstBlock() }
                }
                .padding(.top, Spacing.section)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.section)
            .padding(.vertical, Spacing.hero)
        }
    }

    private func shapeRow(_ shape: DayShape) -> some View {
        Button {
            Task { await apply(shape) }
        } label: {
            CardRow(verticalPadding: Spacing.medium) {
                shapeTile(shape)

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(shape.title)
                        .typeStyle(.rowLabel, color: Theme.ink)
                    Text(shape.detail)
                        .typeStyle(.meta, color: Theme.inkMuted)
                }

                Spacer(minLength: Spacing.small)

                DisclosureChevron(size: 15)
            }
        }
        .buttonStyle(.plain)
    }

    private func shapeTile(_ shape: DayShape) -> some View {
        let tile = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)

        return tile
            .fill(ScheduleTheme.noteTint)
            .frame(width: ScheduleMetrics.shapeTile, height: ScheduleMetrics.shapeTile)
            .overlay { tile.strokeBorder(ScheduleTheme.noteTintBorder, lineWidth: BorderWidth.hairline) }
            .overlay { DisclosureChevron(systemName: shape.symbol, size: 17, color: Theme.accent) }
    }

    /// The design tucks this inside the card rather than under it, on its own faintly tinted
    /// row — copying Monday is a fourth shape, not a footnote.
    private var copyMondayRow: some View {
        Button {
            Task { await copyMonday() }
        } label: {
            CardRow(verticalPadding: Spacing.medium) {
                Text("Copy Monday instead")
                    .typeStyle(.chipMedium, color: Theme.accent)

                Spacer(minLength: Spacing.small)

                DisclosureChevron(systemName: "doc.on.doc", size: 15, color: Theme.accent)
            }
            .background(Theme.runBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: Reads and writes

    private func load() async {
        guard let campID = store.camp?.id, let venueID else {
            blocks = []
            hasLoaded = true
            return
        }
        do {
            blocks = try await store.repository.scheduleBlocks(
                forVenue: venueID, day: selectedDay, campID: campID
            )
        } catch {
            // Cleared rather than kept: leaving the last day's blocks under this day's chip
            // would be a schedule for the wrong day, which is worse than an empty one beside a
            // banner saying why.
            blocks = []
            failure = error.localizedDescription
        }
        hasLoaded = true
    }

    /// There is no block composer in section 8 yet, so this writes the one thing "add" can mean
    /// without one: an empty 9:00 block for the day to be built around.
    private func addFirstBlock() async {
        await write { repository, venueID, campID in
            try await repository.addScheduleBlock(
                ScheduleBlock(
                    venueID: venueID, day: selectedDay, startsAt: TimeOfDay(9, 0),
                    title: "New block"
                ),
                campID: campID
            )
        }
    }

    private func apply(_ shape: DayShape) async {
        await write { repository, venueID, campID in
            try await repository.applyDayShape(
                shape, toVenue: venueID, day: selectedDay, campID: campID
            )
        }
    }

    private func copyMonday() async {
        await write { repository, venueID, campID in
            try await repository.copySchedule(
                fromDay: .mon, toDay: selectedDay, venueID: venueID, campID: campID
            )
        }
    }

    private func write(
        _ work: (SycamoreRepository, Venue.ID, Camp.ID) async throws -> [ScheduleBlock]
    ) async {
        guard let campID = store.camp?.id, let venueID else { return }
        do {
            blocks = try await work(store.repository, venueID, campID)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Takes the day back from `8l` after it writes, and re-resolves the open block from it —
    /// so marking a block done redraws the cover, and deleting one closes it.
    private func absorb(_ day: [ScheduleBlock]) {
        blocks = day
        if let open = openedBlock {
            openedBlock = day.first { $0.id == open.id }
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

/// Seeds the day through the repository before showing the screen, because `AppStore` has no
/// section 8 surface to seed through and `InMemoryRepository`'s storage is actor-isolated.
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
            if seeded, let campID = store.camp?.id, let venueID = store.myStaffRecord?.venueID {
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
