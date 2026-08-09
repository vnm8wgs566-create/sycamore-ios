//
//  RosterSelection.swift
//  Sycamore
//
//  Which parts of a reconciliation the admin actually agreed to, and what that turns into.
//
//  **Selection is ids, not values.** `IntakeImport.update(_:)` replaces a row by `id`
//  (`IntakeRoster.swift:133`) and `AddPlayerView` hands back the same `IntakePlayer` it was given,
//  so a row's id survives a trip through the Fix screen while every field on it may not. A tick
//  held as a value would come back from a fix untucked — the admin corrects an age and the kid
//  silently drops out of the import — and it would come back untucked precisely on the rows
//  somebody had already had to think about.
//
//  This is a separate file from `RosterReconciliation` because it is a separate lifetime: the
//  reconciliation is derived from a file and a camp and never changes, and the selection is
//  `@State` on a screen that the reader is poking at.
//

import Foundation

struct RosterSelection: Hashable, Sendable {
    /// Rows to create, by `IntakePlayer.id`.
    var arriving: Set<IntakePlayer.ID> = []
    /// Kids to patch, by `Player.id`.
    var changed: Set<Player.ID> = []
    /// Kids to take off the roster, by `Player.id`.
    var removing: Set<Player.ID> = []

    /// Every arrival and every unambiguous change ticked; **nothing ticked for removal**.
    ///
    /// The empty removal set is not a cautious default, it is the decision the feature was built
    /// on, written down: kids in the camp but not in the file are *flagged*, not removed. A file
    /// is a list of who signed up, not a list of who exists — an office that exports one week's
    /// sign-ups is not saying the other forty children have left — so the only thing that may take
    /// a child off a roster is a person ticking a box next to their name.
    ///
    /// An ambiguous change starts unticked for the same reason at a smaller scale: the matcher
    /// could not tell two kids apart, so the one thing it must not do is decide for the reader and
    /// pre-tick its guess.
    static func opening(for reconciliation: RosterReconciliation) -> RosterSelection {
        RosterSelection(
            arriving: Set(reconciliation.arriving.map(\.id)),
            changed: Set(reconciliation.changed.lazy.filter { !$0.isAmbiguous }.map(\.id)),
            removing: []
        )
    }
}

// MARK: - What a tick writes

extension RosterReconciliation {

    /// The three writes a commit makes, in the buckets' own order.
    ///
    /// Read back off this reconciliation rather than trusted from the selection, so an id from a
    /// file that has since been re-parsed — or from a bucket it does not belong to, `Player.ID` and
    /// `IntakePlayer.ID` both being `UUID` — writes nothing rather than something unexpected.
    ///
    /// Rows with an open `IntakePlayer.issue` are **not** filtered out here. `8d` already sorts
    /// those into "Needs a detail" with a Fix button beside them, and a commit that quietly
    /// dropped a row the admin had ticked would be worse than one that reports the column's
    /// complaint.
    func commit(_ selection: RosterSelection) -> Commit {
        Commit(
            inserting: arriving.lazy.filter { selection.arriving.contains($0.id) }.map(\.row),
            updating: changed.lazy.filter { selection.changed.contains($0.id) }.map(\.updated),
            removing: absent.lazy.filter { selection.removing.contains($0.id) }.map(\.id)
        )
    }

    struct Commit: Equatable, Sendable {
        /// New kids, still as file rows: `venueIndex` is the only thing that says where they go,
        /// and grouping by it is the caller's job because only the caller has the venues.
        let inserting: [IntakePlayer]
        /// Whole players, already patched — see `RosterReconciliation.Change.updated`.
        let updating: [Player]
        let removing: [Player.ID]

        /// Nothing was ticked, so there is nothing to write and no reason to spin the button.
        var isEmpty: Bool { inserting.isEmpty && updating.isEmpty && removing.isEmpty }
    }
}
