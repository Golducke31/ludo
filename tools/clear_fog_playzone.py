#!/usr/bin/env python3
"""clear_fog_playzone.py - punch a soft play-zone hole in the front fog layer.

The pack's front fog (arena_capas_07_luces_niebla.png) has dense banks right
over the four pen corners (alpha 0.86-0.92), which washes the player pads and
the ring toward fog-violet. This derives luces_niebla_play.png with the alpha
zeroed inside a rounded rectangle that covers the whole play area (board +
pads, design x 280..1640 / y 0..1120 -> art coords at 4/3), with a feathered
edge so the fog still hugs the stage instead of ending on a hard line.
Deterministic; the original file is kept untouched for the behind-board pass.
"""
import numpy as np
from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "arena" / "arena_capas_07_luces_niebla.png"
DST = ROOT / "assets" / "sprites" / "arena" / "luces_niebla_play.png"

# design-space play rect -> art pixels (sprite centered at (960,560), 4/3)
X0, X1 = 280.0, 1640.0
Y0, Y1 = 0.0, 1120.0
RADIUS = 190.0        # design px, rounded corners
FEATHER = 42.0        # design px alpha ramp


def main():
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im).astype(np.float64)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    # art -> design
    dx = (xx - 1280.0) * 0.75 + 960.0
    dy = (yy - 720.0) * 0.75 + 560.0
    # signed distance to the rounded rect (positive outside the corners)
    dist_out = np.sqrt(np.maximum(X0 - dx, 0.0) ** 2 +
                       np.maximum(dx - X1, 0.0) ** 2 +
                       np.maximum(Y0 - dy, 0.0) ** 2 +
                       np.maximum(dy - Y1, 0.0) ** 2)
    body = ((dx >= X0) & (dx <= X1) & (dy >= Y0) & (dy <= Y1)).astype(np.float64)
    ramp = np.clip((FEATHER - dist_out) / FEATHER, 0.0, 1.0) * body
    alpha = a[..., 3] * (1.0 - ramp)
    a[..., 3] = np.clip(alpha, 0.0, 255.0)
    Image.fromarray(a.astype(np.uint8), "RGBA").save(DST)
    print("wrote", DST.name)


if __name__ == "__main__":
    main()
