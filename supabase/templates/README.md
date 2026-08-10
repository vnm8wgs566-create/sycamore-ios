# Auth email templates

`sycamore-otp-email.html` is the message screen 2 is waiting for — the digits a person types into
`VerifyView`. Imported from the Claude Design project
[`e972029f`](https://claude.ai/design/p/e972029f-505b-4082-86cd-2cf3e0c7c9d6).

There is no `supabase/config.toml` in this repo, so the CLI never reads this directory. The file
lives here to be **pasted into the dashboard** — Authentication → Emails — and to be reviewable in
a diff when it changes. Regenerate it by re-importing the design project rather than editing it in
the dashboard and letting the two drift.

---

## Where it goes

Paste the same HTML into **two** templates. `SupabaseAuth.requestCode` posts to `/otp` with
`create_user: true`, and GoTrue picks the template by whether the address already exists:

| Address | Template GoTrue sends |
|---|---|
| already a user | **Magic Link** |
| first time | **Confirm signup** |

Only doing Magic Link is the failure that hides: everyone testing already has an account, so it
looks correct right up until a new coach signs up and gets Supabase's stock "Confirm your signup"
link — which the app has no screen for. Set the subject on both to *Your Sycamore sign-in code*.

## What it depends on

**The mark has to be hosted.** The masthead points at
`https://sycamorecamps.com/email/sycamore-mark-240.png`. The file is checked in beside this README
at [`assets/sycamore-mark-240.png`](assets/sycamore-mark-240.png) (240×240, corners already baked
in, transparent outside them — the `border-radius:9px` in the HTML is only for clients that would
otherwise square it off). Until it is uploaded to that path, every inbox shows a broken image where
the logo belongs.

**The cell count has to equal the project's OTP length, which is 8.** The cells are
`{{ slice .Token 0 1 }}` … `{{ slice .Token 7 8 }}`, and the same 8 is spelled once in
`SupabaseConfig.codeLength` — which is what `VerifyView` draws, what its hidden field truncates
to, and what **both** repositories check a submitted code against before they do anything with it.
Everything in the app reads that constant, so the count that has to be kept in agreement by hand
is only the one in this file.

That was not true until 2026-08-10. `SupabaseRepository.verifySignInCode` and
`InMemoryRepository.verifySignInCode` each carried their own `guard digits.count == 6`, written
after the constant landed and never pointed at it — so an eight-digit code was refused *before the
network*, with the mail correct, eight cells drawn and filled, and nothing in the auth log to look
at. `SignInChallenge` carried a third copy, a `codeLength` defaulting to 6 that nothing read; it is
gone rather than corrected, because a number kept in two places is what this whole section is about.

This is the bug that cost the most time here, so it is worth stating plainly. Go's `slice` panics
past the end of a string, so setting the OTP length *below* the cell count breaks the template
outright — no mail is sent at all, and sign-in simply never arrives. Setting it *above* is quieter
and far worse: the mail goes out showing the first N digits of a longer token. It looks completely
correct. The digits are even genuine. It just can never verify, and nothing in the app, the email,
or the auth log says why — `/verify` only ever answers `otp_expired`.

That is not hypothetical. The project ran at OTP length 8 against six cells, and the only way to
see it was to compare `sha224(email ‖ candidate)` against `auth.users.confirmation_token`. If the
length changes again and you would rather not maintain the count, use the single-plate fallback
commented out inside the file: it prints `{{ .Token }}` whole and cannot go stale.

**Sixty minutes is a claim about a setting.** "The code expires in 60 minutes" and the preview text
both restate the project's OTP expiry (Supabase's default, 3600s). Change one, change the copy.

## Checking it

Paste into the dashboard's template editor and use its preview, or open the file locally — the Go
tags render as literal text, which is enough to check layout, the dark-mode block, and the
`max-width: 620px` collapse. What a local open cannot tell you is how Outlook handles it; the
`mso-line-height-rule` declarations are there for that, and the rounded corners are expected to
square off on Windows Outlook by design.

**GoTrue strips HTML comments before sending.** Confirmed by reading a delivered message back out of
Resend: every `<!-- … -->` in this file — the section markers, the commented-out single-plate
fallback, and the `<!--[if mso]>` PixelsPerInch block — is gone from the mail that actually goes out.
Two consequences. The `<!--[if mso]>` block is decorative here and cannot be relied on, so the inline
`mso-*` properties are doing the whole job on Outlook. And the fallback really is inert: its
`{{ .Token }}` never renders, so it cannot leak the code into a comment.

## Verified

2026-08-10, end to end: `POST /auth/v1/otp` → delivered to a real inbox → message read back from
Resend. `slice` works — the cells came through as separate digits, and `{{ .Email }}` interpolated
in both places. Two blockers were cleared on the way, neither of them the template: the Resend
sending domain sat at `not_started` because verification had never been triggered, so every send
died on an SMTP `550` before the body mattered; and the cell count disagreed with the OTP length,
as above.

Two things that test could not reach:

- **The Magic Link template is still unexercised.** While the account is unconfirmed GoTrue keeps
  sending *Confirm signup*, so repeated requests never reach the other template. It gets its first
  real run the first time somebody completes a sign-in.
- **The subject line is separate from the body.** The delivered mail arrived titled "Confirm your
  email address" — Supabase's stock subject — because pasting the HTML does not change it. Set it on
  both templates, or the message announces itself as a confirmation and then shows a sign-in code.

## Applied to the dashboard

2026-08-09: this 8-cell HTML is now live in **both** *Confirm signup* and *Magic Link*, and both
subjects are set to *Your Sycamore sign-in code*. Verified by reading the project's auth config back
(`GET /v1/projects/{ref}/config/auth`): `mailer_otp_length` is `8`, both template bodies match this
file byte-for-byte, and both subjects match.

2026-08-10, re-read after this branch merged to `main`, and it still holds: `mailer_otp_length` `8`,
both bodies byte-identical to this file, both subjects *Your Sycamore sign-in code*. **There is
nothing to paste** — the dashboard is already carrying exactly these bytes, and it only needs
touching again if this file changes. The length now agrees everywhere: config `8`, cells `8`,
`SupabaseConfig.codeLength` `8`, and both repositories' verify guards reading that constant instead
of a literal 6.

Written through the Management API, not pasted. One gotcha worth recording: the API sits behind
Cloudflare, and a `Python-urllib` User-Agent is refused with **403 `error code: 1010`** (a banned
client signature) regardless of the body. `curl` and browsers are fine. The `1010` looks exactly
like a content/permission rejection and is neither — send template writes from `curl`.

**Still outstanding, and only the account owner can do it:** the masthead logo at
`https://sycamorecamps.com/email/sycamore-mark-240.png` returns **404**, so every inbox shows a
broken image until [`assets/sycamore-mark-240.png`](assets/sycamore-mark-240.png) is uploaded to
that path. Nothing in the app or the auth config can fix this — it is a file on the web host.
Re-checked 2026-08-10: the site itself answers 200, the image is still 404.

A data URI is not the way out of this, tempting as it looks. Gmail and Outlook.com both refuse to
render `src="data:image/png;base64,…"` in a `<img>`, so it trades a broken image in every inbox for
a broken image in most of them, and inlines 8 KB into a template that GoTrue stores as a string.
Either host the file, or delete the `<td>` holding the `<img>` and let the wordmark stand alone —
the masthead is a two-cell table and reads correctly with one of them gone.
