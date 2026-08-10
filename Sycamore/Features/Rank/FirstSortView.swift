//
//  FirstSortView.swift
//  Sycamore
//
//  `4c` — the first sort (`design/rebuild/section-t4.html:167-201`). Two kids, one question,
//  until a venue has a ladder.
//
//  ── WHY IT SITS BESIDE `RankView` RATHER THAN INSIDE IT ──────────────────────────────────────
//
//  `RankView` (`:24`) is the *other* job on the same order: a hundred rows, a drag handle, and a
//  ladder that already exists being corrected one kid at a time. This screen is the one that has
//  no ladder to correct yet. They share a write path (`AppStore.commitRankOrder(_:)`,
//  `AppStore.swift:1230`) and nothing else — this one draws no rows, offers no drag, and asks a
//  question the other never asks. So they are two files in one folder rather than two modes of one
//  screen, and `PushedScreen.rank`'s doc (`AppStore.swift:84-90`) says the same thing from the
//  store's side.
//
//  ── WHAT THIS FILE OWNS AND WHAT IT DOES NOT ────────────────────────────────────────────────
//
//  None of the arithmetic. `FirstSort` (`Models/FirstSort.swift`) is a pure value that owns the
//  ladder, the queue, the search window and the four answers; `AppStore` owns the session
//  (`beginFirstSort(in:)` `:1248`, `answerFirstSort(_:)` `:1260`, `finishFirstSort()` `:1321`).
//  This file draws them and decides *when* the fourth of those may be called — which is the one
//  genuinely load-bearing decision on the screen. See `settledColumn`.
//
//  ── THE TWO STRINGS THE DESIGN WRITES THAT THE APP CANNOT ────────────────────────────────────
//
//  `4c` sets a meta line reading `13 · returning · Group 1 last summer` (`:189`). Nothing on
//  `Player` (`Models.swift:554-640`) and no column in `players` holds a previous season's
//  placement — `groupID` is *this* summer's court — so that clause is dropped rather than faked
//  from a field that means something else. `FirstSortCopy.meta(for:)` draws the rest.
//
//  And the footnote reads "Splits into groups of 8" (`:200`). There is no rule anywhere in this
//  app that says eight. `GroupsRules.opensAt` (`GroupsTokens.swift:277`) is a *gate* — Groups
//  opens at eight kids — and the 8 in the seeded camp is `playerMax / groupCount` landing on it by
//  coincidence. The real split is a deal across the venue's courts, so the number is derived from
//  the venue being sorted: see `FirstSortCopy.splitSize(roll:courts:)`, which is the only honest
//  way to write a sentence that has to hold for a venue shaped differently.
//

import SwiftUI

// MARK: - Tokens

/// What `4c` draws that `Spacing`, `Radius` and `OnTheDayTokens` do not already carry.
///
/// Feature-local rather than pushed into the design system, which is the precedent `GroupsMetrics`
/// and `OnTheDayTokens` both set: a value lives with the screen that reads it until a second
/// screen asks for it. Every number here is transcribed from the design's inline CSS.
enum FirstSortMetrics {

    /// `width:36px; height:36px; border-radius:99px; background:#F1F2F5` — the back disc
    /// (`design/rebuild/section-t4.html:174`). Both existing section-8 headers draw a bare glyph
    /// in a 44pt frame instead; this is the first header in the app to use `CircleIconButton`.
    static let backDiameter: CGFloat = 36
    /// `font-size:18px` on the `ph-arrow-left` inside it.
    static let backGlyph: CGFloat = 18

    /// How far `CircleIconButton`'s 44pt hit frame (`Components.swift:1091`) overhangs the 36pt
    /// disc it is drawn around.
    ///
    /// It has to be spent twice or the crumb row lands 4pt off the design in two places at once:
    /// the disc would sit at 26 from the screen edge instead of 22, and the gap between it and
    /// "Groups" would read 13 instead of 9. Subtracting it from both is what puts the *drawn*
    /// circle where the design puts it while leaving the target at its full 44 — the same trade
    /// `SectionHeader` makes with negative padding (`Components.swift:101-104`).
    static let backOverhang: CGFloat = (HitTarget.minimum - backDiameter) / 2

    /// The crumb row's own leading inset. The trailing edge keeps `Spacing.header`, because
    /// nothing over there is a control and "3 skipped" is aligned to the design's 22pt gutter.
    static let crumbInset: CGFloat = Spacing.header - backOverhang
    /// `gap:9px` between the disc and "Groups", less the overhang above.
    static let crumbGap: CGFloat = OnTheDayTokens.contentGap - backOverhang

    /// `padding:18px 12px` on the content column. The 12 is `Spacing.gutter`; 18 sits between
    /// `Spacing.large` (16) and `Spacing.section` (22) and has no token, so it gets a name here.
    static let columnInset: CGFloat = 18

    /// `width:52px; height:52px` (`:187`) — the largest initials disc in the app.
    static let avatarSize: CGFloat = 52

    /// Air inside a player card.
    ///
    /// The design gives the card none: both cards are `flex:1` and centre their contents in
    /// whatever height is left over, so at the drawn type size the padding is invisible. It is
    /// here for the size the design does not draw — at an accessibility type size the column
    /// scrolls and the cards fall back to their intrinsic height, and a card that hugs its
    /// contents to the pixel reads as a mistake rather than as a button.
    static let cardInset: CGFloat = Spacing.section

    /// `style-active="transform:scale(.975)"` (`:186`) — how far a card drops under a thumb.
    static let pressScale: CGFloat = 0.975

    /// `padding:4px 0 2px` around the answer row (`:197`).
    static let answerLead: CGFloat = 4
    static let answerTrail: CGFloat = 2
    /// The gap between the two answers, which the design does not draw. See `answerRow`.
    static let answerGap: CGFloat = Spacing.small
}

/// The three type styles `4c` sets that the shared table does not name.
enum FirstSortType {

    /// `600 21px`, `-.03em` — a kid's name on a card (`:188`). `.venueHeading` is `600 17/-.03em`
    /// (`Typography.swift:256`), so resizing it lands on the design exactly and no new entry in
    /// the shared table is needed.
    static let name = TypeStyle.venueHeading.size(21)

    /// `600 16px` inside the 52pt disc (`:187`). `TypeStyle.initials(forAvatarSize: 52)` returns
    /// `600 15` (`Typography.swift:442-448`), a ratio read off the 36–46pt discs; the design sets
    /// this one a half-point family larger. Passed through `InitialsAvatar`'s `font:` override
    /// rather than bent into that ladder, which every other avatar in the app is measured against.
    static let initials = TypeStyle(size: 16, weight: .semibold)

    /// The serif sentence a settled ladder is announced in — `400 22`, `-.02em`
    /// (`Typography.swift:254`). One step under `OnTheDayTitle`'s 30, because the screen already
    /// has a title and this is the answer under it rather than a second heading.
    static let settled = TypeStyle.sheetTitle
}

// MARK: - Copy

/// Every sentence on `4c` that is composed rather than literal.
///
/// A namespace rather than methods on the views, because two of these are the screen's whole
/// contribution to being *true* — the meta line and the split figure — and both are worth asking
/// questions of directly. They need no store, no environment and no main actor; see
/// `SycamoreTests/FirstSortCopyTests.swift`.
enum FirstSortCopy {

    /// `13 · returning` / `12 · new this summer` — the line under a name on a card.
    ///
    /// **Not `Player.metaLine`** (`Models.swift:637-644`), which writes `13 · F · returning`, and
    /// the two differences are both the design's:
    ///
    /// *Gender is dropped.* Every other screen in the app carries it, and `4c` (`:189`, `:195`) is
    /// the one place it is left out. That reads as deliberate rather than as an omission: this
    /// screen asks a single question about two children and nothing else on it is a fact you are
    /// meant to weigh. Reusing `metaLine` here would put a letter under both names that the
    /// question is not about.
    ///
    /// *A first-timer says so.* `metaLine` writes "returning" or nothing; `4c` writes "returning"
    /// or "new this summer", which is the more useful half — a new kid is the one with no prior
    /// season behind their placing, and that is exactly what somebody comparing two of them wants
    /// to know.
    ///
    /// What is missing from both is the design's third clause, "Group 1 last summer". No field
    /// holds it, `groupID` is this summer's court, and inventing it from the current placement
    /// would put a confident sentence about last year in front of somebody who is about to rank a
    /// child on it. So the clause is dropped and the separator with it.
    ///
    /// An unknown age drops out rather than showing as a gap, which is the rule `metaLine` already
    /// states (`Models.swift:633-636`) and the reason this returns a joined array rather than an
    /// interpolation.
    static func meta(for player: Player) -> String {
        var parts: [String] = []
        if let age = player.age { parts.append("\(age)") }
        parts.append(player.isReturning ? "returning" : "new this summer")
        return parts.joined(separator: " · ")
    }

    /// `SC` for Serene Chu, `CI` for Caleb Ito — the letters inside the 52pt disc (`:187`, `:194`).
    ///
    /// **Not `Initials.make(from:)`** (`Models.swift:20-26`), which is the whole app's initials
    /// helper and is the wrong one here. It takes the first *two characters of one string*, which
    /// is right for the one-word names it was written against — a coach called "Nass" reads "NA" —
    /// and answers "SE" for Serene Chu. A kid is not stored as one string: `firstName` and
    /// `lastInitial` are two fields precisely because camps write kids as "Serene C"
    /// (`Models.swift:559`), so the two initials are already sitting there and `displayName`
    /// (`:587`) is the thing assembled out of them. Reading the fields is both correct and cheaper
    /// than formatting a name in order to take it apart again.
    ///
    /// `lastName` is the fallback for a roster row that arrived with a surname and no initial, and
    /// the em dash at the end is `Initials.make`'s own answer to a name that is not one — kept so
    /// an empty disc looks the same here as it does everywhere else.
    static func initials(for player: Player) -> String {
        let given = player.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        var family = player.lastInitial.trimmingCharacters(in: .whitespacesAndNewlines)
        if family.isEmpty {
            family = (player.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let letters = (given.prefix(1) + family.prefix(1)).uppercased()
        return letters.isEmpty ? "—" : letters
    }

    /// "30 of 42 placed" (`:182`).
    static func progress(placed: Int, total: Int) -> String { "\(placed) of \(total) placed" }

    /// "3 skipped" (`:176`).
    static func skipped(_ count: Int) -> String { "\(count) skipped" }

    /// What the courts at this venue will hold once the ladder is dealt across them.
    ///
    /// **This is the number the design hard-codes as 8, and it is derived here instead.**
    /// `Camp.redistribute(in:across:)` (`Models.swift:1417`) hands the venue's whole roll to
    /// `deal(_:across:)` (`:1388`), which gives the first `roll % courts` courts one kid more than
    /// the rest and every other court `roll / courts`. So the sizes are not a rule to be looked
    /// up — they are that division, and this spells it:
    ///
    /// * an even division is one figure, which is the sentence the design draws;
    /// * an uneven one is two, and *both* are real — some courts genuinely end one kid heavier,
    ///   and rounding it to a single number would be the same lie the literal 8 is;
    /// * a venue with one court does not split at all, and saying it "splits into groups of 42"
    ///   would be describing a division that never happens;
    /// * fewer kids than courts is the degenerate end of the same arithmetic — some courts take
    ///   one and the rest take none — where "groups of 0 and 1" is arithmetically right and
    ///   unreadable.
    ///
    /// Returns the noun phrase alone so the two sentences that need it (`footnote` and
    /// `settledDetail`) share one derivation instead of agreeing by hand.
    static func splitSize(roll: Int, courts: Int) -> String {
        guard roll > 0, courts > 0 else { return "groups" }
        guard courts > 1 else { return "one group of \(roll)" }

        let base = roll / courts
        let remainder = roll % courts
        guard base > 0 else { return "one kid to a group" }
        guard remainder > 0 else { return "groups of \(base)" }
        return "groups of \(base) and \(base + 1)"
    }

    /// "Splits into groups of 8 when the ladder settles" (`:200`), with the figure derived.
    static func footnote(roll: Int, courts: Int) -> String {
        "Splits into \(splitSize(roll: roll, courts: courts)) when the ladder settles"
    }

    /// The serif sentence a finished sort opens with.
    ///
    /// The design draws only the mid-sort screen, so this is the app's answer to "what does
    /// settled look like". House rule: an empty state names the *reason* it is empty rather than
    /// the absence, in a complete sentence, with one action — so it says who has a place rather
    /// than "no more questions", and it names the skipped kids out loud. Somebody who set three
    /// children aside needs to be told where they went before they press the button that writes
    /// it: the foot of the venue is where `FirstSort.playerIDs()` puts them
    /// (`Models/FirstSort.swift:235`) and nothing else on the screen says so.
    static func settled(venueName: String, skipped: Int) -> String {
        switch skipped {
        case ..<1:
            return "Everyone at \(venueName) has a place on the ladder."
        case 1:
            // "the 1 kid" would be a count where the sentence wants a person; one of anything is
            // spelled by naming it, which is the rule `Group.capacityBanner`
            // (`Models.swift:600-606`) already follows for its own singular.
            return "Everyone at \(venueName) has a place, and the kid you skipped sits at the foot of the ladder."
        default:
            return "Everyone at \(venueName) has a place, and the \(skipped) kids you skipped sit at the foot of the ladder."
        }
    }

    /// The grey line under it, which is the footnote's promise restated in the tense it is about
    /// to be kept in. Same derivation, so the two cannot come to disagree.
    static func settledDetail(roll: Int, courts: Int) -> String {
        "Splitting now makes \(splitSize(roll: roll, courts: courts))."
    }
}

// MARK: - The screen

struct FirstSortView: View {

    /// The venue being sorted, carried by the route rather than read from `store.readVenueID`.
    ///
    /// `PushedScreen.firstSort` (`AppStore.swift:92-98`) already argues this: the sort takes
    /// minutes, and a venue pill tapped on the tab underneath must not change which kids the
    /// question on screen is about.
    let venueID: Venue.ID

    @Environment(AppStore.self) private var store
    /// What decides whether the content column is the design's fixed one or a scroll view.
    /// See `content`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The sort as it read at the moment the split was pressed, held for the dismissal.
    ///
    /// `finishFirstSort()` clears `store.firstSort` and `store.pushedScreen` in the same breath
    /// (`AppStore.swift:1332-1333`), and the cover animates out over the frames after that — with
    /// this view still on screen and still observing a store whose sort is now nil. Without a copy
    /// the settled sentence would be swapped for `strandedColumn` and the whole screen would
    /// announce a fault on its way out, at the one moment nothing has gone wrong at all.
    ///
    /// It is never cleared, and it does not need to be: the only thing that sets it is the button
    /// that ends the screen, and the next sort arrives on a fresh view.
    @State private var committed: FirstSort?

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8` — the same warmer page `8o` sets (`GroupsView.swift:102`), which is the tab
        // this screen is pushed from and returns to.
        .background(Theme.surfaceWarm)
        // One tap when a kid is actually seated, rather than one per answer. Most answers only
        // halve the search window and nothing on screen finishes; `placed` moving is the moment
        // the ladder grew, which is what the progress bar is animating at the same instant.
        .sensoryFeedback(trigger: liveSort?.placed ?? 0) { previous, current in
            current > previous ? .impact(weight: .light) : nil
        }
    }

    // MARK: The white header block

    /// `background:#fff; padding:14px 22px 0; border-bottom:1px solid #EDEEF1` (`:173`).
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            crumbRow
                .padding(.leading, FirstSortMetrics.crumbInset)
                .padding(.trailing, Spacing.header)

            OnTheDayTitle("First sort")
                .padding(.horizontal, Spacing.header)
                // `margin-top:15px`, taken to `Spacing.large`. The same 15→16 rounding
                // `CourtHeader.swift:59` already makes.
                .padding(.top, Spacing.large)

            // The em dash is the design's own (`:179`), and house style keeps it.
            Text("Tap the stronger player — the ladder builds itself")
                .typeStyle(.onTheDayLede, color: Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.header)
                .padding(.top, Spacing.small)

            progress
                .padding(.horizontal, Spacing.header)
                .padding(.top, OnTheDayTokens.headerTop)
                .padding(.bottom, Spacing.large)
        }
        .padding(.top, OnTheDayTokens.headerTop)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline(color: Theme.hairline) }
    }

    /// The back disc, "Groups", and the skipped count on the right.
    ///
    /// The two words are one accessibility element on purpose. "3 skipped" is a readout and not a
    /// control — nothing happens when it is touched — so left standing alone VoiceOver would offer
    /// it as a stop on the way to the cards, which are the only things on this screen worth
    /// reaching. Folded into the crumb it is read once, in passing, as part of where you are.
    private var crumbRow: some View {
        HStack(spacing: FirstSortMetrics.crumbGap) {
            CircleIconButton(
                systemName: "arrow.left",
                size: FirstSortMetrics.backDiameter,
                iconSize: FirstSortMetrics.backGlyph,
                tone: .filled,
                action: leave
            )
            .accessibilityLabel("Back to Groups")

            HStack(spacing: Spacing.small) {
                Text("Groups")
                    .typeStyle(.onTheDayCrumb, color: Theme.inkMuted)

                Spacer(minLength: 0)

                if let skipped = liveSort?.skipped.count, skipped > 0 {
                    Text(FirstSortCopy.skipped(skipped))
                        .typeStyle(.rowDetail, color: Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// `height:4px` track, `width:71%` fill, `600 12.5` figure (`:181-182`).
    ///
    /// `ProgressTrack` (`Components.swift:790`) is the same bar `8m` pins in its own header; the
    /// two disagree only on how the figure beside it is set, which is why that component takes the
    /// style rather than defaulting one.
    private var progress: some View {
        let sort = liveSort
        return ProgressTrack(
            value: sort?.placed ?? 0,
            total: sort?.total ?? 0,
            label: FirstSortCopy.progress(placed: sort?.placed ?? 0, total: sort?.total ?? 0),
            labelStyle: .metaStrong,
            labelColor: Theme.inkWarm,
            accessibilityLabel: "Placed"
        )
    }

    // MARK: The content column

    /// `flex:1; padding:18px 12px; gap:10px; overflow:hidden` (`:185`) — and a scroll view at
    /// accessibility type sizes.
    ///
    /// The design's column does not scroll: both cards are `flex:1` and split whatever is left
    /// between the header and the footnote, which is what makes the two of them equal targets no
    /// matter how long the names are. That holds at every size the design draws and at none of the
    /// accessibility ones, where two 21pt names set at 310% plus a footnote are taller than the
    /// frame and the fixed column simply clips — losing "About even" first and the footnote with
    /// it.
    ///
    /// So the branch is on the type size rather than on measurement: below the accessibility sizes
    /// the column is the design's, and at or above them it scrolls and the cards fall back to
    /// their intrinsic height. `maxHeight: .infinity` costs nothing inside a scroll view — it
    /// resolves to the ideal — so one card view serves both, which is why `cardInset` exists.
    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { column }
                .scrollIndicators(.hidden)
        } else {
            column.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var column: some View {
        SwiftUI.Group {
            if let sort = liveSort, let pair = sort.pair, let camp = store.camp,
               let candidate = camp.player(pair.candidate),
               let incumbent = camp.player(pair.incumbent) {
                askingColumn(sort, candidate: candidate, incumbent: incumbent)
            } else if let sort = liveSort, sort.isSettled {
                settledColumn(sort)
            } else {
                strandedColumn
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, FirstSortMetrics.columnInset)
    }

    // MARK: Asking

    private func askingColumn(
        _ sort: FirstSort, candidate: Player, incumbent: Player
    ) -> some View {
        VStack(spacing: OnTheDayTokens.blockGap) {
            FirstSortPlayerCard(player: candidate) {
                store.answerFirstSort(.candidate)
            }

            versus

            FirstSortPlayerCard(player: incumbent) {
                store.answerFirstSort(.incumbent)
            }

            answerRow(candidate: candidate)

            // The roll is the sort's own total rather than a fresh count of the venue, and the two
            // can disagree — a kid enrolled at the desk while this was running is in the camp and
            // not in the sort. `total` is the number already on screen a few points above, in
            // "30 of 42 placed", and a footnote quoting a *different* 42 would be the screen
            // contradicting itself over a kid nobody here has been asked about yet.
            Text(FirstSortCopy.footnote(roll: sort.total, courts: courtCount))
                .typeStyle(.rowDetail, color: Theme.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.small)
        }
    }

    /// Two 1px rules with "vs" between them (`:191`). Punctuation, so it is hidden rather than
    /// read — VoiceOver already announces both cards as buttons in order.
    private var versus: some View {
        HStack(spacing: Spacing.medium) {
            Hairline(color: Theme.strokeChip)
            Text("vs")
                .typeStyle(.metaStrong, color: Theme.inkFaint)
            Hairline(color: Theme.strokeChip)
        }
        .padding(.horizontal, Spacing.small)
        .accessibilityHidden(true)
    }

    /// "About even", and the control the design counts but does not draw.
    ///
    /// `4c` puts "3 skipped" in its header (`:176`), so setting a kid aside is something the
    /// screen can do — but the only control it draws below the cards is "About even" (`:198`).
    /// The skip has to be somewhere, and this is the row it belongs in: both are answers about the
    /// pair on screen, and neither is a card. Putting it in the crumb row instead — the other
    /// candidate, since the count lives there — would make the one line on the screen that says
    /// *where you are* also the line that changes what you are looking at.
    ///
    /// They are not drawn as equals. "About even" keeps the design's `.quietOutline` — a 1.5pt
    /// `stroke` rule around `inkWarm` — and the skip takes `.outline`, which is the same shape one
    /// step quieter (`Components.swift:430-453`). That ordering is the honest one: an even pair is
    /// an answer, and a skip is a refusal to give one.
    ///
    /// `ViewThatFits` because both labels grow with Dynamic Type and the skip names its kid; two
    /// pills that no longer fit side by side stack instead of truncating.
    private func answerRow(candidate: Player) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: FirstSortMetrics.answerGap) {
                aboutEven
                skip(candidate)
            }
            VStack(spacing: FirstSortMetrics.answerGap) {
                aboutEven
                skip(candidate)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FirstSortMetrics.answerLead)
        .padding(.bottom, FirstSortMetrics.answerTrail)
    }

    /// `border:1.5px solid #E4E5E9; border-radius:999px; padding:11px 24px; font:600 13.5px;
    /// color:#3F4A44` (`:198`). "About even" is the design's own literal and is kept.
    private var aboutEven: some View {
        Pill(
            "About even",
            tone: .quietOutline,
            font: .timelineTitle,
            horizontalPadding: 24,
            verticalPadding: 11,
            borderWidth: BorderWidth.input
        ) {
            store.answerFirstSort(.aboutEven)
        }
        .accessibilityHint("Seats them just below the other kid and asks nothing further")
    }

    /// The kid's first name rather than "Skip", because a button names its object and the object
    /// here is the child on the *top* card — `FirstSort.skip()` sets the candidate aside, not the
    /// pair (`Models/FirstSort.swift:213`). "Skip" alone would leave which of the two ambiguous at
    /// the one moment both are on screen.
    private func skip(_ candidate: Player) -> some View {
        Pill(
            "Skip \(candidate.firstName)",
            tone: .outline,
            font: .timelineTitle,
            horizontalPadding: 18,
            verticalPadding: 11
        ) {
            store.answerFirstSort(.skip)
        }
        .accessibilityHint("Sets them aside at the foot of the venue and moves on")
    }

    // MARK: Settled

    /// What "when the ladder settles" turns out to be.
    ///
    /// **The button is drawn only here, and that is still the point** — but it is no longer the
    /// only thing standing between an unsettled sort and a lost child. `FirstSort.playerIDs()` is
    /// `ladder + skipped` (`Models/FirstSort.swift:235`), and a kid in flight is in neither, so a
    /// commit taken mid-question would hand `commitRankOrder` an assignment with one child missing
    /// from it. `finishFirstSort()` refuses an unsettled sort outright now
    /// (`AppStore.swift:1322`); this branch is what makes the refusal unreachable through the
    /// screen rather than what implements it. It exists only where `pair` is nil, and `pair` is nil
    /// exactly when the sort has settled.
    ///
    /// **The action is one call, and it is two writes on the other side of it.** The store commits
    /// the ladder and then deals this venue's courts, because `applyRankOrder`
    /// (`Models.swift:1321`) renumbers `overallRank` and moves nobody — a sort committed and left
    /// there would give the venue a brand new ladder and courts still holding whoever they held
    /// this morning, every band on `8o` reading a range with holes in it. Both halves are argued
    /// where they run (`AppStore.swift:1271-1320`), including why the deal is the venue-scoped
    /// `spreadKids` and not `evenOut()`.
    ///
    /// This view used to make the second call itself, and check `store.errorMessage` in between.
    /// That is the store's now for the reason the guard moved with it: which half of a write ran
    /// should not depend on what a screen remembered to do next.
    private func settledColumn(_ sort: FirstSort) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.section)

            VStack(spacing: Spacing.small) {
                Text(FirstSortCopy.settled(venueName: venueName, skipped: sort.skipped.count))
                    .typeStyle(FirstSortType.settled, color: Theme.ink)
                    .accessibilityAddTraits(.isHeader)

                Text(FirstSortCopy.settledDetail(roll: sort.total, courts: courtCount))
                    .typeStyle(.onTheDayLede, color: Theme.inkMuted)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.large)

            Spacer(minLength: Spacing.section)

            PrimaryButton("Split \(venueName) into groups", action: split)
        }
        .frame(maxWidth: .infinity)
    }

    /// The sort is gone, or the pair it was asking about is.
    ///
    /// Reachable two ways, both of them the camp changing underneath a screen that takes minutes:
    /// a kid on screen removed from the roll by another device, or `store.firstSort` replaced by a
    /// sort of a different venue. Named rather than drawn blank, and given the one thing that
    /// fixes it — the seed is the same roll in the same order, so starting again costs only the
    /// answers already given.
    private var strandedColumn: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.section)

            Text("This venue's roll changed while the sort was running.")
                .typeStyle(FirstSortType.settled, color: Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.large)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Spacing.section)

            PrimaryButton("Start the first sort again") {
                store.beginFirstSort(in: venueID)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Derived

    /// The sort this screen is drawing, which is the store's until the split is pressed.
    ///
    /// The venue is checked here rather than at each reader. `store.firstSort` is a single slot and
    /// `beginFirstSort(in:)` replaces whatever is in it (`AppStore.swift:1244-1247`), so a screen
    /// left presented while another venue's sort is started would otherwise draw that venue's
    /// question under this venue's name.
    private var liveSort: FirstSort? {
        if let committed { return committed }
        guard let sort = store.firstSort, sort.venueID == venueID else { return nil }
        return sort
    }

    private var venueName: String {
        store.camp?.venue(venueID)?.name ?? "this venue"
    }

    /// How many courts the split will actually be dealt across.
    ///
    /// Counted from the camp graph rather than read off `Venue.groupCount`, which is the *intended*
    /// number: `syncGroups(for:)` (`Models.swift:1417`) is what makes the two agree, and it is the
    /// courts that exist right now that `deal(_:across:)` will divide the roll between.
    private var courtCount: Int {
        store.camp.map { $0.groups(in: venueID).count } ?? 0
    }

    // MARK: Intents

    /// The way out, and it deliberately leaves `store.firstSort` standing.
    ///
    /// There is no draft of a sort anywhere — it is store state and nothing writes it down
    /// (`AppStore.swift:148-152`) — so clearing it here would spend thirty answered questions on
    /// one tap of a back arrow, with no confirmation the design draws and no way to get them back.
    /// Leaving it set costs nothing and buys the resume: Groups reopens this screen rather than
    /// re-seeding when a sort of this venue is still in flight (`GroupsView.swift`, `openFirstSort`).
    ///
    /// It is still discarded eventually, and by the two things that should discard it:
    /// `finishFirstSort()` clears it on commit, and `beginFirstSort(in:)` replaces it when another
    /// venue is asked for.
    private func leave() {
        store.pushedScreen = nil
    }

    /// Hold the sort for the dismissal, then hand the whole thing to the store.
    ///
    /// The `isSettled` test is read rather than enforced here: it decides what `committed` is worth
    /// holding, and `finishFirstSort()` applies the same test to the write itself
    /// (`AppStore.swift:1322`). It was the enforcement once, and its own comment called an unsettled
    /// finish "the one mistake on `4c` that costs a child their place" while the store's comment
    /// blessed exactly that — a rule stated in two places, in opposite directions, and enforced only
    /// in the one a rewrite could delete.
    ///
    /// One call and not two. The ladder and the deal that follows it are both the store's now; see
    /// `settledColumn` for what that changed and `AppStore.finishFirstSort()` for why.
    private func split() {
        guard let sort = store.firstSort, sort.isSettled else { return }
        committed = sort

        Task { await store.finishFirstSort() }
    }
}

// MARK: - A player card

/// One of the two cards — a whole card that is a button.
///
/// `background:#fff; border:1px solid #EDEEF1; border-radius:16px`, contents centred on both axes
/// with `gap:9px` (`design/rebuild/section-t4.html:186-190`).
///
/// The card is the control rather than something inside it, which is what the design's
/// `style-active` on the whole card says and what the screen is for: the question is "which of
/// these two", and a target that is half the frame is what makes answering it forty times
/// possible. That also settles the accessibility shape — one button carrying the name and the
/// meta line as its label, rather than three elements a reader has to walk past to reach the tap.
private struct FirstSortPlayerCard: View {

    let player: Player
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Card(radius: OnTheDayTokens.card, isDivided: false) {
                VStack(spacing: OnTheDayTokens.contentGap) {
                    InitialsAvatar(
                        FirstSortCopy.initials(for: player),
                        size: FirstSortMetrics.avatarSize,
                        tone: .neutralStrong,
                        font: FirstSortType.initials
                    )

                    Text(player.displayName)
                        .typeStyle(FirstSortType.name, color: Theme.ink)

                    Text(FirstSortCopy.meta(for: player))
                        .typeStyle(.subtitle, color: Theme.inkMuted)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, FirstSortMetrics.cardInset)
                // `Card` lays its content out leading-aligned (`Components.swift:159`), so the
                // centring is claimed here rather than left to the card.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(FirstSortCardPress())
        .accessibilityLabel("\(player.displayName), \(FirstSortCopy.meta(for: player))")
        .accessibilityHint("Picks them as the stronger player")
    }
}

/// `transform:scale(.975)` while a card is held (`design/rebuild/section-t4.html:186`).
///
/// A `ButtonStyle` rather than a `@GestureState` on the card, because the press state has to
/// survive the card being rebuilt — which it is on *every* answer, since the kid on it changes.
///
/// Gated on Reduce Motion like every other movement in this app (`Motion.fold(reduceMotion:)`,
/// `Motion.fold(reduceMotion:)`, `Motion.swift:57`). A scale is a change of size rather than of
/// position, and the setting covers
/// it: the card still answers the tap, it simply does not flinch first.
///
/// **`easeOut` over 90ms, not `.snappy(duration: 0.14)`, and the curve matters more here than the
/// number.** `.snappy` is a spring with `bounce: 0.15`, and a spring with bounce does not stop at
/// its target — it passes it and comes back. On a fold that is the point; on a press it means the
/// card *grows past 1.0* on release, so lifting a thumb makes the kid's card swell a shade larger
/// than it sits at rest. The press the design draws is one movement in one direction: down 2.5%
/// under the thumb, back to where it was, no overshoot on either leg. `easeOut` is that, and 90ms
/// is short enough that a tap answered on the way down still reads as instant.
///
/// **This is the app's only press `ButtonStyle`, which is why the curve is argued rather than
/// picked.** Every press style written after it will be read off this one, and a bounce inherited
/// nine times is a house style nobody chose.
///
/// Hard-coded rather than a `Motion.press` beside `Motion.fold`, and deliberately so *for now*:
/// `Motion.swift`'s own header sets the bar at "a duration is admitted when a second file needs
/// it", and today exactly one file plays a press. The second press style in the app is the edit
/// that should move this curve into `Motion` — and should take this paragraph with it.
private struct FirstSortCardPress: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? FirstSortMetrics.pressScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

// MARK: - Previews

/// A store already mid-sort over the design's own venue.
@MainActor
private func firstSortPreviewStore() -> AppStore {
    let store = AppStore.preview
    store.beginFirstSort(in: SampleData.sycamore.id)
    return store
}

#Preview("First sort") {
    let store = firstSortPreviewStore()

    return FirstSortView(venueID: SampleData.sycamore.id)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

/// The two 21pt names and the two pills under them at the app's ceiling — the size at which the
/// column stops being the design's fixed one and starts scrolling.
///
/// `.accessibility1` is that ceiling. This preview said `.accessibility3` under this same sentence,
/// which was a claim about a size the app cannot be put into: `SycamoreApp.swift:128` clamps the
/// whole tree at `...DynamicTypeSize.accessibility1`, so three steps above it is a frame no reader
/// will ever see and a layout nobody has to make work. Every other size preview in the repo names
/// `.accessibility1`, and this one now agrees with them.
///
/// The branch it is here to exercise still fires: `isAccessibilitySize` is true from
/// `.accessibility1` up, so the column takes its `ScrollView` at the clamp exactly as it did three
/// sizes past it.
#Preview("First sort — large type") {
    let store = firstSortPreviewStore()

    return FirstSortView(venueID: SampleData.sycamore.id)
        .environment(store)
        .dynamicTypeSize(.accessibility1)
        .frame(width: 402, height: 874)
}

/// The state the design does not draw: nothing left to ask, one action, and the skipped kids
/// named before anybody commits them to the foot of the venue.
#Preview("First sort — settled") {
    let store = AppStore.preview
    let venueID = SampleData.sycamore.id
    store.beginFirstSort(in: venueID)

    // Answered rather than fabricated, so the preview draws a ladder the real loop produced —
    // with every seventh kid set aside, which is what puts a number in the settled sentence.
    // Bounded because a preview that cannot settle would hang the canvas rather than fail it.
    var answers = 0
    while store.firstSort?.isSettled == false, answers < 2_000 {
        answers += 1
        store.answerFirstSort(answers % 7 == 0 ? .skip : .incumbent)
    }

    return FirstSortView(venueID: venueID)
        .environment(store)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("First sort — dark") {
    let store = firstSortPreviewStore()

    return FirstSortView(venueID: SampleData.sycamore.id)
        .environment(store)
        .preferredColorScheme(.dark)
        .frame(width: 402, height: 874)
}
