//
//  ScheduleShapesCard.swift
//  Sycamore
//
//  The second half of `8f` — "Or start from a shape".
//
//  Three ready-made days and, tucked inside the same card on its own faintly raised row, the
//  fourth: copy the one that already works. The design puts it *in* the card rather than under
//  it, which is the point — copying Monday is another way to shape Friday, not a footnote about
//  the three above it.
//

import SwiftUI

struct ScheduleShapesCard: View {

    let day: Weekday
    let onApply: (DayShape) -> Void
    let onCopyMonday: () -> Void

    /// Grows with the two lines beside it, which is what keeps the row square at
    /// `.accessibility1` instead of leaving a 34pt stamp beside type half again as tall.
    @ScaledMetric(relativeTo: .body) private var tileSize = ScheduleMetrics.shapeTile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `ScheduleType.overline` a hair wider: the two card overlines on `8l` are tracked
            // at `.14em`, this one at `.15em`.
            Text("Or start from a shape")
                .typeStyle(ScheduleType.overline.tracking(em: 0.15), color: Theme.inkMuted)
                .padding(.horizontal, ScheduleMetrics.shapeOverlineInset)
                .padding(.bottom, ScheduleMetrics.shapeOverlineBottom)
                .accessibilityAddTraits(.isHeader)

            Card(radius: ScheduleMetrics.cardRadius) {
                ForEach(DayShape.allCases) { shape in
                    shapeRow(shape)
                }

                // Not offered on Monday, where it would copy the day onto itself.
                if day != .mon {
                    copyMondayRow
                }
            }
        }
    }

    private func shapeRow(_ shape: DayShape) -> some View {
        Button {
            onApply(shape)
        } label: {
            CardRow(verticalPadding: Spacing.medium) {
                tile(shape)

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(shape.title)
                        .typeStyle(ScheduleType.shapeTitle, color: Theme.ink)
                    Text(shape.detail)
                        .typeStyle(ScheduleType.shapeDetail, color: Theme.inkMuted)
                }

                Spacer(minLength: Spacing.small)

                DisclosureChevron()
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Fills \(day.fullName) with this shape")
    }

    private func tile(_ shape: DayShape) -> some View {
        let plate = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)

        return plate
            .fill(Theme.accentSurface)
            .frame(width: tileSize, height: tileSize)
            .overlay { plate.strokeBorder(Theme.accentSurfaceBorder, lineWidth: BorderWidth.hairline) }
            .overlay {
                DisclosureChevron(systemName: shape.symbol,
                                  size: ScheduleMetrics.shapeGlyph,
                                  color: Theme.accent)
            }
            .accessibilityHidden(true)
    }

    private var copyMondayRow: some View {
        Button(action: onCopyMonday) {
            CardRow(verticalPadding: Spacing.medium) {
                Text("Copy Monday instead")
                    .typeStyle(ScheduleType.inlineAction, color: Theme.accent)

                Spacer(minLength: Spacing.small)

                DisclosureChevron(systemName: "doc.on.doc", size: 15, color: Theme.accent)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
            .background(Theme.surfaceRaised)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Copies Monday's blocks onto \(day.fullName)")
    }
}

// MARK: - Previews

#Preview("Day shapes") {
    ScheduleShapesCard(day: .fri, onApply: { _ in }, onCopyMonday: {})
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
}
