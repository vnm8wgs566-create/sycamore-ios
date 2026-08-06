//
//  InboxSection.swift
//  Sycamore
//
//  One heading of the feed and the rows under it.
//

import Foundation

struct InboxSection: Identifiable, Hashable, Sendable {
    let id: InboxBucket
    let title: String
    let items: [InboxItem]
}

extension InboxSection {

    /// Buckets `items` into the feed the design draws: newest heading first, newest row first
    /// inside each heading.
    ///
    /// `now` and `calendar` are arguments rather than reads of the ambient clock, so a caller
    /// can pin them and the bucketing can be exercised without waiting for tomorrow.
    static func feed(
        _ items: [InboxItem],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [InboxSection] {
        Dictionary(grouping: items) { InboxBucket(for: $0.createdAt, now: now, calendar: calendar) }
            .map { bucket, items in
                InboxSection(
                    id: bucket,
                    title: bucket.title(now: now, calendar: calendar),
                    items: items.newestFirst
                )
            }
            .sorted { $0.id > $1.id }
    }
}

// MARK: - Ordering

extension Array where Element == InboxItem {
    /// Reverse-chronological — the one order the feed, the needs-you list and `8h`'s cleared
    /// list all read in. Centralised so the three cannot drift apart.
    var newestFirst: [InboxItem] {
        sorted { $0.createdAt > $1.createdAt }
    }
}
