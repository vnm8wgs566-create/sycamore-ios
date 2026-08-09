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
    /// Nil until one is picked, which reads as the first — see `chosenVenueID`.
    @State private var venueID: VenueShape.ID?
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
            if venues.indices.contains(player.venueIndex) {
                _venueID = State(initialValue: venues[player.venueIndex].id)
            }
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
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { saveButton }
        .navigationBarBackButtonHidden(true)

        #if os(iOS)
        return screen
            .toolbar(.hidden, for: .navigationBar)
            // The number pad has no return key, and the pinned "Add" sits under the keyboard
            // while it is up. This is the way out that does not need a free hand for a drag.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
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
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                namesCard
                genderCard
                if !venues.isEmpty { venueCard }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, OnboardingMetrics.ctaClearance)
        }
        // The age field runs a number pad, which has no return key to put away. Dragging the
        // form is the second way out of it, beside the keyboard bar's Done.
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Name and age

    private var namesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Card(radius: OnboardingMetrics.cardRadius) {
                field("First name", text: $firstName, focus: .first, submit: .next, content: .givenName)
                field("Last name", text: $lastName, focus: .last, submit: .next, content: .familyName)
                field("Age", text: $age, focus: .age, submit: .done, isNumeric: true)
            }

            // Under the card that holds the field rather than in a banner over the screen: the
            // fix is to retype three characters, and the field that takes them is right there.
            // Shown only when it is true — an explanation of a rule nobody has broken is noise.
            if let ageProblem {
                Text(ageProblem)
                    .typeStyle(.intakeNote, color: Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        focus target: Field,
        submit: SubmitLabel,
        isNumeric: Bool = false,
        content: TextContentKind? = nil
    ) -> some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            Text(label)
                .typeStyle(.intakeFieldLabel, color: Theme.inkFaint)
                // `minWidth`, not `width`: the design's 88pt column is a floor once the label
                // itself has grown, and a fixed one breaks "First name" over three lines.
                .frame(minWidth: labelWidth, alignment: .leading)
                .accessibilityHidden(true)

            textField(text, label: label, focus: target, submit: submit, isNumeric: isNumeric, content: content)
        }
        // The label is part of the field's target: tapping the word "Age" puts the caret in it.
        .onTapGesture { focus = target }
    }

    /// `UITextContentType` by another name, so the signature above stays free of UIKit and the
    /// file still builds for the Mac.
    private enum TextContentKind { case givenName, familyName }

    private func textField(
        _ text: Binding<String>,
        label: String,
        focus target: Field,
        submit: SubmitLabel,
        isNumeric: Bool,
        content: TextContentKind?
    ) -> some View {
        let base = TextField("", text: text)
            .textFieldStyle(.plain)
            .typeStyle(.intakeFieldValue, color: Theme.ink)
            .focused($focus, equals: target)
            .autocorrectionDisabled()
            // The row's grey word is the field's name; hidden above so it is not read twice.
            .accessibilityLabel(label)

        #if os(iOS)
        let contentType: UITextContentType? = switch content {
        case .givenName: .givenName
        case .familyName: .familyName
        case nil: nil
        }

        return base
            .keyboardType(isNumeric ? .numberPad : .default)
            .textInputAutocapitalization(isNumeric ? .never : .words)
            .textContentType(contentType)
            .submitLabel(submit)
        #else
        return base
        #endif
    }

    // MARK: Gender

    private var genderCard: some View {
        answerCard("Gender") {
            HStack(spacing: Spacing.tight) {
                ForEach(Gender.intakeOptions, id: \.self) { option in
                    IntakeChoiceChip(title: option.label, isSelected: gender == option) {
                        gender = option
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: gender)
        }
    }

    // MARK: Venue

    private var venueCard: some View {
        answerCard("Venue") {
            HStack(spacing: Spacing.tight) {
                ForEach(venues) { venue in
                    IntakeChoiceChip(title: venue.name, isSelected: venue.id == chosenVenueID) {
                        venueID = venue.id
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: chosenVenueID)

            if let note = venueNote {
                IntakeNote(note)
                    .padding(.top, Spacing.medium)
            }
        }
    }

    /// The venue answered, or the first one — which is where `8c` says the walk-ins go.
    private var chosenVenueID: VenueShape.ID? {
        venueID ?? venues.first?.id
    }

    /// Its position, which is the only thing an `IntakePlayer` can carry: the camp does not exist
    /// yet, so neither do the venues these rows will become.
    private var chosenVenueIndex: Int {
        venues.firstIndex { $0.id == chosenVenueID } ?? 0
    }

    /// A label over a row of answers — the shape both of `8e`'s lower cards take.
    private func answerCard<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Card(radius: OnboardingMetrics.cardRadius, isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .typeStyle(.intakeFieldLabel, color: Theme.inkFaint)
                    .padding(.bottom, 10)

                content()
            }
            .padding(Spacing.gutterWide)
        }
        // The grey word above the chips is what they are all answers to, so it is what VoiceOver
        // should say before reaching them.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// The design's line about the under-11s. Shown only when it is true — an explanation of a
    /// default that was not applied is just noise on the screen.
    private var venueNote: String? {
        guard let years = Int(age), years < 11, chosenVenueIndex == 0, let first = venues.first else { return nil }
        return "Under 11, so \(first.name) by default. Coaches can still move them once they are ranked."
    }

    // MARK: Save

    private var saveButton: some View {
        PrimaryButton(
            saveTitle,
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButtonLg
        ) {
            save()
        }
        .opacity(canSave ? 1 : 0.45)
        .disabled(!canSave)
        .shadow(OnboardingShadows.pinnedCTA)
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, OnboardingMetrics.ctaInset)
    }

    /// A first name is the one thing a kid cannot be added without — everything else can be asked
    /// for later, which is what `8d` exists to do. **But what is typed has to be writable**, and
    /// that is what the two `PlayerRules` gates below are.
    ///
    /// The age field is a free-text numpad. It let a 25 through to `player.age`, and
    /// `importPlayers` sends a whole roster in a single insert — so one kid typed as 25 rejected
    /// **every other kid in the batch** with a raw PostgREST message and no row to point at. That
    /// is exactly the failure wave 1 closed on the file path, and this is the screen it stayed
    /// open on. Worse: this is also the Fix screen for `.impossibleAge`, so the one place whose
    /// job is to settle that issue could re-create it.
    ///
    /// Refused rather than silently dropped. Dropping an out-of-range age would leave a kid with
    /// no age and no sign that the number was thrown away — and the reader typed it on purpose.
    /// The note under the field says which numbers the roster takes.
    private var canSave: Bool {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard ageProblem == nil else { return false }
        return CharLength.of(
            lastName.trimmingCharacters(in: .whitespaces), atMost: PlayerRules.surnameLimit
        )
    }

    /// What is wrong with the age as typed, or nil. An empty field is not a problem — a kid can be
    /// added without one, and `8d` is the screen that asks later.
    private var ageProblem: String? {
        guard !age.isEmpty else { return nil }
        guard let years = Int(age) else { return "Digits only." }
        guard PlayerRules.ageLimits.contains(years) else {
            let limits = PlayerRules.ageLimits
            return "The roster takes ages \(limits.lowerBound) to \(limits.upperBound)."
        }
        return nil
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
        // Through the filter as well as behind `canSave`, so the value that lands is one the
        // column takes even if the gate above is ever loosened. `canSave` is what the reader sees;
        // this is what the roster gets.
        player.age = PlayerRules.age(Int(age))
        player.gender = gender
        player.venueIndex = chosenVenueIndex

        onSave(player)
    }
}

private extension AddPlayerView.Mode {
    var isFix: Bool {
        if case .fix = self { return true }
        return false
    }
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
