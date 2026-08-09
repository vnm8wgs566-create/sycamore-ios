//
//  AppStore+Enrolment.swift
//  Sycamore
//
//  The store's vocabulary for enrolment: a roster agreed to on a review screen, and one kid typed
//  in at a gate.
//
//  It did not have one. `OnboardingFlowView.saveRoster` went straight to the repository and said so
//  in a comment naming the two intents it should become; these are those two, and that bypass is
//  gone in the same change. A store that gains a vocabulary one caller still refuses to use is
//  worse than one that never gained it — the next reader has two places to look for how a roster
//  is written and no way to tell which is authoritative.
//
//  A separate file for the reason `AppStore+Camp` and `AppStore+SectionEight` are separate files:
//  `AppStore.swift` is already the longest thing in `Store/`, and these two are reached only from
//  the enrolment flow.
//

import Foundation

extension AppStore {

    // MARK: - A whole roster

    /// Everything a reader ticked on the review screen, written in one go.
    ///
    /// -----------------------------------------------------------------------------------------
    /// ONE INTENT FOR THREE WRITES, NOT THREE
    /// -----------------------------------------------------------------------------------------
    ///
    /// `perform` owns the in-flight flag and the failure banner, and it clears `errorMessage` on
    /// entry. Three intents in a row would therefore raise a banner naming whichever of the three
    /// failed *last*, having wiped whatever the earlier ones said — so a run that inserted eight
    /// kids, failed to update three and then removed two would report the removal and mention
    /// neither of the other outcomes. One `perform` around all three means the first failure stops
    /// the batch and the banner names it.
    ///
    /// -----------------------------------------------------------------------------------------
    /// INSERT, THEN UPDATE, THEN REMOVE — AND NOT FOR TIDINESS
    /// -----------------------------------------------------------------------------------------
    ///
    /// There is no transaction across three round trips, so the order decides what a half-failure
    /// leaves behind. Removing **last** means the destructive step runs only after the two
    /// additive ones have succeeded: a network that drops half way through leaves a camp with
    /// extra kids in it, which is a state somebody can look at and fix, rather than a camp with
    /// kids missing and no record of who they were.
    ///
    /// Insert before update for the smaller version of the same argument — an insert that fails
    /// costs nothing, and doing it first means the run that gets furthest is the run that has
    /// written the most recoverable things.
    ///
    /// -----------------------------------------------------------------------------------------
    /// AN EMPTY LIST IS SKIPPED HERE, NOT IN THE REPOSITORY
    /// -----------------------------------------------------------------------------------------
    ///
    /// Each of `importPlayers`, `updatePlayers` and `removePlayers` guards its own empty case by
    /// returning `try await camp(id: campID)`, which against Postgres is **eight selects in two
    /// waves** — including a whole week of attendance and the entire inbox. A commit that only
    /// corrects three ages would otherwise spend sixteen of those on two calls that write nothing.
    /// The repository's guard is still right for what it is (a caller that asks for nothing gets
    /// the camp back, not a throw); this is the caller that knows in advance it is asking for
    /// nothing.
    ///
    /// - Parameter venues: the camp's venues in order. Arrivals carry a `venueIndex` — a position,
    ///   because `8b` had no venue ids when the type was drawn — and this is what it is a position
    ///   into. `min(index, count - 1)` is the same arithmetic `AddPlayerView`'s chip row implies:
    ///   a file's rows all default to 0, so in practice everybody lands in the first.
    func applyRoster(_ commit: RosterReconciliation.Commit, venues: [Venue.ID]) async {
        guard let campID = camp?.id, !commit.isEmpty else { return }
        // Arrivals with nowhere to land. Refused whole rather than written partly: doing the
        // updates and silently dropping the new kids would report success for a roster that is
        // missing the half the reader was most likely looking at.
        guard commit.inserting.isEmpty || !venues.isEmpty else { return }

        await perform {
            // One round trip per venue, almost always exactly one — a sign-up list carries no
            // venue column, so everybody lands in the first. Batched rather than looped over
            // `addPlayer` because a roster is forty-odd kids and an insert either lands whole or
            // not at all; half a roster is worse than none, since nobody can tell which half.
            for (index, kids) in Dictionary(grouping: commit.inserting, by: \.venueIndex)
                .sorted(by: { $0.key < $1.key }) {
                let venueID = venues[min(index, venues.count - 1)]
                camp = try await repository.importPlayers(
                    kids.map { $0.asPlayer() }, toVenue: venueID, campID: campID
                )
            }

            if !commit.updating.isEmpty {
                camp = try await repository.updatePlayers(commit.updating, campID: campID)
            }

            if !commit.removing.isEmpty {
                camp = try await repository.removePlayers(commit.removing, campID: campID)
            }
        }
    }

    // MARK: - One kid

    /// `8e`, from inside a camp: a walk-in at 8:55, written the moment they are saved.
    ///
    /// Singular and immediate, unlike onboarding — where the same screen collects kids into
    /// `handAdded` and writes them at the end, because until the flow finishes there is no camp to
    /// write to. Here there is, so there is nothing to be gained by holding them: a pending list
    /// is a list that can be lost by a dismissal, and "did that kid save?" is not a question to
    /// leave open on a court.
    ///
    /// Through `importPlayers` rather than `addPlayer` would work, but `addPlayer` is what the
    /// repository names this and it is one row: the batch exists for the round-trip cost of forty.
    func addPlayer(_ player: IntakePlayer, toVenue venueID: Venue.ID) async {
        guard let campID = camp?.id else { return }
        await perform {
            camp = try await repository.addPlayer(
                player.asPlayer(), toVenue: venueID, campID: campID
            )
        }
    }
}
