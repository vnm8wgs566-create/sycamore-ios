//
//  IntakeTouchTarget.swift
//  Sycamore
//
//  Section 8 draws several controls under Apple's 44pt minimum — a 28pt stepper button, a 33pt
//  answer chip, a 34pt Switch — and shrinking the design is not the fix.
//

import SwiftUI

extension View {

    /// Grows what takes the touch to the 44pt minimum without moving what is drawn.
    ///
    /// `.frame(minWidth:minHeight:)` — the usual fix — grows the *layout* too, which on a stepper
    /// means the grey track stretches 30pt wider than the design draws it. Padding out, fixing
    /// the content shape at that size and then padding back in leaves the parent laying this out
    /// at its drawn size while the touch area stays 44pt. The overflow stays inside the enclosing
    /// card in every use here, so no ancestor's clip shape cuts it off.
    func intakeTouchTarget(inset: CGFloat) -> some View {
        padding(inset)
            .contentShape(.rect)
            .padding(-inset)
    }
}
