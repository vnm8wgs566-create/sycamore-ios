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

import SwiftUI

struct CoachPill: View {

    /// Nil is a court nobody has yet, which the design writes as "Needs a coach".
    let name: String?
    /// Opens the coach's staff card. Omitted when there is no coach to open.
    var action: (() -> Void)?

    private var label: String { name ?? "Needs a coach" }
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
        CoachPill(name: nil)
    }
    .padding(Spacing.bar)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
}
