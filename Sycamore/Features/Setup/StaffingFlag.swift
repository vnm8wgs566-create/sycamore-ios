//
//  StaffingFlag.swift
//  Sycamore
//
//  The amber "2 SHORT" flag beside a venue's name on `8t`.
//
//  It was drawn with `Badge(tone: .accent)` — green, the colour this app uses for *good* — which
//  said the opposite of what the row means. The design sets it in the warning family: a
//  `warningTint` plate under a `warningDark` label, which is the third severity step between
//  "fine" and "destructive". Nobody is deleting anything; a court is two coaches light.
//
//  `Badge` cannot express it. It has no amber tone and its type is fixed at `700 9.5`, where the
//  design draws this at `600 10`. So the flag is its own view, and `BadgeTone.warning` is a hoist
//  candidate the PR body names.
//

import SwiftUI

struct StaffingFlag: View {

    let text: String

    /// `padding:3px 6px` — the same inset `Badge` uses, which is the shape this stands in for.
    private let verticalInset: CGFloat = 3

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .typeStyle(.flagLabel, color: Theme.warningDark)
            .lineLimit(1)
            .padding(.horizontal, Spacing.tight)
            .padding(.vertical, verticalInset)
            .background(
                Theme.warningTint,
                in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
            )
    }
}

extension StaffingStatus {

    /// `2 short` — the flag's own wording.
    ///
    /// `badgeText` spells the same state "2 coaches short", which is the sentence the venue sheet
    /// wants. Here the flag shares a line with the venue's name and a 100pt stepper, so the design
    /// drops the noun: what else at a tennis camp would a venue be short of?
    ///
    /// `nil` when the venue is staffed, so the row can leave the flag off entirely rather than
    /// draw a reassuring green chip the design does not have.
    var flagText: String? {
        switch self {
        case .inRange: nil
        case .coachesShort(let count): "\(count) short"
        case .coachesOver(let count): "\(count) over"
        }
    }
}

// MARK: - Previews

#Preview("Staffing flag") {
    HStack(spacing: Spacing.nameBadge) {
        Text("LATC").typeStyle(.cardTitleSm, color: Theme.ink)
        StaffingFlag(StaffingStatus.coachesShort(2).flagText ?? "")
        StaffingFlag(StaffingStatus.coachesOver(1).flagText ?? "")
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
