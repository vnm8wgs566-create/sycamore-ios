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
//  The court card is read out of the camp graph rather than off the block: which court you are
//  standing on and how many kids are in front of you is the camp's answer, not the schedule's, and
//  the two would drift the moment somebody was reassigned.
//
//  "Who is where" used to be read the same way and it was wrong to. That claim holds for court
//  *occupancy* and not for who runs a block: filtered by venue, every block of the day listed the
//  same names, so the screen could not answer whether this one was covered. `ScheduleBlock` now
//  carries `coachIDs`, the logistics card resolves those, and the venue filter has moved to the
//  editor's picker, where it was always the right question.
//

import SwiftUI

struct BlockDetailView: View {

    @Environment(AppStore.self) private var store

    let block: ScheduleBlock
    /// The block the camp is in the middle of. Handed down rather than recomputed so this cover
    /// and the card behind it can never name different blocks as current.
    let isCurrent: Bool
    let onClose: () -> Void

    /// The editor, presented from here rather than through `store.activeSheet`.
    ///
    /// This screen is itself a cover, and the root that owns `activeSheet` is underneath it —
    /// asking it to present would open the editor *behind* this screen. `PlayerScreen` reaches
    /// `8n` the same way and for the same reason. `ScheduleView` holds a second, independent one
    /// of these: two callers, two pieces of state, no shared slot to fight over.
    @State private var editing: BlockEditorDraft?

    @ScaledMetric(relativeTo: .footnote) private var statusDot = ScheduleMetrics.statusDot
    @ScaledMetric(relativeTo: .headline) private var ctaHeight = ScheduleMetrics.ctaHeight

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: ScheduleMetrics.blockGap) {
                    yourCourt
                    logistics
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
        // A sheet, not a cover: a cover cannot be presented over a cover, and this screen is one.
        // See `BlockEditorSheet`'s header for the rest of the reasoning.
        .sheet(item: $editing) { draft in
            BlockEditorSheet(draft: draft, onClose: { editing = nil })
                .environment(store)
        }
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

    /// The design's `⋯`. Every entry is a write `AppStore` already makes, so none of them is a
    /// button that does nothing.
    ///
    /// "Delete block" stays here *and* appears at the foot of the editor. That is one action in
    /// two places rather than two actions: from the menu it is the quick way out, and inside the
    /// editor it is where somebody who has just looked at what the block contains decides they do
    /// not want it. The alternative — dropping it here — would make deleting a block a two-step
    /// job through a sheet.
    private var blockMenu: some View {
        Menu {
            Button("Edit block", action: edit)
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

    // MARK: Logistics

    /// When the block runs, where, and who is on it.
    ///
    /// Always drawn, unlike the section it replaces. That one hid itself when it had nobody in it,
    /// which was right while empty meant "no staff at this venue" — but it now means "nobody is
    /// covering this", and the when and the where are facts about every block whether or not
    /// anybody has been assigned to one.
    private var logistics: some View {
        BlockAssigneeList(
            day: block.day,
            timeLabel: block.timeLabel,
            venueName: store.venue(block.venueID)?.name,
            people: BlockAssigneeList.coaches(on: block, in: store.camp),
            myID: store.myStaffRecord?.id,
            onAssign: assignAction
        )
    }

    /// Nil for a coach, so the empty row states the fact and offers nothing rather than drawing a
    /// control that would be refused — `ProfileView` locks its admin rows the same way. The gate
    /// that counts is the RLS policy on `schedule_blocks`.
    ///
    /// Spelled out rather than written as `store.isAdmin ? edit : nil` at the call site: a ternary
    /// between a method reference and `nil` gives the type checker nothing to anchor the optional
    /// on, and inside a nine-argument initialiser it gives up on the whole expression.
    private var assignAction: (() -> Void)? {
        guard store.isAdmin else { return nil }
        return edit
    }

    // MARK: Notes

    /// Hidden on a block nobody has written anything on — unless you are the person who would
    /// write the first one.
    ///
    /// The old condition was `!block.notes.isEmpty`, and its reason was sound: "0 notes on this
    /// block" is a row that exists only to say there is nothing in it. That reason survives for a
    /// coach, who can only read. For an admin the card is now also the *composer*, so hiding it
    /// hides the only way to add a note to a block that has none — an empty row for them is an
    /// invitation rather than a tally, and `notesRowLabel` words its zero case that way.
    @ViewBuilder
    private var notesRow: some View {
        if !block.notes.isEmpty || store.isAdmin {
            BlockNotesCard(block: block)
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

    /// `8m`, for every court this block covers.
    ///
    /// The courts come from the camp graph rather than off the block: `ScheduleBlock.detail` is
    /// one free-text line ("Courts 1–3 · 22 players") the design composes differently on every
    /// row, so the venue's own groups are the only answer that cannot drift from it.
    ///
    /// `8l` closes on the way. Both screens are covers, and a cover cannot be presented over a
    /// cover — but more than that, `8m` is where this block's work now happens, and stacking the
    /// two would leave a "Take attendance" button live underneath the screen it opened.
    private func openAttendance() {
        let groupIDs = store.camp?.groups(in: block.venueID).map(\.id) ?? []
        onClose()
        store.pushedScreen = .attendance(groupIDs, block)
    }

    /// Opens the editor on this block. Reached from the `⋯` and from "Assign" on an uncovered
    /// block — the second is the same screen entered with a different question in mind, not a
    /// second editor scoped to coaches.
    private func edit() {
        editing = BlockEditorDraft(editing: block)
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
    /// Who is on the block. The design's Tuesday says nothing about this, because nothing on it
    /// could until now — so the fixture takes it as a parameter and the two previews below draw
    /// the two answers that matter: covered, and not.
    var coachIDs: [StaffMember.ID] = []
    var isAdmin: Bool = true

    @State private var store: AppStore

    init(index: Int, coachIDs: [StaffMember.ID] = [], isAdmin: Bool = true) {
        self.index = index
        self.coachIDs = coachIDs
        self.isAdmin = isAdmin
        _store = State(initialValue: isAdmin ? ScheduleSampleDay.adminStore() : AppStore.preview)
    }

    var body: some View {
        let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id, coachIDs: coachIDs)
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
    BlockDetailPreview(index: 1, coachIDs: [SampleData.nass.id, SampleData.alexStaff.id])
}

#Preview("Block opened — needs a coach") {
    BlockDetailPreview(index: 3)
}

/// The same screen for somebody who can only read it: no "Assign" beside "Nobody assigned", and
/// the notes card carries no composer and no per-note `⋯`.
#Preview("Block opened — coach, read-only") {
    BlockDetailPreview(index: 1, coachIDs: [SampleData.nass.id], isAdmin: false)
}
