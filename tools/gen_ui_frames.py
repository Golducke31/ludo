#!/usr/bin/env python3
"""gen_ui_frames.py - golden nine-patch frames for the UI theme (Fase 6).

Deterministic, license-free ornaments in the project palette: a wide panel
frame (ornate corners + gem dots) and a compact button frame.

9-slice contract: every ornament must live INSIDE the slice margin, otherwise
the stretched edge slices smear it (a gem centred on the margin spilled 5 px
into the edges and rendered as a fat orange blob). Border bands are uniform
along each edge so they stretch cleanly.
Palette-gate safe: gold is ~35 deg (outside the cyan/green neon band).
"""
from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"

FILL = (20, 25, 45, 240)          # dark navy panel body
GOLD = (232, 184, 82, 255)        # main gold band
GOLD_HI = (252, 226, 160, 255)    # bevel light
GOLD_LO = (150, 104, 40, 255)     # bevel shade
VIOLET = (107, 78, 142, 255)      # inner accent line
GEM = (255, 156, 60, 255)         # pumpkin gem


def _band(d: ImageDraw.ImageDraw, box, width, color) -> None:
    x0, y0, x1, y1 = box
    d.rectangle((x0, y0, x1, y1), outline=color, width=width)


def _corners(d: ImageDraw.ImageDraw, n: int, m: int, off: float, arc_r: float,
        gem_r: float, arc_w: int) -> None:
    ## Ornament centred (m-off, m-off) from each corner, fully inside [0, m].
    c = m - off
    # PIL angles: 0 deg = 3 o'clock, growing clockwise (y down). Each corner
    # arc opens toward the board centre.
    for x0, y0, a0, a1 in ((c, c, 0, 90), (n - c, c, 90, 180),
                           (c, n - c, 270, 360), (n - c, n - c, 180, 270)):
        d.arc((x0 - arc_r, y0 - arc_r, x0 + arc_r, y0 + arc_r),
              a0, a1, fill=GOLD, width=arc_w)
        if gem_r > 0.0:
            d.ellipse((x0 - gem_r, y0 - gem_r, x0 + gem_r, y0 + gem_r),
                      fill=GEM, outline=GOLD_LO)


def panel_frame(size: int = 128, margin: int = 44) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = size - 1
    d.rectangle((3, 3, n - 3, n - 3), fill=FILL)
    _band(d, (3, 3, n - 3, n - 3), 9, GOLD)
    d.line((3, 3, n - 3, 3), fill=GOLD_HI, width=3)
    d.line((3, 3, 3, n - 3), fill=GOLD_HI, width=3)
    d.line((3, n - 3, n - 3, n - 3), fill=GOLD_LO, width=3)
    d.line((n - 3, 3, n - 3, n - 3), fill=GOLD_LO, width=3)
    _band(d, (14, 14, n - 14, n - 14), 1, VIOLET)
    _corners(d, n, margin, off=24.0, arc_r=14.0, gem_r=5.0, arc_w=3)
    return im


def button_frame(size: int = 64, margin: int = 22) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = size - 1
    d.rectangle((2, 2, n - 2, n - 2), fill=(34, 42, 68, 250))
    _band(d, (2, 2, n - 2, n - 2), 5, GOLD)
    d.line((2, 2, n - 2, 2), fill=GOLD_HI, width=2)
    d.line((2, 2, 2, n - 2), fill=GOLD_HI, width=2)
    d.line((2, n - 2, n - 2, n - 2), fill=GOLD_LO, width=2)
    d.line((n - 2, 2, n - 2, n - 2), fill=GOLD_LO, width=2)
    _band(d, (9, 9, n - 9, n - 9), 1, VIOLET)
    _corners(d, n, margin, off=12.0, arc_r=7.0, gem_r=3.0, arc_w=2)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    panel_frame().save(OUT / "ui_frame_panel.png")
    button_frame().save(OUT / "ui_frame_btn.png")
    print("frames written to", OUT)


if __name__ == "__main__":
    main()
