//
//  CampPickerView.swift
//  Sycamore
//
//  Two screens, one view, because they are the same list asked twice.
//
//  Screen 3 — "Which camp?" — is stage 1: identity is settled and nothing is loaded yet, so the
//  question is which membership you are working under today.
//
//  `8u` — "Manage camps" — is the same list from inside a camp, opened from Profile. It leads
//  with the camp you are signed in to, offers the others with a Switch beside each, and keeps
//  the join field and the dashed "Start a camp" card underneath.
//
//  The only real difference is that one of them has a camp already. `isManagingCamps` says which
//  it is; everything below the two section headers is shared.
//
//  This view owns the navigation stack for stage 1's second half — "Start a camp" pushes
//  screen 4 onto it. The app's root should present `CampPickerView` bare, without wrapping
//  it in a stack of its own.
//

import SwiftUI

struct CampPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// `8u` rather than screen 3. Presented as a sheet from Profile, with a camp already loaded.
    let isManagingCamps: Bool

    @State private var isCreating = false

    init(isManagingCamps: Bool = false) {
        self.isManagingCamps = isManagingCamps
    }

    var body: some View {
        NavigationStack {
            screen
                .navigationDestination(isPresented: $isCreating) {
                    CreateCampView()
                }
        }
        .task { await store.loadMemberships() }
        // Switching, joining and creating all end in `select(_:)`. When this is `8u` that
        // finishes the errand: close both this sheet and the Profile sheet underneath it, and
        // the new camp is what the tabs are showing.
        .onChange(of: store.selectedMembership?.id) { _, _ in
            guard isManagingCamps else { return }
            // Both are state changes rather than imperative dismissals, so SwiftUI settles them
            // in one pass: this sheet and the Profile sheet under it go together.
            store.pushedScreen = nil
            dismiss()
        }
    }

    /// Both camp screens draw their own header, so the stack's bar stays hidden.
    private var screen: some View {
        let stack = VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)
            content
        }
        .background(Theme.grouped)

        #if os(iOS)
        return stack.toolbar(.hidden, for: .navigationBar)
        #else
        return stack
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                if isManagingCamps {
                    CircleIconButton(systemName: "arrow.left", size: 36, tone: .filled) {
                        dismiss()
                    }
                    .accessibilityLabel("Back to your profile")
                    .padding(.bottom, Spacing.tight)
                } else {
                    // The one brand beat between signing in and the camp loading. Small enough to
                    // sit under the title rather than competing with it.
                    SycamoreMark()
                        .frame(width: 30, height: 30)
                        .padding(.bottom, Spacing.medium)
                }

                Text(isManagingCamps ? "Your camps" : "Which camp?")
                    .typeStyle(.title2, color: Theme.ink)

                if isManagingCamps {
                    Text("Your role comes from the camp, not the login")
                        .typeStyle(.bodyAlt, color: Theme.inkTertiary)
                        .padding(.top, Spacing.small)
                } else {
                    // `verbatim:` — an interpolated literal is still a LocalizedStringKey, so
                    // the address would be Markdown-autolinked and render as a tinted link
                    // instead of the design's #71757E.
                    Text(verbatim: "Signed in as \(store.account?.email ?? "")")
                        .typeStyle(.bodyAlt, color: Theme.inkTertiary)
                        .padding(.top, Spacing.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, isManagingCamps ? Spacing.gutterWide : 28)
            .padding(.bottom, Spacing.section)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                camps
                    .padding(.bottom, Spacing.hero)

                SectionHeader(isManagingCamps ? "Join another" : "Join with a code")
                joinRow
                    .padding(.bottom, Spacing.hero)

                createButton

                if let message = store.errorMessage, !isManagingCamps {
                    Text(message)
                        .typeStyle(.footnote, color: Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Spacing.medium)
                }
            }
            .padding(.horizontal, Spacing.gutterWide)
            .padding(.top, Spacing.sheet)
            .padding(.bottom, Spacing.hero)
        }
    }

    // MARK: Memberships

    /// `8u` splits the list in two: the camp you are in, then the ones you are not. Screen 3 has
    /// no camp yet, so the whole list is one card under "Your camps".
    ///
    /// A `VStack` rather than a bare `@ViewBuilder` group: the caller pads the whole block, and a
    /// `TupleView` under a padding modifier is no longer something the enclosing stack unrolls.
    private var camps: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isManagingCamps, let current = store.selectedMembership {
                let rest = others(besides: current)

                SectionHeader("Signed in to")
                currentCamp(current)

                if !rest.isEmpty {
                    SectionHeader("Also yours")
                        .padding(.top, Spacing.hero)
                    Card(radius: Radius.cardLarge) {
                        ForEach(rest) { membership in
                            otherCamp(membership)
                        }
                    }
                }
            } else if store.memberships.isEmpty {
                // No inline loading state here: `RootView` lays the full-screen seed fall over
                // this whole view while `isWorking`, so a second one underneath it would only
                // ever be drawn behind the first.
                noCamps
            } else {
                SectionHeader("Your camps")
                Card(radius: Radius.cardLarge) {
                    ForEach(store.memberships) { membership in
                        Button {
                            Task { await store.select(membership) }
                        } label: {
                            campRow(membership) {
                                DisclosureChevron(size: 17)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func others(besides current: Membership) -> [Membership] {
        store.memberships.filter { $0.id != current.id }
    }

    /// Shown in place of the `YOUR CAMPS` header and its card when the account belongs to no
    /// camp yet. Without it the header rendered with nothing under it, which read as a screen
    /// that had failed to load rather than one waiting for a first camp.
    private var noCamps: some View {
        // The mark rather than SF Symbols' tent: this is the first empty screen a new person
        // sees, and a seed that has not taken root yet says more here than a campsite glyph.
        ContentUnavailableView {
            Label {
                Text("No camps yet")
            } icon: {
                SycamoreMark()
                    .frame(width: 44, height: 44)
            }
        } description: {
            Text("Join with a code below, or create your own.")
        }
        .frame(maxWidth: .infinity)
    }

    /// The camp you are in: a heavier accent border, and an "Open" pill instead of a control,
    /// because there is nothing to do to the camp you are already standing in.
    private func currentCamp(_ membership: Membership) -> some View {
        Card(
            radius: Radius.cardLarge,
            borderColor: Theme.accentBorder,
            borderWidth: BorderWidth.input,
            isDivided: false
        ) {
            campRow(membership) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                    Text("Open")
                        .typeStyle(.badge.tracking(em: 0.12), color: Theme.accentDark)
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, 5)
                .background(Theme.accentTint, in: Capsule(style: .continuous))
            }
        }
    }

    private func otherCamp(_ membership: Membership) -> some View {
        campRow(membership) {
            Button {
                Task { await store.select(membership) }
            } label: {
                Text("Switch")
                    .typeStyle(.chipMedium, color: Theme.accentDark)
                    .padding(.horizontal, 13)
                    .padding(.vertical, Spacing.small)
                    .background(
                        Theme.accentTint,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch to \(membership.campName)")
        }
    }

    /// Tile, name and role line — the shape every camp row in both screens shares. The trailing
    /// builder is what tells them apart: a caret, an "Open" pill, or a Switch button.
    private func campRow<Trailing: View>(
        _ membership: Membership,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        CardRow(spacing: 13, horizontalPadding: Spacing.gutterWide, verticalPadding: 15) {
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(Theme.color(for: membership.campTint))
                .frame(width: 44, height: 44)
                .overlay { Text(membership.campIcon).font(.system(size: 21)) }

            VStack(alignment: .leading, spacing: Spacing.hairGap) {
                // `.rowTitleLg` is 800 16.5 at -.028em, which is the coach name in Groups. The
                // camp name is the same size and weight but the design sets it a shade looser,
                // at -.025em.
                Text(membership.campName)
                    .typeStyle(.rowTitleLg.tracking(em: -0.025), color: Theme.ink)
                    .lineLimit(1)
                Text(membership.subtitle)
                    .typeStyle(.metaStrong, color: Theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.small)
            trailing()
        }
    }

    // MARK: Join

    private var joinRow: some View {
        @Bindable var store = store

        return HStack(spacing: Spacing.small) {
            ZStack(alignment: .leading) {
                if store.joinCodeInput.isEmpty {
                    Text("SYC-••••")
                        .typeStyle(.monoInput, color: Theme.inkFaint)
                }
                codeField($store.joinCodeInput)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: BorderWidth.input)
            }

            Button {
                Task { await store.joinCamp() }
            } label: {
                Text("Join")
                    .typeStyle(.buttonSmall, color: Theme.surface)
                    .padding(.horizontal, Spacing.section)
                    .frame(maxHeight: .infinity)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: false, vertical: true)
        // Invite codes are printed uppercase everywhere; fold what arrives so a pasted
        // "syc-4821" reads like the code on the flyer. The repository matches loosely anyway.
        //
        // An `onChange` rather than a `Binding(get:set:)` wrapped around the field: the manual
        // binding was rebuilt on every pass of this body, and it wrote to the store from inside
        // view evaluation.
        .onChange(of: store.joinCodeInput) { _, typed in
            let folded = typed.uppercased()
            if folded != typed { store.joinCodeInput = folded }
        }
    }

    private func codeField(_ text: Binding<String>) -> some View {
        let base = TextField("", text: text)
            .textFieldStyle(.plain)
            .typeStyle(.monoInput, color: Theme.ink)
            .autocorrectionDisabled()

        #if os(iOS)
        return base
            .textInputAutocapitalization(.characters)
            .submitLabel(.join)
        #else
        return base
        #endif
    }

    // MARK: Create

    private var createButton: some View {
        Button {
            isCreating = true
        } label: {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .fill(Theme.accentTint)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(isManagingCamps ? "Start a camp" : "Create a camp")
                        .typeStyle(.rowTitle, color: Theme.accent)
                    Text("You become its first admin")
                        .typeStyle(.metaStrong, color: Theme.accentSubtle)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.gutterWide)
            .padding(.vertical, Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.cardLarge, style: .continuous))
            .overlay {
                // CSS draws a dashed 1.5px border as ~3× the width per dash and gap.
                RoundedRectangle(cornerRadius: Radius.cardLarge, style: .continuous)
                    .strokeBorder(
                        Theme.accentBorder,
                        style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("8u Manage camps") {
    CampPickerView(isManagingCamps: true)
        .environment(AppStore.preview)
        .showsMockStatusBar()
}

#Preview("Which camp?") {
    CampPickerView()
        .environment(AppStore.previewCampPicker)
        .showsMockStatusBar()
}

#Preview("Which camp? — no memberships") {
    let store = AppStore(repository: InMemoryRepository(memberships: []))
    store.auth = .signedIn(SampleData.account)
    return CampPickerView()
        .environment(store)
        .showsMockStatusBar()
}
