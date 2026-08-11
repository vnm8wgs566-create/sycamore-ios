//
//  CampDaysPicker.swift
//  Sycamore
//
//  Seven chips, and which of them are lit is the camp's operating week.
//
//  Two screens ask the same question — "Shape the camp" asks it while the camp is being drawn and
//  Camp settings asks it every day after — so the row is a component rather than a shape copied
//  into both. The chips are `ChipMetrics.day`, the row `ScheduleView`, `BlockEditorSheet` and
//  `EarlyPickupSheet` already draw a week with; the difference here is that every chip is
//  independent, because a camp runs a *set* of days rather than sitting on one of them.
//
//  Those three hand-roll the button around the chip to reach the 44pt minimum. This does not, and
//  the difference is a fix that landed after they were written: `Chip` grows its own target when
//  it is handed an action (`Components.swift:365-383`, "what makes those workarounds unnecessary
//  rather than merely redundant"). Repeating it here would be a second `contentShape` over the
//  one the chip already draws.
//
//  The one rule this control keeps is that the last day on cannot be switched off — the floor
//  `CampDays.toggling(_:)` states and `camps_camp_days_check` enforces. Refusing the tap is what
//  stops an empty set reaching a CHECK that answers in the language of constraints, and the chip
//  that cannot be turned off is `disabled`, so VoiceOver says "dimmed" rather than leaving a tap
//  unexplained. The caption beside the row says it in words; see `CampDays.countLine`.
//

import SwiftUI

struct CampDaysPicker: View {

    @Binding var days: CampDays

    var body: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
                dayChip(day)
            }
        }
        .sensoryFeedback(.selection, trigger: days)
    }

    /// One day.
    ///
    /// Black when lit, not green. Both screens this appears on draw their own selected chips
    /// black — `8b`'s sport row, `8t`'s role chips — while `ScheduleView` and `BlockEditorSheet`
    /// draw day chips green because they are answering a different question: which single day you
    /// are *looking at*, rather than which days the camp is open.
    ///
    /// "Cannot be tapped" is asked of `toggling` rather than derived beside it, so the drawn
    /// refusal and the real one are the same rule by construction — a second `count == 1` test
    /// here would be free to drift into a chip that looks live and does nothing.
    ///
    /// `.disabled` and `.accessibilityHint` both take the value rather than branching on it: an
    /// `if` would change the chip's structural identity at the moment it became the last one,
    /// tearing down and rebuilding the button under the finger that had just pressed the day
    /// beside it.
    private func dayChip(_ day: Weekday) -> some View {
        let isOn = days.contains(day)
        let isOnlyDay = days.toggling(day) == days

        return Chip(
            day.shortName,
            isSelected: isOn,
            metrics: .day,
            fillsWidth: true
        ) {
            days = days.toggling(day)
        }
        .disabled(isOnlyDay)
        // Abbreviated on screen, spoken in full: "Tue" is read as a word.
        .accessibilityLabel(day.fullName)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isOnlyDay ? "A camp has to run at least one day" : "")
    }
}

// MARK: - Previews

/// Hoisted to file scope for the reason `SettingsRow.swift:138-139` gives: a `View` declared
/// inside a `#Preview` that also returns it makes the compiler's symbol mangler recurse.
private struct CampDaysPickerPreviewHarness: View {
    @State private var weekdays = CampDays.weekdays
    @State private var weekend = CampDays([.sat, .sun])
    @State private var single = CampDays([.wed])

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            row("Monday to Friday", days: $weekdays)
            row("A Saturday club", days: $weekend)
            // The last day on is drawn lit and refuses the tap.
            row("One day only", days: $single)
        }
        .padding(Spacing.gutterWide)
        .background(Theme.surfaceWarm)
    }

    private func row(_ title: String, days: Binding<CampDays>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .typeStyle(.intakeOverline, color: Theme.inkTertiary)
            CampDaysPicker(days: days)
            Text("\(days.wrappedValue.summaryLine) · \(days.wrappedValue.countLine)")
                .typeStyle(.intakeRowMeta, color: Theme.inkMuted)
        }
    }
}

#Preview("Camp days") {
    CampDaysPickerPreviewHarness()
}
