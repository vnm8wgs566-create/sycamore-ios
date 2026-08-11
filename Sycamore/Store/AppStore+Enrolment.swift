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

        // Which venues actually took somebody: the seating pass below asks only about those, and
        // the sentence after the write counts their groups. A set rather than the grouping's keys,
        // because two indices past the end of `venues` resolve to the same venue through the `min`
        // and asking twice would be a wasted round trip on the one path where an import is already
        // the slowest thing in the app.
        //
        // Declared outside `perform` because it is read on both sides of it.
        var seatedVenues: Set<Venue.ID> = []

        // Who was here before, so the sentence at the end can say who is new.
        //
        // **Not `commit.inserting`'s own ids.** That was the first attempt and it could only ever
        // report "0 dealt": `IntakePlayer.id` belongs to the *file row*, and `asPlayer()` mints a
        // fresh `Player.id` rather than carrying it across, so the two sets are disjoint by
        // construction. It compiled because both are `UUID` — the exact trap `RosterSelection`
        // warns about in prose — and no test asserted the sentence, so a forty-kid import that
        // seated perfectly announced "0 dealt into 6 groups · 40 to place".
        let before = Set((camp?.players ?? []).map(\.id))

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
                seatedVenues.insert(venueID)
            }

            // And then deal them onto courts.
            //
            // `importPlayers` lands everybody group-less on purpose, and for a long time nothing on
            // this path ever picked them up: a roster arrived and sat in one undivided "No group
            // yet" pile beside a venue's six empty courts, which is what a reader reported as "all
            // the kids in one group at one venue".
            //
            // Separate from the insert rather than folded into it, because the two answer different
            // questions and only one of them is safe to repeat. `importPlayers` must not run twice;
            // `seatArrivals` is idempotent by construction — it only ever touches kids with no
            // court — so a retry after a half-failed import re-seats the new arrivals and moves
            // nobody a coach has already placed.
            //
            // In venue order rather than the set's, which has none. Two venues seated in a
            // different order on two devices would produce two different-looking camps from the
            // same file, and "why is Ellis on court 3 on your phone and court 1 on mine" is not a
            // question anybody should have to answer about an import.
            for venueID in venues where seatedVenues.contains(venueID) {
                camp = try await repository.seatArrivals(atVenue: venueID, campID: campID)
            }

            if !commit.updating.isEmpty {
                camp = try await repository.updatePlayers(commit.updating, campID: campID)
            }

            if !commit.removing.isEmpty {
                camp = try await repository.removePlayers(commit.removing, campID: campID)
            }
        }

        // What actually happened, counted off the graph that came back rather than off what was
        // asked for. A roster of forty where six are outside every band is "34 dealt · 6 to
        // place"; saying "40 dealt" would be the screen's word against the venue's.
        guard errorMessage == nil, !commit.inserting.isEmpty else { return }
        let arrived = (camp?.players ?? []).filter { !before.contains($0.id) }
        guard !arrived.isEmpty else { return }

        let dealt = arrived.count { $0.groupID != nil }
        let waiting = arrived.count - dealt

        // The courts somebody actually landed on, not every court at the venue. "34 dealt into 6
        // groups" was true of a venue where only three of the six received anybody, which is the
        // same class of over-claim as the count above.
        let landedOn = Set(arrived.compactMap(\.groupID))
        let groups = landedOn.count

        if waiting > 0 {
            say("\(dealt) dealt into \(groups) \(groups == 1 ? "group" : "groups") · \(waiting) to place")
        } else {
            say("\(dealt) dealt into \(groups) \(groups == 1 ? "group" : "groups")")
        }

        land(on: arrived)
    }

    /// Puts the reader in front of the kids that just arrived.
    ///
    /// `doImport` ends `tab: 'groups', venueSel: venue.id, page: null` (`state1.js:567`), and the
    /// app ended nowhere in particular: onboarding was torn down by `store.camp` landing and
    /// `RootView` decided, while `EnrolmentFlowView` called `onClose()` and left whichever screen
    /// had presented it — Groups, Setup, Camp, Shape or Tournament — showing whatever it had been
    /// showing. Forty kids were written and the screen looked exactly as it had a moment before,
    /// which on the one write that changes the most is the worst possible answer.
    ///
    /// **Here rather than in the two flows**, because where to land is a consequence of the write
    /// and not of which screen asked for it — and because the two flows would otherwise each need
    /// to work out which venue took the most kids, from a graph only this method has both sides of.
    ///
    /// **The venue that took the most of them**, ties falling to the camp's own venue order. The
    /// prototype has one venue selected and no such question; a roster here is routed by age band
    /// and can land at three at once, and the most useful of the three is the one holding the most
    /// new names. Venue order breaks the tie so two devices importing the same file land the same
    /// way, which is the same reason `applyRoster` seats in venue order rather than in a set's.
    ///
    /// `venueFilter` and not `chosenVenueID`: Groups reads its venue off the chip row
    /// (`GroupsView.selectedVenue`), and `chosenVenueID` is section 8's read scope. Writing the one
    /// that is not read would be a line that looks like it works.
    private func land(on arrived: [Player]) {
        guard let camp else { return }
        var counts: [Venue.ID: Int] = [:]
        for player in arrived {
            guard let venueID = player.venueID else { continue }
            counts[venueID, default: 0] += 1
        }
        guard let busiest = camp.orderedVenues.map(\.id).max(by: {
            counts[$0, default: 0] < counts[$1, default: 0]
        }), counts[busiest, default: 0] > 0 else { return }

        selectedTab = .groups
        venueFilter = .venue(busiest)
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
