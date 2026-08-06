//
//  PlayerSheet.swift
//  Sycamore
//
//  `8q` — a kid. Where they sit, what is already booked for them, and the history of how they
//  got there.
//
//  Drawn to `8q`'s content, not its chrome. The design has this as a pushed screen with a serif
//  title, a back caret and a pinned bar; the app presents it as a sheet, which is how every other
//  secondary screen here arrives and is the presentation `store.activeSheet` and `SheetChrome`
//  are built around. See the PR body — the disagreement is presentation only.
//
//  Two of `8q`'s blocks have nothing to draw from. There is no match model, so `RESULTS` and the
//  `Record 6–2` stat cell have no source; and a pick-up carries a day and a time but no collector,
//  so the "Mum" / "Dad" column is not there. Both are noted rather than faked.
//

import SwiftUI

struct PlayerSheet: View {
    let store: AppStore
    let playerID: Player.ID

    var body: some View {
        SheetChrome(
            title: player?.displayName ?? "",
            subtitle: store.camp?.placementLine(for: playerID),
            detentFraction: ActiveSheet.player(playerID).detentFraction,
            onClose: { store.dismissSheet() }
        ) {
            genderAndAge

            statCard
                .padding(.bottom, Spacing.large)

            leavingEarly

            actionRows

            // The design only ever draws this section populated. A kid nobody has moved or
            // ranked yet has no events, and a bare "History" header over an empty sheet
            // reads as something that failed to load — so say what it means instead.
            AttendanceOverline(title: "History", inset: 0)
                .padding(.top, Spacing.large)
            if store.history(for: playerID).isEmpty {
                Text("Nothing yet — moves and rankings show up here.")
                    .typeStyle(.meta, color: Theme.inkFaint)
                    .padding(.top, 2)
            } else {
                timeline
            }
        }
    }

    private var player: Player? { store.player(playerID) }

    // MARK: - Who they are

    /// `Boy · 13 years`, under the name.
    ///
    /// The design sets a gender glyph beside it (`ph-gender-male` at `#A2A6AE`). SF Symbols has
    /// no gender set, and the nearest candidates encode the distinction as a dress, so the line
    /// stands on its own words instead. See the PR body.
    /// Each block carries its own trailing gap rather than taking one from the caller: a block
    /// that has nothing to draw resolves to `EmptyView`, and padding hung on the outside of that
    /// leaves a hole where the block would have been.
    @ViewBuilder
    private var genderAndAge: some View {
        if let player {
            Text("\(genderNoun(player.gender)) · \(player.age) years")
                .typeStyle(.onTheDayLede, color: Theme.inkMuted)
                .padding(.bottom, OnTheDayTokens.contentGap)
        }
    }

    /// `.x` gets a noun of its own rather than a default — a camp that recorded "x" did so
    /// deliberately, and rounding it to one of the other two would be the app overruling them.
    private func genderNoun(_ gender: Gender) -> String {
        switch gender {
        case .m: "Boy"
        case .f: "Girl"
        case .x: "Kid"
        }
    }

    // MARK: - Stats

    /// One card of three cells, not three cards. `8q` draws a single `16`-radius plate with
    /// `padding:14` and `gap:12`, where this sheet had three separate `grouped` tiles.
    ///
    /// The design's third cell is `RECORD 6–2`. There is no match model, so the cell carries the
    /// court rank instead — real data in the shape the design asks for, rather than a dash.
    private var statCard: some View {
        let shape = RoundedRectangle(cornerRadius: OnTheDayTokens.card, style: .continuous)

        return HStack(alignment: .top, spacing: Spacing.medium) {
            StatCell(label: "Groups", value: "#\(player?.overallRank ?? 0)")
            StatCell(label: "Group", value: courtNumber)
            StatCell(label: "On court", value: "#\(player?.courtRank ?? 0)")
        }
        .padding(OnTheDayTokens.cardInsetWide)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.hairline, lineWidth: BorderWidth.hairline) }
    }

    /// The bare numeral the design shows — "1", not "Court 1", because the cell is labelled.
    private var courtNumber: String {
        guard let groupID = player?.groupID, let group = store.group(groupID) else { return "—" }
        return "\(group.number)"
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
            AttendanceOverline(
                title: "Leaving early",
                count: pickups.count,
                actionTitle: "Add",
                action: { store.beginEarlyPickup(for: playerID) },
                inset: 0
            )

            Card(radius: OnTheDayTokens.card) {
                ForEach(pickups) { record in
                    pickupRow(record)
                }
            }
            .padding(.bottom, Spacing.large)
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
                store.beginEarlyPickup(for: playerID)
            }

            ActionRow(
                icon: "arrow.up",
                title: "Move up a court",
                detail: "Sends \(approverName) a request"
            ) {
                Task { await store.moveUpACourt(playerID) }
            }
        }
    }

    private var isAway: Bool { store.isAway(playerID) }

    /// Once a pick-up is on the books the row reads it back instead of the invitation.
    private var pickupDetail: String {
        guard let time = store.leavesAt(playerID) else { return "Pick a day and a time" }
        return "Leaves \(store.today.shortName) at \(time.formatted)"
    }

    /// The design names the coach who has to approve the move. That is the kid's current coach —
    /// Austin Z sits on Nass's court, which is why the design reads "Sends Nass a request".
    private var approverName: String {
        guard let groupID = player?.groupID, let coach = store.coach(forGroup: groupID) else {
            return "an admin"
        }
        return coach.name
    }

    // MARK: - History

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.history(for: playerID)) { event in
                TimelineEntry(event: event)
            }
        }
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

/// A bordered white row at radius 14 — the sheet's equivalent of a card row, but standing alone
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

#Preview("Player sheet") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        PlayerSheet(store: .preview, playerID: SampleData.austinZ.id)
            .frame(height: 562)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Player sheet — away") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        PlayerSheet(store: .preview, playerID: SampleData.liamJ.id)
            .frame(height: 562)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
