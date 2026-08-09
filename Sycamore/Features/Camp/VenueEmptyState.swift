//
//  VenueEmptyState.swift
//  Sycamore
//
//  `8b` with no venues in it — the state the design actually draws for "Shape the camp", and the
//  one the app had no equivalent of.
//
//  `design/Sycamore 3a System.dc.html` carries this frame twice, byte for byte: once as `9a`
//  ("No venues yet — Says what a venue is, then asks for one") and once as `8b` itself, labelled
//  `Shape the camp — empty`. The populated screen beside it is `9b`, captioned "As built: name,
//  sport, venue rows, camp-wide rates" — so the drawing is not asking for the answered screen to
//  go, it is asking for the state in front of it that was missing.
//
//  Three things, in the design's order:
//
//  1. A dashed plate — a map pin on a tinted tile, "No venues yet", one sentence saying what a
//     venue *is*, and the one thing to do about it.
//  2. A card headed "What a venue holds", listing the three things that hang off a venue. It is
//     the same shape as `8c`'s "what a good file looks like" (`FileExampleCard`): teach the
//     concept where somebody is being asked to supply one, rather than after they get it wrong.
//  3. A footnote that argues against the app's old default — *"One venue is enough to start. Add
//     the second the day you need it."* `CampShape.initial()` opened this screen with two.
//
//  Deliberately not `ContentUnavailableView`, for the reason `ScheduleEmptyDayHero:8-11` and
//  `GroupsLockedState:76-83` each give for their own: nothing is unavailable here, and the design
//  answers the absence with a headline, a sentence and a call to action rather than with a shrug.
//  This is the app's fourth hand-drawn empty state and it is composed of the same parts as the
//  other three — a 52pt mark, a serif line, capped copy, a 50pt button — at this frame's padding.
//
//  Deliberately not `AccentDisc` either, which is the mark those three share. That draws a
//  `Circle`; `8b` draws `border-radius:17px` on a 52pt square, which is `IntakeIconTile` — the
//  plate every other tile on this screen is already drawn with.
//

import SwiftUI

/// - Parameters:
///   - courtNoun: "court", "field", "lane". The design writes "courts" because it draws a tennis
///     camp; this screen has renamed the noun in its header since it was written and a swim camp
///     reading "Its courts" would be the one line on the screen that had not.
///   - onCreate: makes the first venue. See `CreateCampView.createFirstVenue` for what that is and
///     what it deliberately does not also do.
struct VenueEmptyState: View {

    let courtNoun: String
    let onCreate: () -> Void

    /// The design's fixed glyph, grown with the reader's type: it sits beside a line of copy that
    /// is half again as tall at the app's `.accessibility1` cap, and a pinned 16 would read as a
    /// bullet next to it. `IntakeIconTile` scales the plate above on the same ramp.
    @ScaledMetric(relativeTo: .body) private var rowGlyph = OnboardingMetrics.holdsRowGlyph
    /// The column the glyph is centred in, on the same ramp as the glyph so the three rows keep
    /// one left edge at every type size. See `OnboardingMetrics.holdsRowSlot`.
    @ScaledMetric(relativeTo: .body) private var rowSlot = OnboardingMetrics.holdsRowSlot
    /// The cap on the paragraph inside the plate, scaled for the same reason `8f` scales its own
    /// (`ScheduleEmptyDayHero:35`) — a fixed 272 forces five words to the line at the cap.
    @ScaledMetric(relativeTo: .body) private var copyWidth = OnboardingMetrics.emptyCopyWidth
    @ScaledMetric(relativeTo: .body) private var ctaHeight = OnboardingMetrics.emptyCtaHeight

    var body: some View {
        VStack(spacing: OnboardingMetrics.emptyStateGap) {
            noVenuesYet
            whatAVenueHolds
            footnote
        }
    }

    // MARK: No venues yet

    /// `background:#fff;border:1.5px dashed #C3DFCF;border-radius:18px`.
    ///
    /// Hand-drawn rather than `Card`, which strokes a solid border. Three screens in this section
    /// already dash their own plate the same way — `CampPickerView:408-413`,
    /// `BringInTheWeekView:218-223`, `RunningOrJoiningView:135-140` — down to the dash pattern,
    /// which is CSS's 1.5px dash read at roughly three times its width per dash and gap.
    private var noVenuesYet: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.cardLarge, style: .continuous)

        return VStack(spacing: 0) {
            // `ph-map-pin` at 24 on a 52pt `accentSurface` tile. `mappin.and.ellipse` rather than
            // the bare `mappin`, which is a pushpin: the design's glyph is the teardrop that means
            // *a place on a map*, and a place is what this screen is asking for.
            IntakeIconTile(
                "mappin.and.ellipse",
                size: OnboardingMetrics.emptyMark,
                glyphSize: OnboardingMetrics.emptyMarkGlyph,
                radius: OnboardingMetrics.emptyMarkRadius,
                fill: Theme.accentSurface,
                border: Theme.accentSurfaceBorder,
                glyphColor: Theme.accent
            )

            IntakeTitle("No venues yet", style: .intakeEmptyHeading)
                .multilineTextAlignment(.center)
                .padding(.top, OnboardingMetrics.emptyTitleGap)

            // `400 13.5/1.6`, which is `TypeStyle.emptyBody` — reached directly rather than through
            // an `intakeEmptyBody` alias. `ScheduleType.emptyCopy`, `GroupsType.lockedBody` and
            // `InboxType.allClearBody` alias the same row because each names a different local role;
            // this one *is* the paragraph inside an empty-state card, which is what the shared row
            // is already called. A second name for it would be a synonym, not a role.
            Text("A venue is one place you run the camp and the \(courtNoun)s inside it. Kids, coaches and the schedule all hang off it.")
                .typeStyle(.emptyBody, color: Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: copyWidth)
                .padding(.top, OnboardingMetrics.emptyBodyGap)

            // `PrimaryButton` sizes its leading glyph from the label — 21pt here against the
            // design's 17 — which is the trade `ScheduleEmptyDayHero:77-84` and
            // `GroupsLockedState:123-130` already made for their own empty-state buttons. Matching
            // the three of them beats matching one number, and the alternative is a `glyphSize` on
            // a shared control for the sake of four points.
            PrimaryButton(
                "Create your first venue",
                systemImage: "plus",
                height: ctaHeight,
                radius: Radius.input,
                font: .intakeButton,
                action: onCreate
            )
            .padding(.top, OnboardingMetrics.emptyCtaGap)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, OnboardingMetrics.emptyPaddingHorizontal)
        .padding(.top, OnboardingMetrics.emptyPaddingTop)
        .padding(.bottom, OnboardingMetrics.emptyPaddingBottom)
        .background(Theme.surface, in: shape)
        .overlay {
            shape.strokeBorder(
                Theme.accentBorder,
                style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
            )
        }
    }

    // MARK: What a venue holds

    /// The heading is inside the card here, which is the one place on this screen it is: every
    /// other block on `8b` sets its overline above the plate, and this one sets it at
    /// `padding:13px 14px 0` within it.
    ///
    /// `isDivided: false` with an inner `DividedStack` rather than the card's own, because the
    /// design rules *between the three rows* and not under the heading — and a `Card` that
    /// divides puts a rule between every adjacent pair, heading included.
    private var whatAVenueHolds: some View {
        Card(radius: OnboardingMetrics.cardRadius, isDivided: false) {
            VStack(alignment: .leading, spacing: 0) {
                IntakeSectionHeader(
                    "What a venue holds",
                    horizontalPadding: OnboardingMetrics.holdsRowInset,
                    bottomPadding: 0
                )
                .padding(.top, OnboardingMetrics.holdsHeaderTop)

                DividedStack {
                    // `ph-tennis-ball` in the design, which draws a tennis camp. `square.split.2x2`
                    // is the glyph this app already spends on courts — `OverviewScreen:321` puts it
                    // on "No courts yet" — and it is the one of the two that still means something
                    // when the sport is swimming.
                    row("square.split.2x2", "Its \(courtNoun)s — six at Northside, four at LATC")
                    row("person.3", "How many kids and coaches a \(courtNoun) takes")
                    row("calendar", "The day's blocks and who is on which \(courtNoun)")
                }
            }
        }
    }

    /// `padding:11px 14px` with a `gap:11px`, a `#A2A6AE` glyph and `#3F4A44` copy.
    ///
    /// `.intakeChecklist` is the style: 13.5 in warm ink inside a card, which is the role `8c`'s
    /// "what a file needs" rows carry (`FileExampleCard:75`) and this is the same list under a
    /// different heading. The design declares no line height on these because it draws them one
    /// line long; they wrap at large type, and the checklist's 1.55 is what they should wrap at.
    private func row(_ symbol: String, _ text: String) -> some View {
        CardRow(
            spacing: Spacing.row,
            horizontalPadding: OnboardingMetrics.holdsRowInset,
            verticalPadding: Spacing.row,
            alignment: .top
        ) {
            Image(systemName: symbol)
                .font(.system(size: rowGlyph, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: rowSlot)
                // Sits on the first line's cap height rather than centred on a wrapped pair, the
                // way `FileExampleCard:71` sets its own.
                .padding(.top, 1)
                // Decorative: each row says in words what its glyph draws.
                .accessibilityHidden(true)

            Text(text)
                .typeStyle(.intakeChecklist, color: Theme.inkWarm)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: The footnote

    /// `400 12.5/1.55 #A2A6AE`, centred, `padding:6px 20px 0`.
    ///
    /// The sentence that decided what this screen opens on. Two venues were seeded here for as
    /// long as there was no drawing of the alternative; the drawing says one is enough, so the
    /// line is both the copy and the reason `CampShape.empty` exists.
    private var footnote: some View {
        Text("One venue is enough to start. Add the second the day you need it.")
            .typeStyle(.intakeNote, color: Theme.inkFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, OnboardingMetrics.emptyPaddingHorizontal)
            .padding(.top, Spacing.tight)
    }
}

// MARK: - Previews

#Preview("8b No venues yet") {
    ScrollView {
        VenueEmptyState(courtNoun: "court", onCreate: {})
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
}

/// The app caps Dynamic Type at `.accessibility1`. The plate's paragraph should still be a
/// paragraph, the three glyphs should still be sitting on the first line of their rows, and all
/// three rows should still share one left edge — that last one is what `holdsRowSlot` buys.
///
/// The noun is a swim camp's, which is the case the design's own copy does not cover.
#Preview("8b No venues yet — large type") {
    ScrollView {
        VenueEmptyState(courtNoun: "lane", onCreate: {})
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
    .dynamicTypeSize(.accessibility1)
}

/// The dashed accent border and the tinted plate are the two things here that are drawn in the
/// accent family rather than in ink, so they are the two worth looking at in the dark.
#Preview("8b No venues yet — dark") {
    ScrollView {
        VenueEmptyState(courtNoun: "court", onCreate: {})
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
    .preferredColorScheme(.dark)
}
