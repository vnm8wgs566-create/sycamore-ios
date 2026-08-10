//
//  NeedsYouRow.swift
//  Sycamore
//
//  4a's second card — `Needs you · 2 · Match play has no coach`.
//
//      <div style="display:flex;align-items:center;gap:9px;background:#fff;
//                  border:1px solid #F0E3C6;border-radius:13px;padding:11px 13px">
//        <i class="ph ph-warning" style="font-size:15px;color:#B67A16"></i>
//        <div style="flex:1;min-width:0;font:400 13px;color:#3F4A44;white-space:nowrap;
//                    overflow:hidden;text-overflow:ellipsis">
//          <span style="font-weight:600;color:#0B0B0C">Needs you · 2</span> · Match play has no coach
//        </div>
//        <i class="ph ph-caret-right" style="font-size:14px;color:#C7CBD2"></i>
//      </div>
//
//  ── What it counts ──────────────────────────────────────────────────────────────────────────
//
//  `AppStore.openInboxCount` — unresolved `needsAction` rows, camp-wide. The same figure the Inbox
//  puts over its own first section (`InboxList.swift:26`) and the same one the tab bar badges, and
//  that is the point of it: a row on Overview that counted something of its own would be a second
//  definition of "waiting on you", and the two would disagree on the first morning somebody
//  resolved something.
//
//  Camp-wide rather than scoped to `readVenueID`, which is the filter this might be expected to
//  apply and must not, for the reason `OverviewView.pinnedNotes` gives about pins: the Inbox is the
//  one part of section 8 that is not about a venue, and narrowing here would put a count on screen
//  that the screen behind the caret disagrees with.
//
//  ── And what the tail says ──────────────────────────────────────────────────────────────────
//
//  The newest of those rows, in its own words. 4a writes "Match play has no coach", which is the
//  shape of an `InboxItem.title` on a `needsAction` row, and naming one of them is what turns a
//  count into something a reader can act on without opening anything: two is a number, "Match play
//  has no coach" is a job.
//
//  Deliberately **not** derived here. It would be easy to walk today's blocks for one with no
//  coaches on it and write that sentence — and it would be a second Inbox, computed differently,
//  disagreeing with the first about what is outstanding. The row reports what the Inbox holds.
//
//  ── The whole row is one control ────────────────────────────────────────────────────────────
//
//  A caret, a count and a sentence that all lead to the same screen, so they are one button and one
//  accessibility element, which is what `PinnedNoteBanner` directly below it already does. One line,
//  clipped rather than wrapped, for that banner's reason: this is a reminder of things written down
//  elsewhere, and the caret is the way to all of them.
//

import SwiftUI

struct NeedsYouRow: View {

    /// How many rows are waiting. Zero never reaches here — see `OverviewScreen.needsYou`, which
    /// draws nothing rather than "Needs you · 0", the same call `InboxList` makes about its own
    /// heading.
    let count: Int
    /// The newest one, in its own words. Nil draws the count alone and no trailing middot.
    var headline: String?
    let action: () -> Void

    /// 15 sits in the callout band, alongside the 13pt line beside it.
    @ScaledMetric(relativeTo: .callout) private var glyphSize = OverviewTheme.needsYouGlyph
    @ScaledMetric(relativeTo: .callout) private var caretSize = OverviewTheme.needsYouCaret

    /// `Needs you · 2`, in the heavier run.
    private var countLabel: String { "Needs you · \(count)" }

    var body: some View {
        Button(action: action) {
            row
                .frame(minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        // Spoken with the clause spelled out rather than run together with a middot, which
        // VoiceOver reads as "middle dot".
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the inbox")
    }

    private var spokenLabel: String {
        guard let headline else { return "\(count) waiting on you" }
        return "\(count) waiting on you. \(headline)"
    }

    /// `Card` and not four lines of plate written out again.
    ///
    /// The design's `background:#fff;border:1px solid #F0E3C6;border-radius:13px` is exactly what
    /// `Card` draws — a `RoundedRectangle(style: .continuous)`, `Theme.surface` behind it and a
    /// `BorderWidth.hairline` `strokeBorder` over it (`Components.swift:148-163`) — so the only
    /// things this row has to say are *which* radius and *which* border. The amber is the whole
    /// difference from the card above it, and `borderColor` is the parameter that exists to say so.
    ///
    /// `isDivided: false` because this is one line of content and not a stack of rows; the default
    /// would slip `DividedStack` in to rule between children this card does not have.
    ///
    /// The padding stays on the content rather than moving to the card. `Card` deliberately carries
    /// no padding of its own — `CardRow` is where the design's 13pt gutter lives — and `4a` sets
    /// this banner at its own `11px 13px`, which is what `needsYouHorizontal`/`needsYouVertical` are.
    private var row: some View {
        Card(radius: Radius.tile, borderColor: Theme.warningBorder, isDivided: false) {
            HStack(spacing: OverviewTheme.bannerGap) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: glyphSize, weight: .regular))
                    .foregroundStyle(Theme.warning)

                line
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DisclosureChevron(size: caretSize, color: Theme.chevron)
            }
            .padding(.horizontal, OverviewTheme.needsYouHorizontal)
            .padding(.vertical, OverviewTheme.needsYouVertical)
        }
    }

    /// One `Text` of two runs, which is how the design writes it — a `<span>` inside the line that
    /// lifts the weight to 600 and the colour to `#0B0B0C`.
    ///
    /// One `Text` and not an `HStack` of two, deliberately, and it is the same call
    /// `OverviewCourtCard.titleText` (`:312-319`) makes about a closed court's reason: stacked side
    /// by side, the count would hold its width against a headline that has none to spare and the
    /// clipping would land in the wrong half. Interpolated, the line clips where the design clips
    /// it — at the end of the sentence.
    private var line: some View {
        // Nothing named behind the count, so the whole line *is* the count and takes the heavy
        // run outright rather than being a bold fragment of a sentence that has no rest.
        guard let headline else {
            return Text(countLabel)
                .typeStyle(OverviewTheme.cardSubtitle.weight(.semibold), color: Theme.ink)
        }
        // Interpolated rather than joined with `+`, which is what `Text.typeStyleRun` asks for.
        // The outer `.typeStyle` sets the run this one does not override.
        let counted = Text(countLabel)
            .typeStyleRun(OverviewTheme.cardSubtitle.weight(.semibold), color: Theme.ink)
        return Text("\(counted) · \(headline)")
            .typeStyle(OverviewTheme.cardSubtitle, color: Theme.inkWarm)
    }
}

// MARK: - Previews

#Preview("Needs you") {
    VStack(spacing: OverviewTheme.cardGap) {
        NeedsYouRow(count: 2, headline: "Match play has no coach") {}
        // The tail the design does not draw: a count with nothing named behind it, and a headline
        // long enough to clip.
        NeedsYouRow(count: 1) {}
        NeedsYouRow(
            count: 4,
            headline: "Austin Zheng has been asked to move from Court 4 to Court 2 this morning"
        ) {}
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceWarm)
}

#Preview("Needs you — accessibility1") {
    NeedsYouRow(count: 2, headline: "Match play has no coach") {}
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
        .environment(\.dynamicTypeSize, .accessibility1)
}
