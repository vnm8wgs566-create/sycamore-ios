//
//  ScheduleEmptyDayHero.swift
//  Sycamore
//
//  The card `8f` gives a day with nothing in it: a glyph in a tinted disc, the day named, one
//  sentence saying what a block is for, and the one thing to do about it.
//
//  Deliberately not `ContentUnavailableView`. That is the right shape for an absence nobody can
//  do anything about — Schedule uses it when the camp has no venue to schedule against — but an
//  empty Tuesday is not an absence, it is a day waiting to be written, and the design answers it
//  with a headline, a sentence and a call to action rather than with a shrug.
//
//  Deliberately not the company mark either, which is what stood here until now — bare, no disc
//  under it, ghosted to `.18`. Three things were wrong with it at once. It named nothing: every
//  other empty state in the app names the thing that is missing — `person.2.slash` for no
//  groups, `square.split.2x2` for no courts, `figure.tennis` for no kids, `tray` for a filtered
//  inbox — and a logo says nothing about a Tuesday with no blocks on it. It was the only
//  empty-state icon in the app drawn below full opacity. And it was the only green thing on the
//  screen, `markGreen` being a brand colour rather than an interface one. `CampPickerView`'s
//  `noCamps` is the one place the mark legitimately *is* the empty-state icon, and the argument
//  it carries there — a seed that has not taken root yet — does not transfer to Tuesday.
//

import SwiftUI

struct ScheduleEmptyDayHero: View {

    let day: Weekday
    let onAdd: () -> Void

    /// Disc and glyph grow together, off the one text style, so the glyph keeps its place inside
    /// the ring rather than rattling around in it. Both scale rather than sitting at their drawn
    /// sizes because a flat 52pt disc above copy set at `.accessibility1` reads as a bullet
    /// rather than as the subject of the card.
    @ScaledMetric(relativeTo: .title) private var markSize = ScheduleMetrics.emptyMark
    @ScaledMetric(relativeTo: .title) private var markGlyph = ScheduleMetrics.emptyMarkGlyph
    @ScaledMetric(relativeTo: .body) private var copyWidth = ScheduleMetrics.emptyCopyWidth
    @ScaledMetric(relativeTo: .body) private var ctaHeight = ScheduleMetrics.emptyCtaHeight

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                // `calendar.day.timeline.left` over the two obvious alternatives. `ScheduleView`
                // already spends `calendar.badge.exclamationmark` on the no-venue state twenty
                // lines away, and `calendar.badge.plus` is the same silhouette — a calendar with
                // a corner badge — so the two states would trade one glyph for a glyph that
                // looks like it, and the plus is on the button below in any case. The timeline
                // variant draws the thing that is missing: a day ruled into blocks beside the
                // time gutter `8k` runs down its left. It also wears no badge, which is what the
                // shapes card under it does too — `sunrise`, `clock` and `trophy` are all whole
                // objects. `.left` rather than the mirroring `.leading`, to match the fixed
                // `chevron.right` the design system draws everywhere; both are the swap to make
                // the day the app ships a right-to-left locale.
                //
                // The treatment is the one `InboxAllClearCard` and `GroupsLockedState` draw: a
                // full-opacity accent glyph on an `accentSurface` disc with a hairline ring.
                // Those two and this one are the app's three hand-drawn empty states, and with
                // this they finally read as one composition rather than as three.
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: markGlyph, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .frame(width: markSize, height: markSize)
                    .background(Theme.accentSurface, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Theme.accentSurfaceBorder, lineWidth: BorderWidth.hairline)
                    }
                    .accessibilityHidden(true)

                Text("\(day.fullName) is empty.")
                    .typeStyle(ScheduleType.emptyHeading, color: Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, ScheduleMetrics.emptyTitleGap)
                    .accessibilityAddTraits(.isHeader)

                Text("Blocks are how the day gets its shape — one per activity, with who runs it.")
                    .typeStyle(ScheduleType.emptyCopy, color: Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    // The design caps the sentence well short of the card so it stays a
                    // paragraph rather than a banner. The cap scales with the type in it, or it
                    // would force five words a line at `.accessibility1`.
                    .frame(maxWidth: copyWidth)
                    .padding(.top, ScheduleMetrics.blockGap)

                PrimaryButton(
                    "Add the first block",
                    systemImage: "plus",
                    height: ctaHeight,
                    radius: Radius.input,
                    font: ScheduleType.emptyCta,
                    action: onAdd
                )
                .padding(.top, ScheduleMetrics.emptyCtaGap)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ScheduleMetrics.emptyPaddingHorizontal)
            .padding(.vertical, ScheduleMetrics.emptyPaddingVertical)
        }
    }
}

// MARK: - Previews

#Preview("Empty day") {
    ScheduleEmptyDayHero(day: .fri, onAdd: {})
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}

/// The app caps Dynamic Type at `.accessibility1`, which is the setting the two `@ScaledMetric`s
/// above are there for: at the cap the disc and its glyph should still be reading as the subject
/// of the card rather than as a bullet above it.
#Preview("Empty day — large type") {
    ScheduleEmptyDayHero(day: .fri, onAdd: {})
        .dynamicTypeSize(.accessibility1)
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}
