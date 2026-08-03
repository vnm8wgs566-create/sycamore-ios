# Manrope

The design is set in Manrope. `Manrope[wght].ttf` in this directory is the family, and
`OFL.txt` is its licence.

## What's here

| File | |
|---|---|
| `Manrope[wght].ttf` | Google Fonts' variable Manrope, weight axis 200–800 |
| `OFL.txt` | SIL Open Font License 1.1 — Copyright 2018 The Manrope Project Authors |

Downloaded from [google/fonts](https://github.com/google/fonts/tree/main/ofl/manrope), which
is the same source the design document loads Manrope from, so the metrics match what the
design was drawn against.

## One file covers all five weights

The variable font is not a compromise here. CoreText reads its **named instances** as
separate faces, so a single registration exposes all of these:

```
family=Manrope  postscript=Manrope-Light
family=Manrope  postscript=Manrope-Regular
family=Manrope  postscript=Manrope-Medium
family=Manrope  postscript=Manrope-SemiBold
family=Manrope  postscript=Manrope-Bold
family=Manrope  postscript=Manrope-ExtraBold
```

Those are exactly the PostScript names `TypeWeight.manropeFaceName` in
[`Typography.swift`](../../DesignSystem/Typography.swift) asks for, and the single filename is
what [`Info.plist`](../Info.plist) lists under `UIAppFonts`. Change one and you must change all
three.

> An earlier version of this file claimed the variable font registered under `Manrope-Regular`
> alone and told you to fetch the static faces instead. That was wrong — verified false by
> reading the font's descriptors with `CTFontManagerCreateFontDescriptorsFromURL`.

## How the fallback works

`FontFamily.availableManropeFaces` asks Core Text for each face and checks that what came back
is actually the face requested — `CTFontCreateWithName` never fails, it substitutes. So the app
is correct with this folder empty (every style falls back to the system font at the matching
weight) and correct with it filled. There is no half-configured state that silently renders the
wrong thing.

To confirm registration in a debug build:

```swift
print(FontFamily.usesManrope)              // expect true
print(FontFamily.availableManropeFaces)    // expect all five weights
```

If it prints `false`, the file is in the repo but not in the bundle — almost always the Copy
Bundle Resources phase, not the filename.
