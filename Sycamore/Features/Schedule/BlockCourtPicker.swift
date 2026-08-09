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
    /// Who is standing on each court, for the second half of a row's grey line.
    ///
    /// Handed in already resolved, like `BlockCoachPicker`'s people, so the one call into the camp
    /// graph is the sheet's — see `coachNames(in:venueID:)`. A `Camp` on this view instead would
    /// put graph-walking inside a `body` that re-runs on every keystroke in the title field.
    var coachNames: [Group.ID: String] = [:]

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

        return BlockPickRow(
            title: court.label,
            detail: headcount(court),
            isOn: isOn,
            hint: isOn ? "Takes this block off the court" : "Puts this block on the court"
        ) {
            selection.toggle(court.id)
        }
    }

    /// `8 kids`, and `8 kids · Nass` once somebody is standing on it.
    ///
    /// `playerCount` rather than `presentCount`: this is a timetable being written, possibly for
    /// Thursday, and who happens to be away today is not a fact about which courts a block should
    /// use. `Group.headcountLine` is the other reading — "Court 1 · 8 here" — and belongs to the
    /// screens that are about today.
    private func headcount(_ court: CourtGroup) -> String {
        let kids = "\(court.playerCount) kid\(court.playerCount == 1 ? "" : "s")"
        guard let coach = coachNames[court.id] else { return kids }
        return "\(kids) · \(coach)"
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

    init(selected: Int) {
        let courts = BlockCourtPicker.pool(in: SampleData.uclaTennisCamp, venueID: SampleData.sycamore.id)
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

#Preview("Court picker — a venue with no courts") {
    BlockCourtPicker(courts: [], selection: .constant([]))
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}
