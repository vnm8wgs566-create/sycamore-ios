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
    /// Opens the enrolment flow. Held by `GroupsView` rather than acted on here, because which
    /// venue a kid lands in is the *chip row's* answer and the chip row is up there.
    let onAddKids: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The "Added so far" list starts folded at two rows, like the design draws it.
    @State private var showsEveryone = false

    /// The design's fixed sizes, grown with the reader's type. Each is drawn *around* text —
    /// the padlock, the button's label, the initials in a disc — so pinning them is how a
    /// screen looks fine at the default setting and clips at the app's `.accessibility1` cap.
    @ScaledMetric(relativeTo: .body) private var actionHeight = GroupsMetrics.lockedActionHeight
    @ScaledMetric(relativeTo: .footnote) private var avatarSize = GroupsMetrics.lockedAvatar

    /// Every kid in the camp, in rank order — five of them, at this point in a camp's life.
    private var players: [Player] { store.camp?.orderedPlayers ?? [] }

    private var remaining: Int { max(0, GroupsRules.opensAt - players.count) }

    /// `Add three more kids`. Spelled out because the design spells it out — "Add 3 more kids"
    /// reads like a form field rather than a sentence — and through `NumberFormatter` rather
    /// than a lookup table so it is still a sentence in a language that is not English.
    private var callToAction: String {
        let spelled = spellOut.string(from: NSNumber(value: remaining)) ?? "\(remaining)"
        return "Add \(spelled) more kid\(remaining == 1 ? "" : "s")"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: GroupsMetrics.lockedGap) {
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

    /// Deliberately *not* a `ContentUnavailableView`, which every other empty state on this
    /// screen is — see `GroupsView.nothingHere`.
    ///
    /// Nothing is unavailable here: there are five kids, they are listed directly below, and the
    /// card is a gate with a progress meter and a call to action rather than an apology for an
    /// absence. The design draws it as a specific composition — a 52pt disc, then 16, then 9,
    /// then 20, then 16 — and `ContentUnavailableView` owns its own spacing, so using it would
    /// mean claiming an exactness the layout does not have.
    private var lockedCard: some View {
        Card(radius: GroupsMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                // The padlock used to be a bare `GroupsMetrics.lockGlyph` inside a `@ScaledMetric`
                // disc, so at the app's `.accessibility1` cap the ring grew and the glyph stayed
                // where it was. `AccentDisc` scales both off one ramp, which is the fix.
                AccentDisc(
                    "lock",
                    size: GroupsMetrics.lockDisc,
                    glyph: GroupsMetrics.lockGlyph,
                    relativeTo: .title2
                )

                Text("Groups open at eight kids.")
                    .typeStyle(GroupsType.lockedHeading, color: Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.large)
                    .accessibilityAddTraits(.isHeader)

                Text("Below that a coach can hold the order in their head, and a list would just be in the way.")
                    .typeStyle(GroupsType.lockedBody, color: Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: GroupsMetrics.lockedCopyWidth)
                    .padding(.top, GroupsMetrics.lockedBodyGap)

                GroupsMeter(count: players.count, target: GroupsRules.opensAt)
                    .padding(.top, GroupsMetrics.meterGap)

                // Wired at last. This closure was empty, and its comment said adding a kid was
                // "its own section 8 screen" with "nothing on the device to write to yet" — the
                // screens are `8c`/`8e` and they exist, and `AppStore.applyRoster` and
                // `addPlayer` are the something to write to. (The comment also pointed at
                // `ScheduleView` as making the same call; that has not been true since the
                // schedule was wired, so the citation was stale as well as the claim.)
                //
                // It opens the whole enrolment flow rather than `8e` alone, because "add three
                // more kids" and "import the sign-up list" are the same errand and `8c` is the
                // screen that offers both. Typing three kids in is one tap further along; sending
                // the file is one tap the other way, and that is the tap most camps want.
                PrimaryButton(
                    callToAction,
                    systemImage: "person.badge.plus",
                    height: actionHeight,
                    radius: Radius.input,
                    font: GroupsType.lockedAction,
                    action: onAddKids
                )
                .padding(.top, Spacing.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GroupsMetrics.lockedPaddingVertical)
            .padding(.horizontal, GroupsMetrics.lockedPaddingHorizontal)
        }
    }

    // MARK: Added so far

    @ViewBuilder
    private var addedSoFar: some View {
        if !players.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Hand-drawn rather than `SectionHeader`, which is a step bigger, a weight
                // heavier and tracked tighter than `8g` sets this — and which would put a count
                // beside it that the design does not draw. The number is already in the meter
                // above; twice on one screen is once too many.
                Text("Added so far")
                    .typeStyle(GroupsType.lockedSection, color: Theme.inkMuted)
                    .padding(.horizontal, GroupsMetrics.lockedSectionInset)
                    .padding(.bottom, GroupsMetrics.lockedSectionGap)
                    .accessibilityAddTraits(.isHeader)

                Card(radius: GroupsMetrics.cardRadius) {
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
            store.pushedScreen = .player(player.id)
        } label: {
            CardRow(verticalPadding: Spacing.row) {
                InitialsAvatar(
                    initials(for: player),
                    size: avatarSize,
                    font: GroupsType.lockedInitials
                )

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(player.displayName)
                        .typeStyle(GroupsType.lockedName, color: Theme.ink)
                        .lineLimit(1)
                    Text(player.metaLine)
                        .typeStyle(GroupsType.lockedMeta, color: Theme.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                DisclosureChevron(size: GroupsMetrics.lockedCaret)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this kid")
    }

    private var moreRow: some View {
        Button(action: toggleEveryone) {
            HStack(spacing: GroupsMetrics.lockedMoreGap) {
                Image(systemName: showsEveryone ? "chevron.up" : "chevron.down")
                    .font(.system(size: GroupsMetrics.lockedMoreCaret, weight: .semibold))
                    .accessibilityHidden(true)
                Text("\(hiddenCount) more")
                    .typeStyle(.metaStrong)
            }
            .foregroundStyle(Theme.accent)
            .padding(.vertical, GroupsMetrics.lockedMorePadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: HitTarget.minimum)
            // `#FAFBFA` — a row one step up from the white card it closes.
            .background(Theme.surfaceRaised)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func toggleEveryone() {
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) { showsEveryone.toggle() }
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

#Preview("Groups — locked, large type") {
    GroupsView()
        .environment(lockedPreviewStore())
        .dynamicTypeSize(.accessibility1)
        .frame(width: 402, height: 874)
}
