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

import SwiftUI

struct BlockCoachPicker: View {

    /// Everybody who could run this block. Handed in already resolved, the way
    /// `BlockAssigneeList` takes its people.
    let people: [StaffMember]
    @Binding var selection: Set<StaffMember.ID>

    @ScaledMetric(relativeTo: .body) private var avatarSize = ScheduleMetrics.assigneeAvatar
    @ScaledMetric(relativeTo: .body) private var checkSize = ScheduleMetrics.pickerCheck

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius) {
            if people.isEmpty {
                emptyRow
            } else {
                ForEach(people) { member in
                    row(member)
                }
            }
        }
    }

    private func row(_ member: StaffMember) -> some View {
        let isOn = selection.contains(member.id)

        return Button {
            selection.toggle(member.id)
        } label: {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                InitialsAvatar(member.initials, size: avatarSize)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(member.name)
                        .typeStyle(ScheduleType.assigneeName, color: Theme.ink)

                    // Allowed to wrap. "Worker · Sycamore · Court 3" is three segments long and
                    // truncating the last of them at an accessibility size hides the court, which
                    // is the part that says whether this is the right person for the block.
                    Text(member.detailLine)
                        .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.small)

                // An empty circle for the unpicked rows rather than nothing at all: a column of
                // ticks with gaps in it reads as a list where some rows have a state and others
                // do not, which is the opposite of what a multi-select is saying.
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkSize, weight: .regular))
                    .foregroundStyle(isOn ? Theme.accent : Theme.chevron)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isOn ? "Takes them off this block" : "Puts them on this block")
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
