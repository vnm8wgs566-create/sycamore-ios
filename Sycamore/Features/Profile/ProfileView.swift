//
//  ProfileView.swift
//  Sycamore
//
//  `8s` — Profile. "Only what belongs to a person."
//
//  Not a tab any more. Section 8 spends all four tabs on the day itself and reaches this from
//  the avatar in every header, so it arrives as a sheet, and the swipe down is the sheet's.
//
//  **The close disc is the app's, and this used to say it was the design's.** No surviving design
//  draws one: `Sycamore Flow.dc.html:337-388` draws Profile as a full page under the floating tab
//  bar with no ✕ and no back control, because it was a tab, and `SPEC.md:218` and `:262` both say
//  "Profile is a page, not a sheet" in as many words. The design of record goes further and draws
//  no profile screen at all — `openProfile` (`design/app/state1.js:42`) opens the *camp* page, and
//  the only account facts in the whole prototype are a signed-in email and a Sign out row on it.
//
//  So this screen is an addition, the sheet is an addition, and the disc is the sheet's way out.
//  All three are worth keeping — the app has an editable name, an emergency phone, a notification
//  switch and a delete-account path, none of which the prototype has anywhere to put — but they
//  are the app's decisions, and a comment claiming a drawing behind them is the one thing that
//  makes them impossible to re-examine. The same correction applies to `AvatarWell` below.
//
//  The screen is three cards and two buttons. "On today" is where you are standing right now.
//  "You" is the account — the things you can change, the one you cannot, the switch, and the one
//  that is somebody else's to grant. "Camps" is the way out to `8u Manage camps` and `8t Camp
//  settings`. Then sign out and delete, side by side at the bottom so neither is a mis-tap away
//  from the list above.
//
//  Your name is the newest of the things you can change, and it is the one that had been missing.
//  The header has always drawn it in 26pt serif with "No name yet" behind it, and there was
//  nowhere in the app to answer that — `Account.displayName` was written once, by Apple, on the
//  first authorisation an Apple ID ever gives (`AppStore.swift:766-772`), and an account created
//  by email had no name at all. It edits in place through `InlineRowEditor`, the same box the
//  emergency number opens, rather than pushing a screen the design does not draw.
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
    @State private var isConfirmingSignOut = false

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

    /// The same, for the name. Two flags rather than one `editingRow` enum: they are answered by
    /// two different rows and nothing needs them to be mutually exclusive — a person who opened
    /// both and then typed in one has done nothing wrong, and closing the other for them would be
    /// the screen taking a decision it was not asked for.
    @State private var isEditingName = false

    /// Mirrors `account.notificationsEnabled`. `SycamoreToggle` wants a real binding, and a
    /// `Binding(get:set:)` built in `body` would be rebuilt on every pass; this is the state the
    /// switch drives, and `onChange` carries it to the store and back.
    @State private var notificationsEnabled: Bool

    #if os(iOS)
    @State private var pickedPhoto: PhotosPickerItem?
    #endif

    /// `height:46px` on the two footer buttons. Scaled rather than pinned: at `.accessibility1`
    /// a 14pt label in a 46pt box is already close, and a reader who has asked for larger type
    /// gets a taller button rather than a clipped one.
    @ScaledMetric(relativeTo: .body) private var footerButtonHeight: CGFloat = 46

    /// The design's 64pt photo well. It holds text — two initials — so it grows with the reader's
    /// type rather than clipping them.
    @ScaledMetric(relativeTo: .title2) private var avatarDiameter: CGFloat = 64

    /// The 42pt plate on the "On today" card, which holds a glyph rather than text but sits on
    /// the same line as two rows of copy; pinning it makes the card lopsided at large sizes.
    @ScaledMetric(relativeTo: .body) private var todayTileSize: CGFloat = 42

    /// The design's `padding:10px 22px 20px` on the white plate, less the 5pt the close disc's
    /// 44pt hit frame already hangs above its 34pt circle. Measuring to the disc rather than to
    /// the frame is what keeps the drawn result identical to the design.
    private let headerTop: CGFloat = 5
    private let headerBottom: CGFloat = 20

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
        // `#F8F9F8`. Section 8's page is a shade warmer than `grouped`, which is the blue-grey
        // the stage-1 screens sit on.
        .background(Theme.surfaceWarm)
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
            // Its own sentence. This shared one word for word with the camp page's **sign out**
            // dialog, so the most destructive control in the app and the most ordinary one made
            // the same promise — and the ordinary one's promise is the reassuring half.
            //
            // True, too, which the old one was not about this. `deleteAccount` deletes the
            // `profiles` row and signs out; it cannot touch `auth.users`, which needs the service
            // role and does not belong in a shipped binary. So the login survives, and signing in
            // again with the same address builds a fresh, empty profile. Saying "your account is
            // deleted" without saying that would leave somebody expecting the address to stop
            // working.
            Text(
                "Your name, phone and camp memberships are deleted for good. "
                + "The email address can still sign in, and would start over with nothing."
            )
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive, action: reallySignOut)
            Button("Stay signed in", role: .cancel) {}
        } message: {
            // Word for word the camp page's, because it is word for word the same action. Two
            // doors to one thing should not describe it two ways.
            Text("Your memberships go with it. Camps you administer keep running without you.")
        }
        .sheet(isPresented: $isManagingCamps) {
            // Sheets do not inherit this view's `store`, which arrives as an init argument
            // rather than through the environment, so `8u` is handed both it and the banner.
            CampPickerView(isManagingCamps: true)
                .environment(store)
                .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
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
                        // `popPushed` rather than `dismiss()`: this screen is often opened *from*
                        // the camp page, and dismissing the sheet dropped the reader on a tab
                        // because the one `pushedScreen` slot had already lost the page
                        // underneath. Popping puts back whatever this covered, and covering
                        // nothing still ends at the tabs.
                        store.popPushed()
                    }
                    .accessibilityLabel("Close")
                }

                HStack(spacing: Spacing.gutterWide) {
                    avatarField

                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        Text(displayName)
                            .typeStyle(.personName, color: Theme.ink)
                            .lineLimit(2)

                        HStack(spacing: Spacing.nameBadge) {
                            // A capsule, not a `Badge` — the design draws this at radius 99 in
                            // `600 10`, where `Badge` is a radius-5 chip in `700 9.5`.
                            if let role = store.role {
                                AccentPill(role.displayName)
                            }
                            if !campName.isEmpty {
                                Text("at \(campName)")
                                    .typeStyle(.detail, color: Theme.inkMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    // The name and what qualifies it are one thought. Scoped to this stack rather
                    // than to the row: combining the row would swallow the photo picker beside it.
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Spacing.header)
            .padding(.top, headerTop)
            .padding(.bottom, headerBottom)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    private var campName: String {
        store.camp?.name ?? store.selectedMembership?.campName ?? ""
    }

    /// The account is real — you cannot reach this screen without one — but the row behind it in
    /// `profiles` may not have been written yet, in which case `displayName` is the empty string.
    /// An empty headline draws as a gap the size of a missing name, which reads as a rendering
    /// fault; this says which of the two it is.
    private var displayName: String {
        let name = store.account?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "No name yet" : name
    }

    /// Same reasoning as `displayName`. The row is a value with no caret, so an empty one would
    /// be a title against blank space rather than a line saying nothing is stored.
    private var emailValue: String {
        let email = store.account?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return email.isEmpty ? "Not set" : email
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
        let well = AvatarWell(
            initials: store.account?.initials ?? "",
            image: storedAvatar,
            diameter: avatarDiameter
        )

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
    /// Reads the picked asset, cuts it down to something worth sending, and saves it.
    ///
    /// **The bytes do leave the device now**, and this comment used to say they did not — they go
    /// to the `avatars` bucket, one private folder per person, and the URL goes in
    /// `profiles.avatar_url`. Before that bucket existed the photo lived in memory and was gone at
    /// the next launch.
    ///
    /// ── Which is why it is re-encoded, and not merely resized ─────────────────────────────────
    ///
    /// What the picker hands over is the original asset: a current iPhone shoots 12 MP HEIC at
    /// 3–8 MB. Three separate things refuse that. The bucket caps an object at 2 MiB. Its
    /// `allowed_mime_types` does list HEIC, but the upload declares `image/jpeg` and a declared
    /// type that disagrees with the bytes is a lie somebody debugs later. And 8 MB up a camp's
    /// wifi to draw a 64pt disc is a minute of somebody's morning for no pixels.
    ///
    /// 512 on the long edge at quality 0.8 lands around 60–100 KiB — four times the disc's size at
    /// 3× so it stays sharp on every phone, and small enough that the upload is not something you
    /// wait for. `UIGraphicsImageRenderer` handles the orientation flags a HEIC carries, which a
    /// naive `CGContext` draw would leave sideways.
    ///
    /// A failure at any step leaves the account untouched rather than writing half of one.
    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard var account = store.account,
              let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = Self.thumbnail(from: data)
        else { return }
        account.avatarImageData = jpeg
        await store.updateAccount(account)
    }

    /// `512`px on the long edge, JPEG at `0.8`. Nil for bytes that are not an image at all.
    ///
    /// `static` and free of any view state so it can be called from the `@Sendable` context above
    /// without capturing `self` — the same constraint `AvatarWell` exists for.
    private static func thumbnail(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longEdge = max(image.size.width, image.size.height)
        // Already small enough: re-encoding it would only lose a generation of quality.
        guard longEdge > avatarMaxEdge else { return image.jpegData(compressionQuality: 0.8) }

        let scale = avatarMaxEdge / longEdge
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        .jpegData(compressionQuality: 0.8)
    }

    /// Four times the 64pt well at 3×, which keeps it sharp on every phone the app runs on and
    /// still lands two orders under the bucket's 2 MiB ceiling.
    private static let avatarMaxEdge: CGFloat = 512
    #endif

    // MARK: - Body

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("On today")
            onTodayCard
                .padding(.bottom, Spacing.cardStack)

            SectionHeader("You")
            youCard
                .padding(.bottom, Spacing.cardStack)

            SectionHeader("Camps")
            campsCard
                .padding(.bottom, Spacing.cardStack)

            footer
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.large)
        // No `tabBarClearance`: this is a sheet, and it draws no tab bar.
        .padding(.bottom, Spacing.sheetFoot)
    }

    // MARK: On today

    /// Where you are standing, and nothing you can do about it from here — the design closes
    /// this card with no caret, so it is a statement rather than a control.
    private var onTodayCard: some View {
        Card(radius: Radius.settingsCard, borderColor: Theme.accentBorder, isDivided: false) {
            CardRow(spacing: Spacing.medium, horizontalPadding: Spacing.gutterWide, verticalPadding: Spacing.gutterWide) {
                if let assignment = store.todayAssignment {
                    // The venue's own emoji on the venue's own tint. The design draws this card
                    // at `design/Sycamore Flow.dc.html:357` with
                    // `background:#F1F5EC;font-size:21px` and 🌳 on it — `#F1F5EC` is
                    // `Theme.color(for: .moss)`, so the plate is the venue's tint, not the
                    // accent's.
                    //
                    // It was a pin on `accentSurface` inside an `accentSurfaceBorder` stroke, on
                    // the argument that `8t` tints per venue because it lists several while this
                    // card lists one that the line beside it already names. The argument is
                    // sound and the drawing was still wrong: `8s.html` and `8t.html` are absent
                    // from this repository and always have been, so neither the pin nor the
                    // green plate could be checked against anything, and the design that is here
                    // draws this card's tile in moss with a tree on it. `TodayAssignment` has
                    // carried `venueIcon` and `venueTint` the whole time — the latter documented
                    // as "what Profile's icon tile reads" (`Models.swift:617`) — and this is the
                    // tile that was not reading them.
                    //
                    // The stroke goes with the pin. In the design the `#C9DDFB` border belongs
                    // to the card, which `Card(borderColor: Theme.accentBorder)` above already
                    // draws; the tile inside it carries no border at all.
                    //
                    // Both halves come off `TodayAssignment` rather than one of them being
                    // looked up live, so the emoji and the name under it are the same snapshot
                    // and cannot disagree with each other. That the snapshot itself can go stale
                    // — `Camp.reindex()` does not refresh the `CourtAssignment` copies a venue
                    // rename or an icon change leaves behind — is older than this tile and shows
                    // in `pathLabel` already. It belongs to `Models.swift`, not here.
                    // Through `IntakeIconTile`, which holds the plate, both `@ScaledMetric`s and
                    // the hiding. Hidden matters here for a second reason: the whole card is
                    // combined into one sentence below and `pathLabel` names the venue in it, so
                    // a read emoji would be a second, wordier name for the same place.
                    IntakeIconTile(
                        emoji: assignment.venueIcon,
                        size: 42,
                        glyphSize: 20,
                        fill: Theme.color(for: assignment.venueTint)
                    )

                    VStack(alignment: .leading, spacing: Spacing.hairGap) {
                        Text(assignment.pathLabel)
                            .typeStyle(.cardTitle, color: Theme.ink)
                        Text(assignment.summaryLine)
                            .typeStyle(.detail, color: Theme.inkMuted)
                    }
                } else {
                    Text("No court today")
                        .typeStyle(.cardTitle, color: Theme.inkMuted)
                }

                Spacer(minLength: 0)
            }
        }
        // A statement, not a control: read it as one sentence.
        .accessibilityElement(children: .combine)
    }

    // MARK: You

    /// Two things you can change, one you are told, one you can switch, and one that is somebody
    /// else's to grant. The endings say which is which: a caret, a value, a switch, a lock.
    ///
    /// The name is the newest row and it leads, because it is the line the header above draws in
    /// 26pt serif — the first thing on the screen, and until now the only thing on it nobody
    /// could change. It was written once, by Apple, on the first authorisation an Apple ID ever
    /// gives the app (`AppStore.swift:766-772`), and never again: a person who signed in by email
    /// had no name at all and read "No name yet" under their own initials with nothing to tap.
    private var youCard: some View {
        Card(radius: Radius.settingsCard) {
            SwiftUI.Group {
                if isEditingName {
                    // Seeded from the account it is handed, the same as the phone row below —
                    // there is no draft on this view for either of them.
                    InlineRowEditor(
                        title: "Your name",
                        field: .name,
                        value: store.account?.displayName ?? "",
                        onCancel: { isEditingName = false },
                        onSave: commitName
                    )
                } else {
                    SettingsRow(
                        "Your name",
                        subtitle: nameDetail,
                        accessory: .chevron
                    ) {
                        isEditingName = true
                    }
                }
            }

            // No caret, because there is nothing behind it. An address is the account's identity
            // and changing it is a re-verification, not an inline edit.
            SettingsRow("Email", accessory: .value(emailValue))
                .accessibilityElement(children: .combine)

            SwiftUI.Group {
                if isEditingPhone {
                    // Seeded from the account it is handed, so the row no longer has to prime a
                    // draft before opening the editor — it is rebuilt each time it appears.
                    InlineRowEditor(
                        title: "Emergency phone",
                        field: .emergencyPhone,
                        value: store.account?.emergencyPhone ?? "",
                        onCancel: { isEditingPhone = false },
                        onSave: commitPhone
                    )
                } else {
                    SettingsRow(
                        "Emergency phone",
                        subtitle: store.account?.emergencyPhoneDetail,
                        accessory: .chevron
                    ) {
                        isEditingPhone = true
                    }
                }
            }

            // Left uncombined on purpose: the switch is the only control in the row, and merging
            // it into its own label would take away the thing VoiceOver has to flip.
            SettingsRow("Notifications", accessory: .toggle($notificationsEnabled))

            // A role is granted by the camp, never taken — so this row ends in a lock.
            SettingsRow(
                "Your role here",
                subtitle: "Only an admin can change this",
                accessory: .lock
            )
            // The lock is a bare glyph and says nothing aloud, so the state is spoken instead —
            // otherwise this reads exactly like the rows above it, which *can* be changed.
            .accessibilityElement(children: .combine)
            .accessibilityValue(roleValue)
        }
    }

    /// What the locked row is worth saying: the role it is holding, and that it is holding it.
    private var roleValue: String {
        guard let role = store.role else { return "Locked" }
        return "\(role.displayName), locked"
    }

    /// What the closed row says under "Your name" — the name itself, or the absence of one.
    ///
    /// The header above says "No name yet" in the place a name goes, which is a statement; this
    /// is under a caret, so it is an instruction. Different sentences for the same fact on
    /// purpose: the two rows are read in different moods.
    private var nameDetail: String {
        let name = store.account?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Add one · how the camp sees you" : name
    }

    /// Trimmed, and empty is allowed — clearing a name is a real edit, the same way clearing the
    /// emergency number is. `Account.displayName` is not optional, so an empty one is the empty
    /// string, and both the header and the row above already know how to say so.
    private func commitName(_ typed: String) {
        guard var account = store.account else { return }
        account.displayName = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingName = false
        Task { await store.updateAccount(account) }
    }

    private func commitPhone(_ typed: String) {
        guard var account = store.account else { return }
        let value = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        account.emergencyPhone = value.isEmpty ? nil : value
        isEditingPhone = false
        Task { await store.updateAccount(account) }
    }

    // MARK: Camps

    private var campsCard: some View {
        Card(radius: Radius.settingsCard) {
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
                subtitle: store.isAdmin ? nil : store.adminsOnlyDetail,
                accessory: store.isAdmin ? .chevron : .lock,
                action: store.isAdmin ? { store.push(.campSettings) } : nil
            )
            // Same as "Your role here" — but only when the row is locked. With a role that can
            // open it the row is a `Button`, which SwiftUI already merges into one element;
            // combining it a second time would take the activation with it.
            .accessibilityElement(children: store.isAdmin ? .contain : .combine)
            .accessibilityValue(store.isAdmin ? "" : "Locked")
        }
    }

    /// `2 on this account`. `store.switchCampDetail` spells the same number "2 camps on this
    /// account", which is the sentence the row used to be; under a title that already says
    /// "camps" the design drops the word.
    private var campCountDetail: String {
        let count = store.memberships.count
        return "\(count) on this account"
    }

    // MARK: Footer

    /// `store.signOut()` clears `pushedScreen` along with `activeSheet`, so Profile does not have
    /// to put itself away. What the store cannot reach is `isManagingCamps` — a `@State` sheet it
    /// has never seen — which would otherwise be left standing over the sign-in form.
    private func closeBeforeSigningOut() {
        isManagingCamps = false
    }

    /// Asks first, which it did not.
    ///
    /// The camp page's Sign out raised a confirmation and this one signed out on the first tap —
    /// two doors to the same action behaving differently, and the one without the guard sitting
    /// next to Delete account.
    ///
    /// The design signs out immediately (`state1.js:946`), and that is the one place this
    /// deliberately departs from it: the design is a prototype with no sign-in cost, and this app
    /// is passwordless. Getting back in means waiting for an eight-digit code to arrive in an
    /// inbox, which makes a mis-tap expensive in a way a password app's is not.
    private func signOut() {
        isConfirmingSignOut = true
    }

    private func reallySignOut() {
        closeBeforeSigningOut()
        Task { await store.signOut() }
    }

    private var footer: some View {
        HStack(spacing: Spacing.buttonPair) {
            PrimaryButton(
                "Sign out",
                tone: .outline,
                height: footerButtonHeight,
                radius: Radius.row,
                font: .footerButton,
                action: signOut
            )

            PrimaryButton(
                "Delete account",
                tone: .danger,
                height: footerButtonHeight,
                radius: Radius.row,
                font: .footerButton
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
    /// Passed in already scaled — `@ScaledMetric` has to live on the view that owns the layout,
    /// and this one is built as a value inside `PhotosPicker`'s `@Sendable` label closure.
    var diameter: CGFloat = 64

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
                    InitialsAvatar(initials, size: diameter, font: .wellInitials)
                }
            }

            // 24pt accent disc with a 2.5px ring in the surface colour, hung a couple of points
            // off the corner — what says the well is a well rather than a picture.
            //
            // This used to call itself "the only mark on this screen the design does not draw",
            // which is wrong in both directions: `Sycamore Flow.dc.html:345` draws exactly this
            // camera disc, and the ✕ at the top — which the header claimed *was* the design's —
            // appears in no surviving drawing. See this file's header.
            Circle()
                .fill(Theme.accent)
                .frame(width: 24, height: 24)
                .overlay { Circle().strokeBorder(Theme.surface, lineWidth: BorderWidth.avatarRing) }
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: IconSize.inChip))
                        .foregroundStyle(Theme.onAccent)
                }
                .offset(x: 2, y: 2)
        }
        .frame(width: diameter, height: diameter)
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

/// An account with nothing in `displayName` — everyone who has ever signed in by email. The
/// header says "No name yet" and the row underneath now offers to fix it, which is the state
/// this screen used to draw as a dead end.
#Preview("8s Profile — no name yet") {
    let store = AppStore.preview
    var account = SampleData.account
    account.displayName = ""
    store.auth = .signedIn(account)

    return ProfileView(store: store)
        .showsMockStatusBar()
}
