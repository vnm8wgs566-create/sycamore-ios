//
//  Motion.swift
//  Sycamore
//
//  Durations that more than one file has to agree on.
//
//  Nearly every animation in this app is a literal at the site that plays it, and that is right:
//  a curve used once, in the view it belongs to, is easier to read where the thing is drawn than
//  three files away.
//
//  The fold earned this one the ordinary way: it had eight callers on the Groups screen, and then
//  Overview grew a folded list too. Two features needing the same curve is the condition below.
//
//  The entrance earned this one differently. Its choreography is written down as a comment in
//  `SycamoreApp` — mark lands, word types, hold, fade — but every number that comment describes
//  is played by `FallingSeeds`, and the one number `SycamoreApp` actually owns, the hold, is the
//  sum of the others. A comment cannot guard an arithmetic relationship that spans two files:
//  change the typing rate and the hold quietly becomes too short, and the word is still being
//  written when the entrance starts to clear. So the relationship is code here, and both files
//  read it rather than restating it.
//
//  Deliberately not a motion table for the whole app. The other fourteen `withAnimation` sites
//  were each chosen against the screen they run on, and none of them were weighed against each
//  other; collecting them here would present them as one shared decision when they are not,
//  which is exactly the failure `Typography.swift` describes of its own table. A duration is
//  admitted when a second file needs it.
//

import SwiftUI

enum Motion {

    /// Every fold and unfold in the app: a group card opening, a court card opening, a kid
    /// sliding to a new target. One curve, so they are recognisably the same motion.
    ///
    /// This lived in `GroupsTokens` while Groups was the only screen that folded a list. Overview
    /// folds one now, which is the condition this file sets for admitting a duration — and the
    /// alternative was `Features/Overview` reaching into `Features/Groups`' token namespace for
    /// its animation, with nothing but the compiler recording the dependency. A Groups-local
    /// decision to retime its fold would have silently retimed Overview's.
    static let fold: Animation = .snappy(duration: 0.24)

    /// `fold`, or nothing at all for a reader who has asked for less motion.
    ///
    /// A fold is position: rows appear below the ones already there and push the rest down. That
    /// is precisely what Reduce Motion is about, so the state still changes — it simply arrives
    /// rather than slides. `nil` rather than a near-zero duration, because `withAnimation(nil)`
    /// and `.animation(nil, value:)` are both the real "do not animate this".
    ///
    /// **A known discrepancy, recorded rather than fixed.** `.snappy` is `bounce: 0.15`, and the
    /// design system's own rule is no bounce and no spring overshoot — the rule `ProgressTrack`
    /// was corrected to (`Components.swift:787-794`). A fold overshooting by a point and settling
    /// is nothing like a 4pt bar overshooting the number printed beside it, which is why that one
    /// was a fix and this one is a note: this curve drives every fold and unfold in the app, and
    /// retiming all of them is a decision to take deliberately and see, not a cleanup to slip in
    /// beside one.
    static func fold(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : fold
    }

    /// The press: `scale(.975)` over 90ms, or nothing at all under Reduce Motion.
    ///
    /// Admitted on a different ground from `fold`, and the header's bar — a second file needing
    /// it — is not the ground. This one has a single caller. What it has that the fourteen
    /// `withAnimation` literals do not is that **the number is not this file's to choose**: the
    /// design system states the press as `scale(.975)` over 90ms, so it is one decision already
    /// taken, for every screen, and the only question left is where it is written down. Nothing
    /// carried it, so the one screen that wanted a press guessed — and guessed a bouncing spring,
    /// which is a press that recoils past its own resting size on the way back up. A literal at
    /// the site is the right home for a curve chosen against the screen it runs on. This was
    /// chosen against all of them.
    ///
    /// `.easeOut` and emphatically not a spring, for `ProgressTrack`'s reason
    /// (`Components.swift:787-794`). A press is a finger arriving: it should decelerate into the
    /// smaller size and stop there, because there is nothing physical for it to overshoot.
    ///
    /// 90ms is short by design. A press is feedback for a touch that has already landed, so any
    /// longer and it is reporting the touch rather than confirming it.
    ///
    /// Gated on Reduce Motion like `fold(reduceMotion:)` and for the same reason, though the scale
    /// itself still applies — the row still reads as pressed, it simply does not travel there.
    static func press(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.09)
    }

    /// The cold-launch entrance, in seconds from its first frame.
    ///
    /// `SeedEntrance` plays the first half — the mark landing, then the word settling beside it.
    /// `SycamoreApp` plays the second — waiting out `hold(reduceMotion:)`, then
    /// `fade(reduceMotion:)`.
    enum Entrance {

        /// The word the entrance sets.
        ///
        /// It lives beside the clock rather than inside the view because it used to *be* part of
        /// the clock: the word was typed a character at a time, so its length decided when the
        /// typing ended and therefore when the fade could start. It no longer is — the word
        /// arrives whole — and `wordFinished` below is a constant now rather than a count. The
        /// string stays here because the two files that draw it should not each hold a copy.
        static let wordmark = "Sycamore"

        /// The mark arriving — scaling up from 0.92 and fading in.
        static let land: Double = 0.42

        /// The gap between the mark landing and the word beginning to settle. The word follows the
        /// mark rather than arriving with it, so the two read as one thing happening in order
        /// rather than two things appearing at once.
        static let markToWord: Double = 0.22

        /// The word settling into place: down, into focus, and to rest.
        ///
        /// ── Why this is not the typing it replaces ────────────────────────────────────────────
        ///
        /// The identity is a samara — the winged seed that spins as it falls, which is what the
        /// flock behind the lockup is doing. A wordmark that *types* is a terminal's gesture and
        /// belongs to a different family of product entirely; it said nothing about this app, and
        /// it said it for 0.56 seconds every cold launch. What the word does now is what
        /// everything else on the screen is doing: it comes down, and it settles.
        ///
        /// Four values move together over this span — a small drop, a blur clearing, a fraction of
        /// scale, and the opacity — because that combination is what reads as *settling* rather
        /// than as fading. Drop alone is a slide; blur alone is a focus pull; together they are a
        /// thing coming to rest.
        ///
        /// **The word stays one `Text` run**, which the typing had to fight for and this gets for
        /// free. Splitting it per letter would throw away kerning and the design's `-.022em`
        /// tracking, and "Sycamore" with the pairs pulled apart is a different wordmark. Typing
        /// also needed a hidden full-width copy underneath to stop the mark being shoved sideways
        /// eight times; a word that arrives whole reserves its own width from the first frame, so
        /// that scaffolding is gone with it.
        ///
        /// Half a second, matched to `land` plus a little: the mark takes 0.42 to arrive and the
        /// word should not beat it into stillness.
        static let settle: Double = 0.5

        /// How far the word falls into place. Small on purpose — this is a seed landing on a
        /// surface, not one dropping onto it, and anything past about ten points reads as the
        /// word sliding in from off screen.
        static let settleDrop: CGFloat = 10

        /// How far out of focus the word starts. Enough to be unmistakably soft on the first
        /// frame, not so much that it is a smear the reader waits out.
        static let settleBlur: CGFloat = 6

        /// The word starts a touch large, as something arriving from nearer the reader does, and
        /// comes down to size with the rest of it.
        static let settleScale: CGFloat = 1.04

        /// When the word comes to rest, measured from the first frame — 0.72s.
        ///
        /// A derived constant rather than a count of characters, which is what it was: with the
        /// typing gone there is no per-letter interval left for the length of the word to
        /// multiply. Kept derived all the same, because it is the number `hold(reduceMotion:)`
        /// needs and the two are played in different files.
        static var wordFinished: Double { markToWord + settle }

        /// How long the finished lockup is held before the entrance begins to clear: the
        /// difference between the name being read and the name being glimpsed.
        static let dwell: Double = 0.47

        /// When the fade starts, measured from the first frame — 1.19s, or 0.89s under Reduce
        /// Motion, where the word is simply already there and there is nothing to wait out.
        static func hold(reduceMotion: Bool) -> Double {
            (reduceMotion ? land : wordFinished) + dwell
        }

        /// The entrance dissolving over the page beneath it. Shorter under Reduce Motion, for the
        /// same reason the hold is: there is materially less on screen to clear.
        static func fade(reduceMotion: Bool) -> Double {
            reduceMotion ? 0.4 : 0.6
        }
    }
}

// MARK: - Folding a set

extension Set {

    /// In if it was out, out if it was in.
    ///
    /// Every folded list in the app keeps its open rows as a set of ids and wrote the same five
    /// lines to flip one — `GroupsView`, `OverviewScreen`, and both of their preview harnesses.
    /// `insert` already reports whether it did anything, so the whole thing is one expression.
    mutating func toggle(_ member: Element) {
        if !insert(member).inserted { remove(member) }
    }
}
