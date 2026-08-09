//
//  OverviewEmptyDayHero.swift
//  Sycamore
//
//  What Overview says on a day nobody has scheduled: a mark, the day named, one sentence about
//  what a block would buy this screen, and the one thing to do about it.
//
//  Until now the screen said nothing at all. With no blocks the header quietly fell back to
//  "Sycamore · 4 courts" (`OverviewView.venueLine`) and the courts drew as usual, so a venue whose
//  morning had never been written looked exactly like a venue between blocks — and every part of
//  this tab that depends on the schedule simply did not appear, with no hint that it could.
//
//  Deliberately not `ContentUnavailableView`, and `ScheduleEmptyDayHero.swift:8-11` is the argument
//  in full: that shape is right for an absence nobody can do anything about, and "an empty Tuesday
//  is not an absence, it is a day waiting to be written". The `courts.isEmpty` state on this same
//  screen keeps its `ContentUnavailableView` because it is genuinely the other kind — the fix for
//  it is in camp settings, on another screen, behind an admin.
//
//  Its own view rather than `ScheduleEmptyDayHero` reused, and only because of the copy: Schedule's
//  reads "Friday is empty", which on this tab would be a claim about a venue with four courts and
//  forty kids on them. The day is not empty here. Its schedule is.
//
//  **Which is an argument for three parameters, not for a second view, and this file knows it.**
//  The shape below is that card's line for line and its numbers are the same eight — see
//  `OverviewTheme`'s "A day with no blocks on it", which carries the full note. Parameterising
//  `ScheduleEmptyDayHero` on its three strings, or lifting the pair beside `AccentDisc` the way
//  that mark was already lifted out of three transcriptions, is the right end state; both live in
//  folders this unit does not own while section 8 is being built by several hands at once. Until
//  one of them happens, a change to this frame has to land in two files.
//

import SwiftUI

struct OverviewEmptyDayHero: View {

    let day: Weekday
    let onAdd: () -> Void

    @ScaledMetric(relativeTo: .body) private var copyWidth = OverviewTheme.emptyCopyWidth
    @ScaledMetric(relativeTo: .body) private var ctaHeight = OverviewTheme.emptyCtaHeight

    var body: some View {
        Card(radius: OverviewTheme.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                // The same mark Schedule's empty day wears, and for the reason it records: the
                // timeline variant draws the thing that is missing, a day ruled into blocks. Two
                // screens naming one absence should name it with one glyph — a reader who meets
                // this on Overview and then opens Schedule has met it before.
                AccentDisc(
                    "calendar.day.timeline.left",
                    size: OverviewTheme.emptyMark,
                    glyph: OverviewTheme.emptyMarkGlyph
                )

                Text("No blocks on \(day.fullName).")
                    .typeStyle(OverviewTheme.emptyHeading, color: Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, OverviewTheme.emptyTitleGap)
                    .accessibilityAddTraits(.isHeader)

                Text("This screen follows the day's blocks — add one and it shows who is on it, what it says, and the notes against it.")
                    .typeStyle(OverviewTheme.emptyCopy, color: Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    // Capped well short of the card so the sentence stays a paragraph rather than a
                    // banner, and the cap scales with the type in it or it forces four words a line
                    // at the size the app caps Dynamic Type to.
                    .frame(maxWidth: copyWidth)
                    .padding(.top, OverviewTheme.emptyCopyGap)

                // Not gated on `store.isAdmin`, which is the position `ScheduleView.addBlockRow`
                // already argues for the four other entrances to this composer: RLS on
                // `schedule_blocks` is the gate that decides, and a lock on one door standing beside
                // four open ones is decoration.
                PrimaryButton(
                    "Add a block",
                    systemImage: "plus",
                    height: ctaHeight,
                    radius: Radius.input,
                    font: OverviewTheme.emptyCta,
                    action: onAdd
                )
                .padding(.top, OverviewTheme.emptyCtaGap)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, OverviewTheme.emptyPaddingHorizontal)
            .padding(.vertical, OverviewTheme.emptyPaddingVertical)
        }
    }
}

// MARK: - Previews

#Preview("Overview — no blocks") {
    OverviewEmptyDayHero(day: .wed, onAdd: {})
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}

/// The app caps Dynamic Type at `.accessibility1`. At the cap the disc should still read as the
/// subject of the card rather than as a bullet above it, and the sentence as a paragraph.
#Preview("Overview — no blocks · large type") {
    OverviewEmptyDayHero(day: .wed, onAdd: {})
        .dynamicTypeSize(.accessibility1)
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}

#Preview("Overview — no blocks · dark") {
    OverviewEmptyDayHero(day: .wed, onAdd: {})
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .preferredColorScheme(.dark)
}
