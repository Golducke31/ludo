#!/usr/bin/env python3
"""slice_arena_pads.py - extract the four player pads from the zonas layer.

The pack composes its pads around a CIRCULAR ring, so they sit beside the
ring, not on our square board's pen corners. This slices the four pads out
of arena_capas_04_zonas_iniciales.png so arena_2d.gd can place each one
centered on its player's pen cluster (design space). Deterministic crops.
"""
from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "arena" / "arena_capas_04_zonas_iniciales.png"
OUT = ROOT / "assets" / "sprites" / "arena" / "pads"

# measured alpha bboxes of the four pads (x0, y0, x1, y1) with margin
CROPS = {
    "pad_violet": (100, 0, 950, 700),      # top-left pad
    "pad_orange": (1620, 0, 2470, 700),    # top-right pad
    "pad_green": (100, 690, 950, 1390),    # bottom-left pad
    "pad_red": (1620, 680, 2470, 1390),    # bottom-right pad
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    im = Image.open(SRC).convert("RGBA")
    for name, box in CROPS.items():
        im.crop(box).save(OUT / f"{name}.png")
        print("wrote", name, box)


if __name__ == "__main__":
    main()
