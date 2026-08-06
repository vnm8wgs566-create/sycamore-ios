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

    var body: some View {
        OverviewScreen(
            store: store,
            courts: store.courts,
            pinnedNote: pinnedNote,
            blockNote: runningBlock?.notes.first,
            nowLine: nowLine
        )
        .task(id: store.readVenueID) { await load() }
    }

    // MARK: What the screen draws

    /// The venue this screen is about now comes from `AppStore.readVenueID`, so Overview,
    /// Schedule and Inbox cannot disagree about which venue they are showing — they each used to
    /// answer that question their own way, and two of the five fell back to `camp.venues.first`
    /// where the others used `orderedVenues.first`. `venues` has no guaranteed order.
    private var venueID: Venue.ID? { store.readVenueID }

    /// One rule, on the model, shared with the repository and with Schedule. This screen used to
    /// ask the clock in its own words while Schedule asked block *status*, so on any morning a
    /// coach forgot to mark a block done the two tabs named different blocks as current.
    private var runningBlock: ScheduleBlock? {
        ScheduleBlock.running(in: store.scheduleBlocks, at: .now())
    }

    /// The design banners one note. Items arrive newest first, so the newest one still standing
    /// is the one the morning is about.
    private var pinnedNote: InboxItem? {
        store.inboxItems.first { $0.kind == .note && !$0.resolved }
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
        let count = store.courts.count
        return "\(venue.name) · \(count) court\(count == 1 ? "" : "s")"
    }

    // MARK: Loading

    /// Through the store, not the repository.
    ///
    /// This screen held its three lists in `@State` and read the repository directly, because the
    /// unit that built it could not edit `AppStore`. That meant a write on another tab was
    /// invisible here — resolving an Inbox item that reassigns a court has to change what these
    /// cards say — and every tab switch re-issued the whole read set, because `MainTabView`
    /// switches on the selected tab and so destroys the view and its `@State` each time.
    private func load() async {
        await store.loadOverview()
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
