//
//  ComingSoonView.swift
//  Sycamore
//
//  The screen the design gives a tab that is not built yet: the block guarded by
//  `<sc-if value="{{ tabIsSoon }}">` in `design/app/regions/showApp.html`. Its copy is
//  `soonMap` in `design/app/state1.js:24-27`, which writes three strings — a title, a serif
//  line and a paragraph — for Overview and for Schedule, and for no other tab.
//
//  It is a *screen*, not a placeholder. The design draws the tab's own header block, then one
//  card that says which tab this is, what will be here, and — through `goGroups`
//  (`state1.js:31`) — the one thing worth doing instead. That last part is the whole reason
//  this is worth building rather than leaving a tab blank: a person who taps Overview on a camp
//  morning and finds nothing has been walked into a dead end, and the design refuses to leave
//  them there. The button is the way back out.
//
//  Deliberately not `ContentUnavailableView`, for the reason `ScheduleEmptyDayHero:8-11`,
//  `GroupsLockedState:76-83` and `VenueEmptyState:24-26` each give for their own: that view is
//  the right shape for an absence nobody can do anything about, and it owns its own spacing —
//  which would mean claiming an exactness this composition does not have. The design draws a
//  specific one: 22 and 18 of padding, then 7, then 8, then 16, over a mark bleeding off the
//  bottom-right corner.
//
//  ── Louder than the design draws it ──────────────────────────────────────────────────────────
//
//  Asked for directly: these two cards were to hold their tabs rather than apologise for them.
//  Four numbers move and one colour, all of them noted at their sites with the design's own
//  figure beside them — headline 24 → `title2`, an existing row, padding 22/18 → 30/20,
//  the three internal gaps up a step, and the hairline frame replaced with `accentBorder` at
//  1.5. Nothing else. In particular the **fill stays white**: `accentSurface` would have taken
//  the paragraph from 4.62:1 to 4.38:1, under AA for 13.5pt, and buying presence by making the
//  screen's only sentence harder to read is not a trade worth making.
//
//  The seed stays exactly as it was — 96pt at 18%, half off the corner. It was the one thing
//  named as already right.
//
//  Deliberately *not* a glyph naming what is missing, which is what the app's other four
//  hand-drawn empty states open with. `ScheduleEmptyDayHero:13-21` argues at length against the
//  ghosted company mark as an empty-state icon, and every word of that argument holds — for an
//  empty Tuesday. It does not transfer here, and the design knows it: what is absent on this
//  screen is not a court or a kid or a block, it is *the feature*, and there is no glyph for a
//  thing that has not been written. So the mark is not the subject at all here. It is a
//  watermark at 18%, behind the copy, half off the corner — the card's texture rather than its
//  icon, and the one honest thing to draw for "we are building this".
//

import SwiftUI

// MARK: - Type
//
// Every row below is a shared `TypeStyle` under this screen's own name, the way `GroupsType`
// and `ScheduleType` alias theirs. The sizes are the design's and are not rounded: 12.5, 24,
// 13.5, 15.

private enum ComingSoonType {

    /// `600 12.5`, `-.01em` — "Coming soon". `metaStrong` is the 600 cut of 12.5; the design
    /// tightens this one line by a hundredth of an em and nothing else in the app asks for that,
    /// so it is nudged here rather than given a row of its own in the table.
    static let overline = TypeStyle.metaStrong.tracking(em: -0.01)

    /// `title2` — the tab-root serif, `400 32/1.02`, `-.022em`. "What is on right now".
    ///
    /// Serif, because in this app serif means *the name of the thing you are looking at* — and
    /// this card's headline is the closest thing the screen has to one.
    ///
    /// **`title2` and not the design's `profileName`, which is a deliberate departure.** The
    /// design sets this line at 24, the same size `8f`, `8g` and `8h` open their empty states
    /// with, and at 24 inside a white card on a white-ish page the whole screen reads as a
    /// hedge — a tab apologising for itself. The instruction was to let these two hold their
    /// tabs confidently, so the headline steps up to the row the app already uses for the
    /// biggest thing on a screen that is not the wordmark: "Which camp?", "New camp".
    ///
    /// A token rather than an invented size, which is why this line did not have to be touched
    /// when the design system re-cut the serif scale underneath it: `title2` was 29 when this was
    /// written and is 32 now, and the card simply grew with the app. A `profileName.size(29)`
    /// would still be 29.
    static let headline = TypeStyle.title2

    /// `400 13.5/1.55` — the paragraph.
    ///
    /// `emptyBody` is the shared row for a paragraph inside an empty-state card and is already
    /// 400 13.5; only the leading differs, `8f`/`8g`/`8h` setting 1.6 where this card sets 1.55.
    /// Half a hundredth of a line is not worth a new row in the table and is worth transcribing
    /// honestly, so it is the shared row with the design's own leading on it.
    static let body = TypeStyle.emptyBody.lineHeight(1.55)

    /// `600 15`, `-.015em` — "Go to Groups". `buttonSmall` is the 600 cut of 15; the design
    /// tracks this one in, the way it tracks every filled button in the section.
    static let action = TypeStyle.buttonSmall.tracking(em: -0.015)
}

// MARK: - Geometry

private enum ComingSoonMetrics {

    /// `padding:14px 12px` on the scrolling area. The gutter either side is `Spacing.gutter`;
    /// the foot is `Spacing.tabBarClearance`, because the tab bar floats over this content
    /// rather than reserving space under it (`RootView.swift:99-104`).
    static let bodyTop: CGFloat = 14

    /// `padding:14px 22px 16px` on the white header block. `ScreenHeader` supplies the 14 and
    /// the 22, and 12 of the 16 — its own `blockBottom`, which is deliberately short of the
    /// design's figure because on three of the four tabs something else follows inside the same
    /// block and makes up the rest (`ScreenHeaderMetrics.blockBottom`). Nothing follows here, so
    /// this screen is the one that owes the difference.
    static let headerBottom: CGFloat = 4

    /// `border-radius:16px`. A point tighter than `Radius.card`, which still reads 17 from the
    /// design this app shipped with — `GroupsMetrics.cardRadius:138-140`, `ScheduleMetrics` and
    /// `OverviewMetrics` each carry their own 16 for the same reason. A fourth copy is one more
    /// than anybody wants; hoisting all four is a change to three other files.
    static let cardRadius: CGFloat = 16

    /// The design's `padding:22px 18px`, opened up.
    ///
    /// Every number from here down to `actionGap` is a step above the design's, and they move
    /// together on purpose: a 32pt headline in a 22pt box is a bigger word in the same small
    /// card, which reads as crowding rather than confidence. The room is what turns the size
    /// into presence. The design's own figures are kept in each comment so the departure stays
    /// legible and reversible.
    static let cardPaddingVertical: CGFloat = 30  // design: 22
    static let cardPaddingHorizontal: CGFloat = 20  // design: 18

    /// The drop from "Coming soon" to the serif line. Design: `margin-top:7px`.
    static let headlineGap: CGFloat = 9
    /// From that line to the paragraph. Design: `margin-top:8px`.
    static let bodyGap: CGFloat = 10
    /// How wide the paragraph runs before it wraps. Design: `max-width:280px` — capped well
    /// short of the card so it stays a paragraph rather than a banner. Widened by the same 20
    /// the card's horizontal padding gained, so the measure is unchanged relative to the plate.
    static let copyWidth: CGFloat = 300
    /// The drop to "Go to Groups". Design: `margin-top:16px`.
    static let actionGap: CGFloat = 20

    /// The card's frame. The design draws `1px #EDEEF1`, the same hairline every other card in
    /// the app carries, which is precisely why it disappears here — this card is alone on its
    /// screen with nothing to be distinguished *from*.
    ///
    /// Green at 1.5 instead, which is the app's own "this one matters" frame: `accentBorder` is
    /// what the sign-in panel and the venue plate already use, and `BorderWidth.input` is a
    /// token rather than a number.
    ///
    /// The *fill* stays white, and that is not an aesthetic call. On `accentSurface` the
    /// paragraph's `inkTertiary` measures 4.38:1, under the 4.5 AA needs for 13.5pt text; on
    /// white it is 4.62:1. Tinting the plate would have bought presence by making the only
    /// sentence on the screen harder to read.
    static let borderWidth = BorderWidth.input
    /// `height:48px`. Two points over the 44pt minimum touch target before it scales at all.
    static let actionHeight: CGFloat = 48

    /// `width:96px;opacity:.18`, offset `right:-8px;bottom:-14px` — the mark, half off the
    /// corner, clipped by the card.
    ///
    /// Pinned rather than `@ScaledMetric`, alone among the numbers on this screen. The others
    /// are all drawn *around* text and have to grow with it; this one is drawn behind it, and a
    /// watermark that grows with the type ends up under the words instead of beside them.
    static let watermark: CGFloat = 96
    static let watermarkOffsetX: CGFloat = 8
    static let watermarkOffsetY: CGFloat = 14
    static let watermarkOpacity: Double = 0.18
}

// MARK: - The screen

struct ComingSoonView: View {

    /// The tab's name, set at the top in Newsreader like every other tab's.
    let title: String
    /// The serif line inside the card — "What is on right now".
    let headline: String
    /// The paragraph under it.
    ///
    /// Stored as `bodyCopy` because `body` is `View`'s own requirement and a struct cannot spend
    /// the name twice. The initialiser still takes `body:`, which is the label a caller reads.
    private let bodyCopy: String
    /// `goGroups` — the way out of a tab that cannot do anything yet.
    ///
    /// Optional, and `nil` draws no button rather than a dead one: this card exists to argue
    /// that a person is not stuck, and a button that goes nowhere makes that argument worse than
    /// silence does. Held by the caller rather than acted on here for the same reason
    /// `GroupsLockedState.onAddKids` is — which tab "Groups" means is `MainTabView`'s answer,
    /// and the selection lives on the store it owns.
    let onGoToGroups: (() -> Void)?

    /// Read optionally, and only for the avatar.
    ///
    /// `ScreenHeader`'s avatar is the one navigation affordance every tab in section 8 shares —
    /// it is how Profile is reached, and through Profile, Camp settings and Manage camps
    /// (`ScreenHeader.swift:16-21`). A tab that is still being built is exactly the tab somebody
    /// is most likely to be standing on when they want to go elsewhere, so dropping the disc
    /// here would take the app's only route to Profile off two of its four tabs.
    ///
    /// Optional so the screen still stands up with no store in the environment — a preview, or a
    /// caller that has not mounted one. `MainTabView` mounts it for every tab it draws.
    @Environment(AppStore.self) private var store: AppStore?

    /// The design's fixed sizes, grown with the reader's type. Both are drawn around text: the
    /// cap on the paragraph forces five words to a line at the app's `.accessibility1` ceiling
    /// if it stays at 280, and a pinned 48 clips a label set half again as tall.
    @ScaledMetric(relativeTo: .body) private var copyWidth = ComingSoonMetrics.copyWidth
    @ScaledMetric(relativeTo: .body) private var actionHeight = ComingSoonMetrics.actionHeight

    init(title: String, headline: String, body: String, onGoToGroups: (() -> Void)? = nil) {
        self.title = title
        self.headline = headline
        self.bodyCopy = body
        self.onGoToGroups = onGoToGroups
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Hairline(color: Theme.hairline)

            ScrollView {
                card
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, ComingSoonMetrics.bodyTop)
                    // The tab bar reserves no layout space of its own.
                    .padding(.bottom, Spacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `#F8F9F8` — the page every screen in this design sits on
        // (`design/app/Sycamore App.dc.html:24`), and a warmer grey than `Theme.grouped`.
        .background(Theme.surfaceWarm)
    }

    // MARK: The header

    /// The white block: the tab's name, the avatar, and the rule under both.
    ///
    /// `ScreenHeader` rather than a transcription of the design's own header row, which also
    /// carries the camp's name in green and a tray button beside the avatar. Those two are the
    /// app *shell's* chrome in `design/app` and no tab in this repo draws them yet — Groups,
    /// Schedule and Inbox all sit on `ScreenHeader`. Drawing them here would put a camp name and
    /// an inbox button on the two tabs that are not built and on neither of the two that are,
    /// which is a worse mismatch than the one it fixes. When the shell header lands it lands for
    /// all four tabs at once, and this call site follows it for free.
    private var header: some View {
        VStack(spacing: 0) {
            StatusBarMock()

            ScreenHeader(title: title, initials: store?.avatarInitials, onAvatarTap: openProfile)
        }
        .padding(.bottom, ComingSoonMetrics.headerBottom)
        .background(Theme.surface)
    }

    /// `nil` when there is no store to route with, which is also when there are no initials to
    /// draw — `ScreenHeader` hides the disc entirely rather than rendering an inert one.
    private var openProfile: (() -> Void)? {
        guard let store else { return nil }
        return { store.pushedScreen = .campHome }
    }

    // MARK: The card

    private var card: some View {
        Card(
            radius: ComingSoonMetrics.cardRadius,
            borderColor: Theme.accentBorder,
            borderWidth: ComingSoonMetrics.borderWidth,
            isDivided: false
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Coming soon")
                    .typeStyle(ComingSoonType.overline, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(headline)
                    .typeStyle(ComingSoonType.headline, color: Theme.ink)
                    // A 32pt serif line with 1.02 of leading clips its descenders the moment the
                    // frame narrows, and "What is on right now" wraps to two lines at the default
                    // size now rather than only at the accessibility ones. Wrapping is the right
                    // answer; truncating the name of the screen is not.
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ComingSoonMetrics.headlineGap)
                    .accessibilityAddTraits(.isHeader)

                // `#71757E` on white measures 4.6:1, which clears AA for normal text on its own —
                // this paragraph is 13.5pt and has no fill behind it to help. It is the design's
                // own colour; `inkMuted`, a step lighter, would not clear it.
                Text(bodyCopy)
                    .typeStyle(ComingSoonType.body, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: copyWidth, alignment: .leading)
                    .padding(.top, ComingSoonMetrics.bodyGap)

                if let onGoToGroups {
                    PrimaryButton(
                        "Go to Groups",
                        height: actionHeight,
                        // `border-radius:13px` — the design draws this button a step tighter than
                        // the 15 the app's other empty-state calls to action take, and 13 is a
                        // token (`Radius.tile`) rather than a number.
                        radius: Radius.tile,
                        font: ComingSoonType.action,
                        action: onGoToGroups
                    )
                    .padding(.top, ComingSoonMetrics.actionGap)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ComingSoonMetrics.cardPaddingHorizontal)
            .padding(.vertical, ComingSoonMetrics.cardPaddingVertical)
            // Behind the content rather than over it, which is what the design's `z-index:1` on
            // the button buys in CSS: at 18% the mark is quiet enough to read type over, and the
            // 4.6:1 measured above is measured against white, so nothing that matters is allowed
            // to land on top of it.
            .background(alignment: .bottomTrailing) { watermark }
        }
    }

    /// The mark, half off the bottom-right corner. `Card` clips its content, which is the
    /// `overflow:hidden` the design sets on the plate to cut it.
    ///
    /// The app's own transcription of the logo stands in for the design's `assets/logo.svg`,
    /// which is not in the repo — in the framing the rest of the app draws it in
    /// (`SycamoreMark.Variant.pair`, the default, as `CampPickerView` and `FirstRunHeader` take
    /// it). It keeps the mark's fixed greens: a logo that changes colour with the scheme is a
    /// different logo (`Theme.swift:183-184`), and at 18% it reads as a watermark in both.
    private var watermark: some View {
        SycamoreMark()
            .frame(width: ComingSoonMetrics.watermark, height: ComingSoonMetrics.watermark)
            .opacity(ComingSoonMetrics.watermarkOpacity)
            .offset(
                x: ComingSoonMetrics.watermarkOffsetX,
                y: ComingSoonMetrics.watermarkOffsetY
            )
            // `SycamoreMark` already hides itself (`SycamoreMark.swift:179`). Said again here
            // because this is the one place in the app the mark is pure decoration behind copy,
            // and the guarantee should not depend on a component two folders away keeping it.
            .accessibilityHidden(true)
    }
}

// MARK: - The two tabs

extension ComingSoonView {

    /// The tabs `soonMap` writes copy for, and the copy itself — once, here.
    ///
    /// Nested rather than added to `AppTab`, which is the app's routing enum and has four cases.
    /// A `soonTitle` there would have to answer for Groups and Inbox as well, and those two are
    /// built — so the honest shape of it is "the two tabs the design wrote this screen for",
    /// which is exactly this.
    enum Tab: String, CaseIterable, Identifiable, Sendable {
        case overview
        case schedule

        var id: String { rawValue }

        /// `soonMap[…][0]` — the name at the top of the screen.
        var title: String {
            switch self {
            case .overview: "Overview"
            case .schedule: "Schedule"
            }
        }

        /// `soonMap[…][1]` — the serif line in the card.
        var headline: String {
            switch self {
            case .overview: "What is on right now"
            case .schedule: "The day as blocks"
            }
        }

        /// `soonMap[…][2]` — the paragraph. Sentence case, no list, no promise of a date: it
        /// says what the tab will do, in the words the rest of the app uses for the same things.
        var body: String {
            switch self {
            case .overview:
                "The Now card, the needs-you strip and every court at a glance land here once days have a shape."
            case .schedule:
                "Build each day from blocks, drag to resize, take attendance from any block."
            }
        }
    }

    /// The convenience a caller wires a tab up with, so the copy is never retyped at a call site.
    init(_ tab: Tab, onGoToGroups: (() -> Void)? = nil) {
        self.init(
            title: tab.title,
            headline: tab.headline,
            body: tab.body,
            onGoToGroups: onGoToGroups
        )
    }
}

// MARK: - Previews

#Preview("Overview — coming soon") {
    ComingSoonView(.overview) {}
        .environment(AppStore.preview)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

#Preview("Schedule — coming soon") {
    ComingSoonView(.schedule) {}
        .environment(AppStore.preview)
        .showsMockStatusBar()
        .frame(width: 402, height: 874)
}

/// The app caps Dynamic Type at `.accessibility1`, which is what the two `@ScaledMetric`s on this
/// screen are for. At the cap the serif headline should be wrapping rather than clipped, the
/// paragraph should still be a paragraph rather than a column of three words, and "Go to Groups"
/// should still fit inside its button.
#Preview("Coming soon — large type") {
    ComingSoonView(.overview) {}
        .environment(AppStore.preview)
        .dynamicTypeSize(.accessibility1)
        .frame(width: 402, height: 874)
}
