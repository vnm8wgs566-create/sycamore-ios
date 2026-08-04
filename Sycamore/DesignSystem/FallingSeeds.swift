//
//  FallingSeeds.swift
//  Sycamore
//
//  The loading state: a handful of samaras falling and spinning, from `leaf2e` in
//  `Sycamore Logo v2.dc.html`.
//
//  A real samara does not tumble end over end — it autorotates, spinning flat about its own
//  axis while it descends, which is why it falls slowly. That is the whole reason the shape is
//  worth animating at all, so each seed here spins at a steady rate and drifts sideways as it
//  goes, rather than pinwheeling.
//
//  Deliberately not a `ProgressView`: this is the one moment the app's own mark can do the
//  waiting, and a spinner would throw that away. It still reports itself to VoiceOver as busy.
//

import SwiftUI

// MARK: - Leaf

/// `leaf2e` — two halves meeting on a vertical spine, with the seed head at the bottom. Drawn
/// on the design's 200×200 canvas and scaled to its frame.
private struct SamaraLeaf: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height) / 200

            ZStack {
                LeafHalf(side: .leading).fill(Theme.markGreen)
                LeafHalf(side: .trailing).fill(Theme.markGreenLight)
                Circle()
                    .fill(Theme.markGreen)
                    .frame(width: 16 * s, height: 16 * s)
                    .offset(x: 0, y: 80 * s)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct LeafHalf: Shape {
    enum Side { case leading, trailing }
    let side: Side

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 200
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        switch side {
        case .leading:
            path.move(to: p(94, 30))
            path.addQuadCurve(to: p(94, 164), control: p(40, 78))
        case .trailing:
            path.move(to: p(106, 30))
            path.addQuadCurve(to: p(106, 164), control: p(160, 78))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - One seed's flight

/// Everything about a single seed's descent, fixed when it is created so the flock does not
/// move in lockstep. Seeded from the index rather than `Math.random`, so a given position in
/// the flock always falls the same way and previews are stable.
private struct Flight: Identifiable {
    let id: Int
    /// Fraction across the width the seed falls at.
    let column: CGFloat
    /// How far it drifts sideways over the fall, as a fraction of the width.
    let drift: CGFloat
    let size: CGFloat
    let duration: Double
    /// Staggers the flock so seeds are already mid-air when the view appears.
    let delay: Double
    let clockwise: Bool

    init(id: Int, of total: Int) {
        self.id = id
        // Spread across the width, then nudged so the columns are not a visible grid.
        let slot = (CGFloat(id) + 0.5) / CGFloat(total)
        let jitter = CGFloat((id &* 37) % 17) / 17 - 0.5
        column = min(max(slot + jitter * 0.12, 0.06), 0.94)
        drift = (CGFloat((id &* 53) % 11) / 11 - 0.5) * 0.28
        size = 18 + CGFloat((id &* 29) % 10)
        duration = 2.6 + Double((id &* 41) % 14) / 10
        delay = Double((id &* 67) % 20) / 10
        clockwise = id.isMultiple(of: 2)
    }
}

// MARK: - The flock

struct FallingSeeds: View {
    var count: Int = 7
    var label: String = "Loading"

    /// Drives every seed off one clock. A `TimelineView` rather than per-seed `withAnimation`
    /// so the flock cannot drift out of phase, and so it costs one redraw per frame instead of
    /// `count` independent animations.
    var body: some View {
        let flights = (0..<count).map { Flight(id: $0, of: count) }

        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate

                ZStack(alignment: .topLeading) {
                    ForEach(flights) { flight in
                        seed(flight, at: now, in: proxy.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private func seed(_ flight: Flight, at now: TimeInterval, in size: CGSize) -> some View {
        // Progress through this seed's own loop, 0 at the top and 1 past the bottom.
        let cycle = (now + flight.delay).truncatingRemainder(dividingBy: flight.duration)
        let t = cycle / flight.duration

        // The fall starts a seed-height above the frame and ends a seed-height below, so a
        // seed is never seen to appear or vanish inside the frame.
        let y = -flight.size + (size.height + flight.size * 2) * t
        // Sideways drift eases rather than tracking linearly, which reads as air resistance
        // rather than as a diagonal line.
        let x = size.width * flight.column + size.width * flight.drift * sin(t * .pi)

        // Autorotation: a steady spin about the seed's own axis, ~2 turns per fall.
        let spin = (flight.clockwise ? 1.0 : -1.0) * t * 720

        SamaraLeaf()
            .frame(width: flight.size, height: flight.size)
            .rotationEffect(.degrees(spin))
            // Fade in and out at the very ends so nothing pops at the frame edge.
            .opacity(min(1, min(t, 1 - t) * 8))
            .position(x: x, y: y)
    }
}

// MARK: - Loading panel

/// The full-bleed loading state — the flock behind the app's own wordmark.
struct SeedLoadingView: View {
    var label: String = "Loading"

    var body: some View {
        ZStack {
            Theme.grouped
            FallingSeeds(label: label)
            SycamoreMark(variant: .ringed)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Falling seeds") {
    SeedLoadingView()
}

#Preview("Falling seeds — dense") {
    ZStack {
        Theme.surface
        FallingSeeds(count: 14)
    }
    .ignoresSafeArea()
}
