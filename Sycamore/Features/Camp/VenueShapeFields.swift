//
//  VenueShapeFields.swift
//  Sycamore
//
//  The blocks `design/app/regions/sheet-shVenue.html` draws between the name and the CTA, once,
//  for the two sheets that draw them.
//
//  ── Why one file and not two copies ──────────────────────────────────────────────────────────
//
//  `VenueShapeSheet` shapes a venue that does not exist yet and `VenueSheet` shapes one that does.
//  That difference is real — one commits to a form, the other to Postgres; one can count a venue's
//  kids and the other has no camp to count in — and it is the *only* difference. Age band, courts,
//  groups, target, the sentence under them and the coach row are the same eight controls asking
//  the same eight questions in the same order, and the design draws them once.
//
//  `VenueNameFields` and `VenueLimitRow` were hoisted out of `VenueSheet` for exactly this reason
//  a change ago (`VenueSheet.swift:146-157`); this is the rest of the sheet following them.
//
//  ── What is deliberately not here ────────────────────────────────────────────────────────────
//
//  No store, no `Camp`, no `Venue`. Everything below takes bindings and plain values, so the
//  pre-creation sheet — which has no camp to read — can draw the identical control. The two
//  callers each answer "what are the kid counts" and "who has joined" in their own way and hand
//  the answers down.
//

import SwiftUI

// MARK: - Chips

extension ChipMetrics {

    /// The venue sheet's age-band chips — `600 12.5`, `7/12`, pill, `#E4E5E9` unselected.
    ///
    /// A preset of its own rather than `.venue` (which is `7/13` on the rounder `strokeChip`),
    /// because these sit inside a sheet against a white field, where `strokeAlt`'s siblings do:
    /// `.time` and `.court` both take a `strokeAlt`-family border for the same reason. The one
    /// pixel of horizontal padding is the design's, and copying it is cheaper than explaining
    /// which chip it nearly is.
    static let ageBand = ChipMetrics(
        font: .chipMedium, horizontalPadding: 12, verticalPadding: 7,
        radius: Radius.pill, spacing: 6, unselectedBorder: Theme.stroke, emojiSize: 12.5
    )

    /// The coach chips under it — `600 13`, `8/13`, pill. One step larger, because these carry a
    /// person's name and the ones above carry a setting.
    static let venueCoach = ChipMetrics(
        font: .chip, horizontalPadding: 13, verticalPadding: 8,
        radius: Radius.pill, spacing: 6, unselectedBorder: Theme.stroke, emojiSize: 13
    )
}

// MARK: - Field label

/// A field label with a quiet word on the right — `Subtitle … optional`.
///
/// `SheetFieldLabel` draws the left half at exactly the design's `600 12.5 / -.01em / #71757E`,
/// so this composes it rather than restating the type: the note is a second `Text` on the
/// baseline, and the label keeps its own padding.
///
/// Not `SheetFieldLabel` with an optional trailing string, which would mean editing a shared
/// component in `Features/Sheets/` for one screen's benefit — see `Motion.swift:12` for when that
/// trade is worth making, and this is the other side of it: one caller, one file.
struct VenueFieldLabel: View {
    let title: String
    var note: String?
    var topPadding: CGFloat = Spacing.gutterWide

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            SheetFieldLabel(title, topPadding: topPadding, bottomPadding: 0)
            if let note {
                Text(note)
                    // `inkFaint` is the design's `#A2A6AE`, and this is the one place it stays:
                    // a five-letter aside beside a label it modifies is not body copy, and it is
                    // read by VoiceOver as part of the field it labels rather than on its own.
                    .typeStyle(.footnote.lineHeight(nil), color: Theme.inkFaint)
            }
        }
        .padding(.bottom, 7)
        // One utterance. "Subtitle, optional" is what a person would say; two elements make the
        // rotor stop twice and say the second one without its noun.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Age band

/// Which ages this venue takes: pick the *shape* of the answer, then pick the age.
///
/// ── Why a shape row over steppers, and not two steppers that switch off ──────────────────────
///
/// `AgeBand` stopped being three cases and became a nullable pair, so this control had to stop
/// being three chips. The two honest ways to draw a nullable pair were a segmented shape row plus
/// one or two steppers, or two steppers each with an off state, and this is the first of them.
///
/// **The deciding argument is what "All ages" costs.** Most venues are not asking about age, so
/// the default has to be free — and with two switchable steppers it is *two* switch-offs and a
/// state the reader has to infer, because "no lower bound and no upper bound" is not a phrase
/// anybody reads as "all ages". Here it is one chip, already selected, worded in the reader's own
/// language, and a venue nobody narrows never sees a stepper at all. It is also the control that
/// was already on this screen, so a camp that was happy with "11 & under" still gets there in one
/// tap and finds the number they expect underneath.
///
/// The second argument is that three of the four shapes make an invalid band *unreachable*, and
/// the fourth is bounded by construction: the lower stepper cannot climb past the upper and the
/// upper cannot fall below the lower, because each takes the other as its range. `sites`
/// `sites_age_bounds_ordered` therefore has nothing to catch, and `AgeBand`'s own init is the
/// second belt rather than the first.
///
/// ── The shape is derived, never stored ───────────────────────────────────────────────────────
///
/// `Shape` below is read off the bounds on every pass and is not a field on anything. That is the
/// whole point of dropping the enum: one representation, and a picker that cannot come to disagree
/// with the band it is editing. Switching shape *seeds* bounds — and seeds them from whatever is
/// already there, so moving between "12 & up" and "between" keeps the twelve rather than throwing
/// away the number somebody just chose.
struct VenueAgeBandPicker: View {
    @Binding var ageBand: AgeBand

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            shapeChips

            if !ageBand.isUnrestricted {
                boundsCard

                // Said here because this is the screen where somebody narrows a venue, and the
                // consequence is the one thing about a band that surprises people: it does not
                // remove anybody. `Camp.admit(_:at:)` leaves a refused kid at the venue with no
                // group, which is a visible, countable, one-drag-away state — and a reader who
                // does not know that reads the steppers as a delete button.
                Text("Kids outside this stay at the venue without a group — nobody is removed.")
                    .typeStyle(.meta.lineHeight(1.5), color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(.selection, trigger: ageBand)
    }

    // MARK: - The shape

    /// The four shapes a nullable pair can take, named for the answer rather than for the columns.
    private enum Shape: CaseIterable {
        case all, upTo, from, between

        /// Short on the chip, because four pills wrap onto two rows at the larger type sizes and
        /// a wrapped pill row is where this control stops reading as one question.
        var title: String {
            switch self {
            case .all: "All ages"
            case .upTo: "Up to"
            case .from: "From"
            case .between: "Between"
            }
        }

        /// Spoken in full. "Up to" on its own is not an answer to anything by ear, and the numbers
        /// that complete it are in a separate element below.
        var spoken: String {
            switch self {
            case .all: "All ages"
            case .upTo: "Up to an age"
            case .from: "From an age"
            case .between: "Between two ages"
            }
        }
    }

    private var shape: Shape {
        switch (ageBand.minAge, ageBand.maxAge) {
        case (nil, nil): .all
        case (nil, _): .upTo
        case (_, nil): .from
        default: .between
        }
    }

    private var shapeChips: some View {
        FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
            ForEach(Shape.allCases, id: \.self) { option in
                let isSelected = option == shape
                Chip(option.title, isSelected: isSelected, metrics: .ageBand) {
                    select(option)
                }
                // The chip draws its selection and does not say so, which makes "which ages" an
                // unanswerable question by ear. `CreateCampView.sportChips` adds the same trait
                // to the same shared control for the same reason.
                .accessibilityLabel(option.spoken)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    /// Seeded from what is already on the band wherever there is something to keep.
    ///
    /// The two one-sided shapes fall back to the bounds this type used to be *made* of — eleven
    /// and twelve — so the two bands the app could express before are still one tap and no steps.
    /// "Between" opens three years wide around whichever bound already exists, which is a band a
    /// reader adjusts rather than one they have to build: fresh, that is 9–12, and from "12 & up"
    /// it is 12–15 rather than the useless 12–12 a plain `?? 12` on both sides would give.
    private func select(_ option: Shape) {
        switch option {
        case .all:
            ageBand = .all
        case .upTo:
            ageBand = .upTo(ageBand.maxAge ?? AgeBand.defaultCeiling)
        case .from:
            ageBand = .from(ageBand.minAge ?? AgeBand.defaultFloor)
        case .between:
            let span = 3
            let lower = ageBand.minAge
                ?? max(AgeBand.range.lowerBound, (ageBand.maxAge ?? AgeBand.defaultFloor) - span)
            let upper = ageBand.maxAge ?? min(AgeBand.range.upperBound, lower + span)
            ageBand = .between(lower, upper)
        }
    }

    // MARK: - The ages

    /// The same card the numbers above it live in — `VenueLimitRow` inside a `Card`, with
    /// `IntakeStepper` as the control. Reused rather than invented: an age is a small integer
    /// somebody nudges, which is exactly what the courts, groups and target steppers are, and a
    /// bespoke control here would be a fourth spelling of one interaction on one sheet.
    /// A `switch` returning three whole cards rather than one card holding two `if`s, and the
    /// reason is `Card`'s divider: it stacks through `_VariadicView`, where a conditional row is
    /// still a child even when it renders nothing — so a one-stepper card built that way draws a
    /// hairline above an empty row. Three shapes, three literal card bodies, no empty children.
    @ViewBuilder
    private var boundsCard: some View {
        switch shape {
        case .all:
            EmptyView()
        case .upTo:
            Card(radius: Radius.input, borderColor: Theme.strokeAlt) { oldestRow }
        case .from:
            Card(radius: Radius.input, borderColor: Theme.strokeAlt) { youngestRow }
        case .between:
            Card(radius: Radius.input, borderColor: Theme.strokeAlt) {
                youngestRow
                oldestRow
            }
        }
    }

    /// The lower stepper stops at the upper bound, so "between" cannot be dragged inside out.
    private var youngestRow: some View {
        VenueLimitRow(
            title: "Youngest",
            detail: "Nobody younger is dealt onto a court here."
        ) {
            IntakeStepper(
                value: floorBinding,
                range: AgeBand.range.lowerBound...(ageBand.maxAge ?? AgeBand.range.upperBound),
                label: "Youngest age",
                valueWidth: 34
            )
        }
    }

    private var oldestRow: some View {
        VenueLimitRow(
            title: "Oldest",
            detail: "Nobody older is dealt onto a court here."
        ) {
            IntakeStepper(
                value: ceilingBinding,
                range: (ageBand.minAge ?? AgeBand.range.lowerBound)...AgeBand.range.upperBound,
                label: "Oldest age",
                valueWidth: 34
            )
        }
    }

    /// Writes through the whole band rather than one property, because `AgeBand`'s bounds are
    /// `private(set)` — the type normalises the pair on the way in, and a binding straight into a
    /// stored property would be the one route past it.
    private var floorBinding: Binding<Int> {
        Binding(
            get: { ageBand.minAge ?? AgeBand.defaultFloor },
            set: { ageBand = AgeBand(minAge: $0, maxAge: ageBand.maxAge) }
        )
    }

    private var ceilingBinding: Binding<Int> {
        Binding(
            get: { ageBand.maxAge ?? AgeBand.defaultCeiling },
            set: { ageBand = AgeBand(minAge: ageBand.minAge, maxAge: $0) }
        )
    }
}

// MARK: - Counts

/// Courts, groups and the optional target — the three numbers the sheet exists to separate.
///
/// ── Stacked, where the design puts courts and groups side by side ────────────────────────────
///
/// The design draws two half-width stepper boxes in a row and the target in a full-width row
/// under them. This draws all three as rows of one card, which is the shape the app already
/// gives a venue's numbers (`VenueLimitRow`, shared by both venue sheets) and is the reason each
/// row can carry the one-line explanation the two-up layout has no room for — "on the ground
/// here" against "how the kids split" is the whole distinction this change is about, and a bare
/// pair of steppers labelled Courts and Groups is precisely how they came to be confused.
///
/// It is also what survives the type ramp. Two steppers side by side hold at `.accessibility1`
/// on a 375pt screen with about forty points to spare and stop holding well before the app's cap;
/// a row that wraps its label above its control does not have a cliff.
struct VenueCountsCard: View {
    /// "court", "field", "lane" — the sport's own word for the ground.
    let courtNoun: String
    @Binding var courts: Int
    @Binding var groups: Int
    @Binding var targetPerGroup: Int?

    var body: some View {
        Card(radius: Radius.input, borderColor: Theme.strokeAlt) {
            VenueLimitRow(
                title: courtsTitle,
                detail: "On the ground here. Moving it re-derives the limits below."
            ) {
                IntakeStepper(
                    value: $courts,
                    range: CampShape.courtRange,
                    label: courtsTitle,
                    valueWidth: 34
                )
            }

            VenueLimitRow(
                title: "Groups",
                detail: "How the kids split. One group is one court's worth."
            ) {
                IntakeStepper(
                    value: $groups,
                    range: CampShape.groupRange,
                    label: "Groups",
                    valueWidth: 34
                )
            }

            VenueLimitRow(
                title: "Kids per group",
                // The design's caption, word for word. It is the only thing standing between a
                // number that guides and a number somebody believes they cannot exceed.
                detail: "Optional target — over flags amber, never blocks"
            ) {
                VenueTargetStepper(target: $targetPerGroup)
            }
        }
    }

    private var courtsTitle: String { "\(courtNoun.capitalized)s" }
}

/// The target stepper: `1…40`, and one step below the floor is "no target at all".
///
/// A control of its own rather than an `IntakeStepper` over `0...40`, for the one thing an
/// `IntakeStepper` cannot do: draw its value as something other than its number. Nought here is
/// not a target of nobody, it is the absence of a target — the column is nullable precisely so
/// the two are distinguishable — and the design draws that state as an em dash in the grey
/// everything unanswered on this screen wears.
///
/// Everything else is `IntakeStepper`'s, deliberately: the same 28pt buttons on the same `fill`
/// track at the same radius, the same touch growth, the same adjustable action, the same haptic.
/// Only the middle 30 points differ.
struct VenueTargetStepper: View {
    @Binding var target: Int?

    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 14
    /// The design's 30pt readout — two digits or a dash.
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 30

    private var range: ClosedRange<Int> { CampShape.targetRange }

    var body: some View {
        HStack(spacing: Spacing.hairGap) {
            button("minus", tint: Theme.inkSecondary, enabled: target != nil, action: decrease)

            Text(target.map(String.init) ?? "—")
                .typeStyle(.intakeStepperValue, color: target == nil ? Theme.inkFaint : Theme.ink)
                .frame(minWidth: valueWidth)
                .multilineTextAlignment(.center)

            button(
                "plus",
                tint: Theme.accent,
                enabled: (target ?? 0) < range.upperBound,
                action: increase
            )
        }
        .padding(3)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kids per group")
        // Spoken rather than shown: an em dash is read as "dash" or as nothing at all depending on
        // the voice, and neither is the answer to "how many kids per group".
        .accessibilityValue(target.map { "\($0)" } ?? "No target")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increase()
            case .decrement: decrease()
            @unknown default: break
            }
        }
        .sensoryFeedback(.selection, trigger: target)
    }

    /// Off the floor is off the target. Stepping down from 1 clears it rather than stopping there,
    /// which is what makes "no target" reachable with a thumb — there is no other control on the
    /// screen that could unset it.
    private func decrease() {
        guard let current = target else { return }
        target = current > range.lowerBound ? current - 1 : nil
    }

    private func increase() {
        target = min(range.upperBound, (target ?? range.lowerBound - 1) + 1)
    }

    private var hitInset: CGFloat {
        max(0, (HitTarget.minimum - buttonSize) / 2)
    }

    private func button(
        _ symbol: String,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(enabled ? tint : Theme.glyphFaint)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Radius.stepperButton, style: .continuous)
                )
                .intakeTouchTarget(inset: hitInset)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - What saving does

/// The live sentence under the numbers: what pressing the button below will actually do.
///
/// ── The design's three variants are not this app's three ─────────────────────────────────────
///
/// `design/app/state1.js:245` writes them as:
///
/// 1. *"Import deals every fitting kid into these {n} groups — kids outside the ages stay
///    unassigned."*
/// 2. *"Save re-deals all {k} kids into {n} groups by ladder order."* (amber)
/// 3. *"{name} holds {k} kids — moves happen in Groups."*
///
/// The third is transcribed exactly. The first two used to describe a machine this app did not
/// have, and this block spent most of its length arguing that — correctly, at the time.
///
/// **The first is now true and the sentence says so.** `AppStore.applyRoster` runs
/// `seatArrivals` after the insert, so an import really does deal every kid the venue admits
/// across its groups, in ladder order, onto the emptiest court. The old objection —
/// `importPlayers`' own "as opposed to being dropped into court 1 by an import and quietly
/// outranking kids already there" — is answered rather than ignored: the pass seats **only** kids
/// with no court, so a re-import moves nobody a coach has placed, and it deals onto the emptiest
/// court rather than the first, so nobody is dropped on top of anybody.
///
/// The band half was already honest and stays: `Camp.seatUnassigned(at:)` asks
/// `AgeBand.admits(_:)` per kid, so a venue that is asking leaves the misfits standing at the
/// venue with no group. That is the sentence under the age picker, not this one.
///
/// **Saving still does not re-deal, and the amber variant still says so.** `updateVenue` →
/// `Camp.upsert` → `syncGroups(for:)` adds or trims courts; a kid standing on a court that goes
/// has their `groupID` cleared and is re-seated by the same pass, but the *ladder* is not
/// re-cut. The re-deal by ladder order is "Even out", which lives on Rank and is camp-wide — not
/// something a venue sheet may fire on the way past, because it would relevel every *other*
/// venue's courts too.
///
/// Amber on the change variant, because moving a group count still leaves somebody to look at.
enum VenueDealSentence {

    /// Nothing exists yet — the venue is being added.
    static func adding(groups: Int) -> String {
        "Creates \(groups) \(groupWord(groups)) here. Kids you bring in are dealt across them evenly — rank them after."
    }

    /// The venue exists and its group count is unchanged. The design's own sentence.
    static func holding(name: String, kids: Int) -> String {
        "\(name) holds \(kids) \(kids == 1 ? "kid" : "kids") — moves happen in Groups."
    }

    /// The venue exists, holds kids, and the group count has been moved.
    static func recutting(from was: Int, to now: Int, kids: Int) -> String {
        let kidWord = kids == 1 ? "kid" : "kids"
        if now < was {
            let closed = was - now
            return "Save closes \(closed) \(groupWord(closed)) — the \(kidWord) standing on \(closed == 1 ? "it" : "them") wait unplaced until you even out on Rank."
        }
        let opened = now - was
        return "Save opens \(opened) more \(groupWord(opened)) — \(opened == 1 ? "it starts" : "they start") empty, and Even out on Rank spreads the \(kids) \(kidWord) across all \(now)."
    }

    private static func groupWord(_ count: Int) -> String {
        count == 1 ? "group" : "groups"
    }
}

/// The sentence, in the colour that says whether somebody has to do something about it.
struct VenueDealLine: View {
    let sentence: String
    /// Amber when saving will leave kids to be placed by hand.
    var isWarning: Bool = false

    var body: some View {
        Text(sentence)
            // `Theme.warning` is the design's `#B67A16`, drawn as plain text with no fill — which
            // is what that token's own note says it is for. The quiet state is `inkTertiary` and
            // not the design's `#A2A6AE`: this is body copy, and `inkFaint` is about 2.9:1 on
            // white where `inkTertiary` is 4.6:1.
            .typeStyle(.meta.lineHeight(1.5), color: isWarning ? Theme.warning : Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 7)
    }
}

// MARK: - Coaches

/// Who is standing here, chosen from the people who have actually joined.
///
/// Takes names and a selection rather than `[StaffMember]` and the store, so the block is drawn by
/// whoever has a camp to read and this file stays camp-free. The id is the caller's — a
/// `StaffMember.ID` from a live camp — and this only ever hands it back.
struct VenueCoachPicker: View {
    let coaches: [VenueCoachOption]
    let selected: Set<StaffMember.ID>
    let onToggle: (StaffMember.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ForEach(coaches) { coach in
                    let isSelected = selected.contains(coach.id)
                    Chip(
                        coach.name,
                        isSelected: isSelected,
                        // Green rather than black: a coach is a person being put somewhere, not a
                        // filter being switched on, and the design fills these `#1A7F55`.
                        selectedTone: .accent,
                        metrics: .venueCoach
                    ) {
                        onToggle(coach.id)
                    }
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }

            Text("Pick from staff who joined — puts them on a court here, and unpicking takes them off it.")
                .typeStyle(.meta.lineHeight(1.5), color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One row of the picker. A name and the id to hand back — nothing else about a `StaffMember`
/// reaches this file.
struct VenueCoachOption: Identifiable, Hashable, Sendable {
    let id: StaffMember.ID
    let name: String
}

/// What stands in the picker's place before anybody has joined: the code, and what happens when
/// somebody uses it.
///
/// The dashed plate is the idiom five screens in this section already draw by hand
/// (`VenueEmptyState.swift:76-80` names the other four) — `BorderWidth.input` at `Theme.accentBorder`
/// with a `4.5/4.5` dash, which is CSS's 1.5px dash read at three times its width.
struct VenueInviteRow: View {
    let inviteCode: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.input, style: .continuous)

        return HStack(spacing: 11) {
            Image(systemName: "lock")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.accent)
                // Decorative: the line beside it says the same thing in words.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                Text("Invite coaches · \(inviteCode)")
                    .typeStyle(.timelineTitle.tracking(em: -0.015), color: Theme.accentDark)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Coaches join with the code, land in Staff, and get assigned here.")
                    .typeStyle(.meta.lineHeight(1.5), color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.gutterWide)
        .padding(.vertical, Spacing.medium)
        .background(Theme.surface, in: shape)
        .overlay(
            shape.strokeBorder(
                Theme.accentBorder,
                style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
            )
        )
        // The code is the point of the row and it is four letters, a dash and four digits — read
        // as one word it is gibberish. Combined so VoiceOver stops once, and spelled by the label
        // rather than left to the voice.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Remove

/// "Remove this venue", and then the confirmation in the same button.
///
/// Two taps rather than a `confirmationDialog`, which is what this used to be. The design writes
/// the confirmation *as the label* — "Tap again — removes its 6 kids too" — and that is the whole
/// argument for it: an action sheet asks "are you sure" and this asks "sure about the six kids",
/// which is a different and better question, in the place the thumb already is.
///
/// The count is the caller's, because only one of the two sheets has a camp to count in.
struct VenueRemoveButton: View {
    /// How many kids go with it. Nought before the camp exists, and the label says so differently.
    let kidCount: Int
    let onRemove: () -> Void

    @State private var isConfirming = false

    var body: some View {
        PrimaryButton(
            label,
            tone: .danger,
            height: 48,
            radius: Radius.tile,
            font: .buttonCompact
        ) {
            if isConfirming {
                onRemove()
            } else {
                isConfirming = true
            }
        }
        // The label changes under the finger, and a button whose *words* change is one VoiceOver
        // will re-read on the next focus and not before. Saying it out loud is the only way the
        // second tap is not a silent one.
        .accessibilityLabel(label)
        .accessibilityHint(isConfirming ? "" : "Asks again before removing")
        // Arming is not a decision, so it does not survive the reader looking away — and a button
        // left armed under a sheet that was scrolled past is a removal one stray tap away.
        .onDisappear { isConfirming = false }
    }

    private var label: String {
        guard isConfirming else { return "Remove this venue" }
        guard kidCount > 0 else { return "Tap again — removes it for good" }
        return "Tap again — removes its \(kidCount) \(kidCount == 1 ? "kid" : "kids") too"
    }
}

// MARK: - Previews

/// The four shapes of a band, stacked, because the control changes height as it changes shape and
/// that is the thing worth looking at: "All ages" is a bare chip row, and only a narrowed venue
/// pays for a card.
#Preview("Age band — the four shapes") {
    @Previewable @State var bands: [AgeBand] = [.all, .upTo(11), .from(12), .between(9, 12)]

    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.large) {
            ForEach(bands.indices, id: \.self) { index in
                VenueFieldLabel(title: bands[index].label, topPadding: 0)
                VenueAgeBandPicker(ageBand: $bands[index])
            }
        }
        .padding(Spacing.sheet)
    }
    .background(Theme.surface)
}

#Preview("Venue shape fields") {
    @Previewable @State var ageBand = AgeBand.all
    @Previewable @State var courts = 6
    @Previewable @State var groups = 4
    @Previewable @State var target: Int? = nil
    @Previewable @State var picked: Set<StaffMember.ID> = []

    let staff = SampleData.uclaTennisCamp.staff.prefix(3).map {
        VenueCoachOption(id: $0.id, name: $0.name)
    }

    return ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            VenueFieldLabel(title: "Age group", topPadding: 0)
            VenueAgeBandPicker(ageBand: $ageBand)

            VenueFieldLabel(title: "Numbers")
            VenueCountsCard(
                courtNoun: "court",
                courts: $courts,
                groups: $groups,
                targetPerGroup: $target
            )
            VenueDealLine(sentence: VenueDealSentence.adding(groups: groups))

            VenueFieldLabel(title: "Coaches", note: "optional")
            VenueCoachPicker(coaches: staff, selected: picked) { id in
                if picked.contains(id) { picked.remove(id) } else { picked.insert(id) }
            }

            VenueFieldLabel(title: "Nobody has joined")
            VenueInviteRow(inviteCode: SampleData.uclaTennisCamp.inviteCode)

            VenueRemoveButton(kidCount: 6) {}
                .padding(.top, Spacing.large)
        }
        .padding(Spacing.sheet)
    }
    .background(Theme.surface)
}
