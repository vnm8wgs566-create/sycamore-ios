//
//  EnrolmentFlowView.swift
//  Sycamore
//
//  `8c` → `8d` / `8e`, reached from inside a camp that already exists.
//
//  Same three screens as onboarding, and that is the point: "import the sign-up list" and "add a
//  walk-in" are the same two questions in week three as on day one, so they are the same two
//  screens rather than a second set drawn to look like them.
//
//  Five things differ from `OnboardingFlowView`, and each of them is a consequence of the camp
//  already being there.
//
//  1. **It creates no camp.** No `campDraft`, no `createCamp()`, no `applyShape()`. Onboarding's
//     whole shape is arranged around the camp being written at the *end*; there is nothing to
//     arrange here.
//
//  2. **It dismisses itself.** Onboarding is torn down by `store.camp` going non-nil — "there is
//     nothing to dismiss by hand" (`OnboardingFlowView.swift:111-113`) — because creating the camp
//     flips the root from the picker to the tabs. Nothing this flow does changes the root, so the
//     way out is a closure the *caller* holds, for the reason `EarlyPickupSheet.swift:13-17`
//     gives: the presenter owns the presentation, and a screen that reached into it would need to
//     know which of the two entry points opened it.
//
//  3. **It reconciles against the store, and memoises the answer.** `store.camp?.players` is read,
//     never copied into `@State` — a private duplicate of a store-owned list goes stale on the
//     next write and there is no moment at which anything would notice. But the reconciliation
//     *itself* is `@State`, because a pass costs roughly `4N + 3M` `String.folding` calls and is
//     the most expensive thing in this file; recomputing it on every `body` would run it on every
//     keystroke of every screen in the stack. It is rebuilt when the file or the camp changes and
//     not otherwise. `RosterReconciliation` is a plain `Equatable, Sendable` struct with no
//     reference members, so it memoises cleanly — the stored copy cannot be a view onto something
//     that has since moved.
//
//  4. **It reads real venues** off `store.camp?.orderedVenues` rather than a `CampShape`. `8e`
//     takes `[VenueShape]`, so they go through `Venue.shape` — see `VenueShapeAdapter`, which
//     records why that borrowing is deliberate.
//
//  5. **It clears the file *and* the selection** when the review leaves the stack. Onboarding
//     clears the file for the reason at `OnboardingFlowView.swift:68-73`; the selection has to go
//     with it, because a selection held against a file that is gone is a set of ids pointing at
//     nothing — and the next file's rows carry freshly minted `IntakePlayer.id`s, so the stale set
//     would be silently, invisibly wrong rather than loudly so.
//
//  The by-hand path writes **immediately** here, one kid per intent, which onboarding cannot do.
//  See `AppStore.addPlayer(_:toVenue:)`.
//

import SwiftUI

/// One step past `8c`, inside a camp.
///
/// Deliberately not `OnboardingStep`, which has the same two cases. The enum is a route table for
/// one stack, and these two stacks route `.review` to different screens — `ImportReviewView` there
/// and `RosterReviewView` here. Sharing it would mean a reader seeing `.review` has to know which
/// flow they are in before they know which screen it names, which is the "chrome depends on a
/// flag" problem one level up from where this unit already refused it.
enum EnrolmentStep: Hashable, Sendable {
    case review
    case addPlayer(AddPlayerView.Mode)
}

struct EnrolmentFlowView: View {

    @Environment(AppStore.self) private var store

    /// Where a kid with no answer lands. Resolved by the caller — Groups uses the venue whose chip
    /// is selected, Camp settings the camp's first — because "which venue did you mean" is a
    /// question about the screen you came from, not about this flow.
    let venueID: Venue.ID
    /// The way out, held by whoever presented this. See the header.
    let onClose: () -> Void

    @State private var path: [EnrolmentStep] = []
    /// The file under review. Nil until one is read; replaced in place as gaps are filled.
    @State private var file: IntakeImport?
    /// How many kids have been typed in one at a time on `8e` this visit.
    ///
    /// A count rather than the list `OnboardingFlowView` keeps, because here each kid is *written*
    /// the moment they are saved and there is nothing left to hold. Keeping the rows would be a
    /// pending roster that is not pending — and the first thing a reader would reasonably assume
    /// about an array called `handAdded` is that something later sends it.
    @State private var handAddedCount = 0
    /// What the reader has ticked on the review screen. Seeded when a file arrives and preserved
    /// through a Fix; see `readFile(_:)`.
    @State private var selection = RosterSelection()
    /// The expensive part, computed off `reconcileKey` rather than in a `body`. Nil until a file
    /// is read.
    @State private var reconciliation: RosterReconciliation?

    // MARK: - Body

    var body: some View {
        // Resolved once. `venues` reads `Camp.orderedVenues`, which sorts and allocates on every
        // access, and `venueName` and `subtitle` each wanted it.
        let venue = venueName

        return NavigationStack(path: $path) {
            BringInTheWeekView(
                venueName: venue,
                subtitle: subtitle(at: venue),
                exit: .done,
                // Only the file is set. `rebuild` reconciles it, seeds the ticks and pushes the
                // review, in that order — see it for why the push cannot happen here.
                onImported: { file = $0 },
                onAddByHand: { path.append(.addPlayer(.new)) },
                onExit: onClose
            )
            .navigationDestination(for: EnrolmentStep.self) { step in
                destination(step)
            }
        }
        // The one writer of both. Rebuilt when the file changes — a new one, or a row fixed on
        // `8e` — and when the camp does, which a commit from this very flow is one cause of.
        // `initial: true` covers a file already in hand on the first pass, which a preview can
        // produce.
        .onChange(of: reconcileKey, initial: true, rebuild)
        // Backing out of the review abandons the file, and the ticks against it. Holding either
        // would leave state nothing on screen can reach: `8c` has no route back to a review that
        // was walked away from.
        .onChange(of: path) { _, steps in
            guard !steps.contains(.review) else { return }
            file = nil
            selection = RosterSelection()
        }
        // A modal covers the banner `MainTabView` floats, so this carries one of its own — the
        // same call `RootView` makes at each of its own presentation sites.
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
    }

    @ViewBuilder
    private func destination(_ step: EnrolmentStep) -> some View {
        switch step {
        case .review:
            if let file, let reconciliation {
                RosterReviewView(
                    file: file,
                    reconciliation: reconciliation,
                    selection: $selection,
                    onFix: { path.append(.addPlayer(.fix($0))) },
                    onApply: apply,
                    isApplying: store.isWorking
                )
            }

        case .addPlayer(let mode):
            AddPlayerView(mode: mode, venues: venueShapes) { player in
                save(player, mode: mode)
            }
        }
    }

    // MARK: - The camp, read

    private var venues: [Venue] { store.camp?.orderedVenues ?? [] }

    /// The camp's venues as `8e` draws them. See `VenueShapeAdapter` for why that type.
    private var venueShapes: [VenueShape] { venues.map(\.shape) }

    /// Where a walk-in lands, named. The caller's venue, falling back to the first — which is what
    /// `AddPlayerView`'s own chip row defaults to, so the two agree.
    private var venueName: String {
        (venues.first { $0.id == venueID } ?? venues.first)?.name ?? "the camp"
    }

    /// `2 added · 76 kids · Sycamore`, and without the first part before anything has been added.
    ///
    /// The camp's own count leads once there is one, because that is the number this screen is
    /// standing in front of. The visit tally goes first when it exists: a walk-in written a second
    /// ago has already moved the camp's total, so without it the reader taps "Add" and watches a
    /// number they were not counting change by one.
    private func subtitle(at venue: String) -> String {
        let count = store.camp?.playerCount ?? 0
        let camp = "\(count) kid\(count == 1 ? "" : "s") · \(venue)"
        guard handAddedCount > 0 else { return camp }
        return "\(handAddedCount) added · \(camp)"
    }

    // MARK: - Reconciling

    /// Everything a reconciliation is a function of, plus the one thing the *selection* is a
    /// function of.
    ///
    /// `.onChange` compares this once per pass — element-wise `==` over two arrays of value types,
    /// with no folding and no allocation — which is several orders cheaper than the pass it is
    /// guarding.
    ///
    /// The whole `IntakeImport` rather than its two fields spelled out, so the key cannot come to
    /// disagree with `file` about which file it describes. It carries the name as well as the
    /// rows, which is what lets `rebuild` tell "a different file" from "the same file with one row
    /// corrected" — the two events that reach it, and which want opposite things done to the ticks.
    private struct ReconcileKey: Equatable {
        let file: IntakeImport?
        let camp: [Player]
    }

    private var reconcileKey: ReconcileKey {
        ReconcileKey(file: file, camp: store.camp?.players ?? [])
    }

    /// The expensive pass, the only place the selection is seeded, **and the only place the review
    /// is pushed**.
    ///
    /// Pushing here rather than in `readFile` is not tidiness — it is what stops the review screen
    /// being reachable before there is anything to draw on it. Setting `file` and appending
    /// `.review` in the same pass means the destination is built on the body evaluation that
    /// *observes* the change, while `onChange` only runs after it: `destination(.review)` then
    /// finds `reconciliation` still nil and renders its empty branch, and a `navigationDestination`
    /// does not reliably fill an empty branch in afterwards. The result is a pushed screen with a
    /// back caret and nothing else, which is what the simulator showed. Pushing from here, the
    /// stack cannot hold `.review` until the reconciliation behind it exists.
    ///
    /// **Seeding is keyed on the file rather than on the reconciliation**, which is the whole point
    /// of carrying the name. This also runs when a row is *fixed* on `8e`, and re-seeding there
    /// would take back every tick the reader had changed their mind about — as would re-pushing.
    /// `RosterSelection`'s header explains why ids survive a fix — `IntakeImport.update(_:)`
    /// replaces a row by id — so holding the ticks across one is exactly what that design buys.
    ///
    /// The residual case is a fix that changes a *name* far enough for the row to newly match
    /// somebody at the camp: it moves from `arriving` to `changed`, its id changes meaning, and it
    /// arrives unticked. That is the safe direction, and the same one `opening(for:)` already
    /// chooses for an ambiguous match.
    private func rebuild(from previous: ReconcileKey, to key: ReconcileKey) {
        guard let file = key.file, !file.players.isEmpty else {
            reconciliation = nil
            return
        }

        let next = RosterReconciliation(file: file.players, camp: key.camp)
        reconciliation = next

        // The same file, re-reconciled: a row was fixed, or the camp moved under it. Neither is a
        // new decision to put in front of the reader.
        guard previous.file?.fileName != file.fileName else { return }
        selection = .opening(for: next)
        if !path.contains(.review) { path.append(.review) }
    }

    // MARK: - Saving

    private func save(_ player: IntakePlayer, mode: AddPlayerView.Mode) {
        switch mode {
        case .new:
            handAddedCount += 1
            // Written now rather than gathered. The camp exists, so there is nothing to be gained
            // by holding it — and a pending kid is a kid a dismissal can lose.
            let chosen = venues.indices.contains(player.venueIndex)
                ? venues[player.venueIndex].id
                : venueID
            Task { await store.addPlayer(player, toVenue: chosen) }

        case .fix:
            file?.update(player)
        }
        // Back to whichever screen asked — `8c` for a walk-in, the review for a gap in the file.
        if !path.isEmpty { path.removeLast() }
    }

    /// Writes everything ticked, then leaves.
    ///
    /// Closing on success rather than returning to `8c`: the reader agreed to a count, the count
    /// landed, and the thing they wanted to see next is the roster it changed. A failure leaves
    /// the flow standing with the banner over it and the ticks intact, which is the same shape
    /// `OnboardingFlowView.finish()` has.
    private func apply() {
        guard !store.isWorking, let reconciliation else { return }
        let commit = reconciliation.commit(selection)
        guard !commit.isEmpty else { return }

        Task {
            await store.applyRoster(commit, venues: venues.map(\.id))
            guard store.errorMessage == nil else { return }
            onClose()
        }
    }
}

// MARK: - Previews

#Preview("Bringing in another week") {
    let store = AppStore.preview

    return EnrolmentFlowView(
        venueID: store.camp?.orderedVenues.first?.id ?? UUID(),
        onClose: {}
    )
    .environment(store)
    .showsMockStatusBar()
}
