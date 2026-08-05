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
    //
    // All three relations are per-venue in Postgres. The app's venue *filter* can be "All",
    // which no single `site_id` answers — so the reads fall back to the first venue rather than
    // returning nothing, and a camp-wide read is a schema question (a `camp_id` on the views)
    // rather than something to fake by looping here.

    var readVenueID: Venue.ID? {
        if case .venue(let id) = venueFilter { return id }
        return camp?.venues.first?.id
    }

    // MARK: Overview

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
