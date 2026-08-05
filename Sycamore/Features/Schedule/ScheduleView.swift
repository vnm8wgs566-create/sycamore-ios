//
//  ScheduleView.swift
//  Sycamore
//
//  `8k` — Schedule, and `8f` — its empty state. "One card per block."
//
//  The day chips run Mon–Fri and the blocks below them are the camp's morning in time order.
//  What is drawn here today is `8f`, and that is not a placeholder standing in for the real
//  screen — `schedule_blocks` was created empty, so an empty Friday is what the data actually
//  says. The populated `8k` arrives when there are blocks to draw.
//
//  The design is careful about this screen in a way worth preserving: an empty day does not get
//  a shrug, it gets one obvious action ("Add the first block") and three shapes to start from.
//  Somebody setting up a camp at 7am should not have to invent a timetable from nothing.
//

import SwiftUI

struct ScheduleView: View {

    @Environment(AppStore.self) private var store
    /// Opens on today rather than on the design's Friday. `8f` happens to depict a Friday, but
    /// the day a person wants when they open Schedule is the one they are standing in.
    @State private var selectedDay: Weekday = .today

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            ScreenHeader(title: "Schedule", initials: store.avatarInitials) {
                store.pushedScreen = .profile
            }

            dayChips
                .padding(.bottom, 12)

            Hairline(color: Theme.hairline)

            ScrollView {
                emptyDay
                    .padding(.horizontal, Spacing.bar)
                    .padding(.top, Spacing.section)
                    .padding(.bottom, Spacing.tabBarClearance)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
    }

    // MARK: Day chips

    /// Five equal chips, the same row Early pick-up draws. `.day` metrics carry no horizontal
    /// padding by design — the width is meant to come from `fillsWidth`, and without it the
    /// chips shrink-wrap their labels and the row reads as five different-sized buttons.
    private var dayChips: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(Weekday.allCases) { day in
                Chip(
                    day.shortName,
                    isSelected: day == selectedDay,
                    selectedTone: .accent,
                    metrics: .day,
                    fillsWidth: true
                ) {
                    selectedDay = day
                }
            }
        }
        .padding(.horizontal, Spacing.bar)
    }

    // MARK: Empty state

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(selectedDay.fullName) is empty.")
                .typeStyle(.title2, color: Theme.ink)
                .padding(.bottom, Spacing.large)

            PrimaryButton("Add the first block") {
                // The block composer is a section 8 screen of its own and is not built yet.
                // Left inert rather than wired to a half-made sheet.
            }
            .padding(.bottom, Spacing.section)

            Text("Or start from a shape")
                .typeStyle(.sectionHeader, color: Theme.inkMuted)
                .padding(.bottom, Spacing.medium)

            VStack(spacing: Spacing.small) {
                ForEach(DayShape.allCases) { shape in
                    shapeRow(shape)
                }
            }
            .padding(.bottom, Spacing.large)

            Button("Copy Monday instead") {}
                .typeStyle(.body, color: Theme.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: 44)
        }
    }

    private func shapeRow(_ shape: DayShape) -> some View {
        Button {
            // Same as above — applying a shape writes blocks, and there is nothing to write to
            // on the device yet.
        } label: {
            CardRow(spacing: Spacing.medium, horizontalPadding: 14, verticalPadding: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shape.title)
                        .typeStyle(.rowTitle, color: Theme.ink)
                    Text(shape.detail)
                        .typeStyle(.meta, color: Theme.inkMuted)
                }
                Spacer(minLength: Spacing.small)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.chevron)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Schedule — empty") {
    ScheduleView()
        .environment(AppStore.preview)
        .showsMockStatusBar()
}
