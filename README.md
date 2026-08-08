# Sycamore — iOS

Native SwiftUI implementation of **Sycamore Flow**, imported from the Claude Design project
[`5bfd872d`](https://claude.ai/design/p/5bfd872d-396c-4675-a650-7ee11d6f19a7). The source design
and a distilled spec live in [`design/`](design/).

Camp management for people standing on a court, not sitting at a desk. Twelve screens in three
stages: get in, run the day, and the sheets that slide over it.

> An account is a **person**, not a camp. The same login can coach one camp and administer
> another, so the camp is chosen *after* identity, and permissions come from the camp
> membership rather than the login. That premise is why `camp == nil` is a routing decision in
> `RootView` and not a state inside the tabs.

---

## Layout

```
design/          the imported design, untouched, plus SPEC.md (tokens + screen-by-screen)
Scripts/         typecheck.sh — the verification path on a machine without Xcode
Sycamore/
  App/           @main, and the routing that maps auth state onto the three stages
  DesignSystem/  Theme (colour, radii, spacing), Typography, Components, TabBar
  Models/        the domain, and SampleData reproducing the design's camp exactly
  Store/         SycamoreRepository protocol + InMemoryRepository, and the AppStore
  Features/      Auth · Camp · Groups · Rank · Setup · Profile · Sheets
  Resources/     Info.plist, and Fonts/ (see below)
```

Four tabs cover everything once you are inside: **Groups** for today, **Rank** for the order,
**Setup** for the shape of the camp, **Profile** for you. The tab bar is a pill that floats
over the content — deliberately not a `TabView`, which cannot let a list scroll underneath it.

---

## Build

Open `Sycamore.xcodeproj` in Xcode 16 or newer and run. iOS 17+, iPhone, portrait.

The project uses an Xcode 16 `PBXFileSystemSynchronizedRootGroup` pointing at `Sycamore/`, so
new source files are picked up from the filesystem without touching the project file. To
regenerate it instead:

```bash
brew install xcodegen && xcodegen generate
```

`project.yml` and the checked-in `project.pbxproj` duplicate deployment target, Info.plist path
and device family by necessity — keep them in step.

### Building on your own device

The simulator needs nothing. A physical phone needs a provisioning profile, and a profile is
issued to *a* developer — so the three settings that are a property of whoever is building live
in [`Config/Signing.xcconfig`](Config/Signing.xcconfig) rather than in the project file:

| | default |
|---|---|
| `SYCAMORE_DEVELOPMENT_TEAM` | `FYQ358R59X` |
| `SYCAMORE_BUNDLE_ID` | `com.cjgimena.app` |
| `SYCAMORE_ENTITLEMENTS` | `Config/Sycamore.entitlements` |

Do nothing and you build with those. To build under a different Apple ID:

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

Fill in your team and a bundle id nobody has registered, then reopen the project. That file is
gitignored, so building on your own phone is never a commit and never changes anyone else's
build. Set them there and not in Xcode's Signing & Capabilities tab, which writes to
`project.pbxproj` — where a target-level setting overrides the xcconfig and lands in your next
commit.

**On a free Apple ID** also clear `SYCAMORE_ENTITLEMENTS` (the example file has the line ready to
uncomment). A Personal Team cannot sign `com.apple.developer.applesignin`, and Xcode fails the
build rather than dropping the claim — "Cannot create a iOS App Development provisioning profile"
is what that looks like. The cost is only the "Continue with Apple" button: the email and
six-digit code path is untouched, and a DEBUG build's Apple button bypasses to the offline store
anyway. Free provisioning also expires after seven days, so re-run from Xcode to refresh.

> **The `.xcodeproj` has never been opened.** It was written on a machine with no Xcode (see
> below), so it is unverified. It parses as a plist and every object reference resolves, but if
> Xcode complains, that file is the first suspect — it is deliberately minimal so it is easy to
> repair by hand.

---

## Verifying without Xcode

This was built on a machine with **Command Line Tools only** — no iOS SDK, no simulator, no
`xcodebuild`. `swift build` does not work either: SwiftPM aborts in dyld with an llbuild symbol
mismatch, which is a broken toolchain install unrelated to this project.

So the verification path is:

```bash
./Scripts/typecheck.sh both
```

It typechecks the whole module under Swift 6 twice, and works around the two things that
otherwise make this impossible:

- **`#Preview` is a macro** whose plugin ships inside Xcode. The script rewrites each preview
  into the function the macro expands to, so preview bodies are still typechecked rather than
  skipped.
- **`#if os(iOS)` branches are invisible to a macOS build.** But the macOS SDK ships the Mac
  Catalyst slice under `SDKs/MacOSX*.sdk/System/iOSSupport`, and targeting
  `arm64-apple-ios17.0-macabi` makes both `os(iOS)` and `canImport(UIKit)` true — so the iOS
  half of the tree compiles for real. This is not theoretical: it caught a Swift 6 error where
  `PhotosPicker`'s `@Sendable` label closure touched main-actor state, which would have broken
  the iOS build and which no macOS-only check can see.

It is `-typecheck` only — nothing links or runs. It is not a substitute for building in Xcode,
but it catches every type, concurrency and API error. `Package.swift` exists for the same
reason and is not how the app ships.

---

## Manrope

The design is set in Manrope and every type token was measured against its metrics. **The font
files are not checked in.** Until they are, the app falls back to the system font at matching
weights — a correct app in the wrong typeface, and the single largest visual delta from the
design. Drop the five static faces into `Sycamore/Resources/Fonts/`; see the
[README there](Sycamore/Resources/Fonts/README.md) for exact filenames and why the variable
font is the wrong choice.

---

## Data

Everything runs on `InMemoryRepository`, seeded from `SampleData` to reproduce the design's camp
exactly — UCLA Tennis Camp, code `SYC-4821`, 100 kids across 🌳 Sycamore and 🎾 LATC, 14 staff,
plus a second Westside Swim membership so *Switch camp* has somewhere to go. The counts in the
UI are derived from that data rather than typed as strings: `All 100`, `1–50`/`51–100`,
`45 more in Sycamore`, `2 coaches short` and `1 over — move one kid down` all fall out of the
model.

`SycamoreRepository` is the seam where a real backend slots in. Nothing here does networking.

**On the existing backend:** the sibling web app (`sycamore-app`) has a Supabase schema with
`sites`, `coaches`, `players`, `ratings`, `assessments`, `attendance` and `court_assignments` —
but no accounts, camps, memberships or roles, and its own README lists coach logins as not yet
built. This design is deliberately ahead of that schema: identity-first auth and per-camp roles
are exactly what it does not model yet. Wiring the two together is schema work, not client work,
and has not been attempted here.

---

## Open questions

Carried over from the design, which raises them and does not answer them. They are left as
seams in the code rather than quietly decided:

- Should a camp invite code expire?
- Should a Trainer, who roams, see every court read-only?
- One profile photo per camp, or one across every camp on the account?
