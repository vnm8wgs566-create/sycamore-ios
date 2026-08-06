//
//  ScreenHeader.swift
//  Sycamore
//
//  The header every tab in section 8 draws: the screen's name on the left, the signed-in
//  person's initials on the right, and — on its own line underneath — either a count or a
//  sentence.
//
//  Three of the four tabs were passing a sentence to `count:` and getting it drawn inline beside
//  the title, which is not a layout section 8 has anywhere. Every screen that writes a second
//  line writes it *under* the title: `8k` "5 blocks", `8g` "5 kids added · Sycamore",
//  `8h` "Nothing waiting on you", `8i` "Skills rotation · until 10:30". So there are two slots
//  here now, because the design draws the two differently — see `SecondLine`.
//
//  The avatar is the one navigation affordance shared by all four tabs — it is how `8s Profile`
//  is reached, and through Profile how `8t Camp settings` and `8u Manage camps` are. Before
//  section 8 that corner held a bell that the design drew with an unread dot and gave no
//  destination; `GroupsHeader` had to render it as decoration rather than a button so it would
//  not report itself to VoiceOver as something you could press. This replaces it with a control
//  that goes somewhere. (`8o` draws no avatar at all. Groups keeps one anyway, for the same
//  reason: it is that tab's only way to Profile.)
//

import SwiftUI

// MARK: - Metrics

/// The header block's own geometry, read off the seven screens that draw it: `8f`, `8g`, `8h`,
/// `8i`, `8k`, `8o`, `8r`.
enum ScreenHeaderMetrics {

    /// `font:400 32px/1.02 Newsreader` — the title size. Unanimous across all seven: the four
    /// tabs and the three empty states set it identically. (Section 8's other Newsreader
    /// headings run 24–40, but those are detail screens with a back row above the title, and
    /// none of them is this component.)
    static let titleSize: CGFloat = 32

    /// `width:34px;height:34px` — the avatar disc. Its *hit* area is `HitTarget.minimum`; the
    /// two are deliberately different sizes.
    static let avatarSize: CGFloat = 34

    /// `font-size:13.5px` — `8k`'s "5 blocks", the only true count in section 8.
    static let countSize: CGFloat = 13.5

    /// `font-size:13px` — the sentence under a title on `8g`, `8h` and `8t`.
    ///
    /// `8i` is the one screen that disagrees, setting its now-line at 13.5 and 7 below the title
    /// rather than 13 and 6. Three screens against one, and half a point either way is under the
    /// threshold where it reads as a different size, so the three win.
    static let subtitleSize: CGFloat = 13

    /// `margin-top:3px` — `8k` sets a count tight under the title it qualifies. A sentence stands
    /// further off, at `Spacing.tight`; that difference is the whole reason the two are separate
    /// slots rather than one optional string.
    static let countGap: CGFloat = 3

    /// `padding:14px 22px …` — the block's inset above the title.
    ///
    /// Measured, and left where it was: `8f`, `8g`, `8h` and `8k` set 14 here while `8i`, `8o`
    /// and `8r` set 20, and the callers are already calibrated against 14 — `ScheduleMetrics`
    /// carries a `chipRowTop` of 4 for no reason other than to make 12 + 4 into the 16 the day
    /// picker sits below. Moving it is a change to those files, not to this one.
    static let blockTop: CGFloat = 14

    /// The gap under the block. Not the design's `padding-bottom`: on three of the four tabs
    /// something else follows inside the same white block (a day picker, chips, a search field)
    /// and supplies the rest of it. See `blockTop`.
    static let blockBottom: CGFloat = 12
}

// MARK: - Type

extension TypeStyle {

    /// `400 32/1.02 Newsreader`, `-.022em` — every section-8 tab title.
    ///
    /// `.tabTitle` already carries the family, the weight, the tracking and the leading this
    /// wants; its size alone is still the 28 of the design that preceded section 8. Declared here
    /// rather than corrected there because `Typography.swift` says in as many words that its
    /// table is mid-rework with seven pull requests open against it, and because `.tabTitle` has
    /// a second reader — `RankView` — with no section-8 screen to measure against. One number to
    /// move once that pass lands.
    static let screenHeaderTitle = TypeStyle.tabTitle.size(ScreenHeaderMetrics.titleSize)

    /// `400 13.5` — `8k`'s "5 blocks".
    ///
    /// Not `.meta`, which this line used to borrow: that is `500 12`. Section 8 sets its
    /// secondary copy in 400 throughout — the note at the top of `Typography.swift` counts 38 of
    /// 44 declarations at 13.5px in the regular weight.
    static let screenHeaderCount = TypeStyle(size: ScreenHeaderMetrics.countSize, weight: .regular)

    /// `400 13` — the sentence under a title.
    ///
    /// The same cut as `SectionEightMetrics.headerDetail`, which transcribed it from `8t` before
    /// this file had a slot to put it in. The two collapse into one the moment that file hoists.
    static let screenHeaderSubtitle = TypeStyle(size: ScreenHeaderMetrics.subtitleSize, weight: .regular)
}

// MARK: - The header

struct ScreenHeader: View {

    let title: String
    /// A genuine figure — `8k`'s "5 blocks". Drawn under the title, tight against it.
    ///
    /// Reach for `subtitle` for anything that reads as a sentence. Only Schedule counts anything.
    var count: String?
    /// A line of prose under the title — "Skills rotation · until 10:30", "Nothing waiting on
    /// you". Set further off the title than a count, and a half-point smaller.
    var subtitle: String?
    /// Initials for the avatar. Nil or empty hides it — empty because `store.avatarInitials`
    /// is empty when signed out, and a blank grey disc is worse than no disc.
    var initials: String?
    var onAvatarTap: (() -> Void)?

    private var shownInitials: String? {
        guard let initials, !initials.isEmpty else { return nil }
        return initials
    }

    /// The one line under the title, and which of its two forms it takes.
    ///
    /// `count` wins when a caller passes both. The design never draws two lines here, so this is
    /// a tie-break rather than a layout.
    private var secondLine: SecondLine? {
        if let count, !count.isEmpty { return .count(count) }
        if let subtitle, !subtitle.isEmpty { return .subtitle(subtitle) }
        return nil
    }

    var body: some View {
        // `display:flex;align-items:flex-start;gap:12px` around a `flex:1;min-width:0` column —
        // which is how `8f`, `8g`, `8h` and `8k` draw it. `8i`, `8o` and `8r` write the row
        // `align-items:center` instead, but they are the screens with nothing under the title,
        // where a 34pt disc against a 32.64px line box lands in the same place either way.
        //
        // Reading order comes free from it: the title and the line qualifying it are siblings,
        // so VoiceOver speaks them together and reaches the avatar afterwards. Putting the
        // avatar in a row with the title alone had it spoken in between the two.
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .typeStyle(.screenHeaderTitle, color: Theme.ink)
                    // Lets the title take a second line at the accessibility text sizes rather
                    // than clipping its descenders.
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let secondLine {
                    Text(secondLine.text)
                        .typeStyle(secondLine.style, color: Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, secondLine.topGap)
                }
            }

            Spacer(minLength: Spacing.medium)

            if let shownInitials {
                avatar(shownInitials)
            }
        }
        .padding(.top, ScreenHeaderMetrics.blockTop)
        .padding(.bottom, ScreenHeaderMetrics.blockBottom)
        // `padding: … 22px …`. Section 8 draws twenty white header blocks and insets every one
        // of them by 22 — not by `Spacing.bar`, the 16 the stage-1 screens use.
        .padding(.horizontal, Spacing.header)
    }

    /// A count and a sentence are the same slot on the screen and different things on the page:
    /// `8k` sets its count 3 under the title at 13.5, and `8g`/`8h` set their sentence 6 under it
    /// at 13. Modelling that as two cases keeps the difference here instead of at four call sites.
    private enum SecondLine {
        case count(String)
        case subtitle(String)

        var text: String {
            switch self {
            case .count(let text), .subtitle(let text): text
            }
        }

        var style: TypeStyle {
            switch self {
            case .count: .screenHeaderCount
            case .subtitle: .screenHeaderSubtitle
            }
        }

        var topGap: CGFloat {
            switch self {
            case .count: ScreenHeaderMetrics.countGap
            // `margin-top:6px`.
            case .subtitle: Spacing.tight
            }
        }
    }

    @ViewBuilder
    private func avatar(_ initials: String) -> some View {
        if let onAvatarTap {
            Button(action: onAvatarTap) {
                InitialsAvatar(initials, size: ScreenHeaderMetrics.avatarSize, tone: .neutral)
            }
            .buttonStyle(.plain)
            // The disc is drawn at the design's diameter. The hit area is widened to the 44pt
            // minimum without moving the pixels — the same trick the stepper and sheet-dismiss
            // buttons use.
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .contentShape(.rect)
            .accessibilityLabel("Your profile")
        } else {
            InitialsAvatar(initials, size: ScreenHeaderMetrics.avatarSize, tone: .neutral)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Previews

#Preview("Screen header") {
    VStack(spacing: 0) {
        ScreenHeader(title: "Overview", subtitle: "Skills rotation · until 10:30", initials: "AR") {}
        Hairline(color: Theme.hairline)
        ScreenHeader(title: "Schedule", count: "5 blocks", initials: "AR") {}
        Hairline(color: Theme.hairline)
        ScreenHeader(title: "Groups", subtitle: "5 kids added · Sycamore", initials: "AR") {}
        Hairline(color: Theme.hairline)
        ScreenHeader(title: "Inbox", initials: "AR") {}
        Spacer()
    }
    .background(Theme.surface)
}
