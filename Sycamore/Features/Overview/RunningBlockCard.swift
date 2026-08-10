//
//  RunningBlockCard.swift
//  Sycamore
//
//  What is happening at the venue right now — 4a's first card, and the top of the screen.
//
//  It used to be inferred. `8i` headed the screen "Skills rotation · until 10:30" and then drew
//  four court cards, only one of which was about the skills rotation, so this card was built to
//  hold the thing the line named and the screen had nowhere to put. 4a draws it outright, first,
//  above the needs-you row and above the pins, and the whole shape of the screen follows from that:
//  **now first, needs-you second, venue up top.**
//
//  ── The accent border lives here now ─────────────────────────────────────────────────────────
//
//  This file used to argue the opposite, at length, and it is worth saying exactly what changed
//  rather than deleting the paragraph. The argument was: `OverviewCourtCard` spends the accent
//  border and `OverviewTheme.yourCourtLift` on one card, the court you are standing on, and a
//  second accent-bordered card above it would make the border mean "yours, or else important",
//  which is to say nothing. That reasoning was sound about the screen it was written for — one
//  where the loudest thing was a court.
//
//  4a moves the treatment rather than duplicating it. The `1.5px #C3DFCF` rule and the
//  `0 8px 22px rgba(26,127,85,.08)` lift are on **this** card and on no court card at all
//  (`design/rebuild/section-t4.html:66,88,105`): 4a is an admin frame and every court on it is a
//  plain `#EDEEF1` box. So the border still means exactly one thing on the screen — *this is what
//  is happening* — and it has simply stopped meaning "yours".
//
//  `8j` keeps a bordered card for a coach's own court, because a coach's screen still has to answer
//  "which of these is mine" and the design has no later frame for that. On that one screen the two
//  borders do coexist, which is precisely what the old paragraph refused; the reason it is
//  acceptable is that the two are never ambiguous when they are stacked — the accent card at the
//  top of the scroll is the block, and the accent card in the run of courts is yours. See
//  `OverviewScreen.swift`'s header for the branch.
//
//  ── And the pills, the instruction and the notes came off ────────────────────────────────────
//
//  4a draws four things inside this card: the status line, the title, one meta line and a call to
//  action, with `Next · …` under a rule. It draws no coach pills (the names run inline in the meta
//  line instead — `Nass, Alina, Tom`), no instruction paragraph and no notes list.
//
//  Losing the notes is the one that costs something, and it was argued for here: "the second note
//  off a block is as likely to be the allergy as the first". What buys it back is the button. The
//  card is now a way *into* the block's morning rather than a transcript of it — `Take attendance`
//  goes to `8m` for exactly these courts, and the block's own screen on Schedule lists the
//  instruction and every note against it. A card that carried all of it could not also carry a
//  48pt call to action without becoming the screen.
//
//  ── The button says "Take attendance" and not "Take attendance · 20 of 22" ───────────────────
//
//  4a draws a count on it. The app does not, and the reason is that the first half of that figure
//  does not exist anywhere it can be read back from.
//
//  "20 of 22" is *marked over roster* — that is what the same pair means on `8m`, whose header
//  draws `\(markedCount) of \(total)` and calls the bar "Marked" (`AttendanceHeader.swift:44-51`).
//  The denominator is real and is the same walk `OverviewNow.playersHere(in:)` already does. The
//  numerator is not stored at all: `Camp.upsertAttendance` **drops an attendance row again the
//  moment it says nothing** — "present, staying to the end" (`Models.swift:1223-1233`) — so a kid
//  answered *present* leaves no trace, and a kid nobody has reached leaves the same no trace.
//  `AttendanceView` knows this and says so in as many words: marked is `@State` on that screen,
//  seeded from the day's away records, "and a kid with no row is indistinguishable from one nobody
//  has got to yet" (`AttendanceView.swift:38-41`).
//
//  So the honest readings available here are "how many are away" and "how many are here", and
//  neither of them is what the design's figure means. Drawing either under that label would put a
//  number on a button that goes down as a coach works and never reaches the total. The segment is
//  dropped whole — never a bare middot — and the button reads exactly as it does on `8l`
//  (`BlockDetailView.swift:259-266`), which is the other place the same register is opened from.
//
//  The figure becomes drawable the day attendance records an answer rather than an exception. That
//  is a column and a migration, not a view.
//

import SwiftUI

struct RunningBlockCard: View {

    let now: OverviewNow
    /// `Courts 1–3 · 22 players · Nass, Alina, Tom`.
    ///
    /// Composed by the screen through `OverviewNow.metaLine(in:)` rather than resolved here, for
    /// the reason `OverviewScreen.body` gives about rosters: the camp is walked once per pass and
    /// handed down, not once per card. Nil draws no line — a block with no courts, no kids and
    /// nobody on it has nothing to say here, and an empty row under the title reads as a fault.
    var metaLine: String?
    /// Opens `8m` for the block's courts.
    let onTakeAttendance: () -> Void

    var body: some View {
        Card(
            radius: OverviewTheme.cardRadius,
            borderColor: Theme.accentBorder,
            borderWidth: BorderWidth.input,
            isDivided: false
        ) {
            VStack(alignment: .leading, spacing: 0) {
                heading

                PrimaryButton(
                    "Take attendance",
                    height: OverviewTheme.blockCtaHeight,
                    radius: Radius.tile,
                    // `600 14.5;letter-spacing:-.015em`. `.rowLabel` is the same size and weight at
                    // `-.02em`; its own doc records that 0.005em drift and this fix.
                    font: .rowLabel.tracking(em: -0.015),
                    action: onTakeAttendance
                )
                .padding(.top, OverviewTheme.blockCtaGap)

                if let nextLine = now.nextLine {
                    Hairline(color: Theme.hairlineSoft)
                        .padding(.top, OverviewTheme.blockRuleTop)
                        .padding(.bottom, OverviewTheme.blockRuleBottom)

                    Text(nextLine)
                        .typeStyle(.rowDetail, color: Theme.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(OverviewTheme.cardPadding)
        }
        .shadow(OverviewTheme.yourCourtLift)
    }

    // MARK: What it is

    /// `On now · 41 min left` / `ends 10:30`, the block's name, and the line under it.
    ///
    /// Two accessibility elements, and the split is the one this card has always made. "On now, 41
    /// minutes left, ends 10:30, Skills rotation" is one phrase and is what the card *is*, so it
    /// combines and takes the heading trait — a reader working the rotor lands on it and knows where
    /// they are. The meta line stays its own element: it is three separate facts about who and where,
    /// and a heading somebody has to sit through the whole cast list of is no longer a landmark.
    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: OverviewTheme.headerGap) {
                    // Sentence case, `600 12.5 / -.01em`, and the countdown folded into the same
                    // run — `OverviewNow.statusLine` composes the pair so the middot can never be
                    // printed with nothing after it.
                    Text(now.statusLine)
                        .typeStyle(OverviewTheme.overline, color: Theme.accent)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    // `ends 10:30` at `400 12.5` in `inkFaint` — a reading, where the line beside it
                    // is a label. It was `now.timeLabel` at `600 12`, which said "until 10:30" in
                    // the same weight as the accent line and competed with it.
                    if let endsLabel = now.endsLabel {
                        Text(endsLabel)
                            .typeStyle(OverviewTheme.capacityReading, color: Theme.inkFaint)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, OverviewTheme.titleGap)

                // Allowed to wrap. A block's name is the subject of the card, and "Skills rotation
                // and serve ladder" truncated to "Skills rotation and…" is the half that says least.
                Text(now.title)
                    .typeStyle(OverviewTheme.blockTitle, color: Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let metaLine {
                Text(metaLine)
                    .typeStyle(OverviewTheme.cardSubtitle, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, OverviewTheme.blockMetaGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("On now — the design's block") {
    RunningBlockCard(
        now: OverviewFixtures.now,
        metaLine: OverviewFixtures.now.metaLine(in: OverviewFixtures.camp),
        onTakeAttendance: {}
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

/// The two ends of the card: a block nobody is on, with no end to count down to and nothing after
/// it, and one carrying everything 4a draws.
#Preview("On now — bare and full") {
    VStack(spacing: OverviewTheme.cardGap) {
        RunningBlockCard(now: OverviewFixtures.bareNow, onTakeAttendance: {})
        RunningBlockCard(
            now: OverviewFixtures.now,
            metaLine: OverviewFixtures.now.metaLine(in: OverviewFixtures.camp),
            onTakeAttendance: {}
        )
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

#Preview("On now — accessibility1") {
    RunningBlockCard(
        now: OverviewFixtures.now,
        metaLine: OverviewFixtures.now.metaLine(in: OverviewFixtures.camp),
        onTakeAttendance: {}
    )
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
    .environment(\.dynamicTypeSize, .accessibility1)
}
