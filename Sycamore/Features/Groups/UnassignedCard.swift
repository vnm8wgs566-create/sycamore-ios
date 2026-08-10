//
//  UnassignedCard.swift
//  Sycamore
//
//  The kids who are at a venue and in **no group** — and, where the app can tell, why.
//
//  Two model paths put a child here and until now neither of them reached a screen.
//
//  * A venue's age band refuses them. `Camp.admit(_:at:)` sets `groupID = nil` on every deal and
//    on every venue upsert that narrows the band, and `AgeBand.admits(_:)` justifies refusing an
//    unknown age on the grounds that "the screen says so out loud and somebody can place them by
//    hand" (`Models.swift:624-632`). No screen said so.
//  * Their group was deleted. `Camp.removeGroup(_:from:)` leaves a deleted group's kids at the
//    venue with no group, which is the same thing `syncGroups(for:)` has always done to a trimmed
//    court's kids.
//
//  Both features were dishonest without this card: the Groups tab is the one screen whose whole
//  job is who-is-where, and a child it holds and does not draw is a child nobody can find. This is
//  the smallest thing that makes them honest — say who, say why, and give the same handle every
//  other kid on the screen has.
//
//  **They are a drag source and not a drop target, and that asymmetry is the design.** "No group"
//  is a state the model puts a kid in; it is not a place you can aim one at. So this card emits no
//  slots (`GroupsView.slots(for:)` never sees it), draws no ghost and never lights up as a target
//  — and the way out of it is the ordinary lift-and-drag into any group card, which is already
//  built, already reaches every seat in the venue, and already writes the ladder correctly for a
//  kid arriving from nowhere (`GroupsLandingPlan` only ever *removes* the mover from the ladder
//  before inserting them, so a mover who was in no group needs no special case).
//
//  **Grouped by reason rather than carrying one per row.** A reason set beside each name would be
//  the same sentence repeated down the card, and the two sentences are long — "Outside this
//  venue's 11 & under band" does not fit in a row that already carries a numeral, a name, three
//  marks and a handle. One line above each run says it once, in the register the card headings
//  use, and the rows underneath stay identical to the rows in every group card — which is what
//  makes it obvious they can be dragged.
//
//  **Deliberately not folded to three rows with a "+N more".** Every other card on this screen is
//  a standing list you scan; this one is a to-do list you empty, and hiding four of its seven
//  entries hides work. It is also self-limiting in a way a group is not — a venue in a normal
//  state has nobody here at all, and the card disappears.
//

import SwiftUI

// MARK: - Why a kid has no group

/// What the app can honestly say about a child standing at a venue with no group.
///
/// Two cases, and the second is a residual rather than a recorded fact. Nothing in the graph
/// remembers *why* a `groupID` went nil, so the band is asked first — it is the one reason that can
/// be re-derived at any time, because the venue still carries the band and the kid still carries
/// the age. Anyone the band would happily admit is here because a group went: `syncGroups(for:)`
/// re-seats every admitted kid with no court onto the smallest one at the end of every venue
/// upsert, so an admitted kid with no group cannot have survived one.
///
/// Written as a type rather than as two booleans at the call site so that the card and its tests
/// agree on the rule, and so a third reason — a venue with no groups shaped yet, say — has an
/// obvious place to be added rather than a condition to be squeezed into.
enum UnassignedReason: Hashable {

    /// The venue's band refuses them. Carries the band so the line can name it.
    case outsideBand(AgeBand)
    /// The band admits them, so the only thing that can have moved them out of a group is the
    /// group going.
    case groupRemoved

    /// Which of the two applies to this kid at this venue.
    static func reason(forAge age: Int?, at band: AgeBand) -> UnassignedReason {
        band.admits(age) ? .groupRemoved : .outsideBand(band)
    }

    /// The line above the run of kids it applies to.
    ///
    /// Sentence case and no numbers: the count is on the card's own subtitle, and repeating it
    /// here would be two answers to "how many".
    var line: String {
        switch self {
        case .outsideBand(let band): "Outside this venue's \(band.label) band"
        case .groupRemoved: "Their group was removed"
        }
    }

    /// The band is a rule the venue is enforcing and the reader may want to change; a removed
    /// group is a thing that already happened. Only the first is worth a colour.
    var isWarning: Bool {
        switch self {
        case .outsideBand: true
        case .groupRemoved: false
        }
    }
}

// MARK: - The card

struct UnassignedCard: View {

    /// Every kid at this venue with no group, in ladder order.
    let rows: [PlayerRow]
    /// The venue's band, which is what decides each row's reason. The venue's name is not needed:
    /// the chip row above the list already names it and the card is inside that venue's list.
    let band: AgeBand

    /// True while a kid — any kid — is in the air. The card fades with the rest of the bystanders
    /// unless the kid came out of it.
    let isMoving: Bool
    let isSource: Bool

    let onOpenPlayer: (PlayerRow) -> Void
    let onMoveBegan: (PlayerRow) -> Void
    let onMoveChanged: (CGFloat) -> Void
    let onMoveEnded: () -> Void
    let onMoveCancelled: () -> Void
    /// Measured for the same reason a group card's rows are: the lift needs the row's rectangle to
    /// position the card it hands the reader. This card produces no drop slots, so these rectangles
    /// are only ever read as an origin.
    let onRowFrame: (Player.ID, CGRect) -> Void
    /// The row the kid in the air came out of, so it can hold its place at reduced opacity exactly
    /// as a group card's does.
    let heldRowID: Player.ID?

    /// The rows split into runs of one reason each, in the order the reasons first appear.
    ///
    /// Stable across a re-render because it is derived from `rows`, which arrives in ladder order:
    /// two kids the band refuses stay in ladder order inside their run, and the runs themselves are
    /// in the order the ladder first meets them.
    private var runs: [Run] {
        var runs: [Run] = []
        for row in rows {
            let reason = UnassignedReason.reason(forAge: row.player.age, at: band)
            if let last = runs.indices.last, runs[last].reason == reason {
                runs[last].rows.append(row)
            } else {
                runs.append(Run(reason: reason, rows: [row]))
            }
        }
        return runs
    }

    private struct Run: Identifiable {
        let reason: UnassignedReason
        var rows: [PlayerRow]

        /// Keyed on the first kid in the run, **not on the reason**.
        ///
        /// The two populations interleave. `Camp.admit` nils `groupID` for everyone a band
        /// refuses; `Camp.removeGroup` nils it for everyone on a deleted court whatever their age;
        /// and `unassigned` is built in `overallRank` order, so a venue can hand this card
        /// `[.outsideBand, .groupRemoved, .outsideBand]`. `runs` chops that into *consecutive*
        /// runs, so keying on the reason gives two runs the same id — SwiftUI logs a duplicate-ID
        /// warning and draws undefined results, on the one card whose entire job is that a kid it
        /// holds and does not draw is a kid nobody can find.
        ///
        /// Not `let id = UUID()`: `runs` is computed on every pass of `body`, so a fresh uuid per
        /// pass would give every run a new identity every render and take diffing and animation
        /// with it. A run is never built empty, so its first row is a stable, unique key.
        var id: Player.ID { rows[0].id }
    }

    var body: some View {
        Card(radius: GroupsMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                header

                Hairline(color: Theme.hairlineSoft)
                    .padding(.horizontal, GroupsMetrics.cardPadding)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(runs) { run in
                        reasonLine(run.reason)

                        ForEach(run.rows) { row in
                            rowView(row)
                        }
                    }
                }
                .padding(.top, Spacing.tight)
                .padding(.bottom, Spacing.tight)
            }
        }
        .opacity(isMoving && !isSource ? GroupsMetrics.bystanderOpacity : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No group yet, \(countLine)")
    }

    // MARK: Header

    /// No caret and no button: there is nothing to fold. The head of a group card presses because
    /// it hides kids; this one hides nobody.
    private var header: some View {
        VStack(alignment: .leading, spacing: GroupsMetrics.titleGap) {
            Text("No group yet")
                .typeStyle(GroupsType.groupTitle, color: Theme.ink)
                .lineLimit(1)

            Text(countLine)
                .typeStyle(GroupsType.rowMeta, color: Theme.inkMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, GroupsMetrics.cardPadding)
        .padding(.top, GroupsMetrics.cardPadding)
        .padding(.bottom, GroupsMetrics.rowsGap)
    }

    /// `3 kids · still at this venue`.
    ///
    /// The second half is the part worth saying. "Unassigned" reads as *gone* to somebody scanning
    /// for a child, and the whole point of this state is that they have not gone anywhere: they are
    /// at the venue, they are in the ladder, they are wearing their rank. They simply have no group
    /// until somebody gives them one.
    private var countLine: String {
        "\(rows.count) kid\(rows.count == 1 ? "" : "s") · still at this venue"
    }

    // MARK: Rows

    private func reasonLine(_ reason: UnassignedReason) -> some View {
        Text(reason.line)
            // `inkTertiary` (#71757E, 4.6:1 on white) rather than `inkMuted` (#8A8E96, 3.5:1).
            // Both halves of this sentence have to be legible, and only one of them was: the
            // `.outsideBand` case takes `warningDark` and passes comfortably, while its
            // `.groupRemoved` sibling — the same size, the same job, the same card — sat below the
            // 4.5:1 floor. A reason nobody can read is a card with no reason on it.
            .typeStyle(
                GroupsType.rowMeta,
                color: reason.isWarning ? Theme.warningDark : Theme.inkTertiary
            )
            // No line cap. This line *is* the card's justification, and a venue named at any
            // length ("Outside this venue's 9–12 band") at an accessibility text size runs past two
            // lines and was being truncated — the sentence explaining where a missing child went,
            // cut off. `fixedSize` lets it take the height it needs.
            .fixedSize(horizontal: false, vertical: true)
            // Indented to where the names start, not to where the numerals do, so it reads as a
            // heading over the names rather than as a row with the numeral column left blank —
            // which is what "+N more" uses that column for.
            // Unscaled, deliberately. The indent's job is to line this sentence up with the
            // *names* below it, and those are drawn by `GroupsRow` off the same unscaled
            // `numeralWidth` — so scaling only this one would walk it out of alignment with the
            // thing it is aligned to, at exactly the text sizes where alignment matters most.
            .padding(.leading, GroupsMetrics.cardPadding + GroupsMetrics.numeralWidth + Spacing.row)
            .padding(.trailing, GroupsMetrics.cardPadding)
            .padding(.top, Spacing.tight)
            .padding(.bottom, Spacing.hairGap)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The same row every group card draws, with the same handle and the same gesture.
    ///
    /// `onNudge: nil` is the one difference, and it is deliberate rather than an omission. The two
    /// rotor actions a group card's row offers are "Move up" and "Move down" **inside the ladder**,
    /// and a kid in no group has no place in a card to step away from — "up" from nowhere is not a
    /// sentence. The non-pointer route to placing them is the one `8q` already owns: tapping the
    /// row opens the kid, and the bar there opens `PlayerCourtPicker`, which lists every group in
    /// the camp with its fill and its coach. That is a better tool for this particular job than two
    /// one-step nudges would be, and it is already built and already tested.
    private func rowView(_ row: PlayerRow) -> some View {
        GroupPlayerRow(
            row: row,
            isAiming: isMoving,
            onOpen: { onOpenPlayer(row) },
            onMoveBegan: { onMoveBegan(row) },
            onMoveChanged: onMoveChanged,
            onMoveEnded: onMoveEnded,
            onMoveCancelled: onMoveCancelled,
            onNudge: nil
        )
        .opacity(heldRowID == row.id ? GroupsMetrics.heldOpacity : 1)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(GroupsSpace.list))
        } action: {
            onRowFrame(row.id, $0)
        }
    }
}

// MARK: - Previews

#Preview("No group yet") {
    let camp = SampleData.uclaTennisCamp
    let venue = camp.orderedVenues[0]

    return ScrollView {
        UnassignedCard(
            rows: camp.players(in: venue.id).prefix(3).map {
                PlayerRow(id: $0.id, player: $0, rank: $0.overallRank, isAway: false, leavesAt: nil)
            },
            band: .upTo(11),
            isMoving: false,
            isSource: false,
            onOpenPlayer: { _ in },
            onMoveBegan: { _ in },
            onMoveChanged: { _ in },
            onMoveEnded: {},
            onMoveCancelled: {},
            onRowFrame: { _, _ in },
            heldRowID: nil
        )
        .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
}
