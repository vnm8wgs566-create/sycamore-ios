# Sycamore Flow — implementation spec

Distilled from `design/Sycamore Flow.dc.html` (the canonical source; consult it for any
detail not captured here). Twelve screens in three stages.

> **Premise.** An account is a *person*, not a camp. The same login can coach one camp and
> administer another, so the camp is chosen **after** identity, never before. Permissions come
> from the camp membership, not the login.

Once inside, four tabs cover everything:
**Groups** (today) · **Rank** (the order) · **Setup** (shape of the camp) · **Profile** (you).

---

## 1. Design tokens

Taken verbatim from the design's inline styles.

### Colour

| Token | Hex | Use |
|---|---|---|
| `ink` | `#0B0B0C` | primary text, dark buttons, active pill |
| `inkSecondary` | `#5C6068` | secondary text, chip labels |
| `inkTertiary` | `#71757E` | body copy on light surfaces |
| `inkMuted` | `#8A8E96` | metadata, section headers |
| `inkFaint` | `#A2A6AE` | placeholders, disabled |
| `inkGhost` | `#B0B4BB` | rank numerals, caret glyphs |
| `chevron` | `#C7CBD2` | disclosure carets, drag handles |
| `accent` | `#1568F0` | primary blue — CTAs, selection, links |
| `accentDark` | `#0F4FC0` | pressed links, text on blue tint |
| `accentTint` | `#EDF3FE` | blue-tinted fills, info banners |
| `accentBorder` | `#C9DDFB` | dashed/solid blue borders |
| `lime` | `#CBFF3C` | app-mark glyph only |
| `danger` | `#C0492A` | destructive text |
| `dangerBorder` | `#F0D9CE` | destructive button border |
| `surface` | `#FFFFFF` | cards, sheets, bars |
| `grouped` | `#F6F7F9` | grouped screen background |
| `canvas` | `#EDEEF0` | design-canvas backdrop (not used in-app) |
| `fill` | `#F1F2F5` | circular icon buttons, inert chips, steppers |
| `fillAlt` | `#EFF0F3` | avatar placeholder |
| `hairline` | `#EDEEF1` | card borders |
| `hairlineSoft` | `#F2F3F6` | inner row dividers |
| `hairlineFaint` | `#F4F5F7` | list row dividers |
| `stroke` | `#E4E5E9` | input borders (1.5px) |
| `strokeAlt` | `#EAEBEE` | button/row borders (1px) |
| `strokeChip` | `#E6E7EB` | unselected chip borders |
| Venue tints | `#F1F5EC` (Sycamore 🌳), `#EDF3FE` (Westside 🏊), `#F7F9E9` (LATC 🎾) | venue icon tiles |

### Type — Manrope

Weights 400/500/600/700/800. Negative tracking scales with size.

| Role | Spec |
|---|---|
| Display | `800 35/1.05`, tracking `-.042em` — sign-in wordmark |
| Title 1 | `800 31/1.08`, `-.038em` — "Check your email" |
| Title 2 | `800 29/1.1`, `-.038em` — "Which camp?", "New camp" |
| Tab title | `800 28/1`, `-.038em` — Groups / Rank / Setup |
| Profile name | `800 24/1.1`, `-.035em` |
| Sheet title | `800 22`, `-.03em` |
| Venue heading | `800 17`, `-.03em` |
| Row title lg | `800 16.5`, `-.028em` — coach name, camp name |
| Row title | `800 16`, `-.025em` |
| Body strong | `700 15`, `-.02em` — player name, setting label |
| Body | `500 14.5/1.5–1.65` — descriptive copy |
| Meta | `500 12–12.5` — "13 · F · returning" |
| Chip | `700 12.5–13` |
| Section header | `700 11`, `+.1em`, uppercase — "YOUR CAMPS" |
| Badge | `700 9.5`, `+.07–.09em`, uppercase — "Away", "In range" |
| Mono | `ui-monospace/Menlo` `700` — invite code `SYC-4821`, court chips `🌳 C1` |

Bundle Manrope if the TTFs are available; otherwise fall back to the system font at the
matching weight. `Typography.swift` owns this decision in one place.

### Geometry

- Radii: `36` device bezel · `24` sheet top corners · `18/17` cards · `16/15` buttons & inputs
  · `14/13/12/11` inner rows and tiles · `999` pills.
- Borders: `1px` hairlines, `1.5px` inputs and unselected states, `2px` focused OTP cell,
  `2.5px` avatar ring.
- Screen padding: `16` horizontal for bars, `12–14` for grouped card gutters, `18` inside sheets.
- Tab bar: floating pill, `22pt` above the bottom edge, `6pt` inner padding, blurred
  `rgba(250,250,251,.82)` + saturation, shadow `0 12 36 rgba(11,11,12,.17)`, hairline ring.
  Selected item is a white capsule with **icon + label**; unselected are icon-only.

### Icons

Design uses Phosphor. Map to the nearest SF Symbol:

| Phosphor | SF Symbol |
|---|---|
| `tennis-ball` | `figure.tennis` (app mark) |
| `apple-logo` | `apple.logo` |
| `envelope-simple` | `envelope` |
| `arrow-left` | `chevron.left` |
| `clock-countdown` | `clock.arrow.circlepath` |
| `shield-check` | `checkmark.shield` |
| `caret-right` / `caret-down` / `caret-up` | `chevron.right` / `chevron.down` / `chevron.up` |
| `plus` / `minus` | `plus` / `minus` |
| `magnifying-glass` | `magnifyingglass` |
| `bell` | `bell` |
| `phone` | `phone` |
| `dots-six-vertical` | `line.3.horizontal` (drag handle) |
| `warning-circle` | `exclamationmark.circle` |
| `squares-four` | `square.grid.2x2` (Groups tab) |
| `list-numbers` | `list.number` (Rank tab) |
| `sliders-horizontal` | `slider.horizontal.3` (Setup tab) |
| `user` | `person` (Profile tab) |
| `share-network` | `square.and.arrow.up` |
| `shuffle` | `shuffle` |
| `user-minus` | `person.badge.minus` |
| `clock` | `clock` |
| `arrow-up` | `arrow.up` |
| `identification-badge` | `person.text.rectangle` |
| `lock-simple` | `lock` |
| `swap` | `arrow.left.arrow.right` |
| `lifebuoy` | `lifepreserver` |
| `camera` | `camera.fill` |
| `info` | `info.circle` |
| `x` | `xmark` |

---

## 2. Domain model

```
Account        id, email, displayName, avatar?, emergencyPhone?
Membership     accountId, campId, role, todayAssignment?   // role lives here, not on Account
Role           .admin | .worker | .trainer | .other(label)
Camp           id, name, sport, inviteCode ("SYC-4821"), venues, staff, players
Sport          .tennis | .soccer | .basketball | .swim | .other
Venue          id, name, subtitle ("Higher level"), icon (emoji), tint,
               groupCount, coachMin/coachMax, playerMin/playerMax
Group          id, venueId, label ("Court 1"), rankOrder, coachId?
Player         id, firstName, lastInitial, age, gender (.m/.f/.x), isReturning,
               venueId?, groupId?, overallRank, courtRank
StaffMember    id, name, initials, role, venueId?, groupId?, phone?, isRoaming
Attendance     playerId, day, present, leavesAt?          // early pick-up
HistoryEvent   playerId, title, detail, isAccent, at
```

**Derived:** venue staffing status — `In range` when `coachMin ≤ coaches ≤ coachMax`,
otherwise `N coaches short` / `N over`. Group over-capacity produces the inline
`1 over — move one kid down` banner.

Sample data must reproduce the design exactly: camp *UCLA Tennis Camp*, code `SYC-4821`,
venues **🌳 Sycamore** ("Higher level", 6 groups, 50 kids, 6 coaches, coaches 4–7, players
40–60) and **🎾 LATC** (6 groups, 50 kids, 4 coaches → *2 coaches short*); a second camp
**🏊 Westside Swim** (Admin · 3 venues · 74 kids) so "Switch camp" has somewhere to go.
Players include Serene C (13 F returning), Liam P (12 M), Austin Z (13 M), Liam J (14 M
returning, **away**), Jacob N (14 M), Isla M (10 F), Hugo C (13 M), Lena B (14 F). Staff:
Nass (Admin, 🌳 C1), Hubert (Admin, 🌳 C2), Alex (Worker, 🌳 C3), Dana (Trainer, roaming),
Marisol (Other · front desk, unassigned). 100 kids total, 50 per venue, 14 staff.

---

## 3. Screens

### Stage 1 — Get in

**1. Sign in.** White. App mark: 56×56 `#0B0B0C` tile, radius 18, lime tennis-ball glyph.
Wordmark "Sycamore" + tagline *"Camp management for people standing on a court, not sitting
at a desk."* Content pinned to the bottom: full-width black **Continue with Apple** (56pt,
radius 16), `or` divider, `EMAIL` label, email field (1.5px border, radius 15, envelope
icon), blue **Email me a code**. Footnote: *"No passwords. Nothing to forget with wet hands."*

**2. Verify.** Back circle (40pt, `fill`). "Check your email" + *We sent a code to
**alex@uclacamp.org***. Six OTP cells, `flex:1`, 64pt tall, radius 15 — filled cells show the
digit at `800 26`, the active cell has a 2px blue border and a blinking caret, the rest are
empty. `Resend in 0:42` with a countdown icon. Bottom info card on `#F6F7F9`: *"Your
permissions come from the camp, not the login…"*

**3. Which camp?** Grouped background. White header: "Which camp?" + *Signed in as
alex@uclacamp.org*. `YOUR CAMPS` card lists memberships — 46pt tinted icon tile, name, and
`Coach · Sycamore, Court 3` / `Admin · 3 venues · 74 kids`. `JOIN WITH A CODE` row: mono
input showing `SYC‑••••` + black **Join**. Then a dashed-blue **Create a camp** button —
*"You become its first admin"*.

**4. New camp.** *"Two answers now. Everything else lives in Setup and can change any day."*
`NAME` text field. `SPORT` single-select chip row: Tennis (selected, black) / Soccer /
Basketball / Swim / Other. `SHAPE` card with two −/+ steppers: **Venues** ("Sites or skill
levels", 2) and **Groups per venue** ("Courts, fields, lanes", 6). Blue **Create camp**;
footnote *"You get an invite code to hand to your staff."*

### Stage 2 — Run the day

**5. Groups.** The day, top to bottom. Header: title + bell with unread dot; search field
(`Search a kid or a coach`); venue filter chips `All 100` / `🌳 Sycamore 50` / `🎾 LATC 50`
(selected = black); a second divided row of attribute chips `Everyone` (selected, blue tint)
/ `Boys` / `Girls` / `Leaving early` / `Away`. Body groups by venue: a venue header row
(emoji, name + caret, `HIGHER LEVEL` label, `50 kids`), then one card per coach —
44pt initials avatar, coach name, `Court 1 · 8 here`, a circular phone button, and a
collapse caret. Expanded cards list players as numbered rows (rank, `Serene C`,
`13 · F · returning`, drag handle). **Away** players are greyed with an `Away` badge.
**Swipe left** on a player reveals a black `Mark away` action (130pt). A collapsed card can
carry an inline blue banner: `1 over — move one kid down`.

**6. Rank.** One list, 1–100, best at the top. Header: title + black **Even out** pill, and
*"One list for the whole camp, best at the top. Drag a kid across a venue line and they
change venue."* Venue sections (`🌳 Sycamore … 1–50`) separated by a 1.5pt black rule.
Rows: rank numeral (28pt column), name, meta, drag handle. The dragged row lifts — blue
1.5px border, radius 12, inset margins, shadow — and a 2.5pt blue insertion bar shows the
drop point. A collapsed run reads `45 MORE IN SYCAMORE`. Crossing a venue rule reassigns the
player's venue.

**7. Setup.** Header: "Setup" + `UCLA Tennis Camp · code SYC-4821` (code in mono blue) and a
circular share button. `VENUES` card: 44pt tinted tile, name + status badge (`In range` grey
/ `2 coaches short` blue), `6 groups · 50 kids · 6 coaches`, caret. Below it a
**Partition the camp** row — *"Fills each venue by rank, inside its limits"*. `STAFF 14` with
an **Invite** action; filter chips `All 14` / `🌳 6` / `🎾 4` / `Unassigned 4`; then one card,
three lines per person: 36pt avatar (admins get a black fill), name, uppercase role, and a
mono court chip (`🌳 C1`) — or `Roaming` for a trainer, `—` for unassigned.

**8. Profile.** A page, not a sheet. Header: 72pt avatar (`image-slot` → editable photo well
with a blue camera badge), "Alex Ramos", `Worker` badge + camp name. `ON TODAY` card
(blue-bordered): venue tile, `Sycamore · Court 3`, `8 kids · 7 here · ranked 9:12am`.
`ACCOUNT`: Email, Emergency phone (*visible to admins*), Role (*only an admin can change
this* — lock icon, not a caret). `APP`: Notifications (toggle, on), Switch camp
(*2 camps on this account*), Help & feedback. Footer: **Sign out** and **Delete account**
side by side, the latter in danger red.

### Stage 3 — Sheets

All slide up over the current tab, dimmed backdrop `rgba(11,11,12,.36)`, 24pt top radius,
grabber, and a circular `x` close button. Heights in the design: 562 / 472 / 612 / 512 of 700
— use `presentationDetents` fractions of roughly `.80 / .67 / .87 / .73`.

**9. Player.** "Austin Z" / `Sycamore · Court 1 · Nass`. Three stat tiles — **On court** `#3`,
**Overall** `#3`, **Age** `13`. Action rows: *Mark away today* (“Stays on the list, greyed
out”), *Set early pick-up* (“Pick a day and a time”), *Move up a court* (“Sends Nass a
request”). `HISTORY` timeline with dots — blue for the most recent: *Moved up to Sycamore ·
Court 1 — Tuesday · Alex, approved by Nass*; grey: *Ranked into today's order — This morning
· Nass*.

**10. Early pick-up.** "Austin Z — leaves before the session ends". `WHICH DAY` — five equal
chips Mon–Fri (Wed selected, blue fill). `LEAVES AT` — wrapped time pills 12:00→15:30 in
30-minute steps (14:30 selected, blue tint + blue border). Blue confirm bar:
**Leaves Wed at 14:30**, which reflects the current selection.

**11. Venue.** "Sycamore" / `50 kids · 6 coaches · 6 groups`. Grey status banner
`Within range`. `NAME` — name field and a subtitle field (`Higher level`). `ICON` — emoji
grid 🌳 🎾 🏆 🔥 ⭐ 🌊, 52pt tiles, selected gets blue border + tint. `LIMITS` card: **Groups**
stepper (6), **Coaches, min – max** (`4 – 7`), **Players, min – max** (`40 – 60`, *"Auto-partition
floor and ceiling"*).

**12. Staff.** 46pt avatar, "Alex", `Worker · Sycamore · Court 3`. Blue-tint call card:
`(310) 555-0106` / *"Tap to call in an emergency"* → `tel:`. `ROLE` — four equal chips
Admin / Worker / Trainer / Other (Worker selected, black). `ON TODAY` — wrapped court chips
`No court` / `🌳 C1`…`🎾 C2` (🌳 C3 selected, blue). Destructive **Remove from camp**.

---

## 4. Notes carried over from the design

- **Setup's staff list** is one card with a venue filter above it, three lines per person
  rather than five. Phone numbers live in the detail sheet. Unassigned staff are a *filter*,
  not a run of grey rows at the bottom.
- **Profile is a page**, not a sheet: today's assignment first, then the account rows people
  actually change, camp switching, and the two destructive actions side by side at the bottom
  so neither is a mis-tap away from the list above.
- **Open questions the design leaves unanswered** (do not invent answers — leave the natural
  seam in the code): should an invite code expire? Should a Trainer see every court
  read-only, since they roam? One profile photo per camp, or one across the account?
