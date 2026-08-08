//
//  CourtHeader.swift
//  Sycamore
//
//  The court screen's white header block: the way back, which venue this is, the court's name,
//  what is happening on it today, and who has it.
//
//  `8q`'s header shape, because the design draws no header for this screen and `8q` is the one it
//  does draw for a pushed screen — back caret, breadcrumb, serif title, a grey line under it. The
//  one thing it adds is the row at the foot: a court is not a child, and "who has it" and
//  "is it in play" are the two facts a coach opens this screen to check. Both are drawn with the
//  components the court card already uses, so the screen a caret opens looks like the card it
//  opened from.
//
//  Its own view for the reason `PlayerHeader` gives: it redraws on a different beat from the list
//  below it. Marking a kid away rebuilds the roster; up here nothing moves but the headcount.
//

import SwiftUI

struct CourtHeader: View {

    /// `Sycamore` — which venue's Court 1 this is. An admin can be responsible for more than one
    /// and every venue numbers its courts from 1, so the number alone does not identify a court.
    let crumb: String
    /// `Court 1`.
    let title: String
    /// `Drills · 8 here · 1 away`, or `Net down · Tom is on it` for a court out of play.
    let lede: String?
    /// The coach's first name. Nil is a court nobody has, which `CoachPill` writes as
    /// "Needs a coach".
    let coachName: String?
    let status: CourtStatus
    let onBack: () -> Void

    private var isClosed: Bool {
        if case .closed = status { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.tight) {
                backButton
                Text(crumb)
                    .typeStyle(.onTheDayCrumb, color: Theme.inkMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            // The caret is drawn at the design's 20pt and centred in a 44pt frame, so 8pt here
            // puts it on the design's 22pt gutter without the hit region eating into the title
            // below — `PlayerHeader` and `AttendanceHeader` set the same row the same way.
            .padding(.horizontal, Spacing.small)

            OnTheDayTitle(title)
                .padding(.horizontal, Spacing.header)
                .padding(.top, OnTheDayTokens.headerTop)

            if let lede {
                Text(lede)
                    .typeStyle(.onTheDayLede, color: Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.header)
                    .padding(.top, Spacing.small)
            }

            standing
                .padding(.horizontal, Spacing.header)
                .padding(.top, Spacing.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, OnTheDayTokens.headerBottom)
    }

    /// Who has the court, and whether it is in play.
    ///
    /// The pill is inert here, where the same pill on a court card opens the coach's staff card.
    /// That card is `store.activeSheet`'s, and this screen is presented over the root that owns
    /// it — asking the root to present would open the sheet *behind* this screen, which is the
    /// trap `PlayerScreen` records. The screen could carry its own copy of the sheet the way
    /// `8q` carries `8n`, but `StaffSheet` closes itself by clearing `store.activeSheet` rather
    /// than through `@Environment(\.dismiss)`, so a locally presented copy would arrive with a
    /// dead ✕. A name that reads is worth more than a control that half works, and
    /// `CourtStatusBadge` beside it is already inert by design — "a status, not a control".
    private var standing: some View {
        HStack(spacing: OverviewTheme.headerGap) {
            // A closed court shows no coach, which is the rule `OverviewCourtCard` states: a
            // court out of play is not being run by anybody, and the lede above already names
            // whoever is on it. Without this the header would offer "Needs a coach" for a court
            // that does not need one.
            if !isClosed {
                CoachPill(name: coachName)
            }
            // Prominent, so an open court says so outright. Every card on Overview but your own
            // stays quiet about being open — a page of "Open" badges is noise — but this screen
            // is one court, and the whole reason to open it is to ask about that court.
            CourtStatusBadge(status: status, isProminent: true)
            Spacer(minLength: 0)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            DisclosureChevron(systemName: "chevron.left", size: 20, color: Theme.inkSecondary)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - Previews

#Preview("Court header") {
    VStack(spacing: 0) {
        CourtHeader(
            crumb: "Sycamore",
            title: "Court 1",
            lede: "Drills · 8 here · 1 away",
            coachName: "Nass",
            status: .open,
            onBack: {}
        )
        Hairline(color: Theme.hairline)
        Spacer(minLength: 0)
    }
    .background(Theme.surface)
    .frame(maxHeight: 300)
}

#Preview("Court header — closed, no coach") {
    VStack(spacing: 0) {
        CourtHeader(
            crumb: "Sycamore",
            title: "Court 4",
            lede: "Net down · Tom is on it",
            coachName: nil,
            status: .closed(reason: "Tom is on it"),
            onBack: {}
        )
        Hairline(color: Theme.hairline)
        Spacer(minLength: 0)
    }
    .background(Theme.surface)
    .frame(maxHeight: 300)
}
