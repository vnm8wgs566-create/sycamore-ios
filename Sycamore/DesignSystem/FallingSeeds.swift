//
//  FallingSeeds.swift
//  Sycamore
//
//  Falling samaras — the app's one loading and entrance motif.
//
//  The seed that falls is `SycamoreSeed`, the same shape the mark is built from, not a
//  redrawing of it. That is the point: the thing spinning down the screen while a camp loads
//  is literally the logo coming apart into its parts, and if the mark's curves change these
//  follow without anyone remembering.
//
//  A real samara does not tumble end over end — it autorotates, spinning flat about its own
//  axis while it descends, which is why it falls slowly. That is the whole reason the shape is
//  worth animating, so each seed spins at a steady rate and drifts sideways as it goes.
//
//  Deliberately not a `ProgressView`: this is the one moment the app's own mark can do the
//  waiting. It still reports itself to VoiceOver as busy.
//

import SwiftUI

// MARK: - One seed's flight

/// Everything about a single seed's descent, fixed when it is created so the flock does not
/// move in lockstep. Derived from the index rather than a random source, so a given position
/// in the flock always falls the same way and previews are stable.
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

    init(id: Int, of total: Int, scale: CGFloat) {
        self.id = id
        // Spread across the width, then nudged so the columns are not a visible grid.
        let slot = (CGFloat(id) + 0.5) / CGFloat(total)
        let jitter = CGFloat((id &* 37) % 17) / 17 - 0.5
        column = min(max(slot + jitter * 0.12, 0.06), 0.94)
        drift = (CGFloat((id &* 53) % 11) / 11 - 0.5) * 0.28
        size = (22 + CGFloat((id &* 29) % 12)) * scale
        // A slow descent. A samara autorotates precisely so it *can* fall slowly — it is the
        // seed taking its time to travel that the shape is for — and at three seconds a screen
        // the flock read as drifting debris rather than something coming down under its own
        // geometry. The spread is wide on purpose: seeds falling at visibly different rates
        // are what stop the group looking like a single sheet moving.
        duration = 4.4 + Double((id &* 41) % 22) / 10
        delay = Double((id &* 67) % 34) / 10
        clockwise = id.isMultiple(of: 2)
    }
}

// MARK: - The flock

struct FallingSeeds: View {
    var count: Int = 7
    /// Scales every seed, for the small inline uses.
    var scale: CGFloat = 1
    var label: String = "Loading"

    /// Drives every seed off one clock. A `TimelineView` rather than per-seed `withAnimation`
    /// so the flock cannot drift out of phase, and so it costs one redraw per frame instead of
    /// `count` independent animations.
    var body: some View {
        let flights = (0..<count).map { Flight(id: $0, of: count, scale: scale) }

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

        SycamoreSeed()
            .frame(width: flight.size, height: flight.size)
            .rotationEffect(.degrees(spin))
            // Fade in and out at the very ends so nothing pops at the frame edge.
            .opacity(min(1, min(t, 1 - t) * 8))
            .position(x: x, y: y)
    }
}

// MARK: - A single spinning seed

/// The inline loading affordance — one seed autorotating in place, for the capsule that floats
/// over a screen while a row commits. Same seed, same spin, at the scale of a spinner.
struct SpinningSeed: View {
    var size: CGFloat = 16

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            SycamoreSeed()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(now.truncatingRemainder(dividingBy: 1.6) / 1.6 * 360))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Loading panel

/// The full-bleed loading state — just the flock.
///
/// No mark and no wordmark here, unlike `SeedEntrance`. Opening the app is a moment worth
/// naming; waiting for a camp to load, several times a session, is not. The logo parked in the
/// middle of every load turns the identity into a progress indicator, which is the fastest way
/// to make people stop seeing it.
struct SeedLoadingView: View {
    var label: String = "Loading"

    var body: some View {
        ZStack {
            Theme.grouped
            FallingSeeds(label: label)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Entrance

/// The lockup: the mark, and the wordmark sliding out from behind it to the right.
///
/// The whole thing is centred, and that is what produces the movement. The word starts at zero
/// width — clipped to nothing behind the mark — and grows to its natural width. Because the
/// row is centred, the mark is pushed left by exactly half the word's width as it emerges, so
/// the two settle as a balanced lockup without either being positioned by hand.
///
/// The word is one `Text`, never one per letter: splitting it would let each letter animate
/// alone but would throw away kerning and the design's `-.042em` tracking, and "Sycamore" with
/// the pairs pulled apart is a different wordmark. Clipping leaves the type exactly as
/// `.display` sets it — the same style the sign-in screen uses — and only uncovers it.
private struct EntranceLockup: View {
    var isRevealed: Bool
    var reduceMotion: Bool

    /// The word's natural width, measured once from its own layout. The reveal animates to
    /// this rather than to `nil`, which cannot be animated.
    @State private var wordWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            SycamoreAppMark(size: 72)
                .shadow(Shadows.tabItem)

            Text("Sycamore")
                .typeStyle(.display, color: Theme.ink)
                // Ideal width regardless of what the collapsing frame proposes, so the
                // measurement below is the word's real width and not the clipped one.
                .fixedSize()
                .padding(.leading, Spacing.large)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { wordWidth = $0 }
                .frame(width: isRevealed ? wordWidth : 0, alignment: .leading)
                // Leading alignment plus the clip is what makes it read as sliding out from
                // behind the mark rather than fading up in place.
                .clipped()
                .opacity(isRevealed ? 1 : 0)
        }
    }
}

/// The app's opening beat: seeds falling, the mark landing, the word writing itself in, then
/// the whole thing clearing to the app.
///
/// Held to about two seconds. Long enough to read as intentional, short enough that somebody
/// opening the app to mark a kid away twenty times a day never waits on it. The seeds and the
/// sweep are both skipped when Reduce Motion is on; the mark and the word still arrive.
struct SeedEntrance: View {
    /// Raised by the scene once the hold is over, and the first half of the exit: the lockup
    /// dissolves on its own before the seed field does. Fading both at once reads as the
    /// screen being switched off; letting the logo go first reads as it handing over.
    var isLeaving: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasLanded = false
    @State private var wordRevealed = false

    var body: some View {
        ZStack {
            Theme.grouped
            if !reduceMotion {
                FallingSeeds(count: 9, label: "Opening Sycamore")
            }

            // Tiled for the same reason as `SeedLoadingView` — a bare pair mark is lost among
            // the seeds falling past it.
            EntranceLockup(isRevealed: wordRevealed, reduceMotion: reduceMotion)
                // Drifts very slightly toward the viewer as it goes, so the fade has a
                // direction rather than being a flat dissolve. Held to 3% — any more and it
                // reads as a zoom.
                .scaleEffect(hasLanded ? (isLeaving ? 1.03 : 1) : 0.92)
                .opacity(hasLanded && !isLeaving ? 1 : 0)
                // The mark and word are one announcement, not two; VoiceOver should not read
                // the splash as separate elements while the app is still opening.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sycamore")
        }
        .ignoresSafeArea()
        .task {
            withAnimation(.smooth(duration: 0.5)) { hasLanded = true }
            // The word follows the mark rather than arriving with it — the mark lands, then
            // the name is written beside it.
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.smooth(duration: 0.65)) { wordRevealed = true }
        }
    }
}
