//
//  BlockNotesCard.swift
//  Sycamore
//
//  The last row on `8l` — "3 notes on this block", and now the place they are written.
//
//  The design puts a caret on that row, so the notes are behind a tap. They expand in place rather
//  than pushing a screen: three lines of text do not need one, and section 8 draws no notes screen
//  to push to. Writing a fourth is the same size of job as reading the three, so it expands in
//  place too — a composer that pushed a screen would make adding a note a bigger event than the
//  note is.
//
//  The store arrives through `@Environment(AppStore.self)` rather than as a parameter. This card is
//  only ever drawn inside `BlockDetailView`, which already has it, and the two writes it needs —
//  `addBlockNote(_:to:)` and `deleteBlockNote(_:from:)` — are the store's, so passing them down as
//  closures would be three parameters restating one dependency.
//

import SwiftUI

struct BlockNotesCard: View {

    /// The whole block rather than its notes alone: both writes name the block, and the row's own
    /// label is spelled by the block so the card and the block agree on the plural.
    let block: ScheduleBlock

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isExpanded = false
    @State private var newNote = ""
    @FocusState private var isComposing: Bool

    var body: some View {
        Card(radius: ScheduleMetrics.cardRadius, isDivided: false) {
            VStack(spacing: 0) {
                Button(action: toggle) {
                    CardRow(spacing: ScheduleMetrics.rowGap,
                            horizontalPadding: ScheduleMetrics.cardPadding) {
                        DisclosureChevron(systemName: "note.text", size: 16, color: Theme.inkFaint)
                            .accessibilityHidden(true)

                        Text(block.notesRowLabel)
                            .typeStyle(ScheduleType.notesRow, color: Theme.inkWarm)

                        Spacer(minLength: Spacing.small)

                        DisclosureChevron(size: 15)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: HitTarget.minimum)
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Hides the notes" : "Shows the notes")

                if isExpanded {
                    // The notes themselves, now that each carries an id. This used to key on
                    // indices, because two coaches can write the same line and identical
                    // strings would have collapsed into one row — an id says which row is
                    // which without that dodge, and it is also what a delete has to name.
                    ForEach(block.notes) { note in
                        Hairline(color: Theme.hairlineSoft)
                        noteRow(note)
                    }

                    // Read-only for everybody else. Deliberately not a composer drawn disabled:
                    // `ProfileView` locks its admin rows rather than greying out the control
                    // behind them, and a field you can put a cursor in but not commit is a worse
                    // answer than no field.
                    //
                    // The gate that counts is the RLS policy on `inbox_items`, which is where a
                    // block note actually lives. This one is courtesy: it keeps a coach from
                    // typing a note the server was always going to refuse.
                    if store.isAdmin {
                        Hairline(color: Theme.hairlineSoft)
                        composer
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    // MARK: A note

    private func noteRow(_ note: BlockNote) -> some View {
        CardRow(spacing: Spacing.row,
                horizontalPadding: ScheduleMetrics.cardPadding,
                verticalPadding: Spacing.medium,
                alignment: .top) {
            Text(note.text)
                .typeStyle(ScheduleType.noteLine, color: Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if store.isAdmin {
                Spacer(minLength: Spacing.small)
                deleteMenu(for: note)
            }
        }
    }

    /// A `⋯` menu rather than a trailing swipe. `swipeActions` is a `List` modifier and there is no
    /// `List` on `8l` — the whole screen is a `ScrollView` of `Card`s — so a swipe here would have
    /// to be hand-built from a drag gesture inside a vertical scroll, which is the one gesture
    /// conflict a hand-built swipe always loses. The menu is also the control the design already
    /// uses for "the other things you can do to this thing", at the top of this very screen.
    private func deleteMenu(for note: BlockNote) -> some View {
        Menu {
            Button("Delete note", role: .destructive) { delete(note) }
        } label: {
            DisclosureChevron(systemName: "ellipsis", size: ScheduleMetrics.pickerCheck,
                              color: Theme.inkFaint)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(.rect)
        }
        .accessibilityLabel("Note options")
    }

    // MARK: Writing one

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            FormTextArea(
                "Add a note for this block",
                text: $newNote,
                label: "New note",
                metrics: .sheetBox,
                type: ScheduleType.editorValue,
                promptType: ScheduleType.editorPlaceholder,
                focus: $isComposing
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Pill(
                    "Add note",
                    tone: .accent,
                    systemImage: "plus",
                    font: ScheduleType.inlineAction,
                    horizontalPadding: 13,
                    verticalPadding: Spacing.small,
                    action: add
                )
                // Refused before the tap rather than after it: `inbox_items.detail` is
                // `check (detail is null or char_length(detail) <= 200)` — `20260805074039:60` —
                // and a blank note is a row that says nothing.
                .opacity(canAdd ? 1 : 0.45)
                .disabled(!canAdd)
            }
        }
        .padding(.horizontal, ScheduleMetrics.cardPadding)
        .padding(.vertical, Spacing.medium)
    }

    private var trimmedNote: String {
        newNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool { BlockRules.isValidNote(trimmedNote) }

    // MARK: Actions

    private func toggle() {
        withAnimation(Motion.fold(reduceMotion: reduceMotion)) { isExpanded.toggle() }
    }

    /// Clears the field on the way out rather than when the write lands. The store re-reads the
    /// day and this card is redrawn from it, so waiting would leave the note in the box next to a
    /// copy of itself in the list.
    private func add() {
        let text = trimmedNote
        guard BlockRules.isValidNote(text) else { return }
        newNote = ""
        isComposing = false
        Task { await store.addBlockNote(text, to: block) }
    }

    private func delete(_ note: BlockNote) {
        Task { await store.deleteBlockNote(note.id, from: block) }
    }
}

// MARK: - Previews

private struct BlockNotesPreview: View {
    var isAdmin: Bool
    var noteCount: Int

    /// `AppStore.preview` is Alex, a *worker* at UCLA — which is exactly the read-only case, and
    /// exactly not the one the composer needs. See `AppStore.previewUCLAAdmin`.
    @State private var store: AppStore

    init(isAdmin: Bool, noteCount: Int) {
        self.isAdmin = isAdmin
        self.noteCount = noteCount
        _store = State(initialValue: isAdmin ? AppStore.previewUCLAAdmin : AppStore.preview)
    }

    var body: some View {
        var block = ScheduleSampleDay.blocks(venueID: SampleData.sycamore.id)[1]
        block.notes = Array(block.notes.prefix(noteCount))

        return BlockNotesCard(block: block)
            .environment(store)
            .padding(Spacing.gutter)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.surfaceWarm)
    }
}

#Preview("Notes — admin") {
    BlockNotesPreview(isAdmin: true, noteCount: 3)
}

#Preview("Notes — none yet, admin") {
    BlockNotesPreview(isAdmin: true, noteCount: 0)
}

#Preview("Notes — read-only") {
    BlockNotesPreview(isAdmin: false, noteCount: 3)
}
