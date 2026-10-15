#!/usr/bin/env python3
"""audit_palette.py - reject neon/cyan leaks (plan M3 gate).

Usage:
    python audit_palette.py            # scan scripts/scenes + assets PNGs

Checks:
  1. Color literals in scripts/**/*.gd, scenes/**/*.tscn and *.tres:
     flagged when S > 0.85 (neon, any hue) or S > 0.60 with hue in
     [70, 250] deg (green/cyan/blue neon band).
  2. PNG pixels under assets/: flagged when a file has > NEON_MAX fraction
     of opaque pixels in the cyan band (hue 150-210, S > 0.70) or in the
     green-neon band (hue 80-150, S > 0.85).

Allowed by design (muted palette): pumpkin orange (~32 deg, S<=0.80),
muted violet (~270 deg), spectral green (~104 deg, S<=0.50), cream/wood.
Exit code 0 = clean, 1 = violations found.
"""
import colorsys
import re
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
NEON_MAX = 0.01  # max fraction of neon-ish pixels per PNG
COLOR_LIT = re.compile(r"Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)(?:\s*,\s*([0-9.]+))?\s*\)")
HEX_LIT = re.compile(r"#[0-9a-fA-F]{6}\b")


def is_bad_color(r: float, g: float, b: float) -> str | None:
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v <= 0.02:
        return None  # black
    hd = h * 360.0
    if s > 0.85:
        return f"neon (h={hd:.0f} s={s:.2f})"
    if s > 0.60 and 70.0 <= hd <= 250.0:
        return f"cyan/green/blue neon band (h={hd:.0f} s={s:.2f})"
    return None


def bad_from_hex(hx: str) -> str | None:
    r, g, b = (int(hx[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    return is_bad_color(r, g, b)


def scan_text() -> list[str]:
    bad = []
    for folder, suffix in (("scripts", ".gd"), ("scenes", ".tscn"), ("assets", ".tres")):
        base = ROOT / folder
        if not base.is_dir():
            continue
        for f in sorted(base.rglob(f"*{suffix}")):
            if ".godot" in f.parts:
                continue
            for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                for m in COLOR_LIT.finditer(line):
                    r, g, b = (float(m.group(i)) for i in (1, 2, 3))
                    why = is_bad_color(r, g, b)
                    if why:
                        bad.append(f"{f.relative_to(ROOT).as_posix()}:{n}: Color({r},{g},{b}) {why}")
                for m in HEX_LIT.finditer(line):
                    why = bad_from_hex(m.group(0))
                    if why:
                        bad.append(f"{f.relative_to(ROOT).as_posix()}:{n}: {m.group(0)} {why}")
    return bad


def scan_pngs() -> list[str]:
    bad = []
    base = ROOT / "assets"
    for f in sorted(base.rglob("*.png")):
        if ".godot" in f.parts:
            continue
        # Normal/ORM maps are DATA vectors (tangent space + AO/rough/metal),
        # not authored art: their channels read as saturated/unhued noise and
        # must never trip the neon/cyan band. Skip them.
        if f.stem.endswith("_normal") or f.stem.endswith("_orm"):
            continue
        img = Image.open(f).convert("RGBA")
        img.thumbnail((256, 256))
        opaque = 0
        neon = 0
        data = img.tobytes()
        for i in range(0, len(data), 4):
            r, g, b, a = data[i], data[i + 1], data[i + 2], data[i + 3]
            if a < 24:
                continue
            opaque += 1
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            hd = h * 360.0
            if s > 0.70 and 150.0 <= hd <= 210.0:
                neon += 1                      # cyan band
            elif s > 0.85 and 80.0 <= hd <= 150.0:
                neon += 1                      # green neon band
        if opaque and neon / opaque > NEON_MAX:
            bad.append(f"{f.relative_to(ROOT).as_posix()}: {neon}/{opaque} neon/cyan pixels")
    return bad


def main() -> int:
    problems = scan_text() + scan_pngs()
    if problems:
        print("PALETTE AUDIT FAIL:")
        for p in problems:
            print("  " + p)
        return 1
    print("PALETTE AUDIT OK: no neon/cyan leaks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
