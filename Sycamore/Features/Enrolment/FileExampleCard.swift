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
//     it contains, so position is never read at all.
//  2. **Any of the three delimiters.** `IntakeFile.separator(in:)` sniffs comma, tab and
//     semicolon — the last being what an Excel installed across most of Europe writes.
//  3. **A missing column is silence.** This is the load-bearing one and the least guessable: a
//     file with no Returning column does not un-return the camp, it says nothing. That rule is
//     `RosterReconciliation.applying`'s, and stating it here is what stops somebody adding a
//     column of "No"s to be helpful.
//
//  Above all three, and drawn first, is the one line here that is not a tolerance. Reading columns
//  by what the header says means there has to *be* a header: a first row of data is refused
//  (`IntakeRoster.swift:321`) rather than read as `first, last, age, gender` by position, because
//  the first real export that fallback met is laid out `Last Name, First Name, Age, Gender`, and a
//  header-less copy of it would have imported a whole camp with every name the wrong way round —
//  cleanly, with nothing on `8d` to notice. A requirement is a poor thing to learn by having a
//  file refused, which is the argument `BringInTheWeekView.swift:94-105` makes for greying a PDF
//  out rather than accepting one and failing, so the card states it before a file is chosen. The
//  words are the refusal's own (`IntakeRoster.swift:246`), so the card and the error are one
//  sentence rather than two that nearly agree.
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
            headerRow

            column("First name", recognised: "first, given — or one “Name” column")
            column("Last name", recognised: "last, surname, family")
            column("Age", recognised: "age")
            column("Gender", recognised: "gender, sex")
            column("Returning", recognised: "returning", isExpected: false)

            tolerances
            template
        }
    }

    // MARK: The row the file has to have

    /// The one hard requirement on a card otherwise made of tolerances, and the reason it is drawn
    /// first: it is a fact about the file's *first row*, so it reads in the place the file's first
    /// row sits, above the names that row is allowed to use.
    ///
    /// Not a tick. A tick on this card means "the camp is hoping for this" (see `column`), and a
    /// row that must be there is a different kind of thing from a column that is wanted — the
    /// glyph is a table with its top band filled, which is the thing being asked for.
    private var headerRow: some View {
        // Named once because it is said twice — the eye reads it and VoiceOver reads it after the
        // word that places it, and a copy edit to one of those is a copy edit to both.
        let why = "Without it we would be guessing which is which, so a file that opens with a kid is refused."

        return row(
            "The first row needs to name the columns",
            detail: why,
            symbol: "rectangle.topthird.inset.filled",
            tint: Theme.accent,
            titleColor: Theme.inkWarm,
            spoken: "Required. \(why)"
        )
    }

    // MARK: One column

    /// - Parameter isExpected: whether the camp is hoping for this one. Every column is optional to
    ///   the *parser* — only a first name is required to make a row at all — so the tick is about
    ///   what the camp wants rather than about what the file must have. Returning is the one most
    ///   offices do not track, and drawing it with a tick would read as a shortfall on nearly
    ///   every real file. The one thing the file genuinely must have is `headerRow` above.
    private func column(_ name: String, recognised: String, isExpected: Bool = true) -> some View {
        row(
            name,
            detail: recognised,
            symbol: isExpected ? "checkmark.circle.fill" : "circle.dashed",
            tint: isExpected ? Theme.accent : Theme.inkFaint,
            titleColor: isExpected ? Theme.inkWarm : Theme.inkMuted,
            spoken: "\(isExpected ? "Wanted" : "Optional"). Recognised as \(recognised)"
        )
    }

    // MARK: The shape both of them are

    /// A glyph, a line, and a grey line under it. The requirement and the five columns are the
    /// same row saying two kinds of thing, so it is drawn once here rather than twice with the
    /// glyph's one-point nudge copied into both.
    ///
    /// - Parameter spoken: what VoiceOver reads after the title. Left to itself it reads "check
    ///   circle fill, First name, first comma given" — a glyph name and a fragment — so each row
    ///   is one element and the glyph is spoken as what it means: "First name. Wanted. Recognised
    ///   as first, given…".
    private func row(
        _ title: String,
        detail: String,
        symbol: String,
        tint: Color,
        titleColor: Color,
        spoken: String
    ) -> some View {
        CardRow(spacing: 10, horizontalPadding: 13, verticalPadding: 11, alignment: .top) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(tint)
                // The glyph sits on the first line's cap height rather than centred on two lines.
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text(title)
                    .typeStyle(.intakeChecklist, color: titleColor)
                Text(detail)
                    .typeStyle(.intakeRowDetail, color: Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken)
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
