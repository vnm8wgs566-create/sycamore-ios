//
//  BlockCoachPicker.swift
//  Sycamore
//
//  Who is running this block — the editor's answer to the third thing a block needs stating.
//
//  The pool began as the one `BlockDetailView` used to *display*: everybody posted to this block's
//  venue, plus the roamers who belong to no venue at all. That predicate was the right pool and
//  the wrong answer — it told you who was standing at the venue, which is the same list under
//  every block of the day, and then labelled it "Who is where". Offered as a *choice* it was
//  nearly right: these are the people who could plausibly run this block.
//
//  Nearly, because it asked only *where somebody stands* and never *who they are*. See
//  `pool(in:venueID:me:)` for the two people it left out and why they had to be let in.
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
    /// The signed-in person, so their row can say "· you" and sit at the top. Nil for somebody with
    /// no staff record in this camp — the same contract, and the same name, as
    /// `BlockAssigneeList.myID`, because the two lists are read minutes apart.
    ///
    /// `let` rather than a defaulted `var`, which is the difference between a caller who forgets
    /// and a caller who cannot compile. It must be the *same* id `people` was sorted with: the pool
    /// lifts your row to the top and this writes the suffix on it, so two answers would label the
    /// wrong row.
    let myID: StaffMember.ID?

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
            title: Self.rowTitle(for: member, me: myID),
            detail: Self.rowDetail(for: member),
            isOn: isOn,
            initials: member.initials,
            hint: hint(member, isOn: isOn)
        ) {
            selection.toggle(member.id)
        }
    }

    /// `Puts them on this block`, and `Puts you on this block` on your own row.
    ///
    /// Worth the pronoun. The row's label now ends in "· you", so a hint that went on saying "them"
    /// would be VoiceOver naming the reader and then talking about them in the third person in the
    /// same breath — and putting yourself on a block is the thing this list was widened to allow,
    /// so it is the row most likely to be reached with the screen reader on.
    ///
    /// Four literals rather than one sentence with the pronoun interpolated into it. `BlockPickRow`
    /// takes a plain `String`, so this is built eagerly for every row on every pass, and this
    /// picker is redrawn on every keystroke in the editor's title field — where a literal costs
    /// nothing an interpolation is an allocation per row, on the one body this codebase flags as
    /// hot (`BlockCourtPicker.swift:36-38`). The word only differs on one row out of fourteen.
    ///
    /// And deliberately not a shared `pronoun(for:me:)` beside `rowTitle` and `rowDetail`, which is
    /// where the two other shared strings went. Those two are the *same* line drawn by two screens
    /// and would be a bug if they diverged. This is two different sentences — "on this block" here,
    /// "on Court 3" in `CourtCoachPicker` — that happen to share one word, and hoisting a word is
    /// how a sentence ends up assembled from parts nobody can read.
    private func hint(_ member: StaffMember, isOn: Bool) -> String {
        guard member.id == myID else {
            return isOn ? "Takes them off this block" : "Puts them on this block"
        }
        return isOn ? "Takes you off this block" : "Puts you on this block"
    }

    /// A camp with nobody in it to offer. Drawn rather than left blank, because an empty card under
    /// a "Coaches" heading is indistinguishable from a card that has not loaded.
    ///
    /// It used to read "Nobody is posted to this venue yet", which was true of the old pool and is
    /// now both unlikely and wrong: the pool carries every admin in the camp and your own record
    /// whether or not anybody has posted you anywhere, so reaching this row means the camp has no
    /// admin, no roamer, nobody at this venue *and* no row for the person reading. That is a camp
    /// with no staff, and the sentence says so — and says where staff come from, which is the half
    /// the old one left out.
    private var emptyRow: some View {
        CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
            Text("There is nobody to put on this block yet. Add staff in camp settings.")
                .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - The pool

/// All three are `nonisolated`, and the reason is `CoachPill.needsACoach`'s (`:43-47`): a `View` is
/// `@MainActor` by inference under Swift 6 and its statics come with it, which would make these
/// three unreadable from anywhere that is not a view — including a test, which is where the
/// permission below is actually specified. A `Camp` and a `StaffMember` are `Sendable` and none of
/// this touches view state, so there is nothing for the isolation to protect. Left as it was, a
/// test calling `pool` compiled with a warning and then trapped on the executor check at run time.
///
/// ── That keyword is an argument for moving all three out ──────────────────────────────────────
///
/// Paying a keyword and a paragraph to shed an isolation the logic never wanted is the sign that
/// it is filed under the wrong noun. `pool` is a permission — the test file below says so in as
/// many words, "the specification of a permission the screens have no other statement of" — and a
/// permission named after the card that happens to draw it is exactly what `BlockRules`,
/// `PlayerRules` and `ScheduleConflicts` exist not to be. `GroupsLandingPlan` and
/// `RosterReconciliation` were both lifted out of a `@MainActor` view under the same pressure, and
/// each records the lift in its own header. A `Sendable` `CoachPool` beside `ScheduleConflicts`
/// is the shape.
///
/// Not done here, for two reasons rather than none. `BlockCourtPicker.pool`,
/// `BlockCourtPicker.courts(on:in:)` and `BlockAssigneeList.coaches(on:in:)` are View-statics of
/// exactly this kind sitting in this same folder, so moving one of four is a new inconsistency
/// bought with the old one — they go together or not at all. And `CourtCoachPicker` was already
/// reaching across the folder for this function before it was widened, so the cross-feature call
/// is not what this change introduced; only the keyword is.
extension BlockCoachPicker {

    /// Everybody who could run a block at `venueID`: the staff posted there, the roamers who belong
    /// to no venue at all, **every admin in the camp**, and **you** — yourself first, then courts in
    /// order, then roamers and the unposted.
    ///
    /// ── The two the venue predicate left out ─────────────────────────────────────────────────
    ///
    /// The filter was `venueID == venueID || (isRoaming && venueID == nil)`, lifted out of
    /// `BlockDetailView.assignees`. It asks only where somebody *stands*, and `StaffMember.venueID`
    /// is `assignment?.venueID` (`Models.swift:674`) — so role never entered into it. Two people
    /// fell through:
    ///
    /// 1. **An admin nobody has put on a court.** `Role.roamsByDefault` is trainer-only
    ///    (`Models.swift:320`), so a fresh admin has `venueID == nil` and `isRoaming == false` and
    ///    matched neither arm. That is not a rare shape: `adoptStaffRow`
    ///    (`SupabaseRepository+Enrolment.swift:44-73`) mints every new member's `coaches` row with
    ///    `site_id` and `group_id` NULL, admins included. So the person who set the camp up was
    ///    invisible in the picker until somebody else posted them somewhere — and the somebody else
    ///    was usually them.
    /// 2. **The person reading.** They appeared only by satisfying the same positional test as
    ///    everybody else, which is how "put me on this" became the one assignment the screen could
    ///    not make.
    ///
    /// ── Camp-wide for admins, and the database agrees ────────────────────────────────────────
    ///
    /// An admin is offered at *every* venue rather than at the one they happen to stand on, because
    /// an admin is a fact about the camp where a court is a fact about a morning. This is a
    /// client-side widening only — no migration went with it, and none was needed:
    /// `private.coach_ids_for_caller()` (`20260806013152_real_rls.sql:176-188`) is joined on
    /// `memberships.camp_id` rather than on a site, and `schedule_block_coaches_member`
    /// (`20260808201645_pins_block_coaches_and_notes.sql:332-342`) is member-writable by a decision
    /// its own comment argues at length. Both halves of that policy still hold for every row this
    /// pool can now produce: the coach is in the caller's camp, and the block is one of the
    /// caller's. Nothing here can name a stranger, because nothing here looks outside `camp.staff`.
    ///
    /// ── Deliberately not every unposted worker ───────────────────────────────────────────────
    ///
    /// Yusuf in `SampleData` is a worker with no court, and he stays out. The widening is by *role*
    /// and not by absence: an admin belongs to the camp, so every venue in it is theirs, where a
    /// worker nobody has posted anywhere is a person whose venue is genuinely unknown — offering
    /// them under both venues of a two-venue camp would be the app guessing. Post them and they
    /// appear, which is what Setup is for. Your own row is the one exception, and it is not an
    /// exception to the rule so much as the answer to a different question: you know where you are.
    ///
    /// The sort is the design's order for a list of people at a venue, kept so this picker and the
    /// logistics card on `8l` list the same names the same way round — with yourself lifted to the
    /// top, because the row somebody is looking for is their own and a camp has fourteen staff.
    nonisolated static func pool(in camp: Camp?, venueID: Venue.ID, me: StaffMember.ID?) -> [StaffMember] {
        guard let camp else { return [] }
        return camp.staff
            // One predicate rather than four lists appended: a roaming admin who is also you
            // satisfies three arms, and concatenation would draw them three times.
            .filter {
                $0.id == me
                    || $0.role.isAdmin
                    || $0.venueID == venueID
                    || ($0.isRoaming && $0.venueID == nil)
            }
            .sorted { lhs, rhs in
                // You first, and only when exactly one of the pair is you — two rows that are both
                // "not me" fall through to the court order below, which is the old sort unchanged.
                let lhsIsMe = lhs.id == me
                let rhsIsMe = rhs.id == me
                if lhsIsMe != rhsIsMe { return lhsIsMe }

                let left = lhs.assignment?.groupNumber ?? .max
                let right = rhs.assignment?.groupNumber ?? .max
                return left == right ? lhs.name < rhs.name : left < right
            }
    }

    /// `Nass`, or `Nass · you` on your own row.
    ///
    /// ` · you` is `BlockAssigneeList.name(for:)`'s wording (`:135-140`) and its position — after
    /// the name, not buried in the grey line under it — so the card that *states* who is on a block
    /// and the two pickers that *choose* them say the same thing the same way.
    ///
    /// A `String` and not that card's tinted `Text`. The accent run needs a `Text`-typed title on
    /// `BlockPickRow`, which is a shared row this change had no other reason to touch, and the
    /// colour is doing less work here anyway: on a picker the accent already means "ticked", so a
    /// second accent phrase on the same row would be one word too many. Pinning the row to the top
    /// is what makes it findable; the suffix is what confirms it.
    nonisolated static func rowTitle(for member: StaffMember, me: StaffMember.ID?) -> String {
        member.id == me ? "\(member.name) · you" : member.name
    }

    /// `Worker · Sycamore · Court 3`, or `Admin · No court` for somebody the camp has not posted
    /// anywhere.
    ///
    /// `StaffMember.detailLine` alone renders that second case as the bare word "Admin", which in a
    /// column of rows that all name a venue and a court reads as a line that failed to load rather
    /// than as a person standing nowhere in particular. "No court" is the camp's own word for it —
    /// it is the first chip in `StaffSheet.courtChips`, which is the control that fixes it.
    ///
    /// The guard restates `detailLine`'s own third arm (`Models.swift:686-690`) from the outside,
    /// which is one condition written twice from opposite ends: move that branching and this
    /// silently mislabels. It belongs on the model, beside `StaffMember.courtChip`, which already
    /// answers this exact case for a different reader and answers it "—". `Models.swift` is not
    /// this unit's file, so the coupling is named here instead of fixed.
    nonisolated static func rowDetail(for member: StaffMember) -> String {
        guard member.isUnassigned, !member.isRoaming else { return member.detailLine }
        return "\(member.detailLine) · No court"
    }
}

// MARK: - Previews

private struct BlockCoachPickerPreview: View {
    @State private var selection: Set<StaffMember.ID>

    /// Alex — the account `SampleData` signs in as, and a worker on Sycamore's Court 3. So the
    /// first row of every preview below is somebody else's court number lifted out of order,
    /// which is exactly what "you first" is meant to look like.
    private static let me = SampleData.alexStaff.id

    private static var staff: [StaffMember] {
        BlockCoachPicker.pool(in: SampleData.uclaTennisCamp, venueID: SampleData.sycamore.id, me: me)
    }

    init(selected: Int) {
        _selection = State(initialValue: Set(Self.staff.prefix(selected).map(\.id)))
    }

    var body: some View {
        BlockCoachPicker(people: Self.staff, selection: $selection, myID: Self.me)
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
