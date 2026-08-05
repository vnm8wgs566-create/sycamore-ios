//
//  BlockDetailView.swift
//  Sycamore
//
//  `8l` — one block opened. "Who is where, and the notes."
//
//  Presented as a cover rather than a sheet, which is the opposite of what `RootView` does with
//  Profile and Setup, and for the reason stated there: those four screens were tabs and none of
//  them draws a back control, so a cover would be a screen you cannot leave. This one draws its
//  own caret. It also draws a bottom call to action, which a sheet's grabber would sit under.
//
//  The court card and "Who is where" are read out of the camp graph rather than off the block.
//  `ScheduleBlock` carries a title, a time and its notes; who is standing where is the camp's
//  answer, not the schedule's, and the two would drift the moment somebody was reassigned.
//

import SwiftUI

struct BlockDetailView: View {

    @Environment(AppStore.self) private var store

    let block: ScheduleBlock
    /// The block the day is on. See `ScheduleDay.currentBlockID`.
    let isCurrent: Bool
    /// Handed the day back after a write, so `8k` behind this cover stays true.
    let onBlocksChanged: ([ScheduleBlock]) -> Void
    let onClose: () -> Void

    /// The notes are behind a tap because the design puts a caret on that row. Expanding in
    /// place rather than pushing a screen: three lines of text do not need one, and section 8
    /// draws no notes screen to push to.
    @State private var showsNotes = false
    @State private var failure: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)

            ScrollView {
                VStack(spacing: ScheduleMetrics.blockGap) {
                    yourCourt
                    whoIsWhere
                    notesRow
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, ScheduleMetrics.listTop)
                .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.grouped)
        .overlay(alignment: .bottom) { takeAttendance }
        // The cover hides `MainTabView`'s banner, so a failure in here needs one of its own.
        .storeErrorBanner(message: failure) { failure = nil }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            HStack(spacing: Spacing.medium) {
                Button(action: onClose) {
                    DisclosureChevron(systemName: "chevron.left", size: 20, color: Theme.inkSecondary)
                        // The caret is drawn at 20; only the frame around it reaches 44.
                        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to the schedule")

                Text(block.day.fullName)
                    .typeStyle(ScheduleType.blockTime, color: Theme.inkMuted)

                Spacer(minLength: 0)

                blockMenu
            }

            statusLine
                .padding(.top, Spacing.large)

            Text(block.title)
                .typeStyle(.tabTitle, color: Theme.ink)
                .padding(.top, Spacing.small)

            Text(subtitle)
                .typeStyle(ScheduleType.blockDetail, color: Theme.inkMuted)
                .padding(.top, Spacing.tight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.header)
        .padding(.bottom, ScheduleMetrics.headerBottom)
        .background(Theme.surface)
    }

    /// `9:00am – 10:30am · Courts 1–3`. `timeLabel` is the shared contract's own spelling, so
    /// the block reads the same here as it will anywhere else it is quoted.
    private var subtitle: String {
        guard let detail = block.detail, !detail.isEmpty else { return block.timeLabel }
        return "\(block.timeLabel) · \(detail)"
    }

    private var statusLine: some View {
        HStack(spacing: Spacing.small) {
            Circle()
                .fill(statusTint)
                .frame(width: ScheduleMetrics.statusDot, height: ScheduleMetrics.statusDot)

            Text(ScheduleDay.statusLine(for: block, isCurrent: isCurrent))
                .typeStyle(.chipSoft, color: statusTint)
        }
        .accessibilityElement(children: .combine)
    }

    /// Green marks the block you are on — but never over the amber. A block that needs a coach
    /// says so in amber whether it is next or now, and the current block can be that block.
    private var statusTint: Color {
        block.status == .planned && isCurrent ? Theme.accent : block.status.tint
    }

    /// The design's `⋯`. Both entries are writes the section 8 repository already makes, so
    /// neither is a button that does nothing.
    private var blockMenu: some View {
        Menu {
            if block.status != .done {
                Button("Mark done") { Task { await markDone() } }
            }
            Button("Delete block", role: .destructive) { Task { await delete() } }
        } label: {
            DisclosureChevron(systemName: "ellipsis", size: 20, color: Theme.inkSecondary)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .accessibilityLabel("Block options")
    }

    // MARK: Your court

    /// Skipped entirely for somebody with no court — an admin or a roaming trainer has no "your
    /// court", and a card headed that way with a dash in it would be worse than its absence.
    @ViewBuilder
    private var yourCourt: some View {
        if let assignment = store.myStaffRecord?.assignment,
           let court = store.group(assignment.groupID) {
            BlockCourtCard(
                block: block,
                courtLabel: assignment.groupLabel,
                playersHere: court.presentCount
            )
        }
    }

    // MARK: Who is where

    @ViewBuilder
    private var whoIsWhere: some View {
        // Resolved once: the filter-and-sort would otherwise run twice per pass, once to decide
        // whether the section exists and once to fill it.
        let people = assignees

        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Who is where")
                    .padding(.top, Spacing.tight)

                Card {
                    ForEach(people) { member in
                        assigneeRow(member)
                    }
                }
            }
        }
    }

    /// Everyone standing at this block's venue, courts first and roamers last, which is the
    /// order the design lists them in.
    private var assignees: [StaffMember] {
        guard let camp = store.camp else { return [] }
        return camp.staff
            .filter { $0.venueID == block.venueID || ($0.isRoaming && $0.venueID == nil) }
            .sorted { lhs, rhs in
                let left = lhs.assignment?.groupNumber ?? .max
                let right = rhs.assignment?.groupNumber ?? .max
                return left == right ? lhs.name < rhs.name : left < right
            }
    }

    private func assigneeRow(_ member: StaffMember) -> some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            InitialsAvatar(member.initials, size: ScheduleMetrics.assigneeAvatar)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                name(for: member)
                    .typeStyle(ScheduleType.assigneeName, color: Theme.ink)

                Text(member.role.membershipName)
                    .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
            }

            Spacer(minLength: Spacing.small)

            Text(member.assignment?.groupLabel ?? "Roaming")
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkFaint)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// `Nass · you`, with the qualifier in the accent and a lighter weight — interpolated as one
    /// `Text` rather than joined with `+`, which is the house rule in `Typography.swift`.
    private func name(for member: StaffMember) -> Text {
        guard member.id == store.myStaffRecord?.id else { return Text(member.name) }
        let you = Text(" · you").typeStyle(ScheduleType.assigneeMeta, color: Theme.accent)
        return Text("\(member.name)\(you)")
    }

    // MARK: Notes

    /// Hidden outright on a block nobody has written anything on. "0 notes on this block" is a
    /// row that exists only to say there is nothing in it.
    @ViewBuilder
    private var notesRow: some View {
        if !block.notes.isEmpty {
            Card(isDivided: false) {
                VStack(spacing: 0) {
                    Button(action: toggleNotes) {
                        CardRow(spacing: Spacing.row, horizontalPadding: ScheduleMetrics.cardPadding) {
                            DisclosureChevron(systemName: "note.text", size: 16, color: Theme.inkFaint)

                            Text(block.notesRowLabel)
                                .typeStyle(ScheduleType.notesRow, color: ScheduleTheme.noteInk)

                            Spacer(minLength: Spacing.small)

                            DisclosureChevron(size: 15)
                                .rotationEffect(.degrees(showsNotes ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showsNotes ? "Hides the notes" : "Shows the notes")

                    if showsNotes {
                        // Indices, not the notes themselves: two coaches can write the same
                        // line, and identical strings would collapse into one row.
                        ForEach(block.notes.indices, id: \.self) { index in
                            Hairline(color: Theme.hairlineSoft)

                            CardRow(spacing: Spacing.row,
                                    horizontalPadding: ScheduleMetrics.cardPadding,
                                    verticalPadding: Spacing.medium,
                                    alignment: .top) {
                                Text(block.notes[index])
                                    .typeStyle(ScheduleType.noteLine, color: Theme.inkTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Take attendance

    private var takeAttendance: some View {
        PrimaryButton(
            "Take attendance",
            height: ScheduleMetrics.ctaHeight,
            font: .button,
            action: openAttendance
        )
        .shadow(ScheduleShadows.cta)
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, Spacing.tabBarInset)
    }

    // MARK: Actions

    private func toggleNotes() {
        withAnimation(.snappy(duration: 0.22)) { showsNotes.toggle() }
    }

    /// Attendance is Groups' job — marking a kid away is the swipe on a coach card — so the
    /// design's call to action goes there rather than to a screen section 8 does not draw.
    private func openAttendance() {
        store.selectedTab = .groups
        onClose()
    }

    private func markDone() async {
        var updated = block
        updated.status = .done
        await write { repository, campID in
            try await repository.updateScheduleBlock(updated, campID: campID)
        }
    }

    private func delete() async {
        let deleted = await write { repository, campID in
            try await repository.deleteScheduleBlock(block.id, campID: campID)
        }
        // Only leave once the block is actually gone — closing on a failure would drop the
        // banner explaining why it is still there.
        if deleted { onClose() }
    }

    @discardableResult
    private func write(
        _ work: (SycamoreRepository, Camp.ID) async throws -> [ScheduleBlock]
    ) async -> Bool {
        guard let campID = store.camp?.id else { return false }
        do {
            let day = try await work(store.repository, campID)
            onBlocksChanged(day)
            return true
        } catch {
            failure = error.localizedDescription
            return false
        }
    }
}

// MARK: - Previews

private struct BlockDetailPreview: View {
    var index: Int

    var body: some View {
        let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
        let currentID = ScheduleDay.currentBlockID(in: blocks)

        BlockDetailView(
            block: blocks[index],
            isCurrent: blocks[index].id == currentID,
            onBlocksChanged: { _ in },
            onClose: {}
        )
        .environment(AppStore.preview)
        .showsMockStatusBar()
    }
}

#Preview("Block opened — on now") {
    BlockDetailPreview(index: 1)
}

#Preview("Block opened — needs a coach") {
    BlockDetailPreview(index: 3)
}
