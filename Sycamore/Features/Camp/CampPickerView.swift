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
//  Section 8 draws `8u` and does not redraw screen 3, so every metric below is `8u`'s and screen
//  3 inherits it. Two parallel styles inside one view would double it to keep a screen the design
//  has stopped describing — and the rows are the same rows.
//

import SwiftUI

struct CampPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// `8u` rather than screen 3. Presented as a sheet from Profile, with a camp already loaded.
    let isManagingCamps: Bool

    @State private var isCreating = false
    @FocusState private var isCodeFocused: Bool
    /// The design's 44pt camp tile and 42pt "Start a camp" tile. Scaled, because a row whose copy
    /// has grown half again leaves a fixed tile looking stuck to the top of it.
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 44

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
        VStack(spacing: 0) {
            header
            Hairline(color: Theme.hairline)
            content
        }
        // `#F8F9F8`, the page colour behind every section 8 screen.
        .background(Theme.surfaceWarm)
        .hidesNavigationBar()
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
                    // The disc is 36 and the button around it is 44, which would otherwise push
                    // the title 4pt down and the disc 4pt right of where the design puts them.
                    // Saying how big the row is leaves the touch overflowing and nothing moved.
                    .frame(width: 36, height: 36)
                    .padding(.bottom, 15)
                } else {
                    // The one brand beat between signing in and the camp loading. Small enough to
                    // sit under the title rather than competing with it.
                    SycamoreMark()
                        .frame(width: 30, height: 30)
                        .padding(.bottom, Spacing.medium)
                }

                IntakeTitle(isManagingCamps ? "Your camps" : "Which camp?")

                if isManagingCamps {
                    Text("Your role comes from the camp, not the login")
                        .typeStyle(.intakeSubtitleSm, color: Theme.inkMuted)
                        .padding(.top, Spacing.tight)
                } else {
                    // `verbatim:` — an interpolated literal is still a LocalizedStringKey, so
                    // the address would be Markdown-autolinked and render as a tinted link
                    // instead of the design's grey.
                    Text(verbatim: "Signed in as \(store.account?.email ?? "")")
                        .typeStyle(.intakeSubtitleSm, color: Theme.inkMuted)
                        .padding(.top, Spacing.tight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, isManagingCamps ? Spacing.gutterWide : 28)
            .padding(.bottom, 18)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            // `gap:13px` between blocks, which is what the design's flex column runs on.
            VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
                camps

                VStack(alignment: .leading, spacing: 0) {
                    IntakeSectionHeader(isManagingCamps ? "Join another" : "Join with a code")
                    joinRow
                }

                createButton

                if let message = store.errorMessage, !isManagingCamps {
                    Text(message)
                        .typeStyle(.intakeNote, color: Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, OnboardingMetrics.contentBottom)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Memberships

    /// `8u` splits the list in two: the camp you are in, then the ones you are not. Screen 3 has
    /// no camp yet, so the whole list is one card under "Your camps".
    ///
    /// A `VStack` rather than a bare `@ViewBuilder` group: the caller pads the whole block, and a
    /// `TupleView` under a padding modifier is no longer something the enclosing stack unrolls.
    private var camps: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
            if isManagingCamps, let current = store.selectedMembership {
                let rest = others(besides: current)

                VStack(alignment: .leading, spacing: 0) {
                    IntakeSectionHeader("Signed in to")
                    currentCamp(current)
                }

                if !rest.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        IntakeSectionHeader("Also yours")
                        Card(radius: OnboardingMetrics.cardRadius) {
                            ForEach(rest) { membership in
                                otherCamp(membership)
                            }
                        }
                    }
                }
            } else if store.memberships.isEmpty {
                // Still no inline loading state, and no longer because something else is drawing
                // one: the seed fall that used to lie over this whole view while `isWorking` has
                // gone (`FallingSeeds.swift`). The reason now is that nothing reaches this branch
                // *while* it is waiting. `FirstRunView` holds a frame of its own until the
                // memberships settle (`FirstRunStep.notYet`), and `8u` is opened from inside a
                // camp, which is not somewhere you can be without one.
                //
                // It is reached when the list settled at nothing, and — `FirstRunStep.CampList
                // .failed` — when it never settled at all, which is the case a spinner would seem
                // to be for. It is not: a fetch that has already been given up on is not one a
                // spinner should be promising. What that reader needs is on screen already, in
                // this view's own content — the failure printed at `:140`, the code field, "Create
                // a camp", and the `.task` above trying the fetch once more of its own accord.
                noCamps
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    IntakeSectionHeader("Your camps")
                    Card(radius: OnboardingMetrics.cardRadius) {
                        ForEach(store.memberships) { membership in
                            Button {
                                Task { await store.select(membership) }
                            } label: {
                                campRow(membership) {
                                    DisclosureChevron(size: 15)
                                        .accessibilityHidden(true)
                                }
                            }
                            .buttonStyle(.plain)
                        }
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
            radius: OnboardingMetrics.cardRadius,
            borderColor: Theme.accentBorder,
            borderWidth: BorderWidth.input,
            isDivided: false
        ) {
            campRow(membership, isCurrent: true) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                    Text("Open")
                        .typeStyle(.intakeBadge, color: Theme.accentDark)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.accentTint, in: Capsule(style: .continuous))
                // The card already reads as the camp you are in; the pill is the picture of it.
                .accessibilityHidden(true)
            }
        }
    }

    private func otherCamp(_ membership: Membership) -> some View {
        campRow(membership) {
            Button {
                Task { await store.select(membership) }
            } label: {
                Text("Switch")
                    .typeStyle(.intakeChip, color: Theme.accent)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        Theme.accentTint,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    // Drawn 34pt tall and 62 wide; only what takes the touch grows to 44.
                    .intakeTouchTarget(inset: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch to \(membership.campName)")
        }
    }

    /// Tile, name and role line — the shape every camp row in both screens shares. The trailing
    /// builder is what tells them apart: a caret, an "Open" pill, or a Switch button.
    private func campRow<Trailing: View>(
        _ membership: Membership,
        isCurrent: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13) {
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(Theme.color(for: membership.campTint))
                .frame(width: tileSize, height: tileSize)
                .overlay { Text(membership.campIcon).font(.system(size: 21)) }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(membership.campName)
                    .typeStyle(isCurrent ? .intakeCampName : .intakeCampNameSm, color: Theme.ink)
                    .lineLimit(1)
                Text(membership.subtitle)
                    // The camp you are standing in wears the green-grey that matches its border;
                    // the others are plain metadata.
                    .typeStyle(
                        .intakeRowDetail,
                        color: isCurrent ? OnboardingTheme.currentCampRole : Theme.inkMuted
                    )
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
            codeField($store.joinCodeInput)

            Button {
                Task { await store.joinCamp() }
            } label: {
                Text("Join")
                    .typeStyle(.intakeJoin, color: Theme.surface)
                    .padding(.horizontal, Spacing.section)
                    .frame(maxHeight: .infinity)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.joinCodeInput.isEmpty)
            .opacity(store.joinCodeInput.isEmpty ? 0.45 : 1)
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

    /// The same `.intakeCard` box "Shape the camp" draws its name field in — one component now,
    /// rather than the two hand-rolled copies this and `CreateCampView` had each grown.
    ///
    /// The two matched on chrome and not on behaviour: the name field carried a `.contentShape`
    /// and a tap-to-focus, this one never had either, so the 14pt of gutter around the code did
    /// nothing when you put a finger on it. `FormField` gives both the whole box.
    private func codeField(_ text: Binding<String>) -> some View {
        let field = FormField(
            "SYC-••••",
            text: text,
            label: "Invite code",
            metrics: .intakeCard,
            type: .intakeJoinCode,
            focus: $isCodeFocused
        )
        .autocorrectionDisabled()

        // Every one of these travels down the environment to the `TextField` inside `FormField`.
        #if os(iOS)
        return field
            // A code is read off a flyer, not remembered — the one-time-code type is what puts a
            // pasted or messaged one on the keyboard bar.
            .textContentType(.oneTimeCode)
            .textInputAutocapitalization(.characters)
            .submitLabel(.join)
            .onSubmit { Task { await store.joinCamp() } }
        #else
        return field
        #endif
    }

    // MARK: Create

    private var createButton: some View {
        Button {
            isCreating = true
        } label: {
            HStack(spacing: Spacing.medium) {
                IntakeIconTile(
                    "plus",
                    size: 42,
                    glyphSize: 19,
                    fill: Theme.accentSurface,
                    border: Theme.accentSurfaceBorder,
                    glyphColor: Theme.accent
                )

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(isManagingCamps ? "Start a camp" : "Create a camp")
                        .typeStyle(.intakeCampNameSm, color: Theme.accent)
                    Text("You become its first admin")
                        .typeStyle(.intakeRowMeta, color: OnboardingTheme.startCampSubtitle)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, Spacing.gutterWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: OnboardingMetrics.cardRadius, style: .continuous)
            )
            .overlay {
                // CSS draws a dashed 1.5px border as ~3× the width per dash and gap.
                RoundedRectangle(cornerRadius: OnboardingMetrics.cardRadius, style: .continuous)
                    .strokeBorder(
                        Theme.accentBorder,
                        style: StrokeStyle(lineWidth: BorderWidth.input, dash: [4.5, 4.5])
                    )
            }
            .contentShape(.rect)
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
