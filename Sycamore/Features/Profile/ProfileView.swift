//
//  ProfileView.swift
//  Sycamore
//
//  `8s` — Profile. "Only what belongs to a person."
//
//  Not a tab any more. Section 8 spends all four tabs on the day itself and reaches this from
//  the avatar in every header, so it arrives as a sheet: the close disc in the corner is the
//  design's, and the swipe down is the sheet's. There is no tab bar to clear at the bottom.
//
//  The screen is three cards and two buttons. "On today" is where you are standing right now.
//  "You" is the account — the two things you can change, the one you cannot, and the switch.
//  "Camps" is the way out to `8u Manage camps` and `8t Camp settings`. Then sign out and delete,
//  side by side at the bottom so neither is a mis-tap away from the list above.
//

import SwiftUI

#if os(iOS)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProfileView: View {
    let store: AppStore

    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingDelete = false

    /// `8u`, presented from here rather than through `store.pushedScreen`.
    ///
    /// Two reasons. `PushedScreen` has no case for it, and adding one would mean editing the
    /// store. More to the point, `8u` leads with a "Signed in to" card describing the camp you
    /// are in — and `store.switchCamp()`, the other way to reach the picker, clears that camp
    /// before you have chosen anything. Presenting keeps the camp loaded, so backing out of `8u`
    /// leaves you exactly where you were.
    @State private var isManagingCamps = false

    /// Whether the emergency-number row is open for editing. It swaps itself for a field in
    /// place rather than pushing a screen the design does not draw.
    @State private var isEditingPhone = false
    /// The open editor's working value. Lives here, not in the store, so an abandoned edit
    /// leaves the account untouched.
    @State private var phoneDraft = ""

    /// Mirrors `account.notificationsEnabled`. `SycamoreToggle` wants a real binding, and a
    /// `Binding(get:set:)` built in `body` would be rebuilt on every pass; this is the state the
    /// switch drives, and `onChange` carries it to the store and back.
    @State private var notificationsEnabled: Bool

    #if os(iOS)
    @State private var pickedPhoto: PhotosPickerItem?
    #endif

    init(store: AppStore) {
        self.store = store
        self._notificationsEnabled = State(initialValue: store.account?.notificationsEnabled ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.grouped)
        .onChange(of: notificationsEnabled) { _, enabled in
            guard enabled != store.account?.notificationsEnabled else { return }
            Task { await store.setNotificationsEnabled(enabled) }
        }
        // A rejected write leaves the account as it was; follow it back so the switch never
        // shows a setting the account does not hold.
        .onChange(of: store.account?.notificationsEnabled) { _, saved in
            if let saved, saved != notificationsEnabled { notificationsEnabled = saved }
        }
        .confirmationDialog(
            "Delete this account?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                closeBeforeSigningOut()
                Task { await store.deleteAccount() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Your memberships go with it. Camps you administer keep running without you.")
        }
        .sheet(isPresented: $isManagingCamps) {
            // Sheets do not inherit this view's `store`, which arrives as an init argument
            // rather than through the environment, so `8u` is handed both.
            CampPickerView(isManagingCamps: true)
                .environment(store)
                .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
                .storeWorkingIndicator(store.isWorking)
        }
    }

    // MARK: - Header

    /// White plate: the close disc, then the 64pt photo well beside the name and role badge.
    private var header: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    CircleIconButton(
                        systemName: "xmark",
                        size: 34,
                        iconSize: 16,
                        tone: .filled,
                        foreground: Theme.ink
                    ) {
                        dismiss()
                    }
                    .accessibilityLabel("Close")
                }

                HStack(spacing: Spacing.gutterWide) {
                    avatarField

                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        Text(store.account?.displayName ?? "")
                            .typeStyle(.profileName, color: Theme.ink)

                        HStack(spacing: Spacing.tight) {
                            if let role = store.role {
                                // `+.09em` — the design tracks this badge one step wider than
                                // the venue badges the style's default is set for.
                                Badge(
                                    role.displayName,
                                    tone: .accent,
                                    trackingEm: 0.09,
                                    horizontalPadding: 10,
                                    verticalPadding: 5
                                )
                            }
                            if !campName.isEmpty {
                                Text("at \(campName)")
                                    .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Spacing.header)
            // The close disc carries its own 44pt hit frame, which is 5pt taller than the disc;
            // this is the rest of the design's 14pt above it.
            .padding(.top, Spacing.small)
            .padding(.bottom, Spacing.large)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    private var campName: String {
        store.camp?.name ?? store.selectedMembership?.campName ?? ""
    }

    // MARK: Photo well

    /// `8s` draws a plain 64pt disc here, because the mock has no photo to show. It is still the
    /// editable well the app has always had — dropping the picker would take away the only way
    /// to set a photo, which is a feature the design never asked to remove. On iOS that is a
    /// `PhotosPicker`; elsewhere the well is inert and just shows what is stored.
    private var avatarField: some View {
        // `AvatarWell` is built here, on the main actor, and captured as a value. PhotosPicker's
        // label closure is `@Sendable`, so it may not reach back into this view's main-actor
        // state — an inline `avatarWell` computed property fails to compile under Swift 6.
        let well = AvatarWell(initials: store.account?.initials ?? "", image: storedAvatar)

        #if os(iOS)
        // No `photoLibrary:` — the out-of-process picker needs no photo-library permission,
        // and the app never sees anything but the one asset the person chose.
        return PhotosPicker(selection: $pickedPhoto, matching: .images) {
            well
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change profile photo")
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        #else
        return well
        #endif
    }

    private var storedAvatar: Image? {
        guard let data = store.account?.avatarImageData else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data).map(Image.init(uiImage:))
        #elseif canImport(AppKit)
        return NSImage(data: data).map(Image.init(nsImage:))
        #else
        return nil
        #endif
    }

    #if os(iOS)
    /// Reads the picked asset into the account. Nothing leaves the device — the bytes go
    /// straight into `Account.avatarImageData`.
    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard var account = store.account,
              let data = try? await item.loadTransferable(type: Data.self)
        else { return }
        account.avatarImageData = data
        await store.updateAccount(account)
    }
    #endif

    // MARK: - Body

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("On today")
            onTodayCard
                .padding(.bottom, Spacing.large)

            SectionHeader("You")
            youCard
                .padding(.bottom, Spacing.large)

            SectionHeader("Camps")
            campsCard
                .padding(.bottom, Spacing.large)

            footer
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.large)
        // No `tabBarClearance`: this is a sheet, and it draws no tab bar.
        .padding(.bottom, Spacing.hero)
    }

    // MARK: On today

    /// Where you are standing, and nothing you can do about it from here — the design closes
    /// this card with no caret, so it is a statement rather than a control.
    private var onTodayCard: some View {
        Card(borderColor: Theme.accentBorder, isDivided: false) {
            CardRow(spacing: Spacing.medium, horizontalPadding: Spacing.gutterWide, verticalPadding: Spacing.gutterWide) {
                if let assignment = store.todayAssignment {
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        // The venue's own tint token, not a guess from its emoji.
                        .fill(Theme.color(for: assignment.venueTint))
                        .frame(width: 42, height: 42)
                        .overlay { Text(assignment.venueIcon).font(.system(size: 20)) }

                    VStack(alignment: .leading, spacing: Spacing.hairGap) {
                        Text(assignment.pathLabel)
                            .typeStyle(.bodyStrong, color: Theme.ink)
                        Text(assignment.summaryLine)
                            .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                    }
                } else {
                    Text("No court today")
                        .typeStyle(.bodyStrong, color: Theme.inkMuted)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: You

    /// One thing you are told, one you can change, one you can switch, and one that is somebody
    /// else's to grant. The endings say which is which: a value, a caret, a switch, a lock.
    private var youCard: some View {
        Card {
            // No caret, because there is nothing behind it. An address is the account's identity
            // and changing it is a re-verification, not an inline edit.
            SettingsRow("Email", accessory: .value(store.account?.email ?? "—"))

            SwiftUI.Group {
                if isEditingPhone {
                    EmergencyPhoneEditor(
                        text: $phoneDraft,
                        onCancel: { isEditingPhone = false },
                        onSave: commitPhone
                    )
                } else {
                    SettingsRow(
                        "Emergency phone",
                        subtitle: store.account?.emergencyPhoneDetail,
                        accessory: .chevron
                    ) {
                        phoneDraft = store.account?.emergencyPhone ?? ""
                        isEditingPhone = true
                    }
                }
            }

            SettingsRow("Notifications", accessory: .toggle($notificationsEnabled))

            // A role is granted by the camp, never taken — so this row ends in a lock.
            SettingsRow(
                "Your role here",
                subtitle: "Only an admin can change this",
                accessory: .lock
            )
        }
    }

    private func commitPhone() {
        guard var account = store.account else { return }
        let value = phoneDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        account.emergencyPhone = value.isEmpty ? nil : value
        isEditingPhone = false
        Task { await store.updateAccount(account) }
    }

    // MARK: Camps

    private var campsCard: some View {
        Card {
            SettingsRow(
                "Manage & switch camps",
                icon: "arrow.left.arrow.right",
                subtitle: campCountDetail,
                accessory: .chevron
            ) {
                isManagingCamps = true
            }

            SettingsRow(
                "Camp settings",
                icon: "slider.horizontal.3",
                subtitle: store.isAdmin ? nil : adminsOnlyDetail,
                accessory: store.isAdmin ? .chevron : .lock,
                action: store.isAdmin ? { store.pushedScreen = .campSettings } : nil
            )
        }
    }

    /// `2 on this account`. `store.switchCampDetail` spells the same number "2 camps on this
    /// account", which is the sentence the row used to be; under a title that already says
    /// "camps" the design drops the word.
    private var campCountDetail: String {
        let count = store.memberships.count
        return "\(count) on this account"
    }

    /// `Admins only · ask Nass or Hubert` — derived, like every other name on this screen, from
    /// who actually administers the camp you are in.
    private var adminsOnlyDetail: String {
        let names = (store.camp?.staff ?? []).filter(\.role.isAdmin).map(\.name)
        // Two, because a row is one line and a camp can have a dozen admins.
        let asked = Array(names.prefix(2))
        guard !asked.isEmpty else { return "Admins only" }
        return "Admins only · ask \(asked.formatted(.list(type: .or)))"
    }

    // MARK: Footer

    /// `signOut()` clears `activeSheet` but not `pushedScreen` — it was written before this
    /// screen was one. Without this the store would still be holding `.profile` when the next
    /// person signs in, and their first camp would open with a stranger's Profile over it.
    private func closeBeforeSigningOut() {
        isManagingCamps = false
        store.pushedScreen = nil
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            PrimaryButton(
                "Sign out",
                tone: .outline,
                height: nil,
                radius: Radius.row,
                font: .buttonCompact
            ) {
                closeBeforeSigningOut()
                Task { await store.signOut() }
            }

            PrimaryButton(
                "Delete account",
                tone: .danger,
                height: nil,
                radius: Radius.row,
                font: .buttonCompact
            ) {
                isConfirmingDelete = true
            }
        }
    }
}

// MARK: - Photo well

/// The 64pt avatar with the camera disc hung off its bottom-trailing corner.
///
/// A standalone view rather than a computed property on `ProfileView` so it can be handed to
/// `PhotosPicker`, whose label closure is `@Sendable`: its inputs are plain sendable values, so
/// the closure captures a finished view instead of reaching into main-actor state.
private struct AvatarWell: View {
    let initials: String
    let image: Image?

    private let diameter: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            SwiftUI.Group {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                } else {
                    InitialsAvatar(initials, size: diameter)
                }
            }

            // 24pt accent disc with a 2.5px ring in the surface colour, hung a couple of points
            // off the corner. The only mark on this screen the design does not draw — it is what
            // says the disc is a well rather than a picture.
            Circle()
                .fill(Theme.accent)
                .frame(width: 24, height: 24)
                .overlay { Circle().strokeBorder(Theme.surface, lineWidth: BorderWidth.avatarRing) }
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.onAccent)
                }
                .offset(x: 2, y: 2)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Emergency phone editor

/// The emergency-number row in edit mode: the same title, with the detail line replaced by a
/// field and the caret replaced by the two buttons that resolve it.
///
/// The design never draws this state — it draws a caret and stops — so it is built out of the
/// pieces the design does specify: the sheet field's 13pt radius over the `grouped` plate, and
/// the header pill for the actions.
private struct EmergencyPhoneEditor: View {
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13, alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Emergency phone")
                    .typeStyle(.rowLabel, color: Theme.ink)

                input
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.grouped,
                        in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    )

                HStack(spacing: Spacing.small) {
                    Spacer(minLength: 0)
                    Pill("Cancel", tone: .outline, horizontalPadding: 13, verticalPadding: 8, action: onCancel)
                    // An emergency number is optional, so clearing it is a real edit and Save is
                    // always live.
                    Pill("Save", tone: .accent, horizontalPadding: 13, verticalPadding: 8, action: onSave)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private var input: some View {
        let base = TextField(
            "",
            text: $text,
            prompt: Text(verbatim: "(310) 555-0106").foregroundStyle(Theme.inkFaint)
        )
        .textFieldStyle(.plain)
        .typeStyle(.fieldValue, color: Theme.ink)
        .focused($isFocused)
        .autocorrectionDisabled()
        .accessibilityLabel("Emergency phone")
        .onSubmit(onSave)

        #if os(iOS)
        return base
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
        #else
        return base
        #endif
    }
}

// MARK: - Previews

/// The state the design draws: a worker, so "Camp settings" is locked and the row names the two
/// people who can open it.
#Preview("8s Profile — worker") {
    ProfileView(store: .preview)
        .showsMockStatusBar()
}

/// The same person at the camp they administer: "Camp settings" unlocks, and there is no court
/// to stand on, so "On today" says so.
#Preview("8s Profile — admin, no court") {
    ProfileView(store: .previewAdmin)
        .showsMockStatusBar()
}
