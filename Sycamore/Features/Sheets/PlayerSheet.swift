//
//  PlayerSheet.swift
//  Sycamore
//
//  Screen 9 — tap a kid. Three stat tiles, three things you can do about them, and the history
//  of how they got where they are.
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
            statTiles
                .padding(.bottom, Spacing.large)

            actionRows

            // The design only ever draws this section populated. A kid nobody has moved or
            // ranked yet has no events, and a bare "History" header over an empty sheet
            // reads as something that failed to load — so say what it means instead.
            SheetSectionHeader("History", topPadding: Spacing.large, bottomPadding: Spacing.small)
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

    // MARK: - Stats

    private var statTiles: some View {
        HStack(spacing: Spacing.small) {
            StatTile(label: "On court", value: "#\(player?.courtRank ?? 0)")
            StatTile(label: "Overall", value: "#\(player?.overallRank ?? 0)")
            StatTile(label: "Age", value: "\(player?.age ?? 0)")
        }
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

// MARK: - Stat tile

/// `grouped` plate at radius 13 — "ON COURT #3".
private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .typeStyle(.statLabel, color: Theme.inkFaint)
            Text(value)
                .typeStyle(.statValue, color: Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(Theme.grouped, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
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
            .overlay(
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .strokeBorder(Theme.strokeAlt, lineWidth: BorderWidth.hairline)
            )
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
