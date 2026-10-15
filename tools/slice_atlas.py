#!/usr/bin/env python
"""Slice sprite sheets into individual frame PNGs for Godot SpriteFrames.

Usage:
  python tools/slice_atlas.py <src.png> <out_dir> <frame_size> [--row R] [--count N]

Frames are read row-major from the source grid. --row selects one grid row
(0-based); --count limits how many frames to take. Fully transparent cells are
dropped (they are padding in these sheets, not animation frames).

Output: <out_dir>/frame_%03d.png  (RGBA, alpha preserved, pixel art untouched)
"""
import argparse
import sys
from pathlib import Path

from PIL import Image


def slice_sheet(src: Path, out_dir: Path, frame_size: int, row: int | None, count: int | None) -> int:
    with Image.open(src) as im:
        im.load()
        sheet = im.convert("RGBA")
    w, h = sheet.size
    if w % frame_size or h % frame_size:
        print(f"ERROR: {src} ({w}x{h}) is not divisible by frame size {frame_size}")
        return 1
    cols, rows = w // frame_size, h // frame_size
    if row is not None and not 0 <= row < rows:
        print(f"ERROR: row {row} out of range (sheet has {rows} rows)")
        return 1
    row_range = [row] if row is not None else list(range(rows))
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    taken = 0
    for r in row_range:
        for c in range(cols):
            if count is not None and taken >= count:
                print(f"sliced {written} frames -> {out_dir}")
                return 0
            box = (c * frame_size, r * frame_size, (c + 1) * frame_size, (r + 1) * frame_size)
            frame = sheet.crop(box)
            if frame.getchannel("A").getextrema()[0] == 255:
                continue  # fully empty padding cell
            frame.save(out_dir / f"frame_{written:03d}.png")
            written += 1
            taken += 1
    print(f"sliced {written} frames -> {out_dir}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out_dir")
    ap.add_argument("frame_size", type=int)
    ap.add_argument("--row", type=int, default=None, help="only take this grid row (0-based)")
    ap.add_argument("--count", type=int, default=None, help="max frames to take")
    args = ap.parse_args()
    src = Path(args.src)
    if not src.exists():
        print(f"MISSING: {src}")
        return 2
    return slice_sheet(src, Path(args.out_dir), args.frame_size, args.row, args.count)


if __name__ == "__main__":
    raise SystemExit(main())
