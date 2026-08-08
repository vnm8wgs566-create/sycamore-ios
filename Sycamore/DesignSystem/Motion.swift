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
    static func fold(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : fold
    }

    /// The cold-launch entrance, in seconds from its first frame.
    ///
    /// `SeedEntrance` plays the first half — the mark landing, then the word typing. `SycamoreApp`
    /// plays the second — waiting out `hold(reduceMotion:)`, then `fade(reduceMotion:)`.
    enum Entrance {

        /// The word the entrance writes.
        ///
        /// It lives beside the clock rather than inside the view because its length *is* part of
        /// the clock: the word is typed a character at a time, so the number of characters is
        /// what decides when the typing ends and therefore when the fade may start. Keeping it
        /// here is what lets `hold(reduceMotion:)` below be derived instead of written down.
        static let wordmark = "Sycamore"

        /// The mark arriving — scaling up from 0.92 and fading in.
        static let land: Double = 0.42

        /// The gap between the mark landing and the first letter. The word follows the mark
        /// rather than arriving with it, so the two read as one thing happening in order rather
        /// than two things appearing at once.
        static let markToWord: Double = 0.22

        /// One keystroke. Eight of them write the wordmark in 0.56s — precisely the span the
        /// width-wipe this replaced took, so the beat the entrance was designed around is
        /// unchanged and only the mechanism is different.
        ///
        /// The rate is the whole of the effect. Much under 50ms an eight-letter word reads as a
        /// smear rather than as typing; much over 100ms it outstays the launch it decorates.
        ///
        /// Deliberately even. Real typing is uneven, but jitter over eight characters in half a
        /// second is not read as human — it is read as a dropped frame.
        static let keystroke: Double = 0.07

        /// How long the finished lockup is held before the entrance begins to clear: the
        /// difference between the name being read and the name being glimpsed.
        static let dwell: Double = 0.47

        /// When the last character lands, measured from the first frame — 0.78s.
        ///
        /// `Task.sleep` guarantees a floor rather than an exact interval, so the real figure runs
        /// fractionally over eight times. `dwell` is what absorbs that.
        static var wordFinished: Double {
            markToWord + keystroke * Double(wordmark.count)
        }

        /// When the fade starts, measured from the first frame — 1.25s, or 0.89s under Reduce
        /// Motion, where the word is simply already there and there is nothing to wait out.
        ///
        /// Derived rather than written down. This is the number that has to move when the typing
        /// rate does, and it is played in a different file from the typing.
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
