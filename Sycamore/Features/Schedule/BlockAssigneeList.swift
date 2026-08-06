//
//  BlockAssigneeList.swift
//  Sycamore
//
//  "Who is where" on `8l` — everyone standing at this block's venue, courts first and roamers
//  last.
//
//  Read out of the camp graph rather than off the block, and handed in already resolved.
//  `ScheduleBlock` carries a title, a time and its notes; who is on which court is the camp's
//  answer, not the schedule's, and the two would drift the moment somebody was reassigned.
//

import SwiftUI

struct BlockAssigneeList: View {

    let people: [StaffMember]
    /// The signed-in person, so their row can say "· you". Nil for somebody with no staff record
    /// in this camp, which is an admin looking at a venue they do not work at.
    let myID: StaffMember.ID?

    @ScaledMetric(relativeTo: .body) private var avatarSize = ScheduleMetrics.assigneeAvatar

    var body: some View {
        VStack(alignment: .leading, spacing: ScheduleMetrics.blockGap) {
            // Not `SectionHeader`: section 8 sets its overlines at `600 10.5 / +.14em` where the
            // shared one is `700 11 / +.1em`, and hangs them 6 under the card above rather than
            // 9 over the card below.
            Text("Who is where")
                .typeStyle(ScheduleType.overline, color: Theme.inkMuted)
                .padding(.horizontal, ScheduleMetrics.rowInset)
                .padding(.top, ScheduleMetrics.overlineTop)
                .accessibilityAddTraits(.isHeader)

            Card(radius: ScheduleMetrics.cardRadius) {
                ForEach(people) { member in
                    row(member)
                }
            }
        }
    }

    private func row(_ member: StaffMember) -> some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            InitialsAvatar(member.initials, size: avatarSize)
                .accessibilityHidden(true)

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

    /// `Nass · you`, with the qualifier in the accent at the name's own size and a lighter
    /// weight — interpolated as one `Text` rather than joined with `+`, which is the house rule
    /// in `Typography.swift`.
    private func name(for member: StaffMember) -> Text {
        guard member.id == myID else { return Text(member.name) }
        let you = Text(" · you")
            .typeStyle(ScheduleType.assigneeName.weight(.regular), color: Theme.accent)
        return Text("\(member.name)\(you)")
    }
}

// MARK: - Previews

#Preview("Who is where") {
    let staff = SampleData.uclaTennisCamp.staff

    return BlockAssigneeList(people: staff, myID: staff.first?.id)
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}
