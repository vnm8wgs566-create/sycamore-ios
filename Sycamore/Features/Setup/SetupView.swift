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

    /// Whether "Roll a new code" is asking first. Rolling is destructive in the way that counts:
    /// the old code is already in somebody's texts, and there is no putting it back.
    @State private var isConfirmingRoll = false

    /// Whether the enrolment flow is up. Presented locally rather than through `store.activeSheet`
    /// or `pushedScreen`: this screen is *itself* presented by `MainTabView`, so asking that view
    /// to present the flow would open it behind this one. `GroupsView.enrolmentFlow` records the
    /// whole argument and the second rejected alternative.
    ///
    /// A cover over a sheet is legal — the recorded constraint (`BlockDetailView.swift:66`) is
    /// that a cover cannot be presented over a *cover*, and `PushedScreen.isFullScreen` is false
    /// for `.campSettings`.
    @State private var isImportingRoster = false

    /// Whether the camp's name row is open for editing. It swaps itself for a field in place
    /// rather than pushing a screen the design does not draw — the same call `8s`'s emergency
    /// number row makes.
    @State private var isEditingIdentity = false

    /// The same, for the row under it: which days the camp opens.
    ///
    /// Two flags rather than one `enum` of "the row being edited", which would say only-one-at-a
    /// -time in the type. Nothing needs it said: the two editors write different columns, so both
    /// open at once is untidy rather than wrong, and an enum would have rewritten three existing
    /// call sites to add a second row.
    @State private var isEditingDays = false

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
        .fullScreenPresentation(isPresented: $isImportingRoster) { enrolmentFlow }
        // The copy has no visible confirmation beyond the word "Copied" swapping in, which a
        // reader looking at the code rather than the header will miss.
        .sensoryFeedback(.success, trigger: inviteCopied) { _, copied in copied }
    }

    // MARK: - Importing a roster

    /// `8c` and everything past it. The venue is the camp's first, which is where `8c` already
    /// says everybody who has not been asked goes — this screen has no chip row to mean anything
    /// else by.
    @ViewBuilder
    private var enrolmentFlow: some View {
        if let venueID = store.camp?.orderedVenues.first?.id {
            EnrolmentFlowView(venueID: venueID) { isImportingRoster = false }
                .environment(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.small) {
                    CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled) {
                        // Back means wherever this was opened from, which is not always Profile.
                        // It hardcoded `.profile` on the grounds that Profile "is where this
                        // screen was opened from" — true of one of its four entry points. The
                        // camp page, Tournament's empty state and Overview's venue-sheet follow-up
                        // all push it too, and all three used to land the reader on a Profile they
                        // had not asked for.
                        store.popPushed()
                    }
                    .accessibilityLabel("Back")

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

                // The second way into the enrolment flow, and the one for the admin who is not
                // standing on Groups. A camp's roster changes every week — a new sign-up list,
                // a walk-in, somebody who did not come back — and "where the camp is set up" is
                // where a person looks for that.
                //
                // Already admin-gated: `body` draws this whole block only for an admin (`:67`).
                SettingsRow(
                    "Import a roster",
                    icon: "arrow.up.doc",
                    iconColor: Theme.accent,
                    subtitle: "A sign-up list, read against the kids already here"
                ) {
                    isImportingRoster = true
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
                    // The venue's own tint with the venue's own emoji on it, which is how the
                    // design draws this exact row: `background:#F1F5EC` and 🌳, then
                    // `background:#F7F9E9` and 🎾 (`design/Sycamore Flow.dc.html:276` and
                    // `:281`).
                    //
                    // It was a generic pin, on the argument that `8t` lists several venues at
                    // once so the plate is what tells them apart. The argument still holds; the
                    // evidence never did. `8t.html` is not in this repository and never has been
                    // — `git log --all --diff-filter=A` finds no section-8 document — so the pin
                    // could not be checked against anything, while the design that *is* here
                    // draws the emoji, contains no `map-pin` at all, and `SPEC.md`'s
                    // Phosphor→SF Symbol table has no pin row. The plate still tells the venues
                    // apart. The emoji tells them apart first, and says which is which rather
                    // than only that they differ.
                    //
                    // Deliberately still 40pt rather than the design's 44: that size came from
                    // the same absent document, and resizing every venue row is a layout change
                    // this is not.
                    // Through `IntakeIconTile` rather than drawn here: it holds the plate, both
                    // `@ScaledMetric`s and the "hidden because the name is beside it" decision,
                    // and three screens replaced the same pin in this batch. It also hides
                    // itself — an emoji is how a venue is recognised, but the name sits
                    // immediately beside it and reading both would say the venue twice.
                    VenueLetterTile(venue.name, size: 40, radius: Radius.tile)

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

                SettingsRow(
                    "Roll a new code",
                    accessory: .glyph("arrow.triangle.2.circlepath")
                ) {
                    isConfirmingRoll = true
                }
                // No `.combine` now the row is a button: its label already reads as one element,
                // and combining a button's children risks flattening the trait that says so.
                // The title alone does not say what is lost, though, which is the one thing
                // somebody should know before they tap it.
                .accessibilityHint("Replaces the code. Anyone holding the old one can no longer join.")
                // Attached to the row rather than to the screen so the dialog animates out of
                // the control that raised it — the same reason a menu is anchored to its button.
                .confirmationDialog(
                    "Roll a new invite code?",
                    isPresented: $isConfirmingRoll,
                    titleVisibility: .visible
                ) {
                    // The same shape "Delete account" uses, which this row's old comment said it
                    // would get the moment there was something to confirm.
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
                // `SwiftUI.Group` rather than `Group`, which in this app is a court.
                SwiftUI.Group {
                    if isEditingIdentity {
                        // Seeded from the camp as it stands, so an edit starts from what is on
                        // screen rather than from whatever the last abandoned one left behind —
                        // which is what `beginEditingIdentity` used to do by hand, and no longer
                        // has to, because the editor is rebuilt each time it appears.
                        CampIdentityEditor(
                            name: camp.name,
                            sport: camp.sport,
                            onCancel: { isEditingIdentity = false },
                            onSave: commitIdentity
                        )
                    } else {
                        // The caret the design draws is back. It was dropped only because the
                        // row had nowhere to send it, and the sport took the trailing slot to
                        // fill the gap; now that the row opens an editor, the caret says so and
                        // the sport moves to the line under the title. No `.combine` either — a
                        // button's label is already one element, and this is a button now.
                        SettingsRow(
                            "Camp name & sport",
                            subtitle: camp.sport.displayName,
                            accessory: .chevron
                        ) {
                            beginEditingIdentity()
                        }
                    }
                }

                // The operating week, in the row under the camp's own name — the two facts the
                // Season card can actually change, in the order somebody would say them. It is
                // asked first on `8b` while the camp is being drawn; this is where a swim club
                // that has just added a Saturday says so.
                SwiftUI.Group {
                    if isEditingDays {
                        CampDaysEditor(
                            days: camp.days,
                            onCancel: { isEditingDays = false },
                            onSave: commitDays
                        )
                    } else {
                        SettingsRow(
                            "Days the camp runs",
                            subtitle: camp.days.summaryLine,
                            accessory: .chevron
                        ) {
                            isEditingDays = true
                        }
                    }
                }

                // Still drawn and still inert, and now the only row on `8t` that is. There is
                // nowhere to record that a camp is archived: `camps` is `id, name, sport,
                // invite_code, icon, tint, created_at`, and `Camp` carries no flag either. It
                // wants a migration adding `camps.archived_at timestamptz` and a matching
                // `Camp.archivedAt` — and then a decision neither of those can make on its own,
                // which is whether an archived camp still comes back from
                // `memberships(forAccount:)` and what the picker does with it if it does.
                // Guessing a column into existence here would be guessing at all three.
                SettingsRow(
                    "Archive this camp",
                    accessory: .plain,
                    titleColor: Theme.danger
                )
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Opens the editor. It seeds itself from the camp it is handed, so there is no draft here
    /// to prime — and nothing on this screen to invalidate while somebody is typing into it. That
    /// is also why it takes no camp any more: the argument was left over from the draft this
    /// screen used to hold, and had been ignored since the editor started seeding itself.
    private func beginEditingIdentity() {
        isEditingIdentity = true
    }

    /// Closes the editor first, then writes. The store round-trip is what redraws the row, and
    /// leaving the field open until it lands would show a name the camp has already taken.
    private func commitIdentity(_ typed: String, _ sport: Sport) {
        let name = typed.trimmingCharacters(in: .whitespaces)
        // `renameCamp` refuses an empty name, and nothing upstream can hand one over any more:
        // the editor's Save is disabled for it and its Return key now asks the same gate the
        // button does (`InlineRowEditor.save()`), which is the hole this guard was written to
        // plug. It stays as the guard on the store call rather than as the guard on a keyboard.
        guard !name.isEmpty else { return }
        isEditingIdentity = false
        Task { await store.renameCamp(name: name, sport: sport) }
    }

    /// The same shape one row down, and with no guard in front of it.
    ///
    /// There is no empty week for one to catch: `CampDaysPicker` will not switch the last day
    /// off, so the only value that could arrive here is one the picker cannot produce. A guard
    /// would turn that impossible bug into a Save button that silently does nothing, which is
    /// worse than the 400 `camps_camp_days_check` would raise — the two repositories say the
    /// same, in the doc comments on `setCampDays`.
    ///
    /// The two Season editors write different columns, so nothing here has to close the other
    /// one first: neither carries a field the other would post back.
    private func commitDays(_ days: CampDays) {
        isEditingDays = false
        Task { await store.setCampDays(days) }
    }
}

// MARK: - Camp identity editor

/// The camp's name and the sport it plays, edited in place.
///
/// The design draws this row with a caret and never draws what is behind it, so the editor is
/// assembled from pieces the design does specify: `InlineRowEditor` for the shape — the box `8s`
/// opens its name and phone rows into, and now literally that box rather than a transcription of
/// it — and screen 4's own sport chips for the sport, so the two places that ask which sport a
/// camp plays ask it the same way.
///
/// What is left here is what is genuinely `8t`'s: the sport, and the rule about what a camp may
/// be called.
private struct CampIdentityEditor: View {

    /// Held here rather than bound up to `SetupView`, and that is most of what is left of this
    /// view.
    ///
    /// `SetupView` is seventeen computed `some View` properties inlined into one body, so a
    /// choice living on it meant every tap re-ran all of them: every venue's staffing status
    /// recomputed, `filteredStaff` and `staffChips` refiltered, the whole 710-line screen rebuilt
    /// to redraw one row of chips. The chips are the only thing that reads this while it is being
    /// chosen, so this is the only thing that needs to hear about it.
    ///
    /// The name used to sit beside it under the same argument and no longer does. The draft lives
    /// one level further in, in `InlineRowEditor`, which makes that argument once for both of its
    /// callers rather than having each of them make it again.
    @State private var sport: Sport

    /// The name the camp has now — a seed rather than a draft. The editor takes a copy of it and
    /// does the typing.
    let name: String

    let onCancel: () -> Void
    let onSave: (String, Sport) -> Void

    init(
        name: String,
        sport: Sport,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Sport) -> Void
    ) {
        self.name = name
        _sport = State(initialValue: sport)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        InlineRowEditor(
            title: "Camp name & sport",
            field: .campName,
            value: name,
            // The row is named for more than the field holds. The sport is chosen under it, by
            // chips that say their own names.
            fieldLabel: "Camp name",
            // The same rule `CampDraft.isValid` applies on the way in — literally the same,
            // rather than a second copy of half of it. This used to test only for empty, so the
            // rename field would happily send an eighty-one character name to a column that
            // refuses one.
            isSaveEnabled: { CampName.isValid($0.trimmingCharacters(in: .whitespaces)) },
            onCancel: onCancel,
            // The sport is not typed, so it does not come back through the field. It is read off
            // this view at the moment Save is tapped, which is all this closure is for.
            onSave: { onSave($0, sport) }
        ) {
            sportChips
        }
    }

    /// `FlowLayout` rather than a plain row: five chips do not fit across a card inset by the
    /// 12pt gutter, and at larger type sizes they fit even less.
    private var sportChips: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(Sport.selectable, id: \.self) { option in
                let isSelected = sport.matchesChip(option)
                Chip(option.chipTitle, isSelected: isSelected, metrics: .sport) {
                    sport = option
                }
                // The chip draws its selection but does not say it, and "which sport" is
                // unanswerable by ear without it.
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: sport)
    }
}

// MARK: - Camp days editor

/// Which days the camp opens, edited in place.
///
/// `InlineRowEditor`'s shape, with the chips in place of the field: seeded from what it is
/// handed, its state its own, and the chosen week handed back through `onSave`. That is not
/// styling — the reason is the one that file gives, that a draft on `SetupView` re-runs seventeen
/// computed properties per tap, and a set of days is four taps for a camp that runs Tue/Thu.
///
/// Drawn out longhand rather than opened through that editor, which is the row above's answer
/// now. `InlineRowEditor` is built around a text field — a prompt, a keyboard, a draft `String`
/// — and this row has no field at all: a week is chosen, not typed. Adopting it would mean an
/// optional field and an optional keyboard threaded through a component whose whole subject is
/// the field, to save a `CardRow` and two `Pill`s. What the two rows genuinely share is the
/// numbers, and those are the design's, stated in both places from the same drawing.
///
/// Cancel and Save rather than writing on each tap, for the same four taps: every one of them
/// would be a PATCH and a whole camp back, and three of the four would describe a week nobody
/// meant to have — Mon–Fri on its way to Sat/Sun passes through some odd shapes.
private struct CampDaysEditor: View {

    @State private var days: CampDays

    let onCancel: () -> Void
    let onSave: (CampDays) -> Void

    init(days: CampDays, onCancel: @escaping () -> Void, onSave: @escaping (CampDays) -> Void) {
        _days = State(initialValue: days)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    /// `Mon–Fri · 5 days a week`, and at the floor `Wed · at least one day`.
    ///
    /// The second half is where the picker's refusal is explained — at a single day the last chip
    /// stops answering, and a tap that does nothing is a mystery unless something on screen says
    /// why. Both readings come from `CampDays` rather than being written here, so the sentence
    /// cannot come to differ between the screen that sets the week up and the one that changes it;
    /// `8b`'s summary row draws the same two properties.
    private var caption: String {
        "\(days.summaryLine) · \(days.countLine)"
    }

    var body: some View {
        CardRow(
            spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13, alignment: .top
        ) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Days the camp runs")
                    .typeStyle(.rowLabel, color: Theme.ink)

                CampDaysPicker(days: $days)

                Text(caption)
                    .typeStyle(.rowSubtitleSmall, color: Theme.inkFaint)

                HStack(spacing: Spacing.small) {
                    Spacer(minLength: 0)
                    Pill(
                        "Cancel", tone: .outline,
                        horizontalPadding: 13, verticalPadding: 8, action: onCancel
                    )
                    // No disabled state to draw. The name field above can be emptied and this
                    // cannot: the picker refuses to switch the last day off, so there is no
                    // invalid week for Save to have to refuse.
                    Pill(
                        "Save", tone: .accent,
                        horizontalPadding: 13, verticalPadding: 8,
                        action: { onSave(days) }
                    )
                }
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
