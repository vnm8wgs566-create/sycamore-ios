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
//  ── No status banner ─────────────────────────────────────────────────────────────────────────
//
//  Screen 11 opens with "Within range" (`design/Sycamore Flow.dc.html:474`), which is a *staffing*
//  reading — `Camp.staffingStatus(for:)` counts the coaches standing in a venue. On `8b` there is
//  no staff, no roster and no camp, so the banner could only ever say one thing, and a banner that
//  cannot change is a decoration.
//

import SwiftUI

struct VenueShapeSheet: View {

    /// The camp as it stands. Read for exactly two things: whether a name is taken, and the
    /// camp-wide rates the court stepper re-derives the two limits from.
    let shape: CampShape
    /// "court", "field", "lane" — what this sport calls a group.
    let courtNoun: String
    let onSave: (VenueShape) -> Void
    /// `nil` for the last venue in the camp, which cannot go. Hides the button rather than
    /// disabling it: a control that can never be used is not a control.
    let onRemove: (() -> Void)?
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

    @State private var isConfirmingRemoval = false

    @FocusState private var isMaxKidsFocused: Bool
    @FocusState private var isMinCoachesFocused: Bool

    /// Wide enough for three digits and a caret. Scaled, because it is the one measurement here
    /// that is a *text* width — at `.accessibility3` "384" is half again as wide and a fixed box
    /// would truncate the number it exists to show. `IntakeStepper` scales its own for the same
    /// reason (`:31-32`).
    @ScaledMetric(relativeTo: .body) private var numberFieldWidth: CGFloat = 72

    /// What the row was called on the way in.
    ///
    /// The `Venue <digits>` pattern is reserved so `CampShape.removeVenue` can tell a typed name
    /// from a number it handed out — but the row arrives *wearing* one of those numbers, and
    /// refusing it would mean no venue could be saved without first being renamed. So the rule is
    /// "refused as a **typed** name": positional is fine if it is the one this row already had.
    private let originalName: String

    init(
        venue: VenueShape,
        shape: CampShape,
        courtNoun: String,
        onSave: @escaping (VenueShape) -> Void,
        onRemove: (() -> Void)?,
        onClose: @escaping () -> Void
    ) {
        self.shape = shape
        self.courtNoun = courtNoun
        self.onSave = onSave
        self.onRemove = onRemove
        self.onClose = onClose
        self.originalName = venue.name
        _draft = State(initialValue: venue)
        _maxKidsText = State(initialValue: "\(venue.maxKids)")
        _minCoachesText = State(initialValue: "\(venue.minCoaches)")
    }

    var body: some View {
        SheetChrome(
            title: title,
            subtitle: draft.limitsLine,
            detentFraction: OnboardingMetrics.venueEditorDetent,
            onClose: onClose
        ) {
            SheetSectionHeader("Name", bottomPadding: Spacing.small)
            nameBlock
                .padding(.bottom, 18)

            SheetSectionHeader("Icon")
            iconGrid
                .padding(.bottom, 18)

            SheetSectionHeader("Limits")
            limitsBlock

            saveButton
                .padding(.top, 18)

            removeButton
        }
        .confirmationDialog(
            "Remove \(title)?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove venue", role: .destructive) { onRemove?() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Nothing has been created yet, so nothing is lost but what is on this screen.")
        }
    }

    /// The sheet is titled by what the venue is called, and falls back to what it was called
    /// rather than to a placeholder — a title that reads "Untitled" while somebody is midway
    /// through clearing the field says less than the name they are replacing.
    private var title: String {
        trimmedName.isEmpty ? originalName : trimmedName
    }

    // MARK: - Name

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            // The same block `VenueSheet` draws, because it is the same block of screen 11 — see
            // `VenueNameFields`. Only the error line under it belongs to this screen: there is
            // nowhere else a name can be refused before it reaches the camp.
            VenueNameFields(name: $draft.name, subtitle: $draft.subtitle)
            if let nameProblem {
                errorLine(nameProblem)
            }
        }
    }

    // MARK: - Icon

    /// Screen 11's grid, drawn here at last. `8b`'s row used to hide these six behind a `Menu` on
    /// the tile, on the argument that "a card's worth of height would not fit the row" — which was
    /// true of the row and is not true of a sheet. This is where they fit.
    private var iconGrid: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(Venue.iconOptions, id: \.self) { icon in
                VenueIconTile(icon: icon, isSelected: draft.icon == icon) {
                    draft.icon = icon
                }
            }
        }
        // Nothing else is written. `VenueShape.tint` is computed from the emoji, so the plate is
        // already the right colour by the time this returns — unlike `VenueSheet`, which has a
        // stored tint to keep in step.
        .sensoryFeedback(.selection, trigger: draft.icon)
    }

    // MARK: - Limits

    private var limitsBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            limitsCard
            if let numberProblem {
                errorLine(numberProblem)
            }
        }
    }

    private var limitsCard: some View {
        Card(radius: Radius.input, borderColor: Theme.strokeAlt) {
            VenueLimitRow(
                title: courtsTitle,
                detail: "Moving this re-derives both numbers below."
            ) {
                IntakeStepper(
                    value: courtsBinding,
                    range: CampShape.courtRange,
                    label: courtsTitle,
                    valueWidth: 34
                )
            }

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

    private var courtsTitle: String { "\(courtNoun.capitalized)s" }

    /// The court stepper stays a stepper — its range is `1...16` and the row on `8b` has one too,
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

    private var isValid: Bool { nameProblem == nil && numberProblem == nil }

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
        if CampShape.isPositionalName(trimmedName),
           trimmedName.lowercased() != originalName.lowercased() {
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

    private var saveButton: some View {
        PrimaryButton(
            "Save venue",
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButton
        ) {
            save()
        }
        .opacity(isValid ? 1 : 0.45)
        .disabled(!isValid)
        // The inline lines above say why, and they are read in order — but a dimmed button is
        // reachable on its own by Switch Control and by a rotor jump, and "Save venue, dimmed" on
        // its own says nothing. Empty rather than optional: no hint is what an empty hint is.
        .accessibilityHint(isValid ? "" : (nameProblem ?? numberProblem ?? ""))
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

    @ViewBuilder
    private var removeButton: some View {
        if onRemove != nil {
            PrimaryButton(
                "Remove this venue",
                tone: .danger,
                height: nil,
                radius: Radius.row,
                font: .buttonCompact
            ) {
                isConfirmingRemoval = true
            }
            .padding(.top, 9)
        }
    }
}

// MARK: - Previews

#Preview("Venue editor") {
    VenueShapeSheetPreviewHarness(venueCount: 2)
}

#Preview("Venue editor — the last venue") {
    VenueShapeSheetPreviewHarness(venueCount: 1)
}

private struct VenueShapeSheetPreviewHarness: View {
    let venueCount: Int

    var body: some View {
        let shape = CampShape.initial(venueCount: venueCount, courts: 6)

        ZStack(alignment: .bottom) {
            Theme.scrim.ignoresSafeArea()
            VenueShapeSheet(
                venue: shape.venues[0],
                shape: shape,
                courtNoun: "court",
                onSave: { _ in },
                onRemove: venueCount > 1 ? {} : nil,
                onClose: {}
            )
            .frame(height: 630)
        }
        .frame(height: 700)
        .background(Theme.canvas)
    }
}
