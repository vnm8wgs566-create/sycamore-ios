//
//  InboxPinnedList.swift
//  Sycamore
//
//  "PINNED · 2" and the rows under it — the first thing on the Inbox, above even "Needs you".
//
//  A pinned message is the camp's standing state rather than an event in its morning: the net on
//  4 is loose until somebody fixes it, and it does not become less true at ten o'clock. That is
//  why it sits above a list ordered newest-first — reverse chronology is the wrong axis for
//  something that is not about when it happened — and why it survives the all-clear card, which
//  is a statement about decisions waiting and not about notices standing.
//
//  Writing here is admin-only. The gate that counts is the RLS policy on `inbox_items`, not this
//  file: a non-admin who reaches the write anyway — an older build, a second device whose
//  membership has since changed, anything at all — is refused by the server, and that refusal
//  arrives as `SycamoreError.notPermitted` and reads "Only an admin can do that." in the banner
//  `MainTabView` floats. `store.isAdmin` below is courtesy: it keeps a control off the screen of
//  somebody it would only ever say no to.
//

import SwiftUI

struct InboxPinnedList: View {

    /// Pinned and unresolved, as the current chip allows, newest first. `InboxContents` has
    /// already derived and ordered them.
    let items: [InboxItem]

    @Environment(AppStore.self) private var store

    /// Not a copy of anything the store owns — the store owns the *rows*, and this is the
    /// half-written sentence that is not a row yet. It lives here rather than in the composer so
    /// that the half which can see whether the write landed is the half that clears it.
    @State private var draft = ""

    var body: some View {
        // Nothing pinned and no pin to give: no section. A coach whose camp has pinned nothing
        // sees the Inbox it has always had, rather than a card advertising a feature that is not
        // theirs. The locked row below appears under a list that exists — explaining the pins
        // they can see and not act on — which is a different thing from advertising.
        if store.isAdmin || !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                InboxOverline(heading)

                Card(radius: InboxMetrics.cardRadius) {
                    ForEach(items) { item in
                        InboxPinnedRow(item: item, canUnpin: store.isAdmin) { unpin(item) }
                    }

                    if store.isAdmin {
                        InboxPinnedComposer(draft: $draft, onPin: pin)
                    } else {
                        lockedRow
                    }
                }
            }
            .padding(.bottom, InboxMetrics.sectionGap)
        }
    }

    /// "Pinned · 2", or a bare "Pinned" over an empty card. `8r`'s headings count what is under
    /// them, and "Pinned · 0" over a composer counts nothing.
    private var heading: String {
        items.isEmpty ? "Pinned" : "Pinned · \(items.count)"
    }

    /// The presentation `ProfileView` gives "Camp settings" for the same situation: a locked row
    /// naming the people who *can*, rather than a control drawn and then switched off. A disabled
    /// composer would put a keyboard-shaped promise in front of somebody it will not keep.
    ///
    private var lockedRow: some View {
        SettingsRow(
            "Pin a message",
            icon: "pin",
            subtitle: store.adminsOnlyDetail,
            accessory: .lock
        )
        // As Profile's locked row: combined, because with no action the row is not a `Button` and
        // SwiftUI has not merged it into one element for us.
        .accessibilityElement(children: .combine)
        .accessibilityValue("Locked")
    }

    // MARK: Intents

    /// Both writes go through `AppStore`, which owns `isWorking` and `errorMessage` — so a
    /// refused pin raises the one banner `MainTabView` floats for all four tabs rather than a
    /// second, tab-shaped one that would make the same failure look like a different class of
    /// problem here.
    private func pin() {
        let text = PinnedMessage.trimmed(draft)
        guard PinnedMessage.isValid(text) else { return }

        Task {
            let before = store.inboxItems.count
            await store.addPinnedMessage(text)
            // Cleared only when the store actually took it, the way `InboxView.resolve` only
            // fires its haptic when the resolve landed. A write the server refused leaves the
            // words in the field to be copied out or tried again, instead of swallowing them
            // behind a banner that has already begun to fade.
            if store.inboxItems.count > before { draft = "" }
        }
    }

    private func unpin(_ item: InboxItem) {
        Task { await store.setPinned(false, for: item.id) }
    }
}

// MARK: - Previews

#Preview("Pinned — admin") {
    ScrollView {
        InboxPinnedList(items: InboxPreviewItems.pinned(venueID: UUID()))
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
    .environment(AppStore.previewUCLAAdmin)
}

/// The composer's empty state: an admin whose camp has pinned nothing yet.
#Preview("Pinned — admin, nothing pinned") {
    ScrollView {
        InboxPinnedList(items: [])
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
    .environment(AppStore.previewUCLAAdmin)
}

/// What a coach sees: the same pins, read-only, under a locked row naming who to ask.
#Preview("Pinned — coach") {
    ScrollView {
        InboxPinnedList(items: InboxPreviewItems.pinned(venueID: UUID()))
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
    }
    .background(Theme.surfaceWarm)
    .environment(AppStore.preview)
}
