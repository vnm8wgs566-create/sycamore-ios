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
//  8 repository offers:
//
//      courts          -> `today_courts`, which the offline repository derives from the camp
//                         graph the app has already loaded. Every column that view selects is
//                         in the graph; none of it is invented.
//      schedule blocks -> the block the venue is inside, which is now the subject of a card of
//                         its own rather than a phrase in the header. See `OverviewNow`.
//      inbox items     -> the notes an admin has pinned, above the courts.
//
//  ── The screen follows the clock ─────────────────────────────────────────────────────────────
//
//  Which block is running is a question about the time, and until `AppClock` arrived nothing told
//  this view to ask it again: `TimeOfDay.now()` was read once per body pass and then held, so a
//  phone left on this tab named the nine o'clock block at half past eleven. Everything below reads
//  `store.timeOfDay` and `store.today`, which come off the clock and therefore move — the card
//  changes over at the block boundary without anybody touching the screen.
//
//  ── And says so when there is nothing to follow ──────────────────────────────────────────────
//
//  A day with no blocks on it used to fall back to "Sycamore · 4 courts" in the header and draw
//  the courts as though that were the whole of the tab. It is not: the coaches on the block, the
//  instruction and the notes all live on the schedule, and a venue that has never written one had
//  no way of learning that from here. `OverviewEmptyDayHero` is what it says instead.
//

import SwiftUI

struct OverviewView: View {

    @Environment(AppStore.self) private var store

    /// Which read produced the lists the store is currently holding.
    ///
    /// Nil until the first one lands, and that is the whole job: `scheduleBlocks` starts empty, an
    /// empty list is also what a day with nothing on it looks like, and telling those apart is the
    /// difference between the call to action and a flash of it on every cold open.
    /// `ScheduleView.loadedDay` is the same guard against the same flash.
    ///
    /// The whole key rather than the day alone, because the day is not the only thing that goes
    /// stale. `loadOverview` does not clear the lists before it reads, so switching venue leaves
    /// the previous venue's blocks in the store for as long as the round trip takes — and a marker
    /// that only remembered the day would call them current and name the other venue's block as
    /// the one running here.
    ///
    /// Deliberately not a copy of the blocks: it is a marker about this screen's loading, which is
    /// a fact that lives nowhere else.
    @State private var loaded: OverviewLoad?

    var body: some View {
        // Everything the screen needs, derived once and handed on rather than left as computed
        // properties the argument list reads twice. A computed property read twice is computed
        // twice: written the obvious way, the header line and the card were the same resolve, and
        // between them they walked the venue's whole staff list into a dictionary twice on every
        // tick of the clock — the cost `OverviewNow`'s own header exists to refuse.
        let key = OverviewLoad(campID: store.camp?.id, venueID: store.readVenueID, day: store.today)
        let blocks = todaysBlocks(for: key)

        return OverviewScreen(
            store: store,
            courts: store.courts,
            now: runningBlock(in: blocks ?? []),
            pinnedNotes: pinnedNotes,
            needsYou: needsYou,
            // Nil is "nobody has looked yet", which draws neither the card nor the invitation.
            dayIsUnscheduled: blocks?.isEmpty == true,
            venueName: venueID.flatMap { store.venue($0)?.name },
            dateLine: dateLine
        )
        .task(id: key) {
            await store.loadOverview()
            // Guarded, because `.task(id:)` cancels the run it is replacing rather than *waiting*
            // for it — and nothing inside `loadOverview` checks: the in-memory repository is an
            // actor, so an `await` on it never throws `CancellationError` and a superseded run
            // still finishes and still reaches this line. Landing after the run that replaced it,
            // it would stamp the *old* key, and `todaysBlocks(for:)` would then answer nil for as
            // long as the new key stood — no running-block card, `dayIsUnscheduled` pinned false,
            // until the venue or the day moved again. `ScheduleView`'s own
            // `.task(id: ScheduleLoad(…))` (`ScheduleView.swift:254-260`) guards the same hand-off
            // for the same reason — "a slow Tuesday landing after a fast Wednesday".
            guard !Task.isCancelled else { return }
            // The key `body` computed, not one read back off the store: the venue can be switched
            // from another tab while this is in flight, and recording the new one against the old
            // one's rows is exactly the staleness the marker exists to catch.
            loaded = key
        }
    }

    // MARK: What the screen draws

    /// The venue this screen is about now comes from `AppStore.readVenueID`, so Overview,
    /// Schedule and Inbox cannot disagree about which venue they are showing — they each used to
    /// answer that question their own way, and two of the five fell back to `camp.venues.first`
    /// where the others used `orderedVenues.first`. `venues` has no guaranteed order.
    private var venueID: Venue.ID? { store.readVenueID }

    /// Today's blocks — or nil, meaning nobody has read them yet.
    ///
    /// Three states rather than two, and the third is the one an empty array cannot express. Nil is
    /// "unread", `[]` is "read, and the day is genuinely empty", and only the second of those is
    /// something to put a call to action under. `ScheduleView.blocks` draws the same distinction for
    /// the same reason; the gate is applied once, here, so that every reader downstream looks at the
    /// same list rather than each deciding for itself whether to trust it.
    ///
    /// **The day filter is not belt and braces.** Even once loaded, `store.scheduleBlocks` is not
    /// guaranteed to be *this* day's: `addScheduleBlock` answers with `scheduleBlocks(forVenue:day:)`
    /// for **the block's** day (`SectionEightRepository.swift:514`), and the composer this screen now
    /// opens lets somebody change the day before saving. Write a block onto Friday from here and the
    /// store comes back holding Friday while the marker still says today — so without this, Overview
    /// would name a Friday block as the one running now, on a Tuesday afternoon.
    private func todaysBlocks(for key: OverviewLoad) -> [ScheduleBlock]? {
        guard loaded == key else { return nil }
        return store.scheduleBlocks.filter { $0.day == store.today }
    }

    /// The block the venue is in the middle of, with its coaches, its instruction and its notes.
    ///
    /// One rule, on the model, shared with the repository and with Schedule. This screen used to
    /// ask the clock in its own words while Schedule asked block *status*, so on any morning a
    /// coach forgot to mark a block done the two tabs named different blocks as current.
    ///
    /// `store.timeOfDay`, not `TimeOfDay.now()`. The static reads the wall clock inside itself and
    /// nothing observes it; the store's reads `AppClock`, which is `@Observable` and ticks on the
    /// minute — which is what makes this card change over on its own.
    ///
    /// `onCourt:` is what makes the card the reader's rather than the venue's, now that a venue
    /// can be running two blocks at once. See `OverviewNow.resolve`.
    private func runningBlock(in blocks: [ScheduleBlock]) -> OverviewNow? {
        OverviewNow.resolve(
            in: blocks, at: store.timeOfDay, staff: store.camp?.staff ?? [], onCourt: viewerCourtID
        )
    }

    /// The reader's own court — but only when it is one of the courts this screen is drawing.
    ///
    /// The venue on screen is `store.readVenueID`, which an admin can switch from any tab, and a
    /// coach's assignment belongs to whichever venue gave it to them. Passed through unchecked, a
    /// coach assigned to Court 1 at the swim club would filter the tennis club's blocks by a court
    /// that is not in them — matching every `.regular` block (they claim their whole venue, and
    /// `BlockRules.claims` cannot know it is the wrong one) and no `.assigned` block at all. That
    /// is not a wrong card so much as an arbitrary one.
    ///
    /// So the same gate `OverviewScreen` already applies to draw "Your court": a court this venue
    /// does not have is nobody's court here, and the screen falls back to the admin's reading of
    /// the morning, which is the one it is drawing anyway.
    private var viewerCourtID: Group.ID? {
        guard let mine = store.myCourtID, store.courts.contains(where: { $0.id == mine }) else {
            return nil
        }
        return mine
    }

    // What the call to action turns on is `blocks?.isEmpty == true` at the call site above:
    // somebody has looked, and there is nothing there. Deliberately *not* "no block is running" —
    // a day whose blocks have all finished by four o'clock is a scheduled day, and offering to
    // write its first block would be wrong twice over: it has blocks, and it is over.

    /// Every note an admin has pinned and nobody has resolved, newest first.
    ///
    /// **All of them, where this used to banner exactly one.** Read off the stored `pinned` flag
    /// rather than guessed — it used to be "the newest unresolved note", which bannered the first
    /// thing any coach happened to write down, and it disagreed with the Inbox, which drew its
    /// green pin for a different rule again. That much is settled and stays.
    ///
    /// What has changed is the count. Taking `first` was a reading of a design frame with one
    /// banner in it, and as a rule it is indefensible: pinning is an admin's deliberate act, the
    /// app offers no way to say "and this one too", and the Inbox lists every pin — so an admin who
    /// pinned the allergy after the shade tent watched the allergy silently not appear, on the tab
    /// they pinned it for. Two screens, one column, one answer.
    ///
    /// Uncapped, deliberately. A cap would be the same defect with a bigger number, and the pins
    /// are one clipped line each on a screen that already scrolls — where four cards of courts sit
    /// below them. The thing that limits this list is an admin taking a pin down, which is the
    /// control the Inbox already has.
    ///
    /// Not narrowed to `readVenueID` either, which is the one filter this screen might be expected
    /// to apply and must not. There is no camp-wide pin in the model: `addPinnedMessage` stamps
    /// every one with wherever its author happened to be standing, so scoping by venue would hide
    /// "sports day Friday, everyone on the lawn at nine" from the other half of the camp. That is
    /// the defect `AppStore.loadInbox` records having already fixed once, from the other side.
    ///
    /// `newestFirst` rather than the order the list arrives in. The repository does sort, and
    /// `filter` preserves it, so this changes nothing today — which is exactly why `InboxSection`
    /// centralised the comparison rather than trusting the read: four screens now put these rows in
    /// order and none of them should be the one that quietly disagrees.
    private var pinnedNotes: [InboxItem] {
        store.inboxItems.filter { $0.pinned && !$0.resolved }.newestFirst
    }

    /// Everything waiting on a decision, newest first — the row under the block.
    ///
    /// `needsAction` and unresolved, which is `AppStore.openInboxCount`'s own predicate written as
    /// a list rather than a number: the screen needs both the count and the newest one's words, and
    /// deriving the two separately is how a count of two comes to be drawn beside a sentence about
    /// a third thing.
    ///
    /// Camp-wide, and not narrowed to `readVenueID`, for the reason `pinnedNotes` gives directly
    /// above about pins: the Inbox is the one screen in section 8 that is not about a venue, and
    /// the caret on this row leads straight to it. A count here that disagreed with the count there
    /// would be this screen quietly keeping its own books.
    private var needsYou: [InboxItem] {
        store.inboxItems.filter { $0.kind == .needsAction && !$0.resolved }.newestFirst
    }

    /// `Tuesday, 12 August · day 2 of 5` — the line under the screen's title.
    ///
    /// This slot used to hold `now?.headerLine ?? venueLine` — the running block's "Skills rotation
    /// · until 10:30", or "Sycamore · 4 courts" when nothing was running. Both halves have somewhere
    /// better to be under 4a: the block is the card at the head of the scroll, with a button on it,
    /// and the venue is the pill above the title, with the court count in the sheet behind it. What
    /// is left is the one fact the screen carries nowhere else — where the camp has got to in its
    /// own run, which is the thing a coach on day two and a coach on day five want to know
    /// differently.
    ///
    /// **`store.clock.now` rather than `.now`**, and it is not fussiness: `store.today` is derived
    /// from that same instant (`AppClock.refresh(to:)`), and a line that spelled the weekday from
    /// one clock and the date from another could read "Tuesday, 13 August" for the minute either
    /// side of midnight. Reading it here costs nothing this view was not already paying — it reads
    /// `store.timeOfDay` off the same clock to resolve the running block, so this pass is already
    /// subscribed to the tick.
    private var dateLine: String {
        OverviewHeader.dateLine(for: store.today, on: store.clock.now, days: store.camp?.days)
    }
}

// MARK: - Reload key

/// What Overview's three reads depend on. `.task(id:)` re-reads when any of the three moves.
///
/// The day joined the key when the clock became real. `loadOverview` fetches `self.today`'s blocks,
/// and this screen's `.task` used to be keyed on the venue alone — so a phone left on this tab
/// through midnight went on drawing yesterday's morning against today's date, and the card naming
/// the running block would have been reading a list from the wrong day.
///
/// A private type beside the one view that uses it, which is where `ScheduleView.ScheduleLoad`
/// keeps its own copy of this idea. It is not a shape the app has; it is an argument list with a
/// name.
private struct OverviewLoad: Equatable {
    let campID: Camp.ID?
    let venueID: Venue.ID?
    let day: Weekday
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
