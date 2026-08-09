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
    let exit: Exit
    let onImported: (IntakeImport) -> Void
    let onAddByHand: () -> Void
    let onExit: () -> Void

    @State private var isChoosingFile = false
    /// Why the last file did not come in. Sits under the card that started it rather than in a
    /// banner over the screen — the fix is to choose a different file, and the button that does
    /// that is right there.
    @State private var readError: String?

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
        // Separated text and Excel. The list is what the app can actually read, which is what a
        // picker's `allowedContentTypes` is for: a greyed-out file is the truth told before the
        // tap, where a file accepted and then refused is the same news delivered worse.
        //
        // `.xlsx` was the missing one and it is the file most offices actually send — this screen
        // greyed out the only export a camp had, with nothing on screen to say why. It is the
        // narrow `UTType.xlsx` rather than the broad `.spreadsheet`; see that token for why.
        //
        // Deliberately no PDF. Its text needs extracting server-side and there is no server yet,
        // so the type stays out and the picker greys those files rather than accepting one and
        // failing. The card above no longer offers one either — it did, and an offer the picker
        // refuses is a worse way to learn this than a greyed-out file.
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .xlsx]
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

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.cardGap) {
                importCard

                if let readError {
                    Text(readError)
                        .typeStyle(.intakeNote, color: Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                addByHandRow

                // The 9pt gap this column already runs on is the space under the header, so it
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
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, Spacing.hero)
        }
    }

    // MARK: The file

    private var importCard: some View {
        let shape = RoundedRectangle(cornerRadius: OnboardingMetrics.cardRadius, style: .continuous)

        return VStack(spacing: 0) {
            // Decoration above a heading that already says what this is.
            IntakeIconTile(
                "arrow.up.doc",
                size: 48,
                glyphSize: 22,
                radius: OnboardingMetrics.cardRadius,
                fill: Theme.accentSurface,
                border: Theme.accentSurfaceBorder,
                glyphColor: Theme.accent
            )

            Text("Import the sign-up list")
                .typeStyle(.intakeStatValue, color: Theme.ink)
                .padding(.top, Spacing.gutterWide)

            // The header row is named here rather than only in the failure. It is the one hard
            // requirement an import has — everything else about the file is tolerated — and
            // learning it by being refused is exactly what greying out a PDF avoids.
            Text("A CSV or an Excel file from the office, with a first row naming the columns. Nobody is ranked yet.")
                .typeStyle(.intakeLead, color: Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)
                .padding(.top, 7)

            HStack(spacing: Spacing.small) {
                IntakePillButton(title: "Choose a file", isProminent: true) {
                    readError = nil
                    isChoosingFile = true
                }
                // Same picker, on purpose. A list forwarded by the office arrives as a mail
                // attachment, and every mail attachment is reachable through the document
                // browser — so this is the honest version of "from email" until there is a
                // camp address to forward it to.
                IntakePillButton(title: "From email") {
                    readError = nil
                    isChoosingFile = true
                }
            }
            .padding(.top, Spacing.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, Spacing.sheet)
        .background(Theme.surface, in: shape)
        .overlay {
            // CSS draws a dashed 1.5px border at roughly three times its width per dash and gap.
            shape.strokeBorder(
                Theme.accentBorder,
                style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
            )
        }
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

    // MARK: By hand

    private var addByHandRow: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            Button(action: onAddByHand) {
                CardRow(spacing: Spacing.row, horizontalPadding: Spacing.gutterWide, verticalPadding: 13) {
                    IntakeIconTile(
                        "person.badge.plus",
                        size: 34,
                        glyphSize: 17,
                        radius: Radius.control,
                        fill: OnboardingTheme.iconPlate
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add a player by hand")
                            .typeStyle(.intakeRowTitle, color: Theme.ink)
                        Text("Walk-ins and under-11s at \(venueName)")
                            .typeStyle(.intakeRowDetail, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)

                    DisclosureChevron(size: 15)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Previews

#Preview("Bring in the week") {
    BringInTheWeekView(
        venueName: "Venue 1",
        subtitle: "Nobody added yet · Venue 1",
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
        exit: .done,
        onImported: { _ in },
        onAddByHand: {},
        onExit: {}
    )
    .showsMockStatusBar()
}
