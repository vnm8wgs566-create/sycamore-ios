//
//  GroupsRow.swift
//  Sycamore
//
//  `1   Serene Chu                    ♀ ⏱   ≡`
//
//  The one line of layout `8o` draws four times: a kid in a group card, "+3 more" under them,
//  and — in `8p` — the card that carries a kid between groups.
//
//  It is one type rather than four spellings because the lifted card is drawn *directly over*
//  the row it came out of. Any drift between them shows as a jump at the moment of pick-up: the
//  name shifting sideways, the numeral changing width. They were two copies of this until the
//  leading inset had already diverged by 2pt.
//
//  The design varies weight and colour between the four, and nothing else. So those are the
//  parameters, and the geometry — the numeral column, the 11pt gap, the alignment — is not.
//

import SwiftUI

struct GroupsRow<Trailing: View>: View {

    /// Nil leaves the column empty. "+3 more" keeps the indent without wearing a number.
    let rank: Int?
    let rankColor: Color
    let name: String
    let nameStyle: TypeStyle
    let nameColor: Color
    @ViewBuilder let trailing: Trailing

    /// The rank column grows with the reader's type size, or a two-digit place lands in a 20pt
    /// box and truncates. `.callout` is the ramp a 13pt style rides, so the column and the
    /// numeral in it grow at exactly the same rate.
    @ScaledMetric(relativeTo: .callout) private var numeralWidth = GroupsMetrics.numeralWidth

    init(
        rank: Int?,
        rankColor: Color = Theme.chevron,
        name: String,
        nameStyle: TypeStyle = GroupsType.playerName,
        nameColor: Color = Theme.inkWarm,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.rank = rank
        self.rankColor = rankColor
        self.name = name
        self.nameStyle = nameStyle
        self.nameColor = nameColor
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Spacing.row) {
            // An empty string rather than a branch: the frame reserves the column either way, so
            // "+3 more" lines up with the names above rather than with their ranks, and the row
            // keeps one structural identity instead of two.
            Text(rank.map { "\($0)" } ?? "")
                .typeStyle(GroupsType.rowMeta, color: rankColor)
                .frame(width: numeralWidth, alignment: .trailing)

            Text(name)
                .typeStyle(nameStyle, color: nameColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
    }
}

extension GroupsRow where Trailing == EmptyView {
    init(
        rank: Int?,
        rankColor: Color = Theme.chevron,
        name: String,
        nameStyle: TypeStyle = GroupsType.playerName,
        nameColor: Color = Theme.inkWarm
    ) {
        self.init(
            rank: rank,
            rankColor: rankColor,
            name: name,
            nameStyle: nameStyle,
            nameColor: nameColor
        ) { EmptyView() }
    }
}

// MARK: - Previews

#Preview("Row shapes") {
    VStack(spacing: 0) {
        GroupsRow(rank: 1, name: "Serene Chu") {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: GroupsMetrics.handleGlyph, weight: .regular))
                .foregroundStyle(Theme.glyphFaint)
        }
        GroupsRow(rank: 10, name: "Austin Zheng") {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: GroupsMetrics.handleGlyph, weight: .regular))
                .foregroundStyle(Theme.glyphFaint)
        }
        GroupsRow(rank: nil, name: "+3 more", nameStyle: GroupsType.moreRow, nameColor: Theme.inkFaint)

        GroupsRow(
            rank: 3,
            rankColor: Theme.accent,
            name: "Austin Zheng",
            nameStyle: GroupsType.liftedName,
            nameColor: Theme.ink
        ) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: GroupsMetrics.handleGlyph, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, GroupsMetrics.cardPadding)
        .padding(.vertical, Spacing.medium)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .padding(.top, Spacing.large)
    }
    .padding(GroupsMetrics.cardPadding)
    .background(Theme.surfaceWarm)
}
