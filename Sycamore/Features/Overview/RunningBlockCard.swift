//
//  RunningBlockCard.swift
//  Sycamore
//
//  What is happening at the venue right now: the block's name and hours, who is running it, what
//  it says to do, and everything written against it.
//
//  Not in the design, and it is the card the design's own header line implies. `8i` heads the
//  screen "Skills rotation · until 10:30" and then draws four court cards, only one of which is
//  about the skills rotation — the line names a thing the screen has nowhere to put. This is that
//  place: one card, above the courts, for the block the whole venue is inside.
//
//  ── Why the title is here *and* in the header ─────────────────────────────────────────────────
//
//  It reads as duplication and is not. `ScreenHeader` is pinned and the scroll runs under it, so
//  the line up there is what still answers "what is on now" after a reader has scrolled past this
//  card to find their child's court. The card is where the block's *contents* live, and a card
//  whose first line is a time with no subject is unreadable to VoiceOver and nearly as bad to the
//  eye. Both, therefore — and both composed by `OverviewNow` so they cannot word it differently.
//
//  ── Deliberately not accent-bordered ─────────────────────────────────────────────────────────
//
//  `OverviewCourtCard` spends the accent border and `OverviewTheme.yourCourtLift` on exactly one
//  card: the court you are standing on. That is the design's one use of the treatment and it means
//  "yours". A second accent-bordered card immediately above it would make the border mean "yours,
//  or else important", which is to say nothing. The overline carries the emphasis instead, which is
//  the same job `8j` gives "YOUR COURT".
//

import SwiftUI

struct RunningBlockCard: View {

    let now: OverviewNow
    /// Opens a coach's staff card. Required rather than optional: every pill this card draws with a
    /// name on it has somewhere to go, so an optional bought one `{ _ in }` in a preview and cost a
    /// nil branch per pill on every pass.
    let onOpenCoach: (StaffMember.ID) -> Void

    /// 13 sits in the callout band, alongside the marks at the end of a roster line.
    @ScaledMetric(relativeTo: .callout) private var noteGlyph = OverviewTheme.noteGlyph

    var body: some View {
        Card(radius: OverviewTheme.cardRadius, isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                heading

                rule
                coaches

                if !now.notes.isEmpty {
                    rule
                    notes
                }
            }
            .padding(OverviewTheme.cardPadding)
        }
    }

    // MARK: What it is

    /// The overline, the hours, the block's name and its instruction.
    ///
    /// Three drawn runs of text, two accessibility elements, and the split is deliberate. "On now,
    /// until 10:30, Skills rotation" is one phrase and is what the card *is*, so it combines and
    /// takes the heading trait — a reader working the rotor lands on it and knows where they are.
    /// The instruction stays its own element: it is a paragraph, and a heading a reader has to sit
    /// through twenty words of is a heading that has stopped being a landmark.
    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: OverviewTheme.headerGap) {
                    Text("On now")
                        .typeStyle(OverviewTheme.overline, color: Theme.accent)

                    Spacer(minLength: 0)

                    Text(now.timeLabel)
                        .typeStyle(.metaSmall, color: Theme.inkMuted)
                        .lineLimit(1)
                }
                .padding(.bottom, OverviewTheme.overlineGap)

                // Allowed to wrap. A block's name is the subject of the card, and "Skills rotation
                // and serve ladder" truncated to "Skills rotation and…" is the half that says least.
                Text(now.title)
                    .typeStyle(OverviewTheme.cardTitle, color: Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let instruction = now.instruction {
                Text(instruction)
                    .typeStyle(OverviewTheme.cardNote, color: Theme.inkWarm)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, OverviewTheme.titleGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Who is on it

    /// The block's own coaches, wrapped.
    ///
    /// `FlowLayout` rather than an `HStack`: a block can name three people, and three pills on one
    /// line at `.accessibility1` would each be squeezed to a disc and an ellipsis. It is the layout
    /// the design already wraps court chips and time pills with.
    ///
    /// **The pill is inert when nobody is on the block, and that is deliberate.** A court card's
    /// empty pill is now a `+` that writes `coaches.group_id` — who has the court. Who runs a
    /// *block* is `schedule_block_coaches`, a different column with a different meaning and an
    /// editor of its own on Schedule. A `+` here that opened the block editor would make Overview
    /// a second place to compose a block; a `+` here that wrote the court's coach would answer a
    /// question nobody asked. So this one says what is true and points nowhere.
    private var coaches: some View {
        // `FlowLayout`'s own 7pt either way, which is the gap the design wraps every other row of
        // pills at. Spelling it out here would be a second copy of a default that already agrees.
        FlowLayout {
            if now.coaches.isEmpty {
                CoachPill(name: nil)
            } else {
                ForEach(now.coaches) { coach in
                    CoachPill(name: coach.name) { onOpenCoach(coach.id) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: What is written against it

    /// Every note on the block, in the order it carries them.
    ///
    /// Wrapped rather than clipped, which is the opposite of `PinnedNoteBanner` one card up and for
    /// the reason that banner gives: it is "a reminder of something already written down" and ends
    /// in a way through to the whole thing. There is no way through from here — this *is* the whole
    /// thing — so a note cut off at one line would simply be a note nobody can read.
    private var notes: some View {
        VStack(alignment: .leading, spacing: OverviewTheme.noteStackGap) {
            ForEach(now.notes) { note in
                HStack(alignment: .firstTextBaseline, spacing: OverviewTheme.noteGap) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: noteGlyph, weight: .regular))
                        .foregroundStyle(Theme.glyph)
                        .accessibilityHidden(true)

                    Text(note.text)
                        .typeStyle(OverviewTheme.cardNote, color: Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Note. \(note.text)")
            }
        }
    }

    private var rule: some View {
        Hairline(color: Theme.hairlineSoft)
            .padding(.vertical, OverviewTheme.ruleGap)
    }
}

// MARK: - Previews

#Preview("On now — the design's block") {
    RunningBlockCard(now: OverviewFixtures.now, onOpenCoach: { _ in })
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}

/// The two ends of the card: a block nobody is on and nothing is written against, and one carrying
/// everything it can carry.
#Preview("On now — bare and full") {
    VStack(spacing: OverviewTheme.cardGap) {
        RunningBlockCard(now: OverviewFixtures.bareNow, onOpenCoach: { _ in })
        RunningBlockCard(now: OverviewFixtures.now, onOpenCoach: { _ in })
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

#Preview("On now — accessibility1") {
    RunningBlockCard(now: OverviewFixtures.now, onOpenCoach: { _ in })
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .environment(\.dynamicTypeSize, .accessibility1)
}
