//
//  VenueShapeAdapter.swift
//  Sycamore
//
//  A venue that exists, described as a row somebody drew.
//
//  `AddPlayerView` takes `venues: [VenueShape]` (`AddPlayerView.swift:27`) and reads exactly two
//  things off them: `.id`, to know which chip is selected, and `.name`, to letter it. Everything
//  else on `VenueShape` — the courts, the two head counts, the emoji — is `8b`'s business and is
//  never touched by that screen.
//
//  So this is a small lie, told deliberately. `VenueShape`'s own header calls it "one row of
//  `8b`'s VENUES card", and handing one to a screen reached from *inside* a camp says the venue is
//  a sketch when it is a real row in Postgres.
//
//  It is told anyway, because both alternatives are worse:
//
//  - **A second vocabulary.** A `VenuePick { id, name }` protocol, or a generic `AddPlayerView`,
//    means two names for one idea across a flow whose whole point is that the same three screens
//    serve onboarding and re-enrolment. The next reader has to learn which of the two a given call
//    site is in.
//  - **Changing the signature.** `AddPlayerView` is drawn to the pixel against `8e` and is the
//    Fix screen for every `IntakeIssue`. Reopening it to take `[Venue]` — or an array of tuples —
//    is a change to a screen this unit had no other reason to touch.
//
//  The conversion is one-way on purpose. Nothing reads a `VenueShape` back into a `Venue`: what
//  comes out of `8e` is an `IntakePlayer` carrying a `venueIndex`, a *position*, which
//  `AppStore.applyRoster` resolves against the venues it was handed. The id below is carried
//  across rather than freshly minted so that position and identity agree if anything ever wants
//  both.
//

import Foundation

extension Venue {

    /// This venue as `8b` would have drawn it — enough of one for a chip row.
    var shape: VenueShape {
        VenueShape(
            id: id,
            name: name,
            subtitle: subtitle,
            icon: icon,
            courts: groupCount,
            ageBand: ageBand,
            maxKids: playerMax,
            minCoaches: coachMin
        )
    }
}
