//
//  MoreRow.swift
//  Sycamore
//
//  "+3 more", and the way back from it.
//
//  Three screens fold a list and three rows opened it, written separately and drifted apart:
//  the Inbox row was centred on a raised plate with its caret leading, Overview's was indented
//  into the rank column with its caret trailing, and the Groups card's had no caret at all, no
//  way back, `inkFaint` on a control that a finger is meant to land on, and nothing for
//  VoiceOver but the fragment "+3 more". Three answers to one gesture, and the newest of them
//  carried a comment claiming it matched the others.
//
//  The layouts are a real difference and stay: a card footer is centred, a row inside a ranked
//  list has to start where the names above it start. Everything else — the accent, the caret
//  that turns over, "Show less", and a spoken label that says what there are more *of* — is the
//  same decision three times and is made here once.
//
//  The design draws only the collapsed half of this, on `8h`. There is no picture of an expanded
//  list and so none of the way back from one; "Show less" is invented, and deliberately the same
//  row with its caret turned over rather than a second control somewhere else.
//

import SwiftUI

// MARK: - Metrics

/// Where the row sits, which is the one thing the three callers genuinely disagree about.
enum MoreRowLayout: Sendable, Hashable {
    /// Centred on a raised plate, closing a card. `8h`'s cleared list.
    case plate
    /// Left-aligned and indented past a list's rank column, so the label starts under the names
    /// rather than under their numbers.
    case inline(indent: CGFloat)
}

/// The drawn part. A preset per shape rather than nine arguments at the call site, following
/// `FormFieldMetrics` and `ChipMetrics`.
struct MoreRowMetrics: Sendable {
    var layout: MoreRowLayout
    /// Plate behind the row. `nil` where it sits directly on the card.
    var background: Color?
    /// The caret leads on a centred row and trails an indented one — in both cases it sits on
    /// the outside of the phrase, away from the content the row belongs to.
    var caretLeads: Bool
    /// `+3 more` inside a ranked list, `3 more` on a card footer. The design writes both.
    var showsPlus: Bool
    var label: TypeStyle
    var caretSize: CGFloat
    var spacing: CGFloat
    var verticalPadding: CGFloat
    var horizontalPadding: CGFloat = 0

    /// `8h`'s cleared card — `#FAFBFA` one step up from the card it closes, so it reads as a
    /// control rather than as a fifth cleared item.
    static let plate = MoreRowMetrics(
        layout: .plate,
        background: Theme.surfaceRaised,
        caretLeads: true,
        showsPlus: false,
        label: .chipSoft,
        caretSize: 14,
        spacing: Spacing.markGap,
        verticalPadding: 10,
        horizontalPadding: 13
    )

    /// A row inside a ranked list — Groups' cards and Overview's courts. No plate: it is one of
    /// the list's own rows, and giving it a background would lift it out of the column it is
    /// deliberately lined up with.
    static func inline(indent: CGFloat) -> MoreRowMetrics {
        MoreRowMetrics(
            layout: .inline(indent: indent),
            background: nil,
            caretLeads: false,
            showsPlus: true,
            label: .subtitle,
            caretSize: 13,
            spacing: 10,
            verticalPadding: 3
        )
    }
}

// MARK: - Row

/// The control that opens and folds a list.
struct MoreRow: View {

    /// Rows still folded away. The count the collapsed label draws.
    let hiddenCount: Int
    let isExpanded: Bool
    /// What there are more of, singular — "kid", "cleared item". VoiceOver inflects it against
    /// the count, which is why it arrives singular rather than pre-pluralised.
    let noun: String
    /// Its plural, for the expanded label where there is no count to inflect against. Spelled
    /// out rather than derived: English plurals are not a `+ "s"` and this app has "kid" in it.
    let nounPlural: String
    /// Where they are — "on this court". Nil where the row's own card is answer enough.
    var qualifier: String?
    var metrics: MoreRowMetrics = .inline(indent: 0)
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .callout) private var caret: CGFloat = 13

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(Theme.accent)
                .padding(.vertical, metrics.verticalPadding)
                .padding(.horizontal, metrics.horizontalPadding)
                // The drawn line stays where the design puts it and the touch grows around it.
                // 19pt of type is not 44pt of finger.
                .frame(minHeight: HitTarget.minimum)
                .background(metrics.background ?? .clear)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // "+3 more" is a fragment. Read out on its own after three children's names, it does not
        // say what there are three more of — and the count has to inflect.
        .accessibilityLabel(spokenLabel)
    }

    // MARK: Pieces

    @ViewBuilder
    private var content: some View {
        switch metrics.layout {
        case .plate:
            phrase
                .frame(maxWidth: .infinity)
        case .inline(let indent):
            HStack(spacing: metrics.spacing) {
                // A width, not a padding: the label has to land in the same column as the names
                // above it, and that column is set by the rank numerals rather than by a gutter.
                Color.clear
                    .frame(width: indent, height: 0)
                phrase
                Spacer(minLength: 0)
            }
        }
    }

    private var phrase: some View {
        HStack(spacing: metrics.spacing) {
            if metrics.caretLeads { caretGlyph }
            Text(label)
                .typeStyle(metrics.label)
            if !metrics.caretLeads { caretGlyph }
        }
    }

    private var caretGlyph: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: caret, weight: .medium))
            .accessibilityHidden(true)
    }

    private var label: String {
        guard !isExpanded else { return "Show less" }
        return metrics.showsPlus ? "+\(hiddenCount) more" : "\(hiddenCount) more"
    }

    private var spokenLabel: Text {
        let tail = qualifier.map { " \($0)" } ?? ""
        return isExpanded
            ? Text("Show fewer \(nounPlural)\(tail)")
            : Text("Show ^[\(hiddenCount) more \(noun)](inflect: true)\(tail)")
    }

    /// The curve for whatever state the caller flips, so a screen folding a list does not have to
    /// remember which one this row was drawn against.
    static func animation(reduceMotion: Bool) -> Animation? {
        Motion.fold(reduceMotion: reduceMotion)
    }
}

// MARK: - Previews

/// Unguarded, like every other harness in the design system. It was behind `#if DEBUG` while the
/// `#Preview` below it was not, which compiled in debug and broke release —
/// `Features/Inbox/InboxPreviewItems.swift` carries the reasoning and the rejected alternative.
private struct MoreRowPreviewHarness: View {
    @State private var plate = false
    @State private var inline = false

    var body: some View {
        VStack(spacing: Spacing.gutter) {
            Card(radius: Radius.card) {
                MoreRow(
                    hiddenCount: 2, isExpanded: plate,
                    noun: "cleared item", nounPlural: "cleared items",
                    metrics: .plate
                ) {
                    withAnimation(MoreRow.animation(reduceMotion: false)) { plate.toggle() }
                }
            }

            Card(radius: Radius.card) {
                MoreRow(
                    hiddenCount: 3, isExpanded: inline,
                    noun: "kid", nounPlural: "kids", qualifier: "on this court",
                    metrics: .inline(indent: 17)
                ) {
                    withAnimation(MoreRow.animation(reduceMotion: false)) { inline.toggle() }
                }
                .padding(.horizontal, Spacing.gutter)
            }
        }
        .padding(Spacing.gutter)
        .background(Theme.surfaceWarm)
    }
}

#Preview("More rows") {
    MoreRowPreviewHarness()
}
