#!/usr/bin/env python3
"""retint_rune_glow.py - bring the pack's cyan rune glow into our palette.

The PBR pack ships `tile_rune_glow_emission.png` with cyan cracks. Our palette
gate (`tools/audit_palette.py`) rejects cyan/neon, and the game's own "magic"
colour is the spectral green of the fog portal (ViewPalette.SPECTRAL_GREEN).
This rewrites the emission map to that green while preserving the crack
structure (the per-pixel intensity is kept, only the colour changes), so the
glow reads as the same magic as the rest of the game.

Deterministic: same input -> same output.
Run:  python tools/retint_rune_glow.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "textures" / "pbr" / "tile_rune_glow_emission.png"

# ViewPalette.SPECTRAL_GREEN (#6FA35A): hue ~103 deg, S ~0.45 -> gate-safe.
TARGET = np.array([0.435, 0.639, 0.353], dtype=np.float32)


def main() -> int:
    img = Image.open(SRC).convert("RGB")
    a = np.asarray(img, dtype=np.float32) / 255.0

    # intensity of the original glow (max channel), normalised to 0..1
    inten = a.max(axis=2)
    peak = float(inten.max())
    if peak <= 1e-6:
        print("retint: source is black, nothing to do")
        return 1
    k = inten / peak

    # scale the target so its brightest channel reaches 1.0 (keeps the hue and
    # saturation, so the emission stays punchy after the colour swap)
    tint = TARGET / float(TARGET.max())
    out = k[..., None] * tint[None, None, :]
    out = np.clip(out, 0.0, 1.0)

    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8)).save(SRC)
    print(f"retint: {SRC.relative_to(ROOT).as_posix()} -> spectral green "
          f"(hue 103, S 0.45); peak intensity kept at {peak:.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
