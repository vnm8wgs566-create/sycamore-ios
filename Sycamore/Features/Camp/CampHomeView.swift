//
//  CampHomeView.swift
//  Sycamore
//
//  The Camp page — what the avatar in every header opens.
//
//  `design/app/state1.js:41` is the whole argument for this file existing: `openProfile: () =>
//  this.setState({ page: 'camp' })`. The disc in the corner of every screen used to lead to
//  Profile, and Profile led to "Camp settings", and only from there could anybody see the camp
//  they were standing in. Three taps down, behind a screen about *you*, for the thing the whole
//  app is about. The design puts the camp one tap away and spends Profile on the account.
//
//  What is on it is `campTabVals()` (`state1.js:925-963`), in its order: what the camp holds,
//  who staffs it and how they get in, and then the three ways out — its name, its siblings, and
//  the door.
//
//  ── Two departures, both because this app has facts the prototype does not ──────────────────
//
//  `seasonLabel` reads `camp.season || 'Season not set'` in the prototype, and there is no
//  `season` on `Camp` here — a camp has `days` (which weekdays it opens) and a `sport`. The chip
//  under the title therefore reads the week (`Mon–Fri`), which is the nearest thing this app
//  actually knows, and the row that changes it opens `8t Camp settings` rather than the
//  prototype's name-and-season sheet: `8t` is where the name, the sport and the week are already
//  edited, and a second editor for two of those three is a second place for them to disagree.
//
//  `goKidsRow` sets `tab: 'groups', page: null` — leave this page and land on Groups. Same here,
//  with the tab set first so the screen underneath has already changed by the time this one is
//  dismissed; the other order shows the tab you came from for a frame on the way out.
//

import SwiftUI

struct CampHomeView: View {

    let store: AppStore

    /// What the back disc does. Nil — the usual case — dismisses whatever presented this.
    ///
    /// A parameter rather than always `dismiss()`, because the routing above this file is not
    /// settled: presented as a sheet, `dismiss` is right and needs no help; drawn inline by
    /// something that owns its own navigation, only that thing knows what "back" means.
    private let onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Whether "Shape the camp" is pushed. This view owns a `NavigationStack` for it — the same
    /// call `CampPickerView` makes for `CreateCampView`, and for the same reason: there is no
    /// `PushedScreen` case for a second camp screen, and the app's tab bar is an overlay rather
    /// than a `TabView`'s chrome, so a push from outside this view would slide under the pill.
    @State private var isShapingCamp = false

    /// `8u`, presented rather than pushed. Selecting a camp in there ends with
    /// `CampPickerView` clearing `store.pushedScreen`, which takes this page with it — correct,
    /// because this page is about the camp you just left.
    @State private var isSwitchingCamps = false

    /// The enrolment flow, presented locally for the reason `SetupView.isImportingRoster` records:
    /// this screen is itself presented, so asking the presenter to raise the flow would open it
    /// *behind* this one.
    @State private var isImportingRoster = false

    /// Whether "Roll a new code" is asking first. The same flag and the same dialog `8t` uses —
    /// the old code is already in somebody's texts and there is no putting it back.
    @State private var isConfirmingRoll = false

    /// The same, for signing out. Both destructive-ish controls on this page ask before they
    /// fire, and neither invents a mechanism: `SetupView.isConfirmingRoll` is the pattern.
    @State private var isConfirmingSignOut = false

    /// The design's `padding:14px 22px 16px`, less the 4pt the back disc's 44pt hit frame hangs
    /// above its 36pt circle. Measured to the disc rather than to the frame, as `8t` does.
    private let headerTop: CGFloat = 10
    private let headerBottom: CGFloat = 16

    init(store: AppStore, onBack: (() -> Void)? = nil) {
        self.store = store
        self.onBack = onBack
    }

    var body: some View {
        NavigationStack {
            screen
                .navigationDestination(isPresented: $isShapingCamp) {
                    CampShapePage(store: store)
                }
        }
        .fullScreenPresentation(isPresented: $isImportingRoster) { enrolmentFlow }
        .sheet(isPresented: $isSwitchingCamps) {
            CampPickerView(isManagingCamps: true)
                .environment(store)
        }
    }

    @ViewBuilder
    private var screen: some View {
        VStack(spacing: 0) {
            header
            if let camp = store.camp {
                content(for: camp)
            } else {
                // Nothing to say about a camp that is not loaded, and no honest way to say it.
                // Reaching here at all means the routing let go of the camp while this page was
                // up; the header still draws its way out.
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8` — section 8's page, a shade warmer than `grouped`.
        .background(Theme.surfaceWarm)
        .hidesNavigationBar()
    }

    // MARK: - Importing a roster

    /// The camp's first venue, which is where `8c` already sends everybody who has not been
    /// asked. This screen draws no venue chips to mean anything else by.
    @ViewBuilder
    private var enrolmentFlow: some View {
        if let venueID = store.camp?.orderedVenues.first?.id {
            EnrolmentFlowView(venueID: venueID) { isImportingRoster = false }
                .environment(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.small) {
                    CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled, action: goBack)
                        .accessibilityLabel("Back to \(store.selectedTab.title)")
                        // The disc is 36 and the button around it is 44, which would otherwise
                        // push the row 4pt in both directions off where the design puts it.
                        .frame(width: 36, height: 36)

                    // `profileBack` — the tab this page was opened from. A label rather than part
                    // of the button: the design draws it as a caption beside the disc, and the
                    // disc already says where it goes.
                    Text(store.selectedTab.title)
                        .typeStyle(.headerDetail, color: Theme.inkTertiary)
                        .lineLimit(1)
                        .accessibilityHidden(true)

                    Spacer(minLength: Spacing.small)

                    profileDisc
                }

                // The camp's own name is the title of its page — which is why this is
                // `IntakeTitle` and carries `.isHeader`: it is what the screen *is*, and it is
                // what VoiceOver should reach first.
                IntakeTitle(store.camp?.name ?? "", style: .campPageTitle)
                    // `margin-top:15px`, less the same 4pt of hit-frame overhang.
                    .padding(.top, Spacing.row)

                if let camp = store.camp {
                    chips(for: camp)
                        .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, headerTop)
            .padding(.bottom, headerBottom)
        }
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    /// The one control on this page that still leads to `8s`.
    ///
    /// The avatar in every *other* header now opens this screen, so without this Profile would
    /// have no door at all — the name, the photo, the emergency number and the notification
    /// switch would all become unreachable. The design draws the disc in this corner and gives it
    /// `openProfile`; here that word means what it says.
    private var profileDisc: some View {
        Button {
            store.pushedScreen = .profile
        } label: {
            InitialsAvatar(store.avatarInitials, size: 34, tone: .neutralStrong)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your profile")
    }

    /// `seasonLabel`, `kidChip` and the role, wrapped — three chips do not fit across the header
    /// once the reader has grown their type, and the third is the one that would be lost.
    private func chips(for camp: Camp) -> some View {
        FlowLayout(horizontalSpacing: Spacing.tight, verticalSpacing: Spacing.tight) {
            CampMetaChip(camp.days.summaryLine)
            CampMetaChip("\(camp.playerCount) kids")
            if let role = store.selectedMembership?.role {
                CampMetaChip(role.membershipName)
            }
        }
    }

    // MARK: - Body

    private func content(for camp: Camp) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                holdsCard(camp)
                staffCard(camp)
                exitsCard(camp)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            // No `tabBarClearance`: this page covers the tabs rather than sitting under them.
            .padding(.bottom, Spacing.sheetFoot)
        }
    }

    // MARK: What the camp holds

    private func holdsCard(_ camp: Camp) -> some View {
        Card(radius: Radius.settingsCard) {
            CampSummaryRow(
                title: "Venues & courts",
                subtitle: venueSummary(camp),
                icon: "mappin.and.ellipse"
            ) {
                isShapingCamp = true
            }

            CampSummaryRow(
                title: "Kids",
                subtitle: kidsSummary(camp),
                icon: "list.number",
                action: goToGroups
            )

            // `canImport` — there is nowhere to deal a roster until the camp has a venue. Admin
            // besides: an import rewrites every court in the camp, and `8t` gates the same
            // control on the same permission.
            if !camp.venues.isEmpty, store.isAdmin {
                SettingsRow(
                    "Import the roster",
                    icon: "arrow.up.doc",
                    iconColor: Theme.accent,
                    accessory: .value("file · paste")
                ) {
                    isImportingRoster = true
                }
            }
        }
    }

    /// `Sycamore + LATC · 10 courts`, or the design's own prompt when there is nothing yet.
    ///
    /// The noun follows the sport, the way `Camp.venueSummary(for:)` already does it — a swim
    /// club reading "10 courts" is the one line on the screen that had not been told what it is.
    private func venueSummary(_ camp: Camp) -> String {
        let venues = camp.orderedVenues
        guard !venues.isEmpty else { return "None yet — start here" }
        let courts = venues.reduce(0) { $0 + $1.courtCount }
        let noun = camp.sport.groupNoun.lowercased()
        return "\(venues.map(\.name).joined(separator: " + ")) · \(courts) \(noun)\(courts == 1 ? "" : "s")"
    }

    /// `74 across 12 groups`. Groups rather than courts on purpose: this row is about the kids,
    /// and how many piles they are in is the fact that qualifies the count.
    private func kidsSummary(_ camp: Camp) -> String {
        let kids = camp.playerCount
        guard kids > 0 else { return "None yet — import after shaping" }
        let groups = camp.orderedVenues.reduce(0) { $0 + $1.groupCount }
        return "\(kids) across \(groups) group\(groups == 1 ? "" : "s")"
    }

    /// The design leaves this page to land on Groups. The tab moves first so the screen behind
    /// this one has already changed by the time it is dismissed.
    private func goToGroups() {
        store.selectedTab = .groups
        goBack()
    }

    // MARK: Who staffs it, and how they get in

    private func staffCard(_ camp: Camp) -> some View {
        Card(radius: Radius.settingsCard) {
            // No destination, exactly as the design draws it: the staff list, the filters and the
            // per-person sheet are `8t`'s, and this row is here to answer "who is here" without
            // going anywhere. `CampSummaryRow` with no action draws no caret and takes no tap.
            CampSummaryRow(
                title: "Staff",
                subtitle: staffSummary(camp),
                icon: "person.3"
            )

            SettingsRow(
                "Invite code",
                icon: "lock",
                accessory: .code(camp.inviteCode)
            )
            // Spelt out, so a synthesiser reads "S Y C - 4 8 2 1" rather than attempting the
            // whole thing as a word. A code is only useful character by character.
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Invite code, \(spelled(camp.inviteCode))")

            if store.isAdmin {
                SettingsRow(
                    "Roll a new code",
                    icon: "arrow.triangle.2.circlepath",
                    accessory: .plain
                ) {
                    isConfirmingRoll = true
                }
                .accessibilityHint("Replaces the code. Anyone holding the old one can no longer join.")
                // Attached to the row rather than to the screen, so the dialog animates out of
                // the control that raised it — the same anchoring `8t` uses.
                .confirmationDialog(
                    "Roll a new invite code?",
                    isPresented: $isConfirmingRoll,
                    titleVisibility: .visible
                ) {
                    Button("Roll a new code", role: .destructive) {
                        Task { await store.rollInviteCode() }
                    }
                    Button("Keep this one", role: .cancel) {}
                } message: {
                    Text("The code you have already handed out stops working. Anyone still joining on it will need the new one.")
                }
            }
        }
    }

    /// `Dana R, Maya K, Hugo T`, or the design's line about the code when nobody has arrived.
    ///
    /// Capped at three, which the prototype does not do because its fixture has three. A camp
    /// with fourteen staff would otherwise wrap a comma-separated wall across the row this line
    /// is a subtitle of; the count carries the rest.
    private func staffSummary(_ camp: Camp) -> String {
        let names = camp.staff.map(\.name)
        guard !names.isEmpty else { return "Coaches join with the invite code" }
        let shown = names.prefix(3).joined(separator: ", ")
        let rest = names.count - 3
        return rest > 0 ? "\(shown) and \(rest) more" : shown
    }

    /// `SYC-4821` -> `S Y C - 4 8 2 1`. Spacing the characters is what makes a speech synthesiser
    /// read them out rather than attempt them as a word.
    private func spelled(_ code: String) -> String {
        code.map(String.init).joined(separator: " ")
    }

    // MARK: The three ways out

    private func exitsCard(_ camp: Camp) -> some View {
        Card(radius: Radius.settingsCard) {
            // The prototype's "Name & season" sheet, pointed at the screen that already owns both
            // halves of it — see the file header. Locked for a worker, which is the same shape
            // and the same reason Profile's row for this screen wears
            // (`ProfileView.campsCard`): `8t` refuses a non-admin outright, and a caret that
            // leads to a refusal is worse than a lock that explains itself.
            SettingsRow(
                "Name & season",
                icon: "pencil",
                subtitle: store.isAdmin ? nil : store.adminsOnlyDetail,
                accessory: store.isAdmin ? .chevron : .lock,
                action: store.isAdmin ? { store.pushedScreen = .campSettings } : nil
            )
            .accessibilityElement(children: store.isAdmin ? .contain : .combine)
            .accessibilityValue(store.isAdmin ? "" : "Locked")

            SettingsRow(
                "Switch camp",
                icon: "arrow.left.arrow.right",
                accessory: .value(campCount)
            ) {
                isSwitchingCamps = true
            }

            SettingsRow(
                "Sign out",
                icon: "rectangle.portrait.and.arrow.right",
                accessory: .value(store.account?.email ?? "")
            ) {
                isConfirmingSignOut = true
            }
            .confirmationDialog(
                "Sign out?",
                isPresented: $isConfirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive, action: signOut)
                Button("Stay signed in", role: .cancel) {}
            } message: {
                Text("Your memberships go with it. Camps you administer keep running without you.")
            }
        }
    }

    /// `2 camps`.
    private var campCount: String {
        let count = store.memberships.count
        return "\(count) camp\(count == 1 ? "" : "s")"
    }

    /// `store.signOut()` clears `pushedScreen` and `activeSheet`, so this page puts itself away.
    /// What the store has never seen is `isSwitchingCamps` — a `@State` sheet that would
    /// otherwise be left standing over the sign-in form, which is the bug `ProfileView
    /// .closeBeforeSigningOut` records.
    private func signOut() {
        isSwitchingCamps = false
        Task { await store.signOut() }
    }

    private func goBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
}

// MARK: - A row that carries a real line under its title

/// The camp page's three summary rows: a glyph, a title, and a line of copy that is the point of
/// the row rather than a hint about it.
///
/// **Not `SettingsRow`, and the difference is one colour.** That row draws its subtitle in
/// `Theme.inkFaint` (`#A2A6AE`), which is right for the qualifiers it was built for — "Anyone
/// with it joins as a worker", "Only an admin can change this" — copy you can skip. The lines
/// here are the answer to the question the row asks: *which* venues, *how many* kids, *who* is
/// coaching. `inkFaint` measures about 2.6:1 on white and `inkMuted` about 3.3:1; only
/// `inkTertiary` clears the 4.5:1 body copy has to clear, so that is what this draws them in.
///
/// Everything else is `SettingsRow`'s: the 21pt glyph column that keeps every title on one left
/// edge, the 13pt gutter, the 44pt floor, the caret that means the row goes somewhere.
struct CampSummaryRow: View {

    let title: String
    let subtitle: String
    var icon: String?
    var action: (() -> Void)?

    init(title: String, subtitle: String, icon: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 13) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Theme.inkSecondary)
                    // The design's Phosphor glyphs are all one width and SF Symbols are not, so
                    // the column is pinned — the same 21 `SettingsRow` pins.
                    .frame(width: 21)
                    // Decorative: the title says what the row is.
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(title)
                    .typeStyle(.rowLabel, color: Theme.ink)
                Text(subtitle)
                    .typeStyle(.detailSm, color: Theme.inkTertiary)
                    // Two lines rather than one: "Sycamore + LATC · 10 courts" is already close
                    // at the default size and past it at the reader's larger ones, and a
                    // truncated venue list is a row that has stopped answering.
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.small)

            // A caret only where there is somewhere to go. A row that ends in one and does
            // nothing is a promise the screen does not keep.
            if action != nil {
                DisclosureChevron(size: 15)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: HitTarget.minimum)
    }
}

// MARK: - The camp's meta chip

/// `600 11.5` on a `#F1F2F5` plate at radius 999 — the chip under the camp's name, and every chip
/// on a venue card over on "Shape the camp".
///
/// **Not `Chip`.** That component's unselected tone is a white fill with a grey border, which is
/// the design's *filter* chip; this is a read-only badge on a grey plate with no border at all,
/// and its second tone swaps both colours for the amber pair. Two different drawings that happen
/// to share a corner radius.
///
/// Not `Badge` either, which is `700 9.5` uppercase at radius 5 — the design tracks and shouts
/// that one, and these are sentence-case facts.
struct CampMetaChip: View {

    /// The two the design draws. Amber is not decoration: it is the venue with nobody on it.
    enum Tone {
        /// `#F1F2F5` / `#5C6068`.
        case neutral
        /// `#FBF2E2` / `#8A5E0F` — read through the palette's one amber pair, which is what
        /// `Theme.warningTint` says to do with this stray.
        case warning
    }

    let text: String
    var tone: Tone = .neutral

    init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .typeStyle(.intakeChipSm, color: foreground)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule(style: .continuous))
    }

    private var background: Color {
        switch tone {
        case .neutral: Theme.fill
        case .warning: Theme.warningTint
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Theme.inkSecondary
        case .warning: Theme.warningDark
        }
    }
}

// MARK: - Type

extension TypeStyle {
    /// `400 30/1.05 Newsreader`, `-.022em` — the camp's name here, and "Shape the camp" next door.
    ///
    /// Its own value rather than `screenTitle`, which is `8t`'s 33. The two screens sit one tap
    /// apart and the design draws them three points apart on purpose: `8t` is a settings screen
    /// with a fixed title, and this one carries a camp's name, which can be eighty characters.
    static let campPageTitle = TypeStyle.tabTitle.size(30).lineHeight(1.05)
}

// MARK: - Previews

/// One store, held and passed down. Two `AppStore.previewUCLAAdmin` expressions would be two
/// different stores — the view reading one and the picker it presents reading the other.
#Preview("Camp page — admin") {
    let store = AppStore.previewUCLAAdmin

    return CampHomeView(store: store)
        .environment(store)
        .showsMockStatusBar()
}

/// The same camp seen by Alex, who coaches there. "Import the roster" and "Roll a new code" are
/// gone and "Name & season" wears a lock — the three differences worth a preview of their own.
#Preview("Camp page — coach") {
    let store = AppStore.preview

    return CampHomeView(store: store)
        .environment(store)
        .showsMockStatusBar()
}

#Preview("Camp page — accessibility1") {
    let store = AppStore.previewUCLAAdmin

    return CampHomeView(store: store)
        .environment(store)
        .showsMockStatusBar()
        .environment(\.dynamicTypeSize, .accessibility1)
}
