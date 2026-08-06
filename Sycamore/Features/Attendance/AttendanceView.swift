//
//  AttendanceView.swift
//  Sycamore
//
//  `8m` — Attendance. "Only the unmarked ask anything."
//
//  Reached from `8l`, where a block carries a "Take attendance" bar. A block runs across courts
//  ("Courts 1–3"), so this takes a list of them rather than one, and the list of kids is the
//  union in ladder order — which is why the numerals run 1, 2, 3 … 11 rather than 1…8.
//
//  The screen's shape is the whole idea: everything still to answer is a full card with two
//  large buttons, and everything answered collapses into a quiet list underneath. The work in
//  front of you shrinks as you do it. That only works because there are three states here and
//  the model has two — a kid is present or away, and "not answered yet" has nowhere to live. So
//  it lives in `marked`, below, and is seeded from the kids the day already says are away.
//
//  Everything read and written here is today's. `AppStore.setAway` writes `store.today` and takes
//  no day, which is right for a screen you stand on a court to use, but it does mean opening a
//  Tuesday block on a Wednesday would mark Wednesday. See the PR body.
//

import SwiftUI

struct AttendanceView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The courts this session covers. One is the common case — a coach marking their own court.
    let groupIDs: [Group.ID]
    /// The block being marked, which names the session: "Skills rotation · 9:00am – 10:30am".
    var block: ScheduleBlock?
    /// How the screen goes away. Nil falls back to `dismiss`, so this works pushed, presented as
    /// a sheet, or presented as a cover without the caller having to say which.
    var onClose: (() -> Void)?

    /// Who has been answered this session. Not derived from the camp graph: an attendance row
    /// says present-or-away, and a kid with no row is indistinguishable from one nobody has got
    /// to yet. Seeded once on appearance from the day's away records — those *were* answered.
    @State private var marked: Set<Player.ID> = []
    /// Every answer given this session, newest last, each carrying what the day said before it.
    /// `Undo last` walks back down this.
    @State private var undoStack: [AttendanceMark] = []
    @State private var hasSeeded = false
    @State private var pickupTarget: PickupTarget?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()
                header(roster)
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                roll(roster)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.gutterWide)
                    .padding(.bottom, Spacing.tabBarClearance)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.grouped)
        .overlay(alignment: .bottom) { finishBar(roster) }
        .onAppear { seed(roster) }
        // One light tap per answer, and a softer one for an undo, so the two are told apart
        // without looking. The count moves on both.
        .sensoryFeedback(trigger: undoStack.count) { previous, current in
            current > previous ? .impact(weight: .light) : .impact(flexibility: .soft, intensity: 0.6)
        }
        // And the one that matters: the last kid on the list.
        .sensoryFeedback(trigger: isComplete(roster)) { previous, current in
            current && !previous ? .success : nil
        }
        .sheet(item: $pickupTarget) { target in
            EarlyPickupSheet(store: store, playerID: target.id) { pickupTarget = nil }
        }
    }

    // MARK: - Header

    private func header(_ roster: [AttendanceEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.tight) {
                closeButton
                Text(sessionLine)
                    .typeStyle(.sheetSubtitle, color: Theme.inkMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            // The glyph is centred in a 44pt frame, so 8pt here puts it on the design's 22pt
            // gutter without the hit region eating into the title below.
            .padding(.horizontal, Spacing.small)

            Text("Attendance")
                .typeStyle(.tabTitle, color: Theme.ink)
                .padding(.horizontal, Spacing.header)
                .padding(.top, Spacing.gutterWide)

            progress(roster)
                .padding(.horizontal, Spacing.header)
                .padding(.top, Spacing.gutterWide)
        }
        .padding(.bottom, Spacing.large)
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close attendance")
    }

    /// The design's 4pt track. The fill is scaled rather than measured: at 4pt tall the capsule's
    /// 2pt ends distort by well under a point, and that keeps the bar free of geometry readers.
    private func progress(_ roster: [AttendanceEntry]) -> some View {
        let done = roster.count { marked.contains($0.id) }
        let fraction = roster.isEmpty ? 0 : Double(done) / Double(roster.count)

        return HStack(spacing: Spacing.row) {
            Capsule(style: .continuous)
                .fill(Theme.hairline)
                .frame(height: OnTheDayTokens.progressHeight)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Theme.accent)
                        .scaleEffect(x: fraction, y: 1, anchor: .leading)
                }
                .animation(.snappy(duration: 0.25), value: fraction)

            Text("\(done) of \(roster.count)")
                .typeStyle(.metaSmall, color: Theme.inkSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marked")
        .accessibilityValue("\(done) of \(roster.count)")
    }

    // MARK: - The roll

    @ViewBuilder
    private func roll(_ roster: [AttendanceEntry]) -> some View {
        if roster.isEmpty {
            emptyCourt
        } else {
            let unmarked = roster.filter { !marked.contains($0.id) }
            let answered = roster.filter { marked.contains($0.id) }

            VStack(alignment: .leading, spacing: 0) {
                if !unmarked.isEmpty {
                    AttendanceOverline(title: "Still to mark", count: unmarked.count)

                    VStack(spacing: Spacing.small) {
                        ForEach(unmarked) { entry in
                            AttendanceAnswerCard(
                                entry: entry,
                                onHere: { answer(entry.id, away: false) },
                                onAway: { answer(entry.id, away: true) },
                                onLeavingEarly: { pickupTarget = PickupTarget(id: entry.id) }
                            )
                        }
                    }
                    .padding(.bottom, Spacing.large)
                }

                if !answered.isEmpty {
                    AttendanceOverline(
                        title: "Marked",
                        count: answered.count,
                        actionTitle: undoStack.isEmpty ? nil : "Undo last",
                        action: undoLast
                    )

                    Card(radius: OnTheDayTokens.card) {
                        ForEach(answered) { entry in
                            AttendanceMarkedRow(entry: entry) {
                                answer(entry.id, away: !entry.isAway)
                            }
                        }
                    }
                }
            }
            // Every answer sends a card from the top of the screen into the list below, which
            // is a lot of travel to watch twenty-two times. Reduce Motion drops the spring's
            // overshoot for a plain fade-length ease.
            .animation(
                reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.28),
                value: marked
            )
        }
    }

    /// A session with nobody in it is a real state — a block can name a court the ladder has not
    /// filled yet — so it says so rather than showing an empty list under a full progress bar.
    private var emptyCourt: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Nobody to mark yet.")
                .typeStyle(.title2, color: Theme.ink)
            Text("Kids appear here as soon as the ladder puts them on \(groupIDs.count > 1 ? "these courts" : "this court").")
                .typeStyle(.body, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.large)
    }

    // MARK: - Finish

    /// "Finish · 2 left" while there is anything to answer, and just "Finish" once there is not.
    /// Carrying the count on the way out is the only reminder the screen gives — nothing here
    /// blocks you from leaving a kid unanswered, because a coach who has to go has to go.
    private func finishBar(_ roster: [AttendanceEntry]) -> some View {
        let left = roster.count { !marked.contains($0.id) }

        return PrimaryButton(
            left == 0 ? "Finish" : "Finish · \(left) left",
            tone: .dark,
            height: OnTheDayTokens.barHeight,
            radius: Radius.button,
            font: .button,
            action: close
        )
        .shadow(Shadows.tabBar)
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, OnTheDayTokens.barInset)
    }

    // MARK: - Reads

    private var courts: [CourtGroup] {
        groupIDs.compactMap { store.group($0) }
    }

    /// "Skills rotation · 9:00am – 10:30am", or the courts themselves when there is no block.
    private var sessionLine: String {
        if let block {
            return "\(block.title) · \(block.timeLabel)"
        }
        let labels = courts.map(\.label)
        return labels.isEmpty ? store.today.fullName : labels.joined(separator: ", ")
    }

    private var roster: [AttendanceEntry] {
        guard let camp = store.camp else { return [] }
        // Naming the court only earns its place when the session spans more than one.
        let namesCourts = groupIDs.count > 1

        return groupIDs
            .flatMap { camp.players(inGroup: $0) }
            .sorted { $0.overallRank < $1.overallRank }
            .map { player in
                AttendanceEntry(
                    id: player.id,
                    name: player.displayName,
                    rank: player.overallRank,
                    courtLabel: namesCourts ? player.groupID.flatMap { camp.group($0)?.label } : nil,
                    isAway: camp.isAway(player.id, on: store.today),
                    leavesAt: camp.leavesAt(player.id, on: store.today)
                )
            }
    }

    private func isComplete(_ roster: [AttendanceEntry]) -> Bool {
        !roster.isEmpty && roster.allSatisfy { marked.contains($0.id) }
    }

    // MARK: - Writes

    /// Seeded once, not on every appearance: coming back from `8n` must not re-answer anybody,
    /// and a kid marked *here* this session has no away record to be seeded from.
    private func seed(_ roster: [AttendanceEntry]) {
        guard !hasSeeded else { return }
        hasSeeded = true
        marked = Set(roster.filter(\.isAway).map(\.id))
    }

    /// Records an answer, remembering what the day said before it so `Undo last` can put back
    /// exactly that — including "not answered yet", which the store has no way to express.
    private func answer(_ playerID: Player.ID, away: Bool) {
        undoStack.append(
            AttendanceMark(
                playerID: playerID,
                wasAway: store.isAway(playerID),
                wasMarked: marked.contains(playerID)
            )
        )
        marked.insert(playerID)
        Task { await store.setAway(playerID, away) }
    }

    private func undoLast() {
        guard let last = undoStack.popLast() else { return }
        if !last.wasMarked { marked.remove(last.playerID) }
        Task { await store.setAway(last.playerID, last.wasAway) }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

// MARK: - Undo

/// One answer, and the state it replaced.
private struct AttendanceMark: Hashable, Sendable {
    let playerID: Player.ID
    let wasAway: Bool
    /// False when this was the kid's first answer of the session, which is what tells `undoLast`
    /// to put them back under "Still to mark" rather than merely flip them.
    let wasMarked: Bool
}

/// `Player.ID` is a `UUID`, and `.sheet(item:)` wants something `Identifiable`.
private struct PickupTarget: Identifiable, Hashable {
    let id: Player.ID
}

// MARK: - Previews

/// The design's own state: a session part-way through, two kids left.
@MainActor
private func partlyMarkedStore() -> AppStore {
    let store = AppStore.preview
    // Mia K is out today, which is what seeds the marked list on first appearance.
    if var camp = store.camp {
        let court = SampleData.nassCourt
        if let mia = camp.players(inGroup: court.id).dropFirst(3).first {
            camp.setAttendance(playerID: mia.id, day: .today, present: false)
        }
        if let serene = camp.players(inGroup: court.id).first {
            camp.setEarlyPickup(playerID: serene.id, day: .today, leavesAt: TimeOfDay(14, 30))
        }
        store.camp = camp
    }
    return store
}

#Preview("Attendance — one court") {
    AttendanceView(
        groupIDs: [SampleData.nassCourt.id],
        block: ScheduleBlock(
            venueID: SampleData.sycamore.id,
            day: .today,
            startsAt: TimeOfDay(9, 0),
            endsAt: TimeOfDay(10, 30),
            title: "Skills rotation"
        )
    ) {}
    .environment(partlyMarkedStore())
    .showsMockStatusBar()
}

#Preview("Attendance — three courts") {
    AttendanceView(
        groupIDs: [SampleData.nassCourt.id, SampleData.hubertsCourt.id, SampleData.alexsCourt.id],
        block: ScheduleBlock(
            venueID: SampleData.sycamore.id,
            day: .today,
            startsAt: TimeOfDay(9, 0),
            endsAt: TimeOfDay(10, 30),
            title: "Skills rotation"
        )
    ) {}
    .environment(partlyMarkedStore())
    .showsMockStatusBar()
}
