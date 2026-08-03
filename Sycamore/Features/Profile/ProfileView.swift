//
//  ProfileView.swift
//  Sycamore
//
//  Screen 8 — Profile. A page, not a sheet: today's assignment first, then the account rows
//  people actually change, then camp switching, and the two destructive actions side by side at
//  the bottom so neither is a mis-tap away from the list above.
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

    @State private var isConfirmingDelete = false

    /// Which `ACCOUNT` row is currently open for editing, if any. The row swaps itself for an
    /// editor in place rather than pushing a screen the design does not draw.
    @State private var editingField: AccountField?
    /// The open editor's working value. Lives here, not in the store, so an abandoned edit
    /// leaves the account untouched.
    @State private var draft = ""

    #if os(iOS)
    @State private var pickedPhoto: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
            }
        }
        .background(Theme.grouped)
        .confirmationDialog(
            "Delete this account?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task { await store.deleteAccount() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Your memberships go with it. Camps you administer keep running without you.")
        }
    }

    // MARK: - Header

    /// White plate: status bar, then the 72pt photo well beside the name and role badge.
    private var header: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            HStack(spacing: 14) {
                avatarField

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.account?.displayName ?? "")
                        .typeStyle(.profileName, color: Theme.ink)

                    HStack(spacing: 6) {
                        if let role = store.role {
                            // `+.09em` — the design tracks this badge one step wider than the
                            // venue badges the style's default is set for.
                            Badge(role.displayName, trackingEm: 0.09, horizontalPadding: 7, verticalPadding: 4)
                        }
                        Text(campName)
                            .typeStyle(.metaStrong, color: Theme.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.large)

            Hairline(color: Theme.hairline)
        }
        .background(Theme.surface)
    }

    private var campName: String {
        store.camp?.name ?? store.selectedMembership?.campName ?? ""
    }

    // MARK: Photo well

    /// The design draws an `<image-slot>` here — an editable well, not a static avatar. On iOS
    /// that is a `PhotosPicker`; elsewhere the well is inert and just shows what is stored.
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
                .padding(.bottom, Spacing.section)

            SectionHeader("Account")
            accountCard
                .padding(.bottom, Spacing.section)

            SectionHeader("App")
            appCard
                .padding(.bottom, Spacing.section)

            footer
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.large)
        .padding(.bottom, Spacing.tabBarClearance)
    }

    // MARK: On today

    @ViewBuilder
    private var onTodayCard: some View {
        if let assignment = store.todayAssignment {
            Button {
                store.selectedTab = .groups
            } label: {
                CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 14) {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        // The venue's own tint token, not a guess from its emoji.
                        .fill(Theme.color(for: assignment.venueTint))
                        .frame(width: 44, height: 44)
                        .overlay(Text(assignment.venueIcon).font(.system(size: 21)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.pathLabel)
                            .typeStyle(.rowTitleLg, color: Theme.ink)
                        Text(assignment.summaryLine)
                            .typeStyle(.metaStrong, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)
                    DisclosureChevron()
                }
            }
            .buttonStyle(.plain)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline)
            )
        } else {
            Card(borderColor: Theme.accentBorder, isDivided: false) {
                CardRow(horizontalPadding: 13, verticalPadding: 14) {
                    Text("No court today")
                        .typeStyle(.rowTitleLg, color: Theme.inkMuted)
                }
            }
        }
    }

    // MARK: Account

    /// Two editable rows and one that is not. The caret on the first two is now honest: it
    /// opens the row's editor. The `Role` row keeps its lock, which is what makes the
    /// distinction readable at a glance.
    private var accountCard: some View {
        Card {
            SwiftUI.Group {
                if editingField == .email {
                    editor(for: .email)
                } else {
                    SettingRow(
                        icon: AccountField.email.icon,
                        title: AccountField.email.title,
                        detail: store.account?.email,
                        action: { beginEditing(.email) }
                    )
                }
            }

            SwiftUI.Group {
                if editingField == .emergencyPhone {
                    editor(for: .emergencyPhone)
                } else {
                    SettingRow(
                        icon: AccountField.emergencyPhone.icon,
                        title: AccountField.emergencyPhone.title,
                        detail: store.account?.emergencyPhoneDetail,
                        action: { beginEditing(.emergencyPhone) }
                    )
                }
            }

            SettingRow(
                icon: "person.text.rectangle",
                title: "Role",
                detail: roleDetail,
                // A role is granted by the camp, never taken — so this row ends in a lock.
                accessory: .lock
            )
        }
    }

    private var roleDetail: String {
        guard let role = store.role else { return "Only an admin can change this" }
        return "\(role.displayName) · only an admin can change this"
    }

    private func editor(for field: AccountField) -> some View {
        AccountFieldEditor(
            field: field,
            text: $draft,
            canSave: canSave(field),
            onCancel: { editingField = nil },
            onSave: { commit(field) }
        )
    }

    private func beginEditing(_ field: AccountField) {
        draft = field.currentValue(of: store.account) ?? ""
        editingField = field
    }

    /// Mirrors what the repository will accept, so Save is never live for a value that would
    /// be thrown away. An emergency number is optional, so clearing it is a real edit.
    private func canSave(_ field: AccountField) -> Bool {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        case .email: return value.contains("@") && value.contains(".")
        case .emergencyPhone: return true
        }
    }

    private func commit(_ field: AccountField) {
        guard var account = store.account, canSave(field) else { return }
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        // `InMemoryRepository` lowercases the address it signs you in with; match it, or the
        // same person could end up with two spellings of one account.
        case .email: account.email = value.lowercased()
        case .emergencyPhone: account.emergencyPhone = value.isEmpty ? nil : value
        }
        editingField = nil
        Task { await store.updateAccount(account) }
    }

    // MARK: App

    private var appCard: some View {
        Card {
            SettingRow(
                icon: "bell",
                title: "Notifications",
                detail: "Court assignment, approved moves",
                accessory: .toggle(
                    Binding(
                        get: { store.account?.notificationsEnabled ?? false },
                        set: { enabled in Task { await store.setNotificationsEnabled(enabled) } }
                    )
                )
            )
            SettingRow(
                icon: "arrow.left.arrow.right",
                title: "Switch camp",
                detail: store.switchCampDetail,
                action: { store.switchCamp() }
            )
            // The design draws a caret here, but gives it nowhere to go, and this app has no
            // support desk to invent one for. So the row keeps its place in the card and
            // loses the caret: it says where help actually comes from, and claims nothing.
            SettingRow(
                icon: "lifepreserver",
                title: "Help & feedback",
                detail: helpDetail,
                accessory: .plain
            )
        }
    }

    /// Derived, like every other number on this screen: whoever runs the camp you are in.
    private var helpDetail: String? {
        let name = campName
        return name.isEmpty ? nil : "Ask an admin at \(name)"
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            PrimaryButton(
                "Sign out",
                tone: .outline,
                height: nil,
                radius: Radius.input,
                font: .buttonCompact
            ) {
                Task { await store.signOut() }
            }

            PrimaryButton(
                "Delete account",
                tone: .danger,
                height: nil,
                radius: Radius.input,
                font: .buttonCompact
            ) {
                isConfirmingDelete = true
            }
        }
    }
}

// MARK: - Photo well

/// The 72pt avatar with the 26pt camera disc hung off its bottom-trailing corner.
///
/// A standalone view rather than a computed property on `ProfileView` so it can be handed to
/// `PhotosPicker`, whose label closure is `@Sendable`: its inputs are plain sendable values, so
/// the closure captures a finished view instead of reaching into main-actor state.
private struct AvatarWell: View {
    let initials: String
    let image: Image?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            SwiftUI.Group {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                } else {
                    InitialsAvatar(initials, size: 72)
                }
            }

            // 26pt blue disc with a 2.5px white ring, hung a couple of points off the corner.
            Circle()
                .fill(Theme.accent)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Theme.surface, lineWidth: BorderWidth.avatarRing))
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.surface)
                }
                .offset(x: 2, y: 2)
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Editable account fields

/// The two `ACCOUNT` rows that are the person's own to change. `Role` is not one of them,
/// which is why it is absent here and carries a lock instead of a caret.
enum AccountField: Hashable, Sendable {
    case email
    case emergencyPhone

    var icon: String {
        switch self {
        case .email: "envelope"
        case .emergencyPhone: "phone"
        }
    }

    var title: String {
        switch self {
        case .email: "Email"
        case .emergencyPhone: "Emergency phone"
        }
    }

    var placeholder: String {
        switch self {
        case .email: "you@example.com"
        case .emergencyPhone: "(310) 555-0106"
        }
    }

    func currentValue(of account: Account?) -> String? {
        switch self {
        case .email: account?.email
        case .emergencyPhone: account?.emergencyPhone
        }
    }
}

/// A row in edit mode: the same glyph column and title, with the detail line replaced by a
/// field and the caret replaced by the two buttons that resolve it.
///
/// The design never draws this state — it draws a caret and stops — so it is built out of the
/// pieces the design does specify: the sheet field's 13pt radius over the `grouped` plate, and
/// the header pill for the actions.
private struct AccountFieldEditor: View {
    let field: AccountField
    @Binding var text: String
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13, alignment: .top) {
            Image(systemName: field.icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 21)

            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(field.title)
                    .typeStyle(.rowLabel, color: Theme.ink)

                input
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.grouped,
                        in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    )

                HStack(spacing: Spacing.small) {
                    Spacer(minLength: 0)

                    Pill("Cancel", tone: .outline, horizontalPadding: 13, verticalPadding: 8, action: onCancel)

                    Pill("Save", tone: .accent, horizontalPadding: 13, verticalPadding: 8, action: onSave)
                        .disabled(!canSave)
                        // Nothing in the design describes a disabled pill; muting it is the
                        // plainest way to say "not yet" without inventing a colour.
                        .opacity(canSave ? 1 : 0.4)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private var input: some View {
        let base = TextField(
            "",
            text: $text,
            prompt: Text(field.placeholder).foregroundColor(Theme.inkFaint)
        )
        .textFieldStyle(.plain)
        .typeStyle(.fieldValue, color: Theme.ink)
        .focused($isFocused)
        .autocorrectionDisabled()
        .accessibilityLabel(field.title)
        .onSubmit { if canSave { onSave() } }

        #if os(iOS)
        return base
            .keyboardType(field == .email ? .emailAddress : .phonePad)
            .textContentType(field == .email ? .emailAddress : .telephoneNumber)
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
        #else
        return base
        #endif
    }
}

// MARK: - Setting row

/// One line of the `ACCOUNT` / `APP` cards: a muted 19pt glyph, a title with an optional
/// detail under it, and whatever closes the row on the right.
private struct SettingRow: View {
    enum Accessory {
        case chevron
        case lock
        case toggle(Binding<Bool>)
        case plain
    }

    let icon: String
    let title: String
    var detail: String?
    var accessory: Accessory = .chevron
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Theme.inkMuted)
                // The design's Phosphor glyphs are all one width; SF Symbols are not, so the
                // column is pinned to keep every title on the same left edge.
                .frame(width: 21)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .typeStyle(.rowLabel, color: Theme.ink)
                if let detail {
                    Text(detail)
                        .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                }
            }

            Spacer(minLength: 0)
            accessoryView
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            DisclosureChevron(size: 15)
        case .lock:
            DisclosureChevron(systemName: "lock", size: 15)
        case .toggle(let isOn):
            // The design's own 46×28 switch, not UIKit's 51×31. The switch carries no visible
            // text of its own, so the row lends it its title to speak.
            SycamoreToggle(isOn: isOn, label: title)
        case .plain:
            EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("Profile") {
    ProfileView(store: .preview)
        .showsMockStatusBar()
}

#Preview("Profile — admin, no court") {
    ProfileView(store: .previewAdmin)
        .showsMockStatusBar()
}
