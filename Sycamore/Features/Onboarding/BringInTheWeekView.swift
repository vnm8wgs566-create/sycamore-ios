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

import SwiftUI
import UniformTypeIdentifiers

struct BringInTheWeekView: View {

    /// The venue a walk-in lands in — the first one, which is where the design puts the
    /// under-11s.
    let venueName: String
    /// Kids typed in by hand so far. The header counts them; nothing else on this screen changes.
    let handAddedCount: Int
    let onImported: (IntakeImport) -> Void
    let onAddByHand: () -> Void
    let onOpenCamp: () -> Void

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
        .background(Theme.grouped)
        // Cross-platform: `fileImporter` is the SwiftUI wrapper over the document browser and
        // exists on macOS too, so the whole intake path builds for both without a shim.
        //
        // CSV and plain text only. The copy offers a PDF because the office often sends one,
        // but a PDF's text needs extracting server-side and there is no server yet; leaving the
        // type out means the picker greys those files rather than accepting one and failing.
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]
        ) { result in
            read(result)
        }
    }

    // MARK: Header

    private var header: some View {
        IntakeHeader(title: "Players", subtitle: subtitle) {
            // The way out of the flow. The camp is created by whichever screen ends it, so
            // "open" is literal: this is the tap that writes the camp and lands in the app.
            Button(action: onOpenCamp) {
                Text("Open the camp")
                    .typeStyle(.chipMedium, color: Theme.accent)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum, alignment: .trailing)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        guard handAddedCount > 0 else { return "Nobody added yet · \(venueName)" }
        return "\(handAddedCount) added by hand · \(venueName)"
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                importCard

                if let readError {
                    Text(readError)
                        .typeStyle(.footnote, color: Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                addByHandRow

                SectionHeader("What a file needs")
                    .padding(.top, Spacing.small)

                requirementsCard
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.gutterWide)
            .padding(.bottom, Spacing.hero)
        }
    }

    // MARK: The file

    private var importCard: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)

        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .fill(Theme.accentTint)
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline)
                }
                .overlay {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Theme.accent)
                }
                // Decoration above a heading that already says what this is.
                .accessibilityHidden(true)

            Text("Import the sign-up list")
                .typeStyle(.venueHeading, color: Theme.ink)
                .padding(.top, Spacing.gutterWide)

            Text("A CSV or a PDF from the office. Names, ages and genders come across — nobody is ranked yet.")
                .typeStyle(.bodySmall, color: Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)
                .padding(.top, 7)

            HStack(spacing: Spacing.small) {
                Pill("Choose a file", tone: .accent, font: .chip, horizontalPadding: 16, verticalPadding: 10) {
                    readError = nil
                    isChoosingFile = true
                }
                // Same picker, on purpose. A list forwarded by the office arrives as a mail
                // attachment, and every mail attachment is reachable through the document
                // browser — so this is the honest version of "from email" until there is a
                // camp address to forward it to.
                Pill("From email", tone: .outline, font: .chip, horizontalPadding: 16, verticalPadding: 10) {
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
            shape.strokeBorder(
                Theme.accentBorder,
                style: StrokeStyle(lineWidth: BorderWidth.input, dash: [6, 4])
            )
        }
    }

    private func read(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            // A file the user picked lives outside the sandbox until this is claimed.
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw IntakeFile.ReadError.unreadable
            }
            onImported(try IntakeFile.parse(text, named: url.lastPathComponent))
        } catch let error as CocoaError where error.code == .userCancelled {
            // The picker was dismissed rather than used. Not a failure to report.
        } catch {
            readError = error.localizedDescription
        }
    }

    // MARK: By hand

    private var addByHandRow: some View {
        Card {
            Button(action: onAddByHand) {
                CardRow(spacing: Spacing.row) {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Theme.fill)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(Theme.inkSecondary)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add a player by hand")
                            .typeStyle(.rowLabel, color: Theme.ink)
                        Text("Walk-ins and under-11s at \(venueName)")
                            .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                    }

                    Spacer(minLength: 0)

                    DisclosureChevron(size: 15)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: What a file needs

    private var requirementsCard: some View {
        Card {
            requirement("First name, last name")
            requirement("Age")
            requirement("Gender")
            requirement("Venue — optional, ask later", isRequired: false)
        }
    }

    private func requirement(_ text: String, isRequired: Bool = true) -> some View {
        CardRow(spacing: 10, horizontalPadding: 13, verticalPadding: 11) {
            // Hidden rather than labelled: the optional row says "optional" in its own copy, so
            // a spoken "dashed circle" would be the only thing on this card that means nothing.
            Image(systemName: isRequired ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isRequired ? Theme.accent : Theme.inkFaint)
                .accessibilityHidden(true)
            Text(text)
                .typeStyle(.bodySmall, color: isRequired ? Theme.inkSecondary : Theme.inkMuted)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews

#Preview("Bring in the week") {
    BringInTheWeekView(
        venueName: "Venue 1",
        handAddedCount: 0,
        onImported: { _ in },
        onAddByHand: {},
        onOpenCamp: {}
    )
    .showsMockStatusBar()
}

#Preview("Bring in the week — two by hand") {
    BringInTheWeekView(
        venueName: "Venue 1",
        handAddedCount: 2,
        onImported: { _ in },
        onAddByHand: {},
        onOpenCamp: {}
    )
    .showsMockStatusBar()
}
