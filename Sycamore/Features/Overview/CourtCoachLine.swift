//
//  CourtCoachLine.swift
//  Sycamore
//
//  Who has this court, on its own line under the activity — a 26pt disc and a first name.
//
//  `8i`'s third row, which the app had been drawing as a pill wedged into the header beside the
//  title:
//
//      <div style="display:flex;align-items:center;gap:9px;margin-top:11px">
//        <image-slot style="width:26px;height:26px" shape="circle" …>
//        <div style="flex:1;font:500 13px 'Instrument Sans';color:#3F4A44">Nass</div>
//      </div>
//
//  No plate. That is the difference from `CoachPill` and the reason this is a second view rather
//  than a flag on that one: the pill's whole shape is a capsule of `coachPillFill` with the disc
//  tucked into its leading edge, and it is right where the design draws it — wrapped in a
//  `FlowLayout` on `RunningBlockCard`, and in the court screen's header. Here the design draws
//  a face and a name sitting directly on the card, full width, under the title they belong to.
//
//  ── The court nobody has ─────────────────────────────────────────────────────────────────────
//
//  `8i` gives Court 2 the same silhouette with the disc dashed and empty, and the design's own
//  words beside it:
//
//      <div style="…width:26px;height:26px;border-radius:99px;background:#F6FAF7;
//                  border:1px dashed #C3DFCF;…"><i class="ph ph-plus" style="font-size:13px;
//                  color:#1A7F55"></i></div>
//      <div style="flex:1;font:600 13px 'Instrument Sans';color:#1A7F55">Add a coach</div>
//
//  **"Add a coach", not "Needs a coach".** The app shipped the second, which is what the earlier
//  design wrote and what `CoachPill` still says on the screens that only report. The frame is a
//  verb because the slot is a control here: it opens `CourtCoachPicker` and writes
//  `coaches.group_id`. A label that names the defect rather than the remedy is the right copy for
//  a read-only pill and the wrong copy for a button.
//
//  The mechanism underneath is unchanged and deliberately so — the `+` still calls the closure
//  `OverviewScreen.coachAction(for:)` hands down, which still opens the picker, which still calls
//  `store.assignStaff(_:toGroup:)`. What moved is the drawing and the word.
//
//  ── Why the invitation left `CoachPill` rather than being copied ─────────────────────────────
//
//  It was the only caller of that pill's `name == nil && action != nil` branch. Leaving the branch
//  behind would have left a second, differently-worded, differently-plated way to fill a court that
//  nothing on any screen could reach — which is how two answers to one gesture start, and
//  `MoreRow`'s header records where that ends.
//
//  ── And why this is a second view rather than a preset on that one ───────────────────────────
//
//  The house pattern for one component drawn several ways is a metrics preset — `ChipMetrics` has
//  eight, `MoreRowMetrics` two — and a `CoachPillMetrics.plated` / `.bare` would collapse these two
//  files into one. It was weighed and refused, for now, on two grounds. `CoachPill` is drawn by
//  `Features/Court`, which this unit does not own, so a shared API here is a change to a component
//  under somebody else's screen. And the two are not one drawing with two plates: this one is
//  full-width and has an *invitation* state the pill deliberately no longer has, which is the half
//  of the API a preset cannot express as a number.
//
//  What the two do still share verbatim is the initials fallback and the pinned-font `InitialsAvatar`
//  call. That is the seam to watch: if a third coach row appears, the preset is right and this
//  paragraph is the argument against it that has run out.
//

import SwiftUI

struct CourtCoachLine: View {

    /// Nil is a court nobody has yet.
    let name: String?
    /// Your own court, which `8j` writes as "You" in place of the name.
    ///
    /// A flag and not the string, which is what this was: the card passed `isMine ? "You" : name`
    /// and this view compared `name == "You"` to pick the spoken form. That is a boolean the caller
    /// already holds, encoded as display copy and decoded by matching on it — so renaming the word
    /// on screen would silently change what VoiceOver says, and a coach genuinely called "You"
    /// would be announced as the reader.
    var isMine: Bool = false
    /// What a tap does: opens their staff card, or — with no name — opens the picker that fills the
    /// court. Nil leaves the line inert, which is a card carrying a coach the camp cannot resolve.
    var action: (() -> Void)?

    /// The disc grows with the reader's type size or the initials inside it spill over the edge.
    /// `.footnote` is the ramp the 12pt initials ride; the `+` that replaces them rides it too, so
    /// the two states of the disc are always the same size.
    @ScaledMetric(relativeTo: .footnote) private var avatarSize = OverviewTheme.courtCoachAvatar
    @ScaledMetric(relativeTo: .footnote) private var plusSize = OverviewTheme.addCoachGlyph

    /// A court with nobody on it, on a screen that can do something about it.
    ///
    /// Inferred from the two arguments rather than declared by a third, which is the call
    /// `CoachPill` already made about the same pair and for the same reason: the four combinations
    /// of (name, action) exhaust the states, each with one sensible reading, and a `kind:` argument
    /// would be a third thing every caller has to keep in step with the other two.
    private var isInvitation: Bool { name == nil && action != nil }

    var body: some View {
        if let action {
            Button(action: action) {
                // The line keeps the height the design draws; only the frame that takes the tap
                // grows to the 44pt minimum. Grown first, shaped second — the reverse pins the hit
                // region to the drawn row and hands back a target 26pt tall.
                line
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spokenLabel)
            .accessibilityHint(isInvitation ? "Chooses who has this court" : "Opens their staff card")
        } else {
            // The disc says nothing a reader can use and the name is already in the label, so this
            // is one element with one line rather than a face and a word.
            line
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
        }
    }

    private var line: some View {
        HStack(spacing: OverviewTheme.coachRowSpacing) {
            if isInvitation {
                // Tinted and dashed, which is this screen's vocabulary for a space with nothing in
                // it yet — the same outline the "2 spots" pill wears one row up. `AccentDisc` is
                // the other candidate and is wrong: it carries a ring and is the app's empty-state
                // *mark*, 52pt above a headline, and half an inch of it on a card would read as a
                // second empty state.
                PlusDisc(size: avatarSize, glyphSize: plusSize)
            } else {
                // The type is pinned to the disc's *drawn* size rather than to the grown one, so
                // `initials(forAvatarSize:)` cannot cross one of its weight buckets as the disc
                // scales and hand a coach bolder initials than the design draws.
                InitialsAvatar(
                    initials,
                    size: avatarSize,
                    font: .initials(forAvatarSize: OverviewTheme.courtCoachAvatar)
                )
                .accessibilityHidden(true)
            }

            Text(label)
                .typeStyle(isInvitation ? OverviewTheme.addCoach : OverviewTheme.coachName, color: labelColour)
                .lineLimit(1)

            // `flex:1` on the design's own name cell. The line runs the width of the card whether
            // it holds "Nass" or "Add a coach", which is what keeps the tap target the same size
            // on every card down the screen.
            Spacer(minLength: 0)
        }
    }

    // MARK: Words

    /// What a court with nobody on it says when it can be fixed from here.
    ///
    /// `8i`'s own word, and a verb because the slot is a control: it opens `CourtCoachPicker` and
    /// writes `coaches.group_id`. `CoachPill.needsACoach` is the noun-phrase this used to borrow,
    /// and it is still right on the two screens that only report.
    ///
    /// `nonisolated` for the reason that constant's own doc gives: a `View`'s statics inherit its
    /// `@MainActor` inference, and copy has nothing to protect.
    nonisolated static let addACoach = "Add a coach"

    private var label: String {
        if isInvitation { return Self.addACoach }
        if isMine { return "You" }
        return name ?? CoachPill.needsACoach
    }

    private var initials: String { name.map { Initials.make(from: $0) } ?? "—" }

    /// `inkWarm` for a name — the design's `#3F4A44`, which is where that token's own doc says to
    /// reach for it: body and detail copy at 13pt and below. Accent once the line is something to
    /// press, and `inkFaint` for the court that is short and has nobody who can fix it from here,
    /// because faint grey on a control reads as disabled.
    private var labelColour: Color {
        if isInvitation { return Theme.accent }
        return name == nil ? Theme.inkFaint : Theme.inkWarm
    }

    /// Said as a fact about the court, not as a fragment. "Nass" alone, read out after a court's
    /// name and its head-count, does not say what Nass has to do with any of it.
    ///
    /// Your own court says both: "You have this court. Coach Nass." The drawn line has room for one
    /// of the two and the design picks "You"; a reader who cannot see it loses nothing by hearing
    /// the name as well, and on a camp with two people on a rota it is the half that says which
    /// of them the app thinks you are.
    private var spokenLabel: String {
        if isInvitation { return Self.addACoach }
        guard let name else { return "This court needs a coach" }
        return isMine ? "You have this court. Coach \(name)" : "Coach \(name)"
    }
}

// MARK: - Previews

#Preview("A court's coach") {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        CourtCoachLine(name: "Nass") {}
        // Your own court keeps the face and changes the word — the disc is still theirs, because
        // on a rota it is worth being able to see which of you the app means.
        CourtCoachLine(name: "Nass", isMine: true) {}
        // The two empty states, which are two different claims: a court that can be filled in
        // from here, and one that cannot.
        CourtCoachLine(name: nil) {}
        CourtCoachLine(name: nil)
    }
    .padding(OverviewTheme.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
}

/// The size the app caps Dynamic Type at. The disc and the `+` ride one ramp, so the filled line
/// and the empty one should still be the same height as each other.
#Preview("A court's coach — accessibility1") {
    VStack(alignment: .leading, spacing: Spacing.medium) {
        CourtCoachLine(name: "Nass") {}
        CourtCoachLine(name: nil) {}
    }
    .padding(OverviewTheme.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.surface)
    .environment(\.dynamicTypeSize, .accessibility1)
}
