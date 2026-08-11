//
//  BringInTheWeekView.swift
//  Sycamore
//
//  `8c` — Bring in the week. The on-ramp to having any data at all: a file from the office, or
//  one kid at a time.
//
//  The design gives the file three quarters of the screen and the by-hand row one line, which
//  is the right proportion — a camp of forty arrives as a spreadsheet, and typing forty kids in
//  at 7am is not a thing anybody should be asked to do. The card at the bottom is there so the
//  answer to "what should be in the file?" is on the screen where the file is chosen, rather
//  than in a support page nobody opens standing on a court.
//
//  It is now the on-ramp for a camp that already exists as well, reached from Groups and from
//  Camp settings through `EnrolmentFlowView`. Two of its properties changed for that, and both
//  for the same reason: they were sentences that assumed a camp which does not exist yet.
//
//  - `handAddedCount` became `subtitle`. It composed "Nobody added yet · Venue 1" here, which is
//    the only true reading before a camp is written and the wrong one after — from inside a camp
//    the line is "74 kids · Sycamore", counted off the graph. The caller composes it, because the
//    caller is the one that knows which of the two it is standing in.
//  - `onOpenCamp` became `onExit` plus an `Exit`. "Open the camp" is literal on the way in — that
//    tap is what writes the camp — and simply untrue on the way back, where the camp is what you
//    are already standing in and the word is "Done".
//
//  Everything else is shared, including the `.fileImporter` and what it accepts, which is the
//  point: choosing a file is the same act in week three as on day one. The list of types is one
//  longer than it was — an `.xlsx` is now a file this reads, through `XLSXReader` — and it grew
//  for both flows at once precisely because there is only one of it.
//
//  ---------------------------------------------------------------------------------------------
//  DRAWN FROM THE FRAME, AND THE THREE PLACES IT IS NOT
//  ---------------------------------------------------------------------------------------------
//
//  The screen above is now transcribed from `design/Sycamore 3a System.dc.html`, the frame badged
//  `8c` and captioned "Bring in the week". Four things moved: the heading is "Drop the sign-up
//  list", the two capsules became one full-width button with a text line under it, the accepted
//  formats are stated as chips before the button rather than in a sentence, and the template
//  download came out of `FileExampleCard` into an action row beside "Add one by hand" — which is
//  where the frame puts it, and which is also the only place it reads as an *action* rather than
//  as the last line of a reference card.
//
//  Three things in the frame are deliberately not drawn, each because the app knows something the
//  drawing does not:
//
//  1. **No `PDF` chip.** The frame offers `XLSX · CSV · PDF`. The picker below accepts the first
//     two and greys out a PDF, for the reason stated at the `.fileImporter` — the text has to come
//     out server-side and there is no server. A chip is a promise read *before* the tap, so a
//     third one would be the one lie this screen tells, and it would be found by the person whose
//     office only sends PDFs, at the moment the picker refuses their file. Two chips, both true.
//  2. **The header keeps its trailing button.** The frame draws none, because a frame is a
//     picture and does not have to leave. This tap is what writes the camp in onboarding and what
//     closes the sheet from inside one; see `Exit`.
//  3. **"venue" is out of the note.** The frame's line reads "Gender and venue are optional — we
//     will ask for what is missing", which would advertise a Venue column. Nothing reads one:
//     `Columns.init?(header:)` has no venue case, so a file carrying one would be silently ignored
//     and every kid would land in the same place anyway. `FileExampleCard.swift:40-42` refused the
//     same promise on the card below for the same reason, and this is that decision reaching the
//     line above it.
//
//  ---------------------------------------------------------------------------------------------
//  AND THE LIST THAT IS NOT A FILE
//  ---------------------------------------------------------------------------------------------
//
//  `sheet-shImport.html:6-10` puts a paste box under the picker, and it is now here: a hairline
//  divider reading "or paste the list", a box, and a button that counts what is in it before it is
//  pressed. `pasteBox` carries the argument for why a second way in earns its place, and
//  `IntakeFile.parse(pasted:)` carries the only rule that differs from a file's — a paste may go
//  without a header row, because the box states the order and an office never was asked.
//
//  Two things in that region of the design are still deliberately not drawn:
//
//  1. **"Use the sample roster · 42 kids"** (`state1.js:502-522`). The app does not invent kids —
//     `IntakeRoster.swift` says so in as many words about `IntakeImport.preview`, which is the
//     nearest thing and is preview-only. Forty-two fictional children written into a real camp is
//     a demo affordance, and the paste box is the honest version of what it was for: a way to get
//     a roster in without leaving the app.
//  2. **The 78% bottom sheet** (`anySheet.html:2-6`). The design commits a file the moment it is
//     chosen, so its sheet holds one screen; the app inserts a review step on purpose, and that
//     screen is a roster of forty with sections and Fix buttons. `presentationDetents` applies to
//     everything pushed inside the sheet, so adopting the chrome would put the review in a box
//     three-quarters of a phone tall. The chrome is the design's answer to a flow this app
//     deliberately does not have.
//
//  What survives underneath is "What a good file looks like". The frame does not draw it — the
//  frame is one screen tall with `overflow:hidden`, and it spends its height on the on-ramp — but
//  the card is the only place the **header-row requirement** is stated before a file is chosen,
//  and that requirement is load-bearing: a header-less file is refused (`IntakeRoster.swift:321`)
//  rather than read by position, because the first real export it met is laid out
//  `Last Name, First Name, …` and a positional read would have imported a whole camp backwards.
//  Taking the frame literally would have deleted the one sentence that stops somebody meeting that
//  rule by being refused. It is now a scroll below the fold rather than the second thing on the
//  screen, which is the demotion the frame does argue for, and no further.
//

import SwiftUI
import UniformTypeIdentifiers

struct BringInTheWeekView: View {

    /// Which of the two ways out this screen is drawing.
    ///
    /// One value rather than a `title` and a `hint` the caller supplies separately. The two must
    /// agree — the hint is what VoiceOver says the button will do — and as free strings nothing
    /// stops "Done" being paired with "Creates the camp and lands in it", which is a lie a
    /// compiler cannot catch and no test would think to look for. The set is closed at two, so it
    /// is an enum, and both sentences sit here beside the rest of this screen's copy rather than
    /// being split across the two flows that present it.
    enum Exit {
        /// Onboarding. This tap is what writes the camp.
        case openCamp
        /// From inside a camp, where there is nothing to write.
        case done

        var title: String {
            switch self {
            case .openCamp: "Open the camp"
            case .done: "Done"
            }
        }

        var hint: String {
            switch self {
            case .openCamp: "Creates the camp and lands in it"
            case .done: "Closes this and goes back to the camp"
            }
        }
    }

    /// The venue a walk-in lands in — the first one, which is where the design puts the
    /// under-11s.
    let venueName: String
    /// The grey line under "Players". Composed by the caller — see the header.
    let subtitle: String
    /// Where these kids are about to go, in one sentence: `Everyone is dealt into Sycamore's 6
    /// groups, evenly — rank them after.`
    ///
    /// `state1.js:337` composes it from the venue on screen. Composed by the caller here for the
    /// same reason `subtitle` is: onboarding may be shaping several venues at once and an import is
    /// routed across them by age band, so "Sycamore's 6 groups" is true of exactly one arrangement
    /// and the caller is the only thing that knows whether it is in it.
    ///
    /// It is the one line that says where these forty names are going, and until it existed this
    /// screen said the opposite — "Everyone lands unranked" was read, correctly, as a claim that
    /// nobody would be placed.
    let dealNote: String
    let exit: Exit
    /// A roster, however it arrived — a file the reader chose or a list they pasted. One closure
    /// rather than two, because what happens next is the same review screen either way and
    /// `IntakeImport.fileName` already carries which of the two it was.
    let onImported: (IntakeImport) -> Void
    let onAddByHand: () -> Void
    let onExit: () -> Void

    @State private var isChoosingFile = false
    /// Why the last file did not come in. Sits under the card that started it rather than in a
    /// banner over the screen — the fix is to choose a different file, and the button that does
    /// that is right there.
    @State private var readError: String?
    /// What is in the paste box. Held here rather than by the caller: nothing has been parsed yet,
    /// so there is nothing for a flow to hold, and a half-typed list is not state anything above
    /// this screen has a use for.
    @State private var pasted = ""
    /// Why the pasted list did not come in. A separate line from `readError` on purpose — they sit
    /// under different controls, and one stale message under the wrong box is the failure both are
    /// arranged to avoid.
    @State private var pasteError: String?
    /// `FormTextArea`'s Return types a newline, so this screen owes it a way out. See
    /// `keyboardDoneBar`, applied on `content` below.
    @FocusState private var isTyping: Bool

    /// The cap on the sentence inside the plate, scaled for the reason `VenueEmptyState:55-57`
    /// gives for its own — a fixed 270 forces four words to the line at the largest sizes.
    @ScaledMetric(relativeTo: .body) private var copyWidth = OnboardingMetrics.dropCopyWidth
    @ScaledMetric(relativeTo: .body) private var ctaHeight = OnboardingMetrics.emptyCtaHeight
    /// The design's `font-size:15px` info glyph, grown with the copy it sits beside.
    @ScaledMetric(relativeTo: .body) private var noteGlyph: CGFloat = 15

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()
            header
            Hairline(color: Theme.hairline)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        // Cross-platform: `fileImporter` is the SwiftUI wrapper over the document browser and
        // exists on macOS too, so the whole intake path builds for both without a shim.
        //
        // The list is what the app can actually read, which is what a picker's
        // `allowedContentTypes` is for: a greyed-out file is the truth told before the tap, where a
        // file accepted and then refused is the same news delivered worse.
        //
        // Read off `RosterFileFormat` rather than written out, and so are the chips on the plate
        // above. The two used to be one claim made in two places that agreed because a comment
        // asked them to; they are now two readings of one list, which is the guarantee this
        // particular pair needs. That type is also where the absent PDF is argued.
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: RosterFileFormat.allowedContentTypes
        ) { result in
            read(result)
        }
    }

    // MARK: Header

    private var header: some View {
        IntakeHeader(title: "Players", subtitle: subtitle) {
            // The way out of the flow, whichever flow it is. Onboarding writes the camp on this
            // tap and calls it "Open the camp"; from inside one there is nothing to write and it
            // says "Done".
            Button(action: onExit) {
                Text(exit.title)
                    .typeStyle(.intakeChip, color: Theme.accent)
                    // A 12.5pt line draws about 15pt tall; 16 either side of it clears 44.
                    .intakeTouchTarget(inset: Spacing.large)
            }
            .buttonStyle(.plain)
            .accessibilityHint(exit.hint)
        }
    }

    // MARK: Content

    /// `padding:18px 12px` with `gap:12px`. The gap is wider than the 9 `8d` and `8e` run on — see
    /// `OnboardingMetrics.cardGap`, which used to claim this screen.
    ///
    /// The frame's `padding-bottom` is 96 and is not transcribed. It is clearance under a column
    /// that cannot scroll — the frame is a fixed 848 with `overflow:hidden`, so the designer's
    /// bottom padding is the space the last card needs to not touch the bezel. This scrolls, and
    /// `8d`'s and `8e`'s 88 is `OnboardingMetrics.ctaClearance`, which exists because those two
    /// float a call to action over the column. Nothing floats here, so the 24 below is the plain
    /// breathing room and the safe area does the rest.
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                dropPlate

                if let readError {
                    refusal(readError)
                }

                pasteBox

                fileNote
                actionsCard

                // The 12pt gap this column already runs on is the space under the header, so it
                // carries none of its own.
                IntakeSectionHeader(
                    "What a good file looks like",
                    trackingEm: 0.14,
                    horizontalPadding: 4,
                    bottomPadding: 0
                )
                .padding(.top, Spacing.small)

                FileExampleCard()
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sheet)
            .padding(.bottom, Spacing.hero)
        }
        // The paste box's Return types a newline, so this is the only way the keyboard goes down
        // without a drag — and the button that acts on what was typed is underneath it.
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar { isTyping = false }
    }

    /// A sentence about why something did not come in. Two controls raise one of these and they
    /// look the same, because they are the same kind of news.
    private func refusal(_ message: String) -> some View {
        Text(message)
            .typeStyle(.intakeNote, color: Theme.danger)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: The file

    /// `background:#fff;border:1.5px dashed #C3DFCF;border-radius:18px;padding:28px 20px 24px`.
    ///
    /// Hand-drawn rather than `Card`, which strokes a solid border — the same call
    /// `VenueEmptyState:76-134` makes, and for the same plate: `8b`'s "No venues yet" and this are
    /// eleven measurements that agree, which is why the `OnboardingMetrics.empty*` constants are
    /// read here under names that say "empty". See the `8c` section of that file.
    private var dropPlate: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.cardLarge, style: .continuous)

        return VStack(spacing: 0) {
            // `ph-file-arrow-up` at 24 on a 52pt `accentSurface` tile. Decoration above a heading
            // that already says what this is.
            IntakeIconTile(
                "arrow.up.doc",
                size: OnboardingMetrics.emptyMark,
                glyphSize: OnboardingMetrics.emptyMarkGlyph,
                radius: OnboardingMetrics.emptyMarkRadius,
                fill: Theme.accentSurface,
                border: Theme.accentSurfaceBorder,
                glyphColor: Theme.accent
            )

            IntakeTitle("Drop the sign-up list", style: .intakeEmptyHeading)
                .multilineTextAlignment(.center)
                .padding(.top, OnboardingMetrics.emptyTitleGap)

            // The sentence is the design's, and it is shorter than the one it replaces by exactly
            // the clause naming the header row. That clause is not gone — it is the first row of
            // `FileExampleCard`, in the words the refusal itself uses. See this file's header for
            // why it was allowed to move down rather than being kept here as well.
            // "Everyone lands unranked" until 2026-08-10, which was true of the *ladder* and read
            // as a claim about courts — and was the sentence a reader quoted back when an import
            // left every kid in one pile. Ranking is still something the camp does afterwards on
            // Rank; what changed is that the groups are no longer empty while it waits.
            //
            // The second half is the caller's now, and it names the venue and its group count —
            // `state1.js:337`'s `importHint`. In the plate rather than under the paste box the
            // design puts it, because both routes end in the same deal and a sentence that only
            // appears beside one of them is a fact half the readers never meet.
            Text("We read names, ages and genders. \(dealNote)")
                .typeStyle(.emptyBody, color: Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: copyWidth)
                .padding(.top, OnboardingMetrics.emptyBodyGap)

            formatChips
                .padding(.top, OnboardingMetrics.dropChipsGap)

            PrimaryButton(
                "Choose a file",
                height: ctaHeight,
                radius: Radius.input,
                font: .intakeButton,
                action: chooseFile
            )
            .padding(.top, OnboardingMetrics.emptyCtaGap)

            pullFromEmail
                .padding(.top, Spacing.gutterWide)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, OnboardingMetrics.emptyPaddingHorizontal)
        .padding(.top, OnboardingMetrics.emptyPaddingTop)
        .padding(.bottom, OnboardingMetrics.emptyPaddingBottom)
        .background(Theme.surface, in: shape)
        .overlay {
            // CSS draws a dashed 1.5px border at roughly three times its width per dash and gap.
            shape.strokeBorder(
                Theme.accentBorder,
                style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
            )
        }
    }

    /// What the picker will let through, said before the tap rather than discovered during it.
    ///
    /// Read off `RosterFileFormat` — the same list the `.fileImporter` below is handed — so a chip
    /// cannot come to promise a format the picker greys out. That is why the type exists; the
    /// missing `PDF` the design draws is argued there rather than here.
    ///
    /// `Text` on a capsule rather than `Chip`. Not because `Chip` insists on being a button — it
    /// has an action-less branch that draws a read-only badge (`Components.swift:385-389`) — but
    /// because reaching it would mean adding both a `ChipMetrics` preset (nothing in that table is
    /// `600 11` uppercase at `5/11`) and a `ChipTone` case (nothing there is a plain grey fill with
    /// no border; `.outline` is white with a grey stroke). Two additions to a shared control, so
    /// that one screen can draw two words. `SetupView.swift:486-493` hand-draws its inert chip for
    /// the same reason. `IntakeChoiceChip` is a button outright and never fitted.
    ///
    /// Nothing here is tappable, so nothing here grows to 44pt either.
    private var formatChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(RosterFileFormat.allCases, id: \.self) { format in
                formatChip(format.label)
            }
        }
        // Left to itself this reads as two stray words between a sentence and a button. One
        // element saying what it means, spelled the way it is said rather than the way it is
        // written — "X L S X" is not how anybody asks whether their file will open.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reads \(RosterFileFormat.spokenNames) files")
    }

    private func formatChip(_ name: String) -> some View {
        Text(name)
            .typeStyle(.intakeFormatChip, color: Theme.inkTertiary)
            .padding(.vertical, OnboardingMetrics.formatChipPaddingVertical)
            .padding(.horizontal, OnboardingMetrics.formatChipPaddingHorizontal)
            .background(OnboardingTheme.formatChip, in: Capsule(style: .continuous))
    }

    /// `600 13` accent copy under the button, `margin-top:14px`.
    ///
    /// The same picker, on purpose, which is why it is a line of text rather than the second
    /// capsule this screen used to draw beside the first. A list forwarded by the office arrives
    /// as a mail attachment, and every mail attachment is reachable through the document browser —
    /// so this is the honest version of "from email" until there is a camp address to forward one
    /// to, and the design is right that an alias for the button above should not look like a
    /// second choice.
    private var pullFromEmail: some View {
        Button(action: chooseFile) {
            Text("Pull one from email")
                .typeStyle(.intakeInlineAction, color: Theme.accent)
                // A 13pt line draws about 17pt tall; 14 either side clears 44. Also exactly the
                // gap above, so the grown target meets the button's bottom edge without taking
                // a strip of it — `intakeTouchTarget` widens what is hit, not what is drawn, and
                // this one is drawn last of the two.
                .intakeTouchTarget(inset: Spacing.gutterWide)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the same file picker — a forwarded list is a mail attachment")
    }

    /// `gap:9px;padding:0 6px` — a bare line on the page background.
    ///
    /// Not `IntakeNote`, which is `8e`'s green-tinted box: this one has no plate, no border and a
    /// grey glyph, because it is a caption under the plate rather than a note inside a card.
    ///
    /// The design's sentence ends "Gender and venue are optional". `venue` is dropped, because
    /// there is no venue column — `Columns.init?(header:)` has no case for one, so a file that
    /// carried it would be read as though it had not and every kid would land in the same place
    /// regardless. Advertising a column that is silently ignored is the failure this whole screen
    /// is arranged to avoid; `FileExampleCard.swift:40-42` refused the identical promise.
    private var fileNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .font(.system(size: noteGlyph, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                // The glyph sits on the first line's cap height rather than centred on two lines.
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text("Needs a first name, last name and age per row. Gender is optional — we will ask for what is missing.")
                .typeStyle(.intakeFileNote, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.tight)
    }

    // MARK: The list, pasted

    /// `sheet-shImport.html:6-10` — a hairline divider reading "or paste the list", a box, and a
    /// button that counts what is in it.
    ///
    /// ── Why a second way in at all ────────────────────────────────────────────────────────────
    ///
    /// The file picker is the right primary and stays it: a camp of forty arrives as a
    /// spreadsheet. But a great many rosters arrive as *text* — the body of an email, a message
    /// from the front desk, six late sign-ups a parent sent overnight — and every one of those had
    /// to be saved into a file first, on a phone, standing on a court at ten to nine. The document
    /// browser is not a route to something that is already on the clipboard.
    ///
    /// It is also the only way to get a roster in at all without leaving the app, which makes this
    /// the one path a simulator or a fresh install can walk end to end.
    ///
    /// ── The count is the label, not a caption ─────────────────────────────────────────────────
    ///
    /// `pasteCta` (`state1.js:338`) reads "Add 12 kids" and dims to `.45` at zero. That is worth
    /// transcribing exactly: it is the whole of the feedback on this control. A person pasting
    /// twelve lines and reading "Add 12 kids" has had their list parsed in front of them, and one
    /// reading "Add 11 kids" has been told about the blank line at the bottom before they commit to
    /// anything. `IntakeFile.pastedCount` is what counts, on every keystroke, swallowing its own
    /// refusals — see it for why.
    @ViewBuilder
    private var pasteBox: some View {
        let count = IntakeFile.pastedCount(pasted)

        divider("or paste the list")

        FormTextArea(
            // Two lines, which is what makes the format legible without a sentence explaining it.
            // The order shown here *is* the contract `IntakeFile.parse(pasted:)` reads by when the
            // paste carries no header of its own — see there for why a paste may go without one
            // and a file may not.
            "Serene Chu, 11, F\nLiam Prior, 12, M",
            text: $pasted,
            label: "Paste the list",
            // `1.5px #E4E5E9` at radius 15 with `13/15` — the design's box, already a preset.
            metrics: .sheetBoxLarge,
            type: .intakeFieldValue,
            promptType: .intakeFieldValue,
            valueColor: Theme.ink,
            // `height:96px` is about four lines at 13.5. A range rather than a fixed height,
            // because a `TextField(axis:)` grows and a fixed 96 would scroll a list of forty inside
            // a box the size of a stamp; the lower bound is the shape the design draws when empty.
            lineLimit: 4...12,
            focus: $isTyping
        )

        if let pasteError {
            refusal(pasteError)
        }

        PrimaryButton(
            count > 0 ? "Add \(count) kid\(count == 1 ? "" : "s")" : "Add kids",
            height: ctaHeight,
            radius: Radius.input,
            font: .intakeButton,
            action: addPasted
        )
        // `opacity:{{ pasteOp }}` — `.45` with nothing in the box. Disabled as well as dimmed,
        // because the design's dimmed CTA is a no-op click and a button that looks pressable and
        // is not is worse than one that says so to VoiceOver too.
        .opacity(count > 0 ? 1 : 0.45)
        .disabled(count == 0)
    }

    /// `flex:1` hairline, a word, `flex:1` hairline.
    private func divider(_ label: String) -> some View {
        HStack(spacing: Spacing.small) {
            Hairline(color: Theme.hairline)
            Text(label)
                .typeStyle(.intakeFootnote, color: Theme.inkFaint)
            Hairline(color: Theme.hairline)
        }
        // `margin:13px 0 9px` on a column that already carries 12 between its children.
        .padding(.top, 1)
        // The rules are decoration around a word; read as three elements they are two silences.
        .accessibilityElement(children: .combine)
    }

    /// Parses what is in the box for real, and hands it on.
    ///
    /// The button is already disabled at zero, so the throw here is the *other* refusals —
    /// `nothingToImport` for a box of blank lines, which `pastedCount` also returns 0 for and which
    /// this is the only thing that can put a sentence to.
    private func addPasted() {
        pasteError = nil
        do {
            onImported(try IntakeFile.parse(pasted: pasted))
            // Cleared on success only. A refusal leaves the text exactly where the reader can fix
            // it, which is the same rule `readError` follows one control up.
            pasted = ""
            isTyping = false
        } catch {
            pasteError = error.localizedDescription
        }
    }

    /// Both routes into the picker, which are the same route.
    ///
    /// Named rather than written twice inline: clearing the last failure is half of what "choose a
    /// file" means, and the copy of this that lived under the second button is exactly the kind of
    /// pair that comes apart — one of them gains a line, the other does not, and the stale error
    /// sits under the plate through the next attempt.
    private func chooseFile() {
        readError = nil
        isChoosingFile = true
    }

    /// Gets at the bytes and hands them over.
    ///
    /// Deliberately only that. Which reader a file needs — a CSV's or a workbook's — is a fact
    /// about rosters rather than about this screen, so it lives on `IntakeFile` and this branches
    /// on nothing. It did briefly: the sniff and the UTF-8 fallback were written here, in a
    /// picker callback, where the second entry point would have had to re-derive them and no test
    /// could reach them.
    ///
    /// What is left is genuinely the view's: the security scope, and the sentence to put under
    /// the card.
    private func read(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            // A file the user picked lives outside the sandbox until this is claimed.
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

            guard let bytes = try? Data(contentsOf: url) else {
                throw IntakeFile.ReadError.unreadable
            }
            onImported(try IntakeFile.parse(bytes, named: url.lastPathComponent))
        } catch let error as CocoaError where error.code == .userCancelled {
            // The picker was dismissed rather than used. Not a failure to report.
        } catch {
            readError = error.localizedDescription
        }
    }

    // MARK: The two ways that are not a file

    /// The one card `8c` ends on: a walk-in, and a blank file to send the office.
    ///
    /// The template row came out of `FileExampleCard`, where it was the last line of a reference
    /// card, and the move is the design's. It belongs beside "Add one by hand" because the two are
    /// the same kind of thing — something to *do* when the file in front of you is not the file
    /// this screen wants — where the card below is something to read.
    private var actionsCard: some View {
        Card(radius: Radius.cardLarge) {
            Button(action: onAddByHand) {
                actionRow(
                    "person.badge.plus",
                    title: "Add one by hand",
                    // The design writes "Walk-ins and under-11s" flat, drawing a camp with one
                    // venue. Kept named, because the second entry point reaches this screen from a
                    // *chosen* venue's chip in Groups and the kid lands in that one — with several
                    // venues on the camp, "at Sycamore" is the whole answer to where they go.
                    detail: "Walk-ins and under-11s at \(venueName)"
                )
            }
            .buttonStyle(.plain)

            templateRow
        }
    }

    /// `ShareLink` rather than a `fileExporter`: the office is at the other end of whatever the
    /// reader already uses to talk to it, and the share sheet holds Save to Files as well, which is
    /// the "download" the design's title means.
    ///
    /// The caption reads `CSV, five columns` where the frame reads `XLSX, four columns`. The app
    /// hands over a CSV of five columns and says so; the whole argument, including why an `.xlsx`
    /// writer was considered and not built, is at the head of `RosterTemplate.swift`, and
    /// `RosterTemplateTests` fails if the file stops matching these words.
    private var templateRow: some View {
        let caption = "CSV, five columns"

        return ShareLink(item: RosterTemplate.file, preview: SharePreview(RosterTemplate.fileName)) {
            actionRow("square.and.arrow.down", title: "Download the template", detail: caption)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Download the template")
        .accessibilityHint("Shares \(RosterTemplate.fileName) — \(caption)")
    }

    /// `padding:13px 14px`, an 11pt gap, a 34pt tile at radius 11, and a caret.
    ///
    /// One function rather than two rows written out, because the second row exists to look like
    /// the first: they are the card's two children and a reader should not be able to tell which
    /// was drawn first.
    private func actionRow(_ symbol: String, title: String, detail: String) -> some View {
        CardRow(spacing: Spacing.row, horizontalPadding: Spacing.gutterWide, verticalPadding: 13) {
            IntakeIconTile(symbol, size: 34, glyphSize: 16, radius: Radius.control, fill: OnboardingTheme.iconPlate)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(title)
                    .typeStyle(.intakeRowTitle, color: Theme.ink)
                Text(detail)
                    .typeStyle(.intakeRowMeta, color: Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            DisclosureChevron(size: 15)
                .accessibilityHidden(true)
        }
        // Both rows draw past 44 on their own, so this changes nothing today. It is here in this
        // order — grow, then shape — because the reverse pins the hit region to the drawn plate,
        // and `CardRow` has already taken its own content shape by the time this runs.
        .frame(minHeight: HitTarget.minimum)
        .contentShape(.rect)
    }
}

// MARK: - Previews

#Preview("Bring in the week") {
    BringInTheWeekView(
        venueName: "Venue 1",
        subtitle: "Nobody added yet · Venue 1",
        dealNote: "Everyone is dealt into Venue 1's 6 groups, evenly — rank them after.",
        exit: .openCamp,
        onImported: { _ in },
        onAddByHand: {},
        onExit: {}
    )
    .showsMockStatusBar()
}

/// The same screen from inside a camp, which is the state the two new entry points open it in:
/// the header counts a roster rather than an absence, and the way out is "Done".
#Preview("Bring in the week — from inside a camp") {
    BringInTheWeekView(
        venueName: "Sycamore",
        subtitle: "2 added · 76 kids · Sycamore",
        dealNote: "Everyone is dealt into Sycamore's 6 groups, evenly — rank them after.",
        exit: .done,
        onImported: { _ in },
        onAddByHand: {},
        onExit: {}
    )
    .showsMockStatusBar()
}
