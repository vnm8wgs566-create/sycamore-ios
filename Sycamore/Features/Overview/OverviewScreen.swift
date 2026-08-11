//
//  OverviewScreen.swift
//  Sycamore
//
//  `4a` drawn, with `8j` surviving as its second branch. Everything this screen needs arrives as a
//  value, so the frames the design draws are sets of arguments rather than views — and so a preview
//  can put the design's own morning on screen without a repository behind it. `OverviewView` is the
//  half that loads.
//
//  ── The order down the page, and why it inverted ─────────────────────────────────────────────
//
//  It is now: **the block that is running, then what needs you, then the pins, then the courts.**
//
//  This file used to state the opposite and argue for it: "a pin is an interruption — 'Court 4 net
//  is loose' is the one thing on this screen that is about to go wrong, and it outranks the block
//  that is merely running." That was a good argument about a card that was merely running. 4a
//  changes what the block's card *is*: it wears the accent border, it names the courts, the kids
//  and the coaches on one line, and it carries a 48pt "Take attendance". It is not a report any
//  more, it is the work — and the pin, which is one clipped line ending in "Open", is a reminder of
//  something already written down. First is for the thing you are here to do.
//
//  What genuinely outranks both is the row between them. "Needs you · 2 · Match play has no coach"
//  is the count of things waiting on a decision, and 4a puts it directly under the block: it is
//  above the pins for the same reason the pins used to be above everything — it is what is going
//  wrong — and below the block because a coach standing on a court at 9:41 is running a session,
//  not triaging one.
//
//  After that the courts, unchanged in order: your own first where you have one, then the rest.
//
//  ── The two frames are two shapes, not one shape twice ───────────────────────────────────────
//
//  This is the difference the screen was missing. `8j`'s caption is "Your court first, the rest
//  quiet", and *quiet* is drawn: your own court is a full card with its roster, and the others are
//  three one-line rows inside a single card — a label, an activity, a face and a caret, no kids.
//  The screen drew a full card for every court in both frames, which made "yours" a border colour
//  rather than a difference in what you are being shown.
//
//  So there are two branches over the same list of courts, and which one runs is `myCourt`:
//
//      admin, no court of their own   ->  `4a`   every court as an `OverviewCourtCard`
//      standing on a court            ->  `8j`   yours as a card, the rest as `CondensedCourtRow`
//
//  **`8j` survives 4a, restyled rather than replaced.** 4a is an admin frame: no "Your court", no
//  accent-bordered court, every court a full card — because an admin has no court and the treatment
//  has moved onto the block. None of that answers a coach's question, which is "which of these is
//  mine", and the design draws no later frame that does. So the coach branch keeps its own card
//  first and the rest condensed, and takes 4a's *label pass* and *card order* with it: the
//  overlines are sentence case (`OverviewTheme.overline`), the court label is sentence case, and
//  the block, the needs-you row and the pins arrive above the courts in 4a's order. The two frames
//  now differ in exactly one thing — whether one of the courts is yours — which is the difference
//  they are for.
//
//  Every full card lists its kids. The design draws exactly one detailed card per frame and this
//  screen once took that literally: it named a single "detailed" court and handed every other card
//  `.none`, so on a twelve-court morning eleven of them said how many kids were there and not
//  one name. Which court a child is on is the question Overview exists to answer. Each card
//  carries its own list, folded to `OverviewTheme.rosterPreview` names with a `+N more` that opens
//  it in place — the design's frames survive as the folded state of a screen that can now also be
//  opened.
//
//  And every one of those names opens the kid. This screen lists more children than any other in
//  the app and was, until now, the only list of them that led nowhere — see `card(for:…)` for the
//  route and `OverviewCourtCard.kidRow` for the row that takes the tap.
//
//  ── The two writes this screen offers ────────────────────────────────────────────────────────
//
//  It had none, and was a read of a morning nobody could act on. It has two now, and they are the
//  two states it was already drawing and could not fix: a court with no coach (`CourtCoachPicker`,
//  behind the design's own "Add a coach") and a day with no blocks (`BlockEditorSheet`, behind the
//  call to action). Deliberately no more than that. Every other gap on this screen already belongs
//  to a screen that owns it — a court's status to the court screen, a block's coaches to the editor
//  on Schedule, a spare place on a court to Groups — and turning each of them into an entrance is
//  how a screen you read becomes a screen you administer. `CourtCapacityBadge` records the closest
//  call: the design draws its "2 spots" with the same dashed `+` that fills the coach slot, and it
//  is a reading all the same.
//

import SwiftUI

struct OverviewScreen: View {

    let store: AppStore
    /// Every court at the venue, in rank order.
    let courts: [CourtCard]
    /// The block the venue is inside, unpacked. Nil draws no card — either nothing has started or
    /// the day is over.
    var now: OverviewNow?
    /// The notes an admin has pinned, newest first. Empty draws no banners.
    var pinnedNotes: [InboxItem] = []
    /// Unresolved `needsAction` rows, newest first — 4a's "Needs you · 2 · Match play has no coach".
    ///
    /// The rows rather than a count and a string, so the screen composes the line and the Inbox
    /// composes nothing: the count is `count` and the clause is the first one's own title. See
    /// `NeedsYouRow` for why neither half is derived here.
    var needsYou: [InboxItem] = []
    /// Whether the day has been read and has no blocks on it at all, which is the one state the
    /// call to action is for. See `OverviewView.todaysBlocks(for:)` — nil there is "nobody has
    /// looked yet" and arrives here as `false`, because an unread day is not an empty one.
    var dayIsUnscheduled: Bool = false
    /// `Sycamore` — the venue this screen is reading, for the header's pill.
    ///
    /// The name alone. This was `venueLine`, "Sycamore · 4 courts", drawn under the title on a day
    /// with no block running; 4a moves the venue into a control at the top of the header and the
    /// court count into the sheet behind it, which is where somebody choosing between venues wants
    /// it. Nil draws no pill — a camp with no venues has nothing to switch between.
    var venueName: String?
    /// `Tuesday, 12 August · day 2 of 5` — the line under the title.
    ///
    /// Composed by `OverviewView` through `OverviewHeader.dateLine(for:on:days:)`, because it takes
    /// the camp's own days and the clock's own date and this screen holds neither.
    var dateLine: String?

    /// Courts the reader has opened past their first few kids.
    ///
    /// Local rather than on the store, and for the reason `GroupsView` gives for the same set:
    /// which cards are open is about this screen at this moment. Nothing else reads it, no write
    /// depends on it, and the default is the *folded* card — so an empty set means what it looks
    /// like it means.
    @State private var expandedCourtIDs: Set<Group.ID> = []

    /// The court whose coach is being picked, and the block being composed.
    ///
    /// Held here rather than on `store.activeSheet`, which is the position `BlockEditorSheet` and
    /// `ScheduleView` already take about the same two sheets: `ActiveSheet` lives in the file every
    /// feature merges, and two callers each owning their own state is simpler than one slot they
    /// take turns in.
    ///
    /// Two `.sheet` modifiers on one view, which `RootView.swift:138` and `:147` already rely on.
    /// They are reached from different controls and each closes before the other can open, so the
    /// pair is never both non-nil — which is the only thing stacked sheets are unhappy about.
    @State private var assigningCoachTo: CourtCoachRequest?
    @State private var addingBlock: BlockEditorDraft?

    /// 4b, and the camp picker its footer leads to.
    ///
    /// Both here rather than as `ActiveSheet` cases, which is the same call the two above make and
    /// for the same reason — see `VenuePickerSheet`'s header. `Bool`s rather than items because
    /// neither carries a payload: 4b is about the camp, and "Your camps" is one screen.
    ///
    /// Four `.sheet` modifiers on one view now. The pairwise rule the two above rely on still
    /// holds for three of them — each is reached from a different control and closes before the
    /// next can open — but this pair is the one that could genuinely overlap, because 4b's footer
    /// leads *out of* 4b: the reader is inside one sheet asking for the next.
    ///
    /// This comment used to claim the pair was safe because "`VenuePickerSheet` calls `onClose`
    /// before it asks for the camp picker". It does not, and it could not have: the footer hands
    /// its rows straight to `onYourCamps` / `onCampSettings` (`VenuePickerSheet.swift:185-207`),
    /// and it was the closures *here* that set the dismissal and the next presentation — in the
    /// same state update. Presenting from a host with a dismissal still in flight is the standard
    /// way the second presentation is silently dropped, and `ProfileView.swift:129/482`, which
    /// reaches the same camp picker from a screen rather than from a sheet, has never had to.
    ///
    /// So the hand-off is chained rather than raced: the exit is *recorded*, the sheet is closed,
    /// and `onDismiss` performs it once the first presentation is actually down. One enum slot for
    /// both exits, which is the shape `BlockDetailView.BlockDetailSheet` uses for the same reason —
    /// two mutually exclusive destinations are one piece of state, not two flags that can disagree.
    @State private var isPickingVenue = false
    @State private var isManagingCamps = false

    /// Where 4b's footer was heading when it closed, or nil for the ordinary dismissal — a tap on
    /// a venue, the grabber, the scrim. Read and cleared by `runAfterVenueSheet`.
    @State private var afterVenueSheet: VenueSheetExit?

    /// A card opening is a change of position, which is precisely what Reduce Motion is about.
    /// The rows still arrive; they simply stop travelling.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Which court is yours, and therefore which frame this pass is drawing. Bound rather than
        // read as computed properties: `otherCourts` was a computed property read twice on the
        // `8j` path — once to ask whether the heading has anything under it and once by the card
        // itself — and each read filtered the venue's whole court list and re-sorted it against
        // the running block. It is also what decides how much of the work below is needed at all.
        let mine = myCourt
        let rest = otherCourts(besides: mine)

        // Once per pass, for every card that will draw one, and read out of the camp exactly once
        // between them. See `TodayCourts.rosters(in:day:venueID:courts:)` and
        // `capacities(in:venueID:)` for why both are built here and handed down rather than asked
        // for inside each card.
        //
        // On `8j` only your own court draws a list — the rest are `CondensedCourtRow`s — so the
        // walk is narrowed to it. On `4a` every card draws one and `nil` takes the venue.
        let camp = store.camp
        let venueID = store.readVenueID
        let rosters = camp.map {
            TodayCourts.rosters(
                in: $0, day: store.today, venueID: venueID, courts: mine.map { [$0.id] }
            )
        } ?? [:]
        let capacities = camp.map { TodayCourts.capacities(in: $0, venueID: venueID) } ?? [:]

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusBarMock()

                // The venue up top, as a control. What used to sit under the title — the running
                // block's "Skills rotation · until 10:30" — is the card at the head of the scroll
                // now, with a button on it; the header carries the one fact nothing else on the
                // screen does, which is where the camp has got to in its own run.
                OverviewHeader(
                    venueName: venueName,
                    isVenueSheetOpen: isPickingVenue,
                    dateLine: dateLine,
                    initials: store.avatarInitials,
                    onVenueTap: { isPickingVenue = true },
                    onAvatarTap: { store.pushedScreen = .campHome }
                )
            }
            .background(Theme.surface)

            Hairline(color: Theme.hairline)

            ScrollView {
                LazyVStack(spacing: OverviewTheme.cardGap) {
                    // First, because it is the work rather than a report of it — see the file
                    // header for the argument this replaced.
                    theBlock(camp)

                    needsYouRow

                    // Under the two above and above the courts. A pin is a reminder of something
                    // already written down, and it ends in a way through to the whole of it.
                    ForEach(pinnedNotes) { note in
                        PinnedNoteBanner(text: text(of: note)) {
                            store.selectedTab = .inbox
                        }
                    }

                    if let mine {
                        // `8j`. Yours in full, everything else condensed into one card of rows.
                        card(
                            for: mine, isMine: true,
                            from: rosters, capacities: capacities
                        )
                        // Only when there are some. A venue with one court, and it is yours, used
                        // to draw "OTHER COURTS" over nothing at all — a heading VoiceOver
                        // announces as a landmark leading to an empty region.
                        if !rest.isEmpty {
                            otherCourtsHeading
                            otherCourtsCard(rest)
                        }
                    } else {
                        // `4a`. No court is yours, so there is no "rest" to keep quiet — every
                        // court is one an admin is responsible for and gets the full card.
                        ForEach(rest) { court in
                            card(
                                for: court, isMine: false,
                                from: rosters, capacities: capacities
                            )
                        }
                    }

                    if courts.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.gutterWide)
                // The floating tab bar reserves no layout space of its own.
                .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `surfaceWarm`, not `grouped`. Section 8 draws every screen on `#F8F9F8`, a shade
        // warmer than the `#F6F7F9` this app has been grouping on since before the redesign.
        .background(Theme.surfaceWarm)
        // One tick as a card opens or closes, which is what `BlockNotesCard` gives the only
        // other fold in the app. On the set rather than on a card, because the cards are drawn
        // in a loop and there is nothing per-card to hang it off.
        .sensoryFeedback(.selection, trigger: expandedCourtIDs)
        .sheet(item: $assigningCoachTo) { request in
            CourtCoachPicker(
                store: store, courtID: request.id, onClose: { assigningCoachTo = nil }
            )
        }
        .sheet(item: $addingBlock) { draft in
            // The composer Schedule uses, not a second one. A block written from here lands in
            // `store.scheduleBlocks`, which is the list this screen reads — so the call to action
            // is replaced by the card it was asking for, without a tab switch or a re-read.
            BlockEditorSheet(draft: draft, onClose: { addingBlock = nil })
                .environment(store)
        }
        .sheet(isPresented: $isPickingVenue, onDismiss: runAfterVenueSheet) {
            // A sheet does not inherit this view's `store`, which arrives as an init argument
            // rather than through the environment, so 4b is handed it.
            VenuePickerSheet(
                store: store,
                onClose: { isPickingVenue = false },
                // Nil locks the row. `8t` is admin-only behind RLS, and an entrance that opened a
                // screen the reader cannot write to would be worse than one that says so.
                //
                // Both exits record where they are going and then close, and neither opens
                // anything from in here — see `afterVenueSheet` above for why the obvious version
                // of these two closures was the bug.
                onCampSettings: store.isAdmin
                    ? {
                        afterVenueSheet = .campSettings
                        isPickingVenue = false
                    }
                    : nil,
                onYourCamps: {
                    afterVenueSheet = .yourCamps
                    isPickingVenue = false
                }
            )
        }
        .sheet(isPresented: $isManagingCamps) {
            CampPickerView(isManagingCamps: true)
                .environment(store)
                .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
        }
    }

    // MARK: What is happening now

    /// The running block, or the invitation to write one.
    ///
    /// The two are mutually exclusive by construction: a day with no blocks on it can have none
    /// running. They are drawn as one `if`/`else if` all the same, so the middle case — a scheduled
    /// day between blocks, or after its last — draws neither rather than being told its day is
    /// empty.
    ///
    /// The call to action is gated on there being courts. A venue with none is a more fundamental
    /// hole and has its own answer at the foot of the screen; offering to write a block for a venue
    /// with nowhere to run it would be two empty states arguing about which problem to fix first.
    ///
    /// Takes the camp the caller already resolved rather than reading `store.camp` a second time —
    /// the meta line walks the venue's kids, and `body` has that value in hand.
    @ViewBuilder
    private func theBlock(_ camp: Camp?) -> some View {
        if let now {
            RunningBlockCard(
                now: now,
                metaLine: now.metaLine(in: camp),
                onTakeAttendance: { takeAttendance(for: now, in: camp) }
            )
        } else if dayIsUnscheduled, !courts.isEmpty {
            OverviewEmptyDayHero(day: store.today, onAdd: addBlock)
        }
    }

    /// `Needs you · 2 · Match play has no coach`.
    ///
    /// Nothing waiting draws nothing at all, which is the call `InboxList.swift:22-24` makes about
    /// the same rows: "an empty 'Needs you · 0' heading is the sort of thing that makes a person
    /// check twice".
    @ViewBuilder
    private var needsYouRow: some View {
        if let first = needsYou.first {
            NeedsYouRow(count: needsYou.count, headline: first.title) {
                store.selectedTab = .inbox
            }
        }
    }

    // MARK: Which court is whose

    /// The court the person reading this is standing on. Nil for an admin, which is what turns
    /// `8j` back into `8i`.
    ///
    /// `AppStore.myCourtID` rather than the two-way fallback spelled out here, which is where it
    /// used to live. `OverviewView` needs the same court to resolve `now`, and a screen whose card
    /// and whose "Your court" heading each worked out whose court it was would be one edit away
    /// from drawing a coach's own court above a block that is not on it.
    private var myCourtID: Group.ID? { store.myCourtID }

    private var myCourt: CourtCard? {
        guard let myCourtID else { return nil }
        return courts.first { $0.id == myCourtID }
    }

    /// Everything but your own court, with the running block's courts floated to the front.
    ///
    /// Your court stays first regardless. It is first because it is yours, which is a fact about
    /// the reader; the block's ordering is a fact about the morning, and the two are not in
    /// competition — a coach standing on Court 3 during a warm-up on Courts 1–2 still wants their
    /// own card at the top.
    ///
    /// `preferring` is a sort and not a filter; see `OverviewNow`. On the blocks the app writes
    /// today `courtIDs` is always empty and this is the identity, which is exactly what it should
    /// be until the editor that populates the column lands.
    ///
    /// Takes `mine` rather than reading `myCourt` itself, so `body` can resolve the pair once and
    /// hand both down — the two questions are one decision, and asking them separately is what let
    /// this get evaluated twice a pass.
    private func otherCourts(besides mine: CourtCard?) -> [CourtCard] {
        let rest = mine.map { mine in courts.filter { $0.id != mine.id } } ?? courts
        return now?.preferring(rest) ?? rest
    }

    // MARK: Pieces

    /// One card, with its court's list already cut to what the card should draw.
    private func card(
        for court: CourtCard,
        isMine: Bool,
        from rosters: [Group.ID: CourtRoster],
        capacities: [Group.ID: Int]
    ) -> some View {
        let isExpanded = expandedCourtIDs.contains(court.id)
        let roster = TodayCourts.roster(
            for: court,
            from: rosters,
            preview: OverviewTheme.rosterPreview,
            isExpanded: isExpanded
        )

        return OverviewCourtCard(
            card: court,
            isMine: isMine,
            // Nil on a closed court and on one the camp graph has no group for, which draws no
            // reading at all rather than "0 of 0". `CourtCapacity.reading(for:capacity:)` owns
            // that rule so the card does not have to restate it.
            capacity: CourtCapacity.reading(for: court, capacity: capacities[court.id]),
            roster: roster,
            isRosterExpanded: isExpanded,
            onOpenCoach: coachAction(for: court),
            // A court small enough to draw whole gets no control. `isFoldable` asks
            // `GroupsRules.visibleCount` the same question the fold answers, so the row and the
            // list can never disagree about whether there is anything behind it.
            onToggleRoster: roster.isFoldable(to: OverviewTheme.rosterPreview)
                ? { toggle(court.id) }
                : nil,
            // The header caret's destination. Nil on your own court, which draws no caret — you
            // are already standing on it. The card decides whether to draw the glyph; this
            // decides where it goes, and the two are the same question asked once each.
            onOpenCourt: isMine ? nil : { store.pushedScreen = .court(court.id) },
            // And the name tapped, which is `8q`. This screen lists more children than any other
            // in the app and was the only one of them that led nowhere; the court screen, both of
            // Groups' lists and Rank all open a kid from a row, and this now does too.
            //
            // Through the root's single `pushedScreen` slot, which **replaces rather than
            // stacks** — `CourtScreen.openKid` sets out at length why that is the slot's whole
            // design and what goes wrong with the alternative. The consequence here is the same
            // one it records: the kid's back caret returns to Overview, which is where the reader
            // was, and is the behaviour every other route into that screen already has.
            //
            // Both frames, not one. On `8i` every card carries a full roster, so this is a route
            // out of any of a dozen cards; on `8j` only "Your court" draws rows at all and the
            // rest are `CondensedCourtRow`s with no kids on them by design, so it is a route out
            // of exactly one. Handed to every card either way, because which cards have rows is a
            // question the roster walk above has already answered.
            onOpenPlayer: { store.pushedScreen = .player($0) }
        )
    }

    private var otherCourtsHeading: some View {
        Text("Other courts")
            .typeStyle(OverviewTheme.overline, color: Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.tight)
            .padding(.horizontal, OverviewTheme.overlineInset)
            .accessibilityAddTraits(.isHeader)
    }

    /// `8j`'s second half: every court that is not yours, one line each, in one card.
    ///
    /// A `Card` of rows rather than a card each, which is what the frame draws and what makes the
    /// section read as "the rest" instead of as four more things competing with yours. `Card`
    /// divides its children by default, so the `border-top:1px solid #F2F3F6` the design puts
    /// between the rows arrives for free and never above the first.
    ///
    /// No roster on these, deliberately, and it is the one place this screen *stops* showing kids.
    /// The argument for every card listing its own is that a coach cannot otherwise find a child
    /// without leaving Overview; on your own screen that reasoning points the other way, because
    /// the card that has your kids on it is right above and the caret on each row opens the court
    /// whose kids you are after.
    private func otherCourtsCard(_ rest: [CourtCard]) -> some View {
        Card(radius: OverviewTheme.cardRadius) {
            ForEach(rest) { court in
                CondensedCourtRow(card: court) { store.pushedScreen = .court(court.id) }
            }
        }
    }

    /// What the coach line does, which is two different things.
    ///
    /// A court with a coach opens their staff card. A court with **nobody** opens the picker that
    /// puts somebody on it — `CourtCoachLine` draws itself as a dashed `+` and the design's own
    /// "Add a coach" when it is handed an action with no name, so this closure is the whole of the
    /// difference between a line that reports a hole and one that fills it.
    ///
    /// A card carrying a coach id the camp cannot resolve still gets nothing, which is the rule
    /// that was already here and it survives for a sharper reason than before: a stale name has
    /// nothing to open, *and* the court is not free, so offering to fill it would be offering to
    /// take it off whoever the read thinks is on it.
    ///
    /// **The court's standing coach wins over the block's, deliberately.** `OverviewNow` reads
    /// `block.coachIDs` and draws it a few cards up; this line reads `coaches.group_id`, and when
    /// they disagree the line keeps saying what the court says. They answer different questions —
    /// who has this court all day, against who is running this one block, which can be two people
    /// on a block that spans three courts — and the deciding argument is that this line is a
    /// control over exactly one of them. Let the block's coaches win here and the `+` would write
    /// `coaches.group_id`, the line would go on reading `schedule_block_coaches`, and assigning
    /// somebody would appear to do nothing at all.
    private func coachAction(for court: CourtCard) -> (() -> Void)? {
        if let coachID = court.coachID {
            guard store.staffMember(coachID) != nil else { return nil }
            return { store.present(.staff(coachID)) }
        }
        return { assigningCoachTo = CourtCoachRequest(id: court.id) }
    }

    /// The note's own words, not the line about who pinned it.
    private func text(of item: InboxItem) -> String { item.detail ?? item.title }

    // MARK: Intents

    private func toggle(_ courtID: Group.ID) {
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) {
            expandedCourtIDs.toggle(courtID)
        }
    }

    /// 4b's footer, performed once 4b is off the screen.
    ///
    /// Nil is the ordinary case and does nothing, which is what makes this safe to hang off
    /// `onDismiss` at all: the sheet goes away far more often for a reason that is not an exit —
    /// a venue tapped, the grabber pulled, the scrim — and every one of those lands here too.
    ///
    /// Cleared on the way past, so a reader who opens 4b again and swipes it down does not arrive
    /// somewhere they asked for once, a minute ago.
    private func runAfterVenueSheet() {
        let exit = afterVenueSheet
        afterVenueSheet = nil
        switch exit {
        case .campSettings: store.push(.campSettings)
        case .yourCamps: isManagingCamps = true
        case nil: break
        }
    }

    /// Opens the composer on today, at this venue.
    ///
    /// The same act `ScheduleView.addBlock` performs and by the same route — nothing is written
    /// until somebody has said what the block is called. `store.today` rather than a day this
    /// screen chose: Overview has no day picker and is only ever about the day you are standing in.
    private func addBlock() {
        guard let venueID = store.readVenueID else { return }
        addingBlock = BlockEditorDraft(creatingIn: venueID, day: store.today)
    }

    /// `8m`, for the courts the running block covers — 4a's call to action.
    ///
    /// The same route and the same rule as `BlockDetailView.openAttendance`
    /// (`BlockDetailView.swift:272-299`): the block's own courts where it names any, the venue's
    /// where it does not, because a lunch happens on no court in particular and the venue is who is
    /// there. Written once on the value (`OverviewNow.courtIDs(in:)`) so the count on the card and
    /// the roll behind the button cannot come to be about different children.
    ///
    /// Through `pushedScreen`, which **replaces rather than stacks** — the slot's whole design, and
    /// the consequence here is the one every other route into `8m` already has: the ✕ comes back to
    /// Overview, which is where the reader was.
    private func takeAttendance(for now: OverviewNow, in camp: Camp?) {
        guard let camp else { return }
        store.pushedScreen = .attendance(now.courtIDs(in: camp), now.block)
    }

    // MARK: Empty state

    /// Not in the design — every frame there is drawn on a camp in full swing. A venue with no
    /// courts is a real state all the same, and the answer to it is the screen that fixes it.
    ///
    /// The system's own empty state rather than a hand-set one, and unlike the no-blocks card above
    /// it that is the right shape here: a court is shaped in camp settings, on another screen and
    /// behind an admin, so there is no action to put on this card. `ScheduleEmptyDayHero.swift:8-11`
    /// draws the same line between the two kinds of nothing.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No courts yet", systemImage: "square.split.2x2")
        } description: {
            Text("Shape the venue into courts in camp settings and they show up here.")
        }
        .padding(.top, Spacing.section)
    }
}

// MARK: - Where 4b's footer leads

/// The two screens reachable *through* the venue sheet, held as one slot rather than as two flags
/// set from inside a sheet that is on its way out. See `OverviewScreen.afterVenueSheet`.
///
/// An enum rather than a `Bool` each, for `BlockDetailSheet`'s reason: they are mutually exclusive
/// by construction — one footer, two rows, one tap — and two flags would be a state the type
/// permits and the screen does not.
private enum VenueSheetExit {
    case campSettings
    case yourCamps
}

// MARK: - Previews

#Preview("4a — Overview · admin") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        now: OverviewFixtures.now,
        pinnedNotes: [OverviewFixtures.pinnedNote],
        needsYou: OverviewFixtures.needsYou,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
}

#Preview("8j — Overview · on a court") {
    OverviewScreen(
        store: OverviewFixtures.coachStore,
        courts: OverviewFixtures.courts,
        now: OverviewFixtures.now,
        pinnedNotes: [OverviewFixtures.pinnedNote],
        needsYou: OverviewFixtures.needsYou,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
}

/// More than one pin, which is the state the screen used to drop on the floor.
#Preview("Overview — two pins") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        now: OverviewFixtures.now,
        pinnedNotes: OverviewFixtures.pinnedNotes,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
}

/// The three cards above the courts, all absent: nothing running, nothing waiting, nothing pinned.
/// The state 4a never draws and the screen opens in on a quiet afternoon.
#Preview("Overview — nothing on") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
}

/// The call to action: courts in full swing, and nobody has written the day down.
#Preview("Overview — nothing scheduled") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        dayIsUnscheduled: true,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
}

#Preview("Overview — no courts") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: [],
        dayIsUnscheduled: true,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
}

/// The two states the design does not draw but the app has to survive: the reader's largest
/// type size, and the dark scheme. Every fixed height on these screens is a `minHeight` or a
/// `@ScaledMetric` so that the first one only ever makes the cards taller.
#Preview("8j — accessibility1") {
    OverviewScreen(
        store: OverviewFixtures.coachStore,
        courts: OverviewFixtures.courts,
        now: OverviewFixtures.now,
        pinnedNotes: [OverviewFixtures.pinnedNote],
        needsYou: OverviewFixtures.needsYou,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("4a — dark") {
    OverviewScreen(
        store: OverviewFixtures.adminStore,
        courts: OverviewFixtures.courts,
        now: OverviewFixtures.now,
        pinnedNotes: [OverviewFixtures.pinnedNote],
        needsYou: OverviewFixtures.needsYou,
        venueName: OverviewFixtures.venueName,
        dateLine: OverviewFixtures.dateLine
    )
    .showsMockStatusBar()
    .preferredColorScheme(.dark)
}
