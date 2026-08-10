//
//  CourtCoachPicker.swift
//  Sycamore
//
//  Who has this court — the sheet behind the `+` on an empty coach pill.
//
//  `assignStaff(_:toGroup:)` has existed since Setup was built and Overview could not reach it.
//  The only way to put a coach on a court was to open Setup, find the person, open their staff
//  sheet and tap a court chip — which is the write done backwards. On a camp morning the question
//  is "Court 3 has nobody, who can take it", and the screen that says so had no answer on it.
//
//  ── One tap, not a multi-select ──────────────────────────────────────────────────────────────
//
//  `BlockCoachPicker` is the app's other picker of people and it is a checklist, because a block
//  can be run by three of them. A court has one coach: `coaches.group_id` is a single column, and
//  `Camp.coach(forGroup:)` returns one person. So a row here is a commit, not a toggle, and the
//  sheet closes on it — a "Done" button over a single-select is a second tap to confirm a choice
//  that was already unambiguous.
//
//  ── Presented by its caller ──────────────────────────────────────────────────────────────────
//
//  No case is added to `ActiveSheet`; `OverviewScreen` holds its own `@State` and its own
//  `.sheet(item:)`. `BlockEditorSheet.swift:29-37` states the rule and `ScheduleView.swift:37-42`
//  states it again — two callers each owning their own state is simpler than one slot they take
//  turns in, and `ActiveSheet` lives in `AppStore.swift`, the file every feature merges.
//
//  ── The row below is `BlockCoachPicker`'s, and should not stay that way ───────────────────────
//
//  `row(_:courtLabel:me:)` draws the same person the same way `BlockCoachPicker.row` does — avatar,
//  name, detail line, trailing mark, the same 44pt frame and the same VoiceOver contract — and
//  `BlockAssigneeList` draws a third. The interaction argument above is about *what a tap does*
//  and does not reach the drawing, so this is duplication rather than divergence, and it has
//  already cost something: the two lists set the detail line at two different sizes until they
//  were held side by side (see `OverviewTheme.pickerMeta`).
//
//  What the two rows *say* is at least shared now. `BlockCoachPicker.rowTitle(for:me:)` and
//  `.rowDetail(for:)` spell "· you" and "· No court" once, beside the pool that decides who is on
//  the list at all, so the wording cannot drift even while the drawing still can.
//
//  It is written out here because the fix is a shared `StaffPickRow` beside `BlockCoachPicker`, or
//  in the design system, and both are folders this unit does not own. Three drawings of one row is
//  the point at which it stops being a coincidence.
//

import SwiftUI

/// The court a picker is open for.
///
/// A one-field wrapper because `.sheet(item:)` wants `Identifiable` and `Group.ID` is a bare
/// `UUID`. Deliberately carries the id and not the `CourtCard`, which is the choice
/// `PushedScreen.court` records: a card is a row of `today_courts` that the store re-reads, and a
/// copy parked in presentation state draws a coach name and a head-count from whenever the sheet
/// happened to be opened.
struct CourtCoachRequest: Identifiable, Hashable, Sendable {
    let id: Group.ID
}

struct CourtCoachPicker: View {

    let store: AppStore
    let courtID: Group.ID
    /// How the sheet gets out of the way: it clears the state the caller is holding. The same
    /// shape `BlockEditorSheet` and `EarlyPickupSheet` take, and for the same reason — the caller
    /// owns the state, so the caller is the only one who can put it down.
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize = OverviewTheme.pickerAvatar
    @ScaledMetric(relativeTo: .body) private var markSize = OverviewTheme.pickerMark

    var body: some View {
        // All three resolved once and used from there. `SheetChrome` builds its content eagerly, so
        // a computed `pool` would be read twice in one pass — a filter and a sort of the venue's
        // whole staff list, twice — and `courtLabel` walks every group in the camp, once per row.
        // `me` joins them for the same reason and a sharper one: it is wanted by the pool *and* by
        // every row, and `myStaffRecord` is itself a walk of `camp.staff`.
        let me = myID
        let pool = self.pool(me: me)
        let courtLabel = self.courtLabel

        return SheetChrome(
            title: "Who has \(courtLabel)?",
            // Said out loud, because it is the part of this write nobody expects. A coach belongs
            // to one court at a time — `assignStaff` moves them rather than copying them — so
            // picking somebody who is already on Court 2 empties Court 2. Each row's own detail
            // line names the court they are on, which is what makes the sentence checkable rather
            // than just a warning.
            subtitle: "They come off whichever court they are on now.",
            detentFraction: OverviewTheme.coachPickerDetent,
            onClose: onClose
        ) {
            if pool.isEmpty {
                emptyCard
            } else {
                Card(radius: OverviewTheme.cardRadius) {
                    ForEach(pool) { member in
                        row(member, courtLabel: courtLabel, me: me)
                    }
                }
            }
        }
    }

    // MARK: The people

    /// Everybody who could take this court: the staff posted to its venue, the roamers who belong
    /// to no venue at all, every admin in the camp, and you.
    ///
    /// `BlockCoachPicker.pool(in:venueID:me:)` rather than a predicate of our own. It is the same
    /// question — who could plausibly be put on something at this venue — asked by the app's other
    /// people-picker, and its header records that the sort is "the design's order for a list of
    /// people at a venue". A second copy here would be a second answer to drift from the first, and
    /// the drift would be invisible: both lists look like lists of coaches.
    ///
    /// **Sharing it paid for itself.** "An admin can put themselves on a court" was asked for
    /// separately from "an admin can put themselves on a block", and it arrived here for nothing
    /// the day the pool learned about roles: an admin with no court is now in this list, and so is
    /// the person reading it, at the top. The `me:` argument is the whole of what this file had to
    /// add. Had the predicate been copied, this sheet would still be listing the same six coaches
    /// it always did and nobody would have noticed until somebody tried.
    private func pool(me: StaffMember.ID?) -> [StaffMember] {
        guard let venueID = store.group(courtID)?.venueID ?? store.readVenueID else { return [] }
        return BlockCoachPicker.pool(in: store.camp, venueID: venueID, me: me)
    }

    /// The signed-in person's own staff row, for the "· you" on their row and the sort that lifts
    /// it. Nil for an admin with no staff record in this camp.
    private var myID: StaffMember.ID? { store.myStaffRecord?.id }

    /// "Court 3". Resolved from the graph once per pass rather than handed in, so a court renamed in
    /// camp settings while this is open retitles instead of lying — freshness needs the lookup to
    /// happen per pass, not per row, which is why `body` binds it and every row is given the result.
    private var courtLabel: String { store.group(courtID)?.label ?? "this court" }

    private func row(_ member: StaffMember, courtLabel: String, me: StaffMember.ID?) -> some View {
        let isOn = member.groupID == courtID

        return Button {
            assign(member.id)
        } label: {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                InitialsAvatar(member.initials, size: avatarSize)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    // `Nass · you` on your own row, spelled by the pool so this sheet and the
                    // block editor cannot word it two ways — see `BlockCoachPicker.rowTitle`.
                    Text(BlockCoachPicker.rowTitle(for: member, me: me))
                        .typeStyle(.rowTitleSm, color: Theme.ink)

                    // Allowed to wrap. "Worker · Sycamore · Court 3" truncated at an accessibility
                    // size loses the court, which is the segment that says whether taking this
                    // person empties another court — the exact thing the subtitle above warns about.
                    Text(BlockCoachPicker.rowDetail(for: member))
                        .typeStyle(OverviewTheme.pickerMeta, color: Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.small)

                // Only the person already on this court gets a mark, and the rest get nothing.
                // Deliberately not `BlockCoachPicker`'s empty circles: those say "tick as many as
                // you like", and this list commits on the first tap. A tick here is a statement
                // about the court, not an unchecked box.
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: markSize, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
            }
            // Grown first, shaped second. `CardRow` sets a `contentShape` of its own, pinned to the
            // plate it draws; restating it out here after the frame is what carries the target out
            // to the grown region rather than leaving it on the drawn one.
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        // "Puts you on Court 3" on your own row, for the reason `BlockCoachPicker.hint` gives: the
        // label above it now ends in "· you", and taking a court yourself is what this sheet was
        // widened to allow.
        .accessibilityHint(
            isOn ? "Already on \(courtLabel)"
                 : "Puts \(member.id == me ? "you" : "them") on \(courtLabel)"
        )
    }

    /// A camp with nobody in it to offer. Drawn rather than left blank, because an empty sheet is
    /// indistinguishable from one that has not loaded — the argument `BlockCoachPicker.emptyRow`
    /// makes about its own card, whose rewritten sentence this one now matches: the pool carries
    /// every admin and your own row, so "nobody is posted to this venue" is no longer what an empty
    /// list means.
    private var emptyCard: some View {
        Card(radius: OverviewTheme.cardRadius, isDivided: false) {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                Text("There is nobody to put on this court yet. Add staff in camp settings and they show up here.")
                    .typeStyle(OverviewTheme.cardSubtitle, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: The write

    /// Assign, and let the store re-read the courts.
    ///
    /// **The re-read is not optional, and it is no longer this file's to make.** `assignStaff`
    /// answers with the camp graph, and a court card's `coachName` does not come from the graph —
    /// it is a column of `today_courts`, which `SectionEightRepository.courts(forVenue:campID:)`
    /// derives from `camp.coach(forGroup:)` at read time. Without it the write lands, the sheet
    /// closes, and the pill goes on saying "Needs a coach" until something else reloads the tab.
    ///
    /// This sheet used to make that second call by hand, over a comment arguing at length that the
    /// pair belonged inside `AppStore.assignStaff` instead — one write with two behaviours
    /// depending on which screen invoked it, `StaffSheet.swift:141` and `:151` being the two that
    /// forgot. It has since moved there, which is why there is one call below. `StaffSheet`'s
    /// callers get the re-read now, and a fourth caller cannot be written without it. The old
    /// warning against "simplifying the second call away" is kept only in this sentence, because
    /// the call it was guarding no longer exists and a reader was left hunting for it.
    ///
    /// Closed before the write rather than after it. A sheet that sits open through a round trip
    /// with nothing moving on it reads as a tap that missed; and if the write is refused, the
    /// banner belongs over the tab — `perform` owns `errorMessage` and `MainTabView` floats it —
    /// not inside a sheet that would then be the only thing on screen still claiming a coach was
    /// being picked.
    private func assign(_ staffID: StaffMember.ID) {
        onClose()
        Task { await store.assignStaff(staffID, toGroup: courtID) }
    }
}

// MARK: - Previews

#Preview("Who has this court") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        CourtCoachPicker(
            store: OverviewFixtures.adminStore,
            courtID: OverviewFixtures.unassigned.id,
            onClose: {}
        )
        .frame(height: 512)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

/// A court that already has somebody, which is what the sheet looks like when it is opened from a
/// pill that has since been filled in by another device.
#Preview("Who has this court — already taken") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        CourtCoachPicker(
            store: OverviewFixtures.adminStore,
            courtID: OverviewFixtures.drills.id,
            onClose: {}
        )
        .frame(height: 512)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
