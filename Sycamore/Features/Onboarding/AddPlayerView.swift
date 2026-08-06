//
//  AddPlayerView.swift
//  Sycamore
//
//  `8e` — Add a player. For the under-11s and the walk-ins.
//
//  Three fields, two rows of chips and one line explaining the venue it picked. Nothing else:
//  a kid who turns up at 8:55 is added by somebody holding a clipboard in one hand.
//
//  The same screen does double duty as the way to fill a gap the file left, which is what `8d`'s
//  "Fix" opens. It is the same three questions with two of them already answered, so a second
//  screen for it would be the same screen with a different title — see `Mode`.
//

import SwiftUI

struct AddPlayerView: View {

    /// New by hand, or filling in what the office's file left out.
    enum Mode: Hashable, Sendable {
        case new
        case fix(IntakePlayer)
    }

    let mode: Mode
    /// The venues drawn as chips. `8e` offers the camp's whole set and defaults to the first.
    let venues: [VenueShape]
    let onSave: (IntakePlayer) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    /// Held as text rather than `Int?` so the field can be empty, and so a half-typed "1" is not
    /// an age the screen believes in.
    @State private var age = ""
    @State private var gender: Gender?
    @State private var venueIndex = 0
    @FocusState private var focus: Field?
    /// The design's 88pt label column. Scaled, because at the larger type sizes "First name"
    /// needs three lines inside 88 and the field beside it ends up taller than the row.
    @ScaledMetric(relativeTo: .callout) private var labelWidth: CGFloat = 88

    private enum Field: Hashable { case first, last, age }

    init(mode: Mode = .new, venues: [VenueShape], onSave: @escaping (IntakePlayer) -> Void) {
        self.mode = mode
        self.venues = venues
        self.onSave = onSave

        if case .fix(let player) = mode {
            _firstName = State(initialValue: player.firstName)
            _lastName = State(initialValue: player.lastName)
            _age = State(initialValue: player.age.map(String.init) ?? "")
            _gender = State(initialValue: player.gender)
        }
    }

    var body: some View {
        let screen = VStack(spacing: 0) {
            StatusBarMock()

            IntakeHeader(
                title: title,
                subtitle: subtitle,
                backLabel: "Players",
                onBack: { dismiss() }
            )

            Hairline(color: Theme.hairline)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.grouped)
        .overlay(alignment: .bottom) { saveButton }
        .navigationBarBackButtonHidden(true)

        #if os(iOS)
        return screen.toolbar(.hidden, for: .navigationBar)
        #else
        return screen
        #endif
    }

    // MARK: Copy

    private var title: String {
        switch mode {
        case .new: "New player"
        case .fix(let player): player.displayName
        }
    }

    private var subtitle: String {
        switch mode {
        case .new: "Joins unranked until the first sort"
        // The gap is named rather than described, because it is the one thing this screen is
        // open to settle.
        case .fix(let player): player.issue?.label ?? "Joins unranked until the first sort"
        }
    }

    private var saveTitle: String {
        let name = firstName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "Add the player" }
        return mode.isFix ? "Save \(name)" : "Add \(name)"
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                namesCard
                genderCard
                if !venues.isEmpty { venueCard }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, Spacing.tabBarClearance)
        }
        // The age field runs a number pad, which has no return key to put away. Dragging the
        // form is the way out of it.
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Name and age

    private var namesCard: some View {
        Card {
            field("First name", text: $firstName, focus: .first, submit: .next)
            field("Last name", text: $lastName, focus: .last, submit: .next)
            field("Age", text: $age, focus: .age, submit: .done, isNumeric: true)
        }
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        focus target: Field,
        submit: SubmitLabel,
        isNumeric: Bool = false
    ) -> some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            Text(label)
                .typeStyle(.sheetSubtitle, color: Theme.inkFaint)
                .frame(width: labelWidth, alignment: .leading)

            textField(text, focus: target, submit: submit, isNumeric: isNumeric)
        }
        // The label is part of the field's target: tapping the word "Age" puts the caret in it.
        .onTapGesture { focus = target }
    }

    private func textField(
        _ text: Binding<String>,
        focus target: Field,
        submit: SubmitLabel,
        isNumeric: Bool
    ) -> some View {
        let base = TextField("", text: text)
            .textFieldStyle(.plain)
            .typeStyle(.body, color: Theme.ink)
            .focused($focus, equals: target)
            .autocorrectionDisabled()

        #if os(iOS)
        return base
            .keyboardType(isNumeric ? .numberPad : .default)
            .textInputAutocapitalization(isNumeric ? .never : .words)
            .submitLabel(submit)
        #else
        return base
        #endif
    }

    // MARK: Gender

    private var genderCard: some View {
        Card(isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Gender")
                    .typeStyle(.sheetSubtitle, color: Theme.inkFaint)

                HStack(spacing: Spacing.tight) {
                    ForEach(Gender.intakeOptions, id: \.self) { option in
                        Chip(
                            option.intakeLabel,
                            isSelected: gender == option,
                            metrics: .intake,
                            fillsWidth: true
                        ) {
                            gender = option
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(Spacing.gutterWide)
        }
    }

    // MARK: Venue

    private var venueCard: some View {
        Card(isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Venue")
                    .typeStyle(.sheetSubtitle, color: Theme.inkFaint)

                HStack(spacing: Spacing.tight) {
                    ForEach(Array(venues.enumerated()), id: \.element.id) { index, venue in
                        Chip(
                            venue.name,
                            isSelected: index == venueIndex,
                            metrics: .intake,
                            fillsWidth: true
                        ) {
                            venueIndex = index
                        }
                    }
                }
                .padding(.top, 10)

                if let note = venueNote {
                    InfoBanner(note, tone: .accent, font: .caption, radius: Radius.chipSquare,
                               horizontalPadding: Spacing.row, verticalPadding: 10, spacing: 9,
                               iconSize: 15, alignment: .top)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.chipSquare, style: .continuous)
                                .strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline)
                        }
                        .padding(.top, Spacing.medium)
                }
            }
            .padding(Spacing.gutterWide)
        }
    }

    /// The design's line about the under-11s. Shown only when it is true — an explanation of a
    /// default that was not applied is just noise on the screen.
    private var venueNote: String? {
        guard let years = Int(age), years < 11, venueIndex == 0, let first = venues.first else { return nil }
        return "Under 11, so \(first.name) by default. Coaches can still move them once they are ranked."
    }

    // MARK: Save

    private var saveButton: some View {
        PrimaryButton(saveTitle, height: 52, font: .button) { save() }
            .opacity(canSave ? 1 : 0.45)
            .disabled(!canSave)
            .shadow(OnboardingShadows.pinnedCTA)
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, 20)
    }

    /// A first name is the one thing a kid cannot be added without — everything else can be
    /// asked for later, which is what `8d` exists to do.
    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        focus = nil

        var player: IntakePlayer
        switch mode {
        case .new: player = IntakePlayer(firstName: "", lastName: "")
        case .fix(let existing): player = existing
        }

        player.firstName = firstName.trimmingCharacters(in: .whitespaces)
        player.lastName = lastName.trimmingCharacters(in: .whitespaces)
        player.age = Int(age)
        player.gender = gender

        onSave(player)
    }
}

private extension AddPlayerView.Mode {
    var isFix: Bool {
        if case .fix = self { return true }
        return false
    }
}

// MARK: - Chip metrics

private extension ChipMetrics {
    /// `8e`'s equal-width answer chips: `600 12.5`, 9pt tall, radius 11, grey border when they
    /// are not the answer. A point tighter than the staff sheet's `.role`, which is the same
    /// control drawn on a sheet rather than on a card.
    static let intake = ChipMetrics(
        font: .chipMedium,
        horizontalPadding: 0,
        verticalPadding: 9,
        radius: Radius.control,
        spacing: 6,
        unselectedBorder: Theme.strokeChip,
        emojiSize: 12.5
    )
}

// MARK: - Previews

#Preview("Add a player") {
    NavigationStack {
        AddPlayerView(venues: CampShape.initial().venues) { _ in }
    }
    .showsMockStatusBar()
}

#Preview("Fix a detail") {
    NavigationStack {
        AddPlayerView(
            mode: .fix(IntakePlayer(firstName: "Priya", lastName: "Nandan", age: nil, gender: .f)),
            venues: CampShape.initial().venues
        ) { _ in }
    }
    .showsMockStatusBar()
}
