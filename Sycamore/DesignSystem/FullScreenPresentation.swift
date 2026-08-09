//
//  FullScreenPresentation.swift
//  Sycamore
//
//  Two platform facts about giving a screen the whole frame, each written once.
//
//  A cover on iOS, a sheet everywhere else — and hiding the navigation bar underneath whichever
//  one it is.
//
//  `fullScreenCover` is iOS-only and everything under `Sycamore/` has to typecheck for macOS as
//  well — see `Package.swift` — so every screen the design gives the whole frame to needs the
//  same three-line `#if`. There were two private copies of it carrying the same comment,
//  `RootView.pushedScreenCover` for `8m`/`8q`/the court screen and `ScheduleView.blockDetailCover`
//  for `8l`, and the enrolment flow made a third. Two identical private extensions is a
//  coincidence; three is a component.
//
//  It lives in `DesignSystem/` rather than beside any one caller because none of the three owns
//  it, and because what it encodes is a fact about the *platform* — the same kind of thing
//  `Motion.fold(reduceMotion:)` and `HitTarget.minimum` encode.
//
//  Two forms, matching the two SwiftUI already gives:
//
//  - `item:` for a screen chosen out of a value, which is what `store.pushedScreen` and the opened
//    block both are.
//  - `isPresented:` for a screen with nothing to choose. `EnrolmentFlowView` is presented from
//    Groups and from Camp settings, and neither has a value to hand over: the flow reads the camp
//    it is already standing in.
//
//  Deliberately not one form with an `Optional<Void>` shim over it. The two SwiftUI modifiers are
//  genuinely different signatures — `item:` re-presents when the value changes and `isPresented:`
//  does not — and collapsing them would mean writing that difference back out at the call sites.
//

import SwiftUI

extension View {

    /// Presents `content` over the whole frame, chosen out of `item`.
    @ViewBuilder
    func fullScreenPresentation<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }

    /// Presents `content` over the whole frame while `isPresented` is true.
    @ViewBuilder
    func fullScreenPresentation<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }

    /// Hides the navigation bar, for a screen that draws its own header and its own way back.
    ///
    /// `toolbar(_:for:)` with `.navigationBar` is iOS-only, so this was the same three-line `#if`
    /// at four screens — and the pattern it forced was worse than the `#if` itself: each one had
    /// to bind its whole `body` to a `let screen` and end in two `return`s, because a `#if` cannot
    /// sit inside a `ViewBuilder` chain. Behind a modifier the callers get one expression back.
    ///
    /// A no-op off iOS rather than an error: a Mac window has no navigation bar to hide, so there
    /// is nothing for the caller to do differently.
    @ViewBuilder
    func hidesNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
