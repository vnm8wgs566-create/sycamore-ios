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
    /// The block the camp is in the middle of. Handed down rather than recomputed so this cover
    /// and the card behind it can never name different blocks as current.
    let isCurrent: Bool
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var statusDot = ScheduleMetrics.statusDot
    @ScaledMetric(relativeTo: .headline) private var ctaHeight = ScheduleMetrics.ctaHeight

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: ScheduleMetrics.blockGap) {
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
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { takeAttendance }
        // A cover hides the pair `MainTabView` floats, so it carries the store's own — not a
        // private banner. `AppStore.perform` owns `errorMessage` and `isWorking`; this screen
        // just has to be somewhere they can be seen from.
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
        .storeWorkingIndicator(store.isWorking)
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
                .typeStyle(ScheduleType.blockHeading, color: Theme.ink)
                .padding(.top, ScheduleMetrics.rowGap)

            Text(subtitle)
                .typeStyle(ScheduleType.blockDetail, color: Theme.inkMuted)
                .padding(.top, ScheduleMetrics.headerSubtitleGap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.header)
        .padding(.top, ScheduleMetrics.headerTop)
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
                .frame(width: statusDot, height: statusDot)
                .accessibilityHidden(true)

            Text(ScheduleDay.statusLine(for: block, isCurrent: isCurrent))
                .typeStyle(ScheduleType.inlineAction, color: statusTint)
        }
    }

    /// Green marks the block you are on — but never over the amber. A block that needs a coach
    /// says so in amber whether it is next or now, and the current block can be that block.
    private var statusTint: Color {
        block.status == .planned && isCurrent ? Theme.accent : block.status.tint
    }

    /// The design's `⋯`. Both entries are writes `AppStore` already makes, so neither is a
    /// button that does nothing.
    private var blockMenu: some View {
        Menu {
            if block.status != .done {
                Button("Mark done", action: markDone)
            }
            Button("Delete block", role: .destructive, action: delete)
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
            BlockAssigneeList(people: people, myID: store.myStaffRecord?.id)
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

    // MARK: Notes

    /// Hidden outright on a block nobody has written anything on. "0 notes on this block" is a
    /// row that exists only to say there is nothing in it.
    @ViewBuilder
    private var notesRow: some View {
        if !block.notes.isEmpty {
            BlockNotesCard(notes: block.notes, label: block.notesRowLabel)
        }
    }

    // MARK: Take attendance

    private var takeAttendance: some View {
        PrimaryButton(
            "Take attendance",
            height: ctaHeight,
            font: ScheduleType.cta,
            action: openAttendance
        )
        .shadow(ScheduleShadows.cta)
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, ScheduleMetrics.ctaBottom)
    }

    // MARK: Actions

    /// Attendance is Groups' job — marking a kid away is the swipe on a coach card — so the
    /// design's call to action goes there rather than to a screen section 8 does not draw.
    private func openAttendance() {
        store.selectedTab = .groups
        onClose()
    }

    private func markDone() {
        var updated = block
        updated.status = .done
        Task { await store.updateScheduleBlock(updated) }
    }

    /// The cover goes away when `store.scheduleBlocks` comes back without this block — see
    /// `ScheduleView`. Closing here instead would drop the banner explaining a delete that
    /// failed.
    private func delete() {
        Task { await store.deleteScheduleBlock(block.id) }
    }
}

// MARK: - Previews

private struct BlockDetailPreview: View {
    var index: Int

    @State private var store = AppStore.preview

    var body: some View {
        let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)
        // The design's clock, so "On now · 41 min left" reads as `8l` draws it whatever the
        // time is on the machine running the preview.
        let currentID = ScheduleBlock.running(in: blocks, at: TimeOfDay(9, 41))?.id

        BlockDetailView(
            block: blocks[index],
            isCurrent: blocks[index].id == currentID,
            onClose: {}
        )
        .environment(store)
        .showsMockStatusBar()
    }
}

#Preview("Block opened — on now") {
    BlockDetailPreview(index: 1)
}

#Preview("Block opened — needs a coach") {
    BlockDetailPreview(index: 3)
}
