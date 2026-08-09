//
//  CoachPill.swift
//  Sycamore
//
//  Who is on something: a 30pt disc and a first name on a `fill` capsule.
//
//  The design draws a photo here. The app has never had one — every face in it is an
//  `InitialsAvatar` — so this is the same disc every other screen uses at the size the design
//  draws it.
//
//  ── Two readers, and neither of them is a court card ─────────────────────────────────────────
//
//  `RunningBlockCard` wraps a row of these in a `FlowLayout` — a block can name three people — and
//  the court screen's header draws one, where `CourtHeader.swift:70-79` gives the reason that pill
//  has nowhere to go.
//
//  A court card on Overview no longer does. `8i` draws its coach with no plate at all: a 26pt disc
//  and a name, on their own line under the activity. That is `CourtCoachLine`, and the invitation
//  that used to live here — a `+` in place of the face, opening `CourtCoachPicker` — went with it,
//  because the card was the only caller that ever asked for it. Two differently worded, differently
//  plated ways to fill a court, one of them unreachable, is how a screen ends up with two answers
//  to one gesture; `MoreRow`'s own header records where that ends.
//
//  What is left is the flat capsule the design draws, and "Needs a coach" on something nobody is
//  on. A report, not a control: both remaining readers are places that say who is on a thing, and
//  neither is a place the app can do anything about it.
//

import SwiftUI

struct CoachPill: View {

    /// The app's spelling of a thing nobody is on.
    ///
    /// Here rather than on each of the three views that say it — this pill, `CourtCoachLine`'s
    /// inert state and `8j`'s condensed rows — because it is one claim about a court and three
    /// literals is three chances for one of them to become "No coach". This pill is the oldest of
    /// the three and the one reached from outside the folder, so it owns the words.
    ///
    /// `CourtCoachLine.addACoach` is deliberately *not* this string. That one is a control and
    /// wants a verb; see its own doc.
    ///
    /// `nonisolated` because a `View` is `@MainActor` by inference under Swift 6 and its statics
    /// come with it, which makes a plain string unreadable from `CondensedCourtRow.Trailing` — a
    /// nested enum that has no reason to be on an actor. A `String` is `Sendable`; there is nothing
    /// here for the isolation to protect.
    nonisolated static let needsACoach = "Needs a coach"

    /// Nil is a block or a court nobody is on.
    let name: String?
    /// What a tap does: opens their staff card. Omitted leaves the pill inert, which is what a
    /// nameless pill always is — there is nobody to open.
    var action: (() -> Void)?

    private var label: String { name ?? Self.needsACoach }
    private var initials: String { name.map { Initials.make(from: $0) } ?? "—" }

    /// The disc grows with the reader's type size, or the initials inside it outgrow the circle
    /// and spill over the edge. `.footnote` is the ramp the 12pt initials ride.
    @ScaledMetric(relativeTo: .footnote) private var avatarSize = OverviewTheme.coachAvatar

    var body: some View {
        if let action {
            Button(action: action) {
                // The capsule keeps the 38pt the design draws; only the frame that takes the
                // tap grows to the 44pt minimum. `minWidth` too, so a one-letter name cannot
                // shrink the target below it.
                pill
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name.map { "Coach \($0)" } ?? label)
            .accessibilityHint("Opens their staff card")
        } else {
            // The disc says nothing a reader can use and the name is already in the label, so
            // the pill is one element with one line rather than a disc and a word.
            pill
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(name.map { "Coach \($0)" } ?? label)
        }
    }

    private var pill: some View {
        HStack(spacing: Spacing.small) {
            // The type is pinned to the disc's *drawn* size rather than to the grown one, so
            // `initials(forAvatarSize:)` cannot cross one of its weight buckets as the disc
            // scales and hand a coach bolder initials than the design draws.
            InitialsAvatar(
                initials,
                size: avatarSize,
                font: .initials(forAvatarSize: OverviewTheme.coachAvatar)
            )

            // `inkWarm` for a name and `inkFaint` for nobody. Faint grey would read as disabled on
            // a control; this pill is not one, which is exactly what makes it the right colour.
            Text(label)
                .typeStyle(.chipSoft, color: name == nil ? Theme.inkFaint : Theme.inkWarm)
                .lineLimit(1)
        }
        .padding(.leading, OverviewTheme.coachPillInset)
        .padding(.trailing, OverviewTheme.coachPillTrailing)
        .padding(.vertical, OverviewTheme.coachPillInset)
        .background(OverviewTheme.coachPillFill, in: Capsule(style: .continuous))
    }
}

// MARK: - Previews

#Preview("Coach pill") {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        CoachPill(name: "Nass") {}
        CoachPill(name: "You") {}
        // Nobody on it, which this pill only ever reports. `CourtCoachLine` is the one that
        // offers to fix it.
        CoachPill(name: nil)
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
}

/// The size the app caps Dynamic Type at. The disc rides the initials in it, so the empty pill
/// should still be exactly as tall as the named one beside it.
#Preview("Coach pill — accessibility1") {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        CoachPill(name: "Nass") {}
        CoachPill(name: nil)
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
    .environment(\.dynamicTypeSize, .accessibility1)
}
