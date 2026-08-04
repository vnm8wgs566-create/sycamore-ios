//
//  EmailAddress.swift
//  Sycamore
//
//  One answer to "is this an email address", because there used to be three.
//
//  The sign-in screen, the profile editor and the repository each carried their own
//  `contains("@") && contains(".")`, which agreed with each other only by luck and let
//  `a@.` through all three. A coach who fat-fingers their address should be told at the
//  field, not discover it when the code never arrives.
//

import Foundation

enum EmailAddress {

    /// Trimmed and lower-cased, which is the form the repository stores and compares.
    static func normalised(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// A deliberately shallow check: exactly one `@`, something before it, and a domain that
    /// looks like a domain.
    ///
    /// It is not RFC 5322 — full compliance admits quoted strings, comments and bracketed IP
    /// literals, and a validator strict enough to reject real addresses is worse than one that
    /// waves through a typo. Anything that passes here still has to survive a real send; this
    /// only catches the mistakes worth catching at the keyboard.
    static func isValid(_ raw: String) -> Bool {
        let address = normalised(raw)

        // No whitespace anywhere, and no stray angle brackets from a pasted "Name <a@b.com>".
        guard !address.isEmpty,
              address.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !address.contains("<"), !address.contains(">")
        else { return false }

        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }

        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty else { return false }

        // The domain needs at least one dot with real labels either side, so `a@.`, `a@b.`
        // and `a@.b` are all rejected while `a@b.co` passes.
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }

        // A bare trailing label of one character is a typo far more often than a real TLD.
        return (labels.last?.count ?? 0) >= 2
    }
}
