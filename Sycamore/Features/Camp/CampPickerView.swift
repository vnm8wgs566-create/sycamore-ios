//
//  CampPickerView.swift
//  Sycamore
//
//  "Your camps" — every camp this login works or runs, and the two ways to get another one.
//
//  ── It used to be two screens wearing one view ────────────────────────────────────────────────
//
//  `isManagingCamps` decided between "Which camp?" (stage 1: identity settled, nothing loaded) and
//  `8u` "Manage camps" (the same list, opened from inside a camp). It picked the title, the
//  subtitle, the leading glyph, whether the list was one card or two under "Signed in to" and
//  "Also yours", what the dashed card at the bottom was called, and whether a failure printed at
//  all. Six differences to say one thing: that sometimes a camp is already loaded.
//
//  `design/app/regions/showCamps.html` draws one screen. One title, one list where every card is
//  the same card, and two actions under it — start one, or join one. So that is what this is now,
//  and `isManagingCamps` is down to the only thing it was ever really saying: whether this was
//  presented over something, and therefore whether there is a way back out of it.
//
//  What that bought, besides the reading: `store.errorMessage` prints in both contexts. It was
//  guarded by `!isManagingCamps`, so a join or a switch that failed from inside a camp left the
//  screen sitting still and saying nothing.
//
//  This view owns the navigation stack that "Start a camp" pushes screen 4 onto. Present it bare,
//  without wrapping it in a stack of your own.
//

import SwiftUI

struct CampPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Whether this was presented over something — Profile, Overview's venue row, the camp page.
    ///
    /// Kept as the parameter's old name because three call sites outside this file pass it, and
    /// its old meaning ("this is `8u` rather than screen 3") is a fair reading of the new one:
    /// there is a camp loaded behind this, so there is somewhere to go back to and something to
    /// close when the errand is done.
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
        // Switching, joining and creating all end in `select(_:)`. When something is behind this,
        // that finishes the errand: close this sheet and whatever raised it — Profile, or the camp
        // page, both of which describe a camp that is no longer the one loaded.
        .onChange(of: store.selectedMembership?.id) { _, _ in
            guard isManagingCamps else { return }
            // Both are state changes rather than imperative dismissals, so SwiftUI settles them
            // in one pass: this sheet and the screen under it go together.
            store.pushedScreen = nil
            dismiss()
        }
    }

    /// The screen draws its own header, so the stack's bar stays hidden.
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
                    .accessibilityLabel("Back")
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

                IntakeTitle("Your camps")

                // One line, in both contexts. It says the thing that is true either way and is
                // the reason this screen exists at all — the login is a person, the role comes
                // from the camp. The pair it replaces ("Signed in as …" / "Your role comes from
                // the camp, not the login") said one of those things to each half of the audience.
                Text("One login, every camp you work or run")
                    .typeStyle(.intakeSubtitleSm, color: Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.tight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, isManagingCamps ? Spacing.gutterWide : 28)
            .padding(.bottom, 18)
        }
        .background(Theme.surface)
    }

    // MARK: Content

    /// The design's order: the camps, then the two things you can do about not having the one you
    /// want — start another, or join one somebody else runs.
    private var content: some View {
        ScrollView {
            // `gap:13px` between blocks, which is what the design's flex column runs on.
            VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
                camps

                createButton

                VStack(alignment: .leading, spacing: 0) {
                    IntakeSectionHeader("Join another")
                    joinRow
                }

                // The failure is not printed here, and every route that draws this view
                // carries a banner instead.
                //
                // It used to be printed inline, from when this screen could be reached with
                // nothing else on it to report a bad code. Since an empty membership list lands
                // here, the first run showed it twice — once in `RootView`'s banner and once in
                // the middle of the page.
                //
                // The three presenters each carry their own, because a sheet covers the
                // presenter's overlay: `RootView:96` for the first run, `ProfileView:160` and
                // `CampHomeView:105` for the two that raise it as a sheet from inside a camp.
                // That last one was missed when the inline copy was removed, which made a bad
                // code silent on exactly the route this comment used to be about.
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, OnboardingMetrics.contentBottom)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Memberships

    /// One list, one row shape. The camp you are standing in — if you are standing in one — ends
    /// in a pill instead of a caret and closes back into itself rather than reloading.
    ///
    /// A `VStack` rather than a bare `@ViewBuilder` group: the caller pads the whole block, and a
    /// `TupleView` under a padding modifier is no longer something the enclosing stack unrolls.
    private var camps: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.memberships.isEmpty {
                // Still no inline loading state, and not because something else draws one:
                // nothing reaches this branch *while* it is waiting. `FirstRunView` holds a frame
                // of its own until the memberships settle (`FirstRunStep.notYet`), and everywhere
                // else this is opened from inside a camp, which is not somewhere you can be
                // without one.
                //
                // It is reached when the list settled at nothing, and — `FirstRunStep.CampList
                // .failed` — when it never settled at all, which is the case a spinner would seem
                // to be for. It is not: a fetch that has already been given up on is not one a
                // spinner should be promising. What that reader needs is on screen already — the
                // failure printed above, the code field, "Start a camp", and the `.task` trying
                // the fetch once more of its own accord.
                noCamps
            } else {
                Card(radius: OnboardingMetrics.cardRadius) {
                    ForEach(store.memberships) { membership in
                        Button {
                            open(membership)
                        } label: {
                            campRow(membership)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func isCurrent(_ membership: Membership) -> Bool {
        store.selectedMembership?.id == membership.id
    }

    /// Tapping the camp you are already in has nothing to load. It closes, which is what the
    /// person meant: they came here to change camps and changed their mind.
    private func open(_ membership: Membership) {
        if isCurrent(membership) {
            dismiss()
        } else {
            Task { await store.select(membership) }
        }
    }

    /// Shown in place of the card when the account belongs to no camp yet. Without it the screen
    /// drew a title with nothing under it, which read as a screen that had failed to load rather
    /// than one waiting for a first camp.
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
            Text("Start one below, or join a camp somebody else runs with their code.")
        }
        .frame(maxWidth: .infinity)
    }

    /// Tile, name and role line, and whatever closes the row: a caret for a camp you can move to,
    /// a pill for the one you are in.
    private func campRow(_ membership: Membership) -> some View {
        let isCurrent = isCurrent(membership)

        return CardRow(spacing: Spacing.medium, horizontalPadding: 13, verticalPadding: 13) {
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
                    // The camp you are standing in wears the green-grey that names it; the others
                    // are plain metadata. `inkTertiary` rather than the design's `#8A8E96`, which
                    // measures about 3.3:1 on white — this line is the role and the court, which
                    // is what somebody is reading the row for.
                    .typeStyle(
                        .intakeRowDetail,
                        color: isCurrent ? OnboardingTheme.currentCampRole : Theme.inkTertiary
                    )
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.small)

            if isCurrent {
                openPill
            } else {
                DisclosureChevron()
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: HitTarget.minimum)
        // The pill is a picture of "this one", so it is hidden and the row says it instead —
        // otherwise VoiceOver reads "UCLA Tennis Camp, Admin · 3 venues · 74 kids, Open" and the
        // word that matters is the one that sounds like a verb.
        .accessibilityValue(isCurrent ? "Current camp" : "")
    }

    /// The accent dot and "Open" on the camp you are signed in to.
    private var openPill: some View {
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
        .accessibilityHidden(true)
    }

    // MARK: Start a camp

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
                    Text("Start a camp")
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

    // MARK: Join another

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
}

// MARK: - Previews

/// Three camps with one of them loaded — the list at its busiest, and the only state that draws
/// the "Open" pill. `SampleData` ships two, so the third is a copy of one with a different name,
/// tint and role: what this preview is for is the row *shape* repeating, not a third fixture.
#Preview("Your camps — three, one open") {
    let store = AppStore.preview
    var third = SampleData.westsideMembership
    third.id = UUID()
    third.role = .trainer
    third.campName = "Palisades Juniors"
    third.campIcon = "⭐"
    third.campTint = .citron
    third.campSummary = "1 venue · 28 kids"
    store.memberships = SampleData.memberships + [third]

    return CampPickerView(isManagingCamps: true)
        .environment(store)
        .showsMockStatusBar()
}

/// One camp, no camp loaded — the first run, where there is no way back and no pill.
#Preview("Your camps — one, first run") {
    let store = AppStore(repository: InMemoryRepository(memberships: [SampleData.uclaMembership]))
    store.auth = .signedIn(SampleData.account)
    store.memberships = [SampleData.uclaMembership]

    return CampPickerView()
        .environment(store)
        .showsMockStatusBar()
}

#Preview("Your camps — none") {
    let store = AppStore(repository: InMemoryRepository(memberships: []))
    store.auth = .signedIn(SampleData.account)
    return CampPickerView()
        .environment(store)
        .showsMockStatusBar()
}
