//
//  StaffAvatarStack.swift
//  Sycamore
//
//  The overlapping discs at the head of `8t`'s staff row — `NA HU AL`, each pulled 8pt over the
//  one before it and ringed in the surface colour so the overlap reads as depth rather than as a
//  smudge. It is the design's shorthand for "there are people here", not a list of them.
//

import SwiftUI

struct StaffAvatarStack: View {

    let members: [StaffMember]
    /// `26px` in the design.
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: -8) {
            ForEach(members) { member in
                InitialsAvatar(
                    member.initials,
                    size: size,
                    tone: member.role.isAdmin ? .dark : .neutral
                )
                .overlay { Circle().strokeBorder(Theme.surface, lineWidth: BorderWidth.focus) }
            }
        }
        // Three initials read aloud say nothing the row's own "14 staff" does not.
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Staff avatar stack") {
    StaffAvatarStack(members: Array(SampleData.uclaTennisCamp.staff.prefix(3)))
        .padding(Spacing.bar)
        .background(Theme.surface)
}
