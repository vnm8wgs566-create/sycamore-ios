//
//  VenueSheet.swift
//  Sycamore
//
//  Screen 11, and `design/app/regions/sheet-shVenue.html` — a venue's whole shape, asked at once.
//
//  What it now collects, in the design's order: name, subtitle, age band, courts, groups, an
//  optional target per group, a live sentence saying what saving will do, and who stands here.
//  Four of those are new, and they are new because `Venue` grew somewhere to put them — a venue
//  knows how many courts it has *and*, separately, how many groups its kids split into, which used
//  to be one number spent twice.
//
//  Three of the pieces below it are not private, because "Shape the camp" grew an editor for the
//  same venue one screen earlier (`VenueShapeSheet`) and draws the same blocks of the same
//  drawing: `VenueNameFields` and `VenueLimitRow` live at the foot of this file, and everything
//  between the name and the button is in `VenueShapeFields.swift`. The icon grid and the limits
//  card were both cut — a venue is drawn by its initial now, and its head-count ranges are
//  derived rather than typed. The box round the two fields went further still, to
//  `FormFieldMetrics.venueBox`, because that is where every other box in the app lives.
//
//  ── The commit moved, and that is the design's doing ─────────────────────────────────────────
//
//  This screen used to have no button. It live-wrote every edit on a 400ms settle and flushed on
//  close, because the frame it was drawn from ends at the icon grid and closing *was* the commit.
//  `sheet-shVenue` draws a CTA — "Save changes" — and hangs a sentence above it that is *about
//  pressing it*: "Save closes 2 groups…". A live write makes that sentence a lie twice over, once
//  because the thing it describes has already happened and once because there is no moment at
//  which it could be read before it did.
//
//  So the ✕ discards and the button commits, which is what a button under a warning has to mean.
//  Everything the old debounce bought is bought better: no round trip per character, no transient
//  "Another venue already uses that name." at a colliding prefix, and one write instead of eleven.
//
//  ── No Remove ────────────────────────────────────────────────────────────────────────────────
//
//  The design draws "Remove this venue" under the CTA for an existing venue, with a two-tap
//  confirm that names the kids it takes with it. **There is no delete path for a created venue
//  anywhere below this view** — not on `AppStore`, not on `Repository`, not in either
//  implementation of it — and `Store/` is not this change's to widen. A button that cannot do what
//  it says is worse than an absence, so the control is not drawn here at all. `VenueShapeSheet`
//  draws it, because before the camp exists removal is a `CampShape` mutation and works.
//

import SwiftUI

struct VenueSheet: View {
    let store: AppStore

    /// The venue being edited, or nil while one is being added.
    ///
    /// Nil is the whole of the difference between the two modes: it decides the title, the CTA's
    /// words, which sentence sits above it, whether the staffing banner has anything to read, and
    /// whether saving is an `updateVenue` or an `addVenue(shapedBy:)`.
    let venueID: Venue.ID?

    /// How the sheet takes itself off screen. Nil for the venue the root presents through
    /// `ActiveSheet`, which is dismissed through the store like every other sheet it owns.
    private let onClose: (() -> Void)?

    /// Edits land here and go nowhere until the button is pressed — see the file header.
    @State private var draft: Venue
    /// Who is picked in the coach row. A selection, not an assignment: it becomes one at save.
    @State private var coaches: Set<StaffMember.ID>
    /// Stops a second tap queueing a second write behind the first.
    @State private var isSaving = false

    /// What the venue looked like on the way in. Two numbers of it, which is all the sentence
    /// above the button needs: how many groups it had, and who was standing in it.
    private let openingGroupCount: Int
    private let openingCoaches: Set<StaffMember.ID>

    /// The venue as it stands, for editing.
    @MainActor
    init(store: AppStore, venueID: Venue.ID) {
        let venue = store.venue(venueID) ?? .placeholder
        let standing = Set((store.camp?.coaches(in: venueID) ?? []).map(\.id))

        self.store = store
        self.venueID = venueID
        self.onClose = nil
        self.openingGroupCount = venue.groupCount
        self.openingCoaches = standing
        _draft = State(initialValue: venue)
        _coaches = State(initialValue: standing)
    }

    /// A venue that does not exist yet, in a camp that does.
    ///
    /// Seeded from the camp's last venue exactly as `Repository.addVenue` seeds one, so pressing
    /// Add without touching a stepper produces the venue the old "Add" produced — with a name on
    /// it. That is the point of the mode: `addVenue()` appended `Venue 4` carrying the previous
    /// venue's numbers and left somebody to find it, which is why Camp settings has always had a
    /// venue called `Venue 4` in it.
    @MainActor
    init(store: AppStore, onClose: @escaping () -> Void) {
        let template = store.camp?.orderedVenues.last
        let index = store.camp?.venues.count ?? 0
        let icon = Venue.iconOptions[index % Venue.iconOptions.count]

        self.store = store
        self.venueID = nil
        self.onClose = onClose
        self.openingGroupCount = template?.groupCount ?? 6
        self.openingCoaches = []
        _draft = State(
            initialValue: Venue(
                // Empty, so the field shows its placeholder and the button stays dimmed until
                // there is a name. The design's `ctaOpacity: name ? 1 : .45` is that rule.
                name: "",
                subtitle: nil,
                icon: icon,
                tint: .suggested(for: icon),
                courtCount: template?.courtCount ?? 6,
                groupCount: template?.groupCount ?? 6,
                // Deliberately not inherited: an age band copied from the venue next door would
                // quietly narrow who this one may take, and a target is a decision about a group
                // size somebody has not been asked about yet.
                targetPerGroup: nil,
                ageBand: .all,
                coachMin: template?.coachMin ?? 4,
                coachMax: template?.coachMax ?? 7,
                playerMin: template?.playerMin ?? 0,
                playerMax: template?.playerMax ?? 60
            )
        )
        _coaches = State(initialValue: [])
    }

    var body: some View {
        SheetChrome(
            title: title,
            subtitle: subtitle,
            detentFraction: ActiveSheet.venue(draft.id).detentFraction,
            onClose: close
        ) {
            if let banner = statusBannerText {
                InfoBanner(banner)
                    .padding(.bottom, Spacing.large)
            }

            SheetSectionHeader("Name", bottomPadding: Spacing.small)
            VenueNameFields(name: $draft.name, subtitle: $draft.subtitle)
                .padding(.bottom, 18)

            VenueFieldLabel(title: "Age group")
            VenueAgeBandPicker(ageBand: $draft.ageBand)

            VenueFieldLabel(title: "Numbers")
            VenueCountsCard(
                courtNoun: courtNoun,
                courts: $draft.courtCount,
                groups: $draft.groupCount,
                targetPerGroup: $draft.targetPerGroup
            )
            VenueDealLine(sentence: dealSentence, isWarning: isRecutting)

            VenueFieldLabel(title: "Coaches", note: "optional")
            coachBlock

            saveButton
                .padding(.top, 18)
        }
    }

    // MARK: - What it is called

    private var title: String {
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return venueID == nil ? "New venue" : draft.name
    }

    /// `50 kids · 6 coaches · 6 groups` for a venue that has some, and the camp's own name for one
    /// that does not exist yet — which is the design's `sheetContext`, and the only thing there is
    /// to say about a venue nobody has added.
    private var subtitle: String? {
        guard let venueID else { return store.camp?.name }
        return store.camp?.sheetSummary(for: venueID)
    }

    /// What a group stands on in this sport — "court", "field", "lane".
    private var courtNoun: String {
        (store.camp?.sport.groupNoun ?? "court").lowercased()
    }

    private var statusBannerText: String? {
        guard let venueID else { return nil }
        return store.camp?.staffingStatus(for: venueID)?.bannerText
    }

    // MARK: - What saving does

    /// Whether the group count has moved on a venue that has kids in it — the amber case.
    private var isRecutting: Bool {
        venueID != nil && kidCount > 0 && draft.groupCount != openingGroupCount
    }

    private var kidCount: Int {
        guard let venueID else { return 0 }
        return store.camp?.players(in: venueID).count ?? 0
    }

    /// The three variants, and why two of them are not the design's words: see `VenueDealSentence`.
    private var dealSentence: String {
        guard venueID != nil, kidCount > 0 else {
            return VenueDealSentence.adding(groups: draft.groupCount)
        }
        guard draft.groupCount != openingGroupCount else {
            return VenueDealSentence.holding(name: title, kids: kidCount)
        }
        return VenueDealSentence.recutting(
            from: openingGroupCount, to: draft.groupCount, kids: kidCount
        )
    }

    // MARK: - Coaches

    /// The people who have joined, or the code that brings them.
    ///
    /// Roamers are in the list. A trainer with no fixed court is exactly the person somebody might
    /// want standing at one venue for the week, and leaving them out would make the picker quietly
    /// disagree with the Staff screen about who is on the team.
    @ViewBuilder
    private var coachBlock: some View {
        if let camp = store.camp, !camp.staff.isEmpty {
            VenueCoachPicker(
                coaches: camp.staff.map { VenueCoachOption(id: $0.id, name: $0.name) },
                selected: coaches
            ) { id in
                if coaches.contains(id) {
                    coaches.remove(id)
                } else {
                    coaches.insert(id)
                }
            }
        } else if let code = store.camp?.inviteCode {
            VenueInviteRow(inviteCode: code)
        }
    }

    // MARK: - Commit

    private var saveButton: some View {
        PrimaryButton(
            ctaTitle,
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButton
        ) {
            Task { await save() }
        }
        .opacity(canSave ? 1 : 0.45)
        .disabled(!canSave)
        // A dimmed button is reachable on its own by Switch Control and by a rotor jump, and
        // "Add venue, dimmed" says nothing about what is missing.
        .accessibilityHint(canSave ? "" : "Give the venue a name first")
    }

    private var ctaTitle: String {
        guard venueID == nil else { return "Save changes" }
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Add venue" : "Add \(trimmed)"
    }

    /// The length bound is `CampName`'s, borrowed for the reason `VenueShapeSheet` borrows it: a
    /// venue name and a camp name are typed into the same kind of box, and `sites.name` carries no
    /// CHECK of its own to mirror.
    ///
    /// No duplicate check here, unlike the pre-creation sheet. It is not that a collision cannot
    /// happen — it is that this write has somewhere to fail: `updateVenue` maps the unique
    /// violation to a 409 and the store raises it, where before the camp exists there is nothing
    /// downstream and the editor is the last chance to refuse.
    private var canSave: Bool {
        !isSaving && CampName.isValid(draft.name.trimmingCharacters(in: .whitespaces))
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        if venueID == nil {
            await add()
        } else {
            await store.updateVenue(shaped(draft))
            await applyCoaches(to: draft.id)
        }

        // Left open on failure, with the store's banner over it, so whatever was typed is still
        // there to try again. Closing on a write that did not land is how a name disappears.
        guard store.errorMessage == nil else { return }
        close()
    }

    /// Creates the venue, then gives it the shape on screen.
    ///
    /// `addVenue(shapedBy:)` is one intent for what used to be two writes at every call site — the
    /// repository's `addVenue` takes no arguments, so a *named* venue has always been an append
    /// followed by an update. The transform receives the venue the repository actually created,
    /// which is what carries the id and the sort index neither this sheet nor its reader can know
    /// in advance.
    ///
    /// The id is recovered afterwards rather than captured inside the transform: the coaches can
    /// only be put on courts once the courts exist, and they do not exist until the write returns.
    private func add() async {
        let before = Set((store.camp?.venues ?? []).map(\.id))
        await store.addVenue(shapedBy: shaped)

        guard store.errorMessage == nil,
              let created = store.camp?.venues.first(where: { !before.contains($0.id) })
        else { return }

        await applyCoaches(to: created.id)
    }

    /// The draft's answers written onto whichever `Venue` is really being saved.
    ///
    /// A function of the draft and nothing else, so it is the same write whether it lands on a
    /// venue the repository has just created or on the one this sheet opened. The four fields it
    /// does *not* touch — the two ranges, the tint's stored copy, the sort index — either have no
    /// control on this screen or are already on the draft.
    private func shaped(_ existing: Venue) -> Venue {
        var updated = existing
        updated.name = draft.name.trimmingCharacters(in: .whitespaces)
        let subtitle = (draft.subtitle ?? "").trimmingCharacters(in: .whitespaces)
        updated.subtitle = subtitle.isEmpty ? nil : subtitle
        updated.icon = draft.icon
        updated.tint = draft.tint
        updated.courtCount = CampShape.clamp(draft.courtCount, into: CampShape.courtRange)
        updated.groupCount = CampShape.clamp(draft.groupCount, into: CampShape.groupRange)
        updated.targetPerGroup = draft.targetPerGroup.map {
            CampShape.clamp($0, into: CampShape.targetRange)
        }
        updated.ageBand = draft.ageBand
        return updated
    }

    /// Puts the picked coaches on courts here and takes the unpicked ones off.
    ///
    /// **A coach is assigned to a court, not to a venue**, and that is the model rather than a
    /// simplification: `CourtAssignment.groupID` is not optional, so "at Sycamore, no court yet"
    /// is not a state a `StaffMember` can be in. Picking somebody therefore seats them on the
    /// first court here that has nobody on it — which is what "sets the default staffing for this
    /// venue" comes to when the venue is made of courts.
    ///
    /// Runs only over what changed. Re-sending an assignment somebody already has would move them
    /// off their own court onto the first free one, which is a person walking to a different court
    /// because a sheet was opened and closed.
    ///
    /// Sequential rather than a task group: each of these is a full camp round trip serialised on
    /// the camp id inside the store anyway, and firing them together only queues them somewhere
    /// less visible.
    private func applyCoaches(to venueID: Venue.ID) async {
        for id in openingCoaches.subtracting(coaches) {
            await store.assignStaff(id, toGroup: nil)
        }

        for id in coaches.subtracting(openingCoaches) {
            // Re-read per coach: the previous iteration took a court, and the camp that knows it
            // is the one that came back from that write.
            guard let free = firstFreeCourt(in: venueID) else { break }
            await store.assignStaff(id, toGroup: free)
        }
    }

    /// The lowest-numbered court here with nobody on it.
    private func firstFreeCourt(in venueID: Venue.ID) -> Group.ID? {
        guard let camp = store.camp else { return nil }
        return camp.groups(in: venueID).first { camp.coach(forGroup: $0.id) == nil }?.id
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            store.dismissSheet()
        }
    }
}

// MARK: - Name fields

/// A venue's name over its subtitle, 9pt apart, in the box screen 11 draws round both:
/// `1.5px #EAEBEE` at radius 13 (`design/Sycamore Flow.dc.html:477-478`).
///
/// Shared by the two venue editors — this one and `VenueShapeSheet`, which edits the same venue
/// one screen before it exists. Three pieces of that block were hoisted out of this file at once
/// (the box became `FormFieldMetrics.venueBox`, the limit rows `VenueLimitRow`, and the icon
/// tiles a file that has since been deleted with the picker); leaving what they compose *into*
/// duplicated would have kept the 9pt gap, the
/// subtitle's grey, the capitalisation rule and the empty-string-to-nil rule in two files each.
///
/// It owns its own focus, unlike `FormField`, which deliberately does not
/// (`FormField.swift:180-183`): the two screens that put a keyboard down before they act do it to
/// a field they hold themselves, and neither of them is this block.
struct VenueNameFields: View {
    @Binding var name: String
    /// Absent is nil in the model and "" in the field; the conversion is here so both callers
    /// cannot disagree about which an empty box means.
    @Binding var subtitle: String?

    @FocusState private var isNameFocused: Bool
    @FocusState private var isSubtitleFocused: Bool

    var body: some View {
        // The keyboard travels down the environment to both fields, which is why `FormField` does
        // not own it (`FormField.swift:20-25`). Capitalised words and no autocorrect: a venue is
        // a proper noun, and "LATC" is not a typo.
        let fields = VStack(spacing: 9) {
            FormField(
                "Venue name",
                text: $name,
                label: "Venue name",
                metrics: .venueBox,
                type: .rowTitle,
                focus: $isNameFocused
            )
            FormField(
                "Subtitle, e.g. Higher level",
                text: subtitleText,
                label: "Subtitle",
                metrics: .venueBox,
                // The design gives this field a plain `500 14px` — no line-height multiple.
                // `.bodyAlt`'s 1.5 is for wrapped copy; on a one-line field it only adds 7pt
                // of leading under a single line.
                type: .bodyAlt.lineHeight(nil),
                valueColor: Theme.inkTertiary,
                focus: $isSubtitleFocused
            )
        }
        .autocorrectionDisabled()

        #if os(iOS)
        return fields
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return fields
        #endif
    }

    private var subtitleText: Binding<String> {
        Binding(
            get: { subtitle ?? "" },
            set: { subtitle = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Limits row

/// A row of a venue's LIMITS card: what the number is, what it means, and the control that sets
/// it. `padding:11px 13px` with the title `700 14.5` over a `500 11.5` grey line
/// (`design/Sycamore Flow.dc.html:488`).
///
/// Shared with `VenueShapeSheet` and with `VenueCountsCard` rather than drawn three times, for the
/// reason `Motion.swift:12` gives: two features needing the same thing. All three are rows of the
/// same card in the same drawing — before the camp exists and after — so a row that drifted
/// between them would be one card in three shapes.
///
/// Named `VenueLimitRow` rather than `LimitRow` on the way out of `private`: a bare `LimitRow`
/// is a name three features could each want. Still drawn by `VenueShapeFields`' camp-wide rates,
/// which is why cutting this sheet's Limits card did not take it with them.
struct VenueLimitRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        CardRow(spacing: 10, horizontalPadding: 13, verticalPadding: 11) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .typeStyle(.rowLabel, color: Theme.ink)
                Text(detail)
                    // `inkTertiary` rather than the design's `#8A8E96`: these lines are body copy
                    // — one of them is the only place "over flags amber, never blocks" is said —
                    // and `inkMuted` is under 4.5:1 on white where `inkTertiary` is 4.6:1.
                    .typeStyle(.rowSubtitleSmall, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

// MARK: - Placeholder

private extension Venue {
    /// Only reachable if a sheet outlives the venue it was opened for. Keeps the sheet from
    /// having to model "no venue" in every subview.
    static let placeholder = Venue(
        name: "",
        subtitle: nil,
        icon: Venue.iconOptions[0],
        tint: .moss,
        courtCount: 1,
        groupCount: 1,
        coachMin: 0,
        coachMax: 0,
        playerMin: 0,
        playerMax: 0
    )
}

// MARK: - Previews

#Preview("Venue sheet") {
    VenueSheetPreviewHarness(venueID: SampleData.sycamore.id)
}

#Preview("Venue sheet — short on coaches") {
    VenueSheetPreviewHarness(venueID: SampleData.latc.id)
}

/// Adding one to a camp that already exists — the mode that used to be an "Add" button appending
/// `Venue 3` and nothing else.
#Preview("Venue sheet — a new venue") {
    VenueSheetPreviewHarness(venueID: nil)
}

/// A camp nobody has joined yet, so the coach row is the invite plate instead of a chip row.
/// Westside Swim has three venues, 74 kids and no staff at all.
#Preview("Venue sheet — nobody has joined") {
    VenueSheetPreviewHarness(
        store: .previewAdmin,
        venueID: SampleData.westsideSwim.orderedVenues[0].id
    )
}

#Preview("Venue sheet — accessibility1") {
    VenueSheetPreviewHarness(venueID: SampleData.sycamore.id)
        .environment(\.dynamicTypeSize, .accessibility1)
}

private struct VenueSheetPreviewHarness: View {
    var store: AppStore = .preview
    let venueID: Venue.ID?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.scrim.ignoresSafeArea()
            sheet
                .frame(height: 612)
        }
        .frame(height: 700)
        .background(Theme.canvas)
    }

    @ViewBuilder
    private var sheet: some View {
        if let venueID {
            VenueSheet(store: store, venueID: venueID)
        } else {
            VenueSheet(store: store, onClose: {})
        }
    }
}
