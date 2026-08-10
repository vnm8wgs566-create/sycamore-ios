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

/// Where a sheet's subtitle sits relative to its title.
///
/// The string is the same either way — a venue and a day, a block and its hours — so this is an
/// order, not a second field. Splitting it into an `eyebrow:` parameter beside `subtitle:` would
/// have given four sheets two ways to say one thing and no way to say both.
enum SheetSubtitlePlacement: Sendable {
    /// Under the title, `.sheetSubtitle` — every sheet the app shipped with.
    case belowTitle
    /// Above the title, `.rowDetail` — `Tuesday · Sycamore` over `Edit block`
    /// (`design/rebuild/section-t5.html:61-62`).
    ///
    /// Half a point smaller than the subtitle below, which is the design's own distinction: a line
    /// under a title is a continuation of it, and a line over one is a place-marker you read first
    /// and then stop reading. The design draws it in the same `#8A8E96` either way.
    case eyebrow
}

struct SheetChrome<Content: View>: View {
    let title: String
    var subtitle: String?
    /// Defaulted to `.belowTitle`, which is what the app's four original sheets draw. The block
    /// editor is the only caller that inverts it, and a default of anything else would have
    /// silently redrawn the header of every other sheet in the app.
    var subtitlePlacement: SheetSubtitlePlacement
    /// How the title itself is set, for the one sheet the design draws over 22.
    ///
    /// `.sheetTitle` is `400 22` serif and is what every sheet the app shipped with wears; the
    /// block editor is `400 26/1.05` (`design/rebuild/section-t5.html:62`). A parameter rather than
    /// a retune of the shared style, because eight files call this and the design has redrawn one
    /// of them — and rather than a second `SheetChrome`, because a title four points larger is not
    /// a different scaffold.
    ///
    /// **The avatar branch still wins.** `StaffSheet` drops a point to make room for its 46pt
    /// avatar (`.sheetTitleSm`), which is a fact about that layout rather than a preference about
    /// type, so it is decided below and not here. A caller passing both an avatar and a
    /// `titleStyle` gets the avatar's size; nothing does.
    var titleStyle: TypeStyle
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
        subtitlePlacement: SheetSubtitlePlacement = .belowTitle,
        titleStyle: TypeStyle = .sheetTitle,
        avatarInitials: String? = nil,
        avatarTone: AvatarTone = .neutral,
        detentFraction: Double,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitlePlacement = subtitlePlacement
        self.titleStyle = titleStyle
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

    /// `3` under the title, `2` once an avatar centres the row, and `6` above it — the design's own
    /// `margin-top:6px` from an eyebrow to the title it introduces
    /// (`design/rebuild/section-t5.html:62`). A gap over a title has to be wider than one under it
    /// or the two lines read as a single stacked block rather than as a marker and a heading.
    private var titleBlockSpacing: CGFloat {
        switch subtitlePlacement {
        case .eyebrow: Spacing.tight
        case .belowTitle: hasAvatar ? 2 : 3
        }
    }

    /// `9px 18px 13px`, or `9px 18px 14px` and centred once an avatar joins the row.
    private var header: some View {
        HStack(alignment: hasAvatar ? .center : .top, spacing: hasAvatar ? 12 : 10) {
            if let avatarInitials {
                InitialsAvatar(avatarInitials, size: 46, tone: avatarTone)
            }

            VStack(alignment: .leading, spacing: titleBlockSpacing) {
                if let subtitle, subtitlePlacement == .eyebrow {
                    Text(subtitle)
                        .typeStyle(.rowDetail, color: Theme.inkMuted)
                }
                Text(title)
                    .typeStyle(hasAvatar ? .sheetTitleSm : titleStyle, color: Theme.ink)
                if let subtitle, subtitlePlacement == .belowTitle {
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

// MARK: - Field label

/// The flat, sentence-case label over a single field inside a sheet.
///
/// `600 12.5px; letter-spacing:-.01em; color:#71757E; margin:14px 0 7px`
/// (`design/rebuild/section-t5.html:62-109`).
///
/// A **sibling** of `SheetSectionHeader`, not a restyle of it. That one is the tracked uppercase
/// overline the design puts over a *block* of a sheet — `LEAVES AT`, `ROLE` — and it still does
/// that in eight files. This one belongs to the box directly under it, and the design writes it
/// differently on every axis there is: sentence case, tighter rather than tracked, a step darker
/// in `inkTertiary`, and half the size difference of an overline. `Block name` is not a heading
/// over a group; it is the name of one field.
///
/// Kept apart rather than folded into a `style:` on `SheetSectionHeader` because the two are
/// wanted at once — the block editor is a sheet of flat field labels, and `VenueSheet`, `StaffSheet`
/// and the court pickers are sheets of overlines. Restyling in place would have moved seventeen
/// call sites nobody has redrawn. The house rule is only that no *new* screen introduces tracked
/// caps, not that the ones already drawn in them are wrong.
///
/// Both gutters are parameters because the first label in a sheet is spaced from a title rather
/// than from a field above it, and the design gives that one `16` where the rest take `14`. The
/// `7` below is the design's own and is a point off `Spacing.tight`.
struct SheetFieldLabel: View {
    let title: String
    var topPadding: CGFloat
    var bottomPadding: CGFloat

    init(_ title: String, topPadding: CGFloat = Spacing.gutterWide, bottomPadding: CGFloat = 7) {
        self.title = title
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
    }

    var body: some View {
        Text(title)
            .typeStyle(.metaStrong.tracking(em: -0.01), color: Theme.inkTertiary)
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

/// The block editor's header and body style: the same subtitle string moved above the title, and
/// flat field labels in place of overlines. Drawn beside the two previews above rather than
/// replacing them — the point is that both spellings are live.
#Preview("Sheet chrome — eyebrow and field labels") {
    ZStack(alignment: .bottom) {
        Theme.scrim.ignoresSafeArea()

        SheetChrome(
            title: "Edit block",
            subtitle: "Tuesday · Sycamore",
            subtitlePlacement: .eyebrow,
            detentFraction: 0.92,
            onClose: {}
        ) {
            // The first label is spaced from a title rather than from a field, so it takes the
            // design's wider 16 where the ones under it take 14.
            SheetFieldLabel("Block name", topPadding: Spacing.large)
            Text("Match play")
                .typeStyle(.rowTitle, color: Theme.ink)
                .formFieldChrome(.sheetBoxLarge)

            SheetFieldLabel("Starts")
            Text("10:45am")
                .typeStyle(.rowTitle, color: Theme.ink)
                .formFieldChrome(.sheetBoxLarge, icon: "clock")
        }
        .frame(height: 620)
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
