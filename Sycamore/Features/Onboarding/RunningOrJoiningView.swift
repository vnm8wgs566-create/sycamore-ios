//
//  RunningOrJoiningView.swift
//  Sycamore
//
//  The second question after signing in: which way in.
//
//  A brand-new account used to meet screen 3 — a list headed "Your camps" with nothing under it,
//  a field for a code nobody had given them, and a dashed card at the bottom. Every one of those
//  controls is the right control; none of them is the question the person is actually holding,
//  which is "am I the one setting this up, or was I sent a code?" Two answers, one tap, and the
//  screen they land on is the one they needed.
//
//  ---------------------------------------------------------------------------------------------
//  IT STEERS THE ROUTE — IT DOES NOT WRITE A ROLE
//  ---------------------------------------------------------------------------------------------
//
//  It reads as a question about who you are, and it must not become one. `Membership.role` is
//  decided by what happens next: `Repository.createCamp` makes the account that created it an
//  admin, `joinCamp` takes whatever the camp's invite grants. There is no role on the account and
//  there is deliberately no column for one — the same login is an admin at one camp and a worker
//  at another, which is the whole of `Role`'s argument and what screen 3's own header line says
//  out loud ("Your role comes from the camp, not the login", `CampPickerView.swift:105`).
//
//  So this hands back a `FirstRunStep.Path` and nothing else. The footnote under the two cards
//  says the same thing in the reader's terms, because a screen that looks like it is asking you
//  to pick a rank should say what it is really doing.
//
//  Neither answer is a commitment. Creating a camp still leaves the code field one screen away,
//  and joining one leaves "Create a camp" on the picker it lands on — which is why there is no
//  back caret here and does not need to be.
//

import SwiftUI

struct RunningOrJoiningView: View {

    let email: String
    let onChoose: (FirstRunStep.Path) -> Void

    var body: some View {
        VStack(spacing: 0) {
            FirstRunHeader(title: "Running a camp, or joining one?", email: email)
            Hairline(color: Theme.hairline)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceWarm)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingMetrics.blockGap) {
                choice(
                    "I'm running one",
                    detail: "Name it, shape the venues, bring in the week",
                    glyph: "plus",
                    hint: "Opens Shape the camp",
                    path: .creatingACamp
                )

                choice(
                    "I've been given a code",
                    detail: "Join a camp somebody has already set up",
                    glyph: "number",
                    hint: "Opens your camps, where the code goes",
                    path: .joiningOne
                )

                // The honest reading of the question above, and the reason it is not a role
                // picker. See the header.
                Text("Starting a camp makes you its admin. A code gives you whatever that camp granted you.")
                    .typeStyle(.intakeFootnote, color: Theme.inkGhost)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.tight)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.large)
            .padding(.bottom, OnboardingMetrics.contentBottom)
        }
    }

    /// One of the two answers, drawn as screen 3 draws its "Create a camp" card
    /// (`CampPickerView.swift:376-417`): a tinted tile, two lines, and the dashed accent rule that
    /// says this card makes something rather than opens something.
    ///
    /// Both are dashed rather than one. The two are a pair of equal answers, and giving the
    /// creating one heavier chrome would read as the recommended choice — which it is not: most
    /// people arriving at a camp were handed a code.
    private func choice(
        _ title: String,
        detail: String,
        glyph: String,
        hint: String,
        path: FirstRunStep.Path
    ) -> some View {
        Button {
            onChoose(path)
        } label: {
            HStack(spacing: Spacing.medium) {
                IntakeIconTile(
                    glyph,
                    size: 42,
                    glyphSize: 19,
                    fill: Theme.accentSurface,
                    border: Theme.accentSurfaceBorder,
                    glyphColor: Theme.accent
                )

                VStack(alignment: .leading, spacing: Spacing.hairGap) {
                    Text(title)
                        .typeStyle(.intakeCampNameSm, color: Theme.accent)
                    Text(detail)
                        .typeStyle(.intakeRowMeta, color: OnboardingTheme.startCampSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                DisclosureChevron(size: 15)
                    .accessibilityHidden(true)
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
            // The card is well past 44pt on its own; the shape is what makes the whole of it —
            // including the gutters — answer a finger rather than only the two lines of type.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

// MARK: - Previews

#Preview("Running a camp, or joining one?") {
    RunningOrJoiningView(email: "alex@uclacamp.org", onChoose: { _ in })
        .showsMockStatusBar()
}

#Preview("Running a camp, or joining one? — large type") {
    RunningOrJoiningView(email: "alex@uclacamp.org", onChoose: { _ in })
        .showsMockStatusBar()
        .dynamicTypeSize(.accessibility1)
}
