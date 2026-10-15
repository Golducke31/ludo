#!/usr/bin/env python3
"""hash_assets.py - SHA256 manifest for assets/ (integrity + audit support).

Usage:
    python hash_assets.py                 # write assets/MANIFEST.sha256
    python hash_assets.py --verify        # compare tree vs manifest (exit 1 on drift)

The manifest is JSON: {"algorithm": "sha256", "files": {relpath: hexdigest}}.
Only real assets are hashed; Godot import caches (.godot/, *.import) and
Godot-generated translation artifacts (*.translation, derived from the i18n
CSVs) are skipped.
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
MANIFEST = ASSETS / "MANIFEST.sha256"
CHUNK = 65536


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            block = f.read(CHUNK)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


def iter_asset_files():
    for p in sorted(ASSETS.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(ASSETS)
        parts = rel.parts
        if any(part.startswith(".godot") for part in parts):
            continue
        if rel.name == "MANIFEST.sha256":
            continue
        if rel.suffix == ".import":
            continue
        if rel.suffix == ".translation":
            continue  # generated from assets/i18n/*.csv by Godot's importer
        yield rel, p


def write_manifest() -> int:
    files = {rel.as_posix(): sha256_file(p) for rel, p in iter_asset_files()}
    data = {"algorithm": "sha256", "files": files}
    MANIFEST.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    total = sum(p.stat().st_size for _, p in iter_asset_files())
    print(f"MANIFEST written: {len(files)} files, {total} bytes -> {MANIFEST}")
    return 0


def verify_manifest() -> int:
    if not MANIFEST.exists():
        print("FAIL: manifest missing (run without --verify first)")
        return 1
    old = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
    new = {rel.as_posix(): sha256_file(p) for rel, p in iter_asset_files()}
    missing = sorted(k for k in old if k not in new)
    added = sorted(k for k in new if k not in old)
    changed = sorted(k for k in new if k in old and new[k] != old[k])
    if not (missing or added or changed):
        print(f"OK: manifest matches ({len(new)} files)")
        return 0
    for k in missing:
        print(f"  MISSING {k}")
    for k in added:
        print(f"  ADDED   {k}")
    for k in changed:
        print(f"  CHANGED {k}")
    return 1


if __name__ == "__main__":
    sys.exit(verify_manifest() if "--verify" in sys.argv else write_manifest())
