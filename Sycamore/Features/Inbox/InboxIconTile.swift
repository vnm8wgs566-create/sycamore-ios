//
//  InboxIconTile.swift
//  Sycamore
//
//  The 34pt rounded tile that opens every row on `8r` and `8h`.
//
//  `inbox_items` carries no glyph column, so the symbol and the tint are derived from what the
//  row actually references — a kid, a court, the person who asked. That is a real constraint
//  rather than a shortcut: an icon stored per row would be a second place the meaning of an
//  item lives, and the two would drift the first time a kind was added.
//

import SwiftUI

struct InboxIconTile: View {

    let systemName: String
    var tint: InboxTint = .neutral

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .fill(tint.tile)
            .frame(width: InboxMetrics.iconTile, height: InboxMetrics.iconTile)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: InboxMetrics.iconGlyph, weight: .medium))
                    .foregroundStyle(tint.glyph)
            }
            // Decoration. The row's title and detail already say what this is a picture of.
            .accessibilityHidden(true)
    }
}

// MARK: - Deriving the glyph

extension InboxIconTile {

    /// The tile for an item, read off the fields it fills in.
    ///
    /// - A `needsAction` naming a player is a move — somebody wants a kid on another court.
    ///   One that names no player is a hole in the roster, which is the amber case.
    /// - A `note` against a court is a court note; a note against nothing is pinned to the
    ///   whole camp, which is what the design draws the green pin for.
    /// - An `activity` with a player but no actor is a standing arrangement about that kid
    ///   (an early pick-up) rather than something a coach just did, so it keeps the amber
    ///   clock. With an actor it is somebody's action, and with neither it is camp-wide.
    ///
    /// `isCleared` forces grey: a row on `8h`'s cleared list is history, whatever it was.
    init(for item: InboxItem, isCleared: Bool = false) {
        let (symbol, tint) = Self.appearance(for: item)
        self.systemName = symbol
        self.tint = isCleared ? .neutral : tint
    }

    private static func appearance(for item: InboxItem) -> (String, InboxTint) {
        switch item.kind {
        case .needsAction:
            item.playerID != nil
                ? ("arrow.up", .accent)
                : ("person.crop.circle.badge.questionmark", .warning)

        case .note:
            item.groupID != nil
                ? ("note.text", .neutral)
                : ("pin.fill", .accent)

        case .activity:
            if item.playerID != nil, item.actorID == nil {
                ("clock", .warning)
            } else if item.playerID != nil {
                ("person.badge.minus", .neutral)
            } else {
                ("checkmark.circle", .neutral)
            }
        }
    }
}

// MARK: - Previews

#Preview("Icon tiles") {
    HStack(spacing: Spacing.medium) {
        InboxIconTile(systemName: "arrow.up", tint: .accent)
        InboxIconTile(systemName: "person.crop.circle.badge.questionmark", tint: .warning)
        InboxIconTile(systemName: "note.text", tint: .neutral)
        InboxIconTile(systemName: "pin.fill", tint: .accent)
        InboxIconTile(systemName: "clock", tint: .warning)
    }
    .padding(Spacing.section)
    .background(Theme.surface)
}
