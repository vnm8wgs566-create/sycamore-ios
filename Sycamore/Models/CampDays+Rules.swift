//
//  CampDays+Rules.swift
//  Sycamore
//
//  The floor under a camp's week, and the two ways the week is read back.
//
//  `CampDays` itself (`Models.swift`) is the mask and the arithmetic: which bit is which day,
//  what `.weekdays` means, and the wrap `openingDay(from:)` does at the end of the week. It has
//  no opinion about who may change it, and `toggle(_:)` there flips a bit unconditionally.
//
//  This is the opinion. A camp with no days is a camp nothing can be scheduled on, and
//  `camps.camp_days` is `check (camp_days > 0 and camp_days <= 127)`
//  (`supabase/migrations/20260809030000_camp_days_and_block_assignment.sql:37-38`) — a CHECK that
//  fires at `insert` or at PATCH, long after the tap that caused it. So the floor is kept here,
//  where every editor has to pass through it, and stated once so the picker that enforces it and
//  the captions that explain it cannot come to disagree.
//
//  A separate file rather than more of `Models.swift`, which four branches are editing this week,
//  and rather than an extension parked beside the picker, which would leave the only legal way to
//  flip a day sitting inside a SwiftUI view.
//

import Foundation

extension CampDays {

    /// This set with `day` flipped, or this set unchanged when flipping it would leave the camp
    /// with no days at all.
    ///
    /// Non-mutating so the rule can be asked as a question rather than only applied — which is
    /// what lets the picker draw the refusal (`toggling(day) == self` means "this tap would do
    /// nothing") instead of deriving a second, parallel test of the same thing.
    func toggling(_ day: Weekday) -> CampDays {
        var next = self
        next.toggle(day)
        return next.isValid ? next : self
    }

    /// Whether the camp is down to the one day the floor keeps.
    ///
    /// Asked of the mask rather than by counting `ordered`, which builds two arrays to answer a
    /// question about bits — this is read once per chip, seven times a pass, on a row that
    /// redraws on every tap. Masked with `everyDay` rather than counted raw so a value from
    /// outside the seven bits answers the same way `isValid` does.
    var isSingleDay: Bool {
        (rawValue & CampDays.everyDay.rawValue).nonzeroBitCount == 1
    }

    /// The week in words: `Every day`, `Mon–Fri`, or the days themselves.
    ///
    /// Two special cases and no general run-collapsing. "Mon–Wed" for `[.mon, .tue, .wed]` would
    /// be right and "Sun–Tue" for `[.sun, .mon, .tue]` would not — the ordering is Monday-first,
    /// so a week that wraps has no contiguous spelling — and a rule with a corner that reads as a
    /// bug is worse than three short names separated by commas.
    var summaryLine: String {
        if self == .everyDay { return "Every day" }
        if self == .weekdays { return "Mon–Fri" }
        // Unreachable through either editor, both of which refuse the empty set, and stated
        // anyway: a `String` has to be something, and "" would draw as a missing subtitle.
        if ordered.isEmpty { return "No days yet" }
        return ordered.map(\.shortName).joined(separator: ", ")
    }

    /// How many days that is — or, at the floor, why it will not go lower.
    ///
    /// The floor's sentence lives here rather than at the two screens that draw it, because both
    /// of them are captioning the *same* refusal and a second wording would make one of them
    /// wrong. It is the one string on this type that exists to explain a rule rather than to
    /// state a fact, which is why it is not simply folded into `summaryLine`: the settings row's
    /// subtitle says what the week is, and only an open editor needs to say what it may not be.
    var countLine: String {
        isSingleDay ? "at least one day" : "\(ordered.count) days a week"
    }
}
