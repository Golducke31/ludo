# REFERENCE COPY — DO NOT ATTACH TO A NODE.
# This is the original pack script from Desktop/newtext/. Its logic is
# INTEGRATED into scripts/game/views3d/arena_3d.gd (PBR_MAP + _retexture_pbr +
# the upgraded Environment in _build_stage). Attaching this standalone would
# create a SECOND WorldEnvironment and duplicate lights. Keep this file only as
# provenance / a porting reference.
# ---------------------------------------------------------------------------
# visual_polish.gd  — Godot 4.x (Forward+ recomendado)
# Uso: agregá este script a un Node3D en tu escena de juego (o como Autoload) y copiá la carpeta textures/ a res://textures/.
# Hace tres cosas: (1) entorno con glow/SSAO/niebla/tonemap, (2) luces de luna y calidez, (3) reemplaza materiales planos por PBR con triplanar.
extends Node3D

@export var tex_dir := "res://textures/"
@export var apply_to: NodePath            # nodo raíz con los modelos del tablero (si vacío, usa get_parent())
@export var moon_color := Color(0.55, 0.62, 1.0)
@export var fog_color := Color(0.16, 0.12, 0.30)

# nombre de material en los .glb  ->  [textura, escala world (m por tile), tinte, rugosidad extra]
const MAP := {
	"floor_charcoal":      ["floor_stone", 0.22, Color(1.0,1.0,1.0)],
	"slate_dark":          ["wall_brick",  0.30, Color(0.85,0.85,0.95)],
	"rim_stone":           ["wall_brick",  0.45, Color(1.0,1.0,1.0)],
	"stone_pale":          ["tile_pale",   0.90, Color(1.0,1.0,1.0)],
	"stone_pale_motif":    ["tile_pale",   0.90, Color(0.7,0.7,0.8)],
	"stone_navy":          ["floor_stone", 0.30, Color(0.8,0.85,1.0)],
	"altar_tier1_stone":   ["wall_brick",  0.60, Color(0.9,0.9,1.0)],
	"altar_tier2_stone":   ["wall_brick",  0.60, Color(1.0,1.0,1.0)],
	"altar_tier3_stone":   ["floor_stone", 0.60, Color(1.0,1.0,1.0)],
	"wall_purple_stone":   ["wall_brick",  0.80, Color(1.0,0.95,1.1)],
	"grave_stone":         ["floor_stone", 0.70, Color(1.0,1.0,1.0)],
	"grave_stone_light":   ["tile_pale",   1.20, Color(0.75,0.75,0.85)],
	"base_rock_charcoal":  ["floor_stone", 1.20, Color(0.8,0.8,0.9)],
	"wood_dark":           ["wood_dark",   0.60, Color(1.0,1.0,1.0)],
	"door_wood":           ["wood_dark",   0.60, Color(1.0,1.0,1.0)],
	"bark_dark":           ["wood_dark",   0.80, Color(0.8,0.75,0.85)],
	"pumpkin_body":        ["pumpkin_skin",1.00, Color(1.0,1.0,1.0)],
	"pumpkin_orange":      ["pumpkin_skin",1.00, Color(1.0,1.0,1.0)],
	"pumpkin_pale":        ["pumpkin_skin",1.00, Color(1.1,1.0,0.9)],
	"pumpkin_deep":        ["pumpkin_skin",1.00, Color(0.9,0.85,0.8)],
	"safe_purple":         ["tile_pale",   0.90, Color(0.62,0.34,1.0)],
	"special_orange":      ["tile_pale",   0.90, Color(1.0,0.55,0.18)],
	"corner_navy":         ["tile_pale",   0.90, Color(0.35,0.40,0.70)],
	"floor_special_rune":  ["tile_rune_glow",0.9, Color(1,1,1)],
}

var _cache := {}

func _ready() -> void:
	_setup_environment()
	_setup_lights()
	var root: Node = get_node_or_null(apply_to) if apply_to != NodePath() else get_parent()
	_retexture(root)

func _tex(n: String) -> Texture2D:
	var p := tex_dir + n
	if not _cache.has(p): _cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.05, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.30, 0.55)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.2
	env.ssil_enabled = true            # luz indirecta falsa: calidez que rebota de las velas/linternas
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.012
	env.volumetric_fog_enabled = true  # bruma con rayos de luz (quitalo en móvil)
	env.volumetric_fog_density = 0.015
	env.volumetric_fog_albedo = Color(0.45, 0.40, 0.75)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)

func _setup_lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = moon_color
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-52, -35, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.shadow_blur = 1.6
	add_child(moon)
	var rim := DirectionalLight3D.new()    # contraluz violeta para recortar siluetas
	rim.light_color = Color(0.75, 0.40, 1.0)
	rim.light_energy = 0.35
	rim.rotation_degrees = Vector3(-20, 150, 0)
	add_child(rim)

func _retexture(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			for s in mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m is BaseMaterial3D and MAP.has(m.resource_name):
					mi.set_surface_override_material(s, _make(m as BaseMaterial3D, MAP[m.resource_name]))
	for c in n.get_children(): _retexture(c)

func _make(src: BaseMaterial3D, cfg: Array) -> StandardMaterial3D:
	var key := "%s|%s" % [src.resource_name, cfg[0]]
	if _cache.has(key): return _cache[key]
	var m := StandardMaterial3D.new()
	m.resource_name = src.resource_name
	var tint: Color = cfg[2]
	var a := _tex(cfg[0] + "_albedo.png")
	if a:
		m.albedo_texture = a
		m.albedo_color = tint
	else:
		m.albedo_color = src.albedo_color
	var nrm := _tex(cfg[0] + "_normal.png")
	if nrm:
		m.normal_enabled = true; m.normal_texture = nrm; m.normal_scale = 1.1
	var orm := _tex(cfg[0] + "_orm.png")
	if orm:
		m.ao_enabled = true; m.ao_texture = orm; m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED; m.ao_light_affect = 0.6
		m.roughness_texture = orm; m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = 0.0
	var e := _tex(cfg[0] + "_emission.png")
	if e:
		m.emission_enabled = true; m.emission_texture = e; m.emission_energy_multiplier = 1.8
	m.uv1_triplanar = true; m.uv1_world_triplanar = true      # sin depender de las UVs
	var s: float = cfg[1]; m.uv1_scale = Vector3(s, s, s)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m
