//
//  EarlyPickupSheet.swift
//  Sycamore
//
//  `8n` — Leaving early. "As many pick-ups as the week needs."
//
//  This used to ask one question and answer it once: pick a day, pick a time, confirm, done. The
//  design asks for a week — a kid can go early on Tuesday for the orthodontist and again on
//  Thursday because Dad finishes at one — so the screen is now a list of what is already on the
//  books plus one card to add another. The confirm bar went with it: each pick-up is committed
//  by its own "Add pick-up", and the bar at the foot is just the way out.
//
//  Reached two ways, which is why `onClose` is a parameter: from the player sheet, where
//  `MainTabView` owns the presentation through `store.activeSheet`, and from `8m`, which
//  presents its own copy because a screen that is itself presented cannot ask the root to
//  present over it.
//

import SwiftUI

struct EarlyPickupSheet: View {

    @Bindable var store: AppStore
    let playerID: Player.ID
    /// How the sheet gets out of the way. Nil clears `store.activeSheet`, which is how
    /// `MainTabView` presents it.
    var onClose: (() -> Void)?

    /// Who collects, and the note under a pick-up. Neither has a column: `Attendance` carries a
    /// day, a present flag and a time and nothing else, so these are held here and are gone when
    /// the sheet is. See the PR body — they want a migration, not a workaround.
    @State private var collector: String = ""
    @State private var collectors: [Weekday: String] = [:]
    @FocusState private var isCollectorFocused: Bool

    var body: some View {
        SheetChrome(
            title: "Leaving early",
            subtitle: subtitle,
            detentFraction: OnTheDayTokens.pickupDetent,
            onClose: close
        ) {
            Text("Coaches see this on the day, in the block it falls in.")
                .typeStyle(.body, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Spacing.large)

            if !weekPickups.isEmpty {
                SheetSectionHeader("This week · \(weekPickups.count)")
                VStack(spacing: Spacing.small) {
                    ForEach(weekPickups) { record in
                        pickupCard(record)
                    }
                }
                .padding(.bottom, Spacing.large)
            }

            newPickup
                .padding(.bottom, Spacing.section)

            PrimaryButton(
                "Done",
                tone: .dark,
                height: OnTheDayTokens.barHeight,
                radius: Radius.button,
                font: .button,
                action: close
            )
        }
    }

    // MARK: - This week

    /// A card per pick-up already on the books, Monday first.
    private func pickupCard(_ record: Attendance) -> some View {
        let shape = RoundedRectangle(cornerRadius: OnTheDayTokens.card, style: .continuous)

        return HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label(for: record))
                    .typeStyle(.bodyStrong, color: Theme.ink)
                    .lineLimit(1)
                if let who = collectors[record.day], !who.isEmpty {
                    Text(who)
                        .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button { remove(record.day) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.chevron)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove the \(record.day.fullName) pick-up")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.gutterWide)
        // 8 rather than the design's 13: the ✕ carries a 44pt hit frame, and the two together
        // would make a one-line card half again as tall as the design draws it.
        .padding(.vertical, Spacing.small)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.hairline, lineWidth: BorderWidth.hairline) }
    }

    /// "Tuesday · 2:30pm"
    private func label(for record: Attendance) -> String {
        guard let leavesAt = record.leavesAt else { return record.day.fullName }
        return "\(record.day.fullName) · \(leavesAt.clockLabel)"
    }

    // MARK: - New pick-up

    private var newPickup: some View {
        let shape = RoundedRectangle(cornerRadius: OnTheDayTokens.card, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            Text("New pick-up")
                .typeStyle(.sectionHeader, color: Theme.accent)

            dayChips
                .padding(.top, Spacing.medium)

            HStack(spacing: Spacing.small) {
                timeField
                collectorField
            }
            .padding(.top, Spacing.small)

            PrimaryButton(
                addLabel,
                tone: .accent,
                systemImage: "plus",
                height: OnTheDayTokens.compactButtonHeight,
                radius: Radius.tile,
                font: .buttonSmall,
                action: addPickup
            )
            .padding(.top, Spacing.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.gutterWide)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline) }
    }

    /// Five equal chips. `fillsWidth` plus a plain `HStack` gives the design's `flex:1` row.
    ///
    /// Selected draws black rather than green, which is what the design has: this card is
    /// already outlined in green, overlined in green and closed by a green button, and a green
    /// chip inside it stops reading as the selection.
    ///
    /// The `Chip` is drawn without an action and wrapped in a button of our own: `.day` metrics
    /// come out about 40pt tall, and `Chip` clips its own hit region to exactly what it drew.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
                Button { select(day) } label: {
                    Chip(
                        day.shortName,
                        isSelected: store.pickupDay == day,
                        selectedTone: .dark,
                        metrics: .day,
                        fillsWidth: true
                    )
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.pickupDay == day ? .isSelected : [])
            }
        }
    }

    private var timeField: some View {
        Menu {
            Picker("Leaves at", selection: $store.pickupTime) {
                ForEach(TimeOfDay.pickupOptions) { time in
                    Text(time.clockLabel).tag(time)
                }
            }
        } label: {
            field(systemImage: "clock") {
                Text(store.pickupTime.clockLabel)
                    .typeStyle(.bodyAlt.lineHeight(nil), color: Theme.ink)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Leaves at")
        .accessibilityValue(store.pickupTime.clockLabel)
    }

    private var collectorField: some View {
        field(systemImage: "person") {
            ZStack(alignment: .leading) {
                if collector.isEmpty {
                    Text("Who collects")
                        .typeStyle(.bodyAlt.lineHeight(nil), color: Theme.inkFaint)
                }
                collectorInput
            }
        }
        // A `TextField` only takes a tap on the glyphs it has drawn, which on an empty field is
        // none of it. The box is the target.
        .contentShape(.rect)
        .onTapGesture { isCollectorFocused = true }
    }

    private var collectorInput: some View {
        let base = TextField("", text: $collector)
            .textFieldStyle(.plain)
            .typeStyle(.bodyAlt.lineHeight(nil), color: Theme.ink)
            .focused($isCollectorFocused)
            .accessibilityLabel("Who collects")

        #if os(iOS)
        return base
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return base
        #endif
    }

    /// The design's bordered field: an icon, a value, and 13pt of gutter either side.
    private func field(systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)

        return HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnTheDayTokens.cardInset)
        .padding(.vertical, Spacing.row)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.stroke, lineWidth: BorderWidth.hairline) }
        // The box keeps the height the design draws it at; only the touch reaches 44.
        .frame(minHeight: HitTarget.minimum)
    }

    /// A day that already has a pick-up is edited, not doubled — `setEarlyPickup` upserts one
    /// row per day. The label says so rather than letting the button quietly overwrite.
    private var addLabel: String {
        store.camp?.leavesAt(playerID, on: store.pickupDay) == nil ? "Add pick-up" : "Update pick-up"
    }

    // MARK: - Reads

    /// "Austin Z · Court 1" — the breadcrumb the design puts above the title.
    private var subtitle: String? {
        guard let player = store.player(playerID) else { return nil }
        let court = player.groupID.flatMap { store.group($0)?.label }
        return [player.displayName, court].compactMap { $0 }.joined(separator: " · ")
    }

    /// Every day this kid leaves early, Monday first. Sparse by construction — `Attendance`
    /// only holds a row when something differs from "here all day".
    private var weekPickups: [Attendance] {
        (store.camp?.attendance ?? [])
            .filter { $0.playerID == playerID && $0.leavesAt != nil }
            .sorted { $0.day.rawValue < $1.day.rawValue }
    }

    // MARK: - Writes

    /// Picking a day that already has a pick-up loads it, so the card edits that one rather than
    /// offering to replace it with whatever was last typed.
    private func select(_ day: Weekday) {
        store.pickupDay = day
        if let existing = store.camp?.leavesAt(playerID, on: day) {
            store.pickupTime = existing
        }
        collector = collectors[day] ?? ""
    }

    private func addPickup() {
        let day = store.pickupDay
        let who = collector.trimmingCharacters(in: .whitespacesAndNewlines)
        collectors[day] = who.isEmpty ? nil : who
        Task { await store.setEarlyPickup(playerID: playerID, day: day, at: store.pickupTime) }
    }

    private func remove(_ day: Weekday) {
        collectors[day] = nil
        if day == store.pickupDay { collector = "" }
        Task { await store.clearEarlyPickup(playerID: playerID, day: day) }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            store.dismissSheet()
        }
    }
}

// MARK: - Previews

/// Austin Z with two pick-ups already on the books — the state the design draws.
@MainActor
private func pickupPreviewStore() -> AppStore {
    let store = AppStore.preview
    if var camp = store.camp {
        camp.setEarlyPickup(playerID: SampleData.austinZ.id, day: .tue, leavesAt: TimeOfDay(14, 30))
        camp.setEarlyPickup(playerID: SampleData.austinZ.id, day: .thu, leavesAt: TimeOfDay(13, 0))
        store.camp = camp
    }
    store.pickupDay = .fri
    store.pickupTime = TimeOfDay(12, 0)
    return store
}

#Preview("Leaving early") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        EarlyPickupSheet(store: pickupPreviewStore(), playerID: SampleData.austinZ.id)
            .frame(height: 616)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Leaving early — nothing booked") {
    let store = AppStore.preview
    store.pickupDay = .wed
    store.pickupTime = TimeOfDay(14, 30)

    return ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()
        EarlyPickupSheet(store: store, playerID: SampleData.sereneC.id)
            .frame(height: 480)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
