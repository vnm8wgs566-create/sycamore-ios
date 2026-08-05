//
//  ScreenHeader.swift
//  Sycamore
//
//  The header every tab in section 8 draws: the screen's name on the left, an optional count
//  beside it, and the signed-in person's initials on the right.
//
//  The avatar is the one navigation affordance shared by all four tabs — it is how `8s Profile`
//  is reached, and through Profile how `8t Camp settings` and `8u Manage camps` are. Before
//  section 8 that corner held a bell that the design drew with an unread dot and gave no
//  destination; `GroupsHeader` had to render it as decoration rather than a button so it would
//  not report itself to VoiceOver as something you could press. This replaces it with a control
//  that goes somewhere.
//

import SwiftUI

struct ScreenHeader: View {

    let title: String
    /// The grey figure beside the title — "5 blocks", "2 short". Omitted when there is nothing
    /// worth counting.
    var count: String?
    /// Initials for the avatar. Nil or empty hides it — empty because `store.avatarInitials`
    /// is empty when signed out, and a blank grey disc is worse than no disc.
    var initials: String?
    var onAvatarTap: (() -> Void)?

    private var shownInitials: String? {
        guard let initials, !initials.isEmpty else { return nil }
        return initials
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Text(title)
                .typeStyle(.tabTitle, color: Theme.ink)

            if let count {
                Text(count)
                    .typeStyle(.meta, color: Theme.inkMuted)
            }

            Spacer(minLength: Spacing.small)

            if let shownInitials {
                avatar(shownInitials)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, Spacing.bar)
    }

    @ViewBuilder
    private func avatar(_ initials: String) -> some View {
        if let onAvatarTap {
            Button(action: onAvatarTap) {
                InitialsAvatar(initials, size: 34, tone: .neutral)
            }
            .buttonStyle(.plain)
            // The disc is drawn at 34 because that is what the design draws. The hit area is
            // widened to the 44pt minimum without moving the pixels — the same trick the
            // stepper and sheet-dismiss buttons use.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .accessibilityLabel("Your profile")
        } else {
            InitialsAvatar(initials, size: 34, tone: .neutral)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Previews

#Preview("Screen header") {
    VStack(spacing: 0) {
        ScreenHeader(title: "Overview", initials: "AR") {}
        Hairline(color: Theme.hairline)
        ScreenHeader(title: "Schedule", count: "5 blocks", initials: "AR") {}
        Hairline(color: Theme.hairline)
        ScreenHeader(title: "Inbox", initials: "AR") {}
        Spacer()
    }
    .background(Theme.surface)
}
