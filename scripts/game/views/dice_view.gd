extends Node2D
## Current die, drawn over the board center-top. M4: 0.5s face-cycling roll
## animation on dice_rolled - skipped entirely when reduce_motion is on or in
## Game.fast_mode (headless). Driven purely by signals + awaits: no _process.

const DIE_SIZE := 44.0
const ROLL_STEPS := 7
const ROLL_STEP_TIME := 0.5 / 7.0   # ~0.07s per face -> 0.5s total

var _face_override := 0     # >0 while the roll animation decides the face
var _rolling := false

func _ready() -> void:
    EventBus.dice_rolled.connect(_on_dice_rolled)
    EventBus.turn_changed.connect(func(_p, _t): queue_redraw())
    EventBus.match_started.connect(func(_c, _m): _reset(); queue_redraw())
    EventBus.match_abandoned.connect(func(): _reset(); queue_redraw())
    Game.state_changed.connect(func(_s): queue_redraw())
    EventBus.settings_changed.connect(queue_redraw)

func _reset() -> void:
    _rolling = false
    _face_override = 0

func _reduced_motion() -> bool:
    return Game.fast_mode or bool(Settings.get_setting("reduce_motion"))

func _on_dice_rolled(_p: int, _v: int) -> void:
    if _rolling or _reduced_motion():
        queue_redraw()
        return
    _roll_faces()

func _roll_faces() -> void:
    _rolling = true
    for i in ROLL_STEPS:
        _face_override = (i % 6) + 1
        queue_redraw()
        await get_tree().create_timer(ROLL_STEP_TIME).timeout
    _face_override = 0
    _rolling = false
    queue_redraw()

func _draw() -> void:
    if Game.active_match == null:
        return
    var center := Vector2(BoardLayout.BOARD_CENTER.x, BoardLayout.BOARD_CENTER.y - 250.0)
    var value: int = _face_override if _face_override > 0 else Game.active_match.state.dice_value
    var rect := Rect2(center - Vector2(DIE_SIZE, DIE_SIZE) * 0.5, Vector2(DIE_SIZE, DIE_SIZE))
    draw_rect(rect, ViewPalette.TEXT_CREAM)
    draw_rect(rect, ViewPalette.ACCENT_ORANGE, false, 2.0)
    if value > 0:
        _draw_pips(center, value)

func _draw_pips(center: Vector2, value: int) -> void:
    var o := DIE_SIZE * 0.24
    var r := 4.0
    var c := center
    match value:
        1:
            draw_circle(c, r, ViewPalette.PIECE_LABEL_INK)
        2:
            draw_circle(c + Vector2(-o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, o), r, ViewPalette.PIECE_LABEL_INK)
        3:
            draw_circle(c + Vector2(-o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c, r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, o), r, ViewPalette.PIECE_LABEL_INK)
        4:
            draw_circle(c + Vector2(-o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(-o, o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, o), r, ViewPalette.PIECE_LABEL_INK)
        5:
            draw_circle(c + Vector2(-o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c, r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(-o, o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, o), r, ViewPalette.PIECE_LABEL_INK)
        6:
            draw_circle(c + Vector2(-o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, -o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(-o, 0), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, 0), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(-o, o), r, ViewPalette.PIECE_LABEL_INK)
            draw_circle(c + Vector2(o, o), r, ViewPalette.PIECE_LABEL_INK)
