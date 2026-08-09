//
//  FirstRunHeader.swift
//  Sycamore
//
//  The white plate at the top of a first-run question: the mark, the heading, and the address
//  you are signed in as.
//
//  Screen 3 draws it first (`CampPickerView.swift:79-123`), and the two questions in front of it
//  now draw the same one — same 30pt mark over `Spacing.medium`, same serif heading, same grey
//  line under it, same `28`/`18` above and below. Written out twice it was two copies of three
//  literals and of the `verbatim:` note that stops SwiftUI autolinking the address; written out
//  three times it would be the point at which they start to drift, and the drift is invisible
//  because no two of these screens are ever on screen together.
//
//  ---------------------------------------------------------------------------------------------
//  WHY NOT `IntakeHeader`
//  ---------------------------------------------------------------------------------------------
//
//  `IntakeHeader` is the *other* header this branch has — the compact one `8c`, `8d` and `8e` use,
//  with a title, a subtitle and a trailing action, and no mark. Its own header comment already
//  anticipates the question and answers it the way this file does: "Fold the two together if a
//  third caller ever wants both." A third caller wants the mark and no action, which is not what
//  that type is; folding them would give one type two mutually exclusive halves.
//
//  Screen 3's copy is not folded in here either, and that is an ownership line rather than a
//  design one: `CampPickerView` belongs to another branch in flight. It is the fourth copy and it
//  should come here when the folders settle — the same "hoist once section 8 lands" this branch's
//  tokens carry (`OnboardingTokens.swift:11-16`).
//

import SwiftUI

struct FirstRunHeader: View {

    let title: String
    /// The account this is being asked of. Drawn as "Signed in as …" — the same line screen 3
    /// leads with, because these questions arrive in the same breath as that one and the address
    /// is the only thing on screen tying them to the account they are about.
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBarMock()

            VStack(alignment: .leading, spacing: 0) {
                // The one brand beat between an email address and a camp, and the only place the
                // app has to say whose these screens are. Small enough to sit under the heading
                // rather than compete with it.
                SycamoreMark()
                    .frame(width: 30, height: 30)
                    .padding(.bottom, Spacing.medium)

                IntakeTitle(title)

                // `verbatim:` — an interpolated literal is still a `LocalizedStringKey`, SwiftUI
                // parses those as Markdown, and Markdown autolinks a bare email address. Without
                // it the line renders as a tinted link that ignores every foreground colour set
                // on it. `CampPickerView.swift:109-111` carries the same note over the same line.
                Text(verbatim: "Signed in as \(email)")
                    .typeStyle(.intakeSubtitleSm, color: Theme.inkMuted)
                    .padding(.top, Spacing.tight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.header)
            .padding(.top, 28)
            .padding(.bottom, 18)
        }
        .background(Theme.surface)
    }
}

// MARK: - Previews

#Preview("First-run header") {
    VStack(spacing: 0) {
        FirstRunHeader(title: "What should we call you?", email: "alex@uclacamp.org")
        Hairline(color: Theme.hairline)
        Spacer()
    }
    .background(Theme.surfaceWarm)
}
