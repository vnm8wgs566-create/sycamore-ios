//
//  PlusDisc.swift
//  Sycamore
//
//  A circle with a `+` in it, drawn where something is missing.
//
//  `8i` uses this shape twice on one card header, at two sizes and with two borders:
//
//      the spare places on a court   18pt, `#fff` fill, solid `#E4EDE7` ring, an 11pt mark
//      the coach nobody has yet      26pt, `#F6FAF7` fill, dashed `#C3DFCF` ring, a 13pt mark
//
//  Written once because it was written twice, three lines apart, and the copies had already begun
//  to diverge — one centred its glyph in a second `.overlay`, the other in the same one as its
//  ring. Neither is wrong and that is the problem: the two are meant to read as one vocabulary
//  (a dashed or ringed circle is how this screen draws a space with nothing in it yet), and a
//  vocabulary maintained in two places is two vocabularies waiting to happen.
//
//  Deliberately not a tone on `InitialsAvatar`. That component's job is a *person* — its API is
//  initials and its `AvatarTone` cases are named for who somebody is (`neutral`, `dark`, `tinted`).
//  A disc that means "nobody" is the absence of that, and folding it in would put a case on a
//  shared enum that the two screens outside this folder using `InitialsAvatar` can never draw.
//
//  The caller owns the sizes. Both are `@ScaledMetric` at their call sites, on the ramp their own
//  label rides, which is a fact about the row the disc sits in rather than about the disc — see
//  `CourtCoachLine` (`.footnote`, with the initials it replaces) against `CourtCapacityBadge`
//  (`.caption`, with the 11pt count beside it).
//

import SwiftUI

struct PlusDisc: View {

    /// The disc's diameter, already scaled for Dynamic Type by the caller.
    let size: CGFloat
    /// The mark inside it, likewise.
    let glyphSize: CGFloat
    var fill: Color = Theme.accentSurface
    var border: Color = Theme.accentBorder
    /// Dashed for a slot that can be filled in, solid for one that is only being counted.
    var isDashed: Bool = true

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Circle().strokeBorder(border, style: stroke)
            }
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            // Never a label of its own. Both callers wrap it in a row that says in words what the
            // `+` means — "Add a coach", "2 spots" — and a disc that announced itself as well
            // would make every one of those two stops instead of one.
            .accessibilityHidden(true)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(
            lineWidth: BorderWidth.hairline, dash: isDashed ? OverviewTheme.dash : []
        )
    }
}

// MARK: - Previews

#Preview("Plus discs") {
    HStack(spacing: Spacing.medium) {
        // The one 4a still draws — the empty coach slot under a court's title. The 18pt white disc
        // that used to sit inside the "2 spots" pill went with the pill's `+`; see
        // `CourtCapacityBadge`'s header. The solid-ring variant is drawn here all the same, because
        // it is the half of this component the remaining caller does not exercise.
        PlusDisc(
            size: OverviewTheme.courtCoachAvatar,
            glyphSize: OverviewTheme.addCoachGlyph
        )
        PlusDisc(
            size: OverviewTheme.courtCoachAvatar,
            glyphSize: OverviewTheme.addCoachGlyph,
            fill: Theme.surface,
            border: Theme.accentSurfaceBorder,
            isDashed: false
        )
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
