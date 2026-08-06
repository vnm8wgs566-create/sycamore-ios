//
//  AttendanceAnswerCard.swift
//  Sycamore
//
//  The card `8m` puts under "Still to mark": a name, the two answers, and the way out to `8n`.
//
//  This is the most-tapped control in the app — somebody stands on a court with wet hands and
//  works down this list several times a day. So the two answers are drawn as the design has
//  them (42pt tall, half the card each) and given a 44pt hit region on top, `Here` carries the
//  filled accent because most kids are here, and neither of them is a row you can graze on the
//  way past: they are separated by 8pt and nothing else on the card is tappable except the
//  pick-up line at the foot.
//

import SwiftUI

struct AttendanceAnswerCard: View {

    let entry: AttendanceEntry
    let onHere: () -> Void
    let onAway: () -> Void
    let onLeavingEarly: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: OnTheDayTokens.card, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            name
            answers
                .padding(.top, Spacing.row)
            Hairline(color: Theme.hairlineSoft)
                .padding(.top, Spacing.row)
            leavingEarly
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OnTheDayTokens.cardInset)
        .padding(.vertical, Spacing.medium)
        .background(Theme.surface, in: shape)
        .overlay { shape.strokeBorder(Theme.hairline, lineWidth: BorderWidth.hairline) }
    }

    // MARK: Name

    private var name: some View {
        HStack(spacing: Spacing.row) {
            Text("\(entry.rank)")
                .typeStyle(.rankNumeral.weight(.regular), color: Theme.chevron)
                .frame(width: OnTheDayTokens.rankColumn, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .typeStyle(.bodyStrong, color: Theme.ink)
                    .lineLimit(1)
                if let courtLabel = entry.courtLabel {
                    Text(courtLabel)
                        .typeStyle(.rowSubtitle, color: Theme.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Answers

    private var answers: some View {
        HStack(spacing: Spacing.small) {
            answer("Here", systemImage: "checkmark", isPrimary: true, action: onHere)
            answer("Away", systemImage: "person.badge.minus", isPrimary: false, action: onAway)
        }
    }

    /// Drawn at the design's 42pt; the frame outside it carries the touch up to 44 without
    /// moving a pixel. The same trick the stepper and the sheet close button use.
    private func answer(
        _ title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)

        return Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .typeStyle(.buttonCompact)
            }
            .foregroundStyle(isPrimary ? Theme.onAccent : Theme.inkSecondary)
            .padding(.horizontal, Spacing.small)
            .frame(maxWidth: .infinity)
            // `minHeight`, not `height`: at the larger Dynamic Type sizes the label outgrows the
            // design's 42pt and a hard frame would clip the one word that matters.
            .frame(minHeight: OnTheDayTokens.answerHeight)
            .background(isPrimary ? Theme.accent : Theme.surface, in: shape)
            .overlay {
                if !isPrimary {
                    shape.strokeBorder(Theme.stroke, lineWidth: BorderWidth.hairline)
                }
            }
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark \(entry.name) \(title.lowercased())")
    }

    // MARK: Leaving early

    private var leavingEarly: some View {
        Button(action: onLeavingEarly) {
            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.accent)
                Text(entry.pickupLine ?? "Leaving early")
                    .typeStyle(.metaStrong, color: Theme.accent)
                    .lineLimit(1)
                Spacer(minLength: 0)
                DisclosureChevron(size: 14)
            }
            // No padding of its own: the 44pt hit frame already supplies the design's air above
            // and below, and adding both would double it.
            .frame(minHeight: HitTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pick-ups for \(entry.name)")
        .accessibilityValue(entry.pickupLine ?? "None set")
    }
}

// MARK: - Previews

#Preview("Answer card") {
    VStack(spacing: Spacing.small) {
        AttendanceAnswerCard(
            entry: AttendanceEntry(
                id: SampleData.austinZ.id,
                name: "Austin Z",
                rank: 3,
                courtLabel: "Court 1",
                isAway: false,
                leavesAt: nil
            ),
            onHere: {}, onAway: {}, onLeavingEarly: {}
        )

        AttendanceAnswerCard(
            entry: AttendanceEntry(
                id: SampleData.sereneC.id,
                name: "Serene C",
                rank: 11,
                courtLabel: nil,
                isAway: false,
                leavesAt: TimeOfDay(14, 30)
            ),
            onHere: {}, onAway: {}, onLeavingEarly: {}
        )
    }
    .padding(Spacing.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.grouped)
}
