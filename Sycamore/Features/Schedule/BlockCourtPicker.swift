//
//  BlockCourtPicker.swift
//  Sycamore
//
//  Which courts an assigned block runs on — the thing `schedule_blocks.detail` used to say in
//  prose and nothing could read back.
//
//  A court per row, ticked or not, exactly as `BlockCoachPicker` draws a person. The two sit under
//  one another in the editor and are the same question asked about two kinds of thing, so drawing
//  them differently would only make a reader wonder what the difference was.
//
//  ── The venue is the ceiling, and it is not enforced here ─────────────────────────────────────
//
//  "Max of courts for that venue" needs no arithmetic. `Venue.groupCount` is the count, and
//  `Camp.syncGroups(for:)` keeps exactly that many `Group` rows for the
//  venue — trimming the tail when the number comes down and minting rows when it goes up. So the
//  pool below *is* the maximum: there is no eighth court to tick at a venue with seven, because
//  there is no eighth row. A `courtIDs.count <= venue.groupCount` guard would be a second
//  statement of the same fact, and the kind that goes stale.
//
//  `Camp.groups(in:)` returns them in `rankOrder`, which is the order Setup shows and the order
//  the deal in `Camp.redistribute(in:across:)` fills them — so court 1 is at the top here for the
//  same reason it takes the top of the ladder there.
//

import SwiftUI

struct BlockCourtPicker: View {

    /// The venue's courts, already resolved and in rank order. Handed in the way
    /// `BlockCoachPicker` takes its people, so the sheet owns the one call to the camp.
    let courts: [CourtGroup]
    @Binding var selection: Set<Group.ID>
    /// Who is standing on each court — the whole of a row's grey line now, rather than half of it.
    ///
    /// Handed in already resolved, like `BlockCoachPicker`'s people, so the one call into the camp
    /// graph is the sheet's — see `coachNames(in:venueID:)`. A `Camp` on this view instead would
    /// put graph-walking inside a `body` that re-runs on every keystroke in the title field.
    var coachNames: [Group.ID: String] = [:]

    // A `closures: [Group.ID: String]` used to sit beside `coachNames`, threaded in by the editor
    // out of `store.courts`. Its doc argued that closure was "a `CourtCard` fact about *this
    // morning* rather than a `Group` fact about the camp, so it is not on the graph this view
    // could walk even if it wanted to" — which was true when it was written and is not now.
    // `Group.closedReason` (`Models.swift:563-582`) is that column on the graph, so a court handed
    // to this view already knows why it is shut, and the parameter was a second route to a fact
    // sitting on the value beside it. The editor's own copy came from `store.courts`, which is
    // loaded for one venue, so on a two-venue camp it came back empty and a shut court drew as an
    // ordinary one; dropping the parameter is what closes that, not a wider filter.

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius) {
            if courts.isEmpty {
                emptyRow
            } else {
                BlockQuickActions(
                    allTitle: "All courts",
                    noneTitle: "No courts",
                    onAll: { selection = Set(courts.map(\.id)) },
                    onNone: { selection = [] }
                )

                ForEach(courts) { court in
                    row(court)
                }
            }
        }
    }

    private func row(_ court: CourtGroup) -> some View {
        let isOn = selection.contains(court.id)
        let closure = court.closedReason

        return BlockPickRow(
            title: court.label,
            detail: detail(court, closedFor: closure),
            detailColor: detailColor(court, closedFor: closure),
            isOn: isOn,
            isMuted: closure != nil,
            hint: isOn ? "Takes this block off the court" : "Puts this block on the court"
        ) {
            selection.toggle(court.id)
        }
    }

    /// `Nass coaches here`, `Needs a coach`, or `Closed — Net down`.
    ///
    /// **The head-count is gone from this line, and it was there.** It read `8 kids · Nass`, on the
    /// argument that a timetable wants the roll rather than today's attendance. `5b` draws neither
    /// number (`design/rebuild/section-t5.html:104-106`), and the reason it is right to drop is
    /// that the count answers a question this card is not asking: which courts a block runs on is
    /// decided by which courts are *free and staffed*, and how many children happen to be standing
    /// on Court 2 right now is about to be changed by the Kids card two sections down. The count
    /// still has a reader — `PlayerCourtChoices.meta` draws `6 of 8 · Nass` on the sheet that
    /// *is* about where a child goes.
    ///
    /// Closure leads, for `PlayerCourtOption.flag`'s reason: a court out of play is out of play
    /// whoever is nominally on it, so the reason replaces the coach rather than joining it. It is
    /// read straight off `court.closedReason` — see the note where the `closures` parameter used
    /// to be for why nothing threads it in any more.
    ///
    /// The reason is printed as it was typed. The design writes `Closed — net down` in lower case
    /// and this writes `Closed — Net down`, which is the one place these rows depart from the
    /// frame: the reason is free text somebody typed into Overview, and "Tom is on it" lower-cased
    /// mid-sentence is a person's name spelled wrong. `CoachAvailability.subtitle` makes the same
    /// call in the other direction and says why — it lower-cases "roaming" because that word is the
    /// app's own, and this one is not.
    private func detail(_ court: CourtGroup, closedFor closure: String?) -> String {
        if let closure { return "Closed — \(closure)" }
        guard let coach = coachNames[court.id] else { return CoachPill.needsACoach }
        return "\(coach) coaches here"
    }

    /// Grey for a court with somebody on it, amber for one without, faint for one that is shut.
    ///
    /// The amber is the same amber as the three warning lines under the time fields, and means the
    /// same thing: worth knowing, never a refusal. A block on an unstaffed court is an ordinary
    /// morning — the Coaches card below is where it gets fixed, and it may well be fixed by
    /// somebody walking over at ten to eleven rather than by this sheet at all.
    private func detailColor(_ court: CourtGroup, closedFor closure: String?) -> Color {
        if closure != nil { return Theme.inkFaint }
        return coachNames[court.id] == nil ? Theme.warning : Theme.inkMuted
    }

    /// A venue with no courts. Drawn rather than left blank, for the reason `BlockCoachPicker`'s
    /// own empty row gives: an empty card under a heading is indistinguishable from one that has
    /// not loaded. It happens — `Venue.groupCount` has no floor above zero on this side of the
    /// wire, and a venue mid-setup can have none yet.
    private var emptyRow: some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            Text("This venue has no courts yet. Add some in Setup.")
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - The pool, and reading a block's courts back

extension BlockCourtPicker {

    /// Every court at `venueID`, in rank order — which is every court the venue has. See the
    /// header for why that is the maximum and why nothing here checks it.
    static func pool(in camp: Camp?, venueID: Venue.ID) -> [CourtGroup] {
        camp?.groups(in: venueID) ?? []
    }

    /// Who is standing on each of them, for the second half of a row's grey line.
    ///
    /// Through `Camp.coach(forGroup:)`, which is the camp's own answer to this and the spelling
    /// `SectionEightRepository` uses when it assembles the same fact for Overview's court cards.
    /// An earlier version walked `coaches(in:)` and reached into `assignment.groupID` by hand,
    /// which was a fourth way of asking a question the model already answers.
    static func coachNames(in camp: Camp?, venueID: Venue.ID) -> [Group.ID: String] {
        guard let camp else { return [:] }
        return camp.groups(in: venueID).reduce(into: [:]) { names, court in
            names[court.id] = camp.coach(forGroup: court.id)?.name
        }
    }

    /// `block.courtIDs` against the camp, in the venue's order rather than the block's.
    ///
    /// The mirror of `BlockAssigneeList.coaches(on:in:)`, with one deliberate difference: that one
    /// keeps the order the block names its people in, because "Nass & Alina" is a sentence the
    /// block composed. A list of courts is not — it is a set, and the order anybody reads it in is
    /// the venue's own. So this sorts by where each court sits rather than by where the block
    /// happened to list it.
    ///
    /// An id that resolves to nothing is dropped rather than force-resolved, for the same reason
    /// that one gives: a court deleted in Setup leaves its id on every block that named it.
    /// Postgres cascades that away on the next read; in the meantime an unresolved id is ordinary,
    /// not a bug.
    ///
    /// The *sentence* those courts make is `ScheduleBlock.courtLine(in:)`, on the model beside
    /// `coachLine(in:)`. Resolving is a question about a camp and belongs where the camp is;
    /// wording is a fact about a block and belongs on the block, reachable from outside SwiftUI.
    static func courts(on block: ScheduleBlock, in camp: Camp?) -> [CourtGroup] {
        guard let camp else { return [] }
        let named = Set(block.courtIDs)
        return camp.groups(in: block.venueID).filter { named.contains($0.id) }
    }
}

// MARK: - Previews

private struct BlockCourtPickerPreview: View {
    @State private var selection: Set<Group.ID>

    private let camp = SampleData.uclaTennisCamp
    private let courts: [CourtGroup]

    init(selected: Int, closingLast: Bool = false) {
        // Shut on the court itself rather than in a dictionary beside it, which is the whole of
        // what changed: a closed court is a `Group` carrying a reason, and the preview has to
        // build one the same way the camp graph hands one over.
        var courts = BlockCourtPicker.pool(in: SampleData.uclaTennisCamp, venueID: SampleData.sycamore.id)
        if closingLast, !courts.isEmpty {
            courts[courts.count - 1].closedReason = "Net down"
        }
        self.courts = courts
        _selection = State(initialValue: Set(courts.prefix(selected).map(\.id)))
    }

    var body: some View {
        BlockCourtPicker(
            courts: courts,
            selection: $selection,
            coachNames: BlockCourtPicker.coachNames(in: camp, venueID: SampleData.sycamore.id)
        )
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
    }
}

#Preview("Court picker — three courts on") {
    BlockCourtPickerPreview(selected: 3)
}

#Preview("Court picker — none yet") {
    BlockCourtPickerPreview(selected: 0)
}

/// The three readings of the grey line side by side: a court with a coach on it, one without —
/// amber, and still tappable — and the last one shut, drawn back but not disabled.
#Preview("Court picker — one closed") {
    BlockCourtPickerPreview(selected: 2, closingLast: true)
}

#Preview("Court picker — a venue with no courts") {
    BlockCourtPicker(courts: [], selection: .constant([]))
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}
