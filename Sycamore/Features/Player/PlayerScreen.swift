//
//  PlayerScreen.swift
//  Sycamore
//
//  `8q` — a kid. Where they sit, what is already booked for them, and the history of how they
//  got there.
//
//  A pushed screen, as the design draws it: white header block running up under the status bar,
//  back caret, serif title, and one bar pinned to the bottom edge. It was a detent sheet on
//  `ActiveSheet.player` until `PushedScreen` learned to carry a payload — a sheet inset the
//  header behind rounded corners, and put a grabber and a swipe-down over a screen that already
//  draws its own way out.
//
//  Two of `8q`'s blocks have nothing to draw from. There is no match model, so `RESULTS` and the
//  `Record 6–2` stat cell have no source; and a pick-up carries a day and a time but no collector,
//  so the "Mum" / "Dad" column is not there. Both are noted rather than faked.
//
//  The pinned bar reads "Move to another group", as the design writes it, and it opens
//  `PlayerCourtPicker` — every group in the camp, venue by venue, with its fill and its coach on
//  it.
//
//  It read "Move up a court" and did exactly that, on the argument recorded here that an arbitrary
//  move belonged to `8p` because "it needs the whole ladder on screen to aim at, which this screen
//  does not have". That was wrong about what aiming needs, and the correction is small: a ladder
//  is how you decide *whether* a kid should move; a list of groups is all you need to decide
//  *where*. One group up is still the common case and is now one tap inside the picker rather than
//  the only sentence this screen could say. `PlayerCourtPicker`'s header argues it in full.
//
//  It then read "Move to another court" for a while, which is the divergence this file used to
//  record as known and unclosed. A move changes which rank band a kid is in — the thing Groups
//  titles "Group N" — and naming it after the place that band happens to play on made the two
//  screens most often used together disagree about what the row was called. Bar, picker and
//  VoiceOver all say group now, off `Group.number`.
//
//  `AppStore.moveUpACourt` went with the first change. This bar was its only caller, and the one
//  direction it could go is a question nothing asks now that the picker offers every group in
//  either direction.
//

import SwiftUI

struct PlayerScreen: View {
    let store: AppStore
    let playerID: Player.ID

    /// `8n`, presented from here rather than through `store.activeSheet`.
    ///
    /// This screen is itself presented, and the root that owns `activeSheet` is underneath it —
    /// asking it to present `8n` would open the sheet behind this one. `8m` reaches `8n` the same
    /// way and for the same reason; see `PickupTarget`.
    @State private var pickupTarget: PickupTarget?

    /// `PlayerCourtPicker`, presented from here for the same reason and in the same way.
    ///
    /// A second `.sheet(item:)` on one view, which `OverviewScreen.swift:199-208` already does for
    /// its own two — the alternative is one slot the two take turns in, and a slot is what this
    /// screen already could not reach.
    @State private var courtRequest: PlayerCourtRequest?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()
                PlayerHeader(
                    placement: store.camp?.placementLine(for: playerID) ?? "",
                    name: player?.displayName ?? "",
                    gender: player?.gender,
                    whoTheyAre: whoTheyAre,
                    onBack: { store.pushedScreen = nil }
                )
            }
            // The white carries up under the status bar, as the design draws it — otherwise the
            // page colour shows above the header block on a device with a notch.
            .background(Theme.surface.ignoresSafeArea(edges: .top))

            Hairline(color: Theme.hairline)

            ScrollView {
                content
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, OnTheDayTokens.headerTop)
                    .padding(.bottom, OnTheDayTokens.contentBottomInset)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, not `grouped`'s `#F6F7F9` — section 8's page is a shade warmer.
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { moveBar }
        .sheet(item: $pickupTarget) { target in
            EarlyPickupSheet(store: store, playerID: target.id) { pickupTarget = nil }
        }
        .sheet(item: $courtRequest) { request in
            PlayerCourtPicker(store: store, playerID: request.id) { courtRequest = nil }
        }
    }

    private var player: Player? { store.player(playerID) }

    // MARK: - Who they are

    /// `Boy · 13 years`, under the name.
    ///
    /// The design sets a gender glyph beside it (`ph-gender-male` at `#A2A6AE`, which is
    /// `Theme.inkFaint`). SF Symbols has no gender set and its nearest candidates encode the
    /// distinction as a dress, so for a long while this line stood on its own words — but that
    /// left the one screen the design draws the mark on largest without it. `GenderMark` draws
    /// Venus, Mars and a third mark of its own, and `PlayerHeader` sets it in front of these
    /// words at `8q`'s size and grey.
    ///
    /// The words stay. `Gender.noun` is `Girl` / `Boy` / `Kid` where the mark's own label is
    /// `Girl` / `Boy` / `Other`: this is a sentence about one child, and "Other · 13 years"
    /// categorises them where the line is meant to describe them.
    private var whoTheyAre: String? {
        guard let player else { return nil }
        // `ageLabel`, not `player.age` — the age became optional when it turned out that
        // substituting `0` for a missing one failed the column's `4..19` CHECK, so a kid imported
        // without an age could not be written at all. Interpolating the optional directly renders
        // "Optional(13) years".
        return "\(player.gender.noun) · \(player.ageLabel)"
    }

    // MARK: - Content

    /// The design's `gap:9px` column. Each block carries its own trailing gap rather than taking
    /// one from a `VStack`: a block that has nothing to draw resolves to `EmptyView`, and spacing
    /// applied between children leaves a hole where the block would have been.
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            statCard
                .padding(.bottom, OnTheDayTokens.contentGap)

            leavingEarly

            actionRows
                .padding(.bottom, OnTheDayTokens.contentGap)

            history
        }
    }

    // MARK: - Stats

    /// One card of three cells, not three cards. `8q` draws a single `16`-radius plate with
    /// `padding:14` and `gap:12`, where this screen had three separate `grouped` tiles.
    ///
    /// **There is one rank in this app, and this card used to draw two.** It read
    /// `GROUPS #7 · GROUP 1 · ON COURT #3`, where the first numeral is `overallRank` — the camp
    /// ladder, 1…N, the number every row on the Groups screen wears — and the third is
    /// `courtRank`, the kid's seat inside their own group. Two hashed numerals side by side, in
    /// identical type, and nothing on the card said which was which; the smaller one read as the
    /// authoritative one, because a smaller number looks like a better place.
    ///
    /// `courtRank` is also, since section 8, a number with nothing of its own to say. A group is a
    /// *band of the ladder* — `Camp.reindex()` re-derives every court's sequence from
    /// `overallRank`, and `GroupsLandingPlan` reads a group's order back off the ladder rather than
    /// authoring it — so "third on this court" is entirely determined by "seventh in the camp". A
    /// cell that competes with the rank and adds nothing to it is the cell to spend.
    ///
    /// What replaces it is the thing that made `#7` mean anything: how many kids there are. The
    /// design's own third cell is `RECORD 6–2` and there is still no match model to fill it, so the
    /// slot goes to the ladder's denominator rather than to a dash or to a second rank.
    private var statCard: some View {
        let shape = RoundedRectangle(cornerRadius: OnTheDayTokens.card, style: .continuous)

        return HStack(alignment: .top, spacing: Spacing.medium) {
            StatCell(label: "Rank", value: "#\(player?.overallRank ?? 0)")
            StatCell(label: "Group", value: groupNumber)
            StatCell(label: "Camp", value: campRoll)
        }
        .padding(OnTheDayTokens.cardInsetWide)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.hairline, lineWidth: BorderWidth.hairline) }
    }

    /// The bare numeral the design shows — "1", not "Group 1", because the cell beside it is
    /// already labelled "Group".
    ///
    /// `Group.number`, which is the same field `GroupCard`'s title and `PlayerCourtChoices`' rows
    /// count off. This cell has always read it; the move path has now been brought up to it.
    ///
    /// The em dash is not only the loading state any more. A kid can genuinely be at a venue with
    /// no group — a band that refuses them, or a group that was deleted out from under them — and
    /// this is what that looks like here. The Groups tab is where it is explained and where it can
    /// be fixed; the bar at the foot of this screen is the other way to fix it.
    private var groupNumber: String {
        guard let groupID = player?.groupID, let group = store.group(groupID) else { return "—" }
        return "\(group.number)"
    }

    /// `42 kids` — what the rank beside it is out of.
    ///
    /// The camp's roll and not the venue's, because `overallRank` is camp-wide: `Camp.reindex()`
    /// sorts the whole roster and numbers it 1…N, and a venue is a contiguous run of that list
    /// rather than a ladder of its own. Pairing `#7` with a venue's 20 would be the same two-ranks
    /// confusion arriving by a different door.
    private var campRoll: String {
        let count = store.camp?.playerCount ?? 0
        return "\(count) kid\(count == 1 ? "" : "s")"
    }

    // MARK: - Leaving early

    /// Every pick-up on the books this week, which is what `8q` lists rather than the single
    /// "today" reading the action row below still gives.
    private var weekPickups: [Attendance] {
        (store.camp?.attendance ?? [])
            .filter { $0.playerID == playerID && $0.leavesAt != nil }
            .sorted { $0.day.rawValue < $1.day.rawValue }
    }

    @ViewBuilder
    private var leavingEarly: some View {
        let pickups = weekPickups

        if !pickups.isEmpty {
            // The first overline on the screen, which the design leads with 2pt rather than the
            // 6 it puts between sections. `8q` spends that opening on RESULTS; with no match
            // model to draw it from, "Leaving early" inherits the position and its padding.
            AttendanceOverline(
                title: "Leaving early",
                count: pickups.count,
                actionTitle: "Add",
                action: { pickupTarget = PickupTarget(id: playerID) }
            )
            .padding(.top, OnTheDayTokens.overlineLead)

            Card(radius: OnTheDayTokens.card) {
                ForEach(pickups) { record in
                    pickupRow(record)
                }
            }
            .padding(.bottom, OnTheDayTokens.contentGap)
        }
    }

    private func pickupRow(_ record: Attendance) -> some View {
        HStack(spacing: Spacing.row) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(OnTheDayTokens.warning)
                .accessibilityHidden(true)

            Text(pickupLabel(record))
                .typeStyle(.onTheDayValue, color: Theme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnTheDayTokens.cardInset)
        .padding(.vertical, Spacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Tuesday · 2:30pm"
    private func pickupLabel(_ record: Attendance) -> String {
        guard let leavesAt = record.leavesAt else { return record.day.fullName }
        return "\(record.day.fullName) · \(leavesAt.clockLabel)"
    }

    // MARK: - Actions

    /// The two writes the design has no room for. `8q` spends its content on results and
    /// pick-ups and its one action on the bar; these are the app's, and they are the only way to
    /// mark a kid away or book a pick-up from the kid's own screen.
    private var actionRows: some View {
        VStack(spacing: Spacing.small) {
            ActionRow(
                icon: "person.badge.minus",
                title: isAway ? "Mark here today" : "Mark away today",
                detail: isAway ? "Puts them back on the court" : "Stays on the list, greyed out"
            ) {
                Task { await store.toggleAway(playerID) }
            }

            ActionRow(
                icon: "clock",
                title: "Set early pick-up",
                detail: pickupDetail
            ) {
                pickupTarget = PickupTarget(id: playerID)
            }
        }
    }

    private var isAway: Bool { store.isAway(playerID) }

    /// Once a pick-up is on the books the row reads it back instead of the invitation.
    private var pickupDetail: String {
        guard let time = store.leavesAt(playerID) else { return "Pick a day and a time" }
        return "Leaves \(store.today.shortName) at \(time.formatted)"
    }

    // MARK: - History

    @ViewBuilder
    private var history: some View {
        // Resolved once and read twice — the filter behind it walks the camp's whole event log,
        // and asking whether it is empty and then asking for it again did that on every pass.
        let events = store.history(for: playerID)

        // The design only ever draws this section populated. A kid nobody has moved or ranked yet
        // has no events, and a bare "History" header over an empty screen reads as something that
        // failed to load — so say what it means instead.
        AttendanceOverline(title: "History")
            .padding(.top, OnTheDayTokens.overlineBreak)

        if events.isEmpty {
            Text("Nothing yet — moves and rankings show up here.")
                .typeStyle(.meta, color: Theme.inkFaint)
                .padding(.horizontal, OnTheDayTokens.overlineInset)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(events) { event in
                    TimelineEntry(event: event)
                }
            }
        }
    }

    // MARK: - The bar

    /// `8q`'s pinned bar, reading the design's "Move to another group"; see the file header for
    /// what it used to say, and `PlayerCourtPicker` for what it opens.
    private var moveBar: some View {
        PlayerMoveBar(isEnabled: canMoveElsewhere) {
            courtRequest = PlayerCourtRequest(id: playerID)
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, OnTheDayTokens.barInset)
    }

    /// Whether there is anywhere else in the camp to put them.
    ///
    /// It used to ask whether there was a group *above* this one, because the bar performed that
    /// one move and `moveUpACourt` returns silently when there is not — a bar that answers a tap
    /// with nothing being worse than one that says it is spent. The bar opens a list now, so the
    /// question is whether the list would have anything in it: a kid in the top group has eleven
    /// other groups to choose from and the bar has no business standing down for them.
    ///
    /// Asked of `PlayerCourtChoices` — the type the sheet itself lists from — rather than with a
    /// predicate of its own. A live bar over an empty picker, or a dead bar over a full one, is a
    /// disagreement neither screen could show you; one answer cannot disagree with itself. A
    /// camp still loading, or one with no groups shaped yet, comes back false through the same
    /// route and the bar stands down and says so.
    private var canMoveElsewhere: Bool {
        PlayerCourtChoices(for: playerID, in: store.camp).hasSomewhereElse
    }
}

// MARK: - Stat cell

/// One third of `8q`'s stat card: `600 10 / +.14em / uppercase` over `600 17 / -.03em`, with the
/// design's 5pt between them. No plate of its own — the card behind all three is the plate.
private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .typeStyle(.onTheDayStatLabel, color: Theme.inkFaint)
            Text(value)
                .typeStyle(.onTheDayStatValue, color: Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Action row

/// A bordered white row at radius 14 — this screen's equivalent of a card row, but standing alone
/// with 8pt between each one rather than divided inside a card.
private struct ActionRow: View {
    let icon: String
    let title: String
    var detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .typeStyle(.rowLabel, color: Theme.ink)
                    if let detail {
                        Text(detail)
                            .typeStyle(.meta, color: Theme.inkMuted)
                    }
                }

                Spacer(minLength: 0)
                DisclosureChevron(size: 15)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .strokeBorder(Theme.strokeAlt, lineWidth: BorderWidth.hairline)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline entry

/// A 7pt dot, blue for the event worth noticing and `timelineDot` for the rest, with the rule
/// carried on the *top* edge so the first entry sits under the HISTORY overline.
private struct TimelineEntry: View {
    let event: HistoryEvent

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(alignment: .top, spacing: Spacing.row) {
                Circle()
                    .fill(event.isAccent ? Theme.accent : Theme.timelineDot)
                    .frame(width: 7, height: 7)
                    // Drops the dot onto the title's optical centre rather than its cap line.
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .typeStyle(.timelineTitle, color: Theme.ink)
                    Text(event.detail)
                        .typeStyle(.timelineMeta, color: Theme.inkFaint)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.small)
        }
    }
}

// MARK: - Previews

#Preview("A kid") {
    PlayerScreen(store: .preview, playerID: SampleData.austinZ.id)
        .showsMockStatusBar()
}

#Preview("A kid — away") {
    PlayerScreen(store: .preview, playerID: SampleData.liamJ.id)
        .showsMockStatusBar()
}

/// Every colour here is a `Theme` token, so the dark scheme is a check rather than a second
/// design — but this screen carries the palette's warmest values and those are the ones a derived
/// dark column is most likely to get wrong.
#Preview("A kid — dark") {
    PlayerScreen(store: .preview, playerID: SampleData.austinZ.id)
        .showsMockStatusBar()
        .preferredColorScheme(.dark)
}

/// The app caps Dynamic Type at `.accessibility1`; the stat card's three cells and the pinned bar
/// are what break first if a frame is fixed rather than floored.
#Preview("A kid — accessibility1") {
    PlayerScreen(store: .preview, playerID: SampleData.austinZ.id)
        .showsMockStatusBar()
        .dynamicTypeSize(.accessibility1)
}
