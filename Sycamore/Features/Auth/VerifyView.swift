//
//  VerifyView.swift
//  Sycamore
//
//  Screen 2 — Verify. Six OTP cells backed by one hidden text field, so the system keyboard,
//  the one-time-code autofill strip and hardware paste all work while the cells stay drawn
//  exactly as the design has them.
//

import SwiftUI

struct VerifyView: View {
    @Environment(AppStore.self) private var store
    @FocusState private var isCodeFocused: Bool
    @State private var caretIsVisible = false

    /// The cell carrying the caret, or nil once every digit is in.
    private var activeIndex: Int? {
        store.isCodeComplete ? nil : store.focusedCodeIndex
    }

    var body: some View {
        VStack(spacing: 0) {
            StatusBarMock()
            prompt
            Spacer(minLength: Spacing.hero)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .onAppear {
            isCodeFocused = true
            startCaret()
        }
    }

    // MARK: Prompt

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 0) {
            CircleIconButton(systemName: "chevron.left", size: 40, tone: .filled) {
                store.backToEmail()
            }
            .padding(.bottom, 28)

            Text("Check your email")
                .typeStyle(.title1, color: Theme.ink)

            sentToLine
                .padding(.top, 10)

            codeField
                .padding(.top, 32)

            resendRow
                .padding(.top, Spacing.section)

            if let message = store.errorMessage {
                Text(message)
                    .typeStyle(.footnote, color: Theme.danger)
                    .padding(.top, Spacing.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.hero)
        .padding(.top, 30)
    }

    /// "We sent a code to **alex@uclacamp.org**" — one line, the address in 700 ink.
    private var sentToLine: some View {
        let email = store.pendingEmail ?? store.emailInput
        return (
            Text("We sent a code to ").typeStyleRun(.body, color: Theme.inkTertiary)
                + Text(email).typeStyleRun(.body.weight(.bold), color: Theme.ink)
        )
        .lineSpacing(TypeStyle.body.lineSpacing)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: OTP

    // The design draws six cells at `flex:1`, 9pt apart, 64pt tall. Eight cells share the same
    // width, so honouring all three numbers at once would leave each one about 36pt across — at
    // radius 15 the corners meet in the middle and the cell reads as a pill rather than a box.
    // The gap closes to 6 and the height to 56, which puts the aspect back near the design's.
    private var codeField: some View {
        HStack(spacing: 6) {
            ForEach(Array(store.codeDigits.enumerated()), id: \.offset) { index, digit in
                cell(digit: digit, isActive: index == activeIndex)
            }
        }
        .background(alignment: .leading) { hiddenInput }
        .contentShape(Rectangle())
        .onTapGesture { isCodeFocused = true }
        .onChange(of: store.isCodeComplete) { _, complete in
            guard complete else { return }
            isCodeFocused = false
            Task { await store.submitCode() }
        }
    }

    private func cell(digit: String, isActive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.input, style: .continuous)

        return shape
            .strokeBorder(
                isActive ? Theme.accent : Theme.stroke,
                lineWidth: isActive ? BorderWidth.focus : BorderWidth.input
            )
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .overlay {
                if !digit.isEmpty {
                    Text(digit)
                        .typeStyle(.otpDigit, color: Theme.ink)
                } else if isActive {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: 2, height: 24)
                        .opacity(caretIsVisible ? 1 : 0)
                }
            }
    }

    /// The real text field. One point square and effectively invisible: it exists so the
    /// keyboard, autofill and selection machinery have something genuine to talk to.
    private var hiddenInput: some View {
        let base = TextField("", text: codeBinding)
            .textFieldStyle(.plain)
            .focused($isCodeFocused)
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .accessibilityLabel("Verification code")

        #if os(iOS)
        return base
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
        #else
        return base
        #endif
    }

    /// Keeps the store's `codeInput` to at most `SupabaseConfig.codeLength` digits however the
    /// text arrives — typed, pasted or autofilled. Backspace simply shortens the string, which
    /// walks the caret back a cell for free.
    private var codeBinding: Binding<String> {
        Binding(
            get: { store.codeInput },
            set: {
                store.codeInput = String(
                    $0.filter(\.isNumber).prefix(SupabaseConfig.codeLength)
                )
            }
        )
    }

    private func startCaret() {
        caretIsVisible = false
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
            caretIsVisible = true
        }
    }

    // MARK: Resend

    private var resendRow: some View {
        Button {
            Task { await store.resendCode() }
        } label: {
            HStack(spacing: Spacing.small) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .regular))
                Text(store.resendLabel)
                    .typeStyle(.countdown)
            }
            .foregroundStyle(store.canResend ? Theme.accent : Theme.inkFaint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!store.canResend)
    }

    // MARK: Footer

    private var footer: some View {
        InfoBanner(
            "Your permissions come from the camp, not the login. The same account can be an admin at one camp and a coach at another.",
            systemImage: "checkmark.shield",
            tone: .grouped,
            font: .caption,
            radius: Radius.input,
            horizontalPadding: 15,
            verticalPadding: 15,
            spacing: Spacing.medium,
            iconSize: 21,
            alignment: .top
        )
        .padding(.horizontal, Spacing.hero)
        .padding(.bottom, 48)
    }
}

// MARK: - Previews

#Preview("Verify") {
    VerifyView()
        .environment(AppStore.previewAwaitingCode)
        .showsMockStatusBar()
}

#Preview("Verify — empty") {
    let store = AppStore()
    store.auth = .awaitingCode(email: SampleData.account.email)
    store.resendSeconds = 42
    return VerifyView()
        .environment(store)
        .showsMockStatusBar()
}
