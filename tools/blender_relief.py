#!/usr/bin/env python3
"""blender_relief.py - give the kit's flat materials real surface relief.

The kit GLBs ship flat colours with no images at all (and the board base has
no UVs), which is why everything reads "excessively smooth". This script, run
by Blender itself, rebuilds each asset's materials with procedural relief and
BAKES it into textures the game can use:

  1. UV unwrap (Smart UV Project) any mesh without usable UVs.
  2. Build a relief material per material name profile (stone / wood / gold /
     tint) with layered bump: fine grain noise + Voronoi crack network, plus
     noise-driven roughness and albedo mottling.
  3. Bake to images: NORMAL (tangent), ROUGHNESS and AO.
  4. Multiply AO into the baked colour (albedo = colour * ao^0.85).
  5. Rebuild the material with the baked maps and re-export the GLB with the
     textures embedded, so Godot shows the relief with no extra wiring.

Run:
    blender --background --python tools/blender_relief.py -- \
        --in assets/models --out assets/models --res 512 --only Tile_Normal

Recommended values live in docs/BLENDER_RELIEF.md; they are the constants in
the PROFILES table below.
"""
import math
import sys
import time
from pathlib import Path

import bpy
import numpy as np

# --- recommended relief profiles -------------------------------------------
# grain/bump/roughness values are the documented recommendations.
PROFILES = {
    "stone": {
        "grain_scale": 32.0, "grain_detail": 8.0, "grain_rough": 0.62,
        "crack_scale": 11.0, "crack_random": 1.0,
        "bump_fine": 0.28, "dist_fine": 0.012,
        "bump_crack": 0.55, "dist_crack": 0.030,
        "rough_base": 0.62, "rough_var": 0.22,
        "metal": 0.0, "mottle": 0.08,
    },
    "wood": {
        "grain_scale": 9.0, "grain_detail": 6.0, "grain_rough": 0.70,
        "crack_scale": 26.0, "crack_random": 0.9,
        "bump_fine": 0.22, "dist_fine": 0.010,
        "bump_crack": 0.35, "dist_crack": 0.018,
        "rough_base": 0.70, "rough_var": 0.16,
        "metal": 0.0, "mottle": 0.07,
    },
    "gold": {
        "grain_scale": 40.0, "grain_detail": 6.0, "grain_rough": 0.55,
        "crack_scale": 14.0, "crack_random": 1.0,
        "bump_fine": 0.18, "dist_fine": 0.008,
        "bump_crack": 0.30, "dist_crack": 0.014,
        "rough_base": 0.30, "rough_var": 0.12,
        "metal": 0.85, "mottle": 0.05,
    },
    "tint": {
        "grain_scale": 48.0, "grain_detail": 6.0, "grain_rough": 0.55,
        "crack_scale": 18.0, "crack_random": 1.0,
        "bump_fine": 0.14, "dist_fine": 0.006,
        "bump_crack": 0.22, "dist_crack": 0.010,
        "rough_base": 0.55, "rough_var": 0.12,
        "metal": 0.0, "mottle": 0.04,
    },
}

GOLD_HINTS = ("gold", "brass", "trim", "ring", "star", "emblem", "glow")
WOOD_HINTS = ("wood", "spine", "clamp")
TINT_HINTS = ("tint", "team", "inlay")
STONE_HINTS = ("stone", "slate", "rim", "socket", "floor", "navy", "pale", "body",
               "surface", "corner", "safe", "special", "lane", "motif", "goal")

MAT_PREFIX = "relief_"


def log(msg: str) -> None:
    print(f"[relief] {msg}", flush=True)


def profile_for(mat_name: str) -> str:
    n = mat_name.lower()
    if any(h in n for h in TINT_HINTS):
        return "tint"
    if any(h in n for h in GOLD_HINTS):
        return "gold"
    if any(h in n for h in WOOD_HINTS):
        return "wood"
    if any(h in n for h in STONE_HINTS):
        return "stone"
    return "stone"


def clean_name(name: str) -> str:
    ## Re-running the bake on its own output stacks MAT_PREFIX ("relief_relief_..").
    ## Strip every leading prefix so names stay stable and idempotent.
    while name.startswith(MAT_PREFIX):
        name = name[len(MAT_PREFIX):]
    return name


def base_color_of(mat) -> tuple:
    ## The kit ships flat colours in Base Color.default_value. But once an asset
    ## has been baked, Base Color is LINKED to the baked albedo texture and
    ## default_value falls back to the useless 0.8 grey -- reading it would grey
    ## the whole kit on a second pass. So handle the linked case explicitly.
    if mat.node_tree is None:
        c = mat.diffuse_color
        return (c[0], c[1], c[2])
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            inp = node.inputs["Base Color"]
            if inp.is_linked:
                return _linked_base_color(inp)
            c = inp.default_value
            return (c[0], c[1], c[2])
    return (0.5, 0.5, 0.5)


def _linked_base_color(inp) -> tuple:
    ## Base Color driven by a texture (an already-baked material): average the
    ## island pixels of the linked image to recover the tint.
    if inp.links:
        src = inp.links[0].from_node
        if src.type == "TEX_IMAGE" and src.image is not None:
            px = np.array(src.image.pixels[:], dtype=np.float32).reshape(-1, 4)
            m = px[px[:, :3].mean(axis=1) > 0.02, :3]
            if len(m):
                c = m.mean(axis=0)
                return (float(c[0]), float(c[1]), float(c[2]))
    return (0.8, 0.8, 0.8)


# --------------------------------------------------------------------- uv ---

def uv_area(obj) -> float:
    if not obj.data.uv_layers:
        return 0.0
    uv = obj.data.uv_layers[0].data
    if len(uv) == 0:
        return 0.0
    mn = [1e9, 1e9]
    mx = [-1e9, -1e9]
    for d in uv:
        for i in (0, 1):
            mn[i] = min(mn[i], d.uv[i])
            mx[i] = max(mx[i], d.uv[i])
    return (mx[0] - mn[0]) * (mx[1] - mn[1])


def unwrap_all(meshes: list, margin: float = 0.02, angle_deg: float = 66.0) -> str:
    ## One SHARED atlas per asset: multi-object edit mode, Smart UV Project for
    ## every mesh, then a single pack across all of them. Packing per object
    ## scales each object's islands to fill 0..1 and they overlap (the body and
    ## its motif then fight over the same texels).
    had_uv = sum(1 for o in meshes if uv_area(o) > 0.0005)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle_deg),
                             island_margin=margin)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return f"unwrapped+shared-atlas ({had_uv}/{len(meshes)} had UVs)"


# ------------------------------------------------------------- materials ----

def relief_material(name: str, col: tuple, prof_key: str):
    p = PROFILES[prof_key]
    mat = bpy.data.materials.new(MAT_PREFIX + name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (900, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (600, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
    bsdf.inputs["Metallic"].default_value = p["metal"]

    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.location = (-900, 0)

    # fine grain
    grain = nt.nodes.new("ShaderNodeTexNoise")
    grain.location = (-600, 200)
    grain.inputs["Scale"].default_value = p["grain_scale"]
    grain.inputs["Detail"].default_value = p["grain_detail"]
    grain.inputs["Roughness"].default_value = p["grain_rough"]
    nt.links.new(tc.outputs["Object"], grain.inputs["Vector"])

    # crack network (Voronoi distance-to-edge)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.location = (-600, -150)
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = p["crack_scale"]
    vor.inputs["Randomness"].default_value = p["crack_random"]
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])

    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-380, -150)
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[1].position = 0.08
    nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])

    bump_crack = nt.nodes.new("ShaderNodeBump")
    bump_crack.location = (100, -220)
    bump_crack.inputs["Strength"].default_value = p["bump_crack"]
    bump_crack.inputs["Distance"].default_value = p["dist_crack"]
    nt.links.new(ramp.outputs["Color"], bump_crack.inputs["Height"])

    bump_fine = nt.nodes.new("ShaderNodeBump")
    bump_fine.location = (320, -80)
    bump_fine.inputs["Strength"].default_value = p["bump_fine"]
    bump_fine.inputs["Distance"].default_value = p["dist_fine"]
    nt.links.new(grain.outputs["Fac"], bump_fine.inputs["Height"])
    nt.links.new(bump_crack.outputs["Normal"], bump_fine.inputs["Normal"])
    nt.links.new(bump_fine.outputs["Normal"], bsdf.inputs["Normal"])

    # roughness: base + noise variation
    map_rough = nt.nodes.new("ShaderNodeMapRange")
    map_rough.location = (100, 200)
    map_rough.inputs["To Min"].default_value = p["rough_base"] - p["rough_var"]
    map_rough.inputs["To Max"].default_value = p["rough_base"] + p["rough_var"]
    nt.links.new(grain.outputs["Fac"], map_rough.inputs["Value"])
    nt.links.new(map_rough.outputs["Result"], bsdf.inputs["Roughness"])

    # albedo mottling (dirt/variation) mixed into the flat colour
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.location = (320, 120)
    mix.inputs["A"].default_value = (col[0], col[1], col[2], 1.0)
    dark = tuple(max(0.0, c * (1.0 - p["mottle"] * 2.0)) for c in col)
    mix.inputs["B"].default_value = (dark[0], dark[1], dark[2], 1.0)
    nt.links.new(grain.outputs["Fac"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat


# ------------------------------------------------------------------ bake ----

def bake_image(name: str, res: int, non_color: bool, is_data: bool):
    img = bpy.data.images.new(name, width=res, height=res, alpha=False,
                              float_buffer=False, is_data=is_data)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def attach_target(obj, img):
    ## Every material of the object needs the target image node active.
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None or mat.node_tree is None:
            continue
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.location = (-1200, -400)
        node.select = True
        mat.node_tree.nodes.active = node


def detach_targets(obj):
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None or mat.node_tree is None:
            continue
        for node in list(mat.node_tree.nodes):
            if node.type == "TEX_IMAGE" and node.image is not None \
                    and node.image.name.startswith("bake_"):
                mat.node_tree.nodes.remove(node)


def bake_object(obj, kind: str, img, clear: bool = False) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bake = bpy.context.scene.render.bake
    if kind == "NORMAL":
        bake.normal_space = "TANGENT"
    elif kind == "DIFFUSE":
        # colour only: the bake scene has no lights, so direct/indirect = black
        bake.use_pass_direct = False
        bake.use_pass_indirect = False
        bake.use_pass_color = True
    # use_clear on EVERY object would erase the previous objects' islands:
    # clear once (first object), then accumulate into the shared atlas.
    bpy.ops.object.bake(type=kind, margin=16, use_clear=clear)


def combine_albedo(color_img, ao_img, out_img, power: float = 0.85) -> None:
    c = np.array(color_img.pixels[:], dtype=np.float32).reshape(-1, 4)
    a = np.array(ao_img.pixels[:], dtype=np.float32).reshape(-1, 4)[:, 0]
    fac = np.power(np.clip(a, 0.0, 1.0), power)
    c[:, 0] *= fac
    c[:, 1] *= fac
    c[:, 2] *= fac
    out_img.pixels[:] = c.reshape(-1).tolist()


def finalize_material(mat, base_img, rough_img, normal_img, prof_key: str):
    ## Rebuild the tree around the baked maps so the GLB carries real PBR.
    p = PROFILES[prof_key]
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (300, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = p["metal"]

    tex_base = nt.nodes.new("ShaderNodeTexImage")
    tex_base.image = base_img
    tex_base.location = (-300, 200)
    nt.links.new(tex_base.outputs["Color"], bsdf.inputs["Base Color"])

    tex_rough = nt.nodes.new("ShaderNodeTexImage")
    tex_rough.image = rough_img
    tex_rough.location = (-300, -60)
    nt.links.new(tex_rough.outputs["Color"], bsdf.inputs["Roughness"])

    tex_norm = nt.nodes.new("ShaderNodeTexImage")
    tex_norm.image = normal_img
    tex_norm.location = (-500, -320)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.location = (-160, -320)
    nm.inputs["Strength"].default_value = 1.0
    nt.links.new(tex_norm.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])


# ------------------------------------------------------------------ main ----

def process(glb: Path, out_dir: Path, res: int) -> dict:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 8
    scn.cycles.use_denoising = False
    scn.render.bake.margin = 16
    scn.render.image_settings.file_format = "PNG"

    meshes = [o for o in scn.objects if o.type == "MESH"]
    if not meshes:
        return {"asset": glb.name, "error": "no meshes"}

    # guard: baking an already-baked asset compounds mottle/AO and, on older
    # versions, greyed the kit (Base Color was linked, so default_value = 0.8).
    baked_in = [m.name for m in bpy.data.materials if m.name.startswith(MAT_PREFIX)]
    if baked_in:
        log(f"WARNING {glb.name}: input already baked ({baked_in[0]}) -- "
            "re-run from the pristine source folder to keep colours exact")

    # 1) UVs + relief materials
    stats = {"uv": unwrap_all(meshes)}
    per_mat_profile = {}
    for obj in meshes:
        for slot in obj.material_slots:
            src = slot.material
            if src is None:
                continue
            key = clean_name(src.name)
            prof_key = profile_for(key)
            per_mat_profile[key] = prof_key
            relief = bpy.data.materials.get(MAT_PREFIX + key)
            if relief is None:
                relief = relief_material(key, base_color_of(src), prof_key)
            slot.material = relief

    # 2) bake the three maps per object into one shared image per material set
    stem = glb.stem
    tag = stem.lower()
    bake_dir = out_dir / "baked"
    bake_dir.mkdir(parents=True, exist_ok=True)
    normal_img = bake_image(f"bake_{tag}_normal", res, True, True)
    rough_img = bake_image(f"bake_{tag}_rough", res, True, True)
    ao_img = bake_image(f"bake_{tag}_ao", res, True, True)
    color_img = bake_image(f"bake_{tag}_color", res, False, False)

    for idx, obj in enumerate(meshes):
        first = idx == 0
        for kind, img in (("NORMAL", normal_img), ("ROUGHNESS", rough_img),
                          ("AO", ao_img), ("DIFFUSE", color_img)):
            attach_target(obj, img)
            bake_object(obj, kind, img, clear=first)
            detach_targets(obj)

    # 3) albedo = colour * ao^0.85
    albedo = bake_image(f"bake_{tag}_albedo", res, False, False)
    combine_albedo(color_img, ao_img, albedo)

    # 4) rewire + export
    for name, prof_key in per_mat_profile.items():
        mat = bpy.data.materials.get(MAT_PREFIX + name)
        if mat is not None:
            finalize_material(mat, albedo, rough_img, normal_img, prof_key)

    for img, suffix in ((normal_img, "normal"), (rough_img, "rough"),
                        (albedo, "albedo")):
        img.filepath_raw = str(bake_dir / f"{tag}_{suffix}.png")
        img.file_format = "PNG"
        img.save()

    out_glb = out_dir / glb.name
    bpy.ops.export_scene.gltf(filepath=str(out_glb), export_format="GLB",
                              export_apply=True, export_yup=True)
    return {
        "asset": glb.name,
        "meshes": len(meshes),
        "uv": stats,
        "materials": len(per_mat_profile),
        "out_kb": round(out_glb.stat().st_size / 1024),
    }


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {}
    for i in range(0, len(argv) - 1, 2):
        args[argv[i].lstrip("-")] = argv[i + 1]
    in_dir = Path(args.get("in", "assets/models"))
    out_dir = Path(args.get("out", in_dir))
    res = int(args.get("res", "512"))
    only = [s.strip() for s in args.get("only", "").split(",") if s.strip()]

    glbs = sorted(in_dir.glob("*.glb"))
    if only:
        glbs = [g for g in glbs if any(o.lower() in g.stem.lower() for o in only)]
    log(f"processing {len(glbs)} assets at {res}px -> {out_dir}")
    for glb in glbs:
        t0 = time.time()
        try:
            info = process(glb, out_dir, res)
        except Exception as exc:                     # keep the batch going
            log(f"FAILED {glb.name}: {exc}")
            continue
        log(f"{info} in {time.time() - t0:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
