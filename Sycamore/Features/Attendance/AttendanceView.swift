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
        // Built once per pass and handed down. It walks the camp, sorts and maps, and reading it
        // as a computed property from five places did that five times for every tap on a screen
        // whose whole job is being tapped.
        let entries = roster

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()
                AttendanceHeader(
                    sessionLine: sessionLine,
                    markedCount: entries.count { marked.contains($0.id) },
                    total: entries.count,
                    onClose: close
                )
            }
            // The white carries up under the status bar, as the design draws it — otherwise the
            // page colour shows above the header block on a device with a notch.
            .background(Theme.surface.ignoresSafeArea(edges: .top))

            Hairline(color: Theme.hairline)

            ScrollView {
                roll(entries)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, OnTheDayTokens.headerTop)
                    .padding(.bottom, OnTheDayTokens.contentBottomInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, not `grouped`'s `#F6F7F9`. Section 8's page is a shade warmer than stage
        // 1's, which is the same half-step towards green the ink ramp takes.
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { finishBar(entries) }
        .onAppear { seed(entries) }
        // One light tap per answer, and a softer one for an undo, so the two are told apart
        // without looking. The count moves on both.
        .sensoryFeedback(trigger: undoStack.count) { previous, current in
            current > previous ? .impact(weight: .light) : .impact(flexibility: .soft, intensity: 0.6)
        }
        // And the one that matters: the last kid on the list.
        .sensoryFeedback(trigger: isComplete(entries)) { previous, current in
            current && !previous ? .success : nil
        }
        .sheet(item: $pickupTarget) { target in
            EarlyPickupSheet(store: store, playerID: target.id) { pickupTarget = nil }
        }
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
                        .padding(.top, OnTheDayTokens.overlineLead)

                    VStack(spacing: OnTheDayTokens.contentGap) {
                        ForEach(unmarked) { entry in
                            AttendanceAnswerCard(
                                entry: entry,
                                onHere: { answer(entry.id, away: false) },
                                onAway: { answer(entry.id, away: true) },
                                onLeavingEarly: { pickupTarget = PickupTarget(id: entry.id) }
                            )
                        }
                    }
                    // The column's `gap:9px` plus the `padding-top:6px` the second overline
                    // carries — the design's one place with more air than the rest.
                    .padding(.bottom, OnTheDayTokens.contentGap + OnTheDayTokens.overlineBreak)
                }

                if !answered.isEmpty {
                    AttendanceOverline(
                        title: "Marked",
                        count: answered.count,
                        actionTitle: undoStack.isEmpty ? nil : "Undo last",
                        action: undoLast
                    )
                    // Once everyone is answered this is the first thing on the screen, and it
                    // takes the opening overline's 2pt rather than the 6 that separates sections.
                    .padding(.top, unmarked.isEmpty ? OnTheDayTokens.overlineLead : 0)

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
    ///
    /// `ContentUnavailableView` rather than a hand-built pair of labels: it is the platform's own
    /// empty state, so it centres itself, scales with Dynamic Type and reads to VoiceOver as one
    /// announcement instead of two stray strings.
    private var emptyCourt: some View {
        ContentUnavailableView {
            Label("Nobody to mark yet", systemImage: "figure.tennis")
        } description: {
            Text("Kids appear here as soon as the ladder puts them on \(groupIDs.count > 1 ? "these courts" : "this court").")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.section)
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
            font: .onTheDayBar,
            action: close
        )
        .shadow(OnTheDayTokens.barShadow)
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

/// Every colour here is a `Theme` token, so the dark scheme is a check rather than a second
/// design — but this screen carries the palette's warmest values (`surfaceWarm`, `inkWarm`) and
/// those are the ones a derived dark column is most likely to get wrong.
#Preview("Attendance — dark") {
    AttendanceView(groupIDs: [SampleData.nassCourt.id])
        .environment(partlyMarkedStore())
        .showsMockStatusBar()
        .preferredColorScheme(.dark)
}

/// The app caps Dynamic Type at `.accessibility1`; the two answers and the pinned bar are what
/// break first if a frame is fixed rather than floored.
#Preview("Attendance — accessibility1") {
    AttendanceView(groupIDs: [SampleData.nassCourt.id])
        .environment(partlyMarkedStore())
        .showsMockStatusBar()
        .dynamicTypeSize(.accessibility1)
}
