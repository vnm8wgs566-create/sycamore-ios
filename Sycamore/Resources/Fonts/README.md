# Instrument Sans

The design is set in Instrument Sans. `InstrumentSans[wdth,wght].ttf` in this directory is the
family, and `OFL.txt` is its licence.

## What's here

| File | |
|---|---|
| `InstrumentSans[wdth,wght].ttf` | Google Fonts' variable Instrument Sans, weight axis 400–700, width axis 75–100 |
| `OFL.txt` | SIL Open Font License 1.1 — Copyright 2022 The Instrument Sans Project Authors |

Downloaded from [google/fonts](https://github.com/google/fonts/tree/main/ofl/instrumentsans),
which is the same source `Sycamore 3a System.dc.html` loads it from — the design document
requests `family=Instrument+Sans:wght@400..700` — so the metrics match what the design was drawn
against.

This replaced Manrope, which the app was set in before section 8 of the design system landed.

## One file covers all four weights

Core Text reads a variable font's **named instances** as separate faces, so a single
registration exposes all of these:

```
family=Instrument Sans  postscript=InstrumentSans-Regular
family=Instrument Sans  postscript=InstrumentSans-Regular_Medium
family=Instrument Sans  postscript=InstrumentSans-Regular_SemiBold
family=Instrument Sans  postscript=InstrumentSans-Regular_Bold
```

**The `_` in those names is not a typo, and it is font-specific.** An instance only gets a clean
`Family-Style` PostScript name when the font's `fvar` table carries a `postScriptNameID` for it.
Instrument Sans does not, so Core Text synthesises `<default PostScript name>_<subfamily>`
instead. Manrope *does* carry those IDs, which is why it came back as `Manrope-Bold` and friends.
Two variable fonts, two naming conventions — so the names in `TypeWeight.faceName` in
[`Typography.swift`](../../DesignSystem/Typography.swift) must be **read off the file**, never
guessed from the family name.

To read them off a file yourself:

```swift
let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
descs?.forEach { print(CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String ?? "?") }
```

The filename is what [`Info.plist`](../Info.plist) lists under `UIAppFonts`. Change the font and
you must change all three: the file, the plist entry, and `TypeWeight.faceName`.

## There is no 800

Instrument Sans stops at 700. `TypeWeight.extraBold` (800) is a leftover from Manrope and
resolves to the 700 face; the design document uses no 800 anywhere. See the note on `TypeWeight`
for why the case is kept rather than deleted.

## How the fallback works

`FontFamily.availableFaces` asks Core Text for each face and checks that what came back is
actually the face requested — `CTFontCreateWithName` never fails, it substitutes. So the app is
correct with this folder empty (every style falls back to the system font at the matching weight)
and correct with it filled. There is no half-configured state that silently renders the wrong
thing.

To confirm registration in a debug build:

```swift
print(FontFamily.usesInstrumentSans)   // expect true
print(FontFamily.availableFaces)       // expect 400, 500, 600, 700
```

If it prints `false`, the file is in the repo but not in the bundle — almost always the Copy
Bundle Resources phase, not the filename.
