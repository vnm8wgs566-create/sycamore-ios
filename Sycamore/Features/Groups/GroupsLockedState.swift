//
//  GroupsLockedState.swift
//  Sycamore
//
//  `8g` — "Nothing to rank yet."
//
//  Groups open at eight kids. Below that a coach can hold the order in their head and a ranked
//  list would just be in the way, so the screen says so plainly, shows how far off eight the
//  camp is, and offers the one action that helps.
//
//  The design is careful here in a way worth keeping: it does not shrug. It gives a reason, a
//  count, a button, and the kids added so far — so a person setting a camp up at 7am can see
//  their work rather than an empty page.
//

import SwiftUI

/// Spells a small number as a word, in the reader's language.
///
/// A `NumberFormatter` costs hundreds of microseconds to build — it wraps ICU, and `.spellOut`
/// additionally loads the locale's spellout rules — so it is made once rather than on every pass
/// through a `body`. `@MainActor` because a formatter is not `Sendable`, and this one is only
/// ever read from a view.
@MainActor private let spellOut: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    return formatter
}()

struct GroupsLockedState: View {

    let store: AppStore

    /// The "Added so far" list starts folded at two rows, like the design draws it.
    @State private var showsEveryone = false

    /// Every kid in the camp, in rank order — five of them, at this point in a camp's life.
    private var players: [Player] { store.camp?.orderedPlayers ?? [] }

    private var remaining: Int { max(0, GroupsRules.opensAt - players.count) }

    private var progress: Double {
        min(1, Double(players.count) / Double(GroupsRules.opensAt))
    }

    /// `Add three more kids`. Spelled out because the design spells it out — "Add 3 more kids"
    /// reads like a form field rather than a sentence — and through `NumberFormatter` rather
    /// than a lookup table so it is still a sentence in a language that is not English.
    private var callToAction: String {
        let spelled = spellOut.string(from: NSNumber(value: remaining)) ?? "\(remaining)"
        return "Add \(spelled) more kid\(remaining == 1 ? "" : "s")"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                lockedCard
                addedSoFar
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, Spacing.tabBarClearance)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: The lock

    private var lockedCard: some View {
        Card(isDivided: false) {
            ContentUnavailableView {
                Label {
                    Text("Groups open at eight kids.")
                        .typeStyle(.profileName, color: Theme.ink)
                } icon: {
                    Image(systemName: "lock")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 52, height: 52)
                        .background(Theme.accentTint, in: Circle())
                        .overlay { Circle().strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline) }
                }
            } description: {
                Text("Below that a coach can hold the order in their head, and a list would just be in the way.")
                    .typeStyle(.footnote, color: Theme.inkTertiary)
            } actions: {
                VStack(spacing: Spacing.large) {
                    meter

                    PrimaryButton(callToAction, systemImage: "person.badge.plus", height: 50, radius: Radius.input, font: .buttonSmall) {
                        // Adding a kid is its own section 8 screen and there is nothing on the
                        // device to write to yet. Left inert rather than wired to a half-made
                        // sheet — see `ScheduleView`, which makes the same call.
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.tight)
        }
    }

    /// `▓▓▓▓▓░░░  5 of 8`
    private var meter: some View {
        HStack(spacing: Spacing.row) {
            Capsule(style: .continuous)
                .fill(Theme.hairline)
                .frame(height: Spacing.tight)
                .overlay(alignment: .leading) {
                    // `GeometryReader` rather than `onGeometryChange`: this is a proportional
                    // *layout*, not a measurement. Reading the width into state and setting a
                    // frame from it would be the same thing with a frame of lag in it.
                    GeometryReader { proxy in
                        Capsule(style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: proxy.size.width * progress)
                    }
                }

            Text("\(players.count) of \(GroupsRules.opensAt)")
                .typeStyle(.metaSmall, color: Theme.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kids added")
        .accessibilityValue("\(players.count) of \(GroupsRules.opensAt)")
    }

    // MARK: Added so far

    @ViewBuilder
    private var addedSoFar: some View {
        if !players.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Added so far", count: players.count)

                Card {
                    ForEach(shownPlayers) { player in
                        playerRow(player)
                    }

                    if hiddenCount > 0 {
                        moreRow
                    }
                }
            }
        }
    }

    /// Folded through the same rule a group card folds by, so a camp of three kids does not
    /// spend a "1 more" row to hide a row.
    private var shownPlayers: [Player] {
        let count = GroupsRules.visibleCount(
            of: players.count,
            preview: GroupsRules.addedPreviewRows,
            isExpanded: showsEveryone
        )
        return Array(players.prefix(count))
    }

    private var hiddenCount: Int { players.count - shownPlayers.count }

    private func playerRow(_ player: Player) -> some View {
        Button {
            store.present(.player(player.id))
        } label: {
            CardRow(verticalPadding: Spacing.row) {
                InitialsAvatar(initials(for: player), size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .typeStyle(.rowLabel, color: Theme.ink)
                        .lineLimit(1)
                    Text(player.metaLine)
                        .typeStyle(.meta, color: Theme.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                DisclosureChevron(size: 15)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this kid")
    }

    private var moreRow: some View {
        Button {
            withAnimation(GroupsMetrics.fold) { showsEveryone.toggle() }
        } label: {
            HStack(spacing: Spacing.tight) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(hiddenCount) more")
                    .typeStyle(.chipMedium)
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: HitTarget.minimum)
            .background(Theme.runBackground)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// `Serene C` → `SC`. `Initials.make(from:)` takes the first two letters of a name, which is
    /// right for "Nass" and wrong for a kid, whose surname is already only one letter.
    private func initials(for player: Player) -> String {
        "\(player.firstName.prefix(1))\(player.lastInitial.prefix(1))".uppercased()
    }
}

// MARK: - Previews

/// A camp with five kids in it — the state `8g` is drawn in.
@MainActor
private func lockedPreviewStore() -> AppStore {
    let store = AppStore.preview
    let firstFew = Array(store.camp?.orderedPlayers.prefix(5) ?? [])
    store.camp?.players = firstFew
    store.camp?.reindex()
    return store
}

#Preview("Groups — locked") {
    GroupsView()
        .environment(lockedPreviewStore())
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}
