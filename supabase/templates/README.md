# Auth email templates

`sycamore-otp-email.html` is the message screen 2 is waiting for — the six digits a person types
into `VerifyView`. Imported from the Claude Design project
[`e972029f`](https://claude.ai/design/p/e972029f-505b-4082-86cd-2cf3e0c7c9d6), verbatim.

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

**The token has to be six characters.** The cells are `{{ slice .Token 0 1 }}` … `{{ slice .Token 5 6 }}`.
Go's `slice` panics past the end of a string, so shortening the project's OTP length breaks the
template outright — no email is sent at all, which surfaces as sign-in silently never arriving.
Lengthening it is quieter and worse: the mail goes out showing the first six of eight digits, and
the code simply never works. If the length ever has to change, use the single-plate fallback that
ships commented out inside the file.

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
Resend. `slice` works — the six cells came through as six separate digits, and `{{ .Email }}`
interpolated in both places. The blocker that made this take a while was never the template: the
Resend sending domain sat at `not_started` because verification had never been triggered, so every
send died on an SMTP `550` before the body mattered.

Two things that test could not reach:

- **The Magic Link template is still unexercised.** While the account is unconfirmed GoTrue keeps
  sending *Confirm signup*, so repeated requests never reach the other template. It gets its first
  real run the first time somebody completes a sign-in.
- **The subject line is separate from the body.** The delivered mail arrived titled "Confirm your
  email address" — Supabase's stock subject — because pasting the HTML does not change it. Set it on
  both templates, or the message announces itself as a confirmation and then shows a sign-in code.
