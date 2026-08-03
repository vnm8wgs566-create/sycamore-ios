//
//  SetupView.swift
//  Sycamore
//
//  Screen 7 — the shape of the camp. Venues and their staffing at the top, the one-shot
//  partition below them, then the whole staff list as a single card with a filter above it
//  rather than the five-line rows and trailing block of grey unassigned people the earlier
//  pass had.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SetupView: View {

    let store: AppStore

    /// The design gives "Invite" no destination, so it hands over the code and says so.
    @State private var inviteCopied = false

    init(store: AppStore) {
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let camp = store.camp {
                content(for: camp)
            } else {
                Spacer(minLength: 0)
            }
        }
        .background(Theme.grouped)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Setup")
                        .typeStyle(.tabTitle, color: Theme.ink)
                    subtitle
                        .padding(.top, 5)
                }
                Spacer(minLength: 0)
                shareButton
            }
            .padding(.horizontal, Spacing.bar)
            .padding(.vertical, 14)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    /// `UCLA Tennis Camp · code SYC-4821`, the code in mono accent.
    private var subtitle: some View {
        Text("\(store.camp?.name ?? "") · code ")
            .typeStyle(.metaStrong, color: Theme.inkMuted)
            + Text(store.camp?.inviteCode ?? "")
            .typeStyle(.monoInline, color: Theme.accent)
    }

    @ViewBuilder
    private var shareButton: some View {
        #if os(iOS)
        ShareLink(item: shareMessage) { shareGlyph }
            .buttonStyle(.plain)
        #else
        // macOS builds exist only for typechecking; nothing to share from here.
        shareGlyph
        #endif
    }

    /// `CircleIconButton` is a `Button`, which cannot nest inside `ShareLink`, so the
    /// share affordance draws its own 34pt disc from the same tokens.
    private var shareGlyph: some View {
        Circle()
            .fill(Theme.surface)
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(Theme.strokeAlt, lineWidth: BorderWidth.hairline))
            .overlay {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .contentShape(Circle())
    }

    private var shareMessage: String {
        guard let camp = store.camp else { return "" }
        return "\(camp.name) · invite code \(camp.inviteCode)"
    }

    // MARK: - Body

    private func content(for camp: Camp) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader("Venues", actionTitle: "Add") {
                    Task { await store.addVenue() }
                }

                Card {
                    ForEach(camp.orderedVenues) { venue in
                        venueRow(venue, in: camp)
                    }
                }
                .padding(.bottom, 10)

                partitionRow
                    .padding(.bottom, Spacing.section)

                staffSection(camp)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, Spacing.tabBarClearance)
        }
    }

    // MARK: - Venues

    private func venueRow(_ venue: Venue, in camp: Camp) -> some View {
        Button {
            store.present(.venue(venue.id))
        } label: {
            CardRow(spacing: Spacing.medium) {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .fill(Theme.color(for: venue.tint))
                    .frame(width: 44, height: 44)
                    .overlay(Text(venue.icon).font(.system(size: 21)))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(venue.name)
                            .typeStyle(.rowTitle, color: Theme.ink)
                        if let status = camp.staffingStatus(for: venue.id) {
                            Badge(status.badgeText, tone: status.needsAttention ? .accent : .neutral)
                        }
                    }
                    Text(camp.rowSummary(for: venue.id))
                        .typeStyle(.meta, color: Theme.inkMuted)
                }

                Spacer(minLength: 0)
                DisclosureChevron()
            }
        }
        .buttonStyle(.plain)
    }

    private var partitionRow: some View {
        Button {
            Task { await store.partitionCamp() }
        } label: {
            Card(radius: Radius.input, isDivided: false) {
                CardRow(spacing: 10, verticalPadding: 14) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Theme.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Partition the camp")
                            .typeStyle(.rowLabel, color: Theme.ink)
                        Text("Fills each venue by rank, inside its limits")
                            .typeStyle(.meta, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Staff

    @ViewBuilder
    private func staffSection(_ camp: Camp) -> some View {
        SectionHeader("Staff", count: camp.staffCount, actionTitle: inviteCopied ? "Copied" : "Invite") {
            copyInviteCode(camp)
        }

        staffFilters

        let people = store.filteredStaff
        if !people.isEmpty {
            Card {
                ForEach(people) { member in
                    staffRow(member)
                }
            }
        }
    }

    /// `All 14` · `🌳 6` · `🎾 4` · `Unassigned 4`. Unlike Groups' venue chips these draw
    /// the count in the label's own colour, so the count rides in the title.
    private var staffFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.tight) {
                ForEach(store.staffChips) { chip in
                    Chip(
                        chip.title.isEmpty ? "\(chip.count)" : "\(chip.title) \(chip.count)",
                        emoji: chip.icon,
                        isSelected: chip.filter == store.staffFilter,
                        metrics: .staffFilter
                    ) {
                        store.staffFilter = chip.filter
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 10)
    }

    private func staffRow(_ member: StaffMember) -> some View {
        Button {
            store.present(.staff(member.id))
        } label: {
            CardRow(verticalPadding: 10) {
                InitialsAvatar(member.initials, size: 36, tone: avatarTone(for: member.role))

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .typeStyle(.bodyStrong, color: Theme.ink)
                    Text(member.role.staffRowLabel)
                        .typeStyle(.overline, color: member.role == .trainer ? Theme.accent : Theme.inkMuted)
                }

                Spacer(minLength: 0)
                courtChip(for: member)
            }
        }
        .buttonStyle(.plain)
    }

    /// A mono chip on a plate for a court; plain grey text for `Roaming` and `—`.
    @ViewBuilder
    private func courtChip(for member: StaffMember) -> some View {
        if let assignment = member.assignment {
            Text(assignment.chip)
                .typeStyle(.mono, color: Theme.inkTertiary)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, 5)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: Radius.monoChip, style: .continuous))
        } else {
            Text(member.courtChip)
                .typeStyle(.chipCompact, color: Theme.inkGhost)
        }
    }

    private func avatarTone(for role: Role) -> AvatarTone {
        switch role {
        case .admin: .dark
        case .trainer: .tinted
        default: .neutral
        }
    }

    /// No invite flow exists yet — the honest thing is to hand over the code and say so.
    @MainActor
    private func copyInviteCode(_ camp: Camp) {
        #if canImport(UIKit)
        UIPasteboard.general.string = camp.inviteCode
        #endif
        inviteCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            inviteCopied = false
        }
    }
}

// MARK: - Previews

#Preview("Setup") {
    SetupView(store: .preview)
        .showsMockStatusBar()
}

#Preview("Setup — three venues") {
    SetupView(store: .previewAdmin)
        .showsMockStatusBar()
}
