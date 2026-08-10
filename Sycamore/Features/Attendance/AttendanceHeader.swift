//
//  AttendanceHeader.swift
//  Sycamore
//
//  `8m`'s white header block: the way out, what session this is, the serif title, and how far
//  through the list you are.
//
//  Its own view rather than a helper on `AttendanceView` because it redraws on a different beat.
//  The roll below it changes shape on every answer; up here only two numbers move, and keeping
//  them apart means the progress bar's spring is not re-evaluated alongside twenty-two rows.
//

import SwiftUI

struct AttendanceHeader: View {

    /// "Skills rotation · 9:00–10:30", or the courts when the session has no block.
    let sessionLine: String
    let markedCount: Int
    let total: Int
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.tight) {
                closeButton
                Text(sessionLine)
                    .typeStyle(.onTheDayCrumb, color: Theme.inkMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            // The glyph is centred in a 44pt frame, so 8pt here puts it on the design's 22pt
            // gutter without the hit region eating into the title below.
            .padding(.horizontal, Spacing.small)

            OnTheDayTitle("Attendance")
                .padding(.horizontal, Spacing.header)
                .padding(.top, OnTheDayTokens.headerTop)

            // The 4pt track is shared now — `4c`'s first sort draws the same bar with a different
            // figure beside it, which is what took it out of this file. The two arguments that
            // used to be made here, for scaling the fill rather than measuring it and for gating
            // the spring on Reduce Motion, went with it (`Components.swift`, `ProgressTrack`).
            ProgressTrack(
                value: markedCount,
                total: total,
                label: "\(markedCount) of \(total)",
                labelStyle: .metaSmall,
                labelColor: Theme.inkSecondary,
                accessibilityLabel: "Marked"
            )
            .padding(.horizontal, Spacing.header)
            .padding(.top, OnTheDayTokens.headerTop)
        }
        .padding(.bottom, OnTheDayTokens.headerBottom)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close attendance")
    }
}

// MARK: - Previews

#Preview("Header") {
    VStack(spacing: 0) {
        AttendanceHeader(
            sessionLine: "Skills rotation · 9:00am – 10:30am",
            markedCount: 20,
            total: 22,
            onClose: {}
        )
        Hairline(color: Theme.hairline)
        Spacer(minLength: 0)
    }
    .background(Theme.surface)
    .frame(maxHeight: 260)
}
