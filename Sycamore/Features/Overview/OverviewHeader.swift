//
//  OverviewHeader.swift
//  Sycamore
//
//  4a's white header block: a venue pill, an avatar, "Overview", and the date.
//
//  ── Why this is not `ScreenHeader` ───────────────────────────────────────────────────────────
//
//  `ScreenHeader` (`ScreenHeader.swift:131-168`) is a title, an optional second line and an avatar
//  in one row — it has no slot for a leading control and never has. 4a puts one *above* the title:
//
//      <div style="display:flex;align-items:center;gap:10px">
//        <div … border-radius:999px;padding:7px 13px>  📍 Sycamore ⌄  </div>
//        <div style="flex:1"></div>
//        <div style="width:34px;height:34px;…">AR</div>
//      </div>
//      <div style="font:400 32px/1.02 Newsreader;…;margin-top:14px">Overview</div>
//      <div style="font:400 13.5px;color:#8A8E96;margin-top:7px">Tuesday, 12 August · day 2 of 5</div>
//
//  That control row is the whole of section 4's inversion — "the header switches the venue; camps
//  live deeper" (`design/rebuild/section-t4.html:48`). It is one screen's header, so it is drawn
//  here rather than by growing a `leading:` slot onto the component the other three tabs share: a
//  slot three callers pass `nil` to is a slot that has to be reasoned about on four screens.
//
//  Everything the two headers agree on is still shared — `ScreenHeaderMetrics` for the block's
//  inset and the avatar's diameter, `TypeStyle.screenHeaderTitle` for the serif line,
//  `InitialsAvatar` for the disc. What is stated locally is exactly what 4a states differently.
//
//  ── The subtitle is the date, not the block ─────────────────────────────────────────────────
//
//  This line used to read "Skills rotation · until 10:30" (`OverviewNow.headerLine`), pinned up
//  here because the scroll runs under the header and it was the copy that still answered "what is
//  on now" once a reader had scrolled past the card. 4a moves the block to a card of its own at the
//  top of the scroll — with a call to action on it — and gives the header the one fact nothing else
//  on the screen carries: which day of the camp's run this is.
//

import SwiftUI

struct OverviewHeader: View {

    /// The venue the screen is reading. Nil draws no pill — a camp with no venues has nothing to
    /// switch between, and an empty capsule is a control that opens an empty sheet.
    var venueName: String?
    /// Whether the sheet the pill opens is showing. 4b draws the pill in its open state and drops
    /// the subtitle underneath it, both of which are this flag.
    var isVenueSheetOpen: Bool = false
    /// `Tuesday, 12 August · day 2 of 5`.
    var dateLine: String?
    var initials: String?
    var onVenueTap: (() -> Void)?
    var onAvatarTap: (() -> Void)?

    private var shownInitials: String? {
        guard let initials, !initials.isEmpty else { return nil }
        return initials
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: OverviewTheme.headerControlGap) {
                if let venueName, let onVenueTap {
                    VenuePill(name: venueName, isOpen: isVenueSheetOpen, action: onVenueTap)
                }

                Spacer(minLength: 0)

                if let shownInitials {
                    avatar(shownInitials)
                }
            }

            Text("Overview")
                .typeStyle(.screenHeaderTitle, color: Theme.ink)
                // Lets the title take a second line at the accessibility text sizes rather than
                // clipping its descenders.
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, OverviewTheme.headerTitleGap)

            // 4b draws no line under the title while its sheet is up. Not decoration: the sheet is
            // asking which venue you are at, and a header still reporting the old venue's day
            // underneath the question is the screen answering itself.
            if let dateLine, !isVenueSheetOpen {
                Text(dateLine)
                    .typeStyle(
                        .screenHeaderSubtitle.size(OverviewTheme.headerSubtitleSize),
                        color: Theme.inkMuted
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, OverviewTheme.headerSubtitleGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, ScreenHeaderMetrics.blockTop)
        // `padding-bottom:16px`, the design's own. `ScreenHeaderMetrics.blockBottom` is 12 because
        // on three of the four tabs a day picker or a chip row follows inside the same white block
        // and supplies the rest (`ScreenHeader.swift:65-68`). Nothing follows here.
        .padding(.bottom, Spacing.large)
        .padding(.horizontal, Spacing.header)
    }

    @ViewBuilder
    private func avatar(_ initials: String) -> some View {
        // `.neutralStrong` — `#EFF0F3` behind `#5C6068`, which is what 4a draws
        // (`design/rebuild/section-t4.html:60`). `ScreenHeader` uses `.neutral`, a step lighter,
        // read off the design that preceded section 4.
        let disc = InitialsAvatar(
            initials, size: ScreenHeaderMetrics.avatarSize, tone: .neutralStrong
        )

        if let onAvatarTap {
            Button(action: onAvatarTap) {
                disc
                    // The disc is drawn at the design's diameter; the frame around it only carries
                    // the tap up to the 44pt minimum.
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your profile")
        } else {
            disc.accessibilityHidden(true)
        }
    }
}

// MARK: - The date line

extension OverviewHeader {

    /// `Tuesday, 12 August · day 2 of 5`.
    ///
    /// A static function over three plain values rather than a computed property on the view, for
    /// the reason this feature applies to `OverviewNow` and `TodayCourts`: it is arithmetic about a
    /// camp and a calendar, and arithmetic lives where a test can reach it.
    ///
    /// **Both halves come off one `Date`.** The weekday is spelled by `Weekday.fullName` and the
    /// numerals by the calendar, and they agree only because the caller passes the date that
    /// `day` was itself derived from — `AppStore.clock.now`. Formatted separately and read off
    /// `.now` in two places, a phone crossing midnight mid-draw could write "Tuesday, 13 August".
    ///
    /// The format is pinned rather than localised, which is the call `TimeOfDay.clockLabel`
    /// (`Models.swift:300-307`) already makes for the camp's clock and for the same reason: the
    /// design writes "12 August" and the weekday beside it is a hard-coded English word already, so
    /// a locale that reordered the numerals would produce "Tuesday, August 12" — half translated.
    ///
    /// The camp-day clause drops when the camp does not run today. `CampDays.dayIndex(of:)` answers
    /// nil there deliberately ("a stale deep link, or a camp whose days were edited while somebody
    /// stood on Thursday"), and the line reads "Tuesday, 12 August" rather than "day 0 of 5".
    /// Nothing prints a middot with nothing after it.
    ///
    /// `nonisolated` because it is a pure composer over three values and touches nothing on the
    /// actor. It inherits `@MainActor` only from `OverviewHeader`'s `View` conformance, and that
    /// inheritance is what `OverviewFixtures.dateLine` (`:221-223`) trips over — a fixture is a
    /// `static var` in a nonisolated enum, so without this the preview data cannot compose the
    /// same line the header does. Isolating the fixture instead would fix the warning by moving
    /// it: the point of that fixture is that it is resolved rather than written out, so it has to
    /// be able to call this.
    nonisolated static func dateLine(for day: Weekday, on date: Date, days: CampDays?) -> String {
        let dated = "\(day.fullName), \(date.formatted(Self.dayAndMonth))"

        guard let days, let index = days.dayIndex(of: day) else { return dated }
        return "\(dated) · day \(index) of \(days.ordered.count)"
    }

    /// `12 August`. `en_GB` orders day before month and spells the month in English, which is what
    /// makes it sit beside `Weekday.fullName` rather than half-translating the line.
    ///
    /// `nonisolated` for `dateLine(for:on:days:)`'s reason, and it has to be: a `static let` on a
    /// `@MainActor` type is main-actor isolated too, so a `nonisolated` function reading it is the
    /// same violation one level down. `Date.FormatStyle` is `Sendable`, so there is nothing to
    /// protect — the isolation was inherited from `View` conformance, not asked for.
    nonisolated private static let dayAndMonth = Date.FormatStyle.dateTime
        .day()
        .month(.wide)
        .locale(Locale(identifier: "en_GB"))
}

// MARK: - The venue pill

/// 4a's venue switcher, and 4b's handle.
///
/// `border:1px solid #E6E7EB;border-radius:999px;padding:7px 13px;gap:6px` around a 13pt map pin in
/// `Theme.accent`, the venue's name at `600 12.5 / -.01em` in `Theme.inkWarm`, and an 11pt caret in
/// `Theme.inkMuted`. Open, it takes 4b's second state: `accentBorder` rule, `accentSurface` fill,
/// `accentDark` label, and the caret flipped and drawn in `Theme.accent`
/// (`design/rebuild/section-t4.html:134`).
///
/// **The venue's name and nothing else.** Not "Sycamore · 4 courts". That line was
/// `OverviewView.venueLine`, drawn under the title on a day with no block running, and 4a retired
/// it: the venue became a control at the top of the header and the court count moved into the sheet
/// behind this pill, where `VenuePickerSheet.meta(for:)` (`VenuePickerSheet.swift:146`) writes
/// "6 courts · 50 kids" against *every* venue at once. `OverviewScreen.venueName`
/// (`OverviewScreen.swift:100-106`) records the same move. A count belongs where somebody is
/// choosing between venues, not inside a pill that has to stay a thumb wide.
///
/// Not `Pill`, which draws a 15/9 capsule with one optional leading glyph and no trailing one, and
/// carries no open state. Three differences on a control drawn once is a component argued into
/// shape for one caller.
///
/// The caret **is** the design system's, and that is not the same argument. `DisclosureChevron`
/// (`Components.swift:50-60`) is an `Image(systemName:)` at a caller's size and colour in
/// `.medium` — which is this caret exactly, symbol and all — and its `systemName` parameter is
/// there so a control that flips its caret can say so. `SetupView.swift:412-413` and
/// `GroupCard.swift:213-214` already pass a toggling symbol through it. What this pill could not
/// borrow was the *capsule*; the glyph inside it was never in dispute.
private struct VenuePill: View {

    let name: String
    let isOpen: Bool
    let action: () -> Void

    /// Both glyphs ride `.caption`, the band the 12.5pt label sits in, so the pill keeps its
    /// proportions as the reader's type grows instead of the pin outgrowing the word.
    @ScaledMetric(relativeTo: .caption) private var pinSize = OverviewTheme.venuePillGlyph
    @ScaledMetric(relativeTo: .caption) private var caretSize = OverviewTheme.venuePillCaret

    var body: some View {
        Button(action: action) {
            capsuleBody
                // Drawn at the design's 7/13; only the frame that takes the tap grows to 44.
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Venue, \(name)")
        .accessibilityHint("Switches which venue this screen is about")
    }

    private var capsuleBody: some View {
        let shape = Capsule(style: .continuous)

        return HStack(spacing: OverviewTheme.venuePillGap) {
            Image(systemName: "mappin")
                .font(.system(size: pinSize, weight: .regular))
                .foregroundStyle(Theme.accent)

            Text(name)
                .typeStyle(OverviewTheme.venuePillLabel, color: isOpen ? Theme.accentDark : Theme.inkWarm)
                .lineLimit(1)

            DisclosureChevron(
                systemName: isOpen ? "chevron.up" : "chevron.down",
                size: caretSize,
                color: isOpen ? Theme.accent : Theme.inkMuted
            )
        }
        // Spoken as one phrase by the button above; the pin and the caret are decoration on a
        // control that already says what it does.
        .accessibilityHidden(true)
        .padding(.horizontal, OverviewTheme.venuePillHorizontal)
        .padding(.vertical, OverviewTheme.venuePillVertical)
        .background(isOpen ? Theme.accentSurface : Theme.surface, in: shape)
        .overlay {
            shape.strokeBorder(
                isOpen ? Theme.accentBorder : Theme.strokeChip, lineWidth: BorderWidth.hairline
            )
        }
    }
}

// MARK: - Previews

#Preview("4a — header") {
    VStack(spacing: 0) {
        OverviewHeader(
            venueName: "Sycamore",
            dateLine: OverviewHeader.dateLine(for: .tue, on: .now, days: .weekdays),
            initials: "AR",
            onVenueTap: {},
            onAvatarTap: {}
        )
        Hairline(color: Theme.hairline)
        Spacer()
    }
    .background(Theme.surface)
}

/// 4b's header: the pill open, and no line under the title.
#Preview("4b — header, sheet open") {
    VStack(spacing: 0) {
        OverviewHeader(
            venueName: "Sycamore",
            isVenueSheetOpen: true,
            dateLine: OverviewHeader.dateLine(for: .tue, on: .now, days: .weekdays),
            initials: "AR",
            onVenueTap: {},
            onAvatarTap: {}
        )
        Hairline(color: Theme.hairline)
        Spacer()
    }
    .background(Theme.surface)
}

#Preview("4a — header, accessibility1") {
    VStack(spacing: 0) {
        OverviewHeader(
            venueName: "Sycamore",
            dateLine: OverviewHeader.dateLine(for: .tue, on: .now, days: .weekdays),
            initials: "AR",
            onVenueTap: {},
            onAvatarTap: {}
        )
        Hairline(color: Theme.hairline)
        Spacer()
    }
    .background(Theme.surface)
    .environment(\.dynamicTypeSize, .accessibility1)
}
