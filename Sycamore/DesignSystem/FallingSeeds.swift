//
//  FallingSeeds.swift
//  Sycamore
//
//  Falling samaras — the app's entrance motif, and now nothing else.
//
//  The seed that falls is `SycamoreSeed`, the same shape the mark is built from, not a
//  redrawing of it. That is the point: the thing spinning down the screen while the app opens
//  is literally the logo coming apart into its parts, and if the mark's curves change these
//  follow without anyone remembering.
//
//  A real samara does not tumble end over end — it autorotates, spinning flat about its own
//  axis while it descends, which is why it falls slowly. That is the whole reason the shape is
//  worth animating, so each seed spins at a steady rate and drifts sideways as it goes.
//
//  Deliberately not a `ProgressView`: opening the app is the one moment the app's own mark can
//  do the waiting. It still reports itself to VoiceOver as busy.
//
//  ---------------------------------------------------------------------------------------------
//  TWO THINGS HAVE LEFT THIS FILE, AND BOTH WENT THE SAME WAY
//  ---------------------------------------------------------------------------------------------
//
//  There was a `SpinningSeed` — one seed autorotating in place, at the scale of a spinner, for the
//  "Working…" capsule that floated over every write. The capsule went and took its only caller
//  with it; see `storeErrorBanner` in `Components.swift` for why.
//
//  There was a `SeedLoadingView` — the flock full-bleed on `Theme.grouped`, which `RootView` laid
//  over the whole first run whenever `store.isWorking` was true. `isWorking` is raised by every
//  intent (`AppStore.perform`), so it fell for switching camps and for the write behind "That's
//  me" as readily as for a wait; and the one real wait it covered it was only *hiding*, because
//  underneath it the memberships had not arrived and the wrong question was being asked. That is
//  fixed at the cause now — `AppStore.hasLoadedMemberships` says whether the answer is known and
//  `FirstRunStep` declines to answer until it is — which left this with no callers at all.
//
//  So the seeds fall once, on the splash, and never again. Which is where they came from.
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

// MARK: - Entrance

/// The lockup: the mark, and the wordmark settling into place beside it.
///
/// One `Text`, arriving whole. That is the plain reading of a wordmark and it is also what makes
/// the row's width correct on the first frame — so the mark is centred where it will finish before
/// anything has moved, and nothing on screen is ever pushed sideways.
///
/// **Two mechanisms were tried here before this one, and both failed the same way.** A growing
/// `.frame(width:)` wiped the word open from zero, which pushed the mark left as it emerged. A
/// typed prefix fixed that by laying out a hidden full-width copy and drawing the written
/// characters over it, leading-aligned — correct, and about fifteen lines of scaffolding whose only
/// job was to undo a problem the typing created. A word that arrives whole has neither problem and
/// needs neither remedy.
///
/// What moves is the word's presentation, not its layout: `settle` drops, unblurs, scales and fades
/// it into place without changing the space it occupies. See `Motion.Entrance.settle`.
private struct EntranceLockup: View {
    /// 0 on the first frame, 1 once the word has come to rest. Owned by `SeedEntrance`, which holds
    /// the whole of the entrance's clock in one place rather than splitting it across two views.
    var settled: Bool

    var body: some View {
        HStack(spacing: 0) {
            SycamoreAppMark(size: 72)
                .shadow(Shadows.tabItem)

            Text(Motion.Entrance.wordmark)
                .typeStyle(.display, color: Theme.ink)
                // Presentation only — none of these four change the word's measured size, so the
                // row is the width it will finish at from the very first frame.
                .blur(radius: settled ? 0 : Motion.Entrance.settleBlur)
                .scaleEffect(settled ? 1 : Motion.Entrance.settleScale)
                .offset(y: settled ? 0 : -Motion.Entrance.settleDrop)
                .opacity(settled ? 1 : 0)
                .padding(.leading, Spacing.large)
        }
    }
}

/// The app's opening beat: seeds falling, the mark landing, the word settling in beside it, then
/// the whole thing clearing to the app.
///
/// Held to about 1.7 seconds. Long enough to read as intentional, short enough that somebody
/// opening the app to mark a kid away twenty times a day never waits on it. The seeds and the
/// settle are both skipped when Reduce Motion is on; the mark and the word still arrive.
///
/// The only place the flock is drawn, and the reason is the one `SeedLoadingView` used to give for
/// carrying no mark: opening the app is a moment worth naming, and waiting for a camp to load,
/// several times a session, is not. A logo parked in the middle of every load turns the identity
/// into a progress indicator, which is the fastest way to make people stop seeing it. That
/// argument now settles the whole question rather than half of it — there is no second place for
/// the seeds to fall.
struct SeedEntrance: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasLanded = false
    /// Whether the word has come to rest. A flag rather than the character count this used to be:
    /// the word arrives as one thing now, so there is one transition to be part-way through and
    /// SwiftUI interpolates it.
    @State private var hasSettled = false

    var body: some View {
        ZStack {
            Theme.grouped
            if !reduceMotion {
                FallingSeeds(count: 9, label: "Opening Sycamore")
            }

            // The mark *and* the name, rather than the mark on its own: a bare pair mark at this
            // size is lost among the seeds falling past it.
            EntranceLockup(settled: hasSettled)
                .scaleEffect(hasLanded ? 1 : 0.92)
                .opacity(hasLanded ? 1 : 0)
                // The mark and word are one announcement, not two; VoiceOver should not read the
                // splash as separate elements while the app is still opening.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sycamore")
        }
        .ignoresSafeArea()
        .task {
            // Reduce Motion gets the finished lockup rather than a quicker one. The settling *is*
            // the motion being asked about; the name is not, so the name still arrives — it is
            // simply already there. Both flags set with no animation at all rather than with a
            // near-zero duration, for the reason `Motion.fold(reduceMotion:)` gives: that is the
            // real "do not animate this".
            guard !reduceMotion else {
                hasLanded = true
                hasSettled = true
                return
            }

            // The landing stays in the synchronous head of the task, before anything is awaited.
            // `SycamoreApp` records — off screen captures, twice — that a `withAnimation` reached
            // after an `await` is not reliably picked up as a view-update transaction and simply
            // snaps. That is also why the settle below is scheduled as a *delayed animation*
            // rather than as a sleep followed by a `withAnimation`: one transaction, declared
            // here, with its own delay.
            withAnimation(.smooth(duration: Motion.Entrance.land)) { hasLanded = true }
            withAnimation(
                .smooth(duration: Motion.Entrance.settle).delay(Motion.Entrance.markToWord)
            ) {
                hasSettled = true
            }
        }
    }
}
