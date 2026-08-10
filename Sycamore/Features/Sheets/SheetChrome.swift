//
//  SheetChrome.swift
//  Sycamore
//
//  The scaffold all four stage-3 sheets are built on, plus the two layout helpers they share.
//
//  Every sheet in the design is the same shape: a 24pt-rounded white plate pinned to the bottom
//  of the frame, a grabber, a title block with a 32pt circular close button, then content on an
//  18pt gutter. The only variation is the staff sheet, which puts a 46pt avatar left of its
//  title and drops the title a point smaller.
//

import SwiftUI

// MARK: - Sheet chrome

struct SheetChrome<Content: View>: View {
    let title: String
    var subtitle: String?
    /// The staff sheet is the only one with anything left of its title.
    var avatarInitials: String?
    var avatarTone: AvatarTone
    /// The design's sheet height over the 700pt frame it was drawn in — 562/700, 472/700, …
    var detentFraction: Double
    let onClose: () -> Void
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        avatarInitials: String? = nil,
        avatarTone: AvatarTone = .neutral,
        detentFraction: Double,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarInitials = avatarInitials
        self.avatarTone = avatarTone
        self.detentFraction = detentFraction
        self.onClose = onClose
        self.content = content()
    }

    private var hasAvatar: Bool { avatarInitials != nil }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sheet)
                .padding(.bottom, Spacing.sheet)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Every sheet in the app puts its commit button at the foot of this scroller, and a
            // keyboard covers the foot. `AddPlayerView.swift:130-132` states the rule from the
            // screen that learned it — "the pinned Add sits under the keyboard while it is up" —
            // and pairs the drag with a Done bar, because a drag is the way out you find by
            // accident and a bar is the one you can be told about.
            //
            // Here rather than on the sheets, which is the one change this scaffold needed: it is
            // true of all four of them, and a sheet that forgot it would be a Save button nobody
            // could reach. Cheap on the sheets with no field in them — with no keyboard up there
            // is nothing to dismiss.
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(.rect(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet))
        .sheetPresentation(fraction: detentFraction)
    }

    // MARK: Header

    /// `9px 18px 13px`, or `9px 18px 14px` and centred once an avatar joins the row.
    private var header: some View {
        HStack(alignment: hasAvatar ? .center : .top, spacing: hasAvatar ? 12 : 10) {
            if let avatarInitials {
                InitialsAvatar(avatarInitials, size: 46, tone: avatarTone)
            }

            VStack(alignment: .leading, spacing: hasAvatar ? 2 : 3) {
                Text(title)
                    .typeStyle(hasAvatar ? .sheetTitleSm : .sheetTitle, color: Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .typeStyle(.sheetSubtitle, color: Theme.inkMuted)
                }
            }

            Spacer(minLength: 0)

            CircleIconButton(
                systemName: "xmark",
                size: 32,
                tone: .filled,
                foreground: Theme.inkTertiary,
                action: onClose
            )
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.sheet)
        .padding(.top, 9)
        .padding(.bottom, hasAvatar ? 14 : 13)
    }
}

// MARK: - Presentation

extension View {
    /// The design's detent plus the 24pt top radius. We draw our own grabber, so the system
    /// drag indicator stays hidden.
    func sheetPresentation(fraction: Double) -> some View {
        #if os(iOS)
        return self
            .presentationDetents([.fraction(fraction), .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Theme.surface)
        #else
        return self
        #endif
    }
}

// MARK: - Section header

/// The uppercase overline above a block inside a sheet.
///
/// `SectionHeader` carries a 4pt horizontal inset because it labels a grouped card that is itself
/// inset; a sheet's blocks sit flush against the 18pt gutter, so this variant has none.
struct SheetSectionHeader: View {
    let title: String
    var topPadding: CGFloat
    var bottomPadding: CGFloat

    init(_ title: String, topPadding: CGFloat = 0, bottomPadding: CGFloat = 9) {
        self.title = title
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
    }

    var body: some View {
        Text(title)
            .typeStyle(.sectionHeader, color: Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }
}

// MARK: - Flow layout

/// `flex-wrap: wrap` — lays children out left to right and starts a new line when the next one
/// would overflow. The design wraps time pills, icon tiles and court chips this way.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 7
    var verticalSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        wrap(subviews, within: proposal.replacingUnspecifiedDimensions().width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = wrap(subviews, within: bounds.width)
        for (subview, frame) in zip(subviews, result.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    /// One wrapping pass: each child's frame in local coordinates, plus the union size.
    private func wrap(_ subviews: Subviews, within width: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var pen = CGPoint.zero
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            // Break before placing, never after, so a line that exactly fills the width does
            // not leave a trailing empty row.
            if pen.x > 0, pen.x + size.width > width {
                pen.x = 0
                pen.y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: pen, size: size))
            pen.x += size.width + horizontalSpacing
            widest = max(widest, pen.x - horizontalSpacing)
            lineHeight = max(lineHeight, size.height)
        }

        return (frames, CGSize(width: widest, height: pen.y + lineHeight))
    }
}

// MARK: - Previews

#Preview("Sheet chrome") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()

        SheetChrome(
            title: "Austin Z",
            subtitle: "Sycamore · Court 1 · Nass",
            detentFraction: 0.80,
            onClose: {}
        ) {
            SheetSectionHeader("Leaves at")
            FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ForEach(TimeOfDay.pickupOptions) { time in
                    Chip(
                        time.formatted,
                        isSelected: time == TimeOfDay(14, 30),
                        selectedTone: .tintedBold,
                        metrics: .time
                    )
                }
            }
        }
        .frame(height: 562)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}

#Preview("Sheet chrome — with avatar") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()

        SheetChrome(
            title: "Alex",
            subtitle: "Worker · Sycamore · Court 3",
            avatarInitials: "AL",
            detentFraction: 0.73,
            onClose: {}
        ) {
            SheetSectionHeader("Role")
            HStack(spacing: 6) {
                ForEach(Role.selectable, id: \.self) { role in
                    Chip(
                        role.chipTitle,
                        isSelected: role == .worker,
                        selectedTone: .dark,
                        metrics: .role,
                        fillsWidth: true
                    )
                }
            }
        }
        .frame(height: 512)
    }
    .frame(height: 700)
    .background(Theme.canvas)
}
