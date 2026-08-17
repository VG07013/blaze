#!/usr/bin/env python3
"""Generate Blaze's app icons (1024x1024 PNG) with a pure-stdlib PNG writer.

Draws a glowing teardrop flame on warm charcoal. Three variants:
  AppIcon (classic orange/gold), AppIconEmber (deep red), AppIconInferno (blue-white).

Usage: python3 Tools/generate_icons.py
"""
import math
import os
import struct
import zlib

SIZE = 1024
ROOT = os.path.join(os.path.dirname(__file__), "..", "Blaze", "Assets.xcassets")


def write_png(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)  # no filter
        raw.extend(row)

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        out += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        return out

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp3(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(3))


def clamp255(v):
    return max(0, min(255, int(v)))


def flame_halfwidth(s):
    """Half-width of the teardrop at vertical position s (0=tip, 1=base)."""
    if s <= 0 or s >= 1:
        return 0.0
    # Slim pointed tip, full belly, smoothly rounded base.
    return 0.32 * (s ** 0.55) * (1.0 - 0.50 * s * s) * math.sqrt(max(0.0, 1.0 - s ** 6))


def render(colors):
    """colors: dict with bg_top, bg_bottom, glow, tip, base, core."""
    tip_y, base_y, cx = 0.20, 0.80, 0.5
    rows = []
    for py in range(SIZE):
        row = bytearray()
        ny = py / SIZE
        # Charcoal background, slightly warmer at the bottom
        bg = lerp3(colors["bg_top"], colors["bg_bottom"], ny)
        for px in range(SIZE):
            nx = px / SIZE
            r, g, b = bg

            # Radial warm glow behind the flame
            dx, dy = nx - cx, ny - 0.55
            dist = math.sqrt(dx * dx + dy * dy)
            glow = max(0.0, 1.0 - dist / 0.52) ** 2 * 0.55
            gr, gg, gb = colors["glow"]
            r += gr * glow
            g += gg * glow
            b += gb * glow

            # Outer flame body
            if tip_y <= ny <= base_y:
                s = (ny - tip_y) / (base_y - tip_y)
                sway = 0.015 * math.sin(6.0 * s)
                hw = flame_halfwidth(s)
                d = abs(nx - cx - sway)
                if d < hw:
                    edge = 1.0 - (d / hw) ** 3            # soft edge
                    fr, fg, fb = lerp3(colors["tip"], colors["base"], s)
                    a = min(1.0, edge * 1.6)
                    r = lerp(r, fr, a)
                    g = lerp(g, fg, a)
                    b = lerp(b, fb, a)

            # Bright inner core, anchored to the base
            core_tip, core_base = 0.44, 0.78
            if core_tip <= ny <= core_base:
                s = (ny - core_tip) / (core_base - core_tip)
                hw = flame_halfwidth(s) * 0.52
                d = abs(nx - cx)
                if d < hw:
                    edge = 1.0 - (d / hw) ** 2
                    cr, cg, cb = colors["core"]
                    a = min(1.0, edge * 1.3)
                    r = lerp(r, cr, a)
                    g = lerp(g, cg, a)
                    b = lerp(b, cb, a)

            row.extend((clamp255(r), clamp255(g), clamp255(b)))
        rows.append(bytes(row))
    return rows


VARIANTS = {
    "AppIcon.appiconset": {
        "bg_top": (26, 21, 16), "bg_bottom": (18, 14, 11),
        "glow": (120, 55, 10),
        "tip": (255, 107, 26), "base": (255, 197, 49),
        "core": (255, 244, 200),
    },
    "AppIconEmber.appiconset": {
        "bg_top": (24, 12, 10), "bg_bottom": (14, 8, 7),
        "glow": (110, 25, 8),
        "tip": (143, 29, 14), "base": (255, 122, 26),
        "core": (255, 214, 140),
    },
    "AppIconInferno.appiconset": {
        "bg_top": (12, 15, 28), "bg_bottom": (8, 10, 18),
        "glow": (25, 60, 130),
        "tip": (36, 48, 143), "base": (79, 217, 255),
        "core": (235, 250, 255),
    },
}


def main():
    for setname, colors in VARIANTS.items():
        path = os.path.join(ROOT, setname, "icon.png")
        print(f"rendering {setname} …")
        rows = render(colors)
        write_png(path, SIZE, SIZE, rows)
        print(f"  wrote {path}")


if __name__ == "__main__":
    main()
