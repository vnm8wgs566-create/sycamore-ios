//
//  SettingsRow.swift
//  Sycamore
//
//  One line of a settings card, as `8s`, `8t` and `8u` all draw it: an optional glyph, a title
//  with an optional second line under it, and whatever closes the row on the right.
//
//  Section 8 asks for more endings than Profile's old private row could give — a value printed
//  flush right ("alex@uclacamp.org", "Tennis"), the invite code in mono, a lock, a switch, a
//  bare glyph — and it asks for them from three different screens. So the row lives here rather
//  than inside any one of them.
//
//  It belongs in `DesignSystem/` next to `Card` and `CardRow`; it is parked in `Profile/` only
//  because that is the folder this pass owns. Hoist it when the folders settle.
//

import SwiftUI

struct SettingsRow: View {

    /// What the row ends in. The design uses a different one on nearly every line, and the
    /// difference is load-bearing: a caret means the row goes somewhere, a lock means it is
    /// somebody else's to change, a value means the row is telling you something and stopping.
    enum Accessory {
        case chevron
        case lock
        /// Grey text on the trailing edge — `Email · alex@uclacamp.org`.
        case value(String)
        /// The invite code: mono, accent, wide-tracked.
        case code(String)
        case toggle(Binding<Bool>)
        /// A trailing SF Symbol, for rows the design closes with an icon rather than a caret.
        case glyph(String)
        /// Nothing. A row that says its piece and offers no ending.
        case plain
    }

    let title: String
    var icon: String?
    /// Overrides the muted glyph colour — the accent shuffle on `8t`'s "Partition by rank".
    var iconColor: Color = Theme.inkSecondary
    var subtitle: String?
    var accessory: Accessory = .chevron
    /// `Theme.danger` for "Archive this camp", which the design writes in red.
    var titleColor: Color = Theme.ink
    var action: (() -> Void)?

    init(
        _ title: String,
        icon: String? = nil,
        iconColor: Color = Theme.inkSecondary,
        subtitle: String? = nil,
        accessory: Accessory = .chevron,
        titleColor: Color = Theme.ink,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.subtitle = subtitle
        self.accessory = accessory
        self.titleColor = titleColor
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        CardRow(spacing: Spacing.row, horizontalPadding: 13, verticalPadding: 13) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(iconColor)
                    // The design's Phosphor glyphs are all one width; SF Symbols are not, so the
                    // column is pinned to keep every title on the same left edge.
                    .frame(width: 21)
                    // Decorative. The title says what the row is; "arrow left arrow right"
                    // in front of it only slows VoiceOver down.
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .typeStyle(.rowLabel, color: titleColor)
                if let subtitle {
                    Text(subtitle)
                        .typeStyle(.rowSubtitleSmall, color: Theme.inkFaint)
                }
            }

            Spacer(minLength: Spacing.small)
            accessoryView
        }
        // Title plus 13pt either side already clears 44 on one line; this holds the floor when
        // the reader has shrunk their type.
        .frame(minHeight: HitTarget.minimum)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            DisclosureChevron(size: 15)
        case .lock:
            DisclosureChevron(systemName: "lock", size: 15)
        case .value(let text):
            Text(text)
                .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        case .code(let code):
            Text(code)
                .typeStyle(.monoInline, color: Theme.accent)
                .lineLimit(1)
        case .toggle(let isOn):
            // The design's own 46×28 switch, not UIKit's 51×31. The switch carries no visible
            // text of its own, so the row lends it its title to speak.
            SycamoreToggle(isOn: isOn, label: title)
        case .glyph(let name):
            Image(systemName: name)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.inkSecondary)
        case .plain:
            EmptyView()
        }
    }
}

// MARK: - Previews

/// Hoisted to file scope: a `View` type declared inside a `#Preview` that also returns it makes
/// the compiler's symbol mangler recurse without bound. Same reason as `Components.swift`.
private struct SettingsRowPreviewHarness: View {
    @State private var notifications = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("You")
                Card {
                    SettingsRow("Email", accessory: .value("alex@uclacamp.org"))
                    SettingsRow("Emergency phone", subtitle: "Visible to admins") {}
                    SettingsRow("Notifications", accessory: .toggle($notifications))
                    SettingsRow(
                        "Your role here",
                        subtitle: "Only an admin can change this",
                        accessory: .lock
                    )
                }
                .padding(.bottom, Spacing.large)

                SectionHeader("Staff & joining", actionTitle: "Invite") {}
                Card {
                    SettingsRow(
                        "Invite code",
                        subtitle: "Anyone with it joins as a worker",
                        accessory: .code("SYC-4821")
                    )
                    SettingsRow("Roll a new code", accessory: .glyph("arrow.triangle.2.circlepath"))
                    SettingsRow(
                        "Partition by rank",
                        icon: "shuffle",
                        iconColor: Theme.accent,
                        subtitle: "Fills every court inside its limits",
                        accessory: .plain
                    ) {}
                    SettingsRow("Archive this camp", accessory: .plain, titleColor: Theme.danger)
                }
            }
            .padding(Spacing.gutter)
        }
        .background(Theme.grouped)
    }
}

#Preview("Settings rows") {
    SettingsRowPreviewHarness()
}
