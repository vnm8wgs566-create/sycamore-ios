//
//  OnboardingTokens.swift
//  Sycamore
//
//  What the getting-in screens draw that the shared palette and geometry have no name for.
//
//  The amber family moved to `Theme` (it is section 8's third severity step and three screens
//  outside this branch reach for it), so what is left here is genuinely local: two green-greys
//  that appear once each on `8u`, one grey the palette only names as a rule, the corner radius
//  section 8 draws its cards at, the two gaps its scroll views run on, and the dozen measurements
//  `8b` draws its "No venues yet" state at.
//
//  They live beside the screens rather than in `Theme`/`Radius`/`Spacing` on purpose. This branch
//  owns five of section 8's twenty-one screens; dropping tokens into the files every feature
//  reads makes them the merge conflict for the whole section. Hoist them once section 8 lands —
//  the radius especially, because *every* card in the section is 16 and the shared `Radius.card`
//  still reads 17 from the design this app shipped with.
//
//  Light values are the design's, unchanged. Dark values are derived the way `Theme` derives its
//  own: the hue holds and the text end brightens far enough to clear 4.5:1 on a near-black card.
//

import SwiftUI

enum OnboardingTheme {

    /// `#5C7A68` — the role line under the camp you are signed in to on `8u` ("Worker · Sycamore,
    /// Court 3"). A green-grey rather than `inkMuted`: it sits inside the accent-bordered card
    /// that marks the camp you are standing in, and the design tints the copy to match the border.
    static let currentCampRole = Color(light: "5C7A68", dark: "9CBCA9")

    /// `#7FA895` — "You become its first admin" under `8u`'s "Start a camp".
    ///
    /// Not `Theme.accentSubtle` (`#8FC2A5`), which is the same line drawn on a *filled* accent
    /// button. This one sits on white inside the dashed card, so the design takes it a step darker.
    static let startCampSubtitle = Color(light: "7FA895", dark: "6E9A87")

    /// `#F4F5F7` — the 34pt plate `8c` sits its "add a player by hand" glyph on.
    ///
    /// Aliased rather than spelled out: the palette already carries this value as `hairlineFaint`,
    /// where it means a list rule. Naming the role here keeps the feature hex-free and makes the
    /// collision visible — if the two ever need to move apart, this is the line that splits.
    static let iconPlate = Theme.hairlineFaint
}

enum OnboardingMetrics {

    /// `border-radius:16px` — every card in section 8. `Radius.card` is 17, from the design this
    /// app shipped with, and `Radius.button` is 16 by coincidence of role rather than of intent.
    static let cardRadius: CGFloat = 16

    /// The `gap:13px` between blocks in `8b`'s and `8u`'s scroll views.
    static let blockGap: CGFloat = 13

    /// The `gap:9px` between cards in `8c`'s, `8d`'s and `8e`'s.
    static let cardGap: CGFloat = 9

    /// The 10pt `8b` and `8u` leave under the last thing in the column, on top of whatever the
    /// safe area asks for.
    static let contentBottom: CGFloat = 10

    /// `height:52px` — every call to action in these five screens. Shorter than the 56 the
    /// stage-1 screens use, because these sit on a scrolling form rather than at the foot of a
    /// full-bleed page.
    static let ctaHeight: CGFloat = 52

    /// `bottom:20px` — the pinned call to action's clearance, measured from the safe area rather
    /// than from the glass so the home indicator never sits under it.
    static let ctaInset: CGFloat = 20

    /// `padding-bottom:88px` — what a scroll view leaves so its last row clears the call to
    /// action floating over it on `8d` and `8e`.
    static let ctaClearance: CGFloat = 88

    /// How far a 28pt control has to grow to reach the 44pt minimum touch target: `(44 - 28) / 2`.
    /// Spent as padding that is added and then taken away again, so nothing moves on screen.
    static let stepperHitInset: CGFloat = 8

    /// How much of the frame `8b`'s venue editor takes.
    ///
    /// Screen 11's own sheet is `612/700` and it draws four blocks; this one draws five — the same
    /// name, icon and limits blocks, plus a call to action and a way to take the venue back off
    /// the list — and its limits card carries a keyboard-summoning field on two of its three rows.
    /// 0.90 is what clears the last of those with the keyboard up.
    ///
    /// Here rather than on `ActiveSheet.detentFraction`, which is a property of a slot this sheet
    /// does not occupy: `MainTabView` presents `ActiveSheet` (`RootView.swift:95`) and is not
    /// mounted while `store.camp == nil`. `BlockEditorSheet.swift:31-33` gives the same reasoning
    /// for its own.
    static let venueEditorDetent: Double = 0.90

    // MARK: `8b` — no venues yet
    //
    // Transcribed from `design/Sycamore 3a System.dc.html`, the frame captioned "Shape the camp"
    // and labelled `Shape the camp — empty`. The mark, its glyph, the button and the side padding
    // are the same four numbers `8f` and `8g` are already built from — `ScheduleMetrics.emptyMark`
    // / `emptyMarkGlyph` / `emptyCtaHeight` / `emptyPaddingHorizontal` and `GroupsMetrics.lockDisc`
    // / `lockGlyph` / `lockedActionHeight` / `lockedPaddingHorizontal` are all 52, 24, 50 and 20 —
    // so the composition is a house style even though each frame sets its own vertical padding and
    // its own cap on the copy.

    /// `gap:11px` between the three things the empty state is made of. Tighter than the 13
    /// `blockGap` the answered screen runs on, because these three are one argument rather than
    /// three separate answers.
    static let emptyStateGap: CGFloat = 11

    /// `padding:28px 20px 24px` inside the dashed "No venues yet" plate. The horizontal 20 is
    /// also what the footnote under the card is inset by (`padding:6px 20px 0`) — one measurement
    /// drawn twice in one state of one screen, rather than two that happen to agree.
    static let emptyPaddingTop: CGFloat = 28
    static let emptyPaddingHorizontal: CGFloat = 20
    static let emptyPaddingBottom: CGFloat = 24

    /// `52` / `24` — the plate the map pin sits on, and the pin.
    static let emptyMark: CGFloat = 52
    static let emptyMarkGlyph: CGFloat = 24
    /// `border-radius:17px` on that plate.
    ///
    /// The same number as `Radius.card` and deliberately not that token, because the two are about
    /// to disagree: this file's own header says the shared radius "still reads 17 from the design
    /// this app shipped with" and is to be taken to 16 when section 8 lands, since *every card* in
    /// the section is 16. This is a 52pt tile rather than a card, and the design draws it at 17
    /// either way — so borrowing the card's corner would move this plate on a day nobody meant to.
    static let emptyMarkRadius: CGFloat = 17

    /// `margin-top:15px` — the drop from the plate to "No venues yet".
    static let emptyTitleGap: CGFloat = 15
    /// `margin-top:8px` — from that heading to the sentence under it.
    static let emptyBodyGap: CGFloat = 8
    /// `max-width:272px` — how wide that sentence runs before it wraps. The design caps it well
    /// short of the plate so it stays a paragraph rather than a banner.
    static let emptyCopyWidth: CGFloat = 272
    /// `margin-top:20px` — the drop to "Create your first venue".
    static let emptyCtaGap: CGFloat = 20
    /// `height:50px` — two points shorter than the "Save the shape" this state stands in for.
    static let emptyCtaHeight: CGFloat = 50

    /// `padding:13px 14px 0` around "WHAT A VENUE HOLDS", which is the one section heading on
    /// this screen the design puts *inside* the card rather than above it.
    static let holdsHeaderTop: CGFloat = 13
    static let holdsRowInset: CGFloat = 14
    /// `font-size:16px` — the grey glyph at the head of each of that card's three rows.
    static let holdsRowGlyph: CGFloat = 16
    /// The column that glyph is centred in.
    ///
    /// The design's Phosphor glyphs are all exactly one em wide, so its three rows of copy share a
    /// left edge for free; SF Symbols are not, and `person.3` is half again as wide as
    /// `square.split.2x2`. Pinning the column is what keeps the three lines aligned — the same fix
    /// `SettingsRow.swift:81-83` makes, and 24 is what the widest of these three needs at 16.
    static let holdsRowSlot: CGFloat = 24
}

extension TypeStyle {

    /// `400 25/1.15 Newsreader`, `-.02em` — "No venues yet".
    ///
    /// Section 8 sets its empty-state headings at two sizes and the app only had the smaller.
    /// `8f`, `8g` and `8h` draw 24 ("Friday is empty.", "Groups open at eight kids.", "All
    /// clear."), which is `TypeStyle.profileName` and what `ScheduleType.emptyHeading` and
    /// `GroupsType.lockedHeading` already alias. `8b` and `8c` draw 25 ("No venues yet", "Drop the
    /// sign-up list"). One point is a real difference in this table — `intakeTitleSm` (32) sits
    /// beside `title1` (31) for the same reason — so this is a row rather than a rounding.
    ///
    /// It belongs in `IntakeTypeStyles.swift` beside its thirty siblings, and being written here
    /// buys nothing but a smaller merge: a `static` on `TypeStyle` is visible app-wide whichever
    /// file declares it, so unlike `OnboardingMetrics` this is not *contained* by living in a
    /// tokens file. It is here because that file is not this branch's to touch and this one is,
    /// which is a boundary between two files in one folder rather than a design. Move it across
    /// when section 8 lands; nothing but the file it is typed into has to change.
    ///
    /// Deliberately not `OnboardingType.emptyHeading`, the shape `ScheduleType`, `GroupsType` and
    /// `InboxType` use — that *would* be contained, and it would put a second naming scheme in a
    /// folder where thirty type styles are already reached as `.intakeSomething`.
    static let intakeEmptyHeading = TypeStyle(size: 25, weight: .regular, trackingEm: -0.02,
                                              lineHeightMultiple: 1.15, isSerif: true)
}

enum OnboardingShadows {

    /// `0 12px 30px rgba(26,127,85,.24)` — the lift under the pinned CTA on `8d` and `8e`.
    ///
    /// Tinted with the accent rather than cast in black, which is what the design draws: the
    /// button floats over scrolling content and the green halo is what separates it from the
    /// rows sliding underneath. CSS blur is roughly twice SwiftUI's, so 30 becomes 15.
    static let pinnedCTA = ShadowToken(color: Theme.accent.opacity(0.24), radius: 15, y: 12)
}
