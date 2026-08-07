//
//  GenderMark.swift
//  Sycamore
//
//  The gender glyph the design asks for, drawn rather than borrowed.
//
//  The design sets Phosphor's `ph-gender-female` / `ph-gender-male` beside a kid's name in four
//  places — `8a`'s roster line, `8d`'s import list, `8h`'s group row and `8q`'s lede. The app
//  drew a letter at all four instead, and three separate comments explained why: SF Symbols has
//  no gender set, and the nearest candidates encode the distinction as a dress. `figure.stand.dress`
//  was in the codebase, it collapsed `.x` onto the male figure, and it was removed.
//
//  Both of those are still true. What has changed is the conclusion: a letter is a poor mark
//  (`X` beside a name reads as a redaction, not an answer) and Phosphor's set has only two marks
//  in it anyway, so importing it would have left `.x` in exactly the hole `figure.stand.dress`
//  put it in. Drawing the marks is the only route that gives the third answer a glyph of its own,
//  which is the thing every previous attempt failed on.
//
//  `SycamoreMark` is the pattern: fixed 200×200 canvas, everything derived from one `size`, the
//  curves scaled rather than re-authored. Two marks are the classical planetary symbols — Venus
//  for `.f`, Mars for `.m`. The third is argued for at `GenderOutline` below.
//

import SwiftUI

// MARK: - The canvas

/// The one place the three marks agree, so they read as a family rather than three drawings.
///
/// Measured off the 200-unit canvas `SycamoreMark` uses, and every number here is shared by at
/// least two of the marks — a mark that wanted its own stroke weight would stop looking like a
/// sibling of the other two at 13pt, which is the only size that matters.
///
/// One more thing all three agree on, which is a property of the drawings rather than a number
/// anything reads: every mark's ink is centred on `(100, 100)` — Venus spans `y 10…190` on a
/// stem, Mars spans `10…190` on its diagonal, the sun `28…172` on its ring. An `HStack` therefore
/// centres them on each other and on the SF Symbols beside them without anybody nudging a
/// baseline, and a mark redrawn later has one rule to keep.
private enum GenderCanvas {
    /// The design canvas. Scaling from it rather than hard-coding points keeps the marks
    /// identical at 13pt in a roster row and at 96pt in a preview.
    static let side: CGFloat = 200

    /// `10%` of the canvas — 1.3pt at the 13pt these are drawn at, which is where SF Symbols'
    /// `.regular` weight sits at the same size. The clock and the away glyph in the same HStack
    /// are SF Symbols, and a mark a hair heavier or lighter than its neighbours is the one thing
    /// a reader notices about it.
    static let stroke: CGFloat = 20

    /// Venus's and Mars's ring, on its centre line. Shared exactly: the ring is what makes the
    /// pair a pair, and the stems are what tell them apart.
    static let ring: CGFloat = 48
}

// MARK: - Geometry

/// The stroked line of each mark: a ring, plus whatever leaves it.
///
/// **Venus** (`.f`) and **Mars** (`.m`) are drawn as they have been since the 18th century — a
/// ring with a cross hung below it, a ring with an arrow leaving at 45°. Nothing to argue about;
/// they are what the design's Phosphor icons are, at the weight the rest of this row is drawn at.
///
/// **The Sun** (`.x`) is the decision. The two obvious candidates for a third mark are the
/// genderqueer and agender glyphs, and both are *built out of the other two* — a Venus cross and
/// a Mars arrow on one ring, or the pair struck through. At 13pt in grey that reads as "both of
/// them at once", which is the same failure `figure.stand.dress` had, only inverted: the third
/// answer described in terms of the first two rather than collapsed onto one of them.
///
/// So the third mark leaves that family and stays in the one Venus and Mars actually come from.
/// They are planetary symbols; `☉` is the third glyph of the same set, and it is the only one
/// whose distinguishing feature sits *inside* the ring rather than as a stem pointing out of it.
/// It cannot be mistaken for either mark, because what tells those two apart is the stem and this
/// has none. And it deliberately is not a bare ring: an empty circle is the universal glyph for
/// "nothing here", which is precisely the reading `Gender.label` decided `.x` must not carry.
private struct GenderOutline: Shape {
    let gender: Gender

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / GenderCanvas.side
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        /// A circle on its centre line, which is what a stroke wants — the drawn edges land
        /// half a stroke either side of `radius`.
        func ring(centre: CGPoint, radius: CGFloat) -> CGRect {
            CGRect(x: centre.x - radius * s, y: centre.y - radius * s,
                   width: radius * 2 * s, height: radius * 2 * s)
        }

        var path = Path()
        switch gender {
        case .f:
            // Ring high, cross hung under it. The stem starts on the ring's centre line rather
            // than at its outer edge, so the two strokes merge instead of butting.
            path.addEllipse(in: ring(centre: p(100, 68), radius: GenderCanvas.ring))
            path.move(to: p(100, 116))
            path.addLine(to: p(100, 180))
            // 62% of the way down the stem, which is where the classical mark puts it.
            path.move(to: p(64, 156))
            path.addLine(to: p(136, 156))

        case .m:
            // Ring low, arrow away to the top-right. `(102, 98)` is the ring's centre line at
            // 45° — `68 + 48/√2`, `132 − 48/√2` — so the shaft leaves it cleanly.
            path.addEllipse(in: ring(centre: p(68, 132), radius: GenderCanvas.ring))
            path.move(to: p(102, 98))
            path.addLine(to: p(180, 20))
            // The head is the classical open corner, not a filled triangle: a solid head at
            // 13pt turns into a blob, and the mark then reads darker than Venus beside it.
            path.move(to: p(180, 74))
            path.addLine(to: p(180, 20))
            path.addLine(to: p(126, 20))

        case .x:
            // Drawn at `62` where Venus and Mars ring at `48`. Matching their radius exactly was
            // tried first and left this mark reading a size smaller than either, because their
            // stems carry half of their apparent size and this one has nothing outside the ring
            // to carry any. `62` puts its ink box at 144 against their 180 — still the smallest
            // of the three, which is right for the only closed shape in the set.
            path.addEllipse(in: ring(centre: p(100, 100), radius: 62))
        }
        return path
    }
}

/// The filled part of each mark, which today is only `☉`'s centre. Its own shape rather than part
/// of `GenderOutline` for the same reason `SeedHead` is separate from `SeedWing`: one is stroked
/// and the other is not, and a single path cannot be both.
///
/// It takes the gender and returns an empty path for the two that have no fill, rather than the
/// call site branching on `.x`. An `if` in the body would wrap the whole mark in
/// `_ConditionalContent` and throw away its structural identity every time a row's kid changes;
/// filling an empty path costs nothing and keeps one view.
private struct GenderFill: Shape {
    let gender: Gender

    func path(in rect: CGRect) -> Path {
        guard gender == .x else { return Path() }
        let s = min(rect.width, rect.height) / GenderCanvas.side
        let centre = CGPoint(x: rect.minX + 100 * s, y: rect.minY + 100 * s)
        // `24` leaves 28 units of clear ring between the dot and the stroke — 1.8pt at 13pt,
        // which is the narrowest gap that still reads as a gap rather than as a smudge.
        return Path(ellipseIn: CGRect(
            x: centre.x - 24 * s, y: centre.y - 24 * s,
            width: 48 * s, height: 48 * s
        ))
    }
}

// MARK: - The mark

/// The gender glyph, wherever a screen has room to draw one.
///
/// Sizes itself against Dynamic Type rather than asking the call site to: the letter this replaces
/// was `.metaSmall` and therefore grew with the reader's setting, and a fixed glyph beside growing
/// text drifts out of the line by the second-largest step. Pass `alongside:` the style it stands
/// next to and the mark rides that ramp.
struct GenderMark: View {

    /// Beside a name in a list — `8a`'s roster line, `8h`'s group row, `8d`'s import list.
    ///
    /// The same 13 as `OverviewTheme.rosterGlyph` and `GroupsMetrics.markGlyph`, restated here
    /// rather than reached for: those tokens belong to two features that own their own sizing,
    /// and this mark appears in a third. They agree today because the design draws all the marks
    /// on a row at one size; if a feature ever moves, this should not move with it silently.
    static let rowGlyph: CGFloat = 13

    /// `8q`'s "Girl · 13 years", where the design draws the mark beside a 13.5pt lede. A shade
    /// larger than the type it sits with, which is how Phosphor's own marks are set.
    static let ledeGlyph: CGFloat = 15

    let gender: Gender
    /// `Theme.glyph` (`#B3B7BE`) is the grey the design gives its icons, a step lighter than its
    /// text. `8q` draws its mark at `#A2A6AE` instead, which is `Theme.inkFaint`.
    let tint: Color

    @ScaledMetric private var side: CGFloat

    init(
        _ gender: Gender,
        size: CGFloat = GenderMark.rowGlyph,
        alongside style: TypeStyle = .metaSmall,
        tint: Color = Theme.glyph
    ) {
        self.gender = gender
        self.tint = tint
        // `style.textStyle` rather than a spelled-out ramp, for the reason the type table gives:
        // a hand-written mapping is the one that gets forgotten.
        self._side = ScaledMetric(wrappedValue: size, relativeTo: style.textStyle)
    }

    var body: some View {
        ZStack {
            GenderOutline(gender: gender)
                .stroke(tint, style: StrokeStyle(
                    lineWidth: side * GenderCanvas.stroke / GenderCanvas.side,
                    lineCap: .round,
                    lineJoin: .round
                ))

            GenderFill(gender: gender).fill(tint)
        }
        .frame(width: side, height: side)
        // Not decorative by default. The glyph says nothing a screen reader can infer, and the
        // letter it replaces carried this word at three of its four sites. A screen that already
        // writes the word beside it — `8q` does — hides the mark at the call site instead.
        .accessibilityElement()
        .accessibilityLabel(gender.label)
    }
}

// MARK: - Previews

#Preview("Gender marks") {
    VStack(alignment: .leading, spacing: 28) {
        // The sizes it is actually drawn at, first — everything above 24 is only ever a check.
        ForEach([GenderMark.rowGlyph, GenderMark.ledeGlyph, 24, 48, 96], id: \.self) { size in
            HStack(spacing: 20) {
                Text("\(Int(size))pt")
                    .typeStyle(.metaSmall, color: Theme.inkMuted)
                    .frame(width: 44, alignment: .trailing)
                ForEach(Gender.allCases, id: \.self) { gender in
                    GenderMark(gender, size: size)
                }
            }
        }

        // In the line it has to sit in, against the letter it replaced and the SF Symbol it
        // shares the row with.
        ForEach(Gender.allCases, id: \.self) { gender in
            HStack(spacing: Spacing.tight) {
                Text("Serene Chu")
                    .typeStyle(.metaSmall, color: Theme.inkWarm)
                GenderMark(gender)
                Text(gender.symbol)
                    .typeStyle(.metaSmall, color: Theme.glyph)
                Image(systemName: "clock.fill")
                    .font(.system(size: GenderMark.rowGlyph, weight: .regular))
                    .foregroundStyle(Theme.warning)
            }
        }

        // `8q`'s tint, at `8q`'s size.
        HStack(spacing: 20) {
            ForEach(Gender.allCases, id: \.self) { gender in
                GenderMark(gender, size: GenderMark.ledeGlyph, tint: Theme.inkFaint)
            }
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Theme.surface)
}
