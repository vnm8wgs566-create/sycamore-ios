//
//  PickupTarget.swift
//  Sycamore
//
//  The kid `8n` is being opened for, from a screen that presents `8n` itself.
//
//  `MainTabView` presents `EarlyPickupSheet` through `store.activeSheet`, and that is the right
//  route from a tab. It is the wrong one from `8m` or `8q`: both of those are presented screens,
//  and a presented screen cannot ask the root — which is underneath it — to present over it. So
//  each carries its own `.sheet(item:)` and this is what it binds.
//
//  A wrapper rather than the id itself because `Player.ID` is a `UUID`, and `.sheet(item:)` wants
//  something `Identifiable`.
//

import Foundation

struct PickupTarget: Identifiable, Hashable, Sendable {
    let id: Player.ID
}
