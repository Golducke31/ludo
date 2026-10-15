#!/usr/bin/env python3
"""gen_board_tiles.py - painted stone tiles for the 2.5D board (Fase 2D).

The tiles act as a near-white "paint layer": BoardView draws them with
draw_texture_rect(..., modulate=palette_color), so the ViewPalette color
semantics asserted by the headless suites stay exact while the surface gains
mortar / bevel / grain detail that matches the layer pack's painted style.
Deterministic (seeded), license-clean, palette-gate-safe (warm neutrals).
"""
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

SEED = 4242
SIZE = 64
OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "board"


def gen_tile(rng, variant: int) -> Image.Image:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    img = np.full((SIZE, SIZE, 3), 0.92)                    # near-white base
    # mortar border
    border = np.zeros((SIZE, SIZE))
    border[:2, :] = 1.0
    border[-2:, :] = 1.0
    border[:, :2] = 1.0
    border[:, -2:] = 1.0
    # inset bevel: light top/left, shade bottom/right
    bevel = np.zeros((SIZE, SIZE))
    bevel[2:5, 2:-2] = -0.10                               # shade top-inner
    bevel[-5:-2, 2:-2] = 0.08                              # light bottom-inner
    bevel[2:-2, 2:5] = 0.08
    bevel[2:-2, -5:-2] = -0.10
    # grain: stretched speckle + a few cracks
    g = rng.random((SIZE, SIZE))
    g = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(0.8)), dtype=np.float64) / 255.0
    grain = (g - 0.5) * 0.10
    cracks = np.zeros((SIZE, SIZE))
    for _ in range(3):
        cx, cy = rng.uniform(6, SIZE - 6, 2)
        ang = rng.uniform(0, 2 * np.pi)
        for _s in range(rng.integers(4, 14)):
            cx += np.cos(ang) * 1.4
            cy += np.sin(ang) * 1.4
            if 2 <= int(cx) < SIZE - 2 and 2 <= int(cy) < SIZE - 2:
                cracks[int(cy), int(cx)] = 1.0
    cracks = np.asarray(Image.fromarray((cracks * 255).astype(np.uint8)).filter(
        ImageFilter.MaxFilter(3)), dtype=np.float64) / 255.0
    shade = 1.0 + grain - border * 0.22 + bevel - cracks * 0.05
    # variant b: faint warm tint drift so the checker reads hand-painted
    if variant == 1:
        shade = shade[..., None] * np.array([1.0, 0.985, 0.955])[None, None, :]
        shade = shade[..., 0]
    img = np.clip(shade[..., None] * img, 0.0, 1.0)
    return Image.fromarray((img * 255).astype(np.uint8), "RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    gen_tile(rng, 0).save(OUT / "tile_stone_a.png")
    gen_tile(rng, 1).save(OUT / "tile_stone_b.png")
    print("board tiles written to", OUT)


if __name__ == "__main__":
    main()
