//
//  VenueCourtStepper.swift
//  Sycamore
//
//  The −/6/+ control on the right of every venue row in `8t`. It sets how many courts the venue
//  has, which is a write to the camp, so it cannot drive `StepperControl` from the model
//  directly: the value has to settle locally and then be sent.
//
//  A view of its own rather than a binding built in `SetupView.body`. `StepperControl` wants a
//  real `Binding<Int>`, and the only way to make one out of `venue.groupCount` inside a body is
//  `Binding(get:set:)` — which is rebuilt on every pass and fires a write from inside view
//  evaluation. Local `@State` plus `onChange` keeps the write on the far side of the render.
//

import SwiftUI

struct VenueCourtStepper: View {

    let venue: Venue
    /// Called with the new court count once the reader has actually pressed a button.
    let onChange: (Int) -> Void

    @State private var count: Int

    init(venue: Venue, onChange: @escaping (Int) -> Void) {
        self.venue = venue
        self.onChange = onChange
        self._count = State(initialValue: venue.groupCount)
    }

    var body: some View {
        StepperControl(
            value: $count,
            range: CampDraft.groupRange,
            valueWidth: 28,
            glyphSize: 14
        )
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
        .accessibilityLabel("Courts at \(venue.name)")
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
