extends Node2D
## Pooled VFX player (M3): spark where a piece lands, burst + poof when a
## capture is settled. Fixed pool of 24 Sprite2D nodes acquired/released by
## tweens; NO _process anywhere, nothing here can stall game logic. Effects
## are skipped in Game.fast_mode (headless tests) and when the reduce_motion
## setting is on, so the deterministic core is never disturbed by visuals.

const POOL := 24
const SPARK_PATH := "res://assets/sprites/vfx/spark.png"
const BURST_PATH := "res://assets/sprites/vfx/burst.png"
const POOF_PATH := "res://assets/sprites/vfx/poof.png"
const SPARK_SIZE := 56.0
const BURST_SIZE := 120.0
const POOF_SIZE := 70.0
const SHORT := 0.22
const LONG := 0.42

var _tex: Dictionary = {}          # "spark"/"burst"/"poof" -> Texture2D
var _pool: Array[Sprite2D] = []
var _busy: Array[bool] = []
var _last_mover_id := -1

func _ready() -> void:
    _tex["spark"] = load(SPARK_PATH) as Texture2D
    _tex["burst"] = load(BURST_PATH) as Texture2D
    _tex["poof"] = load(POOF_PATH) as Texture2D
    for i in POOL:
        var s := Sprite2D.new()
        s.visible = false
        add_child(s)
        _pool.append(s)
        _busy.append(false)
    EventBus.piece_moved.connect(_on_piece_moved)
    EventBus.pieces_captured.connect(_on_captured)
    EventBus.portal_triggered.connect(_on_portal)
    EventBus.piece_exited.connect(_on_exited)
    EventBus.match_abandoned.connect(_release_all)

func _reduced() -> bool:
    return Game.fast_mode or Settings.get_setting("reduce_motion")

func _on_piece_moved(piece_id: int, _to: int, _path: String) -> void:
    _last_mover_id = piece_id
    if _reduced():
        return
    var piece: PieceState = Game.active_match.state.piece_by_id(piece_id)
    if piece == null:
        return
    _play(&"spark", Game.layout.position_for(piece), SPARK_SIZE, SHORT)

func _on_captured(ids: Array, by_player: int) -> void:
    if _reduced() or Game.active_match == null:
        return
    # burst where the capturing piece stands (it just landed there)
    var capturer: PieceState = Game.active_match.state.piece_by_id(_last_mover_id)
    if capturer != null and capturer.owner == by_player and not capturer.in_pen():
        _play(&"burst", Game.layout.position_for(capturer), BURST_SIZE, LONG)
    # poof on each piece banished to its pen
    for id in ids:
        var piece: PieceState = Game.active_match.state.piece_by_id(int(id))
        if piece != null:
            _play(&"poof", Game.layout.position_for(piece), POOF_SIZE, LONG)

func _on_portal(piece_id: int) -> void:
    if _reduced() or Game.active_match == null:
        return
    var piece: PieceState = Game.active_match.state.piece_by_id(piece_id)
    if piece != null:
        _play(&"burst", Game.layout.position_for(piece), BURST_SIZE * 0.8, LONG)

func _on_exited(piece_id: int) -> void:
    if _reduced() or Game.active_match == null:
        return
    var piece: PieceState = Game.active_match.state.piece_by_id(piece_id)
    if piece != null:
        _play(&"spark", Game.layout.position_for(piece), SPARK_SIZE * 1.4, LONG)

func _play(kind: StringName, pos: Vector2, size: float, dur: float) -> void:
    var tex: Texture2D = _tex.get(String(kind), null)
    if tex == null:
        return
    var idx := -1
    for i in _busy.size():
        if not _busy[i]:
            idx = i
            break
    if idx < 0:
        return          # pool exhausted: drop, never queue
    _busy[idx] = true
    var s := _pool[idx]
    s.texture = tex
    s.position = pos
    s.scale = Vector2(size, size) / tex.get_size()
    s.modulate = Color(1, 1, 1, 1)
    s.visible = true
    var t := create_tween()
    t.tween_property(s, "scale", s.scale * 1.35, dur)
    t.parallel().tween_property(s, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
    t.tween_callback(_release.bind(s, idx))

func _release(s: Sprite2D, idx: int) -> void:
    s.visible = false
    if idx >= 0 and idx < _busy.size():
        _busy[idx] = false

func _release_all() -> void:
    for i in _pool.size():
        _release(_pool[i], i)
    _last_mover_id = -1
