//
//  BlockCoachPicker.swift
//  Sycamore
//
//  Who is running this block — the editor's answer to the third thing a block needs stating.
//
//  The pool is the same one `BlockDetailView` used to *display*: everybody posted to this block's
//  venue, plus the roamers who belong to no venue at all. That predicate was the right pool and
//  the wrong answer — it told you who was standing at the venue, which is the same list under
//  every block of the day, and then labelled it "Who is where". Offered as a *choice* it is
//  exactly right: these are the people who could plausibly run this block.
//
//  A `Card` of rows rather than a `Picker` with `.pickerStyle(.inline)`: this is multi-select, and
//  the design has an established row for a person — avatar, name, role — that it draws in Setup,
//  in the staff sheet and in the block's own logistics card. A picker would draw a fourth.
//
//  The "all coaches / no coaches" pair at the top is `BlockQuickActions`, shared with the court
//  picker below it — the two cards ask the same question about two kinds of thing, so they answer
//  the shortcut the same way. See that file for why it is a row of the card rather than a control
//  beside the heading.
//

import SwiftUI

struct BlockCoachPicker: View {

    /// Everybody who could run this block. Handed in already resolved, the way
    /// `BlockAssigneeList` takes its people.
    let people: [StaffMember]
    @Binding var selection: Set<StaffMember.ID>

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius) {
            if people.isEmpty {
                emptyRow
            } else {
                // Only over a pool worth shortcutting. On the empty card there is nothing to take
                // all of, and "All coaches" over no coaches is a button that cannot do anything.
                BlockQuickActions(
                    allTitle: "All coaches",
                    noneTitle: "No coaches",
                    onAll: { selection = Set(people.map(\.id)) },
                    onNone: { selection = [] }
                )

                ForEach(people) { member in
                    row(member)
                }
            }
        }
    }

    /// The avatar is what makes this row a person's rather than a court's — `BlockPickRow` draws
    /// one when it is given initials and nothing there when it is not.
    private func row(_ member: StaffMember) -> some View {
        let isOn = selection.contains(member.id)

        return BlockPickRow(
            title: member.name,
            detail: member.detailLine,
            isOn: isOn,
            initials: member.initials,
            hint: isOn ? "Takes them off this block" : "Puts them on this block"
        ) {
            selection.toggle(member.id)
        }
    }

    /// A venue with nobody posted to it. Drawn rather than left blank, because an empty card under
    /// a "Coaches" heading is indistinguishable from a card that has not loaded.
    private var emptyRow: some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            Text("Nobody is posted to this venue yet.")
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - The pool

extension BlockCoachPicker {

    /// Everybody who could run a block at `venueID`: the staff posted there, plus the roamers who
    /// belong to no venue at all, courts first and roamers last.
    ///
    /// Lifted verbatim out of `BlockDetailView.assignees`, which is where it was written and is no
    /// longer where it is needed — that screen now resolves the block's own `coachIDs`. The sort
    /// is the design's order for a list of people at a venue and is kept so the picker and the
    /// logistics card list the same names the same way round.
    static func pool(in camp: Camp?, venueID: Venue.ID) -> [StaffMember] {
        guard let camp else { return [] }
        return camp.staff
            .filter { $0.venueID == venueID || ($0.isRoaming && $0.venueID == nil) }
            .sorted { lhs, rhs in
                let left = lhs.assignment?.groupNumber ?? .max
                let right = rhs.assignment?.groupNumber ?? .max
                return left == right ? lhs.name < rhs.name : left < right
            }
    }
}

// MARK: - Previews

private struct BlockCoachPickerPreview: View {
    @State private var selection: Set<StaffMember.ID>

    init(selected: Int) {
        let staff = BlockCoachPicker.pool(in: SampleData.uclaTennisCamp, venueID: SampleData.sycamore.id)
        _selection = State(initialValue: Set(staff.prefix(selected).map(\.id)))
    }

    var body: some View {
        BlockCoachPicker(
            people: BlockCoachPicker.pool(in: SampleData.uclaTennisCamp, venueID: SampleData.sycamore.id),
            selection: $selection
        )
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
    }
}

#Preview("Coach picker — two on the block") {
    BlockCoachPickerPreview(selected: 2)
}

#Preview("Coach picker — nobody yet") {
    BlockCoachPickerPreview(selected: 0)
}
