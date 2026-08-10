//
//  BlockCourtCard.swift
//  Sycamore
//
//  One court of one block, on `5d` — its name, how many kids are on it, and who is running it.
//
//  ── What this card used to be ────────────────────────────────────────────────────────────────
//
//  The green "Your court" plate at the top of `8l`: the block read from the point of view of the
//  one court the signed-in person happened to be posted to, with an "Open" badge and the block's
//  pinned note under it. Its argument was that "which court you are standing on and how many kids
//  are in front of you is the camp's answer, not the schedule's" — which was true, and answered a
//  question `5d` no longer asks. A block runs on three courts and each of them has a different
//  coach; a screen that showed one of the three because of where the *reader* stands could not say
//  whether the block was covered. So the card is now drawn once per court, in the venue's order,
//  and nobody's own posting decides which.
//
//  The "Open" badge went with it. Court status is Overview's write (`setCourtStatus`) and nothing
//  on this screen owns it — it was a badge reporting a fact from another tab, and `5d` does not
//  draw one. The pinned note went too: `ScheduleBlockCard` still pins `notes.first` on the day
//  list, and `BlockNotesCard` holds the rest under this card, so the note had two homes on one
//  screen and this was the redundant one.
//
//  ── The block that has no courts ─────────────────────────────────────────────────────────────
//
//  `court` is optional and nil is not a degenerate case. A `.regular` block — a lunch, a
//  drop-off — names no courts because it happens on none of them in particular, and `5d` drawn
//  strictly per court would say nothing at all about who is running one. The same card with the
//  same shape then asks the block-wide question, which is exactly the fork
//  `BlockCourtStaffingSheet` takes on its own `courtID`.
//

import SwiftUI

struct BlockCourtCard: View {

    /// The court this card is about, or nil for the block as a whole.
    let court: CourtGroup?
    /// Who is on it, resolved. `ScheduleBlock.coachIDs(onCourt:)` is what produces the list and it
    /// carries a fallback worth knowing about here: a court with no staffing entry of its own is
    /// staffed by whoever runs the block, so two courts of an unstaffed-per-court block draw the
    /// same name. That is the honest reading — a block staffed as a whole is staffed on each court
    /// it claims — and not a bug in this card.
    let coaches: [StaffMember]
    /// Opens `4d` on this court. Nil for somebody who cannot write the camp's schedule, in which
    /// case an empty court states the fact in its head row and offers nothing, rather than drawing
    /// a control the database would refuse. `ProfileView` locks its admin rows the same way; the
    /// gate that counts is `adminWrite` around `updateScheduleBlock`.
    var onStaff: (() -> Void)?

    /// The 26pt disc `CourtCoachLine` draws, reached across for rather than restated — the size is
    /// a fact about that row and this card only needs to know it to lay a `Reassign` out beside it.
    @ScaledMetric(relativeTo: .footnote) private var avatarSize = OverviewTheme.courtCoachAvatar

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius, isDivided: false) {
            // The `10` gap belongs to the stack rather than to the coach row, because the coach
            // row is sometimes not there at all — a court a reader can see is short and cannot fix
            // draws its head and nothing else. As a `.padding(.top:)` on an absent view that gap
            // would still take its ten points and leave the card sitting on a strip of white.
            VStack(alignment: .leading, spacing: ScheduleMetrics.rowGap) {
                headRow
                coachLines
            }
            .padding(ScheduleMetrics.cardPadding)
        }
    }

    // MARK: The head

    /// `Court 1` and `8 kids`, or `Court 2` and `Needs a coach` in amber.
    ///
    /// A flat label rather than the tracked uppercase overline this screen used to head its
    /// sections with. `5d` distils five section headers into flat labels, and the house rule is
    /// that no new screen introduces tracked caps.
    private var headRow: some View {
        HStack(spacing: ScheduleMetrics.rowGap) {
            Text(label)
                .typeStyle(.metaStrong.tracking(em: -0.01), color: Theme.inkTertiary)

            Spacer(minLength: Spacing.small)

            if let meta {
                Text(meta)
                    .typeStyle(.rowDetail, color: coaches.isEmpty ? Theme.warning : Theme.inkFaint)
                    .layoutPriority(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var label: String { court?.label ?? "On this block" }

    /// The head row's right-hand fact: the head-count on a staffed court, the amber gap on an
    /// empty one, and **nothing** on a staffed block-wide card.
    ///
    /// Nothing, rather than a number, because there is no honest one. `Group.presentCount` is a
    /// court's register and a block that names no courts is not a court — the venue's total would
    /// be a different quantity wearing the same words. The segment is dropped whole, which is the
    /// rule `CoachAvailability.subtitle` states for the grey line and the same rule applies to a
    /// card's head: never print the shape of a fact you do not have.
    private var meta: String? {
        if coaches.isEmpty { return CoachPill.needsACoach }
        guard let court else { return nil }
        let kids = court.presentCount
        return "\(kids) kid\(kids == 1 ? "" : "s")"
    }

    // MARK: The coaches

    /// A face and a first name per coach, and `Add a coach` when there are none.
    ///
    /// `CourtCoachLine` rather than a fourth drawing of a coach row. That view is `8i`'s and it
    /// already draws both halves of what `5d` asks for — a 26pt disc with a first name beside it,
    /// and a dashed disc with the accent invitation `Add a coach` — down to the words. Its own
    /// header names the seam this exercises: "if a third coach row appears, the preset is right".
    /// This is a second *caller*, not a third drawing, so the paragraph still holds.
    ///
    /// The line is inert and `Reassign` beside it is the control, where that view's own callers
    /// make the whole line a button onto a staff card. `5d`'s tap does something else — it opens
    /// the picker for this court — and a line that opened a profile with a `Reassign` sitting on it
    /// would be two destinations one gesture apart.
    @ViewBuilder
    private var coachLines: some View {
        if coaches.isEmpty {
            // Nothing at all for a reader who cannot fix it. The head row above has already said
            // "Needs a coach" in amber; a faint second copy under it would be the same sentence
            // twice, and an invitation nobody can accept is worse than either.
            if onStaff != nil {
                CourtCoachLine(name: nil, action: onStaff)
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                ForEach(Array(coaches.enumerated()), id: \.element.id) { index, coach in
                    HStack(spacing: Spacing.small) {
                        CourtCoachLine(name: coach.name)

                        // One `Reassign` per card, on the first line. The control is about the
                        // *court* and not the person — `4d` writes the court's whole list — so one
                        // per name would be three buttons doing one thing. The first line is where
                        // the design draws it, on the only card it drew with a coach on it.
                        if index == 0, let onStaff {
                            reassign(onStaff)
                        }
                    }
                }
            }
        }
    }

    /// `Reassign`, in the accent, at the size `5d` writes inline actions
    /// (`design/rebuild/section-t5.html:200`).
    ///
    /// Grown first, shaped second. The word is about 13pt tall and the frame around it reaches 44;
    /// stating the shape before the frame pins the target to the drawn glyph, which is the order
    /// `BlockPickRow.swift:106-109` records as load-bearing.
    private func reassign(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Reassign")
                .typeStyle(ScheduleType.inlineAction, color: Theme.accent)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // The drawn word is the design's; the spoken one carries the object, the way `4d`'s
        // `Assign` does. "Reassign" read out after a court's name and a coach's is a verb with
        // nothing attached to it.
        .accessibilityLabel("Reassign \(label)")
        .accessibilityHint("Chooses who runs it")
    }
}

// MARK: - Resolving one court's coaches

extension BlockCourtCard {

    /// `block.coachIDs(onCourt:)` resolved against `camp.staff`, in the order the block names them
    /// — and `BlockAssigneeList.coaches(on:in:)` verbatim when no court was named.
    ///
    /// Written as a fork onto that function rather than as a second `compactMap` of its own,
    /// because the block-wide answer is *its* rule and there is no version of this screen where
    /// the two should differ about a lunch. What is left here is the one thing this reader adds:
    /// the court, and with it the fallback argued at `SectionEight.swift:293-318` — a court with no
    /// staffing entry of its own is staffed by whoever runs the block.
    ///
    /// `compactMap`, never `first(where:)!`, on both arms. "Remove from camp" deactivates rather
    /// than deletes, so an id on a block outlives the person's presence in `camp.staff` — that row
    /// is a fact about last Tuesday, not a dangling pointer, and it drops out of the card rather
    /// than taking the screen with it.
    ///
    /// `nonisolated` for `BlockCoachPicker.pool`'s reason (`:170-175`): a `View` is `@MainActor` by
    /// inference under Swift 6 and its statics come with it, which would make this unreadable from
    /// a test — where the fallback above is actually specified. A `Camp` and a `ScheduleBlock` are
    /// both `Sendable` and none of this touches view state, so there is nothing for the isolation
    /// to protect.
    nonisolated static func coaches(
        on block: ScheduleBlock, court: Group.ID?, in camp: Camp?
    ) -> [StaffMember] {
        guard let camp else { return [] }
        guard let court else { return BlockAssigneeList.coaches(on: block, in: camp) }
        return block.coachIDs(onCourt: court).compactMap { id in camp.staff.first { $0.id == id } }
    }
}

// MARK: - Previews

private struct BlockCourtCardPreview: View {
    var body: some View {
        let camp = SampleData.uclaTennisCamp
        let block = ScheduleSampleDay.blocks(
            venueID: SampleData.sycamore.id, coachIDs: [SampleData.nass.id]
        )[1]
        let courts = BlockCourtPicker.courts(on: block, in: camp)

        return VStack(spacing: ScheduleMetrics.blockGap) {
            // Staffed, from the block-wide fallback — the state every block written before
            // per-court staffing existed is in.
            BlockCourtCard(
                court: courts.first,
                coaches: BlockCourtCard.coaches(on: block, court: courts.first?.id, in: camp),
                onStaff: {}
            )

            // A court somebody has opened `4d` on and left without picking: an entry that exists
            // and is empty, which is the one state that means "this is somebody's problem".
            BlockCourtCard(court: courts.dropFirst().first, coaches: [], onStaff: {})

            // The same gap for a coach, who can read it and cannot fix it.
            BlockCourtCard(court: courts.dropFirst().first, coaches: [])

            // The block that names no courts.
            BlockCourtCard(
                court: nil,
                coaches: BlockCourtCard.coaches(on: block, court: nil, in: camp),
                onStaff: {}
            )
        }
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
    }
}

#Preview("A block's courts") {
    BlockCourtCardPreview()
}
