//
//  ScheduleEmptyDayHero.swift
//  Sycamore
//
//  The card `8f` gives a day with nothing in it: the mark held back to a watermark, the day
//  named, one sentence saying what a block is for, and the one thing to do about it.
//
//  Deliberately not `ContentUnavailableView`. That is the right shape for an absence nobody can
//  do anything about — Schedule uses it when the camp has no venue to schedule against — but an
//  empty Tuesday is not an absence, it is a day waiting to be written, and the design answers it
//  with a headline, a sentence and a call to action rather than with a shrug.
//

import SwiftUI

struct ScheduleEmptyDayHero: View {

    let day: Weekday
    let onAdd: () -> Void

    @ScaledMetric(relativeTo: .title) private var markSize = ScheduleMetrics.emptyMark
    @ScaledMetric(relativeTo: .body) private var copyWidth = ScheduleMetrics.emptyCopyWidth
    @ScaledMetric(relativeTo: .body) private var ctaHeight = ScheduleMetrics.emptyCtaHeight

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                SycamoreMark(variant: .ringed)
                    .frame(width: markSize, height: markSize)
                    .opacity(0.18)
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
