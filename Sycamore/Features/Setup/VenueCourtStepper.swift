//
//  VenueCourtStepper.swift
//  Sycamore
//
//  The −/6/+ control on the right of every venue row in `8t`. It sets how many **groups** the
//  venue splits its kids into, which is a write to the camp, so the value has to settle locally
//  and then be sent.
//
//  Groups, despite the name on the file. It reads and writes `Venue.groupCount`, and it always
//  has — the model has only lately grown a `courtCount` to sit beside it, so until then "courts"
//  and "groups" were one number and calling this a court stepper was true. It is not any more:
//  `groupCount` is how many `Group` records `syncGroups(for:)` keeps, and moving this adds or
//  deletes courts and rehomes whoever was standing on them. What it is *not* is a statement about
//  how many courts exist on the ground, which is what a reader hearing "Courts at Sycamore" would
//  reasonably take it for — so the spoken label says groups.
//
//  The type keeps its name because its caller does (`SetupView.setCourts`), and `Features/Setup`
//  is not this change's to rename. The venue sheet is where both numbers can be set apart.
//
//  Drawn here rather than through `StepperControl` because `8t`'s stepper is not that stepper.
//  The shared one comes from "Shape" and the venue sheet, where the buttons are 34×32 and both
//  glyphs are ink; this one draws 28×28 and colours the two glyphs differently — minus in
//  `inkSecondary`, plus in `accent` — because adding a court is the move the screen is
//  encouraging and taking one away is not. Those are parameters `StepperControl` does not have,
//  and adding them means editing `DesignSystem/`.
//
//  Local `@State` plus `onChange` keeps the write on the far side of the render: a
//  `Binding(get:set:)` built in a body is rebuilt every pass and fires its setter from inside
//  view evaluation.
//

import SwiftUI

struct VenueCourtStepper: View {

    let venue: Venue
    /// Called with the new court count once the reader has actually pressed a button.
    let onChange: (Int) -> Void

    @State private var count: Int

    /// `28×28` buttons and a `28`-wide readout. Scaled because the number between them is text,
    /// and a court count clipped to "1…" is worse than a stepper that has grown a little.
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 28

    /// `padding:3px` on the grey track the two buttons sit in.
    private let trackInset: CGFloat = 3

    private var range: ClosedRange<Int> { CampDraft.groupRange }

    init(venue: Venue, onChange: @escaping (Int) -> Void) {
        self.venue = venue
        self.onChange = onChange
        self._count = State(initialValue: venue.groupCount)
    }

    var body: some View {
        HStack(spacing: Spacing.hairGap) {
            button("minus", tint: Theme.inkSecondary, enabled: count > range.lowerBound) {
                count = max(range.lowerBound, count - 1)
            }

            Text("\(count)")
                .typeStyle(.stepperCount, color: Theme.ink)
                .frame(minWidth: valueWidth)
                .multilineTextAlignment(.center)

            button("plus", tint: Theme.accent, enabled: count < range.upperBound) {
                count = min(range.upperBound, count + 1)
            }
        }
        .padding(trackInset)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .onChange(of: count) { _, new in
            guard new != venue.groupCount else { return }
            onChange(new)
        }
        // Adding or trimming courts round-trips the whole camp, and a rejected write leaves
        // `groupCount` where it was. Follow the model back so the stepper never sits on a number
        // the venue does not hold.
        .onChange(of: venue.groupCount) { _, saved in
            if saved != count { count = saved }
        }
        .sensoryFeedback(.selection, trigger: count)
        // One adjustable control rather than two buttons and a label. VoiceOver and Switch
        // Control then drive it by swiping up and down, which is the whole point of a stepper —
        // and it means neither 28pt glyph has to be found and hit individually.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Groups at \(venue.name)")
        .accessibilityValue("\(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if count < range.upperBound { count += 1 }
            case .decrement: if count > range.lowerBound { count -= 1 }
            @unknown default: break
            }
        }
    }

    private func button(
        _ symbol: String,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(enabled ? tint : Theme.inkGhost)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Radius.stepperButton, style: .continuous)
                )
                // The white button still draws 28×28; the frame outside it only carries the tap.
                // It widens the grey track past the design's 94pt, which is the trade the rest of
                // this app already makes wherever a drawn control lands under 44.
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Previews

#Preview("Venue court stepper") {
    VStack(spacing: Spacing.large) {
        VenueCourtStepper(venue: SampleData.sycamore) { _ in }
        VenueCourtStepper(venue: SampleData.latc) { _ in }
    }
    .padding(Spacing.bar)
    .background(Theme.surface)
}
