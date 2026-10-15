extends Node2D
## Renders every piece as an AnimatedSprite2D from the faction SpriteFrames
## (M3 assets). Positions come from Game.layout (pure core); the view never
## feeds anything back into logic (desync-proof). Legal-move highlights and
## destination hints stay in _draw() UNDER the sprites; a light pedestal keeps
## dark silhouettes (Conejo Espectral) readable on the dark board.
## M4: 0.18s jump on piece_moved (skipped with reduce_motion/fast_mode) and
## colorblind shape badges drawn around each piece.

const PIECE_VISUAL_SIZE := 46.0   # on-screen size in design px
const HIGHLIGHT_RADIUS := 26.0
const JUMP_TIME := 0.18
const JUMP_HEIGHT := 30.0
const FACTION_FRAME_PATHS := {
    &"gato_negro": "res://assets/sprites/factions/gato_negro/idle.tres",
    &"fantasma_bruja": "res://assets/sprites/factions/fantasma_bruja/idle.tres",
    &"rey_calabaza": "res://assets/sprites/factions/rey_calabaza/idle.tres",
    &"conejo_espectral": "res://assets/sprites/factions/conejo_espectral/idle.tres",
}

var _pieces: Dictionary = {}               # piece_id -> AnimatedSprite2D
var _frames: Dictionary = {}               # faction_id -> SpriteFrames
var _tweens: Dictionary = {}               # piece_id -> Tween (jump in flight)

func _ready() -> void:
    for id in FACTION_FRAME_PATHS:
        var res := load(FACTION_FRAME_PATHS[id]) as SpriteFrames
        if res != null:
            _frames[id] = res
    EventBus.match_started.connect(func(_c, _m): _build_pieces())
    EventBus.turn_changed.connect(func(_p, _t): _sync_pieces(false))
    EventBus.dice_rolled.connect(func(_p, _v): _sync_pieces(false))
    EventBus.piece_moved.connect(func(_id, _to, _path): _sync_pieces(true))
    EventBus.bonus_resolved.connect(func(_c): _sync_pieces(true))
    EventBus.pieces_captured.connect(func(_ids, _by): _sync_pieces(false))
    EventBus.match_finished.connect(func(_r): _sync_pieces(false))
    EventBus.match_abandoned.connect(func(): _clear_pieces())
    EventBus.settings_changed.connect(func(): _refresh_highlights())
    Game.state_changed.connect(func(_s): _refresh_highlights())

func _clear_pieces() -> void:
    for id in _tweens:
        var tw: Tween = _tweens[id]
        if tw != null and tw.is_valid():
            tw.kill()
    _tweens.clear()
    for id in _pieces:
        _pieces[id].queue_free()
    _pieces.clear()
    queue_redraw()

func _build_pieces() -> void:
    _clear_pieces()
    if Game.active_match == null:
        return
    for p in Game.active_match.state.players:
        var frames: SpriteFrames = _frames.get(p.faction_id, null)
        for piece in p.pieces:
            var spr := AnimatedSprite2D.new()
            if frames != null:
                spr.sprite_frames = frames
                var tex: Texture2D = frames.get_frame_texture(&"idle", 0)
                if tex != null:
                    var native: Vector2 = tex.get_size()
                    if native.x > 0.0 and native.y > 0.0:
                        spr.scale = Vector2(PIECE_VISUAL_SIZE, PIECE_VISUAL_SIZE) / native
                spr.play(&"idle")
            spr.position = _position_for(piece)
            add_child(spr)
            _pieces[piece.id] = spr
    _refresh_highlights()

func _position_for(piece: PieceState) -> Vector2:
    var pos: Vector2 = Game.layout.position_for(piece)
    if piece.in_goal():
        # small 2x2 cluster so the four refuge pieces don't fully overlap
        pos += Vector2((float(piece.slot % 2) - 0.5) * 14.0, (float(piece.slot / 2) - 0.5) * 14.0)
    return pos

func _reduced_motion() -> bool:
    return Game.fast_mode or bool(Settings.get_setting("reduce_motion"))

func _sync_pieces(animate: bool) -> void:
    if Game.active_match == null:
        return
    for p in Game.active_match.state.players:
        for piece in p.pieces:
            var spr: AnimatedSprite2D = _pieces.get(piece.id, null)
            if spr == null:
                continue
            var target := _position_for(piece)
            if animate and not _reduced_motion() and spr.position.distance_to(target) > 0.5:
                _jump(spr, piece.id, target)
            else:
                _kill_jump(piece.id)
                spr.position = target
    _refresh_highlights()

func _kill_jump(piece_id: int) -> void:
    var tw: Tween = _tweens.get(piece_id, null)
    if tw != null and tw.is_valid():
        tw.kill()
    _tweens.erase(piece_id)

func _jump(spr: AnimatedSprite2D, piece_id: int, target: Vector2) -> void:
    _kill_jump(piece_id)
    var from := spr.position
    var apex := minf(from.y, target.y) - JUMP_HEIGHT
    var tw := create_tween()
    tw.tween_property(spr, "position:x", target.x, JUMP_TIME).set_trans(Tween.TRANS_LINEAR)
    _tweens[piece_id] = tw
    var hop := create_tween()
    hop.tween_property(spr, "position:y", apex, JUMP_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    hop.tween_property(spr, "position:y", target.y, JUMP_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    hop.finished.connect(func(): _tweens.erase(piece_id))

func _refresh_highlights() -> void:
    queue_redraw()

func _draw() -> void:
    if Game.active_match == null or Game.layout == null:
        return
    var badges: bool = ViewPalette.colorblind_mode()
    # pedestals: soft light discs under every piece (contrast for dark sprites)
    for p in Game.active_match.state.players:
        for piece in p.pieces:
            var pos: Vector2 = _position_for(piece)
            draw_circle(pos, PIECE_VISUAL_SIZE * 0.42, ViewPalette.PEDESTAL)
            if badges:
                _draw_badge(pos, ViewPalette.badge_shape(p.faction_id))
    if Game.active_match.state.over:
        return
    if Game.machine.current != TurnMachine.WAITING_FOR_PIECE_SELECTION:
        return
    if not Game.is_human_turn():
        return
    var rules: MatchRules = Game.active_match.rules
    for m in Game.active_match.legal_moves():
        var piece: PieceState = Game.active_match.state.piece_by_id(m.piece_id)
        if piece == null:
            continue
        var hpos: Vector2 = _position_for(piece)
        draw_arc(hpos, HIGHLIGHT_RADIUS, 0.0, TAU, 28, ViewPalette.HIGHLIGHT, 3.0)
        # destination hint: small dot where the piece would land
        if m.to_progress >= 0 and m.to_progress < rules.home_steps:
            draw_circle(Game.layout.ring_position(rules.start_index(piece.owner) + m.to_progress), 5.0, Color(ViewPalette.HIGHLIGHT, 0.55))
        elif m.to_progress < rules.total_route_steps():
            draw_circle(Game.layout.column_position(piece.owner, m.to_progress - rules.home_steps), 5.0, Color(ViewPalette.HIGHLIGHT, 0.55))
        else:
            draw_circle(Game.layout.goal_position(piece.owner), 5.0, Color(ViewPalette.HIGHLIGHT, 0.55))

func _draw_badge(pos: Vector2, shape: StringName) -> void:
    # anti-color-only identity: every faction has one shape, always the same
    var r := PIECE_VISUAL_SIZE * 0.58
    var col := ViewPalette.TEXT_CREAM
    if shape == &"triangle":
        for k in 3:
            var a1 := -PI / 2.0 + float(k) * TAU / 3.0
            var a2 := -PI / 2.0 + float(k + 1) * TAU / 3.0
            draw_line(pos + Vector2(cos(a1), sin(a1)) * r, pos + Vector2(cos(a2), sin(a2)) * r, col, 2.0)
    elif shape == &"square":
        draw_rect(Rect2(pos - Vector2(r * 0.75, r * 0.75), Vector2(r * 1.5, r * 1.5)), col, false, 2.0)
    elif shape == &"diamond":
        draw_line(pos + Vector2(0, -r), pos + Vector2(r, 0), col, 2.0)
        draw_line(pos + Vector2(r, 0), pos + Vector2(0, r), col, 2.0)
        draw_line(pos + Vector2(0, r), pos + Vector2(-r, 0), col, 2.0)
        draw_line(pos + Vector2(-r, 0), pos + Vector2(0, -r), col, 2.0)
    else:
        draw_arc(pos, r, 0.0, TAU, 24, col, 2.0)
