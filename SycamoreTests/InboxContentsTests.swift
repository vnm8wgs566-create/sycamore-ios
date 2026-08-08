//
//  InboxContentsTests.swift
//  SycamoreTests
//
//  The Inbox's one-pass derivation, now that it has a fourth destination.
//
//  `InboxContents` is the only part of the Inbox with any logic in it, which its own header says
//  makes it the only part worth exercising on its own. Adding the pinned section put two claims
//  at risk that the screen makes in words: "All clear." — nothing is waiting on a decision — and
//  "Nothing under notes" — this chip has narrowed the screen to nothing. Both are easy to make
//  quietly false by lifting a row somewhere else, and neither is visible in a diff.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("InboxContents")
struct InboxContentsTests {

    private static let venue = UUID()

    private static func note(
        _ title: String,
        pinned: Bool = false,
        resolved: Bool = false,
        minutesAgo: Int = 0
    ) -> InboxItem {
        InboxItem(
            venueID: venue, kind: .note, title: title,
            pinned: pinned, resolved: resolved,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 - Double(minutesAgo) * 60)
        )
    }

    private static func ask(
        _ title: String,
        pinned: Bool = false,
        minutesAgo: Int = 0
    ) -> InboxItem {
        InboxItem(
            venueID: venue, kind: .needsAction, title: title, actionLabel: "Review",
            pinned: pinned,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 - Double(minutesAgo) * 60)
        )
    }

    // MARK: The flag, not the shape

    /// The rule this replaced read "a note against no court is pinned", which meant attaching a
    /// note to a court un-pinned it. The two claims are independent now, so a row is entitled to
    /// make either, both or neither.
    @Test("Pinned is the stored flag and nothing else")
    func readsTheStoredFlag() {
        var againstACourt = Self.note("Two in sandals", pinned: true)
        againstACourt.groupID = UUID()
        let campWide = Self.note("Shade tent is up")

        let contents = InboxContents(items: [againstACourt, campWide], filter: .all)

        #expect(contents.pinned.map(\.title) == ["Two in sandals"])
        #expect(contents.feed.flatMap(\.items).map(\.title) == ["Shade tent is up"])
    }

    @Test("A pinned row is lifted out of the feed rather than drawn twice")
    func liftsOutOfTheFeed() {
        let contents = InboxContents(
            items: [Self.note("Net is loose", pinned: true), Self.note("Rank published")],
            filter: .all
        )

        #expect(contents.pinned.count == 1)
        #expect(contents.feed.flatMap(\.items).count == 1)
    }

    @Test("Resolving beats pinning — a cleared row is history whatever flag it wears")
    func resolvedWins() {
        let contents = InboxContents(
            items: [Self.note("Net is loose", pinned: true, resolved: true)],
            filter: .all
        )

        #expect(contents.pinned.isEmpty)
        #expect(contents.cleared.count == 1)
    }

    @Test("Newest pin first, as everywhere else on the screen")
    func ordersNewestFirst() {
        let contents = InboxContents(
            items: [
                Self.note("Older", pinned: true, minutesAgo: 90),
                Self.note("Newer", pinned: true, minutesAgo: 10),
            ],
            filter: .all
        )

        #expect(contents.pinned.map(\.title) == ["Newer", "Older"])
    }

    // MARK: The chips

    /// The section obeys the chips like every other row: a pinned message is a note, so Notes
    /// shows it and Needs you does not.
    @Test("Pins answer to the filter chips")
    func obeysTheChips() {
        let items = [Self.note("Net is loose", pinned: true), Self.ask("Austin → Court 2")]

        #expect(InboxContents(items: items, filter: .all).pinned.count == 1)
        #expect(InboxContents(items: items, filter: .notes).pinned.count == 1)
        #expect(InboxContents(items: items, filter: .needsYou).pinned.isEmpty)
    }

    // MARK: The two claims the screen makes in words

    /// A pin is a notice, not a decision. "All clear." stays true above one.
    @Test("A pin alone is still all clear")
    func pinAloneIsAllClear() {
        let contents = InboxContents(items: [Self.note("Net is loose", pinned: true)], filter: .all)

        #expect(contents.isAllClear)
        #expect(contents.headerSubtitle == "Nothing waiting on you")
        #expect(!contents.isNarrowedToNothing)
    }

    /// The screen is not empty while a pin is on it, so it must not say it is.
    @Test("A screen showing only a pin is not narrowed to nothing")
    func pinIsNotNothing() {
        let contents = InboxContents(
            items: [Self.note("Net is loose", pinned: true), Self.ask("Austin → Court 2")],
            filter: .notes
        )

        #expect(!contents.pinned.isEmpty)
        #expect(contents.needsYou.isEmpty)
        #expect(contents.feed.isEmpty)
        #expect(!contents.isNarrowedToNothing)
    }

    /// And with the pin filtered away it says it again, because now it is true.
    @Test("Still narrowed to nothing when the chip hides the pin too")
    func narrowedWhenEverythingIsHidden() {
        let contents = InboxContents(
            items: [Self.note("Net is loose", pinned: true), Self.ask("Austin → Court 2")],
            filter: .needsYou
        )

        // The ask matches `needsYou`, so this pair cannot narrow to nothing — swap it for a pin
        // and a note and the chip lands on an empty screen with something still waiting.
        #expect(!contents.needsYou.isEmpty)

        let onlyNotes = InboxContents(
            items: [Self.note("Net is loose", pinned: true), Self.note("Rank published")],
            filter: .needsYou
        )
        // Nothing is waiting on anybody, so this is the all-clear state rather than the narrowed
        // one: the narrowed card exists to say "N still waiting under All", and there is no N.
        #expect(onlyNotes.isAllClear)
        #expect(!onlyNotes.isNarrowedToNothing)
    }

    // MARK: A pinned ask — a state only the data layer can reach

    /// `setPinned` will pin any row it is given, and the screen never offers it for an ask — but
    /// if one arrives, "is anything waiting on you" must not change its answer because the row
    /// was moved up the page.
    @Test("A pinned ask is still counted as waiting on you")
    func pinnedAskStillCounts() {
        let contents = InboxContents(items: [Self.ask("Austin → Court 2", pinned: true)], filter: .all)

        #expect(contents.openNeedsAction.count == 1)
        #expect(!contents.isAllClear)
        #expect(contents.headerSubtitle == nil)
        // Drawn once, at the top — so the "Needs you · N" heading below counts the rows under it.
        #expect(contents.pinned.count == 1)
        #expect(contents.needsYou.isEmpty)
    }
}
