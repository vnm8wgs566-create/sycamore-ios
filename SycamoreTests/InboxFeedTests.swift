//
//  InboxFeedTests.swift
//  SycamoreTests
//
//  Which heading a feed row falls under, and in what order the headings come.
//
//  This is the rule a reader reported as broken — "This afternoon doesn't work" — and it was
//  never wrong. It was untested and unfed. A grep for `InboxBucket`, `InboxSection` or `DayPart`
//  across this directory returned nothing at all before this file, so the morning/afternoon/
//  evening branch had never once been run: every fixture in `InboxContentsTests` pins `createdAt`
//  to `Date(timeIntervalSince1970: 1_700_000_000)` — a Tuesday in November 2023 — which is never
//  the day the tests run on, so `InboxBucket.part` came back nil every time and the three-way
//  split was dead code under a passing suite.
//
//  So these drive the boundaries directly. `InboxBucket` and `InboxSection.feed` both take `now`
//  and `calendar` as arguments precisely so this is possible without waiting for the afternoon,
//  and every case below pins both.
//
//  The calendar is fixed to a UTC one rather than the reader's. `startOfDay`, `isDateInYesterday`
//  and `component(.hour:)` are all answered by the calendar's time zone, so a machine in Sydney
//  and one in Los Angeles would otherwise disagree about which day 09:12 belongs to — and a suite
//  that passes in one office and fails in another teaches nobody anything.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("Inbox feed — which heading a row lands under")
struct InboxFeedTests {

    /// A fixed calendar, so a row's day is the same fact in every time zone.
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    /// Midnight UTC on the day the suite runs.
    ///
    /// Pinned to a fixed date first, which is what a test of a rule that takes its own `now`
    /// ought to be able to do — and it does not work, for a reason worth writing down.
    /// `InboxBucket.title` answers "Yesterday" through `Calendar.isDateInYesterday`
    /// (`InboxBucket.swift:63`), and that method compares against the wall clock rather than
    /// against the `now` it was handed. So a fixture pinned to February answers "Tuesday" for a
    /// row written the day before it, and the one heading that cannot be tested at an arbitrary
    /// date is the one heading the design draws beside "This morning".
    ///
    /// So the day floats and only the *hour* is pinned, which is all these cases are about
    /// anyway. Everything below injects its own `now`, so nothing here depends on when it is run
    /// except the yesterday case — which depends on it because the rule does.
    private static var today: Date { calendar.startOfDay(for: .now) }

    /// `hour:minute` on `today`, or on a day before it. `today` is already a start of day, so it
    /// is added to directly.
    private static func at(_ hour: Int, _ minute: Int, daysAgo: Int = 0) -> Date {
        let start = today
        return calendar.date(
            byAdding: DateComponents(day: -daysAgo, hour: hour, minute: minute), to: start
        ) ?? start
    }

    private static func item(_ title: String, at moment: Date) -> InboxItem {
        InboxItem(venueID: UUID(), kind: .activity, title: title, createdAt: moment)
    }

    /// The heading a single row would be filed under, read the way the screen reads it.
    private static func heading(for moment: Date, now: Date) -> String? {
        InboxSection.feed([item("row", at: moment)], now: now, calendar: calendar).first?.title
    }

    // MARK: The three parts of today

    @Test("An item written at 09:12 lands under This morning")
    func morning() {
        #expect(Self.heading(for: Self.at(9, 12), now: Self.at(9, 52)) == "This morning")
    }

    /// The section the report was about. Nothing in the shipped app could write a row into it
    /// until `AppStore`'s day-running intents started logging one, which is why it read as broken.
    @Test("An item written at 13:40 lands under This afternoon")
    func afternoon() {
        #expect(Self.heading(for: Self.at(13, 40), now: Self.at(14, 5)) == "This afternoon")
    }

    @Test("An item written at 18:05 lands under This evening")
    func evening() {
        #expect(Self.heading(for: Self.at(18, 5), now: Self.at(18, 30)) == "This evening")
    }

    // MARK: The boundaries themselves

    /// Noon is the first minute of the afternoon and not the last of the morning. Stated as a
    /// pair, because an off-by-one here is invisible in a diff and is the whole of the rule.
    @Test("11:59 is still the morning and 12:00 is already the afternoon")
    func noonBoundary() {
        let now = Self.at(15, 0)
        #expect(Self.heading(for: Self.at(11, 59), now: now) == "This morning")
        #expect(Self.heading(for: Self.at(12, 0), now: now) == "This afternoon")
    }

    @Test("16:59 is still the afternoon and 17:00 is already the evening")
    func fiveBoundary() {
        let now = Self.at(20, 0)
        #expect(Self.heading(for: Self.at(16, 59), now: now) == "This afternoon")
        #expect(Self.heading(for: Self.at(17, 0), now: now) == "This evening")
    }

    /// Midnight is the morning, which is the only sensible reading of `..<12` and is worth
    /// pinning because it is the one hour a reader never sees while testing by hand.
    @Test("A row written just after midnight belongs to this morning")
    func midnight() {
        #expect(Self.heading(for: Self.at(0, 1), now: Self.at(9, 0)) == "This morning")
    }

    // MARK: Any day but today

    /// Yesterday gets a date heading rather than a "This …" one. The asymmetry is the design's:
    /// while you are inside a day you place things against now, and once a day is behind you all
    /// that matters is which day.
    @Test("Yesterday's item gets a date heading rather than a This one")
    func yesterdayIsNotSplit() {
        let heading = Self.heading(for: Self.at(9, 12, daysAgo: 1), now: Self.at(9, 52))
        #expect(heading == "Yesterday")
    }

    /// Written at the same hour of the morning as the row above and filed differently, which is
    /// the point: the hour only means something on the day you are standing in.
    @Test("An afternoon two days back is a weekday, not This afternoon")
    func earlierInTheWeek() {
        let heading = Self.heading(for: Self.at(13, 40, daysAgo: 2), now: Self.at(14, 5))
        #expect(heading != "This afternoon")
        // Its own day's start, for the reason `beyondAWeek` sets out below.
        #expect(heading == Self.at(0, 0, daysAgo: 2).formatted(.dateTime.weekday(.wide)))
    }

    /// Past a week a weekday alone is ambiguous — "Tuesday" could be either of two — so the
    /// heading becomes a date.
    @Test("Past a week the heading is a date rather than a weekday")
    func beyondAWeek() {
        let heading = Self.heading(for: Self.at(10, 0, daysAgo: 8), now: Self.at(14, 5))
        // Compared against the same instant the bucket formats — its day's *start* — rather than
        // against the row's own 10:00. `InboxBucket.title` formats through `Date.FormatStyle`,
        // which reads the machine's time zone rather than the calendar handed in, so on a machine
        // west of UTC the two would be different dates and this would fail for a reason that has
        // nothing to do with the rule.
        #expect(heading == Self.at(0, 0, daysAgo: 8).formatted(.dateTime.day().month(.abbreviated)))
    }

    // MARK: Order

    /// **Newest first, headings included** — so the evening sits above the afternoon, which sits
    /// above the morning. `InboxBucket` is ordered chronologically and the feed sorts on the
    /// reverse of it (`InboxBucket.swift:74-79`, `InboxSection.swift:36`), which is the same
    /// direction the rows inside each heading already run in.
    ///
    /// Worth stating because the obvious guess is the other one — that a day reads forward from
    /// its morning. It does not, and it should not: the feed exists so somebody walking in late
    /// can catch up on what they missed (`InboxActivityRow.swift:7-8`), and a screen that read
    /// newest-first inside a heading and oldest-first between them would make a reader scan
    /// downwards and upwards on the same page.
    @Test("Headings run newest first, so the evening sits above the morning")
    func partsRunNewestFirst() {
        let feed = InboxSection.feed(
            [
                Self.item("evening", at: Self.at(18, 5)),
                Self.item("morning", at: Self.at(9, 12)),
                Self.item("afternoon", at: Self.at(13, 40)),
            ],
            now: Self.at(20, 0),
            calendar: Self.calendar
        )

        #expect(feed.map(\.title) == ["This evening", "This afternoon", "This morning"])
    }

    /// Today's three above yesterday's one — one rule, applied twice. A day that is behind you
    /// has no parts, so it sorts below every part of today.
    @Test("The newest day comes first, and today's parts sit above yesterday")
    func newestDayFirst() {
        let feed = InboxSection.feed(
            [
                Self.item("yesterday", at: Self.at(16, 20, daysAgo: 1)),
                Self.item("evening", at: Self.at(18, 5)),
                Self.item("morning", at: Self.at(9, 12)),
                Self.item("afternoon", at: Self.at(13, 40)),
            ],
            now: Self.at(20, 0),
            calendar: Self.calendar
        )

        #expect(feed.map(\.title) == ["This evening", "This afternoon", "This morning", "Yesterday"])
    }

    /// Inside a heading the newest row is at the top — the one order the feed, the needs-you list
    /// and `8h`'s cleared list all read in.
    @Test("Newest row first inside a heading")
    func newestRowFirst() {
        let feed = InboxSection.feed(
            [
                Self.item("older", at: Self.at(9, 12)),
                Self.item("newer", at: Self.at(11, 30)),
            ],
            now: Self.at(11, 45),
            calendar: Self.calendar
        )

        #expect(feed.count == 1)
        #expect(feed.first?.items.map(\.title) == ["newer", "older"])
    }

    /// Two rows an hour apart across noon are two headings, not one. This is the case that was
    /// unreachable while every fixture in the suite sat in November 2023.
    @Test("A row either side of noon makes two headings out of one day")
    func noonSplitsTheDay() {
        let feed = InboxSection.feed(
            [
                Self.item("before", at: Self.at(11, 30)),
                Self.item("after", at: Self.at(12, 30)),
            ],
            now: Self.at(13, 0),
            calendar: Self.calendar
        )

        #expect(feed.map(\.title) == ["This afternoon", "This morning"])
        #expect(feed.map { $0.items.count } == [1, 1])
    }

    // MARK: The fixture the previews draw

    /// `InboxPreviewItems.morning` used to write three of its rows at 9:44, 9:31 and 9:12 off the
    /// day's midnight, so every `#Preview` of `8r` said "This morning" whatever the hour — the
    /// exact failure `InboxBucket` was written to prevent. The rows are offsets from `now` now,
    /// and this asks the question from the far end of the day.
    @Test("The preview morning reads This afternoon when it is the afternoon")
    func previewFixtureFollowsTheClock() {
        let afternoon = Self.at(15, 30)
        let feed = InboxSection.feed(
            InboxPreviewItems.morning(venueID: UUID(), now: afternoon, calendar: Self.calendar)
                .filter { !$0.pinned && $0.kind != .needsAction },
            now: afternoon,
            calendar: Self.calendar
        )

        #expect(feed.first?.title == "This afternoon")
        // And yesterday's row is still yesterday's — the fixture moves with the clock without
        // collapsing into a single heading.
        #expect(feed.map(\.title) == ["This afternoon", "Yesterday"])
    }
}
