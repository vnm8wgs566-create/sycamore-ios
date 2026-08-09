//
//  BlockPickRow.swift
//  Sycamore
//
//  One row of a card you choose from: a title, the line under it, and a tick on the right.
//
//  The block editor asks four "which of these" questions — what kind of block this is, which
//  courts it runs on, what to do with the kids, and who is on it — and drew the same row four
//  times to ask them, with four declarations of the same `@ScaledMetric` for the same glyph. The
//  differences were an avatar on one and an accessibility hint on three, which is a row with two
//  optional parts rather than four rows.
//
//  ── Single- and multi-select draw the same ────────────────────────────────────────────────────
//
//  Deliberately, and it is worth defending. The kind picker is pick-one and the court picker is
//  pick-several, and both wear `checkmark.circle.fill` over `circle`. A third glyph for "chosen,
//  but only one of these" would be a third vocabulary on one sheet, learned by a reader who is
//  already being asked four questions. What tells them apart is what happens on the tap — picking
//  one kind clears the other — and, for VoiceOver, `.isSelected`, which reads out over exactly one
//  row in a single-select card and over several in a multi-select one.
//
//  The empty circle on the unpicked rows is not decoration. A column of ticks with gaps in it
//  reads as a list where some rows have a state and others do not, which is the opposite of what
//  either kind of card is saying.
//

import SwiftUI

struct BlockPickRow: View {

    let title: String
    /// The grey line under it: "A title and a time", "8 kids · Nass", "Worker · Sycamore".
    let detail: String
    let isOn: Bool
    /// A person's initials, for the rows that are about people. Nil everywhere else — a court has
    /// no face.
    var initials: String?
    /// What the tap will do, when that is worth saying. The single-select rows leave it nil: their
    /// title already is the answer, where "Court 3" does not say what ticking it means.
    var hint: String?
    let select: () -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize = ScheduleMetrics.assigneeAvatar
    @ScaledMetric(relativeTo: .body) private var checkSize = ScheduleMetrics.pickerCheck

    var body: some View {
        Button(action: select) {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                if let initials {
                    InitialsAvatar(initials, size: avatarSize)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(title)
                        .typeStyle(ScheduleType.assigneeName, color: Theme.ink)

                    // Allowed to wrap. "Worker · Sycamore · Court 3" is three segments long, and
                    // truncating the last of them at an accessibility size hides the court — which
                    // is the part that says whether this is the right person for the block.
                    Text(detail)
                        .typeStyle(ScheduleType.assigneeMeta, color: Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.small)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkSize, weight: .regular))
                    .foregroundStyle(isOn ? Theme.accent : Theme.chevron)
                    .accessibilityHidden(true)
            }
            // Grown, then shaped — that order is load-bearing. Reversed, the hit region would be
            // pinned to what is drawn and the added height would be inert. `Chip` states the same
            // rule at `Components.swift:374-379`, where it was learned from a finger.
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(hint ?? "")
    }
}

// MARK: - Previews

#Preview("Pick rows") {
    Card(radius: ScheduleMetrics.cardRadius) {
        BlockPickRow(
            title: "Courts & coaches",
            detail: "Says which courts are running and who is on them.",
            isOn: true,
            select: {}
        )
        BlockPickRow(title: "Court 2", detail: "8 kids · Nass", isOn: false, select: {})
        BlockPickRow(
            title: "Nass",
            detail: "Worker · Sycamore · Court 1",
            isOn: true,
            initials: "N",
            hint: "Takes them off this block",
            select: {}
        )
    }
    .padding(Spacing.gutter)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}
