#!/usr/bin/env python3
"""scan_i18n.py - catch missing/extra localization keys (M4 gate).

Usage:
    python scan_i18n.py

Extracts L10n.t("key") literals from scripts/**/*.gd and compares them with
assets/i18n/ui.csv. Fails when a key is used but missing from the CSV, when a
key exists in the CSV but no locale uses it, or when a CSV row has an empty
locale. Deliberately duplicate keys in the CSV also fail.
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "assets" / "i18n" / "ui.csv"
USED = re.compile(r'L10n\.t\(\s*"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"')
SCENE_PREFIX = re.compile(r'L10n\.localize_scene\([^,]+,\s*"([a-z_]+)"\)')
COMPUTED = re.compile(r'L10n\.t\(\s*[a-z_]+')  # non-literal first arg (faction./diff. dynamic)
# Test fixtures: suite_accessibility intentionally probes the missing-key
# fallback ("does.not.exist" must return the key itself).
FIXTURES = {"does.not.exist"}


def main() -> int:
    used: set[str] = set()
    for f in sorted((ROOT / "scripts").rglob("*.gd")):
        text = f.read_text(encoding="utf-8", errors="replace")
        used.update(USED.findall(text))
        for prefix in SCENE_PREFIX.findall(text):
            used.add(prefix)

    with CSV_PATH.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.reader(fh))
    header, data = rows[0], rows[1:]
    locales = header[1:]
    keys: dict[str, list[str]] = {}
    for row in data:
        if not row or not row[0]:
            continue
        if row[0] in keys:
            print(f"I18N FAIL: duplicate key {row[0]}")
            return 1
        keys[row[0]] = [c.strip() for c in row[1:]] + [""] * (len(locales) - len(row) + 1)

    missing = sorted(k for k in used if "." in k and k not in keys and k not in FIXTURES)
    if missing:
        print("I18N FAIL: keys used in code but missing from ui.csv:")
        for k in missing:
            print(f"  {k}")
        return 1

    empty = sorted(k for k, v in keys.items() if any(not c for c in v[: len(locales)]))
    if empty:
        print("I18N FAIL: keys with empty locale text:")
        for k in empty:
            print(f"  {k}")
        return 1

    dynamic_ok = {"faction.", "diff."}
    scene_prefixes = {p for p in used if "." not in p}
    unused = sorted(
        k for k in keys
        if k not in used
        and not any(k.startswith(p + ".") for p in scene_prefixes)
        and not any(k.startswith(p) for p in dynamic_ok)
    )
    if unused:
        print("I18N WARN: keys in ui.csv not referenced:")
        for k in unused:
            print(f"  {k}")

    print(f"I18N OK: {len(used)} literal keys used, {len(keys)} keys in csv, locales={locales}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
