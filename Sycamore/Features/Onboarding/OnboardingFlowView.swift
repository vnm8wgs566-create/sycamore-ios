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
    /// Kids typed in one at a time on `8e`.
    @State private var handAdded: [IntakePlayer] = []

    var body: some View {
        NavigationStack(path: $path) {
            BringInTheWeekView(
                venueName: shape.venues.first?.name ?? "the camp",
                handAddedCount: handAdded.count,
                onImported: { imported in
                    file = imported
                    path.append(.review)
                },
                onAddByHand: { path.append(.addPlayer(.new)) },
                onOpenCamp: finish
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
        .storeErrorBanner(message: store.errorMessage, onDismiss: store.clearError)
        .storeWorkingIndicator(store.isWorking, label: "Creating the camp…")
    }

    @ViewBuilder
    private func destination(_ step: OnboardingStep) -> some View {
        switch step {
        case .review:
            if let file {
                ImportReviewView(
                    file: file,
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
    /// Straight to the repository rather than through an intent, because `AppStore` has no
    /// vocabulary for enrolment yet and this branch does not own it — `store.perform` still
    /// carries the in-flight flag and the failure banner, so a network that drops half way
    /// through says so in the one place every other write says it. See the PR body for the two
    /// intents this should become.
    private func saveRoster() async {
        guard let campID = store.camp?.id else { return }
        let venueIDs = (store.camp?.orderedVenues ?? []).map(\.id)
        guard !venueIDs.isEmpty else { return }

        let handAdded = self.handAdded
        let imported = file?.players ?? []
        guard !handAdded.isEmpty || !imported.isEmpty else { return }

        await store.perform {
            // One at a time, because one at a time is how they were typed in.
            for kid in handAdded {
                let venueID = venueIDs[min(kid.venueIndex, venueIDs.count - 1)]
                store.camp = try await store.repository.addPlayer(
                    kid.asPlayer(), toVenue: venueID, campID: campID
                )
            }

            // One round trip per venue for the file. Almost always exactly one: a sign-up list
            // carries no venue column, so everybody lands in the first.
            for (index, kids) in Dictionary(grouping: imported, by: \.venueIndex).sorted(by: { $0.key < $1.key }) {
                let venueID = venueIDs[min(index, venueIDs.count - 1)]
                store.camp = try await store.repository.importPlayers(
                    kids.map { $0.asPlayer() }, toVenue: venueID, campID: campID
                )
            }
        }
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
