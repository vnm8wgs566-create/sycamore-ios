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
//  Reached two ways — from `8m` and from `8q` — and presented by whichever one opened it rather
//  than by `MainTabView`. Both of those are themselves presented screens, and a presented screen
//  cannot ask the root underneath it to present over it, so each holds its own `PickupTarget` and
//  puts this sheet up from there. That is why `onClose` is a parameter: the state holding the
//  sheet open belongs to the caller, so the caller is the only one who can put it down.
//

import SwiftUI

struct EarlyPickupSheet: View {

    @Bindable var store: AppStore
    let playerID: Player.ID
    /// How the sheet gets out of the way: it clears the `PickupTarget` the caller is holding.
    /// Both callers pass one. Optional for the previews below, which draw the sheet inline and
    /// have nothing to put down.
    var onClose: (() -> Void)?

    // **"Who collects" is gone.** It asked a real question into a `@State` with no column
    // behind it: `Attendance` carries a day, a present flag and a time and nothing else, so a
    // name typed at the side of a court survived until the sheet closed and then did not exist.
    // A field that quietly discards what a parent told you is worse than no field.
    //
    // The design's leave record is a day and a time, which is what this sheet now collects. If
    // it should ask again it needs a column first, and the schema is the place to start.

    var body: some View {
        SheetChrome(
            title: "Leaving early",
            subtitle: subtitle,
            detentFraction: OnTheDayTokens.pickupDetent,
            onClose: close
        ) {
            Text("Coaches see this on the day, in the block it falls in.")
                .typeStyle(.onTheDayLede, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, OnTheDayTokens.headerTop)

            if !weekPickups.isEmpty {
                AttendanceOverline(title: "This week", count: weekPickups.count, inset: 0)
                VStack(spacing: OnTheDayTokens.contentGap) {
                    ForEach(weekPickups) { record in
                        pickupCard(record)
                    }
                }
                .padding(.bottom, OnTheDayTokens.contentGap)
            }

            newPickup
                .padding(.bottom, Spacing.section)

            PrimaryButton(
                "Done",
                tone: .dark,
                height: OnTheDayTokens.barHeight,
                radius: Radius.button,
                font: .onTheDayBar,
                action: close
            )
            // No `barShadow` here, unlike `8m`. The design pins this bar over the content and
            // lifts it off the page; presented as a sheet it is the last thing in a scroll, and
            // a shadow under something that is not floating reads as a rendering fault.
        }
    }

    // MARK: - This week

    /// A card per pick-up already on the books, Monday first.
    private func pickupCard(_ record: Attendance) -> some View {
        let shape = RoundedRectangle(cornerRadius: OnTheDayTokens.card, style: .continuous)

        return HStack(spacing: OnTheDayTokens.blockGap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label(for: record))
                    .typeStyle(.onTheDayName, color: Theme.ink)
                    .lineLimit(1)
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
        .padding(.horizontal, OnTheDayTokens.cardInsetWide)
        // 8 rather than the design's 13: the ✕ carries a 44pt hit frame, which is already taller
        // than a one-line card's copy, and the two together would make the card half again as
        // tall as the design draws it. The height it lands on is the design's; the padding that
        // gets there is not.
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
            // A plain label rather than `AttendanceOverline`: this one opens a card rather than a
            // section, and the design gives it 12pt of air below where a section overline gets 9.
            Text("New pick-up")
                .typeStyle(.onTheDayOverline, color: Theme.accent)
                .accessibilityAddTraits(.isHeader)

            dayChips
                .padding(.top, Spacing.medium)

            timeField
                .padding(.top, OnTheDayTokens.blockGap)

            PrimaryButton(
                addLabel,
                tone: .accent,
                systemImage: "plus",
                height: OnTheDayTokens.compactButtonHeight,
                radius: Radius.tile,
                font: .onTheDayAdd,
                action: addPickup
            )
            .padding(.top, OnTheDayTokens.blockGap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OnTheDayTokens.cardInsetWide)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.accentBorder, lineWidth: BorderWidth.hairline) }
    }

    /// One chip per day the camp actually runs — `fillsWidth` plus a plain `HStack` gives the
    /// design's `flex:1` row.
    ///
    /// **Off `camp.days`, not off `Weekday.allCases`.** This comment claimed "five equal chips"
    /// and the code drew seven: `Weekday` synthesises `allCases` over all seven, so a Monday-to-
    /// Friday camp offered a Saturday pick-up that no block could ever fall in and no coach would
    /// ever see. The comment was right about the design and wrong about the code beneath it,
    /// which is the shape of every bug in this file.
    ///
    /// Selected draws black rather than green, which is what the design has: this card is
    /// already outlined in green, overlined in green and closed by a green button, and a green
    /// chip inside it stops reading as the selection.
    ///
    /// The `Chip` is drawn without an action and wrapped in a button of our own: `.day` metrics
    /// come out about 40pt tall, and `Chip` clips its own hit region to exactly what it drew.
    /// The camp's own days, in week order, falling back to the whole week only when there is no
    /// camp to ask — a preview, or a sheet outliving its store. A camp with no days set at all
    /// would otherwise draw an empty row and no way to choose one.
    private var campDays: [Weekday] {
        let days = Weekday.allCases.filter { store.camp?.days.contains($0) ?? false }
        return days.isEmpty ? Weekday.allCases : days
    }

    /// Moves the selection onto a day the camp actually runs.
    ///
    /// **Filtering the chips was only half of it**, which is the shape of the original bug rather
    /// than a new one: `store.pickupDay` defaults to `.today`, so a coach opening this on a
    /// Saturday at a Monday-to-Friday camp saw five chips with **none of them lit** and a button
    /// that would write a Saturday pick-up no block could ever contain. Taking the chip away
    /// stopped it being *offered*; it did not stop it being *held*.
    ///
    /// The next running day rather than the first, so a Saturday lands on Monday and a Wednesday
    /// at a Mon/Wed/Fri camp stays where it is.
    private func clampPickupDayToCampDays() {
        let days = campDays
        guard !days.isEmpty, !days.contains(store.pickupDay) else { return }
        let today = store.pickupDay.rawValue
        store.pickupDay = days.first { $0.rawValue > today } ?? days[0]
    }

    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(campDays) { day in
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
                // Mon–Fri abbreviated on screen, spoken in full: "Tue" is read as a word.
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(store.pickupDay == day ? .isSelected : [])
            }
        }
        // Runs when the sheet opens and again if the camp's days change under it. Without it the
        // row can draw a full set of chips with none of them lit — see
        // `clampPickupDayToCampDays`.
        .onChange(of: campDays, initial: true) { _, _ in clampPickupDayToCampDays() }
    }

    /// A menu wearing the same box as the field beside it. `.sheetBox` is where that box lives
    /// now — this one is not a `TextField`, so it borrows the chrome rather than the component,
    /// and the two stop being two drawings of the same thing that have to be kept in step.
    private var timeField: some View {
        Menu {
            Picker("Leaves at", selection: $store.pickupTime) {
                ForEach(TimeOfDay.pickupOptions) { time in
                    Text(time.clockLabel).tag(time)
                }
            }
        } label: {
            Text(store.pickupTime.clockLabel)
                .typeStyle(.onTheDayValue, color: Theme.ink)
                .formFieldChrome(.sheetBox, icon: "clock")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Leaves at")
        .accessibilityValue(store.pickupTime.clockLabel)
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
    }

    private func addPickup() {
        let day = store.pickupDay
        Task { await store.setEarlyPickup(playerID: playerID, day: day, at: store.pickupTime) }
    }

    private func remove(_ day: Weekday) {
        Task { await store.clearEarlyPickup(playerID: playerID, day: day) }
    }

    /// No `store.dismissSheet()` fallback: with `8n` off `ActiveSheet` there is nothing of this
    /// sheet's in that slot, so clearing it could only ever close a venue or staff sheet that
    /// happened to be open underneath.
    private func close() {
        onClose?()
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
