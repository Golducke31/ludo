#!/usr/bin/env python3
"""check_scene_refs.py - every %Node ref in a script must be a unique_name node
in the scene that hosts it (M4 gate, catches the %BonusTitle class of bug).

Usage: python check_scene_refs.py
Exits 1 when a script references a node its scene does not expose.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# script -> scene that hosts it (exact, not rglob: there are two settings.gd)
HOSTS = {
    "scripts/game/views/hud.gd": "scenes/game/match_root.tscn",
    "scripts/game/views/pause_overlay.gd": "scenes/game/match_root.tscn",
    "scripts/game/views/results_overlay.gd": "scenes/game/match_root.tscn",
    "scripts/ui/setup.gd": "scenes/ui/setup.tscn",
    "scripts/ui/settings.gd": "scenes/ui/settings.tscn",
    "scripts/ui/credits.gd": "scenes/ui/credits.tscn",
    "scripts/ui/tutorial.gd": "scenes/ui/tutorial.tscn",
    "scripts/ui/main_menu.gd": "scenes/ui/main_menu.tscn",
}
NODE = re.compile(r'\[node name="([^"]+)"[^\]]*\][^\[]*?unique_name_in_owner = true')
REF = re.compile(r'%([A-Z][A-Za-z0-9_]*)')


def main() -> int:
    ok = True
    for script, scene in sorted(HOSTS.items()):
        spath, gpath = ROOT / script, ROOT / scene
        if not spath.exists() or not gpath.exists():
            print(f"  MISSING FILE {script} or {scene}")
            ok = False
            continue
        uniq = set(NODE.findall(gpath.read_text(encoding="utf-8")))
        refs = set(REF.findall(spath.read_text(encoding="utf-8")))
        missing = sorted(refs - uniq)
        if missing:
            print(f"FAIL {scene}: {missing} referenced by {script} but not unique_name_in_owner")
            ok = False
        else:
            print(f"OK   {script}: {len(refs)} refs exposed by {scene}")
    print("SCENE REFS AUDIT", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
