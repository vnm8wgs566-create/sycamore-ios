//
//  BlockDetailView.swift
//  Sycamore
//
//  `5d` — one block opened. "Which court has who, and what still needs somebody."
//
//  Presented as a cover rather than a sheet, which is the opposite of what `RootView` does with
//  Profile and Setup, and for the reason stated there: those four screens were tabs and none of
//  them draws a back control, so a cover would be a screen you cannot leave. This one draws its
//  own. It also draws a bottom call to action, which a sheet's grabber would sit under.
//
//  ── The screen turned itself inside out ──────────────────────────────────────────────────────
//
//  It used to be three cards about a block: "Your court", read from where the *reader* stands;
//  "Logistics", one list of names for the whole block; and the notes. Its own header argued that
//  the court card came out of the camp graph because "which court you are standing on and how
//  many kids are in front of you is the camp's answer, not the schedule's". That was right about
//  occupancy and it was answering the wrong question. A match play runs on three courts with a
//  different coach on each, and neither of the first two cards could say whether Court 2 was
//  covered — one showed a single court chosen by who was holding the phone, the other showed one
//  undifferentiated list of everybody on the block.
//
//  `5d` (`design/rebuild/section-t5.html:179-226`) draws a card per court instead, each with its
//  own coach row and its own amber gap, and routes both of that row's states — `Reassign` and
//  `Add a coach` — into `BlockCourtStaffingSheet`. `ScheduleBlock.staffing` is what makes it
//  sayable; before that column existed the design could not have been built.
//
//  ── Two things `5d` drops and this screen keeps ──────────────────────────────────────────────
//
//  **The clash line.** This is the screen somebody opens *by tapping the amber line* on `8k`, and
//  a cover that then said nothing about the clash would be the one place the flag leads to a dead
//  end. `5d` draws no such line; that is the frame being a frame rather than a decision, and the
//  argument this file has carried since the flag was built still stands.
//
//  **"Take attendance".** The register for this block's courts is the thing somebody standing on
//  one of them opens this screen to reach. `8k` and `8i` reach `8m` too, but neither of them
//  reaches it *scoped to this block's courts*, which is the whole value of the button.
//
//  What `5d` does take away is the status dot line and the `⋯` menu. The dot said "On now · 41
//  min left" over a screen that now says which courts are short a coach, which is the more urgent
//  of the two; the menu became a single control with a single destination, because everything else
//  it held lives somewhere better — "Delete block" inside the editor, and "Mark done" at the foot
//  beside the other thing you do to a block you are finished with.
//

import SwiftUI

struct BlockDetailView: View {

    @Environment(AppStore.self) private var store

    let block: ScheduleBlock

    // An `isCurrent: Bool` used to sit here, and nothing on `5d` ever read it: it fed the status
    // dot line — "On now · 41 min left" — which the redraw removed. Its own comment recorded that
    // it stayed only because `ScheduleView` passed it and that file was not this unit's to edit,
    // and that it was "the argument to delete the day the two land together". They landed
    // together. The caller no longer computes it either, which is the half worth having: working
    // it out meant `ScheduleBlock.running(in:at:)` over the whole day inside `ScheduleView.body`,
    // to answer a question the cover had no drawing for.

    /// The block this one clashes with, or nil — handed down rather than recomputed so this cover
    /// and the card behind it can never name different blocks as current, and it matters more
    /// here: this is the screen somebody opens *by tapping the amber line*. See `ScheduleConflicts`
    /// for where the answer is worked out.
    var conflict: ScheduleBlock?
    let onClose: () -> Void

    /// Both sheets this cover presents, in one slot.
    ///
    /// Presented from here rather than through `store.activeSheet`: this screen is itself a cover
    /// and the root that owns `activeSheet` is underneath it, so asking it to present would open
    /// the editor *behind* this screen. `PlayerScreen` reaches `8n` the same way and for the same
    /// reason.
    ///
    /// One `@State` and one `.sheet(item:)` for the two of them rather than two of each. Two
    /// `.sheet` modifiers on one view is a documented way to end up with a sheet that will not
    /// open, and the two are mutually exclusive anyway — you are either editing this block or
    /// staffing one of its courts. `ScheduleView` holds its own, independent, editor state; that
    /// is two callers with two pieces of state, which is a different thing from one view stacking
    /// two presentations.
    @State private var sheet: BlockDetailSheet?

    @ScaledMetric(relativeTo: .headline) private var ctaHeight = ScheduleMetrics.ctaHeight
    @ScaledMetric(relativeTo: .body) private var headerDisc = BlockDetailView.headerDisc

    var body: some View {
        // Resolved once in `body` and handed to both readers. `BlockCourtPicker.courts(on:in:)` is
        // a walk of `camp.groups(in:)` — a filter and a sort — and it was called twice in one pass:
        // the header counts the courts and the list below draws a card per court. Two callers, two
        // walks, one answer. `BlockEditorSheet.body` and `BlockCourtStaffingSheet.body` already
        // hoist their own pools out of exactly this shape and say why.
        let courts = BlockCourtPicker.courts(on: block, in: store.camp)

        return VStack(spacing: 0) {
            header(courts)
            Hairline(color: Theme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: ScheduleMetrics.blockGap) {
                    description
                    courtCards(courts)
                    notesRow
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, ScheduleMetrics.listTop)
                .padding(.bottom, footerClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .overlay(alignment: .bottom) { footer }
        // A sheet, not a cover: a cover cannot be presented over a cover, and this screen is one.
        // See `BlockEditorSheet`'s header for the rest of the reasoning.
        //
        // `.environment(store)` on both, because a sheet presented from inside a cover is not
        // somewhere the root's environment can be relied on to reach — the same re-injection
        // `BlockCourtStaffingSheet`'s header asks of every one of its callers.
        .sheet(item: $sheet) { which in
            switch which {
            case .editor(let draft):
                BlockEditorSheet(draft: draft, onClose: dismissSheet)
                    .environment(store)
            case .staffing(let courtID):
                BlockCourtStaffingSheet(block: block, courtID: courtID, onDismiss: dismissSheet)
                    .environment(store)
            }
        }
        // A cover hides the banner `MainTabView` floats, so it carries the store's own — not a
        // private one. `AppStore.perform` owns `errorMessage`; this screen just has to be
        // somewhere it can be seen from.
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
    }

    // MARK: Header

    private func header(_ courts: [CourtGroup]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            HStack(spacing: ScheduleMetrics.blockGap) {
                // A filled disc, where this screen used to draw a bare caret grown to 44. `5d`
                // puts the back control and the `⋯` in matching 36pt `fill` discs
                // (`design/rebuild/section-t5.html:185-189`), which is the shape every other
                // header in the app already uses for exactly these two jobs.
                CircleIconButton(
                    systemName: "chevron.left", size: headerDisc, tone: .filled, action: onClose
                )
                .accessibilityLabel("Back to the schedule")

                Text(block.day.fullName)
                    .typeStyle(ScheduleType.blockTime, color: Theme.inkMuted)

                Spacer(minLength: 0)

                // One destination, so a control and not a menu. The menu held three items and two
                // of them have moved: "Delete block" lives at the foot of the editor, where
                // somebody who has just looked at what a block contains decides they do not want
                // it, and "Mark done" is at the foot of this screen. What was left was a `⋯` whose
                // only entry was "Edit block", which is a tap to reach a tap.
                CircleIconButton(
                    systemName: "ellipsis", size: headerDisc, tone: .filled, action: edit
                )
                .accessibilityLabel("Edit this block")
            }

            Text(block.title)
                .typeStyle(ScheduleType.blockHeading, color: Theme.ink)
                .padding(.top, Self.titleGap)

            Text(subtitle(courts))
                .typeStyle(ScheduleType.blockDetail, color: Theme.inkMuted)
                .padding(.top, ScheduleMetrics.headerSubtitleGap)

            clashLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.header)
        .padding(.top, ScheduleMetrics.headerTop)
        .padding(.bottom, ScheduleMetrics.headerBottom)
        .background(Theme.surface)
    }

    /// `10:45 – 12:15 · Sycamore · 3 courts`.
    ///
    /// Three facts about where and when, assembled here rather than taken from `block.detail`.
    /// This line used to be `timeLabel · detail`, and the free text has moved down to its own
    /// plate — which is the change worth naming, because the two say different kinds of thing. The
    /// hours, the venue and the court count are facts the app holds in columns and can act on; the
    /// description is prose somebody typed, and a header that concatenated the two put "Ladder
    /// matches to 11 — winners move up a court" on the same line as a time.
    ///
    /// Segments are dropped whole rather than printed empty — never a trailing middot, which is
    /// the rule `CoachAvailability.subtitle` states for the line under a coach's name. A block
    /// that names no courts prints two segments, and that is the honest reading: a lunch runs on
    /// none of them.
    ///
    /// The courts are handed in rather than resolved here — see `body`, which is what counts them
    /// and what draws them.
    private func subtitle(_ courts: [CourtGroup]) -> String {
        let parts: [String?] = [
            block.shortTimeLabel,
            store.venue(block.venueID)?.name,
            courtCount(courts)
        ]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// `3 courts`, `1 lane`, `6 fields` — the third segment, or nothing when the block names no
    /// courts.
    ///
    /// **The noun follows the sport** (`Sport.groupNoun`, `Models.swift:440-441`), where this line
    /// hard-coded "court". Every other composed fact in the app already derives it —
    /// `ScheduleBlock.courtSummary(in:)` writes "Lanes 1–3", `Camp.venueSummary(for:)` writes "6
    /// lanes · 50 kids", `CreateCampView.courtNoun` lower-cases it the same way, and `Camp.reindex`
    /// is what makes a court's own label read `Lane 3` in the first place. So a swim camp's header
    /// read "3 courts" directly above three cards labelled `Lane 1`, `Lane 2`, `Lane 3`.
    ///
    /// Lower-cased mid-line, which is `Camp.venueSummary(for:)`'s call and for its reason: the noun
    /// is a word in a sentence here, not the head of a label.
    ///
    /// Nil rather than "0 courts" on a block that names none, so the segment drops whole. Nil too
    /// while the camp has not loaded — `BlockCourtPicker.courts(on:in:)` answers empty without one
    /// anyway, so the two absences are the same absence.
    private func courtCount(_ courts: [CourtGroup]) -> String? {
        guard !courts.isEmpty, let sport = store.camp?.sport else { return nil }
        let noun = sport.groupNoun.lowercased()
        return "\(courts.count) \(noun)\(courts.count == 1 ? "" : "s")"
    }

    /// The same amber sentence the card on `8k` carries, under the same times it is about.
    ///
    /// `ScheduleBlock.clashLine`, so the screen that opens off the flag says the words the flag
    /// said. It is a statement and not a control: the way out of a clash is the two time menus in
    /// the editor, which the `⋯` above already reaches, and a second route to them here would be
    /// a button that only appears when something is wrong.
    @ViewBuilder
    private var clashLine: some View {
        if let conflict {
            Text(conflict.clashLine)
                .typeStyle(ScheduleType.blockDetail, color: Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, ScheduleMetrics.courtMetaGap)
        }
    }

    // MARK: What the block is

    /// The description, on the tinted plate `5d` gives it
    /// (`design/rebuild/section-t5.html:195`).
    ///
    /// `accentSurface` rather than white, and 13/1.5 rather than the header's 13.5, because this
    /// is the one run of prose on a screen of facts — it is somebody's sentence about how the
    /// block is meant to go, and the plate is what stops it reading as another derived line.
    ///
    /// Hidden when there is nothing in it. An empty plate is a card that failed to load.
    ///
    /// `Card` rather than the shape drawn by hand, which is what stood here: a
    /// `RoundedRectangle(cornerRadius:style:.continuous)`, a `.background(_:in:)` and an
    /// `.overlay { shape.strokeBorder(…) }` — which is `Card.body` verbatim, restated with a
    /// different set of colours. `isDivided: false` because there is one child and nothing to rule
    /// between. `BlockCourtCard` and `BlockCourtStaffingSheet.emptyCard`, both a folder away, are
    /// already the same tinted-plate-with-one-thing-in-it written the short way.
    @ViewBuilder
    private var description: some View {
        if let detail = block.detail, !detail.isEmpty {
            Card(
                radius: Radius.tile,
                background: Theme.accentSurface,
                borderColor: Theme.accentSurfaceBorder,
                isDivided: false
            ) {
                Text(detail)
                    .typeStyle(.sheetSubtitle.lineHeight(1.5), color: Theme.inkWarm)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.row)
                    .padding(.horizontal, Self.plateInset)
            }
        }
    }

    // MARK: The courts

    /// One card per court the block runs on, in the venue's order — and one card for the block
    /// itself when it runs on none.
    ///
    /// `BlockCourtPicker.courts(on:in:)` sorts by where each court sits rather than by where the
    /// block happened to list it, which is the reading its own doc argues for: a list of courts is
    /// a set, and the order anybody reads it in is the venue's.
    ///
    /// The no-courts arm is not a fallback so much as the honest answer for a `.regular` block. A
    /// lunch names no courts because it happens on none of them in particular, and a screen drawn
    /// strictly per court would say nothing at all about who is running it — which is the fact
    /// `ScheduleBlockStatus.needsCoach` puts in amber on `8k` for exactly those blocks too.
    @ViewBuilder
    private func courtCards(_ courts: [CourtGroup]) -> some View {
        if courts.isEmpty {
            BlockCourtCard(
                court: nil,
                coaches: BlockCourtCard.coaches(on: block, court: nil, in: store.camp),
                onStaff: staffAction(nil)
            )
        } else {
            ForEach(courts) { court in
                BlockCourtCard(
                    court: court,
                    coaches: BlockCourtCard.coaches(on: block, court: court.id, in: store.camp),
                    onStaff: staffAction(court.id)
                )
            }
        }
    }

    /// Opens `4d` on one court. Nil for somebody who cannot write the camp's schedule, in which
    /// case the card states the gap and offers nothing rather than drawing a control the database
    /// would refuse — `updateScheduleBlock` goes through `adminWrite`, and `ProfileView` locks its
    /// admin rows the same way.
    ///
    /// Spelled out rather than written as `store.isAdmin ? … : nil` at the call site: a ternary
    /// between a closure and `nil` gives the type checker nothing to anchor the optional on.
    private func staffAction(_ courtID: Group.ID?) -> (() -> Void)? {
        guard store.isAdmin else { return nil }
        return { sheet = .staffing(courtID) }
    }

    // MARK: Notes

    /// Hidden on a block nobody has written anything on — unless you are the person who would
    /// write the first one.
    ///
    /// The old condition was `!block.notes.isEmpty`, and its reason was sound: "0 notes on this
    /// block" is a row that exists only to say there is nothing in it. That reason survives for a
    /// coach, who can only read. For an admin the card is now also the *composer*, so hiding it
    /// hides the only way to add a note to a block that has none.
    ///
    /// `5d` draws this as a flat plate — a glyph, the sentence "Notes for the day live on the
    /// block, not in the editor." and an accent `Add`. That is `BlockNotesCard`'s collapsed row
    /// with a fixed sentence in place of the count, and `BlockNotesCard.swift` is not this unit's
    /// file to redraw. The card is kept whole rather than half-copied here: it owns the composer,
    /// the per-note `⋯` and the admin gate on both, and a second collapsed row in front of it
    /// would be a second thing to keep in step with all three.
    @ViewBuilder
    private var notesRow: some View {
        if !block.notes.isEmpty || store.isAdmin {
            BlockNotesCard(block: block)
        }
    }

    // MARK: The foot

    /// "Take attendance", and under it the one thing the `⋯` menu used to hold that had nowhere
    /// else to go.
    ///
    /// ── Why "Mark done" landed here ──────────────────────────────────────────────────────────
    ///
    /// `5d` turns the `⋯` into a direct route to the editor, and the editor has no status control
    /// — so the action was about to be deleted by a redraw that never mentioned it. The foot is
    /// where it belongs rather than where it fits: these are the two things somebody does to a
    /// block they are standing in front of, in the order they do them. Taking the register is the
    /// loud one and keeps the filled button; marking the block finished is the quiet one and is a
    /// word, drawn where this app already draws the line under a call to action.
    ///
    /// It names its object — "Mark this block done", not "Mark done" — because a bare verb under
    /// a full-width button reads as a second thing you could do to the *register*.
    ///
    /// Hidden once the block is done, as the menu entry was: an action that has already happened
    /// is not an action. Hidden for a coach for the same reason the staffing controls are, and it
    /// is the sharper case of the two — this one writes immediately, with nothing in between to
    /// refuse it.
    private var footer: some View {
        VStack(spacing: ScheduleMetrics.rowGap) {
            PrimaryButton(
                "Take attendance",
                height: ctaHeight,
                font: ScheduleType.cta,
                action: openAttendance
            )
            .shadow(ScheduleShadows.cta)

            if canMarkDone {
                Button(action: markDone) {
                    Text("Mark this block done")
                        .typeStyle(ScheduleType.inlineAction, color: Theme.inkSecondary)
                        // The word is about 13pt tall; only the frame around it reaches 44.
                        .frame(minHeight: HitTarget.minimum)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, ScheduleMetrics.ctaBottom)
    }

    private var canMarkDone: Bool { store.isAdmin && block.status != .done }

    /// How far the last card has to clear the floating foot.
    ///
    /// `tabBarClearance` was measured against one 52pt button and its 20pt gutter. The second row
    /// is a 44pt hit target and a 10pt gap, so it is added rather than absorbed — a bottom note on
    /// the last court card is exactly the thing that would end up under "Mark this block done".
    private var footerClearance: CGFloat {
        canMarkDone ? Spacing.tabBarClearance + HitTarget.minimum : Spacing.tabBarClearance
    }

    // MARK: Actions

    /// `8m`, for every court this block covers.
    ///
    /// The block's own courts when it has any, and the whole venue when it has not.
    ///
    /// This used to be the venue unconditionally, and the reason given was that the only other
    /// candidate was `ScheduleBlock.detail` — one free-text line reading "Courts 1–3 · 22 players"
    /// that the design composes differently on every row, "so the venue's own groups are the only
    /// answer that cannot drift from it". That reasoning was sound and is now spent:
    /// `ScheduleBlock.courtIDs` is a column set, not a sentence, so a block that says it runs on
    /// courts 1–3 can be taken at its word — and taking attendance for six courts when three of
    /// them belong to a different block is the register nobody can fill in.
    ///
    /// The fallback is not a fallback so much as the honest answer for a `.regular` block: a lunch
    /// names no courts because it happens on none of them in particular, and the venue is who is
    /// there. A `.assigned` block with nothing ticked lands here too, which is right — it has told
    /// us nothing, so we are back to what we knew before it did.
    ///
    /// `5d` closes on the way. Both screens are covers, and a cover cannot be presented over a
    /// cover — but more than that, `8m` is where this block's work now happens, and stacking the
    /// two would leave a "Take attendance" button live underneath the screen it opened.
    private func openAttendance() {
        var courts = BlockCourtPicker.courts(on: block, in: store.camp).map(\.id)
        if courts.isEmpty {
            courts = store.camp?.groups(in: block.venueID).map(\.id) ?? []
        }
        onClose()
        store.pushedScreen = .attendance(courts, block)
    }

    /// Opens the editor on this block — `5a`, the only place a block's shape, its times and its
    /// deletion are changed.
    private func edit() {
        sheet = .editor(BlockEditorDraft(editing: block))
    }

    private func markDone() {
        var updated = block
        updated.status = .done
        Task { await store.updateScheduleBlock(updated) }
    }

    private func dismissSheet() {
        sheet = nil
    }
}

// MARK: - What this cover can put in front of itself

/// The editor and the coach picker, in one slot.
///
/// An enum rather than two `Optional`s, so the states that cannot both be true are not
/// representable — see the `@State` above for why one slot rather than two `.sheet` modifiers.
///
/// `Identifiable` by a string built from the case, because `.sheet(item:)` wants one and the two
/// payloads have nothing in common: a draft is identified by the block it edits and a staffing
/// request by the court it is opened on, which may be nil for the block as a whole. The prefixes
/// keep those two id spaces apart — a court and a block are both `UUID` underneath.
private enum BlockDetailSheet: Identifiable {
    case editor(BlockEditorDraft)
    case staffing(Group.ID?)

    var id: String {
        switch self {
        case .editor(let draft): "editor-\(draft.id)"
        case .staffing(let courtID): "staffing-\(courtID?.uuidString ?? "block")"
        }
    }
}

// MARK: - Metrics

/// `5d`'s two numbers that are nobody else's. `ScheduleTokens.swift` is not this unit's file, and
/// two constants used by one header are not a vocabulary anything has to share.
private extension BlockDetailView {
    /// `width:36px;height:36px` on the back and `⋯` discs
    /// (`design/rebuild/section-t5.html:186`). Between the 34pt bordered default and the 40pt back
    /// button the component's own doc describes, and matched to each other rather than to either.
    static let headerDisc: CGFloat = 36
    /// `margin-top:15px` from the control row to the serif title.
    static let titleGap: CGFloat = 15
    /// The description plate's horizontal gutter, which is `CardRow`'s default restated so the
    /// plate cannot drift from the cards under it if that default moves.
    static let plateInset: CGFloat = 13
}

// MARK: - Previews

private struct BlockDetailPreview: View {
    var index: Int
    /// Who is on the block. The design's Tuesday says nothing about this, because nothing on it
    /// could until now — so the fixture takes it as a parameter and the previews below draw the
    /// answers that matter: covered, and not.
    var coachIDs: [StaffMember.ID] = []
    var isAdmin: Bool = true

    @State private var store: AppStore

    init(index: Int, coachIDs: [StaffMember.ID] = [], isAdmin: Bool = true) {
        self.index = index
        self.coachIDs = coachIDs
        self.isAdmin = isAdmin
        _store = State(initialValue: isAdmin ? AppStore.previewUCLAAdmin : AppStore.preview)
    }

    var body: some View {
        // No clock is pinned here any more. The fixture used to resolve the design's 9:41 so
        // `isCurrent` could be answered as `5d` draws it; nothing on the screen reads the minute
        // now, so there is no "now" for a preview to hold still.
        let blocks = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id, coachIDs: coachIDs)

        BlockDetailView(block: blocks[index], onClose: {})
        .environment(store)
        .showsMockStatusBar()
    }
}

#Preview("Block opened — a court each") {
    BlockDetailPreview(index: 1, coachIDs: [SampleData.nass.id, SampleData.alexStaff.id])
}

#Preview("Block opened — nobody on it") {
    BlockDetailPreview(index: 3)
}

/// The same screen for somebody who can only read it: no `Reassign`, no `Add a coach`, no "Mark
/// this block done", and the notes card carries no composer and no per-note `⋯`. The amber
/// "Needs a coach" on each head row stays, because it is a fact rather than a control.
#Preview("Block opened — coach, read-only") {
    BlockDetailPreview(index: 1, coachIDs: [SampleData.nass.id], isAdmin: false)
}
