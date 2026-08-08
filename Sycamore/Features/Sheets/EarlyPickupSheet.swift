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
                .typeStyle(.onTheDayLede, color: Theme.inkMuted)
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
                if let who = collectors[record.day], !who.isEmpty {
                    Text(who)
                        .typeStyle(.onTheDaySubtitle, color: Theme.inkMuted)
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

            HStack(spacing: Spacing.small) {
                timeField
                collectorField
            }
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
                // Mon–Fri abbreviated on screen, spoken in full: "Tue" is read as a word.
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(store.pickupDay == day ? .isSelected : [])
            }
        }
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

    /// No `.autocorrectionDisabled()`, unlike every other field in the app. This one is a
    /// person's name typed one-handed at the side of a court, and the four screens that switch
    /// autocorrect off are typing an address, an org name or a printed code — none of which the
    /// dictionary can help with. A name it can.
    private var collectorField: some View {
        let field = FormField(
            "Who collects",
            text: $collector,
            label: "Who collects",
            metrics: .sheetBox,
            type: .onTheDayValue,
            // A placeholder is one weight lighter than a value in this design — `400` against
            // the time field's `500` — so the two read apart before the colour difference lands.
            promptType: .onTheDayPlaceholder,
            icon: "person",
            focus: $isCollectorFocused
        )

        // Both travel down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        return field
        #endif
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
