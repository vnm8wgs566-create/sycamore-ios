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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            progress
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

    /// The design's 4pt track. The fill is scaled rather than measured: at 4pt tall the capsule's
    /// 2pt ends distort by well under a point, and that keeps the bar free of geometry readers.
    private var progress: some View {
        let fraction = total == 0 ? 0 : Double(markedCount) / Double(total)

        return HStack(spacing: Spacing.row) {
            Capsule()
                .fill(Theme.hairline)
                .frame(height: OnTheDayTokens.progressHeight)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.accent)
                        .scaleEffect(x: fraction, y: 1, anchor: .leading)
                }
                .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: fraction)

            Text("\(markedCount) of \(total)")
                .typeStyle(.metaSmall, color: Theme.inkSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marked")
        .accessibilityValue("\(markedCount) of \(total)")
        // Read out as the count moves rather than only when the header is swiped to, so a coach
        // running VoiceOver hears the list shrink without leaving the row they are on.
        .accessibilityAddTraits(.updatesFrequently)
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
