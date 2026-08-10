//
//  SwipeToDelete.swift
//  Sycamore
//
//  A row that slides left to show one destructive action, for a `ScrollView` of `Card`s.
//
//  Two comments in this app say a swipe cannot be built here — `InboxPinnedRow.swift:71` and
//  `BlockNotesCard.swift:103` — and both are right about `.swipeActions`, which is a `List`
//  modifier and would silently do nothing: there is no `List` anywhere under `Sycamore/`. Where
//  both go wrong is the next step, "so a hand-built one always loses to the scroll view". They
//  generalised that from the app's vertical `DragGesture`s — `GroupCard.swift:600`,
//  `RankView.swift:353` and now `ScheduleBlockCard`'s two — and every one of those is a
//  **vertical** drag — the same axis as the scroll,
//  so nothing about the movement can separate them and only *time* can, which is why both sit
//  behind a `LongPressGesture.sequenced(before:)`. A swipe is horizontal. Direction separates it,
//  and direction costs the reader nothing.
//
//  The geometry is not invented. `design/SPEC.md:196` and `design/Sycamore Flow.dc.html:204` draw
//  this on a player row and always did — a 130pt panel behind a row translated out of the way,
//  revealing `Mark away`. It was never built. This is that panel, mirrored to the trailing edge,
//  because a destructive action goes where the platform has put destructive actions since iOS 7.
//
//  Deliberately not a general `SwipeActions` taking a `@ViewBuilder` panel. That needs multiple
//  actions, a per-edge configuration and a full-swipe policy per action; there is one caller and
//  one action, and the second caller is what would earn the generality.
//

import SwiftUI

// MARK: - Metrics

/// Every number the reveal is built from, in one place.
enum SwipeMetrics {

    /// `width:130px` — the panel behind a swiped row (`design/Sycamore Flow.dc.html:204`).
    static let actionWidth: CGFloat = 130

    /// How far a finger travels before the row will say which way it is going.
    ///
    /// 12 rather than `DragGesture`'s default 10: the enclosing scroll view claims a pan at
    /// roughly ten points, so deciding at ten is deciding in the same frame it does, and the tie
    /// goes to whichever recogniser SwiftUI happens to poll first. Two points past it is not a
    /// delay anybody feels, and it is a decision nobody has to arbitrate.
    static let axisLock: CGFloat = 12

    /// Past the stop the finger keeps moving and the row does not, much. A third, which is the
    /// shallowest ratio that still reads as "there is nothing more here" rather than as a row
    /// that has jammed.
    static let resistance: CGFloat = 0.35

    /// Where a release settles: past the middle of the panel, it opens.
    static let settleFraction: CGFloat = 0.5
}

// MARK: - Which row is open

/// Which row is open, and which row has a finger on it.
///
/// One value rather than two bindings, because the two facts are read by the same parent in the
/// same breath — the open row decides what is drawn, the tracked row decides `.scrollDisabled` —
/// and a parent holding two `@State`s that must never disagree is a parent that eventually will.
///
/// Deliberately not a `PreferenceKey`. Preferences flow child→parent and need a second pass to
/// come back down; this is genuinely two-way (row B opening must close row A), and two-way
/// coordination through preferences is a known source of update loops.
struct SwipeRevealState<ID: Hashable & Sendable>: Equatable, Sendable {

    /// The one row showing its action, if any.
    var openID: ID?

    /// The row with a finger committed to a horizontal drag, if any. The parent hands this to
    /// `.scrollDisabled` so the list cannot slide out from under a row that is sliding.
    var trackingID: ID?

    var isTracking: Bool { trackingID != nil }

    init() {}
}

// MARK: - The arithmetic

/// One row's reveal, with no view in it.
///
/// Lifted out for the reason `GroupsLandingPlan` was (`GroupsLandingPlan.swift:7-11`): every
/// threshold below decides something a person can otherwise only check by putting a finger on a
/// device, and every way it can be wrong looks right. The row moves, something happens, nothing
/// throws.
struct SwipeRevealPlan: Equatable, Sendable {

    /// Which way this drag committed.
    ///
    /// Decided once, at `SwipeMetrics.axisLock`, and never revisited — a swipe that curves
    /// downward halfway through is still a swipe, and a scroll that drifts sideways is still a
    /// scroll. Re-deciding per sample is how a row ends up jittering between the two.
    enum Axis: Equatable, Sendable { case undecided, horizontal, vertical }

    let actionWidth: CGFloat
    private(set) var axis: Axis = .undecided

    /// Where the row rested when this finger landed: `0` or `-actionWidth`.
    private(set) var restingOffset: CGFloat

    /// Where the row is drawn right now. Rubber-banded while a finger is down; exactly `0` or
    /// `-actionWidth` at every other moment.
    private(set) var offset: CGFloat

    init(actionWidth: CGFloat = SwipeMetrics.actionWidth, isOpen: Bool = false) {
        self.actionWidth = actionWidth
        let rest = isOpen ? -actionWidth : 0
        self.restingOffset = rest
        self.offset = rest
    }

    var isOpen: Bool { offset == -actionWidth }

    /// One `onChanged`.
    ///
    /// - Returns: whether this row claimed the finger. `false` means the parent must not touch
    ///   `trackingID` — the scroll view is having this one.
    @discardableResult
    mutating func drag(_ translation: CGSize) -> Bool {
        if axis == .undecided {
            // Nothing is decided and nothing moves until there is enough travel to judge. A tap
            // never gets this far, which is what leaves the row's own `Button` its gesture.
            guard hypot(translation.width, translation.height) >= SwipeMetrics.axisLock else {
                return false
            }
            axis = abs(translation.width) > abs(translation.height) ? .horizontal : .vertical
        }
        guard axis == .horizontal else { return false }

        let raw = restingOffset + translation.width
        if raw > 0 {
            // No leading action exists. A rightward drag on a closed row does nothing; on an open
            // one it closes and stops at zero.
            offset = 0
        } else if raw >= -actionWidth {
            offset = raw
        } else {
            offset = -actionWidth + (raw + actionWidth) * SwipeMetrics.resistance
        }
        return true
    }

    /// One `onEnded`.
    ///
    /// Takes `predictedEndTranslation` rather than `translation`, which is the whole reason a
    /// fast flick opens the row without travelling the full 130pt: the predicted value is
    /// velocity-aware and the raw one is not.
    ///
    /// - Returns: whether the row settled open.
    @discardableResult
    mutating func end(predictedEndTranslation: CGSize) -> Bool {
        guard axis == .horizontal else {
            cancel()
            return isOpen
        }
        let predicted = restingOffset + predictedEndTranslation.width
        let opened = predicted <= -actionWidth * SwipeMetrics.settleFraction
        offset = opened ? -actionWidth : 0
        restingOffset = offset
        axis = .undecided
        return opened
    }

    /// Another row opened, or a tap landed on this one.
    mutating func close() {
        offset = 0
        restingOffset = 0
        axis = .undecided
    }

    /// A cancelled gesture.
    ///
    /// Returns to the rest it started from — deliberately *not* to zero, which would close a row
    /// that was already open before the finger landed.
    mutating func cancel() {
        offset = restingOffset
        axis = .undecided
    }
}

// MARK: - The row

/// A row that slides left to reveal one destructive action.
///
/// The reveal is the whole gesture: a full swipe does **not** commit. Every caller of this deletes
/// something there is no undo for — `CampShape.removeVenue` is a `removeAll` and no screen in this
/// app draws a snackbar — and Mail's full-swipe commit is only safe because Mail has an Undo. The
/// tap on the revealed panel is the commit.
struct SwipeToDelete<ID: Hashable & Sendable, Content: View>: View {

    let id: ID

    /// Shared with every sibling row, so only one is ever open.
    @Binding var state: SwipeRevealState<ID>

    /// "Remove Sycamore" — the accessibility action's name, and what the panel would say if it
    /// had the room. It rarely does: the design's panel is 130pt (`Flow.dc.html:204`) and was
    /// drawn around "Mark away", so anything naming the thing being removed truncates to
    /// "Remove Ven…". `panelLabel` is what is actually drawn; this is what is spoken, and the
    /// spoken one has to be the specific one — "Remove" alone, read out of a list of eight venue
    /// rows, does not say which venue.
    let actionLabel: String

    /// The verb on the plate. Short by default because 130pt is short.
    var panelLabel: String = "Remove"

    /// The plate under the row.
    ///
    /// The design draws `background:#fff` on the translating child (`Flow.dc.html:204`) for the
    /// reason it has to: the panel sits behind the whole row, so a transparent row shows it at
    /// rest. `CardRow` draws no background of its own — `Card` does — so this is where it comes
    /// from.
    var background: Color = Theme.surface

    /// `nil` switches the swipe off and hides the action entirely: the last venue cannot go.
    let onDelete: (() -> Void)?

    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var plan = SwipeRevealPlan()

    var body: some View {
        contentLayer
            .accessibilityActions {
                if let onDelete {
                    Button(actionLabel, role: .destructive, action: onDelete)
                }
            }
    }

    // MARK: Layers

    private var contentLayer: some View {
        #if os(iOS)
        return ZStack(alignment: .trailing) {
            actionPanel
            content
                .background(background)
                // The catcher goes on **before** the offset, and that order is the whole of it.
                // `.offset` is a render-time transform: it moves what you see and leaves the
                // layout frame where it was. An overlay applied after it therefore sits on the
                // *un-offset* frame — the row's full width, including the strip the panel is now
                // showing through — so every tap meant for Remove was caught and closed the row
                // instead. Applied before, the catcher is part of the content and travels with
                // it, which is what "a tap on the open row closes it" was ever supposed to mean.
                .overlay { closeCatcher }
                .offset(x: plan.offset)
        }
        .clipped()
        .gesture(swipe)
        .onChange(of: state.openID) { _, open in
            // Somebody else opened. Close, without touching `openID` — they own it now.
            guard open != id, plan.isOpen else { return }
            withAnimation(Motion.fold(reduceMotion: reduceMotion)) { plan.close() }
        }
        .onChange(of: isDragging) { _, live in
            // `onEnded` is not guaranteed on a cancelled gesture, and `RankView.beginDrag` already
            // records what stale gesture state costs. `@GestureState` resets by construction, so
            // this is the one signal that always arrives.
            guard !live, plan.axis != .undecided else { return }
            state.trackingID = nil
            withAnimation(Motion.fold(reduceMotion: reduceMotion)) { plan.cancel() }
        }
        .sensoryFeedback(.selection, trigger: plan.isOpen)
        #else
        // A trackpad's two-finger horizontal swipe arrives as a scroll event, not a drag, so the
        // only thing that would reveal this panel on the Mac is a click-and-drag nobody performs
        // on a list row. Drawing an unreachable action is worse than drawing none — the named
        // accessibility action above is the Mac's route, and so is the caller's own editor.
        return content
        #endif
    }

    #if os(iOS)
    /// The destructive plate behind the row.
    ///
    /// `dangerTint` rather than the design's `#0B0B0C`, and rather than a saturated red. The
    /// design's black panel is its *non-destructive* treatment ("Mark away"); this app has never
    /// drawn a filled red surface — `ButtonTone.danger` is a white fill with a red label
    /// (`Components.swift:399`) — and `Theme.danger`'s dark value `FF7A5C` carries white at about
    /// 2.6:1, which is not a contrast this app ships.
    private var actionPanel: some View {
        Button {
            withAnimation(Motion.fold(reduceMotion: reduceMotion)) { plan.close() }
            state.openID = nil
            onDelete?()
        } label: {
            HStack(spacing: Spacing.small) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                Text(panelLabel)
                    .typeStyle(.chipMedium, color: Theme.danger)
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.danger)
            .padding(.leading, Spacing.large)
            .frame(width: SwipeMetrics.actionWidth, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Theme.dangerTint)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Translated off-screen is still focusable, still in the VoiceOver order and still in
        // Switch Control's scan. Hidden while closed takes it out of all three.
        .accessibilityHidden(!plan.isOpen)
    }

    /// While the row is open, a tap anywhere on it closes rather than reaching what is underneath.
    @ViewBuilder
    private var closeCatcher: some View {
        if plan.isOpen {
            Color.clear
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(Motion.fold(reduceMotion: reduceMotion)) { plan.close() }
                    state.openID = nil
                }
        }
    }

    /// Plain `.gesture`, deliberately, and both alternatives are wrong here.
    ///
    /// `.highPriorityGesture` runs ahead of the child's gestures and delays their recognition —
    /// the row's content is a `Button` whose tap opens an editor, and putting a drag in front of
    /// it makes every tap wait for the drag to fail. `.simultaneousGesture` is worse: the `Button`
    /// would *also* fire at the end of a swipe, so a completed swipe-left would open the editor.
    /// Plain `.gesture` on the ancestor leaves the child's tap first refusal, which is exactly the
    /// arbitration wanted — a press-and-release is the button's, a press-and-move is ours, and
    /// `minimumDistance` is the line between them.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: SwipeMetrics.axisLock, coordinateSpace: .local)
            .updating($isDragging) { _, live, _ in live = true }
            .onChanged { value in
                guard onDelete != nil else { return }
                guard plan.drag(value.translation) else { return }
                // Guarded, because `@State` does not compare before it writes and this runs at
                // display rate. `state` is a binding into the screen that owns the list, so an
                // unguarded assignment re-ran that whole body on every frame of every swipe —
                // the scroll view, every sibling row, every stepper — for a value that changes
                // once per gesture. `GroupsView.swift:317` guards its frame writes for exactly
                // this reason, behind `isMeasuring`.
                if state.trackingID != id { state.trackingID = id }
                if state.openID != nil, state.openID != id { state.openID = nil }
            }
            .onEnded { value in
                state.trackingID = nil
                var opened = false
                // Only the settle is animated. The tracking phase follows the finger 1:1, and
                // wrapping `plan.drag` would put 0.24s between the finger and the row.
                withAnimation(Motion.fold(reduceMotion: reduceMotion)) {
                    opened = plan.end(predictedEndTranslation: value.predictedEndTranslation)
                }
                if opened {
                    state.openID = id
                } else if state.openID == id {
                    state.openID = nil
                }
            }
    }
    #endif
}

// MARK: - Previews

#Preview("Swipe to delete") {
    SwipeToDeletePreviewHarness()
}

private struct SwipeToDeletePreviewHarness: View {
    @State private var names = ["Sycamore", "Westside", "LATC"]
    @State private var swipe = SwipeRevealState<String>()

    var body: some View {
        ScrollView {
            Card {
                ForEach(names, id: \.self) { name in
                    SwipeToDelete(
                        id: name,
                        state: $swipe,
                        actionLabel: "Remove \(name)",
                        onDelete: names.count > 1 ? { names.removeAll { $0 == name } } : nil
                    ) {
                        CardRow {
                            Text(name).typeStyle(.intakeRowTitle, color: Theme.ink)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(Spacing.hero)
        }
        .scrollDisabled(swipe.isTracking)
        .background(Theme.surfaceWarm)
    }
}
