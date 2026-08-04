//
//  SycamoreMark.swift
//  Sycamore
//
//  The app mark, transcribed from `Sycamore Logo v2.dc.html` in the "Sycamore app logo design"
//  project. A sycamore samara — the winged seed that spins as it falls.
//
//  Everything here derives from one shape, `seed2a` in the design: a wing swept up and to the
//  right off a round seed head. The three variants the design draws are the same shape framed
//  three ways, so they are cases of one view rather than three views.
//
//  The design authors on a 200×200 canvas. `SeedWing` and `SeedHead` keep those coordinates
//  and scale to whatever frame they are given, so the curves stay exactly as drawn.
//

import SwiftUI

// MARK: - Geometry

/// The wing. Two stacked sweeps — the outer is the full wing, the inner sits on top of it a
/// shade lighter so the halves read apart even at 24pt.
private struct SeedWing: Shape {
    enum Half { case outer, inner }
    let half: Half

    func path(in rect: CGRect) -> Path {
        // The design's canvas. Scaling here rather than hard-coding points keeps the mark
        // identical at 22pt in a nav bar and at 1024pt in an icon export.
        let s = min(rect.width, rect.height) / 200
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        switch half {
        case .outer:
            path.move(to: p(78, 130))
            path.addQuadCurve(to: p(174, 30), control: p(82, 54))
            path.addQuadCurve(to: p(94, 134), control: p(162, 106))
        case .inner:
            path.move(to: p(86, 120))
            path.addQuadCurve(to: p(152, 44), control: p(96, 62))
            path.addQuadCurve(to: p(96, 124), control: p(142, 100))
        }
        path.closeSubpath()
        return path
    }
}

/// The seed head, at the wing's root.
private struct SeedHead: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 200
        let centre = CGPoint(x: rect.minX + 72 * s, y: rect.minY + 146 * s)
        return Path(ellipseIn: CGRect(
            x: centre.x - 20 * s, y: centre.y - 20 * s,
            width: 40 * s, height: 40 * s
        ))
    }
}

/// `3f` — the same silhouette drawn as a stroke rather than a fill, for places that need the
/// mark to sit as a line weight beside text.
private struct SeedOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 200
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: p(82, 126))
        path.addQuadCurve(to: p(172, 34), control: p(86, 56))
        path.addQuadCurve(to: p(96, 130), control: p(160, 104))
        path.closeSubpath()

        // The vein.
        path.move(to: p(98, 112))
        path.addQuadCurve(to: p(148, 52), control: p(106, 72))
        return path
    }
}

// MARK: - Mark

/// The mark, in the three framings the design draws.
struct SycamoreMark: View {

    enum Variant {
        /// `3d` — the seed inside a ring. The most self-contained of the three, and the one
        /// that survives being shrunk to a favicon.
        case ringed
        /// `3e` — two seeds, one large and one small and turned, the way they fall in pairs.
        case pair
        /// `3f` — outlined. Lighter beside text than either filled variant.
        case outlined
    }

    var variant: Variant = .ringed
    /// Overrides the mark's own greens — for the rare surface that needs it monochrome.
    var tint: Color?

    private var primary: Color { tint ?? Theme.markGreen }
    private var secondary: Color { tint ?? Theme.markGreenLight }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            // The design places sub-marks with SVG `<use x= y=>`, which positions from the
            // top-left. SwiftUI's `.offset` moves from the centre, so every placement below is
            // the design's box centre measured from the canvas centre (100, 100).
            let k = side / 200

            switch variant {
            case .ringed:
                ZStack {
                    // r=84 stroked at 9.
                    Circle()
                        .strokeBorder(primary, lineWidth: k * 9)
                        .frame(width: k * 168, height: k * 168)
                    // x=34 w=132 -> centre 100, i.e. dead centre. No offset needed.
                    seedBody.frame(width: k * 132, height: k * 132)
                }
                .frame(width: side, height: side)

            case .pair:
                ZStack {
                    // scale(0.66) at (10, 4) -> a 132 box centred on (76, 70).
                    seedBody
                        .frame(width: k * 132, height: k * 132)
                        .offset(x: k * -24, y: k * -30)
                    // scale(0.44) about its own centre, dropped at (138, 146).
                    seedBody
                        .frame(width: k * 88, height: k * 88)
                        .rotationEffect(.degrees(160))
                        .offset(x: k * 38, y: k * 46)
                }
                .frame(width: side, height: side)

            case .outlined:
                ZStack {
                    SeedOutline()
                        .stroke(primary, style: .init(lineWidth: k * 8, lineCap: .round, lineJoin: .round))
                        .frame(width: side, height: side)
                    // cx=74 cy=144 r=16, stroked at 8.
                    Circle()
                        .strokeBorder(primary, lineWidth: k * 8)
                        .frame(width: k * 32, height: k * 32)
                        .offset(x: k * -26, y: k * 44)
                }
                .frame(width: side, height: side)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var seedBody: some View {
        ZStack {
            SeedWing(half: .outer).fill(primary)
            SeedWing(half: .inner).fill(secondary)
            SeedHead().fill(primary)
        }
    }
}

// MARK: - App icon

/// The mark on its tile, at the corner radius the design draws (45 on 200 — a shade tighter
/// than a superellipse, which is what the design asks for).
struct SycamoreAppMark: View {
    var variant: SycamoreMark.Variant = .ringed
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 45 / 200, style: .continuous)
            .fill(Theme.markTile)
            .frame(width: size, height: size)
            .overlay {
                SycamoreMark(variant: variant)
                    .padding(size * (variant == .ringed ? 10 : 14) / 200)
            }
    }
}

// MARK: - Previews

#Preview("Mark — variants") {
    HStack(spacing: 24) {
        ForEach([SycamoreMark.Variant.ringed, .pair, .outlined], id: \.self) { variant in
            VStack(spacing: 10) {
                SycamoreAppMark(variant: variant, size: 96)
                SycamoreMark(variant: variant)
                    .frame(width: 40, height: 40)
            }
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.grouped)
}

extension SycamoreMark.Variant: Hashable {}
