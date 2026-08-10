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
    ///
    /// **Four steps now, not three, and the new one is first.** 4a's header pill and 4b's venue
    /// sheet both let the reader say which venue they are looking at, and this was a computed
    /// property with no setter — a rule about where somebody is posted, being asked a question
    /// about where they are *looking*. `chosenVenueID` (`AppStore.swift:427-440`) is that answer
    /// and nil until somebody gives one, so the three fallbacks below are untouched and a reader
    /// who never taps the pill still opens on their own court.
    ///
    /// A choice outranks a posting rather than the other way round, which is the whole of the
    /// answer to "may a coach posted to Sycamore look at LATC?". They may: 4b draws the control
    /// with no lock, the reads it retargets are all `select` and all already scoped by RLS to the
    /// camps the reader is a member of, and a switch that silently snapped back to their own venue
    /// would be a control that does nothing.
    var readVenueID: Venue.ID? {
        chosenVenueID
            ?? myStaffRecord?.venueID
            ?? todayAssignment?.venueID
            ?? camp?.orderedVenues.first?.id
    }

    /// 4b's "Switch" — the reader picks a venue, and section 8's three tabs follow.
    ///
    /// **Clears before the read it sets off, which is the point of the intent existing at all.**
    /// `loadOverview` assigns into `courts`, `scheduleBlocks` and `inboxItems` only once each read
    /// has returned, and never clears first — `OverviewView.swift:50-55` records that staleness
    /// deliberately, because on a *reload of the same venue* an empty grid flashing between two
    /// identical answers is worse than a moment of yesterday's numbers. Switching venue inverts
    /// that: the stale rows are another venue's courts, drawn under the new venue's name, and a
    /// coach reading them has no way to tell. So the clear happens here, where the venue actually
    /// changed, rather than in the load, where it usually has not.
    ///
    /// `inboxItems` is deliberately not cleared. The Inbox is camp-wide (`loadInbox`), so its rows
    /// are as true after the switch as before and blanking them would be a flicker with nothing
    /// behind it.
    ///
    /// **Reads nothing, deliberately, and that is the half this used to get wrong.** It ended in
    /// `await loadOverview()` under a comment claiming Overview needed the push because "the other
    /// two screens key their own `.task` on `readVenueID` … Overview is the one the sheet is
    /// presented over". That is inverted: `readVenueID` is a member of `OverviewLoad`
    /// (`OverviewView.swift:67`), so writing `chosenVenueID` moves Overview's `.task(id:)` key
    /// exactly as it moves Schedule's and the Inbox's. The push was a *second* wave over the first
    /// — one tap on 4b costing six round trips to draw three lists, with two `perform` blocks
    /// overlapping, which is precisely the `isWorking` interleaving `loadOverview` below says its
    /// single `perform` exists to prevent.
    ///
    /// So `.task(id:)` is the sole owner of the reload and this is the sole owner of the choice.
    /// `chosenVenueID` is written **last** because it is the write the reload hangs off: the two
    /// clears are already in place by the time anything can observe the new venue, so no pass can
    /// pair the new name with the old rows.
    ///
    /// Synchronous, now that nothing here is awaited. `VenuePickerSheet.select(_:)` was wrapping
    /// this in a `Task` to say "and then reload"; there is no "and then" left, and a picker whose
    /// tap took effect on some later turn of the runloop would be one the sheet could out-race on
    /// the way down.
    func selectVenue(_ id: Venue.ID) {
        guard chosenVenueID != id else { return }
        courts = []
        scheduleBlocks = []
        chosenVenueID = id
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
            async let inbox = self.repository.inboxItems(forCamp: campID)

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

    /// Overview's "Close this court", and the only write in this file that moves two things.
    ///
    /// `courts` is what the repository answers with and what Overview redraws from. The camp graph
    /// carries the same fact now — `Group.closedReason` (`Models.swift:563-582`) — and
    /// `closedCourts` below is derived from *that*, so a graph left holding the old value would
    /// have `PlayerCourtPicker` calling a court open a second after somebody shut it, on the one
    /// screen in the app where not knowing puts a child on the wrong court.
    ///
    /// Applied locally rather than re-read. Both repositories write the row and hand back the
    /// venue's cards; neither returns the camp, and asking for the whole graph again to learn one
    /// nullable string would be a round trip to fetch what the write has already established.
    /// `status.closureReason` is assigned rather than a reason being appended or cleared by hand,
    /// so `.open` and `.closed(reason:)` are one statement and cannot fall out of step.
    ///
    /// Inside `perform` and *after* the call, which is what makes it safe: a refused write throws
    /// before this line and leaves the graph exactly as it was.
    func setCourtStatus(_ status: CourtStatus, forGroup groupID: Group.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.courts = try await self.repository.setCourtStatus(
                status, forGroup: groupID, campID: campID
            )
            if let index = self.camp?.groups.firstIndex(where: { $0.id == groupID }) {
                self.camp?.groups[index].closedReason = status.closureReason
            }
        }
    }

    /// Which courts are out of play this morning, across the whole camp, for the screens that hold
    /// a `Group` and need to know. `PlayerCourtChoices` is the caller: a court with "Net down" on
    /// it must not be offered unmarked in the sheet somebody uses to decide where to send a child.
    ///
    /// Derived rather than stored, which is unchanged and is the same call `AppStore.openInboxCount`
    /// makes about the count it derives from `inboxItems` rather than banking beside them. What
    /// changed is *what it is derived from*.
    ///
    /// **It reads `camp.groups`, and so it is every venue's.** This used to be
    /// `Set(courts.lazy.filter(\.isClosed))`, and the comment here argued at length that a
    /// per-venue answer was all the app could give: `courts(forVenue:campID:)` is a per-venue
    /// relation, `loadOverview` asks it for the venue Overview is drawing, and on a two-venue camp
    /// a court shut at the *other* venue was simply not in here — its row in the picker said
    /// nothing, which reads as open. The block editor is scoped to `draft.venueID` and 4a's venue
    /// pill moves `readVenueID` under both, so the set could also change venue between two draws of
    /// one sheet.
    ///
    /// That argument ended the moment the reason landed on the row. `groups.closed_reason`
    /// (`20260810030000`) is on `groups`, the camp graph already selects every venue's `groups`
    /// rows in one request (`SupabaseRepository+Graph.swift:33`), and `Group.closedReason`
    /// (`Models.swift:563-582`) is that column in the model — so the camp-wide answer costs no
    /// round trip at all. `courts(forCamp:)` on `SectionEightData`, which this comment used to name
    /// as the eventual fix, is not needed and would be the more expensive of the two: a camp-wide
    /// read, both repositories behind it, and a load on screens that now need none.
    ///
    /// **The freshness that was lost with `courts` is bought back at the writer**, not here.
    /// `courts` was updated by `setCourtStatus` on the way past, and the graph is not returned by
    /// that write — so `setCourtStatus` above applies the same change to `camp.groups` once the
    /// repository has accepted it. Deriving from a graph nobody updated would have traded a
    /// one-venue answer for a stale one.
    ///
    /// A `Set` rather than the reasons, because that is the whole of what the caller asks: closure
    /// changes what a row *says* and never which rows exist. A screen that needs the words asks
    /// `Camp.closedReason(for:)` (`Models.swift:1075-1086`), which answers for any venue's court.
    var closedCourts: Set<Group.ID> {
        guard let camp else { return [] }
        return Set(camp.groups.lazy.filter { $0.closedReason != nil }.map(\.id))
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

    /// The block editor's "put every kid on these courts" / "divide them evenly".
    ///
    /// Assigns `camp` rather than `scheduleBlocks`, and is the only intent in this file that does.
    /// Nothing about the *block* changes — its courts were written a moment ago by the save that
    /// preceded this — what moves is where the kids stand, which is the camp graph.
    ///
    /// The two no-op cases are refused here rather than in the repository, so a spread nobody
    /// asked for does not cost a whole-graph round trip to discover it had nothing to do. Both are
    /// ordinary: `.leaveThem` is the editor's default, and a block with no courts is what every
    /// `.regular` one saves.
    ///
    /// Here rather than in `AppStore.swift` for the reason this file's header gives — that one is
    /// the file every feature edits, and this is Schedule's.
    func spreadKids(_ spread: BlockKidSpread, over courtIDs: [Group.ID], atVenue venueID: Venue.ID) async {
        guard let campID = camp?.id, spread != .leaveThem, !courtIDs.isEmpty else { return }
        await perform {
            self.camp = try await self.repository.spreadKids(
                spread, overCourts: courtIDs, atVenue: venueID, campID: campID
            )
        }
    }

    /// Writes a note against a block, then re-reads the Inbox.
    ///
    /// The second read has a precedent and a rule: `resolveInboxItem` re-reads Overview because
    /// that is "the only place the two are known to be coupled". A block note *is* an Inbox row,
    /// so this is the second such place — leaving it out would put a note on `8l` that `8r`
    /// does not know about until the tab is opened again.
    func addBlockNote(_ text: String, to block: ScheduleBlock) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.addBlockNote(
                text, to: block, authorID: self.myStaffRecord?.id, campID: campID
            )
        }
        await loadInbox()
    }

    func deleteBlockNote(_ noteID: InboxItem.ID, from block: ScheduleBlock) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.scheduleBlocks = try await self.repository.deleteBlockNote(
                noteID, from: block, campID: campID
            )
        }
        await loadInbox()
    }

    // MARK: Inbox

    /// The camp's rows, not one venue's.
    ///
    /// This read was per-venue until pinned messages arrived, and `SectionEightRepository` has
    /// argued against that from the day the camp-wide variant was written: `8r` puts a row
    /// reading "LATC is 2 coaches short" in front of a reader standing on Sycamore, so the Inbox
    /// is the one screen in section 8 that is not about a venue. Against the seeded camp the
    /// narrow read hid exactly the row the design uses as its example.
    ///
    /// A pin is what made it a defect rather than a shortcoming. An admin pins at
    /// `readVenueID`, so a camp-wide announcement reached only the venue its author happened to
    /// be standing on — and `setPinned` already answered with the camp's rows, so pinning
    /// widened the list and the next load quietly narrowed it again.
    func loadInbox() async {
        guard let campID = camp?.id else { return }
        await perform {
            self.inboxItems = try await self.repository.inboxItems(forCamp: campID)
        }
    }

    func resolveInboxItem(_ itemID: InboxItem.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.inboxItems = try await self.repository.resolveInboxItem(itemID, forCamp: campID)
        }
        // Resolving is the one inbox write that changes another tab: approving a court move
        // reassigns a kid. Re-reading Overview here is cheaper than making every tab re-read on
        // every appearance, and it is the only place the two are known to be coupled.
        await loadCourts()
    }

    func addInboxItem(_ item: InboxItem) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.inboxItems = try await self.repository.addInboxItem(item, forCamp: campID)
        }
    }

    /// The admin composer. A pinned message is an ordinary `.note` row wearing the flag, so this
    /// is `addInboxItem` with the two fields the composer does not ask about filled in — not a
    /// separate kind of thing.
    func addPinnedMessage(_ text: String) async {
        guard let venueID = readVenueID else { return }
        await addInboxItem(
            InboxItem(
                venueID: venueID,
                kind: .note,
                title: text,
                actorID: myStaffRecord?.id,
                pinned: true
            )
        )
    }

    func setPinned(_ pinned: Bool, for itemID: InboxItem.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.inboxItems = try await self.repository.setPinned(
                pinned, forItem: itemID, forCamp: campID
            )
        }
    }
}
