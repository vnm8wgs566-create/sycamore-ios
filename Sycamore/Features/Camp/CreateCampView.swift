//
//  CreateCampView.swift
//  Sycamore
//
//  `8b` — Shape the camp. The places you run and the courts inside each, before anything else.
//
//  ── Two states, and which one a new camp opens in ─────────────────────────────────────────────
//
//  `design/Sycamore 3a System.dc.html` draws this screen twice. `8b` — and `9a`, which is the same
//  frame byte for byte — is labelled `Shape the camp — empty`: a dashed plate reading "No venues
//  yet", a card saying what a venue holds, and a footnote reading *"One venue is enough to start.
//  Add the second the day you need it."* `9b` is labelled `Shape the camp — venues` and captioned
//  "As built: name, sport, venue rows, camp-wide rates".
//
//  So the answered screen below is endorsed rather than replaced, and what was missing is the
//  state in front of it. A new camp now opens on `CampShape.empty` and `VenueEmptyState` is what
//  it draws. It used to open on `CampShape.initial()` — two venues called Venue 1 and Venue 2 —
//  which the frame's own footnote is the argument against: the second is a guess the app makes on
//  somebody's behalf and then carries into Groups, Rank, the venue chip row and the schedule until
//  they find it and delete it.
//
//  Deliberately *not* a wholesale swap. The empty frame draws no name field, no sport chips, no
//  days and no "Save the shape", and none of those absences is an instruction — it is one state of
//  a screen, and a state with no venue in it has nothing to apply a camp-wide rate to and nothing
//  to save. What the empty state replaces is exactly that: the venues card, the "Every venue"
//  card, the button and its footnote. Name, sport and days stay where they are, because the camp
//  is still created by name and the sport still decides whether the rest of the screen says
//  courts, fields or lanes.
//
//  The header's own sentence changes with the state, because the drawing's does: the empty frame
//  reads "Northside Tennis Camp has nowhere to put anyone yet. Start with the place you run."
//
//  ── Everything else ──────────────────────────────────────────────────────────────────────────
//
//  Name and sport sit above the shape, in the order you would say them out loud. Neither can be
//  deferred, and `9b` draws both.
//
//  Nothing here is a commitment. The header says so, and it is true: venues, courts, both rates
//  and everything in the venue editor are editable from Camp settings any day of the week. They
//  are edited *here* because this is where the venues come into existence — a venue named, tinted
//  and bounded at setup is a venue that was never wrong, and by the time Camp settings can correct
//  it somebody has looked at the wrong row all week.
//
//  Tapping a venue opens `VenueShapeSheet`; swiping one left offers to take it back off the list.
//  Both are new and both replace something: the tile used to be a `Menu` of six emoji because a
//  grid "would not fit the row", and the row used to carry a `.contextMenu` "Remove" because a
//  long press was the only gesture going spare. The editor is where the grid fits, and a swipe is
//  the gesture the design has been drawing since screen 5 (`SwipeToDelete.swift:17-20`).
//
//  Saving does not create the camp. It hands the shape to `OnboardingFlowView`, which brings in
//  the week and writes the camp at the end of it — see that file for why the order is that way
//  round.
//

import SwiftUI

struct CreateCampView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    /// The shape as the design draws it — a row per venue with its own name, emoji, court count
    /// and head-count limits, plus the two camp-wide rates those limits are seeded from.
    /// `CampDraft` can hold none of that (one uniform `groupsPerVenue`, nothing per venue at all),
    /// so it is held here and written into the camp the moment there is one. See `CampShape`.
    ///
    /// Starts empty, which is the state `8b` is drawn in — see the file header for why, and
    /// `CampShape.empty` for what that costs.
    @State private var shape: CampShape
    @State private var isBringingInTheWeek = false

    /// The name as it is being typed, which is deliberately not `store.campDraft.name`.
    ///
    /// `campDraft` is one observed property, so a write to any part of it invalidates every
    /// reader of any other part — and this screen reads it for `courtNoun`, for the CTA's gate
    /// and for the sport chips. Bound straight to the store, each character therefore rebuilt
    /// the whole screen: the chip row and its layout pass, the venues card, a `SwipeToDelete`
    /// and an `IntakeStepper` per venue. Held here, a character touches this field and the
    /// button's opacity and nothing else.
    ///
    /// The store still gets it — see the settle in `screen` and the flush in `saveTheShape` —
    /// because the draft living there is what lets somebody drop out of the flow and still find
    /// the camp creatable, which the comment on `saveTheShape` records.
    @State private var name = ""

    /// The venue whose editor is open. Presented from here rather than through `store.activeSheet`
    /// — see `VenueShapeSheet.swift:12-21` for why that slot is unreachable from this screen.
    @State private var editingVenue: VenueShape?

    /// Which row is showing its Remove, and which has a finger on it. One value shared by every
    /// row, so only one can be open (`SwipeToDelete.swift:56-64`).
    @State private var swipe = SwipeRevealState<VenueShape.ID>()

    /// - Parameter shape: what the screen opens on. Both callers — `CampPickerView:49` and
    ///   `FirstRunView:87` — take the default, because a camp being created has no venues yet.
    ///   The parameter is here so the answered state is still previewable: it is a whole frame of
    ///   the design (`9b`, "Shape the camp — venues") and no production path reaches it on entry
    ///   any more.
    init(shape: CampShape = .empty) {
        _shape = State(initialValue: shape)
    }

    var body: some View {
        // The whole frame on the phone, where bringing in the week is the whole job and a card
        // that can be swiped away mid-import is not; a sheet on the Mac, which has no cover. Both
        // halves of that, and the navigation bar this screen draws its own header instead of, are
        // `FullScreenPresentation`'s — the same two modifiers `RootView`, `ScheduleView` and the
        // enrolment flow reach for.
        screen
            .hidesNavigationBar()
            .fullScreenPresentation(isPresented: $isBringingInTheWeek) { flow }
    }

    private var screen: some View {
        VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)
            content
        }
        // `#F8F9F8`, which section 8 puts behind every screen in it — warmer than the `#F6F7F9`
        // the design this app shipped with used, and the reason its white cards read as paper.
        .background(Theme.surfaceWarm)
        .navigationBarBackButtonHidden(true)
        // Settle, then write the draft out. Nothing on this screen needs the store to be current
        // between characters — `saveTheShape` flushes before the flow reads it — so this exists
        // only so that backing out mid-name still leaves the camp creatable from what was typed.
        .task(id: name) {
            guard name != store.campDraft.name else { return }
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            store.campDraft.name = name
        }
        // Seeds the field from the draft when the screen is entered a second time, and follows
        // any write the store makes on its own.
        .onChange(of: store.campDraft.name, initial: true) { _, committed in
            if committed != name { name = committed }
        }
    }

    /// What a group is called in this sport — "court", "field", "lane".
    private var courtNoun: String { store.campDraft.sport.groupNoun.lowercased() }

    /// The grey line under the title, which the design writes differently in each state.
    ///
    /// `leadLine` rather than `lead`, which `summaryRow(_:trailing:)` already takes as a parameter
    /// name — one word meaning two things in one type is a trap for whoever reads it next.
    ///
    /// Empty: *"Northside Tennis Camp has nowhere to put anyone yet. Start with the place you
    /// run."* — the frame's own sentence, and the only line on this screen that names the camp.
    /// Answered: what the screen is for, unchanged.
    ///
    /// The name comes from the **settled** draft rather than from the field two properties down,
    /// which is the one place that difference is a feature: this is prose about a camp, not a live
    /// echo of a text box, and the 250ms settle is exactly the right lag for it.
    ///
    /// It also costs nothing, which is the half worth being exact about. `campDraft` is one stored
    /// property, so reading `trimmedName` registers the same observation key `sportChips` and
    /// `courtNoun` already register — this widens nothing. And `body` re-runs on every keystroke
    /// whatever this says, because `name` is `@State` on this view; what the settle buys is that
    /// the *value* here does not change between characters, so the header's wrapping paragraph is
    /// value-equal and never re-measured. Reading `name` would have put a text re-measure behind
    /// every character.
    ///
    /// The fallback is for the real case the design does not draw: the name field is on this
    /// screen, so the camp is very often nameless while the empty state is on screen.
    private var leadLine: String {
        guard shape.isCreatable else {
            let named = store.campDraft.trimmedName
            let subject = named.isEmpty ? "This camp" : named
            return "\(subject) has nowhere to put anyone yet. Start with the place you run."
        }
        return "Which days you run, how many places, and how many \(courtNoun)s inside each. All of it changes any day from Camp settings."
    }

    private var flow: some View {
        OnboardingFlowView(shape: shape)
            // Sheets and covers are presented outside this view's hierarchy, so the store is
            // handed over explicitly — the same thing `MainTabView` does for its own sheets.
            .environment(store)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled) {
                    dismiss()
                }
                // The shared control draws a glyph and nothing else, so the label belongs to
                // whoever knows where the button goes.
                .accessibilityLabel("Back to your camps")
                // The disc is 36 and the button around it is 44, which would otherwise push the
                // title 4pt down and the disc 4pt right of where the design puts them. Saying
                // how big the row is leaves the touch overflowing and nothing moved.
                .frame(width: 36, height: 36)
                .padding(.bottom, Spacing.large)

                IntakeTitle("Shape the camp")

                Text(leadLine)
                    .typeStyle(.intakeLead, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, 20)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            // `gap:13px` between blocks, which is what the design's flex column runs on.
            VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
                block("Name") { nameField }
                block("Sport") { sportChips }
                // Above the venues rather than below them: the days are a fact about the camp,
                // like its name and its sport, and the two cards under this one are both about
                // the places inside it. Splitting "Venues" from "Every venue" to slot the week
                // between them would have put a camp-wide answer inside the venue block.
                block("Days") { daysCard }

                // The same predicate the header's sentence turns on, and the same one
                // `saveTheShape` refuses without — see `CampShape.isCreatable`.
                if shape.isCreatable {
                    block("Venues") { venuesCard }
                    block("Every venue") { everyVenueCard }
                    saveButton
                    // No failure line here any more. This screen calls nothing that can fail —
                    // creating the camp moved to the end of the flow, and the flow carries the
                    // banner for it.
                    Text("Next: add kids, then hand out the code.")
                        .typeStyle(.intakeFootnote, color: Theme.inkGhost)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    // No "VENUES" overline above it: the empty frame draws none, and the plate is
                    // the whole block rather than a card under a heading.
                    VenueEmptyState(courtNoun: courtNoun, onCreate: createFirstVenue)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, OnboardingMetrics.contentBottom)
        }
        // The name field has a return key, but a thumb already on the list is the faster way out.
        .scrollDismissesKeyboard(.interactively)
        // A row travelling sideways under a finger must not also have the list slide out from
        // under it. `GroupsView.swift:140` and `RankView.swift:116` make the same call for their
        // own drags.
        .scrollDisabled(swipe.isTracking)
        .sheet(item: $editingVenue) { venue in
            venueEditor(venue)
        }
    }

    /// Attached to the scroll view rather than to `screen`, which already carries the
    /// `fullScreenCover`: two presentation modifiers on one view is a shape SwiftUI has never
    /// promised to honour, and there is a whole view here to hang the second one on.
    private func venueEditor(_ venue: VenueShape) -> some View {
        VenueShapeSheet(
            venue: venue,
            shape: shape,
            courtNoun: courtNoun,
            onSave: { saved in
                if let index = shape.venues.firstIndex(where: { $0.id == saved.id }) {
                    shape.venues[index] = saved
                }
                editingVenue = nil
            },
            // Never withheld now. It used to be nil for the last venue in the camp, because one
            // venue was the fewest a camp could have and the sheet hides a Remove it is not given
            // — but the empty state is a screen the design draws, so removing the only venue is a
            // way back to it rather than an action that would have to refuse.
            onRemove: {
                shape.removeVenue(venue.id)
                editingVenue = nil
            },
            onClose: { editingVenue = nil }
        )
    }

    /// A header and the card under it — one child of the design's 13pt column.
    private func block<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            IntakeSectionHeader(title)
            content()
        }
    }

    /// Drawn only beside a shape that has a venue in it, which is why it carries no "add a venue
    /// first" of its own.
    ///
    /// The empty state hides this rather than dimming it, where the name gate below dims. The two
    /// are different refusals: a name is a keystroke away and a dimmed button with a filled field
    /// beside it is a puzzle worth posing, where a camp with no venue is answered by a plate that
    /// fills half the screen saying "No venues yet" over a green button that says what to do. A
    /// control that can never be used is not a control, and the design draws no button at all in
    /// the empty frame.
    ///
    /// (That sentence used to cite `VenueShapeSheet`'s Remove, which was hidden for the last venue
    /// on the same argument. It is not hidden any more — the last venue can go now, because there
    /// is a state for it to leave behind — so the citation went with it.)
    private var saveButton: some View {
        PrimaryButton(
            "Save the shape",
            height: OnboardingMetrics.ctaHeight,
            radius: OnboardingMetrics.cardRadius,
            font: .intakeButton
        ) {
            saveTheShape()
        }
        // Gated on what is in the field, not on what has reached the store. The settle in `screen`
        // is 250ms and this button has to light the moment a name is long enough to be one — a
        // gate that lagged the last character would be a worse trade than the re-render it was
        // bought with.
        .opacity(isNameValid ? 1 : 0.45)
        .disabled(!isNameValid)
        // `margin:2px 2px 0` — the button is inset a touch from the cards above it.
        .padding(.horizontal, Spacing.hairGap)
        .padding(.top, Spacing.hairGap)
    }

    /// What "Create your first venue" does — exactly what "Add a venue" does, which is why it is
    /// `addVenue()` and not a second seeding rule: the row it makes is already named, tinted and
    /// bounded from the camp-wide rates.
    ///
    /// Deliberately does *not* open the editor behind it. "Create your first venue" says create,
    /// the row it lands on is one tap from `VenueShapeSheet` and says "Tap to name it" in so many
    /// words, and a sheet arriving unasked over a screen somebody has not finished reading is a
    /// worse greeting than one more tap.
    private func createFirstVenue() {
        shape.addVenue()
    }

    private func saveTheShape() {
        // The floor `CampDraft.venueRange` states, kept at the last moment this branch can keep it.
        // Nothing on screen can reach here without a venue — the button is not drawn in the empty
        // state — so this is a backstop rather than a gate, and it is a backstop in a *view*, which
        // is one layer too high.
        //
        // The rule belongs on `CampDraft.isValid` (`Models.swift:834`), beside the `venueRange` two
        // lines under it and next to the name rule that was hoisted there for exactly this reason
        // ("One rule, stated once, next to the SQL it mirrors", `Models.swift:846`). Both
        // repositories already `guard draft.isValid` at the write boundary, so `OnboardingFlowView`
        // — which re-applies this shape one statement before `createCamp` and checks nothing —
        // would inherit the refusal for free. It is not done here because it needs a `Repository`
        // failure case beside `.campNameRequired` (`Repository.swift:41`), and `Store/` is not this
        // branch's to change. See the PR body.
        guard shape.isCreatable else { return }
        isNameFocused = false
        // Nothing may be on screen when the cover goes up. An editor still presented would meet
        // `fullScreenCover` mid-flight and the runtime would refuse the pair — "attempt to present
        // while already presenting" — leaving the button dead and no way to find out why.
        editingVenue = nil
        // The draft carries what it can of the shape now, so a failure to reach the end of the
        // flow still leaves the camp creatable from what was drawn here.
        var draft = shape.applied(to: store.campDraft)
        // Flushed by hand: the settle is cancelled by this screen going away, and the name is
        // the one thing on it the next screen cannot do without.
        draft.name = name
        store.campDraft = draft
        isBringingInTheWeek = true
    }

    /// `CampName.isValid` against the field rather than the store — the same rule
    /// `CampDraft.isValid` applies, asked of the value the reader can see.
    private var isNameValid: Bool {
        CampName.isValid(name.trimmingCharacters(in: .whitespaces))
    }

    // MARK: Name

    private var nameField: some View {
        @Bindable var store = store

        let field = FormField(
            "UCLA Tennis Camp",
            text: $name,
            label: "Camp name",
            metrics: .intakeCard,
            type: .intakeFieldTitle,
            focus: $isNameFocused
        )
        .autocorrectionDisabled()

        // Every one of these travels down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            .textContentType(.organizationName)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return field
        #endif
    }

    // MARK: Sport

    /// The shared `FlowLayout`, same as `SetupView.sportChips` (`:632`): at 402pt the five sport
    /// chips do not fit on one line, and the design lets them break rather than shrink.
    private var sportChips: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(Sport.selectable, id: \.self) { sport in
                let isSelected = store.campDraft.sport.matchesChip(sport)
                Chip(sport.chipTitle, isSelected: isSelected, metrics: .sport) {
                    store.campDraft.sport = sport
                }
                // The shared chip draws the selection but does not say so, and "which sport"
                // is unanswerable by ear without it.
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: store.campDraft.sport)
    }

    // MARK: Days

    /// The operating week, and a line under it reading back what has been drawn.
    ///
    /// Bound straight to the draft, exactly as the sport chips above it are, and deliberately not
    /// held on `shape` beside the venues. `CampDraft` has a `days` of its own — one value per
    /// camp, where a venue's courts are one per venue — so a copy on the shape would be a second
    /// place for the same answer, reset to Monday-to-Friday every time this screen is entered and
    /// written back over the real one by `saveTheShape`. Somebody who dropped out of the flow and
    /// came back would find their Saturday quietly gone.
    ///
    /// The re-render that costs is the one `sportChips` already pays: a write to `campDraft`
    /// invalidates every reader of it. That is the trade the name field two properties up refuses
    /// — and it refuses it because a name is twenty characters, where a week is four taps.
    private var daysCard: some View {
        @Bindable var store = store

        return Card(radius: OnboardingMetrics.cardRadius) {
            CardRow(horizontalPadding: 13, verticalPadding: Spacing.medium) {
                CampDaysPicker(days: $store.campDraft.days)
            }
            // The right-hand side is where the picker's one refusal is explained: it will not let
            // the last lit chip go out, and a tap that does nothing is a mystery unless something
            // on screen says why. `countLine` is that sentence, shared with `8t`'s editor.
            summaryRow(store.campDraft.days.summaryLine, trailing: store.campDraft.days.countLine)
        }
    }

    // MARK: Venues

    private var venuesCard: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            ForEach(shape.venues) { venue in
                venueRow(venue)
            }
            addVenueRow
            // `2 venues · 10 courts` and, until there is a roster, the honest right-hand side.
            summaryRow(shape.summaryLine(noun: courtNoun), trailing: "no kids yet")
        }
    }

    /// Tile, name, subtitle, caret and a stepper — the design's row, plus the two ways in it
    /// never had.
    ///
    /// The `Button` deliberately ends before the stepper, which is exactly `SetupView.venueRow`'s
    /// shape (`:204-215`): the left of the row opens the editor, the stepper on the right is its
    /// own control and does not. The caret is where "opens the editor" stops.
    ///
    /// Three gestures were two too many. The tile used to be a `Menu` and the row used to carry a
    /// `.contextMenu`, so a tap, a long press and now a swipe would all have landed on the same
    /// 68pt of card — and a `.contextMenu`'s lift preview begins under a finger that is about to
    /// swipe. Both are gone: the six emoji live in the editor, where the design's grid actually
    /// fits, and `SwipeToDelete` puts "Remove" in the VoiceOver actions rotor exactly where the
    /// context menu had it. Keeping both would have offered "Remove Venue 1" in the rotor twice.
    ///
    /// Every row swipes, including the last one. That used to be conditional on there being a
    /// venue to spare; the empty state is now somewhere to land, so it is not — see
    /// `CampShape.removeVenue`.
    private func venueRow(_ venue: VenueShape) -> some View {
        SwipeToDelete(
            id: venue.id,
            state: $swipe,
            actionLabel: "Remove \(venue.name)",
            onDelete: { shape.removeVenue(venue.id) }
        ) {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
                Button {
                    editingVenue = venue
                } label: {
                    venueRowFace(venue)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the venue editor")

                IntakeStepper(
                    value: courtsBinding(for: venue.id),
                    range: CampShape.courtRange,
                    label: "\(courtNoun)s at \(venue.name)",
                    valueWidth: 28
                )
            }
        }
    }

    /// Everything the row's `Button` covers.
    ///
    /// The tile is a plain `IntakeIconTile` again. It was a `Menu` of six emoji on the argument
    /// that screen 11's grid "is a card's worth of height and would not fit the row" — which was
    /// true, and stopped being the question the moment the row grew an editor with room for it.
    /// The tile hides itself from VoiceOver because the name is read on the very next line.
    private func venueRowFace(_ venue: VenueShape) -> some View {
        HStack(spacing: Spacing.row) {
            IntakeIconTile(
                emoji: venue.icon,
                size: 40,
                // 21-on-44 is the design's ratio (`:276`); on this 40pt plate that is 19.
                glyphSize: 19,
                fill: Theme.color(for: venue.tint)
            )

            // Both lines hold to one. A name is eighty characters at most and the stepper on the
            // right is not giving any of its width up, so an unlimited row would grow to four
            // lines of it and push the card open. `SetupView.venueRow` clips the same two lines
            // for the same reason.
            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(venue.name)
                    .typeStyle(.intakeRowTitle, color: Theme.ink)
                    .lineLimit(1)
                Text(venue.subtitle ?? "Tap to name it")
                    .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.small)

            // `ph-caret-right` at `font-size:16px;color:#C7CBD2` (`design/Sycamore Flow.dc.html:278`),
            // which is `DisclosureChevron`'s own default twice over. Decorative: it says the row
            // opens something, and the hint on the button says what.
            DisclosureChevron()
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }

    /// A court count is a write to the whole row, not just to one field: `setCourts(_:for:)`
    /// re-derives that venue's ceiling and floor from the camp-wide rates, so a venue taken from
    /// six courts to eight does not keep a 48-kid ceiling it only ever had because it had six.
    private func courtsBinding(for id: VenueShape.ID) -> Binding<Int> {
        Binding(
            // The row this belongs to is on screen, so the lookup cannot miss; the fallback is
            // there because a `Binding` must return something, and the lower bound is the only
            // number that is in range whatever went wrong.
            get: { shape.venues.first { $0.id == id }?.courts ?? CampShape.courtRange.lowerBound },
            set: { shape.setCourts($0, for: id) }
        )
    }

    private var addVenueRow: some View {
        Button {
            shape.addVenue()
        } label: {
            CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
                IntakeIconTile(
                    "plus",
                    size: 40,
                    glyphSize: 17,
                    fill: Theme.accentSurface,
                    border: Theme.accentBorder,
                    isDashed: true,
                    glyphColor: Theme.accent
                )

                Text("Add a venue")
                    .typeStyle(.intakeRowTitle, color: Theme.accent)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        // Through `canAddVenue` rather than counting here, which this row did twice: the ceiling
        // is `addVenue`'s own guard and the row should be dimmed by the same rule that refuses it.
        .disabled(!shape.canAddVenue)
        .opacity(shape.canAddVenue ? 1 : 0.45)
    }

    /// The line a card closes with: what has been drawn, and one quieter thing on the right.
    ///
    /// Two cards end this way — `2 venues · 10 courts` and `Mon–Fri · 5 days a week` — and they
    /// were the same eleven lines twice, down to the two type styles and the warm plate. Taking
    /// the two strings as arguments is the whole of the difference between them.
    private func summaryRow(_ lead: String, trailing: String) -> some View {
        CardRow(spacing: 9, horizontalPadding: 13, verticalPadding: Spacing.row) {
            Text(lead)
                .typeStyle(.intakeOverline, color: Theme.inkMuted)
            Spacer(minLength: 0)
            Text(trailing)
                .typeStyle(.intakeRowMeta, color: Theme.inkFaint)
        }
        // A row inside the card, one step warmer than the white above it.
        .background(Theme.surfaceRaised)
        .accessibilityElement(children: .combine)
    }

    // MARK: Every venue

    /// The two camp-wide rates, which write into every row rather than being read at the end.
    ///
    /// They used to be read: `venue(applying:)` multiplied them by each row's courts on the way to
    /// the camp, so a venue could not have a ceiling of its own. Now that it can, a rate nobody
    /// reads would be a card that quietly did nothing — so moving either stepper writes the number
    /// it implies into every venue, and the block is titled for what that does.
    ///
    /// That is what keeps the common case (every venue the same) at one stepper, leaves a
    /// per-venue override standing until somebody deliberately moves a camp-wide stepper whose own
    /// subtitle says it does this, and needs no third piece of state to remember which is which.
    private var everyVenueCard: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            rateRow(
                "Kids per \(courtNoun)",
                detail: "Sets every venue's ceiling",
                value: kidsPerCourtBinding,
                range: CampShape.kidsRange
            )
            rateRow(
                "Coaches per \(courtNoun)",
                detail: "Sets every venue's floor",
                value: coachesPerCourtBinding,
                range: CampShape.coachRange
            )
        }
    }

    /// Through the mutator rather than straight at `$shape.kidsPerCourt`: the write into every
    /// venue is the whole point of the row, and a binding that skipped it would leave the rate and
    /// the venues disagreeing with nothing on screen to say so.
    private var kidsPerCourtBinding: Binding<Int> {
        Binding(get: { shape.kidsPerCourt }, set: { shape.setKidsPerCourt($0) })
    }

    private var coachesPerCourtBinding: Binding<Int> {
        Binding(get: { shape.coachesPerCourt }, set: { shape.setCoachesPerCourt($0) })
    }

    private func rateRow(
        _ title: String,
        detail: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(title)
                    .typeStyle(.intakeRowTitleSm, color: Theme.ink)
                Text(detail)
                    .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
            }

            Spacer(minLength: 0)

            IntakeStepper(value: value, range: range, label: title, valueWidth: 34)
        }
    }
}

// MARK: - Previews

/// `9b` — "As built: name, sport, venue rows, camp-wide rates." No production path opens here any
/// more, which is why the shape is handed in.
#Preview("Shape the camp — venues") {
    let store = AppStore.previewCampPicker
    store.campDraft = CampDraft(name: "UCLA Tennis Camp", sport: .tennis, venueCount: 2, groupsPerVenue: 6)
    return NavigationStack {
        CreateCampView(shape: .initial())
            .environment(store)
    }
    .showsMockStatusBar()
}

/// `8b` itself, one tap after "Create a camp": named, and with nowhere to put anyone.
#Preview("Shape the camp — empty") {
    let store = AppStore.previewCampPicker
    store.campDraft = CampDraft(name: "Northside Tennis Camp", sport: .tennis)
    return NavigationStack {
        CreateCampView()
            .environment(store)
    }
    .showsMockStatusBar()
}

/// And before a word has been typed, which is the case the design does not draw — the name field
/// is on this screen, so the header has no camp to name for as long as the field is blank.
#Preview("Shape the camp — empty and unnamed") {
    NavigationStack {
        CreateCampView()
            .environment(AppStore.previewCampPicker)
    }
    .showsMockStatusBar()
}
