#!/usr/bin/env python3
"""inspect_glb.py - dump GLB structure: meshes, bboxes, materials, nodes."""
import struct
import json
from pathlib import Path

FOLDER = Path(r"C:/Users/emanu/Desktop/ludo")


def inspect(path: Path) -> None:
    data = path.read_bytes()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        print(f"{path.name}: NOT GLB")
        return
    off = 12
    js = None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        pad = (4 - clen % 4) % 4
        off += 8 + clen + pad
    g = js
    meshes = g.get("meshes", [])
    mats = [m.get("name", "?") for m in g.get("materials", [])]
    nodes = g.get("nodes", [])
    print(f"--- {path.name} ({length/1024:.0f} KB) gen={g.get('asset',{}).get('generator','?')}")
    print(f"    meshes={len(meshes)} materials={len(mats)} nodes={len(nodes)}")
    accs = g.get("accessors", [])
    seen = set()
    for m in meshes:
        for prim in m.get("primitives", []):
            ai = prim.get("attributes", {}).get("POSITION")
            if ai is None or ai in seen:
                continue
            seen.add(ai)
            a = accs[ai]
            if "min" in a and "max" in a:
                mn, mx = a["min"], a["max"]
                size = [round(mx[i] - mn[i], 4) for i in range(3)]
                print(f"      {m.get('name','mesh')}: size={size} "
                      f"min={[round(v,3) for v in mn]} max={[round(v,3) for v in mx]}")
    if mats:
        print("      materials:", mats[:8])
    nnames = [n.get("name", "?") for n in nodes][:10]
    if nnames:
        print("      nodes:", nnames)


for f in sorted(FOLDER.glob("*.glb")):
    inspect(f)
