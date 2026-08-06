//
//  ScheduleTokens.swift
//  Sycamore
//
//  The tokens section 8's Schedule screens need that the shared design system does not carry
//  yet. Local to this folder on purpose — `Theme.swift` is the file every feature touches, and
//  the four screens of section 8 are being built at the same time.
//
//  Everything here is transcribed from `8k` / `8l` exactly as `Theme.swift` transcribes the
//  rest: the light column is the design, the dark column is derived from it. Hoist any of it
//  the moment a second feature wants it.
//

import SwiftUI

// MARK: - Colour

enum ScheduleTheme {

    /// `#B67A16` — the amber section 8 reserves for the one row on the screen that is somebody's
    /// problem right now ("Needs a coach"). Deliberately not `Theme.danger`: a court without a
    /// coach is work to do, not a failure, and the red is what the app spends on destruction.
    ///
    /// Lightened in the dark, where `B67A16` on `1C1C1E` measures 3.4:1 and this metadata line
    /// is drawn at 13.5pt — small text, which needs 4.5:1.
    static let warning = Theme.warning

    /// `#3F4A44` — the ink a note is written in. A green-shifted grey rather than the neutral
    /// ramp, because a note always sits on or beside the green.
    static let noteInk = Color(light: "3F4A44", dark: "C2CFC8")

    /// `#F6FAF7` — the plate a pinned note sits on, and the tile behind a day shape's glyph.
    /// A step lighter than `Theme.accentTint`, which section 8 spends on filled banners.
    static let noteTint = Color(light: "F6FAF7", dark: "18261E")

    /// `#E4EDE7` — that plate's border.
    static let noteTintBorder = Color(light: "E4EDE7", dark: "26382D")
}

// MARK: - Geometry

enum ScheduleMetrics {

    /// `16` — section 8 draws its cards a point tighter than `Radius.card`.
    static let cardRadius: CGFloat = 16
    /// `14` — the padding inside a block card, and the gutter either side of `8l`'s CTA.
    static let cardPadding: CGFloat = 14
    /// `14` — the gap between the day chips' rule and the first block.
    static let listTop: CGFloat = 14
    /// `18` — the drop from a white header block's last line to its rule.
    static let headerBottom: CGFloat = 18
    /// `9` — the gap between two blocks.
    static let blockGap: CGFloat = 9
    /// `52` — the time gutter running down the left of the day.
    static let timeColumn: CGFloat = 52
    /// `15` — how far the gutter time drops so it sits on the card's title.
    static let timeBaseline: CGFloat = 15
    /// `4` — the inset on the rows that carry no card of their own.
    static let rowInset: CGFloat = 4
    /// `30` — the avatar in "Who is where".
    static let assigneeAvatar: CGFloat = 30
    /// `34` — the tinted tile behind a day shape's glyph on `8f`.
    static let shapeTile: CGFloat = 34
    /// `52` — the watermark on an empty day.
    static let emptyMark: CGFloat = 52
    /// `250` — how wide the sentence under it is allowed to run before it wraps. The design
    /// caps it well short of the card so the copy stays a paragraph rather than a banner.
    static let emptyCopyWidth: CGFloat = 250
    /// `52` — the height of section 8's call to action ("Take attendance", "Add the first
    /// block"), which sits a little under the 56 the stage-1 screens use.
    static let ctaHeight: CGFloat = 52
    /// `7` — the dot beside "On now".
    static let statusDot: CGFloat = 7
}

// MARK: - Shadow

enum ScheduleShadows {

    /// `0 8px 22px rgba(26,127,85,.08)` — the lift under the block that is running now.
    ///
    /// Built from `Theme.accent` rather than from the design's literal `rgba(26,127,85,…)` so
    /// the glow follows the accent into the dark scheme. It is a *tint*, not a cast shadow —
    /// see `Shadows.cast` for why the ordinary ones are pinned to black instead.
    static let currentBlock = ShadowToken(color: Theme.accent.opacity(0.08), radius: 11, y: 8)

    /// `0 12px 30px rgba(26,127,85,.24)` — under `8l`'s "Take attendance".
    static let cta = ShadowToken(color: Theme.accent.opacity(0.24), radius: 15, y: 12)
}

// MARK: - Type

/// Section 8's own type scale. It runs lighter than the rest of the app — titles are 600 where
/// `Sycamore Flow` sets them at 800 — so these are separate styles rather than tweaks to the
/// shared table, which every other screen is still drawn from.
enum ScheduleType {

    /// `400 13` — the time beside a block.
    static let blockTime = TypeStyle(size: 13, weight: .regular)
    /// `600 13` — the time beside the block running now.
    static let blockTimeNow = TypeStyle(size: 13, weight: .semibold)
    /// `600 16`, `-.03em` — a block's title.
    static let blockTitle = TypeStyle(size: 16, weight: .semibold, trackingEm: -0.03)
    /// `600 17`, `-.03em` — the title of the block running now, a point larger.
    static let blockTitleNow = TypeStyle(size: 17, weight: .semibold, trackingEm: -0.03)
    /// `400 13.5` — a block's grey second line, and `8l`'s "9:00am – 10:30am · Courts 1–3".
    static let blockDetail = TypeStyle(size: 13.5, weight: .regular)
    /// `400 12.5` — the note line under a block's rule, and the `+2` beside it.
    static let noteLine = TypeStyle(size: 12.5, weight: .regular)
    /// `500 12.5` — a pinned note, which is written a shade heavier than a counted one.
    static let pinnedNote = TypeStyle(size: 12.5, weight: .medium)
    /// `600 10.5`, `+.14em`, uppercase — "YOUR COURT".
    static let cardOverline = TypeStyle(size: 10.5, weight: .semibold, trackingEm: 0.14, isUppercased: true)
    /// `600 19`, `-.035em` — "Court 1 – Skills rotation".
    static let courtTitle = TypeStyle(size: 19, weight: .semibold, trackingEm: -0.035)
    /// `400 13` — "8 players · rotate at 10:30am".
    static let courtMeta = TypeStyle(size: 13, weight: .regular)
    /// `600 13.5` — the "Open" badge on the court card.
    static let courtBadge = TypeStyle(size: 13.5, weight: .semibold)
    /// `600 14`, `-.02em` — a person's name in "Who is where".
    static let assigneeName = TypeStyle(size: 14, weight: .semibold, trackingEm: -0.02)
    /// `400 12.5` — their role, and the court they are on.
    static let assigneeMeta = TypeStyle(size: 12.5, weight: .regular)
    /// `500 13.5` — "3 notes on this block".
    static let notesRow = TypeStyle(size: 13.5, weight: .medium)
}
