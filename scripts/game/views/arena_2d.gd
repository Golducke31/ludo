extends Node2D
## 2.5D arena backdrop: the painted layer pack (Desktop/arena -> assets/sprites/arena)
## stacked per its README. Every layer is centered on BoardLayout.BOARD_CENTER
## at 0.75 scale (2560x1440 art -> 1920x1080 design canvas); the fog layer is
## duplicated behind the board (low alpha) and in front (higher alpha). The
## moon altar is scaled down to live inside the ring interior. The four player
## pads are sliced out of the zonas layer (they are composed around a circular
## ring) and re-placed centered on our square board's pen clusters.
## Static scene: Ludo never moves the camera, so there is no parallax here.
## Gameplay layers (BoardView/PieceView/DiceView/VfxView) draw above this node.

const PACK := "res://assets/sprites/arena/"
const BOARD_CENTER := Vector2(960.0, 560.0)
const PACK_SCALE := 0.75          # 2560x1440 art -> 1920x1080 design canvas
const ALTAR_SCALE := 0.30         # moon altar, shrunk into the ring interior
const PAD_SCALE := 0.50           # sliced pads onto the pen clusters
# corner of each player's pen cluster -> pad art colour at that corner
const PAD_BY_PLAYER := {
    0: "pads/pad_red.png",        # bottom-right corner
    1: "pads/pad_green.png",      # bottom-left corner
    2: "pads/pad_violet.png",     # top-left corner
    3: "pads/pad_orange.png",     # top-right corner
}

var _pads: Array = []

func _ready() -> void:
    _add_layer("arena_capas_01_fondo.png", -70, PACK_SCALE, 1.0)
    _add_layer("arena_capas_07_luces_niebla.png", -60, PACK_SCALE, 0.30)
    _add_layer("arena_capas_02_base_tablero.png", -10, PACK_SCALE, 1.0)
    _add_layer("arena_capas_05_centro_luna.png", -6, ALTAR_SCALE, 1.0)
    _add_layer("arena_capas_06_decoracion.png", -4, PACK_SCALE, 1.0)
    # front fog: play-zone-cleared variant so pads/pieces stay unwashed
    _add_layer("luces_niebla_play.png", 90, PACK_SCALE, 0.45)
    EventBus.match_started.connect(func(_c, _m): _build_pads())
    EventBus.match_abandoned.connect(_clear_pads)

func _add_layer(file: String, z: int, scale: float, alpha: float) -> void:
    var tex := load(PACK + file) as Texture2D
    if tex == null:
        return
    var spr := Sprite2D.new()
    spr.texture = tex
    spr.centered = true
    spr.position = BOARD_CENTER
    spr.scale = Vector2(scale, scale)
    spr.z_index = z
    spr.modulate.a = alpha
    add_child(spr)

func _build_pads() -> void:
    _clear_pads()
    if Game.active_match == null or Game.layout == null:
        return
    var lay: BoardLayout = Game.layout
    var rules: MatchRules = Game.active_match.rules
    for p in 4:
        var center := Vector2.ZERO
        for s in rules.pieces_per_player:
            center += lay.pen_position(p, s)
        center /= float(rules.pieces_per_player)
        var tex := load(PACK + PAD_BY_PLAYER[p]) as Texture2D
        if tex == null:
            continue
        var spr := Sprite2D.new()
        spr.texture = tex
        spr.centered = true
        spr.position = center
        spr.scale = Vector2(PAD_SCALE, PAD_SCALE)
        spr.z_index = -8
        add_child(spr)
        _pads.append(spr)

func _clear_pads() -> void:
    for spr in _pads:
        spr.queue_free()
    _pads.clear()
