extends Node3D
## 3D arena built from the user's GLB kit (Desktop/ludo -> assets/models/).
##
## Scale contract: our design pitch (2720/52 design px between ring squares)
## maps to the kit's tile width (0.85), so K = 0.85 / pitch. Ring tiles then sit
## 1:1; home lanes (6 tiles, 1.0 native pitch) are squashed to (1, 1, 0.85) so
## their tiles land exactly on our column squares; the home platforms' four
## token sockets (0.84 spacing) land on our pen slots (0.845). The kit's own
## HomeZone slabs are stripped: our pens live outside the ring, theirs inside.
##
## Contract: no _process. The board builds on match_started, pieces re-sync on
## the same EventBus signals the 2D views used, and pick_piece_at() keeps the
## old screen-space parity. reduce_motion / fast_mode skip every tween.

const KIT := "res://assets/models/"
const DESIGN_PITCH := 2720.0 / 52.0        # ring square pitch (design px)
const K := 0.85 / DESIGN_PITCH             # design px -> world units
const BASE_SCALE := 1.35                   # 12x12 kit base -> 16.2 stage
const FLOOR_Y := 0.81                      # stage floor top after BASE_SCALE
const TILE_TOP := FLOOR_Y + 0.20           # ring tile surface
const PLATFORM_TOP := FLOOR_Y + 0.44       # home platform surface
const ALTAR_SCALE := 1.2
const CAM_DIST := 20.0
const HUD_FREE_FALLBACK := 0.74            # used until the panel is measurable
const CLICK_RADIUS := 44.0                 # screen-space pick radius (px)
const JUMP_TIME := 0.22
const JUMP_HEIGHT := 0.42

const TILE_NORMAL := preload(KIT + "Tile_Normal.glb")
const TILE_SAFE := preload(KIT + "Tile_Safe.glb")
const TILE_SPECIAL := preload(KIT + "Tile_Special.glb")
const TILE_START := preload(KIT + "Tile_Start.glb")
const TILE_CORNER := preload(KIT + "Tile_Corner.glb")
const BASE_SCENE := preload(KIT + "tablero_halloween_base.glb")
const ALTAR_SCENE := preload(KIT + "altar_calabaza.glb")
const MANSION_SCENE := preload(KIT + "mansion_embrujada.glb")
const LANES := {
    &"gato_negro": preload(KIT + "FinalLane6_Carmesi.glb"),
    &"fantasma_bruja": preload(KIT + "FinalLane6_Purpura.glb"),
    &"rey_calabaza": preload(KIT + "FinalLane6_NaranjaDorado.glb"),
    &"conejo_espectral": preload(KIT + "FinalLane6_Esmeralda.glb"),
}
const PLATFORMS := {
    &"gato_negro": preload(KIT + "HomePlatform_Carmesi.glb"),
    &"fantasma_bruja": preload(KIT + "HomePlatform_Purpura.glb"),
    &"rey_calabaza": preload(KIT + "HomePlatform_NaranjaDorado.glb"),
    &"conejo_espectral": preload(KIT + "HomePlatform_Esmeralda.glb"),
}
const BANNERS := {
    &"gato_negro": preload(KIT + "Banner_Pata_Carmesi.glb"),
    &"fantasma_bruja": preload(KIT + "Banner_Luna_Purpura.glb"),
    &"rey_calabaza": preload(KIT + "Banner_Calabaza_NaranjaDorado.glb"),
    &"conejo_espectral": preload(KIT + "Banner_Luna_Esmeralda.glb"),
}
const CORNER_SQUARES := [51, 12, 25, 38]   # the four square-ring corners

enum CamMode { ISO, FOLLOW }

var _cam: Camera3D                         # isometric overview
var _cam_follow: Camera3D                  # first-person rider
var _cam_mode := CamMode.ISO
var _focus_id := -1                        # piece ridden in FOLLOW mode
var _focus_dir := Vector3(0.0, 0.0, 1.0)   # heading of the ridden piece
var _focus_target := Vector3.ZERO          # destination while a hop is in flight
var _last_moved_id := -1                   # ride fallback when the turn passes
var _follow_tween: Tween = null
var _board_root: Node3D = null
var _scenery: Array = []                   # fixed props included in the camera fit
var _pieces: Dictionary = {}               # piece_id -> Node3D
var _tweens: Dictionary = {}               # piece_id -> Tween
var _hints: Array = []                     # turn rings + destination markers
var _die: Node3D = null
var _die_inner: Node3D = null
var _die_tween: Tween = null

func _ready() -> void:
    _build_stage()
    EventBus.match_started.connect(func(_c, _m): _build_board())
    EventBus.match_abandoned.connect(_clear_board)
    EventBus.settings_changed.connect(_on_settings_changed)
    get_viewport().size_changed.connect(_fit_camera)
    EventBus.turn_changed.connect(_on_turn_changed)
    EventBus.dice_rolled.connect(_on_dice_rolled)
    EventBus.piece_moved.connect(_on_piece_moved)
    EventBus.bonus_resolved.connect(func(_c): _sync_pieces(true))
    EventBus.pieces_captured.connect(func(_ids, _by): _sync_pieces(false))
    EventBus.match_finished.connect(func(_r): _sync_pieces(false))
    Game.state_changed.connect(func(_s): _refresh_hints())

# ---------------------------------------------------------------- stage ----

func _build_stage() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.043, 0.040, 0.098)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.227, 0.204, 0.439)
    e.ambient_light_energy = 0.45
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.glow_enabled = true
    e.glow_intensity = 0.75
    e.glow_bloom = 0.1
    e.ssao_enabled = true
    e.ssao_radius = 0.6
    e.ssao_intensity = 0.8
    e.fog_enabled = true
    e.fog_light_color = Color(0.165, 0.129, 0.314)
    e.fog_density = 0.012
    env.environment = e
    add_child(env)

    # ground under the whole scene (mansion + stage share it)
    var ground := MeshInstance3D.new()
    var gm := BoxMesh.new()
    gm.size = Vector3(56.0, 0.3, 56.0)
    ground.mesh = gm
    var gmat := StandardMaterial3D.new()
    gmat.albedo_color = Color(0.075, 0.070, 0.115)
    gmat.roughness = 0.95
    ground.material_override = gmat
    ground.position = Vector3(0, -0.15, 0)
    add_child(ground)

    # stage base (kit), minus its HomeZone slabs (our pens sit outside the ring)
    var base: Node3D = BASE_SCENE.instantiate()
    base.scale = Vector3.ONE * BASE_SCALE
    _strip_nodes(base, "HomeZone")
    add_child(base)

    # scenery: haunted mansion + moon
    var mansion: Node3D = MANSION_SCENE.instantiate()
    mansion.position = Vector3(-12.5, 0.0, 0.0)
    mansion.rotation_degrees = Vector3(0, 45, 0)
    mansion.scale = Vector3.ONE * 0.95
    add_child(mansion)
    _scenery.append(mansion)

    # key: cold moonlight (shadows, bias from the review pass)
    var sun := DirectionalLight3D.new()
    sun.light_color = Color(0.561, 0.627, 1.0)
    sun.light_energy = 1.1
    sun.shadow_enabled = true
    sun.shadow_bias = 0.06
    sun.shadow_normal_bias = 1.5
    sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
    add_child(sun)

    # fill: warm torch bounce onto the camera-facing sides
    var fill := DirectionalLight3D.new()
    fill.light_color = ViewPalette.ACCENT_ORANGE
    fill.light_energy = 0.55
    fill.shadow_enabled = false
    fill.rotation_degrees = Vector3(-14.5, 45.0, 0.0)
    add_child(fill)

    # warm corner lamps (Halloween contrast)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var lamp := OmniLight3D.new()
            lamp.light_color = Color(1.0, 0.604, 0.235)
            lamp.light_energy = 1.9
            lamp.omni_range = 10.0
            lamp.shadow_enabled = false
            lamp.position = Vector3(sx * 7.6, 1.7, sz * 7.6)
            add_child(lamp)

    _cam = Camera3D.new()
    _cam.projection = Camera3D.PROJECTION_ORTHOGONAL
    _cam.size = 12.0
    _cam.far = 160.0
    _cam.position = Vector3(CAM_DIST, CAM_DIST, CAM_DIST)
    add_child(_cam)
    _cam.look_at(Vector3.ZERO, Vector3.UP)
    _cam.current = true

    # first-person rider (eye height just above the tile tops)
    _cam_follow = Camera3D.new()
    _cam_follow.projection = Camera3D.PROJECTION_PERSPECTIVE
    _cam_follow.fov = 72.0
    _cam_follow.near = 0.05
    _cam_follow.far = 200.0
    add_child(_cam_follow)
    _cam_follow.current = false

    _build_die()

func camera_mode() -> int:
    return _cam_mode

func _active_camera() -> Camera3D:
    return _cam_follow if _cam_mode == CamMode.FOLLOW else _cam

func toggle_camera_mode() -> void:
    _cam_mode = CamMode.FOLLOW if _cam_mode == CamMode.ISO else CamMode.ISO
    _cam.current = _cam_mode == CamMode.ISO
    _cam_follow.current = _cam_mode == CamMode.FOLLOW
    if _cam_mode == CamMode.FOLLOW:
        _pick_focus()
        _update_follow(false)
    EventBus.camera_mode_changed.emit(_cam_mode)

func _pick_focus() -> void:
    ## Ride, in order of preference: the current player's movable piece, any of
    ## their pieces in play, the last piece that moved, any piece in play.
    ## Keeps the previous ride when nothing better exists (bots open from the
    ## pen, so the current player often has nothing on the ring yet).
    if Game.active_match == null or Game.layout == null:
        return
    var state = Game.active_match.state
    var cur: int = state.current
    var movable := -1
    var in_play := -1
    if cur >= 0 and cur < state.players.size():
        for piece in state.players[cur].pieces:
            if piece.in_pen() or piece.in_goal():
                continue
            if in_play < 0:
                in_play = piece.id
        for m in Game.active_match.legal_moves():
            var mid: int = int(m.piece_id)
            if int(mid / 10) == cur and _pieces.has(mid):
                movable = mid
                break
    var last_ok := -1
    if _last_moved_id >= 0 and _pieces.has(_last_moved_id):
        var lp: PieceState = state.piece_by_id(_last_moved_id)
        if lp != null and not lp.in_pen() and not lp.in_goal():
            last_ok = _last_moved_id
    var any_play := -1
    for pl in state.players:
        for piece in pl.pieces:
            if not piece.in_pen() and not piece.in_goal() and _pieces.has(piece.id):
                any_play = piece.id
                break
        if any_play >= 0:
            break
    var pick := -1
    for candidate in [movable, in_play, last_ok, any_play, _focus_id]:
        if candidate >= 0 and _pieces.has(candidate):
            pick = candidate
            break
    if pick < 0:
        _focus_target = Vector3.ZERO
        return
    _focus_id = pick
    _focus_target = (_pieces[pick] as Node3D).position

func _focus_position() -> Vector3:
    if _focus_target != Vector3.ZERO:
        return _focus_target
    if _focus_id >= 0 and _pieces.has(_focus_id):
        return (_pieces[_focus_id] as Node3D).position
    return Vector3(0.0, TILE_TOP + 0.4, 0.0)

func _follow_transform() -> Transform3D:
    var anchor := _focus_position()
    var dir := _focus_dir
    if dir.length() < 0.01:
        dir = Vector3(0.0, 0.0, 1.0)
    var eye := anchor - dir * 1.05 + Vector3.UP * 0.62
    var look := anchor + dir * 1.6 + Vector3.UP * 0.24
    return Transform3D(Basis.looking_at((look - eye).normalized(), Vector3.UP), eye)

func _update_follow(animate: bool) -> void:
    if _cam_follow == null:
        return
    if _follow_tween != null and _follow_tween.is_valid():
        _follow_tween.kill()
    var target := _follow_transform()
    if not animate or _reduced_motion():
        _cam_follow.global_transform = target
        return
    # lag behind the hop so the ride reads as "following" the piece
    _follow_tween = create_tween()
    _follow_tween.tween_interval(0.10)
    _follow_tween.tween_property(_cam_follow, "global_transform", target, 0.40) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _strip_nodes(root: Node, prefix: String) -> void:
    for child in root.get_children():
        if child.name.begins_with(prefix):
            child.queue_free()
        else:
            _strip_nodes(child, prefix)

# ---------------------------------------------------------------- board ----

func _on_settings_changed() -> void:
    if _board_root != null:
        _build_board()

func _clear_board() -> void:
    for id in _tweens:
        var tw: Tween = _tweens[id]
        if tw != null and tw.is_valid():
            tw.kill()
    _tweens.clear()
    _pieces.clear()
    _hints.clear()
    if _board_root != null:
        _board_root.queue_free()
        _board_root = null

func _apply_accessibility() -> void:
    ViewPalette.apply_accessibility(
        bool(Settings.get_setting("high_contrast")),
        bool(Settings.get_setting("colorblind_mode")))

static func world_of(design: Vector2) -> Vector3:
    ## Design space (1920x1080, y down) -> world plane (y = 0).
    return Vector3(
        (design.x - BoardLayout.BOARD_CENTER.x) * K,
        0.0,
        (design.y - BoardLayout.BOARD_CENTER.y) * K)

func _build_board() -> void:
    _clear_board()
    if Game.active_match == null or Game.layout == null:
        return
    _apply_accessibility()
    var lay: BoardLayout = Game.layout
    var rules: MatchRules = Game.active_match.rules
    var state = Game.active_match.state
    _board_root = Node3D.new()
    add_child(_board_root)

    # --- ring tiles ------------------------------------------------------
    for i in rules.ring_size:
        var tile: Node3D = _tile_scene_for(i, rules).instantiate()
        tile.position = world_of(lay.ring_position(i)) + Vector3(0.0, FLOOR_Y, 0.0)
        _board_root.add_child(tile)
        var start_of := _start_owner(i, rules)
        if start_of >= 0:
            _tint_tile(tile, ViewPalette.tint(state.players[start_of].faction_id))
        var special: StringName = Game.active_match.geo.special_at(i)
        if special == &"portal":
            _add_special_icon(tile, ViewPalette.SPECTRAL_GREEN, true)
        elif special == &"lantern":
            _add_special_icon(tile, ViewPalette.ACCENT_ORANGE, false)

    # --- home lanes + platforms + banners --------------------------------
    # Only the ACTIVE seats own an arm: the ring always has 4 arms, but a
    # 2- or 3-player match leaves the rest unused (indexing state.players with
    # a hardcoded 4 crashed the whole board build).
    for p in state.players.size():
        var faction: StringName = state.players[p].faction_id
        var lane: Node3D = (LANES.get(faction, LANES[&"gato_negro"]) as PackedScene).instantiate()
        lane.scale = Vector3(1.0, 1.0, 0.85)
        lane.position = world_of(lay.column_position(p, 0)) + Vector3(0.0, FLOOR_Y, 0.0)
        lane.rotation.y = _lane_yaw(p, rules)
        _board_root.add_child(lane)

        var out := _outward_dir(p)
        var center := _pen_center(p, lay, rules)
        var plat: Node3D = (PLATFORMS.get(faction, PLATFORMS[&"gato_negro"]) as PackedScene).instantiate()
        plat.position = center + out * 0.1 + Vector3(0.0, FLOOR_Y, 0.0)
        plat.rotation.y = atan2(-out.x, -out.z)
        _board_root.add_child(plat)

        var banner: Node3D = (BANNERS.get(faction, BANNERS[&"gato_negro"]) as PackedScene).instantiate()
        banner.position = plat.position + out * 0.98 + Vector3(0.0, 0.30, 0.0)
        banner.rotation.y = plat.rotation.y
        _board_root.add_child(banner)

    # --- moon altar at the centre socket ---------------------------------
    var altar: Node3D = ALTAR_SCENE.instantiate()
    altar.scale = Vector3.ONE * ALTAR_SCALE
    altar.position = Vector3(0.0, FLOOR_Y, 0.0)
    _board_root.add_child(altar)

    _build_pieces()
    _fit_camera.call_deferred()

func _start_owner(idx: int, rules: MatchRules) -> int:
    ## Only ACTIVE seats own a start tile: a 2-player match must not tint the
    ## two unused arms (and must never index past state.players).
    var count := 4
    if Game.active_match != null:
        count = Game.active_match.state.players.size()
    for p in count:
        if rules.start_index(p) == idx:
            return p
    return -1

func _tile_scene_for(idx: int, rules: MatchRules) -> PackedScene:
    if _start_owner(idx, rules) >= 0:
        return TILE_START
    if Game.active_match.geo.special_at(idx) != &"":
        return TILE_SPECIAL
    if CORNER_SQUARES.has(idx):
        return TILE_CORNER
    if Game.active_match.geo.is_safe(idx):
        return TILE_SAFE
    return TILE_NORMAL

func _tint_tile(tile: Node3D, col: Color) -> void:
    ## Tile_Start carries a tint_white plate: swap it for the faction colour.
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.roughness = 0.7
    for node in _walk(tile):
        if node is MeshInstance3D and node.name.begins_with("Tint"):
            (node as MeshInstance3D).material_override = mat

func _add_special_icon(tile: Node3D, col: Color, portal: bool) -> void:
    var icon := MeshInstance3D.new()
    if portal:
        var tm := TorusMesh.new()
        tm.inner_radius = 0.10
        tm.outer_radius = 0.20
        icon.mesh = tm
    else:
        var cm := CylinderMesh.new()
        cm.top_radius = 0.0
        cm.bottom_radius = 0.14
        cm.height = 0.26
        icon.mesh = cm
    icon.material_override = _emissive(col, 1.8)
    icon.position = Vector3(0.0, 0.42, 0.0)
    tile.add_child(icon)

func _walk(root: Node) -> Array:
    var out: Array = []
    for child in root.get_children():
        out.append(child)
        out.append_array(_walk(child))
    return out

func _outward_dir(p: int) -> Vector3:
    ## Unit diagonal (world XZ) pointing away from the board centre.
    match p:
        0: return Vector3(1, 0, 1).normalized()
        1: return Vector3(-1, 0, 1).normalized()
        2: return Vector3(-1, 0, -1).normalized()
        _: return Vector3(1, 0, -1).normalized()

func _pen_center(p: int, lay: BoardLayout, rules: MatchRules) -> Vector3:
    var c := Vector2.ZERO
    for s in rules.pieces_per_player:
        c += lay.pen_position(p, s)
    return world_of(c / float(rules.pieces_per_player))

func _lane_yaw(p: int, rules: MatchRules) -> float:
    ## The kit lane runs along -Z; aim it inward from the ring entry edge.
    var entry := rules.home_entry_index(p)
    var inward := Vector3.ZERO
    match entry / rules.arm_length:
        0: inward = Vector3(0, 0, -1)
        1: inward = Vector3(1, 0, 0)
        2: inward = Vector3(0, 0, 1)
        _: inward = Vector3(-1, 0, 0)
    return atan2(-inward.x, -inward.z)

# --------------------------------------------------------------- pieces ----

func _build_pieces() -> void:
    for p in Game.active_match.state.players:
        for piece in p.pieces:
            var node := _make_piece_node(p.faction_id)
            node.position = world_position_for(piece)
            _board_root.add_child(node)
            _pieces[piece.id] = node
    _refresh_hints()

func _faction_mat(col: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = rough
    return m

func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi

func _make_piece_node(faction: StringName) -> Node3D:
    ## Stylised Halloween piece per faction (the kit ships board parts only).
    var root := Node3D.new()
    root.scale = Vector3.ONE * 1.45
    var body_mat := _faction_mat(ViewPalette.tint(faction), 0.55)
    var dark := _faction_mat(ViewPalette.PIECE_OUTLINE, 0.6)
    var cream := _faction_mat(ViewPalette.TEXT_CREAM, 0.5)
    var violet := _faction_mat(ViewPalette.SQUARE_COLUMN, 0.6)

    # pedestal disc (contrast under dark silhouettes)
    var ped := CylinderMesh.new()
    ped.top_radius = 0.30
    ped.bottom_radius = 0.30
    ped.height = 0.03
    var pmat := StandardMaterial3D.new()
    pmat.albedo_color = ViewPalette.PEDESTAL
    pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _add_mesh(root, ped, pmat, Vector3(0.0, 0.02, 0.0))

    var sphere := SphereMesh.new()
    var cone := CylinderMesh.new()
    var eye := SphereMesh.new()
    eye.radius = 0.045
    eye.height = 0.09

    match faction:
        &"rey_calabaza":
            sphere.radius = 0.24
            sphere.height = 0.42
            _add_mesh(root, sphere, body_mat, Vector3(0.0, 0.24, 0.0))
            var stem := CylinderMesh.new()
            stem.top_radius = 0.04
            stem.bottom_radius = 0.05
            stem.height = 0.14
            _add_mesh(root, stem, dark, Vector3(0.0, 0.47, 0.0))
            _add_mesh(root, eye, cream, Vector3(-0.08, 0.28, 0.19))
            _add_mesh(root, eye, cream, Vector3(0.08, 0.28, 0.19))
        &"fantasma_bruja":
            sphere.radius = 0.22
            sphere.height = 0.40
            _add_mesh(root, sphere, body_mat, Vector3(0.0, 0.23, 0.0))
            cone.top_radius = 0.0
            cone.bottom_radius = 0.20
            cone.height = 0.34
            _add_mesh(root, cone, violet, Vector3(0.0, 0.55, 0.0))
            var brim := CylinderMesh.new()
            brim.top_radius = 0.30
            brim.bottom_radius = 0.30
            brim.height = 0.04
            _add_mesh(root, brim, violet, Vector3(0.0, 0.40, 0.0))
        &"gato_negro":
            sphere.radius = 0.22
            sphere.height = 0.38
            _add_mesh(root, sphere, body_mat, Vector3(0.0, 0.22, 0.0))
            var head := SphereMesh.new()
            head.radius = 0.15
            head.height = 0.26
            _add_mesh(root, head, body_mat, Vector3(0.0, 0.42, 0.10))
            cone.top_radius = 0.0
            cone.bottom_radius = 0.07
            cone.height = 0.14
            _add_mesh(root, cone, body_mat, Vector3(-0.08, 0.56, 0.10))
            _add_mesh(root, cone, body_mat, Vector3(0.08, 0.56, 0.10))
            _add_mesh(root, eye, cream, Vector3(-0.06, 0.44, 0.23))
            _add_mesh(root, eye, cream, Vector3(0.06, 0.44, 0.23))
        _:
            sphere.radius = 0.21
            sphere.height = 0.38
            _add_mesh(root, sphere, body_mat, Vector3(0.0, 0.22, 0.0))
            var ear := CylinderMesh.new()
            ear.top_radius = 0.05
            ear.bottom_radius = 0.06
            ear.height = 0.34
            _add_mesh(root, ear, body_mat, Vector3(-0.09, 0.54, 0.02))
            _add_mesh(root, ear, body_mat, Vector3(0.09, 0.54, 0.02))
    return root

func _on_piece_moved(piece_id: int, _to_index: int, _path: String) -> void:
    if _pieces.has(piece_id) and Game.active_match != null:
        var node: Node3D = _pieces[piece_id]
        var dest := world_position_for(Game.active_match.state.piece_by_id(piece_id))
        var heading := Vector3(dest.x - node.position.x, 0.0, dest.z - node.position.z)
        if heading.length() > 0.05:
            _focus_dir = heading.normalized()
        _focus_id = piece_id
        _last_moved_id = piece_id
        _focus_target = dest
    _sync_pieces(true)
    if _cam_mode == CamMode.FOLLOW:
        _update_follow(true)

func _on_turn_changed(_player_index: int, _turn_number: int) -> void:
    _sync_pieces(false)
    if _cam_mode == CamMode.FOLLOW:
        _pick_focus()
        _update_follow(true)

func _reduced_motion() -> bool:
    return Game.fast_mode or bool(Settings.get_setting("reduce_motion"))

func world_position_for(piece) -> Vector3:
    ## Piece anchor in world space (also used by the screen-space pick).
    if Game.active_match == null or Game.layout == null:
        return Vector3.ZERO
    var lay: BoardLayout = Game.layout
    var rules: MatchRules = Game.active_match.rules
    var p := world_of(lay.position_for(piece))
    if piece.in_pen():
        p.y = PLATFORM_TOP + 0.03
    elif piece.in_goal():
        # finished pieces cluster on the lane's goal tile (2x2 spread)
        p = world_of(lay.column_position(piece.owner, rules.column_length - 1))
        p.x += (float(piece.slot % 2) - 0.5) * 0.30
        p.z += (float(piece.slot / 2) - 0.5) * 0.30
        p.y = TILE_TOP
    else:
        p.y = TILE_TOP
    return p

func _sync_pieces(animate: bool) -> void:
    if Game.active_match == null:
        return
    for pl in Game.active_match.state.players:
        for piece in pl.pieces:
            var node: Node3D = _pieces.get(piece.id, null)
            if node == null:
                continue
            var target := world_position_for(piece)
            if animate and not _reduced_motion() and node.position.distance_to(target) > 0.05:
                _hop(node, piece.id, target)
            else:
                _kill_hop(piece.id)
                node.position = target
    _refresh_hints()

func _kill_hop(piece_id: int) -> void:
    var tw: Tween = _tweens.get(piece_id, null)
    if tw != null and tw.is_valid():
        tw.kill()
    _tweens.erase(piece_id)

func _hop(node: Node3D, piece_id: int, target: Vector3) -> void:
    _kill_hop(piece_id)
    var from := node.position
    var mid := (from + target) * 0.5
    mid.y = maxf(from.y, target.y) + JUMP_HEIGHT
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(node, "position:x", mid.x, JUMP_TIME * 0.5)
    tw.tween_property(node, "position:z", mid.z, JUMP_TIME * 0.5)
    tw.tween_property(node, "position:y", mid.y, JUMP_TIME * 0.5)
    tw.chain().set_parallel(true)
    tw.tween_property(node, "position:x", target.x, JUMP_TIME * 0.5)
    tw.tween_property(node, "position:z", target.z, JUMP_TIME * 0.5)
    tw.tween_property(node, "position:y", target.y, JUMP_TIME * 0.5)
    tw.chain().finished.connect(func(): _tweens.erase(piece_id))
    _tweens[piece_id] = tw

# ---------------------------------------------------------------- hints ----

func _refresh_hints() -> void:
    for h in _hints:
        if is_instance_valid(h):
            h.queue_free()
    _hints.clear()
    if Game.active_match == null or Game.active_match.state.over:
        return
    if Game.machine.current != TurnMachine.WAITING_FOR_PIECE_SELECTION:
        return
    if not Game.is_human_turn():
        return
    var rules: MatchRules = Game.active_match.rules
    var lay: BoardLayout = Game.layout
    for m in Game.active_match.legal_moves():
        var piece: PieceState = Game.active_match.state.piece_by_id(m.piece_id)
        if piece == null:
            continue
        var ring := MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.26
        tm.outer_radius = 0.36
        ring.mesh = tm
        ring.material_override = _emissive(ViewPalette.HIGHLIGHT, 2.0)
        ring.position = world_position_for(piece) + Vector3(0.0, -0.14, 0.0)
        _board_root.add_child(ring)
        _hints.append(ring)

        var dest := Vector3.ZERO
        if m.to_progress < rules.home_steps:
            dest = world_of(lay.ring_position(rules.start_index(piece.owner) + m.to_progress))
        elif m.to_progress < rules.total_route_steps():
            dest = world_of(lay.column_position(piece.owner, m.to_progress - rules.home_steps))
        else:
            dest = world_of(lay.column_position(piece.owner, rules.column_length - 1))
        var mark := MeshInstance3D.new()
        var dm := CylinderMesh.new()
        dm.top_radius = 0.16
        dm.bottom_radius = 0.16
        dm.height = 0.03
        mark.mesh = dm
        mark.material_override = _emissive(ViewPalette.HIGHLIGHT, 2.4)
        mark.position = dest + Vector3(0.0, TILE_TOP + 0.06, 0.0)
        _board_root.add_child(mark)
        _hints.append(mark)

func _emissive(col: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.emission_enabled = true
    m.emission = col
    m.emission_energy_multiplier = energy
    m.roughness = 0.5
    return m

# ------------------------------------------------------------------ die ----

func _build_die() -> void:
    _die = Node3D.new()
    _die.position = Vector3(0.0, 2.2, 7.4)
    _die.rotation_degrees = Vector3(-18.0, 32.0, 0.0)
    add_child(_die)
    _die_inner = Node3D.new()
    _die.add_child(_die_inner)

    var body := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.86, 0.86, 0.86)
    body.mesh = bm
    body.material_override = _faction_mat(ViewPalette.TEXT_CREAM, 0.55)
    _die_inner.add_child(body)

    var faces := {
        1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.RIGHT, 5: Vector3.LEFT,
        3: Vector3.BACK, 4: Vector3.FORWARD,
    }
    var pip := CylinderMesh.new()
    pip.top_radius = 0.07
    pip.bottom_radius = 0.07
    pip.height = 0.03
    var pip_mat := _faction_mat(ViewPalette.PIECE_LABEL_INK, 0.6)
    for value in faces:
        var n: Vector3 = faces[value]
        var up: Vector3 = Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
        var x_axis := up.cross(n).normalized()
        var y_axis := n.cross(x_axis).normalized()
        for off in _pip_offsets(value):
            var m := MeshInstance3D.new()
            m.mesh = pip
            m.material_override = pip_mat
            m.position = n * 0.44 + x_axis * (off.x * 0.24) + y_axis * (off.y * 0.24)
            var b := Basis()
            b.z = n
            b.x = x_axis
            b.y = y_axis
            m.transform.basis = b
            _die_inner.add_child(m)
    _show_die_value(1)

func _pip_offsets(value: int) -> Array:
    match value:
        1: return [Vector2(0, 0)]
        2: return [Vector2(-1, -1), Vector2(1, 1)]
        3: return [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)]
        4: return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
        5: return [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]
        _: return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]

func _value_basis(value: int) -> Basis:
    ## Rotation that brings the rolled face to the top.
    match value:
        2: return Basis.from_euler(Vector3(0, 0, deg_to_rad(90)))
        3: return Basis.from_euler(Vector3(deg_to_rad(-90), 0, 0))
        4: return Basis.from_euler(Vector3(deg_to_rad(90), 0, 0))
        5: return Basis.from_euler(Vector3(0, 0, deg_to_rad(-90)))
        6: return Basis.from_euler(Vector3(deg_to_rad(180), 0, 0))
        _: return Basis.from_euler(Vector3.ZERO)

func _show_die_value(value: int) -> void:
    if _die_inner == null:
        return
    _die_inner.rotation = _value_basis(value).get_euler()

func _on_dice_rolled(_p: int, value: int) -> void:
    if _die_inner == null:
        return
    if _die_tween != null and _die_tween.is_valid():
        _die_tween.kill()
    if _reduced_motion():
        _show_die_value(value)
        return
    _die_tween = create_tween()
    _die_tween.tween_property(_die_inner, "rotation",
        Vector3(TAU * 2.0, TAU * 1.5, TAU), 0.45) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _die_tween.tween_property(_die_inner, "rotation",
        _value_basis(value).get_euler(), 0.25) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ cam ----

func _board_points() -> Array:
    var pts: Array = []
    if Game.active_match != null and Game.layout != null:
        var lay: BoardLayout = Game.layout
        var rules: MatchRules = Game.active_match.rules
        for i in rules.ring_size:
            pts.append(world_of(lay.ring_position(i)))
        for p in 4:
            for i in rules.column_length:
                pts.append(world_of(lay.column_position(p, i)))
            for s in rules.pieces_per_player:
                pts.append(world_of(lay.pen_position(p, s)))
            var c := _pen_center(p, lay, rules)
            for dx in [-1.38, 1.38]:
                for dz in [-1.38, 1.38]:
                    pts.append(c + Vector3(dx, 0, dz))
    # fixed props (the mansion): include their world AABB so nothing is cropped
    for node in _scenery:
        if is_instance_valid(node):
            var ab := _subtree_world_aabb(node)
            for i in 8:
                pts.append(ab.get_endpoint(i))
    return pts

func _mesh_instances(root: Node) -> Array:
    var out: Array = []
    if root is MeshInstance3D:
        out.append(root)
    for c in root.get_children():
        out.append_array(_mesh_instances(c))
    return out

func _subtree_world_aabb(root: Node3D) -> AABB:
    var out := AABB()
    var first := true
    for mi in _mesh_instances(root):
        var a: AABB = (mi as MeshInstance3D).get_aabb()
        for i in 8:
            var w: Vector3 = (mi as MeshInstance3D).global_transform * a.get_endpoint(i)
            if first:
                out = AABB(w, Vector3.ZERO)
                first = false
            else:
                out = out.expand(w)
    return out

func _hud_free() -> float:
    ## Fraction of the viewport width the board may use: everything left of the
    ## HUD side panel, MEASURED from the panel itself so the board never slides
    ## under it at any window size or aspect.
    var vp := get_viewport().get_visible_rect().size
    if vp.x <= 0.0:
        return HUD_FREE_FALLBACK
    var panel := get_parent().get_node_or_null("CanvasLayer/Hud/SidePanel") as Control
    if panel == null or panel.size.x <= 0.0:
        return HUD_FREE_FALLBACK
    return clampf(1.0 - (panel.size.x + 30.0) / vp.x, 0.45, 0.95)

func _fit_camera() -> void:
    ## Ortho `size` is the FULL vertical extent. Fit the TRUE bounding box in
    ## camera space (min/max, never |max|): the scenery sits far off-centre, so a
    ## symmetric fit wasted most of the frame and shrank the board. Then centre
    ## the box inside the HUD-free area with a pure translation (re-aiming with
    ## look_at would put the box back on the screen centre and cancel the shift).
    if _cam == null:
        return
    var base := Vector3(CAM_DIST, CAM_DIST, CAM_DIST)
    _cam.position = base
    _cam.look_at(Vector3.ZERO, Vector3.UP)
    var basis := _cam.transform.basis
    var right := basis.x
    var up := basis.y
    var min_h := 1e9
    var max_h := -1e9
    var min_v := 1e9
    var max_v := -1e9
    for p in _board_points():
        var v: Vector3 = p
        var h := v.dot(right)
        var u := v.dot(up)
        min_h = minf(min_h, h)
        max_h = maxf(max_h, h)
        min_v = minf(min_v, u)
        max_v = maxf(max_v, u)
    if min_h > max_h:
        return
    var span_h := max_h - min_h
    var span_v := max_v - min_v
    var c_h := (min_h + max_h) * 0.5
    var c_v := (min_v + max_v) * 0.5
    var vp := get_viewport().get_visible_rect().size
    var aspect := 16.0 / 9.0
    if vp.x > 0.0 and vp.y > 0.0:
        aspect = float(vp.x) / float(vp.y)
    var free := _hud_free()
    _cam.size = maxf(span_v * 1.10, span_h * 1.06 / (free * aspect))
    var shift_h := (0.5 - free * 0.5) * _cam.size * aspect + c_h
    _cam.position = base + right * shift_h + up * c_v

# ----------------------------------------------------------------- pick ----

func pick_piece_at(screen_pos: Vector2) -> int:
    ## Screen-space projection pick: nearest projected piece anchor wins.
    ## Uses whichever camera is live, so first person is clickable too.
    var cam := _active_camera()
    if Game.active_match == null or Game.layout == null or cam == null:
        return -1
    var best_id := -1
    var best_d := CLICK_RADIUS
    for pl in Game.active_match.state.players:
        for piece in pl.pieces:
            if piece.in_pen() or piece.in_goal():
                continue
            var anchor := world_position_for(piece)
            if cam.is_position_behind(anchor):
                continue
            var s: Vector2 = cam.unproject_position(anchor)
            var d := s.distance_to(screen_pos)
            if d <= best_d:
                best_d = d
                best_id = piece.id
    return best_id
