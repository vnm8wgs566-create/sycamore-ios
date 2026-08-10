//
//  PlayerMoveTargetsTheGroupTests.swift
//  SycamoreTests
//
//  What `8q`'s move path calls the thing it is moving a kid into.
//
//  The Groups tab titles its cards "Group N" (`GroupCard.swift:63`). The move path used to speak
//  courts on both halves — a bar reading "Move to another court" over a picker listing
//  `Group.label`'s "Court 1 … Court 12" — so the two screens most likely to be open in the same
//  minute had two names for one row. Both halves say group now.
//
//  The bar's own words are a literal in a `View` and are not testable without inspecting a
//  hierarchy; what *is* derived, and what these pin, is the picker's rows. Three claims:
//
//      the sentence     -> a row reads "Group N", the same sentence `GroupCard` titles a card with
//      the source      -> the N comes off `Group.number` and off nothing else — not the label, not
//                          the row's position, not `rankOrder`
//      and VoiceOver   -> hears the same word the row shows, because both come from one property
//
//  The middle one is the load-bearing claim, and it is the one nothing on screen would report. A
//  picker numbering its rows off `Group.label` reads correctly on a tennis camp nobody has renamed
//  and only goes wrong on a swim club, or on the day somebody edits a court's name; one numbering
//  off position or `rankOrder` only goes wrong after a coach reorders the ladder. Both are
//  perfectly good-looking pickers that disagree with the Groups tab.
//
//  `PlayerCourtPickerTests` is next door and owns the rest of the list — what is on it, which row
//  is ticked, and what the flags say. This file is only about the name.
//

import Foundation
import Testing
@testable import Sycamore

// MARK: - Fixtures

private enum MoveTarget {

    /// Two venues of three groups each, four kids, all four parked on the first venue's first
    /// group. Ceilings set by hand for the same reason `PlayerCourtPickerTests` sets them: the
    /// fixture derives one from `playerMax / groupCount`, which is 999/3 and reads as noise in an
    /// asserted sentence.
    static func camp(groupsEach: Int = 3, ceiling: Int = 4) -> Camp {
        var camp = Fixture.camp(
            [Fixture.VenueSpec("Sycamore", courts: groupsEach), Fixture.VenueSpec("LATC", courts: groupsEach)],
            players: 4
        )
        for index in camp.groups.indices {
            camp.groups[index].capacity = ceiling
        }
        camp.reindex()
        return camp
    }

    static func kid(_ camp: Camp) -> Player { camp.orderedPlayers[0] }

    static func choices(_ camp: Camp) -> PlayerCourtChoices {
        PlayerCourtChoices(for: kid(camp).id, in: camp)
    }

    /// Every row the picker would draw, in the order it would draw them, name only.
    static func rows(_ camp: Camp) -> [String] {
        choices(camp).courts.map(\.label)
    }

    /// The sentence the Groups tab titles a card with — `GroupCard.swift:63`, written out here
    /// rather than called.
    ///
    /// `GroupCard.title` is `private` on a `View`, so it is `@MainActor` and unreachable besides.
    /// Copying the sentence into a test is the thing this file exists to catch, which is why it is
    /// copied *once*, in a helper named for where it came from: if the two ever part, the failure
    /// lands on a line that says whose sentence this is.
    static func groupsTabTitle(_ group: Group) -> String { "Group \(group.number)" }

    /// Every group in the camp, in the order the picker walks them — venues by `sortIndex`, groups
    /// by `rankOrder`.
    static func groupsInPickerOrder(_ camp: Camp) -> [Group] {
        camp.orderedVenues.flatMap { camp.groups(in: $0.id) }
    }
}

// MARK: - The sentence

@Suite("The move screen calls a group what the Groups tab calls it")
struct PlayerMoveRowNameTests {

    /// The whole change, stated against the Groups tab's own formula rather than against a list of
    /// strings this file made up. A picker that started saying "Band 1" would fail here even if
    /// somebody updated the literals below it.
    @Test("Every row is titled the way Groups titles the same card")
    func rowsMatchTheGroupsTab() {
        let camp = MoveTarget.camp()

        #expect(
            MoveTarget.rows(camp) == MoveTarget.groupsInPickerOrder(camp).map(MoveTarget.groupsTabTitle)
        )
    }

    /// And the same claim written out, because a test that only compares two derivations passes
    /// happily when both are wrong in the same direction.
    @Test("Which reads Group 1, Group 2, Group 3 at each venue")
    func rowsReadAsWritten() {
        let camp = MoveTarget.camp()

        #expect(
            MoveTarget.rows(camp) == [
                "Group 1", "Group 2", "Group 3",
                "Group 1", "Group 2", "Group 3",
            ]
        )
    }

    /// The numbering restarts at every venue, so the list carries two "Group 1"s and the section
    /// header is the only thing between them. True of `Group.label` before and no less true of
    /// `Group.number` — `syncGroups` counts from one per venue (`Models.swift:1592-1598`).
    @Test("Both venues open at Group 1, and the section is what tells them apart")
    func bothVenuesOpenAtGroupOne() {
        let camp = MoveTarget.camp()
        let choices = MoveTarget.choices(camp)

        let first = choices.sections[0].courts[0]
        let second = choices.sections[1].courts[0]

        #expect(first.label == "Group 1")
        #expect(second.label == "Group 1")
        #expect(first.id != second.id)
        #expect(choices.sections[0].title == "Sycamore")
        #expect(choices.sections[1].title == "LATC")
    }
}

// MARK: - Where the numeral comes from

@Suite("The row is numbered from Group.number and from nothing else")
struct PlayerMoveRowSourceTests {

    /// **The test the brief asks for.** A venue that renames its courts — a club that calls them
    /// pitches, a swim camp on lanes, anybody who edits a name — must not change what the move
    /// screen calls a group. Every label in the camp is rewritten here and not one row moves.
    @Test("Renaming every court changes nothing on the move screen")
    func renamedCourtsChangeNothing() {
        var camp = MoveTarget.camp()
        let before = MoveTarget.rows(camp)

        for index in camp.groups.indices {
            camp.groups[index].label = "Lane \(index + 90)"
        }

        #expect(MoveTarget.rows(camp) == before)
        #expect(MoveTarget.rows(camp).allSatisfy { $0.hasPrefix("Group ") })
    }

    /// `Group.label` is left alone by all of this, which is the other half of the decision: it is
    /// still the sport's noun for the place a group plays on, and Attendance, Overview and Schedule
    /// still read it. A pass that "fixed" the divergence by rewriting the model would break those.
    @Test("Group.label still names the place, untouched")
    func theLabelStillNamesThePlace() {
        let camp = MoveTarget.camp()

        #expect(camp.sport == .tennis)
        #expect(MoveTarget.groupsInPickerOrder(camp).prefix(3).map(\.label) == ["Court 1", "Court 2", "Court 3"])
    }

    /// Position in the list is not the number either. A camp whose groups are numbered 7, 8, 9 —
    /// which is what a venue trimmed and regrown gets — lists three rows reading Group 7, 8 and 9,
    /// not Group 1, 2 and 3.
    @Test("A group numbered 7 is Group 7, whatever row it is drawn on")
    func theNumberIsNotThePosition() {
        var camp = MoveTarget.camp()
        let sycamore = camp.orderedVenues[0].id

        for group in camp.groups(in: sycamore) {
            guard let index = camp.groups.firstIndex(where: { $0.id == group.id }) else { continue }
            camp.groups[index].number += 6
        }

        #expect(MoveTarget.choices(camp).sections[0].courts.map(\.label) == ["Group 7", "Group 8", "Group 9"])
    }

    /// And `rankOrder` is not the number. The two agree until a coach reorders a venue's ladder,
    /// which is exactly when a picker reading the wrong one starts naming a kid's destination after
    /// the row above or below the one they tapped.
    ///
    /// The order of the list is `rankOrder`'s — that is `groups(in:)`, and every screen agrees on it
    /// — so reversing it reverses the rows. What must not happen is the *names* reversing with
    /// them: each group carries its own number wherever it is drawn.
    @Test("Reordering the ladder moves the rows and does not renumber them")
    func rankOrderMovesRowsWithoutRenamingThem() {
        var camp = MoveTarget.camp()
        let sycamore = camp.orderedVenues[0].id
        let ladder = camp.groups(in: sycamore)

        for (offset, group) in ladder.enumerated() {
            guard let index = camp.groups.firstIndex(where: { $0.id == group.id }) else { continue }
            camp.groups[index].rankOrder = ladder.count - offset
        }

        let section = MoveTarget.choices(camp).sections[0]

        #expect(section.courts.map(\.id) == ladder.reversed().map(\.id))
        #expect(section.courts.map(\.label) == ["Group 3", "Group 2", "Group 1"])
    }
}

// MARK: - And what VoiceOver hears

@Suite("VoiceOver hears the word the row shows")
struct PlayerMoveRowSpokenTests {

    /// A screen that says group and speaks court is worse than one that is merely inconsistent —
    /// the person who cannot see it has no way to notice the mismatch. `spokenLabel` opens with the
    /// same `label` the row draws, so this cannot come apart without the drawn row coming apart
    /// too.
    @Test("The spoken sentence opens with the row's own name")
    func spokenOpensWithTheLabel() {
        let camp = MoveTarget.camp()

        for option in MoveTarget.choices(camp).courts {
            #expect(option.spokenLabel.hasPrefix("\(option.label). "))
        }
    }

    /// The whole sentence, once, so the rename is pinned in the ear as well as the eye. The fill
    /// and the coach are unchanged by any of this — they name no place — and are here to say so.
    @Test("A full group with nobody on it reads Group 1, four of four, full, needs a coach")
    func theWholeSentence() {
        let camp = MoveTarget.camp(ceiling: 4)
        let courts = MoveTarget.choices(camp).courts

        #expect(courts[0].spokenLabel == "Group 1. 4 of 4 kids. Full. Needs a coach")
        #expect(courts[1].spokenLabel == "Group 2. 0 of 4 kids. 4 spots left. Needs a coach")
    }

    /// And it survives a renamed court in the ear too, which is the point of both halves reading
    /// one property.
    @Test("A renamed court is not heard either")
    func renamingIsNotHeard() {
        var camp = MoveTarget.camp()
        for index in camp.groups.indices {
            camp.groups[index].label = "Pitch \(index + 90)"
        }

        #expect(MoveTarget.choices(camp).courts[0].spokenLabel.hasPrefix("Group 1. "))
    }
}
