//
//  IntakeChoiceChip.swift
//  Sycamore
//
//  `8e`'s equal-width answers: black fill and white label when chosen, a `strokeChip` outline and
//  `inkMuted` label when not. Radius 11, 9pt of vertical padding, no horizontal padding — the row
//  divides the width between them.
//
//  Not `DesignSystem/Chip`, whose unselected label is `700 12.5` on `inkSecondary`; section 8
//  draws it `600 12.5` on `inkMuted`, and the shared one cannot say it is selected out loud.
//

import SwiftUI

struct IntakeChoiceChip: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)

        Button(action: action) {
            Text(title)
                .typeStyle(.intakeChip, color: isSelected ? Theme.onAccent : Theme.inkMuted)
                // Kept, though the answer that needed it is gone. "Prefer not to say" wrapped to
                // two lines at every type size and is now "Other", which does not — but the
                // gender row is not this chip's only caller: `8e`'s venue row puts whatever the
                // camp named its venues through the same control, at a third of the width each.
                // Left-ragged second lines in an equal-width row is the state this prevents.
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Theme.ink : Theme.surface, in: shape)
                .overlay {
                    if !isSelected {
                        shape.strokeBorder(Theme.strokeChip, lineWidth: BorderWidth.hairline)
                    }
                }
                // Drawn 33pt tall. Only the vertical is short, and the chips are 6pt apart, so
                // the touch grows up and down rather than into its neighbour.
                .padding(.vertical, 5.5)
                .contentShape(.rect)
                .padding(.vertical, -5.5)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Previews

#Preview("Answer chips") {
    @Previewable @State var choice = 0
    let answers = Gender.intakeOptions.map(\.label)

    HStack(spacing: Spacing.tight) {
        ForEach(answers.indices, id: \.self) { index in
            IntakeChoiceChip(title: answers[index], isSelected: choice == index) {
                choice = index
            }
        }
    }
    .padding(Spacing.gutterWide)
    .background(Theme.surface)
}
