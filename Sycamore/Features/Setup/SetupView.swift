//
//  SetupView.swift
//  Sycamore
//
//  `8t` — Camp settings. "Admin only."
//
//  It was the Setup tab until section 8 gave all four tabs to the day itself; now it is reached
//  from Profile's "Camp settings" row and arrives as a sheet over it. The back disc in the
//  corner therefore goes back to `8s` rather than out — the design draws an arrow, and Profile
//  is what it points at.
//
//  Three blocks, in the order somebody setting up a camp needs them: where the camp happens,
//  who is in it and how they get in, and the season itself.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SetupView: View {

    let store: AppStore

    /// The design gives "Invite" no destination, so it hands over the code and says so.
    @State private var inviteCopied = false

    /// Expanding the staff list is decoration — the rows are all still reachable — so it is the
    /// first thing to go when the reader has asked for less movement.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The design's `padding:14px 22px 18px`, less the 4pt the back disc's 44pt hit frame hangs
    /// above its 36pt circle.
    private let headerTop: CGFloat = 10
    private let headerBottom: CGFloat = 18

    /// The 40pt plate on a venue row. Grows with the reader's type so it keeps its proportion to
    /// the two lines of copy beside it.
    @ScaledMetric(relativeTo: .body) private var venueTileSize: CGFloat = 40

    /// `8t` collapses the whole staff list into one summary row with a caret. There is no staff
    /// screen to send that caret to and no `PushedScreen` case to reach one, so the row opens
    /// the list in place — which is also what keeps the staff sheet reachable.
    @State private var isShowingStaff = false

    init(store: AppStore) {
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !store.isAdmin {
                locked
            } else if let camp = store.camp {
                content(for: camp)
            } else {
                // No camp loaded is not a permission problem, and saying so would be a lie.
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8` — the same warm page as `8s`, which this arrives on top of.
        .background(Theme.surfaceWarm)
        // The copy has no visible confirmation beyond the word "Copied" swapping in, which a
        // reader looking at the code rather than the header will miss.
        .sensoryFeedback(.success, trigger: inviteCopied) { _, copied in copied }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.small) {
                    CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled) {
                        // Back means Profile, which is where this screen was opened from.
                        store.pushedScreen = .profile
                    }
                    .accessibilityLabel("Back to your profile")

                    Spacer(minLength: 0)

                    if store.isAdmin { adminBadge }
                }

                Text("Camp settings")
                    .typeStyle(.screenTitle, color: Theme.ink)
                    // `margin-top:15px`, less the same 4pt of hit-frame overhang.
                    .padding(.top, Spacing.row)

                Text(subtitle)
                    .typeStyle(.headerDetail, color: Theme.inkMuted)
                    .padding(.top, Spacing.tight)
            }
            .padding(.horizontal, Spacing.header)
            .padding(.top, headerTop)
            .padding(.bottom, headerBottom)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    /// `UCLA Tennis Camp · 2 venues · 100 kids`, every figure derived from the graph.
    private var subtitle: String {
        guard let camp = store.camp else { return "" }
        return "\(camp.name) · \(camp.summaryLine)"
    }

    /// The shield pill in the corner — the same capsule as `8s`'s role pill, with the glyph that
    /// makes it read as a permission rather than a job title.
    private var adminBadge: some View {
        AccentPill(
            "Admin",
            systemImage: "checkmark.shield.fill",
            horizontalPadding: Spacing.row,
            verticalPadding: Spacing.tight
        )
    }

    // MARK: - Not an admin

    /// Profile locks the row that opens this screen, so nobody should arrive here without the
    /// permission. If they do — a role changed underneath them, say — the screen says so rather
    /// than drawing an empty shell.
    private var locked: some View {
        ContentUnavailableView {
            Label("Admins only", systemImage: "lock")
        } description: {
            Text("Your role at this camp comes from the camp. Ask an admin to change it.")
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Body

    private func content(for camp: Camp) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                venuesSection(camp)
                    .padding(.bottom, Spacing.cardStack)

                staffSection(camp)
                    .padding(.bottom, Spacing.cardStack)

                seasonSection(camp)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            // No `tabBarClearance`: this is a sheet, and it draws no tab bar.
            .padding(.bottom, Spacing.sheetFoot)
        }
    }

    // MARK: Venues & courts

    /// A `VStack` rather than a bare `@ViewBuilder` pair: the caller pads the whole block, and a
    /// `TupleView` under a padding modifier is no longer something the enclosing stack unrolls.
    private func venuesSection(_ camp: Camp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Venues & courts", actionTitle: "Add") {
                Task { await store.addVenue() }
            }

            Card(radius: Radius.settingsCard) {
                ForEach(camp.orderedVenues) { venue in
                    venueRow(venue, in: camp)
                }

                // The design closes this row with a caret. It goes nowhere — it partitions the
                // camp on the spot — so it keeps its place in the card and loses the caret, the
                // same call the old "Help & feedback" row got.
                SettingsRow(
                    "Partition by rank",
                    icon: "shuffle",
                    iconColor: Theme.accent,
                    subtitle: "Fills every court inside its limits",
                    accessory: .plain
                ) {
                    Task { await store.partitionCamp() }
                }
            }
        }
    }

    /// Tile, name, headcount and a stepper for the venue's courts. The left of the row opens the
    /// venue sheet; the stepper on the right is its own control and does not.
    private func venueRow(_ venue: Venue, in camp: Camp) -> some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            Button {
                store.present(.venue(venue.id))
            } label: {
                HStack(spacing: Spacing.row) {
                    // The venue's own tint, with the design's generic pin on it. `8t` lists
                    // several venues at once, so the plate is what tells them apart.
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .fill(Theme.color(for: venue.tint))
                        .frame(width: venueTileSize, height: venueTileSize)
                        .overlay {
                            Image(systemName: "mappin")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.hairGap) {
                        HStack(spacing: Spacing.nameBadge) {
                            Text(venue.name)
                                .typeStyle(.cardTitleSm, color: Theme.ink)
                                .lineLimit(1)
                            // Only when it needs someone: `8t` flags the short venue and leaves
                            // the healthy one clean.
                            if let flag = camp.staffingStatus(for: venue.id)?.flagText {
                                // The stepper on the right is most of this row, so the line is
                                // narrow. The flag holds its width and the name gives way —
                                // a truncated "2 shor…" would say nothing.
                                StaffingFlag(flag)
                                    .fixedSize()
                            }
                        }
                        Text(headcount(for: venue, in: camp))
                            .typeStyle(.detailSm, color: Theme.inkMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Spacing.small)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            VenueCourtStepper(venue: venue) { courts in
                setCourts(courts, for: venue)
            }
        }
    }

    /// A court count is a write to the whole camp, so it goes back through the store rather than
    /// being mutated in place.
    private func setCourts(_ courts: Int, for venue: Venue) {
        var updated = venue
        updated.groupCount = courts
        Task { await store.updateVenue(updated) }
    }

    /// `50 kids · 6 coaches`. The court count moved to the stepper, so unlike `Camp.rowSummary`
    /// this line does not repeat it.
    private func headcount(for venue: Venue, in camp: Camp) -> String {
        let kids = camp.players(in: venue.id).count
        let coaches = camp.coachCount(in: venue.id)
        return "\(kids) kids · \(coaches) coach\(coaches == 1 ? "" : "es")"
    }

    // MARK: Staff & joining

    private func staffSection(_ camp: Camp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Staff & joining", actionTitle: inviteCopied ? "Copied" : "Invite") {
                copyInviteCode(camp)
            }

            Card(radius: Radius.settingsCard) {
                staffSummaryRow(camp)

                if isShowingStaff {
                    staffFilters
                    ForEach(store.filteredStaff) { member in
                        staffRow(member)
                    }
                }

                SettingsRow(
                    "Invite code",
                    subtitle: "Anyone with it joins as a worker",
                    accessory: .code(camp.inviteCode)
                )
                // Spelt out, so VoiceOver reads "S Y C 4 8 2 1" rather than trying the whole
                // thing as a word. A code is only useful character by character.
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Invite code, \(spelled(camp.inviteCode))")
                .accessibilityHint("Anyone with it joins as a worker")

                // Drawn, but inert, the same way `8f`'s "Add the first block" is: rolling a code
                // is a write to the camp, and the repository has no camp write to make it with.
                // It gets no action rather than a dead button, and it will get the confirmation
                // dialog "Delete account" uses the moment there is something to confirm.
                SettingsRow(
                    "Roll a new code",
                    accessory: .glyph("arrow.triangle.2.circlepath")
                )
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// `SYC-4821` -> `S Y C - 4 8 2 1`. Spacing the characters is what makes a speech synthesiser
    /// read them out rather than attempt them as a word.
    private func spelled(_ code: String) -> String {
        code.map(String.init).joined(separator: " ")
    }

    /// The three faces, the count, and what the count is made of. Tapping opens the list under
    /// it rather than pushing a screen that does not exist yet.
    private func staffSummaryRow(_ camp: Camp) -> some View {
        Button(action: toggleStaffList) {
            CardRow(spacing: Spacing.row) {
                StaffAvatarStack(members: Array(camp.staff.prefix(3)))

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text("\(camp.staffCount) staff")
                        .typeStyle(.cardTitleSm, color: Theme.ink)
                    Text(staffBreakdown(camp))
                        .typeStyle(.detailSm, color: Theme.inkMuted)
                }

                Spacer(minLength: Spacing.small)
                DisclosureChevron(
                    systemName: isShowingStaff ? "chevron.down" : "chevron.right",
                    size: 15
                )
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(camp.staffCount) staff, \(staffBreakdown(camp))")
        .accessibilityHint(isShowingStaff ? "Hides the list" : "Shows the list")
        // The caret flips to say the list is open. `AccessibilityTraits` has no expansion trait,
        // so the state rides in the value instead — otherwise the row sounds identical either way.
        .accessibilityValue(isShowingStaff ? "Expanded" : "Collapsed")
    }

    /// The rows arrive either way; only the sliding is optional.
    private func toggleStaffList() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            isShowingStaff.toggle()
        }
    }

    /// `2 admins · 4 unassigned`
    private func staffBreakdown(_ camp: Camp) -> String {
        let admins = camp.staff.count { $0.role.isAdmin }
        let unassigned = camp.unassignedStaff().count
        return "\(admins) admin\(admins == 1 ? "" : "s") · \(unassigned) unassigned"
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
            .padding(.horizontal, 13)
            .padding(.vertical, Spacing.row)
        }
        .scrollIndicators(.hidden)
    }

    private func staffRow(_ member: StaffMember) -> some View {
        Button {
            store.present(.staff(member.id))
        } label: {
            CardRow(verticalPadding: 10) {
                InitialsAvatar(member.initials, size: 36, tone: avatarTone(for: member.role))

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(member.name)
                        .typeStyle(.bodyStrong, color: Theme.ink)
                    Text(member.role.staffRowLabel)
                        .typeStyle(.overline, color: member.role == .trainer ? Theme.accent : Theme.inkMuted)
                }

                Spacer(minLength: Spacing.small)
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

    // MARK: Season

    private func seasonSection(_ camp: Camp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Season")

            Card(radius: Radius.settingsCard) {
                // Both rows are drawn and inert for the same reason as "Roll a new code":
                // renaming a camp and archiving one are camp writes, and the repository has
                // neither. The design closes both with a caret; neither has anywhere to send it,
                // so neither keeps it.
                SettingsRow("Camp name & sport", accessory: .value(camp.sport.displayName))
                    .accessibilityElement(children: .combine)

                SettingsRow(
                    "Archive this camp",
                    accessory: .plain,
                    titleColor: Theme.danger
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Previews

/// The camp the design draws, seen by someone who can change it — Alex coaches at UCLA, so the
/// membership is promoted here rather than switching to a different camp.
#Preview("8t Camp settings") {
    let store = AppStore.preview
    var membership = SampleData.uclaMembership
    membership.role = .admin
    store.selectedMembership = membership

    return SetupView(store: store)
        .showsMockStatusBar()
}

#Preview("8t Camp settings — three venues") {
    SetupView(store: .previewAdmin)
        .showsMockStatusBar()
}

/// The camp the design draws — but Alex is a worker there, so the screen refuses.
#Preview("8t Camp settings — not an admin") {
    SetupView(store: .preview)
        .showsMockStatusBar()
}
