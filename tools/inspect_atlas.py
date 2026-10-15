#!/usr/bin/env python
"""Inspect sprite sheets: dimensions, candidate grid sizes, frame counts.

Usage:
  python tools/inspect_atlas.py <png> [<png> ...]

Prints, per file: width/height and the plausible uniform square frame grids
(frame sizes that divide both dimensions exactly, 8..128 px), so slicing can
be chosen from facts instead of guesses.
"""
import sys
from pathlib import Path

from PIL import Image


def divisors(v: int) -> list[int]:
    return [d for d in range(8, min(v, 128) + 1) if v % d == 0]


def inspect(path: Path) -> None:
    with Image.open(path) as im:
        im.load()
        w, h = im.size
        mode = im.mode
        print(f"{path}")
        print(f"  size={w}x{h} mode={mode} bytes={path.stat().st_size}")
        common = sorted(set(divisors(w)) & set(divisors(h)))
        for fs in common:
            frames = (w // fs) * (h // fs)
            print(f"  grid {fs}x{fs} -> {w // fs}x{h // fs} = {frames} frames")
        if not common:
            print("  no uniform square grid 8..128 divides both dimensions")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for arg in sys.argv[1:]:
        p = Path(arg)
        if not p.exists():
            print(f"MISSING: {p}")
            continue
        inspect(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
