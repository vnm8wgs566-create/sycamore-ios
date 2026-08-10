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
    /// The line under it: "Kids and coaches are placed court by court.", "Nass coaches here",
    /// "Free at 10:30".
    let detail: String
    /// What colour that line is drawn in, because on this sheet it is three different kinds of
    /// statement (`design/rebuild/section-t5.html:104-106, 118-119`).
    ///
    /// Grey is the default and the commonest: a fact about the row that changes nothing. Amber is
    /// a court with nobody on it or a coach who is already busy — a thing to know before you save,
    /// never a thing that stops you saving, which is the rule this whole sheet is built on. Accent
    /// is a coach who is free right now, the one line worth reading as good news.
    ///
    /// A `Color` rather than a state enum, because the row does not need to know *why*: the two
    /// pickers above it are the ones that can tell a closed court from an unstaffed one, and a
    /// third opinion here would be a fourth place to keep the reading in step.
    var detailColor: Color = Theme.inkMuted
    let isOn: Bool
    /// Drawn back — a closed court, on a sheet that will happily still let you tick it.
    ///
    /// Title in `inkFaint` and the empty ring a shade lighter, exactly as `5b` draws Court 4
    /// (`design/rebuild/section-t5.html:106`). What it deliberately does **not** do is disable the
    /// button. `PlayerCourtPicker.swift:25` states the house rule from the other sheet that faced
    /// this — "a full or closed court is flagged, not blocked" — and there are two reasons it holds
    /// harder here. A block already naming a court that shut this morning would otherwise be a row
    /// you cannot untick; and this sheet writes a *timetable*, possibly for Thursday, where a net
    /// that is down today is not a fact about Thursday at all.
    var isMuted: Bool = false
    /// A person's initials, for the rows that are about people. Nil everywhere else — a court has
    /// no face.
    var initials: String?
    /// What the tap will do, when that is worth saying. The single-select rows leave it nil: their
    /// title already is the answer, where "Court 3" does not say what ticking it means.
    var hint: String?
    let select: () -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize = ScheduleMetrics.assigneeAvatar
    @ScaledMetric(relativeTo: .body) private var checkSize = ScheduleMetrics.pickTick

    var body: some View {
        Button(action: select) {
            CardRow(spacing: Spacing.row, verticalPadding: Spacing.row) {
                if let initials {
                    InitialsAvatar(initials, size: avatarSize)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    // `rowLabel` (`600 14.5`, `-.02em`) and not `rowTitleSm` (`600 14`): the
                    // design sets every pick-row title on this sheet at 14.5, where 14 is what
                    // `8l`'s "Who is where" list used for a person who was being *reported* rather
                    // than chosen (`design/rebuild/section-t5.html:70`). That list is gone with
                    // `8l`, and so is `ScheduleType.assigneeName`, which is what this used to name
                    // the smaller size by.
                    Text(title)
                        .typeStyle(ScheduleType.pickRowTitle, color: isMuted ? Theme.inkFaint : Theme.ink)

                    // Allowed to wrap. "Spread every kid over these courts" wraps at the default
                    // size and "Free at 10:30 · Court 2 until then" wraps a step above it, and
                    // truncating either hides the half that says whether to tap the row.
                    Text(detail)
                        .typeStyle(ScheduleType.assigneeMeta, color: detailColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.small)

                // The unpicked ring is `stroke` rather than `chevron` — `1.5px solid #E4E5E9`,
                // which is the rule the design draws around every empty field on this sheet, so an
                // empty circle and an empty box are the same absence. A muted row takes it a shade
                // lighter again, the way `5b` draws Court 4's.
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkSize, weight: .regular))
                    .foregroundStyle(isOn ? Theme.accent : (isMuted ? Theme.hairline : Theme.stroke))
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

/// Every reading of the grey line in one card, which is the point of the row having a colour at
/// all: a fact, a warning, a court that is shut, and a coach who is free.
#Preview("Pick rows") {
    Card(radius: ScheduleMetrics.cardRadius) {
        BlockPickRow(
            title: "On courts",
            detail: "Kids and coaches are placed court by court.",
            isOn: true,
            select: {}
        )
        BlockPickRow(title: "Court 1", detail: "Nass coaches here", isOn: true, select: {})
        BlockPickRow(
            title: "Court 2",
            detail: "Needs a coach",
            detailColor: Theme.warning,
            isOn: true,
            select: {}
        )
        BlockPickRow(
            title: "Court 4",
            detail: "Closed — Net down",
            detailColor: Theme.inkFaint,
            isOn: false,
            isMuted: true,
            select: {}
        )
        BlockPickRow(
            title: "Nass",
            detail: "Free now · roaming",
            detailColor: Theme.accent,
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
