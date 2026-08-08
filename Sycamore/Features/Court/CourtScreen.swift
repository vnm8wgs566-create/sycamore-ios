//
//  CourtScreen.swift
//  Sycamore
//
//  One court, behind the caret every court card on `8i`/`8j` has been drawing since Overview was
//  built: who is on it, who has it, whether it is in play, and the notes written against it.
//
//  The design draws no frame for this screen — section 8 stops at the caret — so its shape is
//  borrowed rather than invented. `8q` is the one pushed screen the design *does* draw, and this
//  takes its header wholesale: white block running up under the status bar, back caret, serif
//  title, sections under small overlines. Everything inside those sections is the court card's own
//  furniture, so the screen a caret opens looks like the card it opened from.
//
//  **It shows who is missing, where the card does not.** `TodayCourts.rosters` drops away kids
//  from a court's list entirely and that is right for Overview — a card answers "who is on this
//  court right now". A screen about one court is the other question, and until now nothing in the
//  app answered it: Groups greys away kids but is organised by group rather than by the day. So
//  the roll arrives in two parts, the kids who are here numbered 1…n exactly as the card numbers
//  them, and the ones who are not under their own heading below. See `CourtDetailRoster`, which
//  is where that decision lives and is tested.
//
//  **The notes are scoped by court, not by the pin.** `inbox_items.pinned` is a camp-wide flag an
//  admin sets on a message, and it is not backfilled — every row written before the column existed
//  reads `false`. Scoping by `groupID` is what makes this section the notes *about this court*
//  rather than the notes somebody happened to hold up, which is also why the heading reads "Notes"
//  and not "Pinned notes": it would be false for every court note nobody has pinned, which today
//  is all of them. Pinned ones sort to the top and wear a pin, so the flag is still visible where
//  it is set.
//
//  Nothing here loads. The screen is opened from Overview, which has already read the courts and
//  the inbox for this venue into the store, and both lists live on `AppStore` precisely so a
//  second screen can read them without issuing the query again.
//

import SwiftUI

struct CourtScreen: View {

    let store: AppStore
    let groupID: Group.ID

    var body: some View {
        // Resolved once and read several times. Each of these walks the camp — the roster over
        // one court's roll, the notes over the venue's inbox — and `body` asks the header, the
        // lede and two sections the same questions. `PlayerScreen` resolves its history the same
        // way and for the same reason.
        let roster = detailRoster
        let notes = courtNotes

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()
                CourtHeader(
                    crumb: venueName,
                    title: title,
                    lede: lede(roster),
                    coachName: coachName,
                    status: status,
                    onBack: { store.pushedScreen = nil }
                )
            }
            // The white carries up under the status bar, as `8q` draws it — otherwise the page
            // colour shows above the header block on a device with a notch.
            .background(Theme.surface.ignoresSafeArea(edges: .top))

            Hairline(color: Theme.hairline)

            ScrollView {
                content(roster: roster, notes: notes)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, OnTheDayTokens.headerTop)
                    // `Spacing.section`, not `OnTheDayTokens.contentBottomInset` (88) and not
                    // `Spacing.tabBarClearance` (92). Both of those are clearance under something
                    // — a pinned bar on `8m`/`8q`, the floating pill on a tab — and this screen
                    // has neither. 88pt of air under the last name would read as a missing block.
                    .padding(.bottom, Spacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8`, not `grouped`'s `#F6F7F9` — section 8's page is a shade warmer.
        .background(Theme.surfaceWarm)
    }

    // MARK: - What this screen is about

    /// The court in the camp graph. The screen's own subject: it survives an empty
    /// `today_courts`, which the card below it does not.
    private var group: Group? { store.group(groupID) }

    /// The `today_courts` row, which carries what the graph does not — the activity running on
    /// this court and whether it has been taken out of play.
    ///
    /// Read fresh by each of the five properties below rather than resolved once into `body` the
    /// way the roster is. `store.courts` is one venue's courts — a dozen at the outside — so the
    /// scan is a dozen comparisons, where `detailRoster` above walks a court's roll and the
    /// attendance table behind it. The rule this codebase follows is to hoist what is expensive
    /// and cite why, not to hoist everything.
    private var card: CourtCard? { store.courts.first { $0.id == groupID } }

    /// `Court 1`. The graph's label first: a court that is in the camp but not in the day's
    /// `today_courts` read still has a name.
    private var title: String {
        group?.label ?? card?.courtLabel ?? card?.groupName ?? ""
    }

    /// `Sycamore`. An admin can be responsible for more than one venue and every venue numbers
    /// its courts from 1, so which venue this is is the part the title cannot say.
    private var venueName: String {
        let venueID = group?.venueID ?? card?.venueID
        return venueID.flatMap { store.venue($0)?.name } ?? ""
    }

    /// Open unless the day says otherwise. A court with no `today_courts` row has had no closure
    /// recorded against it, which is what open means.
    private var status: CourtStatus { card?.status ?? .open }

    /// The coach's first name, off the camp graph rather than off the card.
    ///
    /// The card carries a `coachName` too, but it is a denormalised copy from whenever the courts
    /// were last read, and this screen sits over a tab that can reassign one. The graph is the
    /// thing the reassignment writes to.
    private var coachName: String? {
        store.coach(forGroup: groupID)?.name ?? card?.coachName
    }

    /// `Drills · 8 here · 1 away`, or `Net down · Tom is on it` for a court out of play.
    ///
    /// The counts come from the roster this screen draws rather than from `card.playersHere`, so
    /// the number in the line and the names under it cannot disagree — they are one derivation
    /// read twice. `OverviewRosterTests` pins the card's own count to the same arithmetic.
    ///
    /// "here", not "players", because `Group.headcountLine` already writes a court's occupancy
    /// that way ("Court 1 · 8 here") and the away count beside it needs the contrast.
    private func lede(_ roster: CourtDetailRoster) -> String? {
        var parts: [String] = []
        // The card's activity wins: the repository already resolves it to the running block's
        // title when the court has not gone its own way, where `Group.activity` is only the
        // column.
        if let activity = card?.activity ?? group?.activity {
            parts.append(activity)
        }

        if case .closed(let reason) = status {
            parts.append(reason)
        } else {
            parts.append("\(roster.here.rows.count) here")
            if !roster.away.isEmpty {
                parts.append("\(roster.away.count) away")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - The day

    /// The court's roll, split into the kids who are here and the kids who are not.
    ///
    /// A closed court lists nobody — there is nobody on it. That is the card's rule
    /// (`TodayCourts.roster(for:from:preview:isExpanded:)` guards on exactly this) and it holds
    /// here rather than being quietly relaxed: the kids are still on the court in the graph, and
    /// two screens disagreeing about what "closed" means is worse than a screen that says less.
    /// What this one adds is the reason, in words, where the card only badges it.
    private var detailRoster: CourtDetailRoster {
        guard !status.isClosed, let camp = store.camp else { return .none }
        return CourtDetailRoster.build(forCourt: groupID, in: camp, day: store.today)
    }

    /// Every note written against this court, pinned ones first and newest first within that.
    ///
    /// `groupID` is the scope. `pinned` is read only as a sort key and never as a filter — it is
    /// a flag an admin sets on a camp-wide message, it is not backfilled, and a court whose notes
    /// are all unpinned is the ordinary case rather than an empty section.
    ///
    /// Resolved notes are left out. Taking a note down has to take it down everywhere, and
    /// `OverviewView` already reads the banner the same way.
    private var courtNotes: [InboxItem] {
        store.inboxItems
            .filter { $0.groupID == groupID && $0.kind == .note && !$0.resolved }
            .sorted {
                if $0.pinned != $1.pinned { return $0.pinned }
                return $0.createdAt > $1.createdAt
            }
    }

    // MARK: - Content

    /// The design's `gap:9px` column. Each block carries its own trailing gap rather than taking
    /// one from a `VStack`: a block with nothing to draw resolves to `EmptyView`, and spacing
    /// applied between children leaves a hole where the block would have been.
    @ViewBuilder
    private func content(roster: CourtDetailRoster, notes: [InboxItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            notesSection(notes)
            hereSection(roster)
            awaySection(roster)
        }
    }

    // MARK: Notes

    @ViewBuilder
    private func notesSection(_ notes: [InboxItem]) -> some View {
        if !notes.isEmpty {
            // The first overline on the screen, which section 8 leads with 2pt rather than the 6
            // it puts between sections.
            AttendanceOverline(title: "Notes", count: notes.count)
                .padding(.top, OnTheDayTokens.overlineLead)

            Card(radius: OnTheDayTokens.card) {
                ForEach(notes) { note in
                    CourtNoteRow(item: note)
                }
            }
            .padding(.bottom, OnTheDayTokens.contentGap)
        }
    }

    // MARK: Who is on it

    @ViewBuilder
    private func hereSection(_ roster: CourtDetailRoster) -> some View {
        AttendanceOverline(title: "On this court", count: roster.here.rows.count)
            .padding(.top, OnTheDayTokens.overlineBreak)

        if roster.here.isEmpty {
            emptyLine
        } else {
            Card(radius: OnTheDayTokens.card) {
                ForEach(roster.here.rows) { row in
                    kidRow(row)
                }
            }
        }
    }

    /// Why the list above is empty, which is two different facts wearing one shape.
    ///
    /// The reason is set down exactly as it was written. A closure reason is a capitalised
    /// fragment — "Net down", "Tom is on it" — and folding it into a lower-case clause would need
    /// to know which of those is a name. There is no way to tell, and "tom is on it" is the cost
    /// of guessing wrong, so the sentence is built to read with the fragment left alone.
    private var emptyLine: some View {
        let words: String = {
            if case .closed(let reason) = status {
                return "This court is out of play — \(reason). Nobody is on it today."
            }
            return "Nobody is on this court today."
        }()

        return Text(words)
            .typeStyle(.meta, color: Theme.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, OnTheDayTokens.overlineInset)
    }

    // MARK: Who is not

    /// The section Overview has no room for and the card deliberately does not draw.
    ///
    /// Absent on the ordinary morning: a court with everybody in shows no heading at all, rather
    /// than a heading over "0 away", which reads as something that failed to load.
    @ViewBuilder
    private func awaySection(_ roster: CourtDetailRoster) -> some View {
        if !roster.away.isEmpty {
            AttendanceOverline(title: "Away today", count: roster.away.count)
                .padding(.top, OnTheDayTokens.overlineBreak)

            Card(radius: OnTheDayTokens.card) {
                ForEach(roster.away) { row in
                    kidRow(row)
                }
            }
        }
    }

    // MARK: A kid

    /// One name, and the way to the kid behind it.
    ///
    /// The drawn line is `CourtRosterRow` exactly as a court card draws it — 13.5/400, unclipped,
    /// its marks at the end — with the tap grown around it to the 44pt minimum. The row stays a
    /// line that takes no gestures of its own; a list you can open is a property of this screen,
    /// not of the row, and a card that only reads must keep drawing the same kid identically.
    private func kidRow(_ row: PlayerRow) -> some View {
        Button {
            openKid(row.id)
        } label: {
            CourtRosterRow(row: row)
                .padding(.horizontal, OnTheDayTokens.cardInset)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Set outright rather than lifted off the row inside the label — see
        // `CourtRosterRow.spokenLabel(for:)` for why a button that leaves this to inference can
        // end up as one of eight controls all called "Button".
        .accessibilityLabel(CourtRosterRow.spokenLabel(for: row))
        .accessibilityHint("Opens their screen")
    }

    // MARK: - Intents

    /// `8q`, for the kid tapped.
    ///
    /// Through the root's one `pushedScreen` slot, which **replaces this screen rather than
    /// stacking on it**. That is what the slot is: one screen at a time, no stack, because the
    /// tab bar is an overlay in `RootView` and a real push would slide underneath it. Two
    /// precedents, both in the app already — `RankView` opens a kid the same way from a screen
    /// that is itself presented, and `BlockDetailView.openAttendance` states the rule outright
    /// ("a cover cannot be presented over a cover") and closes `8l` on its way to `8m`.
    ///
    /// So the kid's back caret returns to Overview and not to this court. That is the behaviour
    /// every other route into `8q` already has, and the alternative — this screen presenting its
    /// own copy of `PlayerScreen` — is worse: `PlayerScreen` dismisses itself by clearing
    /// `store.pushedScreen`, which from underneath a locally presented cover would take this
    /// screen away and leave the kid's on top of nothing.
    ///
    /// The one thing that cannot be checked without a device: this is a cover replacing a cover
    /// through a single `.fullScreenCover(item:)`, so it turns on SwiftUI re-presenting when the
    /// item's identity changes. `PushedScreen.id` carries the payload for exactly that reason.
    private func openKid(_ playerID: Player.ID) {
        store.pushedScreen = .player(playerID)
    }
}

// MARK: - Previews

#Preview("A court") {
    CourtScreen(store: OverviewFixtures.courtStore, groupID: OverviewFixtures.drills.id)
        .showsMockStatusBar()
}

/// A court with nothing written against it — no notes section at all, which is what most courts
/// look like.
#Preview("A court — no notes") {
    CourtScreen(store: OverviewFixtures.courtStore, groupID: OverviewFixtures.matchPlay.id)
        .showsMockStatusBar()
}

/// Out of play: the badge, the reason in the lede, and the empty list saying why rather than
/// leaving a reader to wonder where a whole court's kids went.
#Preview("A court — closed") {
    CourtScreen(store: OverviewFixtures.courtStore, groupID: OverviewFixtures.netDown.id)
        .showsMockStatusBar()
}

/// Every colour here is a `Theme` token, so the dark scheme is a check rather than a second
/// design — but this screen carries the palette's warmest values and those are the ones a derived
/// dark column is most likely to get wrong.
#Preview("A court — dark") {
    CourtScreen(store: OverviewFixtures.courtStore, groupID: OverviewFixtures.drills.id)
        .showsMockStatusBar()
        .preferredColorScheme(.dark)
}

/// The app caps Dynamic Type at `.accessibility1`. The header's coach pill and status badge sit
/// on one row, and the roster's rank column is what breaks first if a width is fixed rather than
/// scaled.
#Preview("A court — accessibility1") {
    CourtScreen(store: OverviewFixtures.courtStore, groupID: OverviewFixtures.drills.id)
        .showsMockStatusBar()
        .dynamicTypeSize(.accessibility1)
}
