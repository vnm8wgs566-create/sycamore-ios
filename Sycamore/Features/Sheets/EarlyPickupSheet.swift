//
//  EarlyPickupSheet.swift
//  Sycamore
//
//  Screen 10 — early pick-up. Two answers, and a confirm bar that reads back exactly what is
//  currently selected so nobody has to re-read the chips to know what they are about to save.
//

import SwiftUI

struct EarlyPickupSheet: View {
    let store: AppStore
    let playerID: Player.ID

    var body: some View {
        SheetChrome(
            title: "Early pick-up",
            subtitle: subtitle,
            detentFraction: ActiveSheet.earlyPickup(playerID).detentFraction,
            onClose: { store.dismissSheet() }
        ) {
            SheetSectionHeader("Which day")
            dayChips
                .padding(.bottom, 20)

            SheetSectionHeader("Leaves at")
            timePills
                .padding(.bottom, Spacing.section)

            confirmBar
        }
    }

    private var subtitle: String {
        guard let name = store.player(playerID)?.displayName else {
            return "Leaves before the session ends"
        }
        return "\(name) — leaves before the session ends"
    }

    // MARK: - Which day

    /// Five equal chips. `fillsWidth` plus a plain `HStack` gives the design's `flex:1` row.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
                Chip(
                    day.shortName,
                    isSelected: store.pickupDay == day,
                    selectedTone: .accent,
                    metrics: .day,
                    fillsWidth: true
                ) {
                    store.pickupDay = day
                }
            }
        }
    }

    // MARK: - Leaves at

    private var timePills: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(TimeOfDay.pickupOptions) { time in
                Chip(
                    time.formatted,
                    isSelected: store.pickupTime == time,
                    selectedTone: .tintedBold,
                    metrics: .time
                ) {
                    store.pickupTime = time
                }
            }
        }
    }

    // MARK: - Confirm

    /// 15pt of padding around a 15pt bold label — 50pt tall, which is why the height is spelled
    /// out rather than left to `PrimaryButton`'s 56.
    private var confirmBar: some View {
        PrimaryButton(
            store.pickupConfirmLabel,
            tone: .accent,
            height: 50,
            radius: Radius.row,
            font: .buttonSmall
        ) {
            Task { await store.confirmEarlyPickup(for: playerID) }
        }
    }
}

// MARK: - Previews

#Preview("Early pick-up") {
    let store = AppStore.preview
    store.pickupDay = .wed
    store.pickupTime = TimeOfDay(14, 30)

    return ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        EarlyPickupSheet(store: store, playerID: SampleData.austinZ.id)
            .frame(height: 472)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Early pick-up — Friday 12:30") {
    let store = AppStore.preview
    store.pickupDay = .fri
    store.pickupTime = TimeOfDay(12, 30)

    return ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        EarlyPickupSheet(store: store, playerID: SampleData.sereneC.id)
            .frame(height: 472)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
