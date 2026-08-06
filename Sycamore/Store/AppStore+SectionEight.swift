//
//  AppStore+SectionEight.swift
//  Sycamore
//
//  The store surface for Overview, Schedule and Inbox.
//
//  Every screen unit built for section 8 arrived at the same shape independently — load in
//  `.task`, mutate through a method, re-read the returned list — and each held it in its own
//  `@State` because none of them owned this file. This is that shape, once, where a write on one
//  tab is visible on the next.
//
//  Split from `AppStore.swift` (already 900-odd lines) for the same reason `SectionEight.swift`
//  is split from `Models.swift`: the file every feature edits is the file every feature
//  conflicts in.
//

import Foundation

extension AppStore {

    // MARK: The venue these reads are scoped to

    /// The venue Overview, Schedule and Inbox are about: the court you are posted to, then the
    /// one you are on today, then the camp's first.
    ///
    /// One rule, because there were five. Each section 8 screen grew its own — some falling back
    /// to `camp.venues.first`, some to `camp.orderedVenues.first`. `venues` carries no guaranteed
    /// order, which is exactly why `orderedVenues` exists, so those two families could name
    /// *different* venues in the same session: Overview showing one venue while the Inbox read
    /// another's items, and neither saying so.
    ///
    /// Deliberately not keyed off `venueFilter`. That is Groups' chip row, and wiring these reads
    /// to it would mean tapping a chip on one tab silently retargeted the other three — a
    /// coupling nobody asked for, through a filter the redesign otherwise removed. `venueFilter`
    /// also has an `.all` case that no per-venue relation can answer, and every screen privately
    /// correcting for a state the model should not hold is a symptom, not a fix.
    var readVenueID: Venue.ID? {
        myStaffRecord?.venueID
            ?? todayAssignment?.venueID
            ?? camp?.orderedVenues.first?.id
    }

    // MARK: Overview

    /// Overview's three reads, in one wave and one `perform`.
    ///
    /// One `perform` because it tracks in-flight work with a plain `Bool`: three concurrent calls
    /// would each set it true and the first to finish would clear it, so the spinner would vanish
    /// while two reads were still out. `async let` because the three are independent — run in
    /// sequence they cost three round trips to draw one screen.
    func loadOverview() async {
        guard let campID = camp?.id, let venueID = readVenueID else { return }
        await perform {
            async let courts = self.repository.courts(forVenue: venueID, campID: campID)
            async let blocks = self.repository.scheduleBlocks(
                forVenue: venueID, day: self.today, campID: campID
            )
            async let inbox = self.repository.inboxItems(forVenue: venueID, campID: campID)

            self.courts = try await courts
            self.scheduleBlocks = try await blocks
            self.inboxItems = try await inbox
        }
    }

    func loadCourts() async {
        guard let campID = camp?.id, let venueID = readVenueID else { return }
        await perform {
            self.courts = try await self.repository.courts(forVenue: venueID, campID: campID)
        }
    }

    func setCourtStatus(_ status: CourtStatus, forGroup groupID: Group.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.courts = try await self.repository.setCourtStatus(
                status, forGroup: groupID, campID: campID
            )
        }
    }

    // MARK: Schedule

    func loadScheduleBlocks(day: Weekday) async {
        guard let campID = camp?.id, let venueID = readVenueID else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.scheduleBlocks(
                forVenue: venueID, day: day, campID: campID
            )
        }
    }

    func addScheduleBlock(_ block: ScheduleBlock) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.addScheduleBlock(block, campID: campID)
        }
    }

    func updateScheduleBlock(_ block: ScheduleBlock) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.updateScheduleBlock(block, campID: campID)
        }
    }

    func deleteScheduleBlock(_ blockID: ScheduleBlock.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.deleteScheduleBlock(blockID, campID: campID)
        }
    }

    func applyDayShape(_ shape: DayShape, day: Weekday) async {
        guard let campID = camp?.id, let venueID = readVenueID else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.applyDayShape(
                shape, toVenue: venueID, day: day, campID: campID
            )
        }
    }

    func copySchedule(from source: Weekday, to destination: Weekday) async {
        guard let campID = camp?.id, let venueID = readVenueID else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.copySchedule(
                fromDay: source, toDay: destination, venueID: venueID, campID: campID
            )
        }
    }

    // MARK: Inbox

    func loadInbox() async {
        guard let campID = camp?.id, let venueID = readVenueID else { return }
        await perform {
            self.inboxItems = try await self.repository.inboxItems(forVenue: venueID, campID: campID)
        }
    }

    func resolveInboxItem(_ itemID: InboxItem.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.inboxItems = try await self.repository.resolveInboxItem(itemID, campID: campID)
        }
        // Resolving is the one inbox write that changes another tab: approving a court move
        // reassigns a kid. Re-reading Overview here is cheaper than making every tab re-read on
        // every appearance, and it is the only place the two are known to be coupled.
        await loadCourts()
    }

    func addInboxItem(_ item: InboxItem) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.inboxItems = try await self.repository.addInboxItem(item, campID: campID)
        }
    }
}
