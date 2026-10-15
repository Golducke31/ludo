#!/usr/bin/env python
"""Generate Godot SpriteFrames resources from sliced frame dirs.

Usage:
  python tools/build_sprite_frames.py [extra_dir ...]

Default scan root is assets/sprites/factions/<id>; each extra_dir argument is
scanned the same way (frame_*.png -> idle.tres in that directory). The output
has a single looping "idle" animation. Deterministic: re-running produces
byte-identical .tres files.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = ROOT / "assets" / "sprites"
SPEED = 8.0


def build(faction_dir: Path) -> bool:
    frames = sorted(faction_dir.glob("frame_*.png"))
    if not frames:
        print(f"  no frames in {faction_dir.name}, skipped")
        return False
    lines = []
    lines.append("[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (len(frames) + 1))
    lines.append("")
    for i, f in enumerate(frames, start=1):
        rel = f.relative_to(ROOT).as_posix()
        lines.append("[ext_resource type=\"Texture2D\" path=\"res://%s\" id=\"%d\"]" % (rel, i))
    lines.append("")
    lines.append("[resource]")
    frame_entries = []
    for i in range(1, len(frames) + 1):
        frame_entries.append(
            "{\n\"duration\": 1.0,\n\"texture\": ExtResource(\"%d\")\n}" % i
        )
    anim = (
        "animations = [{\n\"frames\": [%s],\n\"loop\": true,\n\"name\": &\"idle\",\n\"speed\": %s\n}]"
        % (", ".join(frame_entries), SPEED)
    )
    lines.append(anim)
    out = faction_dir / "idle.tres"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  {faction_dir.name}: {len(frames)} frames -> {out.relative_to(ROOT).as_posix()}")
    return True


def scan_roots(extra: list[str]) -> list[Path]:
    roots: list[Path] = []
    factions = SPRITES_DIR / "factions"
    if factions.is_dir():
        roots.extend(p for p in sorted(factions.iterdir()) if p.is_dir())
    for arg in extra:
        p = Path(arg)
        if not p.is_absolute():
            p = ROOT / arg
        if p.is_dir():
            roots.append(p)
        else:
            print(f"missing dir {arg}")
    return roots


def main() -> int:
    changed = 0
    for d in scan_roots(sys.argv[1:]):
        if build(d):
            changed += 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
