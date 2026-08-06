//
//  PickupTarget.swift
//  Sycamore
//
//  The kid `8n` is being opened for, from a screen that presents `8n` itself.
//
//  `8m` and `8q` are the only two ways into `8n`, and both of them are presented screens. A
//  presented screen cannot ask the root — which is underneath it — to present over it, so each
//  carries its own `.sheet(item:)` and this is what it binds. Nothing routes `8n` through
//  `store.activeSheet` any more; there is no third caller left that could.
//
//  A wrapper rather than the id itself because `Player.ID` is a `UUID`, and `.sheet(item:)` wants
//  something `Identifiable`.
//

import Foundation

struct PickupTarget: Identifiable, Hashable, Sendable {
    let id: Player.ID
}
