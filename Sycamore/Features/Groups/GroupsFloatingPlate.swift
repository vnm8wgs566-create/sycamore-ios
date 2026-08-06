//
//  GroupsFloatingPlate.swift
//  Sycamore
//
//  The frosted capsule the design floats over a screen: a blur, a tinted plate on top of it, a
//  half-point ring around it, and a catch of light along the top edge only.
//
//  `FloatingTabBar` draws exactly this in `DesignSystem/TabBar.swift`, and `8p` puts the move
//  bar on the same plate directly above it — two pills on screen together, which is precisely
//  the case where a copy that has drifted is visible side by side.
//
//  So this is the three layers named once, inside the feature that noticed. It is still a copy:
//  the original cannot be shared until it moves out of `TabBar.swift` into the design system,
//  which is a change to a file this work does not own. **Hoist candidate** — lift this file into
//  `DesignSystem` as `floatingPlate()` and have `FloatingTabBar` call it too.
//

import SwiftUI

struct GroupsFloatingPlate: ViewModifier {

    func body(content: Content) -> some View {
        content
            .background(plate)
            .overlay { ring }
            .overlay { lip }
            .shadow(Shadows.tabBar)
    }

    /// `rgba(250,250,251,.82)` over a blur.
    private var plate: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay { Capsule(style: .continuous).fill(Theme.tabBarPlate) }
    }

    /// `0 0 0 .5px rgba(11,11,12,.07)`.
    private var ring: some View {
        Capsule(style: .continuous)
            .strokeBorder(Theme.ink.opacity(0.07), lineWidth: BorderWidth.ring)
    }

    /// `inset 0 1px 0 rgba(255,255,255,.95)` — light along the top edge only.
    private var lip: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Theme.tabBarLip, Theme.tabBarLip.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: BorderWidth.hairline
            )
            .allowsHitTesting(false)
    }
}

extension View {
    /// Prefixed rather than named `floatingPlate()`, so that the day the design system grows
    /// the real one there is no ambiguity about which of the two a call site meant.
    func groupsFloatingPlate() -> some View {
        modifier(GroupsFloatingPlate())
    }
}
