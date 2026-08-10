//
//  VenueShapeSheet.swift
//  Sycamore
//
//  Screen 11, one screen early — a venue's name, its emoji and its limits, edited on `8b` before
//  the camp that will hold it exists.
//
//  Named for what it edits. `VenueSheet` edits a `Venue`, a row of `sites` that has been written;
//  this edits a `VenueShape`, a row of a form that has not. They draw almost the same blocks and
//  they are not interchangeable, so the names have to say which is which.
//
//  ── Presented by `CreateCampView`, not by the root ────────────────────────────────────────────
//
//  `CreateCampView` holds `@State private var editingVenue: VenueShape?` and a `.sheet(item:)`.
//  No case is added to `ActiveSheet`, and here that is structural rather than a preference:
//  `MainTabView` is what presents `ActiveSheet` (`RootView.swift:95`), and `MainTabView` is not
//  mounted while `store.camp == nil` — `RootView.swift:44-53` draws `CampPickerView` instead, and
//  this screen is pushed from inside it. There is nothing on screen that could present the sheet.
//  `BlockEditorSheet.swift:26-33` records the same rule from the other direction.
//
//  No wrapper type either. `VenueShape` is already `Identifiable`, unlike the bare `UUID` that
//  forced `PickupTarget.swift:12` to exist.
//
//  ── Held and committed, never live-written ───────────────────────────────────────────────────
//
//  `VenueSheet` pushes every keystroke out with `.onChange(of: draft)` (`:50-52`), which is right
//  there and wrong here twice over. There is nothing to write to — the camp does not exist, and
//  `CampShape` is a form. And a live write leaves no moment at which an invalid name can be
//  refused: by the time "Main Courts" had been typed over an existing "Main Courts" it would
//  already be in the shape. So "Save venue" is the commit, and everything above it is a draft.
//  `BlockEditorSheet.swift:35-38` records the same reasoning for `schedule_blocks.title`.
//
//  The draft's type is `VenueShape` itself, held as `@State`. No mirror struct: the two numeric
//  fields need `String` mirrors because a half-typed number is not an `Int`, and those are the
//  only two things a `VenueShape` cannot hold.
//
//  ── No status banner, and no coaches ─────────────────────────────────────────────────────────
//
//  Screen 11 opens with "Within range" (`design/Sycamore Flow.dc.html:474`), which is a *staffing*
//  reading — `Camp.staffingStatus(for:)` counts the coaches standing in a venue. On `8b` there is
//  no staff, no roster and no camp, so the banner could only ever say one thing, and a banner that
//  cannot change is a decoration.
//
//  The same absence takes the design's Coaches block with it, and the argument is one step
//  stronger. `sheet-shVenue` draws either a row of staff chips or, when nobody has joined, an
//  invite plate reading "Invite coaches · {code}". Before the camp exists there is no staff to
//  chip **and no code to print** — `Camp.inviteCode` is minted by `Camp.make(from:)` at the end of
//  the flow — so the block could only be drawn as an empty row or as a plate with a hole in it.
//  `VenueSheet` draws both halves, one screen later, where both have an answer.
//
//  ── Add, then edit ───────────────────────────────────────────────────────────────────────────
//
//  This sheet opens on rows that are not on the list yet. "Add a venue" used to append a row named
//  `Venue 3` carrying the previous venue's numbers and leave somebody to find it; it now opens
//  here on `CampShape.newVenue()` — seeded, not appended — and the shape hears nothing until `Add
//  {name}` is pressed. Which is why the CTA has two spellings and Remove is drawn only for a row
//  that is already on the list: there is nothing to remove from a venue nobody has added.
//

import SwiftUI

struct VenueShapeSheet: View {

    /// The camp as it stands. Read for exactly two things: whether a name is taken, and the
    /// camp-wide rates the court stepper re-derives the two limits from.
    let shape: CampShape
    /// "court", "field", "lane" — what this sport calls a group.
    let courtNoun: String
    /// Whether this row is already on the list. Decides the CTA's words and whether Remove is
    /// drawn at all — see the file header.
    let isEditing: Bool
    let onSave: (VenueShape) -> Void
    /// Takes the venue back off the list.
    ///
    /// Not optional any more. It was `(() -> Void)?` so that the *last* venue in a camp could be
    /// handed nothing and have the button hidden — one venue being the fewest a camp could have —
    /// and `8b` is drawn with no venues at all, so removing the only one lands on a state the
    /// design draws rather than on an action that would have to refuse. With the one caller
    /// always supplying it, the optional was a branch nothing could take.
    let onRemove: () -> Void
    let onClose: () -> Void

    @State private var draft: VenueShape

    /// The two limits, as text — what is in the boxes, which is not always a number.
    ///
    /// A stepper never has this problem and these could not be steppers. `playerMax` reaches
    /// `courtRange.upperBound × kidsRange.upperBound` — 384 — and `IntakeStepper` has never been
    /// asked for a range past 24; two hundred taps is not a control. A field can hold "4" on the
    /// way to "48", and it can hold "" on the way to anything, so the value is `Int(text)` and
    /// `nil` is what makes the sheet invalid.
    ///
    /// Every number that parses is written straight into `draft` (see `numberBinding`), so the
    /// row's numbers are never a stale second copy of what is on screen — `draft` is what the
    /// header reads and what Save sends, and these two are only the raw keystrokes behind it.
    @State private var maxKidsText: String
    @State private var minCoachesText: String

    @FocusState private var isMaxKidsFocused: Bool
    @FocusState private var isMinCoachesFocused: Bool

    /// Wide enough for three digits and a caret. Scaled, because it is the one measurement here
    /// that is a *text* width — at `.accessibility3` "384" is half again as wide and a fixed box
    /// would truncate the number it exists to show. `IntakeStepper` scales its own for the same
    /// reason (`:31-32`).
    @ScaledMetric(relativeTo: .body) private var numberFieldWidth: CGFloat = 72

    /// What the row was called on the way in, or nil for a row nobody has named yet.
    ///
    /// The `Venue <digits>` pattern is reserved so `CampShape.removeVenue` can tell a typed name
    /// from a number it handed out — but an *existing* row arrives wearing one of those numbers,
    /// and refusing it would mean no venue could be saved without first being renamed. So the rule
    /// is "refused as a **typed** name": positional is fine if it is the one this row already had.
    ///
    /// Nil is what makes that exemption stop at the sheet's other door. A row being added carries
    /// a positional name too — `newVenue()` seeds one — but it is a placeholder rather than a name
    /// somebody is keeping, and exempting it would have made "Add Venue 3" a live button. Which is
    /// the thing this whole change exists to stop: a venue on the list called by its number.
    private let originalName: String?

    /// Whether the name field has been touched.
    ///
    /// Only so that a sheet which opens on an empty field does not greet the reader with "A venue
    /// needs a name." in red before they have done anything. The refusal is still there the whole
    /// time — the button is dimmed from the first frame — it simply does not shout until there is
    /// something to shout about.
    @State private var hasTypedName = false

    init(
        venue: VenueShape,
        shape: CampShape,
        courtNoun: String,
        isEditing: Bool,
        onSave: @escaping (VenueShape) -> Void,
        onRemove: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.shape = shape
        self.courtNoun = courtNoun
        self.isEditing = isEditing
        self.onSave = onSave
        self.onRemove = onRemove
        self.onClose = onClose
        self.originalName = isEditing ? venue.name : nil

        var opening = venue
        // A new row opens with the field empty and the design's own placeholder showing, rather
        // than with `Venue 3` typed into it and refused a line below. Everything *else* the seed
        // decided — the emoji, the courts, both limits — is left in place, so this is a filled-in
        // form with one blank at the top and not an interrogation.
        if !isEditing { opening.name = "" }

        _draft = State(initialValue: opening)
        _maxKidsText = State(initialValue: "\(venue.maxKids)")
        _minCoachesText = State(initialValue: "\(venue.minCoaches)")
    }

    var body: some View {
        // Both answers worked out once and handed down, rather than left as computed properties
        // the blocks reach for. Each is asked for by its own error line, by the save button's
        // opacity, by its `disabled`, and twice more by the accessibility hint — five evaluations
        // of one answer per pass. `nameProblem` alone trims, counts unicode scalars, runs
        // `isPositionalName` and lowercases every other venue's name, so at eight venues that was
        // about a hundred throwaway strings for each character typed into the name field.
        let nameProblem = nameProblem
        let numberProblem = numberProblem
        let isValid = nameProblem == nil && numberProblem == nil

        return SheetChrome(
            title: title,
            subtitle: draft.shapeLine(noun: courtNoun),
            detentFraction: OnboardingMetrics.venueEditorDetent,
            onClose: onClose
        ) {
            SheetSectionHeader("Name", bottomPadding: Spacing.small)
            nameBlock(problem: nameProblem)
                .padding(.bottom, 18)

            SheetSectionHeader("Icon")
            iconGrid

            VenueFieldLabel(title: "Age group")
            VenueAgeBandPicker(ageBand: $draft.ageBand)

            VenueFieldLabel(title: "Numbers")
            VenueCountsCard(
                courtNoun: courtNoun,
                courts: courtsBinding,
                groups: $draft.groups,
                targetPerGroup: $draft.targetPerGroup
            )

            // No kids anywhere yet — the camp is not created until the end of the flow — so this
            // is always the "what adding it will do" variant, and never amber.
            VenueDealLine(sentence: VenueDealSentence.adding(groups: draft.groups))

            SheetSectionHeader("Limits", topPadding: 18)
            limitsBlock(problem: numberProblem)

            saveButton(isValid: isValid, hint: nameProblem ?? numberProblem ?? "")
                .padding(.top, 18)

            if isEditing {
                // Nought kids, always: nothing has been imported and no camp exists to import
                // into, so the second tap reads "…it for good" rather than naming a head count.
                VenueRemoveButton(kidCount: 0, onRemove: onRemove)
                    .padding(.top, 9)
            }
        }
    }

    /// The sheet is titled by what the venue is called, and falls back to what it was called
    /// rather than to a placeholder — a title that reads "Untitled" while somebody is midway
    /// through clearing the field says less than the name they are replacing. A row that has never
    /// had a name falls back to the design's own `sheetTitle` for the case: "New venue".
    private var title: String {
        if !trimmedName.isEmpty { return trimmedName }
        return originalName ?? "New venue"
    }

    /// `Add Main Courts`, `Add venue`, or `Save changes` — the design's three, in its own words
    /// (`state1.js:252`).
    private var ctaTitle: String {
        if isEditing { return "Save changes" }
        return trimmedName.isEmpty ? "Add venue" : "Add \(trimmedName)"
    }

    // MARK: - Name

    private func nameBlock(problem: String?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // The same block `VenueSheet` draws, because it is the same block of screen 11 — see
            // `VenueNameFields`. Only the error line under it belongs to this screen: there is
            // nowhere else a name can be refused before it reaches the camp.
            VenueNameFields(name: nameBinding, subtitle: $draft.subtitle)
            // Held back only for the field nobody has touched on a sheet that opened empty. Every
            // other refusal — too long, reserved, already taken — needs a name to have been typed
            // first, so this is the one case where the message would arrive before the mistake.
            if let problem, hasTypedName || isEditing {
                errorLine(problem)
            }
        }
    }

    /// The name, and the note that somebody has been at it.
    private var nameBinding: Binding<String> {
        Binding(
            get: { draft.name },
            set: { typed in
                draft.name = typed
                hasTypedName = true
            }
        )
    }

    // MARK: - Icon

    /// Screen 11's grid, drawn here at last. `8b`'s row used to hide these six behind a `Menu` on
    /// the tile, on the argument that "a card's worth of height would not fit the row" — which was
    /// true of the row and is not true of a sheet. This is where they fit.
    private var iconGrid: some View {
        // Nothing else is written. `VenueShape.tint` is computed from the emoji, so the plate is
        // already the right colour by the time this returns — unlike `VenueSheet`, which has a
        // stored tint to bring along.
        VenueIconGrid(selected: draft.icon) { draft.icon = $0 }
    }

    // MARK: - Limits

    private func limitsBlock(problem: String?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            limitsCard
            if let problem {
                errorLine(problem)
            }
        }
    }

    /// The two absolutes the auto-partition works between — which the design's sheet does not draw
    /// and this screen keeps anyway.
    ///
    /// `sheet-shVenue` asks for courts, groups, a target and an age band, and stops. It can: in the
    /// design these are the venue's *whole* shape. Here they are not — `sites.player_max` and
    /// `sites.coach_min` are columns with a CHECK between them, `8b`'s "Every venue" card is two
    /// rates that write into them, and this sheet is the only place a venue may sit off those
    /// rates. Dropping the pair to match the drawing would have taken the per-venue override away
    /// from the card that offers it.
    ///
    /// The court stepper that used to head this card has gone up to `VenueCountsCard`, beside the
    /// group count it is so easily confused with. Its detail line went with it.
    private var limitsCard: some View {
        Card(radius: Radius.input, borderColor: Theme.strokeAlt) {
            // Where the design's static `Players, min – max` reading used to be. Half of that
            // reading is now a control and the other half is a constant, so the detail line is
            // where the constant is stated in words rather than drawn as a number nobody can move.
            VenueLimitRow(
                title: "Kids at most",
                detail: "Auto-partition ceiling. The floor stays 0."
            ) {
                numberField(
                    "Kids at most",
                    text: numberBinding($maxKidsText, into: \.maxKids, within: CampShape.venueKidsRange),
                    ceiling: CampShape.venueKidsRange.upperBound,
                    focus: $isMaxKidsFocused
                )
            }

            VenueLimitRow(
                title: "Coaches at least",
                detail: "Fewer than this flags the venue short. One over is still in range."
            ) {
                numberField(
                    "Coaches at least",
                    text: numberBinding($minCoachesText, into: \.minCoaches, within: CampShape.venueCoachRange),
                    ceiling: CampShape.venueCoachRange.upperBound,
                    focus: $isMinCoachesFocused
                )
            }
        }
    }

    /// The court stepper stays a stepper — its range is `1...40` and the row on `8b` has one too,
    /// so this is the same control in the same units.
    ///
    /// It goes through `VenueShape.setCourts(_:kidsPerCourt:coachesPerCourt:)`, which is the same
    /// call `CampShape.setCourts(_:for:)` makes for the row's own stepper. The draft is detached
    /// from the shape until Save, so it cannot go through the shape's mutator — but the sequence
    /// underneath both is one method, so the two steppers agree by construction rather than by
    /// inspection, and a third consequence of changing the courts is added in one place.
    ///
    /// The two text mirrors are refreshed here because this is the one write that moves them
    /// without anybody typing.
    private var courtsBinding: Binding<Int> {
        Binding(
            get: { draft.courts },
            set: { courts in
                draft.setCourts(
                    courts,
                    kidsPerCourt: shape.kidsPerCourt,
                    coachesPerCourt: shape.coachesPerCourt
                )
                maxKidsText = "\(draft.maxKids)"
                minCoachesText = "\(draft.minCoaches)"
            }
        )
    }

    /// What is typed, kept as typed — and, whenever it parses, written through into the row.
    ///
    /// The alternative was to read `Int(text)` only at Save, which leaves the row's own number a
    /// stale copy of what the box says for as long as the sheet is open: the header above reads
    /// `draft.limitsLine`, so typing 41 over 48 left it saying "up to 48 kids" until the sheet
    /// closed. One number in one place, and the text is only the keystrokes on their way there.
    ///
    /// Clamped on the way in, which is why the header answers a typed 999 with 384: that is the
    /// most a venue can be given, and saying so while the finger is still on the keypad is more
    /// use than saying it after the sheet has gone.
    private func numberBinding(
        _ text: Binding<String>,
        into value: WritableKeyPath<VenueShape, Int>,
        within range: ClosedRange<Int>
    ) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { typed in
                text.wrappedValue = typed
                guard let parsed = Int(typed) else { return }
                draft[keyPath: value] = CampShape.clamp(parsed, into: range)
            }
        )
    }

    /// A field sized to three digits, on the plate a stepper's track is drawn on.
    private func numberField(
        _ label: String,
        text: Binding<String>,
        ceiling: Int,
        focus: FocusState<Bool>.Binding
    ) -> some View {
        let field = FormField(
            "\(ceiling)",
            text: text,
            label: label,
            metrics: .numberBox,
            type: .intakeStepperValue,
            focus: focus
        )
        .frame(width: numberFieldWidth)
        .multilineTextAlignment(.center)

        #if os(iOS)
        return field
            // A number pad has no return key, which is why the sheet's way out is the button
            // below rather than `.onSubmit`.
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
        #else
        return field
        #endif
    }

    // MARK: - Validity

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespaces)
    }

    private var maxKids: Int? { Int(maxKidsText) }
    private var minCoaches: Int? { Int(minCoachesText) }

    /// Why this name cannot be saved, in the order the reader would find out.
    ///
    /// The length is `CampName.lengthLimits` counted through `CharLength.of(_:fits:)`, and this is
    /// the app's **own** rule rather than a mirror of a column: `sites` predates
    /// `supabase/migrations/` — there is no `create table` for it anywhere in this repository —
    /// and it carries no CHECK on `name`. `CampName` genuinely mirrors one, which is why the bound
    /// is borrowed from there rather than invented here: a venue name and a camp name are typed
    /// into the same kind of box and there is no reason for them to differ.
    private var nameProblem: String? {
        if trimmedName.isEmpty {
            return "A venue needs a name."
        }
        guard CharLength.of(trimmedName, fits: CampName.lengthLimits) else {
            return "That is longer than \(CampName.lengthLimits.upperBound) characters."
        }
        // `originalName` is nil for a row being added, so the exemption cannot fire there and the
        // seeded `Venue 3` is refused like any other typed number — see the property's own note.
        if CampShape.isPositionalName(trimmedName),
           trimmedName.lowercased() != originalName?.lowercased() {
            return "\(trimmedName) is how setup numbers a venue nobody has named. Give it a name of its own."
        }
        guard shape.isVenueNameAvailable(trimmedName, excluding: draft.id) else {
            return "Another venue in this camp is already called that."
        }
        return nil
    }

    private var numberProblem: String? {
        switch (maxKids, minCoaches) {
        case (nil, nil): "Both limits need a number."
        case (nil, _): "Kids at most needs a number."
        case (_, nil): "Coaches at least needs a number."
        default: nil
        }
    }

    /// `.intakeNote` rather than `.intakeRowMeta`: these lines wrap, and it is the style section
    /// 8's two other inline failures already wear (`CampPickerView.swift:147`,
    /// `BringInTheWeekView.swift:89`).
    private func errorLine(_ message: String) -> some View {
        Text(message)
            .typeStyle(.intakeNote, color: Theme.danger)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Commit

    private func saveButton(isValid: Bool, hint: String) -> some View {
        PrimaryButton(
            ctaTitle,
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButton
        ) {
            save()
        }
        // `0.45`, which is the design's own `ctaOpacity` for a sheet with no name in it.
        .opacity(isValid ? 1 : 0.45)
        .disabled(!isValid)
        // The inline lines above say why, and they are read in order — but a dimmed button is
        // reachable on its own by Switch Control and by a rotor jump, and "Save venue, dimmed" on
        // its own says nothing. Empty rather than optional: no hint is what an empty hint is.
        .accessibilityHint(isValid ? "" : hint)
    }

    /// Only the two names are trimmed here. The limits were clamped on their way into `draft` as
    /// they were typed, so there is nothing left to do to them — and `CampShape.venue(applying:)`
    /// clamps again anyway, which is the funnel that matters: it is the one place every venue
    /// reaches the wire, whether or not this sheet was ever opened.
    private func save() {
        var saved = draft
        saved.name = trimmedName
        let subtitle = (draft.subtitle ?? "").trimmingCharacters(in: .whitespaces)
        saved.subtitle = subtitle.isEmpty ? nil : subtitle
        onSave(saved)
    }
}

// MARK: - Previews

#Preview("Venue editor") {
    VenueShapeSheetPreviewHarness(venueCount: 2)
}

/// The last venue in the camp, which now offers Remove like every other one — the shape it leaves
/// behind is `8b`'s "No venues yet" rather than a state nothing could draw.
#Preview("Venue editor — the last venue") {
    VenueShapeSheetPreviewHarness(venueCount: 1)
}

/// "Add a venue" on a camp that already has two: a row that is not on the list, so the CTA reads
/// `Add …` and there is no Remove under it.
#Preview("Venue editor — a new venue") {
    VenueShapeSheetPreviewHarness(venueCount: 2, isEditing: false)
}

/// A venue that has been given a shape of its own — four groups on six courts, a target, and a
/// nine-to-twelve age band — which is the whole point of the sheet and the state no other preview
/// reaches. The band is closed at both ends deliberately: it is the shape the old three-case
/// `AgeBand` could not say at all, so it is the one worth drawing.
#Preview("Venue editor — shaped") {
    VenueShapeSheetPreviewHarness(venueCount: 2, shaping: true)
}

/// The type ramp at the app's cap. Every label wraps, every stepper grows, and the two number
/// fields have to keep three digits.
#Preview("Venue editor — accessibility1") {
    VenueShapeSheetPreviewHarness(venueCount: 2, shaping: true)
        .environment(\.dynamicTypeSize, .accessibility1)
}

private struct VenueShapeSheetPreviewHarness: View {
    let venueCount: Int
    var isEditing = true
    var shaping = false

    var body: some View {
        var shape = CampShape.initial(venueCount: venueCount, courts: 6)
        if shaping {
            shape.venues[0].name = "Main Courts"
            shape.venues[0].subtitle = "Higher level"
            shape.venues[0].groups = 4
            shape.venues[0].targetPerGroup = 12
            shape.venues[0].ageBand = .between(9, 12)
        }
        let venue = isEditing ? shape.venues[0] : shape.newVenue()

        return ZStack(alignment: .bottom) {
            Theme.scrim.ignoresSafeArea()
            VenueShapeSheet(
                venue: venue,
                shape: shape,
                courtNoun: "court",
                isEditing: isEditing,
                onSave: { _ in },
                onRemove: {},
                onClose: {}
            )
            .frame(height: 630)
        }
        .frame(height: 700)
        .background(Theme.canvas)
    }
}
