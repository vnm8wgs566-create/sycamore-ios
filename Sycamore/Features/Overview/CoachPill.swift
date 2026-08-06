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

    var body: some View {
        if let action {
            Button(action: action) {
                // The capsule keeps the 38pt the design draws; only the frame that takes the
                // tap grows to the 44pt minimum.
                pill
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name.map { "Coach \($0)" } ?? label)
            .accessibilityHint("Opens their staff card")
        } else {
            pill
                .accessibilityElement(children: .combine)
                .accessibilityLabel(name.map { "Coach \($0)" } ?? label)
        }
    }

    private var pill: some View {
        HStack(spacing: Spacing.small) {
            InitialsAvatar(initials, size: OverviewTheme.coachAvatar)
            Text(label)
                .typeStyle(.chipSoft, color: name == nil ? Theme.inkFaint : Theme.inkSecondary)
                .lineLimit(1)
        }
        .padding(.leading, OverviewTheme.coachPillInset)
        .padding(.trailing, OverviewTheme.coachPillTrailing)
        .padding(.vertical, OverviewTheme.coachPillInset)
        .background(Theme.fill, in: Capsule(style: .continuous))
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
