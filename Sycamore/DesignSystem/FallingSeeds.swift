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
//  There was a `SpinningSeed` here too — one seed autorotating in place, at the scale of a
//  spinner, for the "Working…" capsule that floated over every write. The capsule went and took
//  its only caller with it; see `storeErrorBanner` in `Components.swift` for why.
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

/// The lockup: the mark, and the wordmark typing itself in beside it.
///
/// The row holds the finished word's width from the first frame. A copy of the whole word is
/// laid out and `.hidden()`, and the characters written so far are drawn over it, leading
/// aligned. So the lockup is centred where it will settle before a single letter exists, and no
/// letter already on screen ever moves again — which is what typing means.
///
/// Deliberately not the growing frame this used to be. That version measured the word and
/// animated `.frame(width:)` up from zero; because the row is centred, the mark was pushed left
/// as the word emerged. That is a fine reading of a continuous wipe and the wrong one for
/// typing, where eight discrete characters would have shoved the mark sideways eight times.
/// Running both together is worse again: a clip that does not land exactly on a glyph boundary
/// shows a letter cut down the middle, which is the wipe this is replacing.
///
/// The word is one `Text`, never one per letter: splitting it would let each letter animate
/// alone but would throw away kerning and the design's `-.022em` tracking, and "Sycamore" with
/// the pairs pulled apart is a different wordmark. A prefix of the string is still a single run,
/// so what is on screen is set exactly as `.display` sets it — the same style the sign-in screen
/// uses — with only its last character's advance in question rather than all eight.
private struct EntranceLockup: View {
    /// How many characters of the wordmark are written. Owned by `SeedEntrance`, which holds the
    /// whole of the entrance's clock in one place rather than splitting it across two views.
    var typedCount: Int

    var body: some View {
        HStack(spacing: 0) {
            SycamoreAppMark(size: 72)
                .shadow(Shadows.tabItem)

            word(Motion.Entrance.wordmark)
                // Drawn nowhere, measured everywhere: this copy is what sets the row's width.
                // `.hidden()` rather than `.opacity(0)` so it leaves the accessibility tree too.
                .hidden()
                .overlay(alignment: .leading) {
                    word(Motion.Entrance.wordmark.prefix(typedCount))
                }
                .padding(.leading, Spacing.large)
        }
    }

    /// Both runs of the wordmark, set once.
    ///
    /// The reserved width and the typed prefix have to be set identically or the mark shifts
    /// mid-type — the hidden copy would be measuring a word the visible one is not drawing.
    /// Declared as a function so that is structural rather than two `.typeStyle(.display)`
    /// calls four lines apart that a reader has to notice must agree.
    private func word(_ characters: some StringProtocol) -> some View {
        Text(String(characters))
            .typeStyle(.display, color: Theme.ink)
    }
}

/// The app's opening beat: seeds falling, the mark landing, the word writing itself in, then
/// the whole thing clearing to the app.
///
/// Held to about two seconds. Long enough to read as intentional, short enough that somebody
/// opening the app to mark a kid away twenty times a day never waits on it. The seeds and the
/// typing are both skipped when Reduce Motion is on; the mark and the word still arrive.
struct SeedEntrance: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasLanded = false
    /// Characters of the wordmark written so far. A count rather than a fraction, because the
    /// word arrives in whole letters: there is no state between two of them for a curve to
    /// interpolate, which is also why nothing below animates it.
    @State private var typedCount = 0

    var body: some View {
        ZStack {
            Theme.grouped
            if !reduceMotion {
                FallingSeeds(count: 9, label: "Opening Sycamore")
            }

            // Tiled for the same reason as `SeedLoadingView` — a bare pair mark is lost among
            // the seeds falling past it.
            EntranceLockup(typedCount: typedCount)
                .scaleEffect(hasLanded ? 1 : 0.92)
                .opacity(hasLanded ? 1 : 0)
                // The mark and word are one announcement, not two; VoiceOver should not read
                // the splash as separate elements while the app is still opening, and it must
                // certainly not read it a character at a time as the word arrives.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sycamore")
        }
        .ignoresSafeArea()
        .task {
            // The landing stays here, in the synchronous head of the task, rather than moving
            // into `typeWordmark()` with the rest. `SycamoreApp` records — off screen captures,
            // twice — that a `withAnimation` reached after an `await` is not reliably picked up
            // as a view-update transaction and simply snaps. Nothing has been awaited yet at
            // this line, and that is the only reason this one animates.
            withAnimation(.smooth(duration: Motion.Entrance.land)) { hasLanded = true }
            await typeWordmark()
        }
    }

    /// Writes the word beside the mark, a character at a time.
    ///
    /// A plain sleep loop rather than an animation. Each step is a whole character appearing,
    /// not a value travelling between two states, so there is nothing for a curve to
    /// interpolate; `phaseAnimator` would want nine phases and still need the same interval
    /// between them. Nothing here animates, and nothing here needs to.
    private func typeWordmark() async {
        // Reduce Motion gets the finished word rather than a quicker one. The writing *is* the
        // motion being asked about; the name is not, so the name still arrives — it is simply
        // already there. Nothing at all rather than a near-zero interval, for the reason
        // `GroupsMetrics.fold(reduceMotion:)` gives: that is the real "do not animate this".
        guard !reduceMotion else {
            typedCount = Motion.Entrance.wordmark.count
            return
        }

        do {
            // The word follows the mark rather than arriving with it — the mark lands, then the
            // name is written beside it.
            try await Task.sleep(for: .seconds(Motion.Entrance.markToWord))
            for count in 1...Motion.Entrance.wordmark.count {
                try await Task.sleep(for: .seconds(Motion.Entrance.keystroke))
                typedCount = count
            }
        } catch {
            // Cancelled: the entrance is already being torn down, so the half-written word is
            // never seen. Caught rather than swallowed per-sleep with `try?` on purpose —
            // `try?` would let every remaining sleep return instantly and spin the rest of the
            // word out inside a single frame.
        }
    }
}
