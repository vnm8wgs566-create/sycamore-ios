//
//  CampPickerView.swift
//  Sycamore
//
//  Screen 3 — Which camp? Identity is settled; this is where a person picks which of their
//  memberships they are working under today, or acquires a new one.
//
//  This view owns the navigation stack for stage 1's second half — "Create a camp" pushes
//  screen 4 onto it. The app's root should present `CampPickerView` bare, without wrapping
//  it in a stack of its own.
//

import SwiftUI

struct CampPickerView: View {
    @Environment(AppStore.self) private var store
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            screen
                .navigationDestination(isPresented: $isCreating) {
                    CreateCampView()
                }
        }
        .task { await store.loadMemberships() }
    }

    /// Both stage-1 camp screens draw their own header, so the stack's bar stays hidden.
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
                // The one brand beat between signing in and the camp loading. Small enough to
                // sit under the title rather than competing with it.
                SycamoreMark()
                    .frame(width: 30, height: 30)
                    .padding(.bottom, Spacing.medium)

                Text("Which camp?")
                    .typeStyle(.title2, color: Theme.ink)

                // `verbatim:` — an interpolated literal is still a LocalizedStringKey, so
                // the address would be Markdown-autolinked and render as a tinted link
                // instead of the design's #71757E.
                Text(verbatim: "Signed in as \(store.account?.email ?? "")")
                    .typeStyle(.bodyAlt, color: Theme.inkTertiary)
                    .padding(.top, Spacing.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, 28)
            .padding(.bottom, Spacing.section)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // No inline loading state here: `RootView` lays the full-screen seed fall over
                // this whole view while `isWorking`, so a second one underneath it would only
                // ever be drawn behind the first.
                if store.memberships.isEmpty {
                    noCamps
                        .padding(.bottom, Spacing.hero)
                } else {
                    SectionHeader("Your camps")
                    membershipCard
                        .padding(.bottom, Spacing.hero)
                }

                SectionHeader("Join with a code")
                joinRow
                    .padding(.bottom, Spacing.hero)

                createButton

                if let message = store.errorMessage {
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

    private var membershipCard: some View {
        Card(radius: Radius.cardLarge) {
            ForEach(store.memberships) { membership in
                Button {
                    Task { await store.select(membership) }
                } label: {
                    CardRow(spacing: 13, horizontalPadding: Spacing.gutterWide, verticalPadding: 15) {
                        campTile(membership)

                        VStack(alignment: .leading, spacing: Spacing.hairGap) {
                            // `.rowTitleLg` is 800 16.5 at -.028em, which is the coach name in
                            // Groups. The camp name is the same size and weight but the design
                            // sets it a shade looser, at -.025em.
                            Text(membership.campName)
                                .typeStyle(.rowTitleLg.tracking(em: -0.025), color: Theme.ink)
                            Text(membership.subtitle)
                                .typeStyle(.metaStrong, color: Theme.inkMuted)
                        }

                        Spacer(minLength: 0)
                        DisclosureChevron(size: 17)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func campTile(_ membership: Membership) -> some View {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
            .fill(Theme.color(for: membership.campTint))
            .frame(width: 46, height: 46)
            .overlay {
                Text(membership.campIcon)
                    .font(.system(size: 23))
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
    }

    private func codeField(_ text: Binding<String>) -> some View {
        // Invite codes are printed uppercase everywhere; fold the input as it is typed so the
        // mono field reads like the code on the flyer. The repository matches loosely anyway.
        let upper = Binding(get: { text.wrappedValue }, set: { text.wrappedValue = $0.uppercased() })

        let base = TextField("", text: upper)
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
                    Text("Create a camp")
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
