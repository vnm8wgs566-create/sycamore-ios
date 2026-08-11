//
//  Toast.swift
//  Sycamore
//
//  The black pill that says what just happened, and sometimes offers to undo it.
//
//  `design/app/regions/toast.html` with `state1.js:17` behind it: `bottom:96px`, radius 999,
//  `500 13` white on `#0B0B0C`, `0 12 36 rgba(11,11,12,.3)`, auto-dismissing after 3200ms, with
//  an optional `Undo` in `#7BC5A1`.
//
//  ── Why this file exists at all ──────────────────────────────────────────────────────────────
//
//  Three separate files in this app had already written the absence down as a fact about it —
//  `SwipeToDelete.swift`, `EvenOutSheet.swift` and `PlayerCourtPicker.swift` each say some version
//  of "no screen in this app draws a snackbar" while describing a design that does. The design
//  toasts eight different writes and offers Undo on two of them, and until now every one of those
//  writes happened in silence: a kid moved court, a venue was added, a roster of forty landed, a
//  group was removed, and the screen simply looked slightly different afterwards.
//
//  ── Not an alert, and not the error banner ───────────────────────────────────────────────────
//
//  `ErrorBanner` is the other half of this pair and deliberately unlike it: it sits at the *top*,
//  it stays until dismissed, and it reports something that went wrong. A toast is the opposite in
//  all three — foot of the screen, times out on its own, and reports something that went *right*.
//  A person who has to dismiss confirmations stops reading them.
//
//  ── Undo is a closure, not a stack ───────────────────────────────────────────────────────────
//
//  The design's `undo` (`state1.js:49`) restores a whole snapshot of the roster. This takes a
//  closure instead, so the caller decides what undoing means — `movePlayer` back to the court it
//  came from, `removeGroup` by writing the group again — and a caller with no sensible inverse
//  simply does not pass one. A global snapshot stack would have to answer "what does undo mean
//  three screens later", and the honest answer is that it should not still be offered.
//

import SwiftUI

// MARK: - The message

/// One thing that happened, and optionally the way back from it.
///
/// `Identifiable` on a fresh id rather than on the text: two identical toasts in a row — "Even
/// out" pressed twice — are two events, and keying on the sentence would make the second one a
/// no-op that leaves the first one's timer running.
struct Toast: Identifiable, Sendable {
    let id = UUID()
    let message: String
    /// Nil draws no button. See the file header.
    let undo: (@Sendable @MainActor () -> Void)?

    init(_ message: String, undo: (@Sendable @MainActor () -> Void)? = nil) {
        self.message = message
        self.undo = undo
    }
}

// MARK: - Geometry

enum ToastMetrics {
    /// `bottom:96px` — clear of the floating tab bar rather than measured from the safe area, so
    /// the pill sits above it on the four tabbed screens and in roughly the same place elsewhere.
    static let bottomInset: CGFloat = 96
    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat = 12
    /// `3200ms`. Long enough to read eleven words, short enough that a person who has moved on
    /// does not come back to a stale claim.
    static let lifetime: Duration = .milliseconds(3200)
    /// The gap between the sentence and `Undo`.
    static let actionGap: CGFloat = 14
}

// MARK: - The pill

struct ToastPill: View {
    let toast: Toast
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: ToastMetrics.actionGap) {
            Text(toast.message)
                .typeStyle(.toastMessage, color: Theme.onAccent)
                .fixedSize(horizontal: false, vertical: true)

            if toast.undo != nil {
                Button("Undo", action: onUndo)
                    .buttonStyle(.plain)
                    .typeStyle(.toastAction, color: Theme.undoGreen)
                    // 13pt of copy draws about 16 tall; this is inside a pill that is already
                    // 44 with its padding, so the target is the pill rather than the word.
                    .contentShape(.rect)
            }
        }
        .padding(.horizontal, ToastMetrics.horizontalPadding)
        .padding(.vertical, ToastMetrics.verticalPadding)
        .background(Theme.ink, in: .rect(cornerRadius: Radius.pill))
        .shadow(Shadows.toast)
        // One utterance, announced when it appears — a toast nobody can see is exactly the case
        // VoiceOver has to speak, and reading "Austin moved to Group 3" then "Undo" as two
        // separate stops loses which write the button belongs to.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - The presenter

extension View {

    /// Draws whatever toast is up, over everything, and takes it down on its own.
    ///
    /// Applied once at the root rather than per screen: a toast raised by a sheet has to outlive
    /// the sheet — "Venue added" is raised as the sheet closes — and an overlay owned by the
    /// sheet would leave with it before anybody read a word.
    func toasts(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastPresenter(toast: toast))
    }
}

private struct ToastPresenter: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    ToastPill(toast: toast) {
                        toast.undo?()
                        self.toast = nil
                    }
                    .padding(.bottom, ToastMetrics.bottomInset)
                    .padding(.horizontal, Spacing.gutter)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // Keyed on the id so a second toast arriving while the first is up restarts
                    // the clock rather than inheriting the remains of it.
                    .task(id: toast.id) {
                        try? await Task.sleep(for: ToastMetrics.lifetime)
                        guard !Task.isCancelled else { return }
                        self.toast = nil
                    }
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.9), value: toast?.id)
    }
}
