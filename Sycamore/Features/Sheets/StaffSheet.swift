//
//  StaffSheet.swift
//  Sycamore
//
//  Screen 12 — tap a staff member. The phone number lives here rather than in Setup's list,
//  because this is where you go when you actually need to reach someone.
//

import SwiftUI

struct StaffSheet: View {
    let store: AppStore
    let staffID: StaffMember.ID

    @Environment(\.openURL) private var openURL

    @State private var isConfirmingRemoval = false

    var body: some View {
        SheetChrome(
            title: member?.name ?? "",
            subtitle: member?.detailLine,
            avatarInitials: member?.initials ?? "",
            avatarTone: avatarTone,
            detentFraction: ActiveSheet.staff(staffID).detentFraction,
            onClose: { store.dismissSheet() }
        ) {
            callCard
                .padding(.bottom, 18)

            SheetSectionHeader("Role")
            roleChips
                .padding(.bottom, 20)

            SheetSectionHeader("On today")
            courtChips
                .padding(.bottom, 20)

            removeButton
        }
        .confirmationDialog(
            "Remove \(member?.name ?? "this person") from the camp?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove from camp", role: .destructive) {
                Task { await store.removeStaff(staffID) }
            }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("Their court is freed up. Kids and rankings are untouched.")
        }
    }

    private var member: StaffMember? { store.staffMember(staffID) }

    /// Setup's list gives admins a black disc and the roaming trainer a blue one; the sheet
    /// keeps the same reading so a person looks like themselves in both places.
    private var avatarTone: AvatarTone {
        switch member?.role {
        case .admin: .dark
        case .trainer: .tinted
        default: .neutral
        }
    }

    // MARK: - Call

    @ViewBuilder
    private var callCard: some View {
        if let phone = member?.phone, !phone.isEmpty {
            Button(action: call) {
                HStack(spacing: Spacing.row) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(phone)
                            .typeStyle(.rowTitle, color: Theme.accentDark)
                        Text("Tap to call in an emergency")
                            .typeStyle(.metaSmall, color: Theme.accentMuted)
                    }

                    Spacer(minLength: 0)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                // The plate is the target, not the two runs of text drawn on it.
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(phoneURL == nil)
        }
    }

    /// `tel:` wants bare digits — the model stores the number the way a person reads it.
    private var phoneURL: URL? {
        guard let phone = member?.phone else { return nil }
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private func call() {
        guard let phoneURL else { return }
        #if os(iOS)
        openURL(phoneURL)
        #endif
    }

    // MARK: - Role

    private var roleChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Role.selectable, id: \.self) { role in
                Chip(
                    role.chipTitle,
                    isSelected: member?.role.matchesChip(role) == true,
                    selectedTone: .dark,
                    metrics: .role,
                    fillsWidth: true
                ) {
                    Task { await store.setRole(role, forStaff: staffID) }
                }
            }
        }
    }

    // MARK: - On today

    private var courtChips: some View {
        FlowLayout(horizontalSpacing: Spacing.tight, verticalSpacing: Spacing.tight) {
            Chip(
                "No court",
                isSelected: member?.groupID == nil,
                selectedTone: .accent,
                metrics: .court
            ) {
                Task { await store.assignStaff(staffID, toGroup: nil) }
            }

            ForEach(store.allCourts) { court in
                Chip(
                    store.courtChipLabel(court),
                    isSelected: member?.groupID == court.id,
                    selectedTone: .accent,
                    metrics: .court
                ) {
                    Task { await store.assignStaff(staffID, toGroup: court.id) }
                }
            }
        }
    }

    // MARK: - Remove

    private var removeButton: some View {
        PrimaryButton(
            "Remove from camp",
            tone: .danger,
            height: nil,
            radius: Radius.row,
            font: .buttonCompact
        ) {
            isConfirmingRemoval = true
        }
    }
}

// MARK: - Previews

#Preview("Staff sheet") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        StaffSheet(store: .preview, staffID: SampleData.alexStaff.id)
            .frame(height: 512)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Staff sheet — roaming trainer") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        StaffSheet(store: .preview, staffID: SampleData.dana.id)
            .frame(height: 512)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
