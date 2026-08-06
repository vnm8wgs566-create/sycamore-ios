//
//  EmailAddressTests.swift
//  SycamoreTests
//
//  `EmailAddress` exists because the sign-in screen, the profile editor and the repository each
//  carried their own `contains("@") && contains(".")`. All three agreed that `a@.` was an email
//  address, and the coach who typed it found out when the code never arrived.
//
//  The tests below are the cases that check disagreed on, plus the two directions the rule can
//  fail: too loose lets a typo through, too strict rejects a real address — and a validator that
//  rejects a real address is the worse of the two, because there is nothing the person can do.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("EmailAddress.normalised")
struct EmailAddressNormalisationTests {

    @Test("Trims and lower-cases, which is the form the repository stores")
    func trimsAndLowercases() {
        #expect(EmailAddress.normalised("  Alex@UCLACamp.org  ") == "alex@uclacamp.org")
    }

    @Test("Strips a trailing newline, which is what a paste brings with it")
    func stripsNewlines() {
        #expect(EmailAddress.normalised("\nalex@uclacamp.org\n") == "alex@uclacamp.org")
    }

    @Test("Leaves an already-normalised address untouched")
    func isIdempotent() {
        let once = EmailAddress.normalised("  Alex@UCLACamp.org ")
        #expect(EmailAddress.normalised(once) == once)
    }

    @Test("Does not touch inner whitespace — that is a validity question, not a shape one")
    func keepsInnerWhitespace() {
        #expect(EmailAddress.normalised(" a b@c.co ") == "a b@c.co")
    }
}

@Suite("EmailAddress.isValid")
struct EmailAddressValidityTests {

    // MARK: The addresses that must pass

    @Test("Accepts ordinary addresses", arguments: [
        "a@b.co",
        "alex@uclacamp.org",
        "alex.ramos@uclacamp.org",
        "alex_ramos@ucla-camp.org",
        // Sub-domains: three labels is still "a dot with real labels either side".
        "alex@mail.uclacamp.org",
        // The relay address the offline build's Apple sign-in stands in.
        "apple.user@privaterelay.appleid.com",
        // Plus-addressing. Real, common, and the reason the query layer escapes `+` by hand.
        "alex+camp@uclacamp.org",
        // A long TLD, and a numeric one — both exist.
        "coach@sycamore.marketing",
        "coach@sycamore.co1",
    ])
    func accepts(_ address: String) {
        #expect(EmailAddress.isValid(address))
    }

    @Test("Accepts an address that only needs trimming or lower-casing first")
    func normalisesBeforeJudging() {
        #expect(EmailAddress.isValid("  Alex@UCLACamp.org  "))
        #expect(EmailAddress.isValid("ALEX@UCLACAMP.ORG"))
    }

    // MARK: The four the old checks let through

    /// Named in `EmailAddress`'s own doc comment. Each of these passed
    /// `contains("@") && contains(".")` in all three places it was written.
    @Test("Rejects the domains the old three-way check waved through", arguments: [
        "a@.",
        "a@b.",
        "a@.b",
        // One-character TLD: a typo far more often than a real address.
        "a@b.c",
    ])
    func rejectsTheOldFalsePositives(_ address: String) {
        #expect(!EmailAddress.isValid(address))
    }

    // MARK: The rest of the shape

    @Test("Rejects addresses that are not addresses at all", arguments: [
        "",
        "   ",
        "alex",
        "uclacamp.org",
        // Nothing before the @.
        "@uclacamp.org",
        "@",
        // Nothing after it.
        "alex@",
        // Exactly one @ — two is a different address, or a paste of two.
        "alex@camp@uclacamp.org",
        // An empty label in the middle is as broken as one on the end.
        "alex@uclacamp..org",
        "alex@.uclacamp.org",
    ])
    func rejects(_ address: String) {
        #expect(!EmailAddress.isValid(address))
    }

    @Test("Rejects an address with whitespace inside it")
    func rejectsInnerWhitespace() {
        #expect(!EmailAddress.isValid("alex ramos@uclacamp.org"))
        #expect(!EmailAddress.isValid("alex@uclacamp .org"))
        #expect(!EmailAddress.isValid("alex@uclacamp.org extra"))
        #expect(!EmailAddress.isValid("alex\t@uclacamp.org"))
    }

    /// Copying a row out of a mail client gives you `Alex Ramos <alex@uclacamp.org>`. Accepting
    /// it would post the brackets to the server, which then has an address nobody can deliver to.
    @Test("Rejects a display-name paste")
    func rejectsADisplayNamePaste() {
        #expect(!EmailAddress.isValid("Alex Ramos <alex@uclacamp.org>"))
        #expect(!EmailAddress.isValid("<alex@uclacamp.org>"))
    }

    /// Deliberately shallow, and this pins the shallowness so nobody "fixes" it into a rule that
    /// rejects real mailboxes. Anything here still has to survive a real send.
    @Test("Does not attempt to police the local part")
    func leavesTheLocalPartAlone() {
        #expect(EmailAddress.isValid(".alex@uclacamp.org"))
        #expect(EmailAddress.isValid("alex.@uclacamp.org"))
        #expect(EmailAddress.isValid("!#$%@uclacamp.org"))
    }

    @Test("Judging is unaffected by normalising first")
    func agreesWithItselfAfterNormalising() {
        for address in ["  Alex@UCLACamp.org  ", "a@.", "A@B.CO", " ", "alex@camp@x.org"] {
            #expect(EmailAddress.isValid(address) == EmailAddress.isValid(EmailAddress.normalised(address)))
        }
    }
}
