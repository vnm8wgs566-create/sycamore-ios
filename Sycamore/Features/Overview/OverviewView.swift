//
//  OverviewView.swift
//  Sycamore
//
//  `8i` / `8j` — Overview. "Every court, its coach and its kids."
//
//  The first tab, and the one the app opens on: on a camp morning the question is which courts
//  are running, who has them and how many kids are there. The design draws it two ways — an
//  admin sees every court in order, a coach sees their own court first under "Your court" with
//  the rest below under "Other courts".
//
//  This half loads; `OverviewScreen` draws. The three reads it needs are the three the section
//  8 repository offers, and all three come back empty today because nothing on the device
//  talks to Postgres yet:
//
//      courts          -> `today_courts`, stood in for by `TodayCourts.derive` over the camp
//                         graph the app has already loaded. Every column that view selects is
//                         in the graph; none of it is invented.
//      schedule blocks -> the activity on each court, and "Skills rotation · until 10:30".
//                         Nothing is drawn in their place — the header says which venue is on
//                         screen instead, which is true whether or not a day is planned.
//      inbox items     -> the pinned note above the courts. No note, no banner.
//
//  So the screen is complete the moment any of the three has rows, and honest until then.
//

import SwiftUI

struct OverviewView: View {

    @Environment(AppStore.self) private var store

    /// Courts exactly as the repository returned them. Empty is the ordinary case for now, and
    /// `courts` below is where that is answered.
    @State private var loadedCourts: [CourtCard] = []
    @State private var blocks: [ScheduleBlock] = []
    @State private var inbox: [InboxItem] = []

    var body: some View {
        OverviewScreen(
            store: store,
            courts: courts,
            pinnedNote: pinnedNote,
            blockNote: runningBlock?.notes.first,
            nowLine: nowLine
        )
        .task(id: venueID) { await load() }
    }

    // MARK: What the screen draws

    /// The venue this screen is about: the one you are standing in, or the camp's first when
    /// you are standing in none of them.
    private var venueID: Venue.ID? {
        store.myStaffRecord?.venueID
            ?? store.todayAssignment?.venueID
            ?? store.camp?.orderedVenues.first?.id
    }

    /// Derived rather than held in `@State` so the cards stay honest between loads: marking a
    /// kid away anywhere in the app changes a headcount here on the next pass.
    private var courts: [CourtCard] {
        if !loadedCourts.isEmpty { return loadedCourts }
        guard let camp = store.camp, let venueID else { return [] }
        return TodayCourts.derive(
            forVenue: venueID, in: camp, activity: runningBlock?.title, day: store.today
        )
    }

    private var runningBlock: ScheduleBlock? {
        TodayCourts.running(in: blocks, at: TodayCourts.now())
    }

    /// The design banners one note. Items arrive newest first, so the newest one still standing
    /// is the one the morning is about.
    private var pinnedNote: InboxItem? {
        inbox.first { $0.kind == .note && !$0.resolved }
    }

    /// "Skills rotation · until 10:30" while a block is running.
    private var nowLine: String? {
        if let runningBlock {
            guard let ends = runningBlock.endsAt else { return runningBlock.title }
            return "\(runningBlock.title) · until \(ends.formatted)"
        }
        // Nothing scheduled: name the venue on screen instead. An admin can be responsible for
        // more than one and every venue numbers its courts from 1, so which one this is is the
        // most useful thing the line can say.
        guard let venue = venueID.flatMap({ store.venue($0) }) else { return nil }
        return "\(venue.name) · \(courts.count) court\(courts.count == 1 ? "" : "s")"
    }

    // MARK: Loading

    private func load() async {
        guard let campID = store.camp?.id, let venueID else { return }
        do {
            loadedCourts = try await store.repository.courts(forVenue: venueID, campID: campID)
            blocks = try await store.repository.scheduleBlocks(
                forVenue: venueID, day: store.today, campID: campID
            )
            inbox = try await store.repository.inboxItems(forVenue: venueID, campID: campID)
        } catch {
            // The tab shell is already watching `errorMessage` and floats the banner for it.
            store.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

#Preview("Overview — on a court") {
    OverviewView()
        .environment(AppStore.preview)
        .showsMockStatusBar()
}

#Preview("Overview — admin") {
    OverviewView()
        .environment(OverviewFixtures.adminStore)
        .showsMockStatusBar()
}
