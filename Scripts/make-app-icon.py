#!/usr/bin/env python3
"""
Renders the app icon from the same geometry `SycamoreMark` draws in SwiftUI.

The mark is the design's `seed3e` — the large samara with a smaller turned one below it —
transcribed from `Sycamore Logo v2.dc.html`. The coordinates here are the design's 200x200
canvas, identical to the ones in `Sycamore/DesignSystem/SycamoreMark.swift`; change one and
change the other.

This exists as a script rather than a checked-in blob so the icon can be regenerated when the
mark moves, and so the numbers are auditable next to the Swift.

    python3 Scripts/make-app-icon.py

Requires Pillow. Writes Sycamore/Resources/Assets.xcassets/AppIcon.appiconset/.
"""

from __future__ import annotations

import json
import pathlib

from PIL import Image, ImageDraw

# The design's palette.
TILE = (247, 245, 239)      # #F7F5EF
GREEN = (20, 96, 60)        # #14603C
GREEN_LIGHT = (63, 125, 83) # #3F7D53

# iOS masks the corners itself, so the PNG is a full opaque square. Rounding it here would
# show as a dark fringe inside the system's own mask.
SIDE = 1024
# Supersample, then box-filter down. PIL's polygon fill has no antialiasing of its own, and
# at 1024 the wing's edge is the whole character of the mark.
SS = 4

# `SycamoreAppMark` insets the mark by size * 14/200 for the non-ringed variants.
INSET = 14 / 200


def quad(p0, p1, p2, steps=96):
    """A quadratic Bezier as a polyline — SVG's `Q`, which is what the design authors in."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        out.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return out


def seed_paths():
    """`seed2a`, on its own 200x200 canvas: outer wing, inner wing, seed head."""
    outer = quad((78, 130), (82, 54), (174, 30)) + quad((174, 30), (162, 106), (94, 134))
    inner = quad((86, 120), (96, 62), (152, 44)) + quad((152, 44), (142, 100), (96, 124))
    return outer, inner, (72, 146, 20)  # head: cx, cy, r


def place(points, scale, cx, cy, rotation=0.0):
    """
    Scale a 200-canvas path about its own centre, optionally turn it, and drop its centre at
    (cx, cy) — the design's `translate(...) rotate(...) scale(...)` chain, flattened.
    """
    import math
    theta = math.radians(rotation)
    cos_t, sin_t = math.cos(theta), math.sin(theta)
    out = []
    for x, y in points:
        # About the seed's own centre.
        dx, dy = (x - 100) * scale, (y - 100) * scale
        out.append((cx + dx * cos_t - dy * sin_t, cy + dx * sin_t + dy * cos_t))
    return out


def draw_seed(d, scale, cx, cy, rotation, unit):
    outer, inner, (hx, hy, hr) = seed_paths()

    def to_px(pts):
        return [(x * unit, y * unit) for x, y in pts]

    d.polygon(to_px(place(outer, scale, cx, cy, rotation)), fill=GREEN)
    d.polygon(to_px(place(inner, scale, cx, cy, rotation)), fill=GREEN_LIGHT)

    # The head, placed through the same transform as a point, then drawn as a circle.
    (px, py), = place([(hx, hy)], scale, cx, cy, rotation)
    r = hr * scale * unit
    d.ellipse([px * unit - r, py * unit - r, px * unit + r, py * unit + r], fill=GREEN)


def render(side: int) -> Image.Image:
    big = side * SS
    img = Image.new("RGB", (big, big), TILE)
    d = ImageDraw.Draw(img)

    # The mark's own 200-canvas maps into the inset square.
    inset = big * INSET
    span = big - inset * 2
    unit = span / 200

    # Everything below is in the mark's 200-canvas; `unit` converts to pixels, and the inset
    # is folded in by offsetting the origin.
    class Offset:
        def polygon(self, pts, fill):
            d.polygon([(x + inset, y + inset) for x, y in pts], fill=fill)

        def ellipse(self, box, fill):
            d.ellipse([box[0] + inset, box[1] + inset, box[2] + inset, box[3] + inset], fill=fill)

    o = Offset()
    # `seed3e`: scale(0.66) centred on (76, 70), then scale(0.44) turned 160 at (138, 146).
    draw_seed(o, 0.66, 76, 70, 0, unit)
    draw_seed(o, 0.44, 138, 146, 160, unit)

    return img.resize((side, side), Image.LANCZOS)


def main():
    root = pathlib.Path(__file__).resolve().parent.parent
    out = root / "Sycamore/Resources/Assets.xcassets/AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)

    render(SIDE).save(out / "AppIcon-1024.png")

    (out / "Contents.json").write_text(json.dumps({
        "images": [{
            "filename": "AppIcon-1024.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
        }],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")

    catalog = out.parent / "Contents.json"
    catalog.write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    print(f"wrote {out/'AppIcon-1024.png'}")


if __name__ == "__main__":
    main()
