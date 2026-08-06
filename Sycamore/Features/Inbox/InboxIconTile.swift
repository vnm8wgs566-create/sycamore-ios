//
//  InboxIconTile.swift
//  Sycamore
//
//  The 34pt rounded tile that opens every row on `8r` and `8h`.
//
//  `inbox_items` carries no glyph column, so the symbol and the tint are derived from what the
//  row actually references — a kid, a court, the person who asked. That is a real constraint
//  rather than a shortcut: an icon stored per row would be a second place the meaning of an
//  item lives, and the two would drift the first time a kind was added. It is also not free —
//  see the pull request for the two rows the design draws that no field on `InboxItem` can tell
//  apart.
//

import SwiftUI

struct InboxIconTile: View {

    let systemName: String
    var tint: InboxTint = .neutral

    /// The tile is drawn at 34 and the glyph at 16, and both grow with the reader's text size.
    /// A plate that stayed 34pt beside a title set at `.accessibility1` reads as a bullet point
    /// rather than as an icon.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = InboxMetrics.iconTile
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = InboxMetrics.iconGlyph

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .fill(tint.tile)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: glyphSize, weight: .medium))
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
    /// `isCleared` forces the quiet pair: a row on `8h`'s cleared list is history, whatever it
    /// was, and the design drops its glyph a step to say so.
    init(for item: InboxItem, isCleared: Bool = false) {
        let (symbol, tint) = Self.appearance(for: item)
        self.systemName = symbol
        self.tint = isCleared ? .cleared : tint
    }

    private static func appearance(for item: InboxItem) -> (String, InboxTint) {
        switch item.kind {
        case .needsAction:
            item.playerID != nil
                ? ("arrow.up", .accent)
                // `ph-user-circle-dashed`: a person outlined but not filled in, which is exactly
                // what an unassigned court is.
                : ("person.crop.circle.dashed", .warning)

        case .note:
            item.groupID != nil
                ? ("note.text", .neutral)
                : ("pin.fill", .accent)

        case .activity:
            if item.playerID != nil, item.actorID == nil {
                // `ph-fill ph-clock-countdown` — the filled face, because this one is counting
                // down to something rather than reporting a time that has passed.
                ("clock.fill", .warning)
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
        InboxIconTile(systemName: "person.crop.circle.dashed", tint: .warning)
        InboxIconTile(systemName: "note.text", tint: .neutral)
        InboxIconTile(systemName: "pin.fill", tint: .accent)
        InboxIconTile(systemName: "clock.fill", tint: .warning)
        InboxIconTile(systemName: "arrow.up", tint: .cleared)
    }
    .padding(Spacing.section)
    .background(Theme.surface)
}
