//
//  PinnedMessage.swift
//  Sycamore
//
//  The one rule about what a pinned message may say.
//
//  `inbox_items.title text not null check (char_length(title) between 1 and 120)`. A pinned
//  message *is* that column — `AppStore.addPinnedMessage` puts the composer's text straight into
//  `title` and fills the rest in itself — so the composer has to mirror the CHECK or an over-long
//  message passes every gate on the device and fails at `insert`, after the keyboard has already
//  gone down and the words are no longer in front of anybody.
//
//  Modelled on `CampName` (`Models.swift`), which is the same rule in the same shape for
//  `camps.name`. It is not written *beside* `CampName` because every screen in section 8 is being
//  built at once and `Models.swift` is the file every feature conflicts in; the two belong
//  together once the section lands.
//

import Foundation

enum PinnedMessage {

    /// The CHECK, in Swift.
    static let lengthLimits = 1...120

    /// Counted through `CharLength`, which counts the way Postgres does.
    ///
    /// Deliberately a refusal rather than a truncation. `CampName` validates rather than trims,
    /// and a composer that silently swallowed the end of a sentence would be worse than one that
    /// declines to send it: the words stay on screen where their author can see which to cut.
    static func isValid(_ trimmed: String) -> Bool {
        CharLength.of(trimmed, fits: lengthLimits)
    }

    /// What the composer will actually store.
    ///
    /// A message is not its surrounding whitespace, and the column's CHECK counts every character
    /// it is given — so `"  net is loose  "` spends four of its hundred and twenty on nothing.
    /// Newlines as well as spaces, unlike `CampDraft.trimmedName`: the field is single-line and
    /// cannot be typed into with a return, but it can be pasted into with one.
    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How far past the limit a draft is, or zero. Drawn under the field, so the number the
    /// reader is asked to cut is the same number this rule is measuring.
    static func overrun(_ trimmed: String) -> Int {
        CharLength.overrun(trimmed, over: lengthLimits.upperBound)
    }
}
