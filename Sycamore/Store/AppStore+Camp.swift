//
//  AppStore+Camp.swift
//  Sycamore
//
//  The store surface for `8t`'s Season and Staff & joining blocks: the camp's own name, the
//  sport it plays, and the code people join it with.
//
//  Split from `AppStore.swift` for the reason `AppStore+SectionEight.swift` gives — the file
//  every feature edits is the file every feature conflicts in. The intents themselves are the
//  same three lines as `updateVenue`; what earns them a file is the second half of a rename,
//  which no other camp write has to do.
//

import Foundation

extension AppStore {

    /// `8t`'s "Camp name & sport".
    ///
    /// Two writes, not one. The camp graph is what this screen draws, but the camp *picker*
    /// draws `Membership.campName` — a denormalised copy taken when the list was loaded, which
    /// both repositories refresh on their own side and neither can reach into the app to fix.
    /// Without the second read, `8u` and Profile's subtitle keep the old name until the next
    /// sign-in, which is the kind of disagreement nobody thinks to look for.
    ///
    /// Inside one `perform`, so the two are one piece of work: `perform` tracks in flight with a
    /// plain `Bool`, and a second call would clear the spinner the first one was still using.
    func renameCamp(name: String, sport: Sport) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.renameCamp(
                name: name, sport: sport, campID: campID
            )
            // Returns from the closure, not from the intent: the rename above has already
            // landed, and no account to re-read the list for is not a reason to undo it.
            guard let account = self.account else { return }
            self.memberships = try await self.repository.memberships(forAccount: account.id)
            // Keep whatever was selected if the refreshed list somehow has no row for this camp.
            // Clearing it would drop the reader back to the picker over a rename that worked.
            self.selectedMembership = self.memberships.first { $0.campID == campID }
                ?? self.selectedMembership
        }
    }

    /// `8t`'s "Days the camp runs".
    ///
    /// One write, where the rename above needs two. The picker's projection is `campName`,
    /// `campIcon`, `campTint` and a summary of venues and kids (`Membership`, `Models.swift`) —
    /// there is nowhere in it for the days to be stale, so re-reading the whole membership list
    /// after this would be seven requests to learn nothing.
    func setCampDays(_ days: CampDays) async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.setCampDays(days, campID: campID)
        }
    }

    /// `8t`'s "Roll a new code". No membership refresh: an invite code is not part of the
    /// picker's projection, and the only place it is drawn is the row above the one that rolled
    /// it — which reads it straight off `camp`.
    func rollInviteCode() async {
        guard let campID = camp?.id else { return }
        await perform {
            self.camp = try await self.repository.rollInviteCode(campID: campID)
        }
    }
}
