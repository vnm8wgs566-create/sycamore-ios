//
//  CoachPill.swift
//  Sycamore
//
//  Who has this court: a 30pt disc and a first name on a `fill` capsule.
//
//  The design draws a photo here. The app has never had one — every face in it is an
//  `InitialsAvatar` — so this is the same disc every other screen uses at the size the design
//  draws it.
//
//  A court nobody has draws the design's "Needs a coach". Which was, until now, the whole of what
//  the app did about it: an inert grey capsule with an em dash where the face goes, on the one
//  screen an admin is looking at when they notice. The pill knows the court is short and the write
//  that fixes it has existed since Setup was built, so the empty pill is now the way to it — see
//  `plusDisc`, and `CourtCoachPicker` for what it opens.
//

import SwiftUI

struct CoachPill: View {

    /// Nil is a court nobody has yet.
    ///
    /// What it draws depends on whether there is anything to do about it. With an `action` the pill
    /// is a control: a `+` in place of the face, the design's "Needs a coach" beside it, and the
    /// accent to say it is the one pill on the screen that wants pressing. Without one it is the
    /// flat capsule the design draws — which is what the court screen's header wants, and
    /// `CourtHeader.swift:70-79` gives the reason that pill has nowhere to go.
    let name: String?
    /// What a tap does. With a name it opens their staff card; with none it opens the picker that
    /// fills the court. Omitted leaves the pill inert.
    var action: (() -> Void)?

    private var label: String { name ?? "Needs a coach" }
    private var initials: String { name.map { Initials.make(from: $0) } ?? "—" }
    /// Only an empty pill that can be filled in draws the `+`. An empty pill with nowhere to go
    /// keeps the em dash, because a `+` on it would be a control that is not one.
    ///
    /// Inferred from the two arguments rather than declared by a third, and that is a decision.
    /// A `kind:` parameter would say it out loud, but it would also be a parameter every caller has
    /// to keep in step with the other two — and the four combinations of (name, action) already
    /// exhaust the states this pill has, each with exactly one sensible reading: a name and a tap
    /// opens them, no name and a tap fills the court, and no tap is the design's flat capsule
    /// either way. A caller passing an action for a nameless pill means "let them fix it"; there is
    /// nothing else it could mean. The one thing the inference pins that a caller might want to
    /// vary is the VoiceOver hint, which is why it is worded about the *court* and not about
    /// whichever screen is asking.
    private var isInvitation: Bool { name == nil && action != nil }

    /// The disc grows with the reader's type size, or the initials inside it outgrow the circle
    /// and spill over the edge. `.footnote` is the ramp the 12pt initials ride.
    @ScaledMetric(relativeTo: .footnote) private var avatarSize = OverviewTheme.coachAvatar
    /// The `+` rides the same ramp as the initials it replaces, so the two states of the disc grow
    /// at one rate and the pill keeps its height whichever it is drawing.
    @ScaledMetric(relativeTo: .footnote) private var plusSize = OverviewTheme.coachPlusGlyph

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
            .accessibilityHint(
                isInvitation ? "Chooses who has this court" : "Opens their staff card"
            )
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
            if isInvitation {
                plusDisc
            } else {
                // The type is pinned to the disc's *drawn* size rather than to the grown one, so
                // `initials(forAvatarSize:)` cannot cross one of its weight buckets as the disc
                // scales and hand a coach bolder initials than the design draws.
                InitialsAvatar(
                    initials,
                    size: avatarSize,
                    font: .initials(forAvatarSize: OverviewTheme.coachAvatar)
                )
            }

            Text(label)
                .typeStyle(.chipSoft, color: labelColour)
                .lineLimit(1)
        }
        .padding(.leading, OverviewTheme.coachPillInset)
        .padding(.trailing, OverviewTheme.coachPillTrailing)
        .padding(.vertical, OverviewTheme.coachPillInset)
        .background(OverviewTheme.coachPillFill, in: Capsule(style: .continuous))
    }

    /// The `+` an empty, fillable pill wears where a face would go.
    ///
    /// `AvatarTone.tinted`'s pair — an `accentTint` disc with an `accent` mark — rather than a
    /// fourth tone or a bare glyph. It is the tone the app already spends on the one person in a
    /// list who is different, it sits on the same `hairlineFaint` capsule without a border to hold
    /// it, and it keeps the disc a disc: a pill that dropped the circle when the coach was missing
    /// would change shape as well as colour, and the row of pills down the screen would stop
    /// lining up.
    ///
    /// Deliberately not `AccentDisc`, which carries a ring and is the app's empty-state *mark* —
    /// 52pt above a headline. Half an inch of it inside a capsule would read as a second, smaller
    /// empty state sitting on a card.
    private var plusDisc: some View {
        Circle()
            .fill(Theme.accentTint)
            .frame(width: avatarSize, height: avatarSize)
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: plusSize, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)
    }

    /// `inkWarm` for a name, `inkFaint` for a court nobody has — and the accent once that pill is
    /// something to press. Faint grey on a control reads as disabled, which is the reading
    /// `OverviewCourtCard.overflowRow` records about the `+N more` line it inherited from the
    /// design for the same reason: it was right while the line was a label.
    private var labelColour: Color {
        if isInvitation { return Theme.accentDark }
        return name == nil ? Theme.inkFaint : Theme.inkWarm
    }
}

// MARK: - Previews

#Preview("Coach pill") {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        CoachPill(name: "Nass") {}
        CoachPill(name: "You") {}
        // The two empty states, which are two different claims: a court that can be filled in from
        // here, and one that cannot.
        CoachPill(name: nil) {}
        CoachPill(name: nil)
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
}

/// The size the app caps Dynamic Type at. The disc and the `+` inside it ride one ramp, so the
/// two pills either side of the empty one should still be the same height as it.
#Preview("Coach pill — accessibility1") {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        CoachPill(name: "Nass") {}
        CoachPill(name: nil) {}
        CoachPill(name: nil)
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
    .environment(\.dynamicTypeSize, .accessibility1)
}
