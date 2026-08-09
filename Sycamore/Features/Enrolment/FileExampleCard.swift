//
//  FileExampleCard.swift
//  Sycamore
//
//  "What a good file looks like" — the card at the foot of `8c`.
//
//  It replaces the four-row "What a file needs" checklist that stood here. The rows are the same
//  rows and they are drawn the same way; what is added is the part a checklist cannot say. A list
//  of four nouns tells somebody *what* to send and nothing about what happens if their spreadsheet
//  spells it differently, orders it differently, or leaves a column out — which is every real
//  question a person has while looking at the export their office actually sends them.
//
//  So each row now carries the words the parser recognises for it, and three lines underneath say
//  the three tolerances the parser genuinely has:
//
//  1. **Any order.** `Columns.init?(header:)` finds each column by searching the header for what
//     it contains, so position is never read when there is a header row.
//  2. **Any of the three delimiters.** `IntakeFile.separator(in:)` sniffs comma, tab and
//     semicolon — the last being what an Excel installed across most of Europe writes.
//  3. **A missing column is silence.** This is the load-bearing one and the least guessable: a
//     file with no Returning column does not un-return the camp, it says nothing. That rule is
//     `RosterReconciliation.applying`'s, and stating it here is what stops somebody adding a
//     column of "No"s to be helpful.
//
//  And then the file itself, through `ShareLink`, because the honest answer to "what should I
//  send?" is a file rather than a paragraph — the office can open it, type over the three rows and
//  send it back.
//
//  The copy deliberately does not claim more than the parser does. There is no venue column: `8c`
//  promises "Venue — optional, ask later" and the truth behind that promise is that nothing reads
//  one, so the row says where everybody lands instead of implying a column that would be ignored.
//

import SwiftUI

struct FileExampleCard: View {

    /// The design's 15pt row glyph, grown with the reader's type so it keeps its place beside two
    /// lines of copy.
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 15
    /// The bullet on a tolerance line. Scaled off `.footnote` — the style the line itself is set
    /// in — so the dot and the sentence grow together rather than the dot staying put.
    @ScaledMetric(relativeTo: .footnote) private var bulletSize: CGFloat = 4

    var body: some View {
        Card(radius: OnboardingMetrics.cardRadius) {
            column("First name", recognised: "first, given — or one “Name” column")
            column("Last name", recognised: "last, surname, family")
            column("Age", recognised: "age")
            column("Gender", recognised: "gender, sex")
            column("Returning", recognised: "returning", isExpected: false)

            tolerances
            template
        }
    }

    // MARK: One column

    /// - Parameter isExpected: whether the camp is hoping for this one. Every column is optional to
    ///   the *parser* — only a first name is required to make a row at all — so the tick is about
    ///   what the camp wants rather than about what the file must have. Returning is the one most
    ///   offices do not track, and drawing it with a tick would read as a shortfall on nearly
    ///   every real file.
    private func column(_ name: String, recognised: String, isExpected: Bool = true) -> some View {
        CardRow(spacing: 10, horizontalPadding: 13, verticalPadding: 11, alignment: .top) {
            Image(systemName: isExpected ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(isExpected ? Theme.accent : Theme.inkFaint)
                // The glyph sits on the first line's cap height rather than centred on two lines.
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(name)
                    .typeStyle(.intakeChecklist, color: isExpected ? Theme.inkWarm : Theme.inkMuted)
                Text(recognised)
                    .typeStyle(.intakeRowDetail, color: Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        // One element per line, and the tick spoken as what it means. Left to itself VoiceOver
        // reads "check circle fill, First name, first comma given", which is a glyph name and a
        // fragment — this reads "First name. Wanted. Recognised as first, given…".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(
            "\(isExpected ? "Wanted" : "Optional"). Recognised as \(recognised)"
        )
    }

    // MARK: What the file is allowed to do

    /// Through `CardRow` like the two blocks either side of it, rather than restating the card's
    /// 13/11 gutter — one rule for every row in this card.
    private var tolerances: some View {
        CardRow(horizontalPadding: 13, verticalPadding: 11) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                tolerance("Any order — the header row is read by what it says, not where it sits.")
                tolerance("Commas, tabs or semicolons, whichever your spreadsheet writes.")
                tolerance("A column that is not there says nothing. Nobody is changed by a blank.")
            }
        }
    }

    private func tolerance(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // A dot rather than a second tick: these are not things to supply, they are things
            // that will not go wrong.
            Circle()
                .fill(Theme.inkGhost)
                .frame(width: bulletSize, height: bulletSize)
                .padding(.top, Spacing.tight)
                .accessibilityHidden(true)

            Text(text)
                .typeStyle(.intakeRowDetail, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: The file itself

    private var template: some View {
        ShareLink(
            item: RosterTemplate.file,
            preview: SharePreview(RosterTemplate.fileName)
        ) {
            CardRow(spacing: 10, horizontalPadding: 13, verticalPadding: 11) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: glyphSize, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)

                Text("Send a blank one to the office")
                    .typeStyle(.intakeChecklist, color: Theme.accent)

                Spacer(minLength: 0)
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send a blank one to the office")
        .accessibilityHint("Shares \(RosterTemplate.fileName)")
    }
}

// MARK: - Previews

#Preview("What a good file looks like") {
    ScrollView {
        FileExampleCard()
            .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
}

#Preview("What a good file looks like — large type") {
    ScrollView {
        FileExampleCard()
            .padding(Spacing.gutter)
    }
    .background(Theme.surfaceWarm)
    .dynamicTypeSize(.accessibility1)
}
