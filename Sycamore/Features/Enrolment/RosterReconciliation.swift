//
//  RosterReconciliation.swift
//  Sycamore
//
//  The office's file read against a camp that already has kids in it: who is new, who is already
//  here, what the file says differently about them, and who the file left out.
//
//  Pure `Foundation` — no store, no `@MainActor`, no SwiftUI — for the reason `GroupsLandingPlan`
//  records at the top of its own file: this is arithmetic that can put a child in the wrong place
//  without anything on screen looking wrong, and arithmetic like that belongs somewhere a test can
//  reach it. The review screen is built on top of this and owns none of it.
//
//  The entry types are nested rather than hoisted to file scope. `AppStore`'s filter enums were
//  hoisted (`AppStore.swift:10-12`) to keep their `CaseIterable`/`Identifiable` conformances clear
//  of actor isolation; this type has no isolation to be caught by, so nesting is free and says
//  what these things belong to. `Commit` nests here too but is declared over in
//  `RosterSelection.swift`, beside the ticks it is built from.
//
//  ---------------------------------------------------------------------------------------------
//  THE MATCH KEY: THE NAME IS THE KEY. AGE DISAMBIGUATES AND DETECTS CHANGE; IT IS NOT IN THE KEY.
//  ---------------------------------------------------------------------------------------------
//
//  This is the load-bearing decision. Put age in the key and a kid whose age was *corrected*
//  between two files — a birthday, or a typo the office fixed — produces **two** rows: a duplicate
//  in New, and the real child sitting in "Not in this file" being offered for removal. That is
//  precisely the failure a re-import exists to prevent, and it is the worst one on the board:
//  the roster ends up with two of somebody and none of somebody else, and the admin was shown a
//  screen that looked reasonable while it happened.
//
//  Name-dominant matching turns that same event into one Changed row reading `12 years →
//  13 years`, which is the thing the admin opened the file to see.
//
//  **Two keys per person**, because the camp holds rows that carry only `lastInitial` and no
//  `lastName` at all (`Models.swift:425-429` — 100 seeded kids are exactly that):
//
//  - strict — `serene|chu`. Nil when either side has no surname.
//  - loose  — `serene|c`. Always available; `serene|` for somebody known by one name.
//
//  Matched strict first, then loose, so a file's "Liam Prior" prefers the camp's "Liam Prior" over
//  the camp's "Liam Park" before the initial tier is ever consulted. Under the loose tier a camp
//  kid recorded as "Serene C" matches the file's "Serene Chu" and the surname becomes a **Changed**
//  field — the single most valuable thing a re-import does, and unreachable without that tier.
//
//  The initial is therefore also the *limit*. Two spellings with different first letters — "Chu"
//  and "Zhu" — are two children as far as this can tell, and land as one New and one Missing. That
//  is stated rather than papered over: a fuzzy surname match would silently merge two real
//  siblings far more often than it would catch a typist.
//
//  **The fold uses `locale: nil`, deliberately.** `Player.matches(search:)` uses
//  `localizedStandardContains` because a search field belongs to whoever is holding the phone. A
//  *key* does not. A locale-aware fold moves a kid between buckets when the reader changes their
//  language — Turkish folds `I` to `ı`, so "Iris" and "IRIS" stop being the same person — and a
//  roster that reconciles differently in two languages is a roster nobody can trust.
//
//  ---------------------------------------------------------------------------------------------
//  WHAT IS DELIBERATELY NOT READ
//  ---------------------------------------------------------------------------------------------
//
//  `venueID`, `groupID`, `overallRank`, `courtRank`. Camp state, not file state. **A re-import
//  never moves a kid who is already in the camp** — where a child stands was decided on Groups by
//  somebody watching them play, and a spreadsheet column that mostly holds its own default does
//  not get to overturn that. `IntakePlayer.venueIndex` is a destination for arrivals only, and
//  `IntakePlayer.id` is a fresh `UUID` per parse (`IntakeRoster.swift:23`) that is never written
//  onto an existing kid.
//
//  **Rejected alternative: `players.external_ref`.** The column exists in Postgres, is nullable,
//  carries no unique index, and is completely unused by the app — the seed migration is the only
//  thing that has ever written it. A stable office id there would make every line below exact and
//  make this file a fallback rather than the mechanism. It is not used because *no file supplies
//  one*: the exports this app has seen carry names, ages and genders and nothing else. If a camp
//  ever exports an office id, `external_ref` becomes tier 0 above the strict key and the rest of
//  this stands underneath it unchanged.
//

import Foundation

struct RosterReconciliation: Equatable, Sendable {

    // MARK: - What one row turned into

    /// A row nobody at the camp answers to. Becomes a kid on commit, at `row.venueIndex`.
    struct Arrival: Identifiable, Hashable, Sendable {
        var id: IntakePlayer.ID { row.id }
        let row: IntakePlayer
    }

    /// A row that found its kid and said nothing the camp did not already hold.
    struct Match: Identifiable, Hashable, Sendable {
        var id: Player.ID { player.id }
        let row: IntakePlayer
        let player: Player
        let isAmbiguous: Bool
    }

    /// A row that found its kid and disagrees with the camp about something.
    struct Change: Identifiable, Hashable, Sendable {
        var id: Player.ID { player.id }
        let row: IntakePlayer
        let player: Player
        /// Never empty — see `init?`.
        let fields: [FieldChange]
        let isAmbiguous: Bool
        /// The kid as the file would leave them, everything else untouched. This is what a commit
        /// writes; it is built beside `fields` from the same comparison so the two cannot drift.
        var updated: Player

        /// Nil when the file says nothing this camp does not already hold — which is a `Match`,
        /// not a change. Deciding that here rather than at the call site keeps one rule in one
        /// place: an entry with an empty `fields` cannot be constructed at all.
        ///
        /// The kid is patched **first** and the fields are then read back off the difference,
        /// rather than the two being derived from the row in parallel. Only `applying` knows what
        /// a nil on the file side means, so a field the screen offers and a field the commit
        /// writes cannot come apart — anything `applying` left alone is, by construction, not a
        /// change.
        init?(row: IntakePlayer, player: Player, isAmbiguous: Bool) {
            let updated = RosterReconciliation.applying(row, to: player)
            let fields = RosterReconciliation.differences(from: player, to: updated)
            guard !fields.isEmpty else { return nil }

            self.row = row
            self.player = player
            self.fields = fields
            self.isAmbiguous = isAmbiguous
            self.updated = updated
        }
    }

    /// A kid at the camp no row claimed. **Flagged, never removed** — see `RosterSelection`.
    struct Absence: Identifiable, Hashable, Sendable {
        var id: Player.ID { player.id }
        let player: Player
        let isAmbiguous: Bool
    }

    /// `Age unknown → 13 years`.
    ///
    /// The strings are the ones the review screen draws, so the copy is pinned by a test rather
    /// than reinvented inside a `ViewBuilder` — the same call `Player.metaLine` and
    /// `Player.ageLabel` already make.
    struct FieldChange: Hashable, Sendable {
        enum Field: Hashable, Sendable { case age, gender, isReturning, surname }
        let field: Field
        let before: String
        let after: String
    }

    // MARK: - The four buckets

    /// In file order, which is the order the review screen draws them in.
    let arriving: [Arrival]
    let alreadyHere: [Match]
    let changed: [Change]
    /// In the camp's own order — the ladder, as the caller handed it over.
    let absent: [Absence]

    /// How many rows the file had. Counted back out of the buckets rather than remembered from
    /// the input, because every row lands in exactly one of the three and a stored copy could
    /// disagree with them.
    var fileCount: Int { arriving.count + alreadyHere.count + changed.count }

    /// `42 in the file · 8 new · 3 changed · 2 not in this file`.
    ///
    /// Zeroes drop out rather than reading `0 changed`: on the first import every count but "new"
    /// is zero, and a line of noughts is three pieces of nothing in front of the one number that
    /// matters. A file that agrees with the camp entirely says so in words instead.
    var summary: String {
        var parts = ["\(fileCount) in the file"]
        if !arriving.isEmpty { parts.append("\(arriving.count) new") }
        if !changed.isEmpty { parts.append("\(changed.count) changed") }
        if !absent.isEmpty { parts.append("\(absent.count) not in this file") }
        if parts.count == 1 { parts.append("nothing has changed") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Reconciling

    /// - Parameters:
    ///   - file: the rows as parsed, in the file's own order.
    ///   - camp: every kid the camp currently holds.
    init(file: [IntakePlayer], camp: [Player]) {
        let rowKeys = file.map { Self.keys(first: $0.firstName, surname: $0.lastName) }
        let kidKeys = camp.map {
            Self.keys(first: $0.firstName, surname: $0.lastName, initial: $0.lastInitial)
        }

        // Bucketed by the loose key, so both tiers of a name are decided together and one child
        // cannot be claimed by two buckets.
        //
        // Rows arrive in file order — the order the admin is looking at, which is what makes the
        // outcome explicable rather than merely deterministic. Kids arrive sorted by
        // `id.uuidString`, which is the only stable ordinal a `Player` has: `overallRank` is
        // derived from `ratings.rating` at read time (`SupabaseRepository+Graph.swift:39-58`) and
        // moves the moment anybody is assessed, so ordering by it would make the same file
        // reconcile differently on Tuesday.
        //
        // `uuidString` is decorated out first rather than read inside the comparator: it renders a
        // fresh 36-character String on every access, and a comparator runs n log n times.
        let ordinals = camp.map(\.id.uuidString)
        let rowsByKey = Dictionary(grouping: file.indices) { rowKeys[$0].loose }
        let kidsByKey = Dictionary(
            grouping: camp.indices.sorted { ordinals[$0] < ordinals[$1] }
        ) { kidKeys[$0].loose }

        // A loose key with more than one person on either side had a choice to get wrong, and
        // every entry it produces is flagged. Counted from both sides: two children the roster
        // cannot tell apart are worth flagging in "Not in this file" even when no row went near
        // them, because whichever one the admin ticks they are guessing.
        var crowdedKeys = Set(rowsByKey.lazy.filter { $0.value.count > 1 }.map(\.key))
        crowdedKeys.formUnion(kidsByKey.lazy.filter { $0.value.count > 1 }.map(\.key))

        var partner: [Int: Int] = [:]           // row index → kid index
        var claimedKids: Set<Int> = []

        // The buckets partition `file.indices` and `camp.indices`, so no two of them can reach the
        // same row or the same kid and the order they are visited in cannot change the outcome.
        for (key, rows) in rowsByKey {
            // Claimed kids are taken out of `free` rather than tested against a set, so each pass
            // walks a shrinking list — the difference between four scans of a whole bucket and one.
            var free = kidsByKey[key] ?? []

            func sameStrictKey(_ row: Int, _ kid: Int) -> Bool {
                guard let strict = rowKeys[row].strict else { return false }
                return strict == kidKeys[kid].strict
            }
            func sameAge(_ row: Int, _ kid: Int) -> Bool {
                guard let rowAge = file[row].age, let kidAge = camp[kid].age else { return false }
                return rowAge == kidAge
            }
            /// One pass: every still-unpartnered row, in file order, takes the first unclaimed kid
            /// it is allowed to have. Both are consumed, so nobody is matched twice.
            func claim(where isEligible: (Int, Int) -> Bool) {
                for row in rows where partner[row] == nil {
                    guard let slot = free.firstIndex(where: { isEligible(row, $0) }) else { continue }
                    let kid = free.remove(at: slot)
                    partner[row] = kid
                    claimedKids.insert(kid)
                }
            }

            // Four passes, most specific first. The whole surname beats the initial, and within
            // either tier a matching age beats file order — so two camp kids called Liam P are
            // told apart by their ages, and one camp kid with two rows against him goes to the row
            // whose age agrees, wherever that row sits in the file.
            claim { sameStrictKey($0, $1) && sameAge($0, $1) }
            claim { sameStrictKey($0, $1) }
            claim { sameAge($0, $1) }
            claim { _, _ in true }
        }

        var arriving: [Arrival] = []
        var alreadyHere: [Match] = []
        var changed: [Change] = []
        for index in file.indices {
            guard let kid = partner[index] else {
                arriving.append(Arrival(row: file[index]))
                continue
            }
            let isAmbiguous = crowdedKeys.contains(rowKeys[index].loose)
            if let change = Change(row: file[index], player: camp[kid], isAmbiguous: isAmbiguous) {
                changed.append(change)
            } else {
                alreadyHere.append(
                    Match(row: file[index], player: camp[kid], isAmbiguous: isAmbiguous)
                )
            }
        }

        self.arriving = arriving
        self.alreadyHere = alreadyHere
        self.changed = changed
        self.absent = camp.indices
            .filter { !claimedKids.contains($0) }
            .map { Absence(player: camp[$0], isAmbiguous: crowdedKeys.contains(kidKeys[$0].loose)) }
    }
}

// MARK: - The key

extension RosterReconciliation {

    /// Case, diacritics and width folded, then everything that is not a letter or a digit dropped.
    ///
    /// The same *idea* the app already applies to a header cell in `Columns.init?(header:)` and to
    /// an invite code in `InMemoryRepository.normalise` (`Repository.swift:595`) — reduce a string
    /// people typed to the part of it that carries the meaning — but deliberately not the same
    /// reduction, and the three are not shared for that reason. A header cell keeps its case fold
    /// only and drops digits, because "Age 2" and "Age" are different columns; an invite code
    /// upper-cases, because it is read aloud off a card. This one folds diacritics and width as
    /// well, because "José" and "Jose" are one child and a full-width export is one child too.
    ///
    /// Punctuation is **dropped rather than mapped to a space**, which is what makes "Mary-Jane",
    /// "Mary Jane" and "MaryJane" one child instead of three.
    ///
    /// `locale: nil` is the decision this whole file rests on; the reasoning is in the header.
    static func fold(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    /// The two keys one person is filed under.
    private struct Keys {
        /// `serene|chu` — nil for anybody with no surname at all, on either side.
        let strict: String?
        /// `serene|c`, and `serene|` for somebody the roster knows by one name.
        let loose: String
    }

    /// - Parameter initial: `Player.lastInitial`, which is all 100 of the camp's seeded rows hold.
    ///   Defaulted away for a file row, which has no initial of its own: a file writes whole
    ///   surnames or nothing.
    private static func keys(first: String, surname: String?, initial: String = "") -> Keys {
        let given = fold(first)
        let family = fold(surname ?? "")
        let mark = family.first ?? fold(initial).first
        return Keys(
            strict: family.isEmpty ? nil : "\(given)|\(family)",
            loose: "\(given)|\(mark.map(String.init) ?? "")"
        )
    }
}

// MARK: - What counts as changed

extension RosterReconciliation {

    /// The file written onto the kid. **One rule over four fields: a nil on the file side is
    /// silence, never an instruction** — and this is the only place that rule lives.
    ///
    /// | field         | written when                                   | never                          |
    /// |---------------|------------------------------------------------|--------------------------------|
    /// | `age`         | file age *legal* and differs (incl. nil → 13)   | a nil file age clears an age   |
    /// | `gender`      | file gender non-nil and differs                 | a nil file gender writes `.x`  |
    /// | `isReturning` | file value non-nil and differs                  | a file with no column flips it |
    /// | `lastName`    | file surname *legal* and differs as a name      | a blank cell clears a surname  |
    ///
    /// Everything the file did not speak to is carried across untouched — including venue, court
    /// and both ranks.
    ///
    /// **A value the column would refuse counts as silence**, which is what `PlayerRules.age` and
    /// `PlayerRules.surname` do here. An age of 25 or a surname of 200 characters is not a change
    /// to offer: `commit` deliberately does not drop rows with an open `IntakeIssue`, so proposing
    /// one would put a pre-ticked line on the review screen whose only possible outcome is
    /// `updatePlayers` failing at the CHECK — and taking the other forty legitimate updates in the
    /// same batch down with it. The row still appears under "Needs a detail" with its Fix button,
    /// which is where the reader can actually do something about it.
    ///
    /// **Gender is read off `IntakePlayer.gender` directly and never off `asPlayer().gender`.**
    /// `asPlayer()` maps a nil to `.x` (`IntakeRoster.swift:83`) because `Player.gender` cannot be
    /// nil — and `.x` is *also* a real answer, the "Other" chip on `8e`. Going through `asPlayer()`
    /// would make every file with a blank gender column propose turning every girl into an X, and
    /// `RosterSelection.opening(for:)` would arrive with all of it pre-ticked.
    private static func applying(_ row: IntakePlayer, to player: Player) -> Player {
        var player = player
        if let age = PlayerRules.age(row.age) { player.age = age }
        if let gender = row.gender { player.gender = gender }
        if let isReturning = row.isReturning { player.isReturning = isReturning }

        // "Differs" means differs *as a name*, folded exactly as the key is. Rejected alternative:
        // an exact string comparison, which makes every weekly re-import propose recapitalising
        // surnames it already agrees with — "Chu" → "CHU" — pre-ticked, for no information at all.
        if let surname = PlayerRules.surname(row.lastName), fold(surname) != fold(player.lastName ?? "") {
            player.lastName = surname
            // The initial is derived beside the surname rather than left behind it, exactly as
            // `IntakePlayer.asPlayer()` derives it (`IntakeRoster.swift:80`). A kid who reads
            // "Serene C" everywhere the surname is missing must not go on reading "Serene C" once
            // it is filled in.
            player.lastInitial = surname.first.map { String($0).uppercased() } ?? player.lastInitial
        }
        return player
    }

    /// What changed, in the words the review screen draws — read off the patched kid rather than
    /// off the row, so there is no second copy of the four rules above to fall out of step with
    /// them. A plain `!=` per field is exact here precisely because `applying` already refused to
    /// write anything the file did not say.
    private static func differences(from player: Player, to updated: Player) -> [FieldChange] {
        var fields: [FieldChange] = []

        if updated.age != player.age {
            fields.append(FieldChange(field: .age, before: player.ageLabel, after: updated.ageLabel))
        }
        if updated.gender != player.gender {
            fields.append(
                FieldChange(field: .gender, before: player.gender.label, after: updated.gender.label)
            )
        }
        if updated.isReturning != player.isReturning {
            fields.append(
                FieldChange(
                    field: .isReturning,
                    before: returnLabel(player.isReturning),
                    after: returnLabel(updated.isReturning)
                )
            )
        }
        if updated.lastName != player.lastName {
            fields.append(
                FieldChange(field: .surname, before: surnameLabel(player), after: surnameLabel(updated))
            )
        }
        return fields
    }

    /// Not "New" for `false`, though the counts card on `8d` uses that word: on the review screen
    /// "New" already names the bucket of kids who are not at the camp yet, and a Changed row
    /// reading `New → Returning` would be pointing at the wrong thing.
    private static func returnLabel(_ isReturning: Bool) -> String {
        isReturning ? "Returning" : "First time"
    }

    /// What the camp holds by way of a surname today: the whole thing, else the initial it was
    /// written down as, else the absence said out loud.
    private static func surnameLabel(_ player: Player) -> String {
        if let surname = player.lastName, !surname.isEmpty { return surname }
        return player.lastInitial.isEmpty ? "No surname" : player.lastInitial
    }
}
