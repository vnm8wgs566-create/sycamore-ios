//
//  BlockAssigneeList.swift
//  Sycamore
//
//  "Logistics" on `8l` — when this block runs, where it runs, and who is running it.
//
//  This card used to be headed "Who is where", and its people were `camp.staff` filtered by
//  *venue*. The comment that justified it said "who is on which court is the camp's answer, not
//  the schedule's, and the two would drift the moment somebody was reassigned" — which is true of
//  court occupancy and false of who runs a block. Filtered by venue, every block of the day listed
//  the same names, so the card could not answer the only question anybody opens it with: is this
//  one covered?
//
//  So the people are now `block.coachIDs` resolved against `camp.staff`. The venue predicate has
//  not been thrown away — it is the *pool* the editor's `BlockCoachPicker` offers, which is what it
//  was always right about.
//
//  Resolved with `compactMap` and never force-unwrapped. `removeStaff` deactivates rather than
//  deletes, so a coach who has left the camp keeps their assignment row and their id stops
//  resolving — a `!` here would crash `8l` for every block they were ever put on.
//

import SwiftUI

struct BlockAssigneeList: View {

    /// When and where — `Tuesday`, `9:00am – 10:30am`, `Sycamore`. Passed in already spelled so
    /// this card and the header above it cannot write the same block's hours two ways.
    let day: Weekday
    let timeLabel: String
    let venueName: String?
    /// Who is running the block, resolved. See `coaches(on:in:)`.
    let people: [StaffMember]
    /// The signed-in person, so their row can say "· you". Nil for somebody with no staff record
    /// in this camp, which is an admin looking at a venue they do not work at.
    let myID: StaffMember.ID?
    /// Opens the editor on the coaches. Nil for somebody who cannot write the camp's schedule, and
    /// for the previews below — in which case the empty row states the fact and offers nothing,
    /// rather than drawing a disabled button. `ProfileView` locks its admin rows the same way.
    var onAssign: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var avatarSize = ScheduleMetrics.assigneeAvatar

    var body: some View {
        VStack(alignment: .leading, spacing: ScheduleMetrics.blockGap) {
            // Not `SectionHeader`: section 8 sets its overlines at `600 10.5 / +.14em` where the
            // shared one is `700 11 / +.1em`, and hangs them 6 under the card above rather than
            // 9 over the card below.
            Text("Logistics")
                .typeStyle(ScheduleType.overline, color: Theme.inkMuted)
                .padding(.horizontal, ScheduleMetrics.rowInset)
                .padding(.top, ScheduleMetrics.overlineTop)
                .accessibilityAddTraits(.isHeader)

            Card(radius: ScheduleMetrics.cardRadius) {
                factRow("When", value: "\(day.fullName) · \(timeLabel)")

                if let venueName {
                    factRow("Where", value: venueName)
                }

                if people.isEmpty {
                    nobodyRow
                } else {
                    ForEach(people) { member in
                        row(member)
                    }
                }
            }
        }
    }

    // MARK: When and where

    /// A label and its value on one line — the shape `VenueSheet`'s limits card draws, without the
    /// second grey line, because "When" needs no explaining.
    private func factRow(_ label: String, value: String) -> some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            Text(label)
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)

            Spacer(minLength: Spacing.small)

            Text(value)
                .typeStyle(ScheduleType.assigneeName, color: Theme.ink)
                .multilineTextAlignment(.trailing)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Who

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
            .typeStyleRun(ScheduleType.assigneeName.weight(.regular), color: Theme.accent)
        return Text("\(member.name)\(you)")
    }

    /// A row, not a hidden section.
    ///
    /// The card used to disappear when it had nobody in it, which was right while empty meant "no
    /// staff at this venue" — an absence nobody could act on. It now means "nobody is covering
    /// this", which is the single most actionable thing `8l` can say, and hiding it is how a block
    /// goes uncovered quietly. `ScheduleBlockStatus.needsCoach` has been drawing that fact in
    /// amber on `8k` with nowhere to act on it; this is the place.
    private var nobodyRow: some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            Text("Nobody assigned")
                .typeStyle(ScheduleType.assigneeName, color: Theme.warning)

            Spacer(minLength: Spacing.small)

            if let onAssign {
                Button(action: onAssign) {
                    Text("Assign")
                        .typeStyle(ScheduleType.inlineAction, color: Theme.accent)
                        // The word is about 13pt tall; only the frame around it reaches 44.
                        .frame(minHeight: HitTarget.minimum)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the block editor on its coaches")
            }
        }
    }
}

// MARK: - Resolving the block's coaches

extension BlockAssigneeList {

    /// `block.coachIDs` against `camp.staff`, in the order the block names them.
    ///
    /// `compactMap`, never `first(where:)!`. `removeStaff` deactivates rather than deletes, so an
    /// id on a block can outlive the person's presence in `camp.staff` — that row is a fact about
    /// last Tuesday, not a dangling pointer, and it drops out of the list rather than taking the
    /// screen with it.
    static func coaches(on block: ScheduleBlock, in camp: Camp?) -> [StaffMember] {
        guard let camp else { return [] }
        return block.coachIDs.compactMap { id in camp.staff.first { $0.id == id } }
    }
}

// MARK: - Previews

private struct BlockLogisticsPreview: View {
    var coachIDs: [StaffMember.ID]

    var body: some View {
        let camp = SampleData.uclaTennisCamp
        let block = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id, coachIDs: coachIDs)[1]

        return BlockAssigneeList(
            day: block.day,
            timeLabel: block.timeLabel,
            venueName: camp.venue(block.venueID)?.name,
            people: BlockAssigneeList.coaches(on: block, in: camp),
            myID: SampleData.alexStaff.id,
            onAssign: {}
        )
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
    }
}

#Preview("Logistics — two coaches on it") {
    BlockLogisticsPreview(coachIDs: [SampleData.nass.id, SampleData.alexStaff.id])
}

#Preview("Logistics — nobody assigned") {
    BlockLogisticsPreview(coachIDs: [])
}
