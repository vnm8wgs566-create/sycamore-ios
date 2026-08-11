//
//  OnboardingFlowView.swift
//  Sycamore
//
//  `8c` → `8d` / `8e`, and the one place the camp is actually written.
//
//  The order is the design's: shape the camp, bring in the week, check what came in. It is one
//  flow rather than three screens because none of them means anything on its own — a camp with
//  no kids is a shape, and a list of kids with no camp is a file.
//
//  Two things are worth knowing about how this is wired.
//
//  The stack is local. `AppStore` routes by state (`camp == nil` decides the whole screen), and
//  it has no vocabulary for "part-way through setting a camp up". Rather than teach it one from
//  a branch that owns four screens, the path lives here in `@State` — see the PR body for the
//  store surface this should become.
//
//  The camp is created at the *end*, not at `8b`. `createCamp` sets `AppStore.camp`, which flips
//  the root from the picker to the tabs and tears this flow down with it — so creating the camp
//  first would mean `8c` never appeared. Committing at the end also makes the button on `8d`
//  honest: nothing has been written until you agree to the count.
//
//  The kids are written in the same breath, and in the order the repository names them: the ones
//  typed in on `8e` go through `addPlayer`, one at a time, because one at a time is what that
//  screen produces; the file goes through `importPlayers`, which is one round trip for forty kids
//  and either lands whole or not at all. Both put a kid at the back of their venue with no court,
//  so `Groups`' unassigned band is where somebody decides where they belong.
//

import SwiftUI

/// One step past `8c`. `8e` carries its mode because "add a walk-in" and "fill in what the file
/// missed" are the same screen with a different answer already in it.
enum OnboardingStep: Hashable, Sendable {
    case review
    case addPlayer(AddPlayerView.Mode)
}

struct OnboardingFlowView: View {

    @Environment(AppStore.self) private var store

    /// The shape `8b` drew. Written into the camp the moment it exists — see `finish()`.
    let shape: CampShape

    @State private var path: [OnboardingStep] = []
    /// The file under review. Nil until one is read; replaced in place as gaps are filled.
    @State private var file: IntakeImport?
    /// Kids typed in one at a time on `8e`. Gathered rather than written, unlike
    /// `EnrolmentFlowView`, because until this flow ends there is no camp to write them to.
    @State private var handAdded: [IntakePlayer] = []

    /// Where a walk-in lands — the first venue, which is where the design puts the under-11s.
    private var venueName: String { shape.venues.first?.name ?? "the camp" }

    /// What `8c`'s grey line names, off the draft rather than off the shape.
    ///
    /// `CampShape` carries the venues and the two rates; the name is `CampDraft`'s, and the draft
    /// is the store's because it survives the two screens that collect it. Falling back to the
    /// venue keeps the line honest in the one state that can reach here without a name — a preview
    /// that seeds a shape and no draft. Nothing in the flow itself can: `8b`'s "Save the shape" is
    /// disabled until the camp is named (`CampDraft.isCreatable`), which is what puts a real name
    /// in the draft before this screen is ever built.
    private var campName: String {
        let named = store.campDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return named.isEmpty ? venueName : named
    }

    var body: some View {
        NavigationStack(path: $path) {
            BringInTheWeekView(
                venueName: venueName,
                // Composed here rather than inside the screen: `8c` counts kids that are not
                // written anywhere yet, and the same screen from inside a camp counts a roster.
                // Only the caller knows which of those it is.
                //
                // The **camp** rather than the venue, which is what the frame names — "Nobody added
                // yet · Northside Tennis Camp", where the same design calls a venue plainly
                // "Northside". It read `venueName` here and that was the weaker of the two at
                // exactly this moment in the flow: `8b` does not make anybody name a venue, so the
                // line said "Nobody added yet · Venue 1" to a person who had just typed the camp's
                // name two screens ago. `EnrolmentFlowView` still names the venue, because from
                // inside a camp you arrive from one venue's chip and that is the question you asked.
                subtitle: handAdded.isEmpty
                    ? "Nobody added yet · \(campName)"
                    : "\(handAdded.count) added by hand · \(campName)",
                exit: .openCamp,
                onImported: { imported in
                    file = imported
                    path.append(.review)
                },
                onAddByHand: { path.append(.addPlayer(.new)) },
                onExit: finish
            )
            .navigationDestination(for: OnboardingStep.self) { step in
                destination(step)
            }
        }
        // Backing out of the review abandons the file. Holding it would leave a roster nothing
        // on screen can reach — `8c` has no route back to a review that was walked away from,
        // and its "nobody added yet" would be quietly untrue.
        .onChange(of: path) { _, steps in
            if !steps.contains(.review) { file = nil }
        }
        // The banner, and nothing beside it. A "Creating the camp…" capsule floated here — the
        // only one in the app with a label of its own — and went with the rest. What still shows
        // the write: `finish()` guards the second tap below, `8d` dims its Import button, and the
        // flow is torn down by its own success the moment `store.camp` lands.
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
    }

    @ViewBuilder
    private func destination(_ step: OnboardingStep) -> some View {
        switch step {
        case .review:
            if let file {
                ImportReviewView(
                    file: file,
                    // The bands chosen on `8b`. Omitted until now, so a file imported into a camp
                    // whose venues had been narrowed was placed as if none of them were — the
                    // screen whose promise is "nothing is written until the button at the bottom"
                    // was showing a placement the button would not make.
                    venues: shape.venues.map(\.rosterVenue),
                    onFix: { path.append(.addPlayer(.fix($0))) },
                    onCommit: finish,
                    isCommitting: store.isWorking
                )
            }

        case .addPlayer(let mode):
            AddPlayerView(mode: mode, venues: shape.venues) { player in
                save(player, mode: mode)
            }
        }
    }

    // MARK: Saving one kid

    private func save(_ player: IntakePlayer, mode: AddPlayerView.Mode) {
        switch mode {
        case .new: handAdded.append(player)
        case .fix: file?.update(player)
        }
        // Back to whichever screen asked — `8c` for a walk-in, `8d` for a gap in the file.
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: Ending the flow

    /// Writes the camp and the week's kids, then lands in the app. `RootView` swaps the picker
    /// for the tabs the moment `store.camp` is set, which is what dismisses this flow — there is
    /// nothing to dismiss by hand, and a failure leaves the flow standing with the banner over it.
    private func finish() {
        guard !store.isWorking else { return }

        store.campDraft = shape.applied(to: store.campDraft)

        // Unstructured on purpose: this view is torn down by the success of its own first
        // await, and the venue and roster writes after it have to survive that.
        Task { @MainActor in
            await store.createCamp()
            guard store.camp != nil else { return }
            await applyShape()
            await saveRoster()
        }
    }

    /// `createCamp` builds every venue to the same size, because that is all `CampDraft` can
    /// say. This writes each row's real numbers over the top; `updateVenue` re-syncs the courts,
    /// so a camp drawn as six courts here and four there ends up exactly that.
    private func applyShape() async {
        for (index, venue) in (store.camp?.orderedVenues ?? []).enumerated() {
            guard let updated = shape.venue(applying: index, to: venue) else { continue }
            await store.updateVenue(updated)
        }
    }

    /// Everyone `8c`, `8d` and `8e` gathered, into the venue each was answered into.
    ///
    /// Through `store.applyRoster`, which is the intent this used to say it should become. It went
    /// straight to the repository because the store had no vocabulary for enrolment; it has one
    /// now, and a store that gains a vocabulary one caller still refuses to use leaves two places
    /// to look for how a roster is written and nothing to say which is authoritative.
    ///
    /// Every row is an insert: at onboarding there is nobody to reconcile against, so the commit
    /// has an empty `updating` and an empty `removing` and `applyRoster` skips both round trips.
    ///
    /// The kids typed in by hand go **first**, in front of the file, which is the order this had
    /// before. What changed is that they now travel in the same batch rather than one round trip
    /// each: "one at a time, because one at a time is how they were typed in" was a sentence about
    /// the reader's experience of a screen, spent on forty sequential network calls at the one
    /// moment somebody is waiting for a camp to open.
    /// **Routed, which it was not.** `ImportReviewView` has always computed the age fit and printed
    /// it — "38 go to Sycamore · 4 need someone to place them" — and then this method built the
    /// commit from the file's untouched rows and handed it over. `IntakePlayer.venueIndex` defaults
    /// to 0 and no file has a venue column, so every arrival grouped under key 0 and the whole
    /// roster went to the first venue: the screen showed a split the button did not perform.
    ///
    /// `routed(by:)` is the verb written for exactly this and `EnrolmentFlowView` was its only
    /// caller. It runs the identical `RosterAgeFit` over the identical rows, off the identical
    /// `shape.venues` the review screen was drawn from three lines above — which is what makes the
    /// two answers the same answer rather than two computations that agree today.
    ///
    /// Safe for the by-hand kids in front of the file. `RosterAgeFit` treats a row's existing
    /// `venueIndex` as its *home* and leaves it alone when that venue admits them, so a walk-in
    /// stays on the chip they were saved against; the only ones it moves are those whose chosen
    /// venue would refuse them, which is the one case where honouring the chip is the bug.
    private func saveRoster() async {
        let arriving = handAdded + (file?.players ?? [])
        guard !arriving.isEmpty else { return }

        await store.applyRoster(
            RosterReconciliation.Commit(inserting: arriving, updating: [], removing: [])
                .routed(by: shape.venues.map(\.rosterVenue)),
            venues: (store.camp?.orderedVenues ?? []).map(\.id)
        )
    }
}

// MARK: - Previews

#Preview("Getting in — the flow") {
    let store = AppStore.previewCampPicker
    store.campDraft = CampDraft(name: "UCLA Tennis Camp", sport: .tennis)

    return OnboardingFlowView(shape: .initial())
        .environment(store)
        .showsMockStatusBar()
}
