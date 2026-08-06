//
//  OnTheDayTitle.swift
//  Sycamore
//
//  The serif line at the top of a section-8 screen.
//
//  `8m` sets its title `font: 400 30px/1.05 Newsreader, Georgia, serif` with
//  `letter-spacing:-.022em`. `.tabTitle` is the nearest existing style and agrees on the family,
//  the weight and the fit, but it is drawn at 28/1.02 — two points short, and set a little
//  tighter down the line than a heading with this much air wants.
//
//  It is no longer only `8m`'s: `8l` opens with the same heading, so `ScheduleType.blockHeading`
//  takes this style rather than restating it. Four of section 8's screens now draw from it, which
//  is what would earn it a place in `Typography.swift` beside `.tabTitle`.
//

import SwiftUI

extension TypeStyle {

    /// `400 30/1.05 Newsreader`, `-.022em` — `8m`'s "Attendance".
    ///
    /// The tracking is not carried over from the sans styles; it is what `8m.html` itself sets.
    /// Every Newsreader declaration in section 8 is tracked in — `-.022em` at 30–33px, `-.02em`
    /// at 24–26, `-.025em` at 40 — so the negative fit is the design's reading of this face
    /// rather than a sans-serif optical correction that followed it here.
    static let onTheDayTitle = TypeStyle(
        size: OnTheDayTokens.titleSize,
        weight: .regular,
        trackingEm: OnTheDayTokens.titleTrackingEm,
        lineHeightMultiple: OnTheDayTokens.titleLineHeight,
        isSerif: true
    )
}

/// The title itself, so a screen writes the heading trait once rather than at each call site.
struct OnTheDayTitle: View {

    let text: String
    var color: Color = Theme.ink

    init(_ text: String, color: Color = Theme.ink) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .typeStyle(.onTheDayTitle, color: color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Previews

#Preview("Screen title") {
    VStack(alignment: .leading, spacing: Spacing.large) {
        Text(FontFamily.serifFace ?? "Platform serif — Newsreader is not registered")
            .typeStyle(.onTheDayOverline, color: Theme.inkMuted)

        OnTheDayTitle("Attendance")
        OnTheDayTitle("Leaving early")
        OnTheDayTitle("Austin Zheng")

        Text("`.tabTitle`, for the comparison")
            .typeStyle(.onTheDayOverline, color: Theme.inkMuted)
        Text("Attendance")
            .typeStyle(.tabTitle, color: Theme.ink)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(Spacing.header)
    .background(Theme.surface)
}
