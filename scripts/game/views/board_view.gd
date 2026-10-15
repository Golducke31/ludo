extends Node2D
## Board drawn from Game.layout (pure core) with the pack-matching painted
## stone tiles: a near-white tile multiplied by the ViewPalette color keeps
## the exact color semantics the headless suites assert, while the surface
## gains mortar / bevel / grain. Background, pads, altar, fog and corner
## decor come from arena_2d.gd (the painted layer pack). Never uses _process:
## it redraws on Game signals so logic can never wait on the view.
## Pieces and move highlights live in piece_view.gd; VFX in vfx_view.gd.

const SQ := BoardLayout.SQUARE_SIZE
const TILE_A := "res://assets/sprites/board/tile_stone_a.png"
const TILE_B := "res://assets/sprites/board/tile_stone_b.png"
const CANVAS := Vector2(1920.0, 1080.0)

var _tiles: Array = []

func _ready() -> void:
    for path in [TILE_A, TILE_B]:
        var tex := load(path) as Texture2D
        if tex != null:
            _tiles.append(tex)
    _apply_accessibility()
    EventBus.match_started.connect(func(_c, _m): queue_redraw())
    EventBus.match_abandoned.connect(queue_redraw)
    Game.state_changed.connect(func(_s): queue_redraw())
    EventBus.settings_changed.connect(func(): _apply_accessibility(); queue_redraw())

func _apply_accessibility() -> void:
    ViewPalette.apply_accessibility(
        bool(Settings.get_setting("high_contrast")),
        bool(Settings.get_setting("colorblind_mode")))

func _sq_rect(c: Vector2) -> Rect2:
    return Rect2(c - Vector2(SQ, SQ) * 0.5, Vector2(SQ, SQ))

func _draw_tile(rect: Rect2, col: Color, variant: int) -> void:
    if _tiles.is_empty():
        draw_rect(rect, col)
        return
    var tex: Texture2D = _tiles[variant % _tiles.size()]
    draw_texture_rect(tex, rect, false, col)

func _draw() -> void:
    if Game.active_match == null or Game.layout == null:
        return
    var lay: BoardLayout = Game.layout
    var rules: MatchRules = Game.active_match.rules
    # ring squares (alternating tile variants, painted stone under the tint)
    for i in rules.ring_size:
        var c := lay.ring_position(i)
        var rect := _sq_rect(c)
        var safe: bool = Game.active_match.geo.is_safe(i)
        _draw_tile(rect, ViewPalette.SQUARE_SAFE if safe else ViewPalette.SQUARE_BASE, i)
        draw_rect(rect, ViewPalette.SQUARE_GRID, false, 1.0)
        # special square markers (Halloween mode)
        var special: StringName = Game.active_match.geo.special_at(i)
        if special != &"":
            var dot_col: Color = ViewPalette.TEXT_VIOLET
            var label := "P"
            if special == &"lantern":
                label = "L"
                dot_col = ViewPalette.ACCENT_ORANGE
            elif special == &"capture":
                label = "C"
                dot_col = ViewPalette.SPECTRAL_GREEN
            draw_circle(c + Vector2(0, 12), 4.0, dot_col)
            draw_string(ThemeDB.fallback_font, c + Vector2(-4, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ViewPalette.TEXT_CREAM)
    # start markers (faction tinted)
    for p in 4:
        var sc := lay.ring_position(rules.start_index(p))
        var tint: Color = ViewPalette.tint(Game.active_match.state.players[p].faction_id)
        _draw_tile(_sq_rect(sc), Color(tint, 0.55), 0)
        draw_string(ThemeDB.fallback_font, sc + Vector2(-4, 5), str(p + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ViewPalette.piece_label_color(Game.active_match.state.players[p].faction_id))
    # home columns + goals
    for p in 4:
        for i in rules.column_length:
            var cc := lay.column_position(p, i)
            var rect := _sq_rect(cc)
            _draw_tile(rect, ViewPalette.SQUARE_COLUMN, i + 1)
            draw_rect(rect, ViewPalette.SQUARE_GRID, false, 1.0)
        var g := lay.goal_position(p)
        var gt: Color = ViewPalette.tint(Game.active_match.state.players[p].faction_id)
        draw_circle(g, SQ * 0.45, Color(gt, 0.6))
        draw_arc(g, SQ * 0.45, 0.0, TAU, 24, ViewPalette.outline(Game.active_match.state.players[p].faction_id), 2.0)
    # pens: dark slots over the painted pads
    for p in 4:
        var pt: Color = ViewPalette.tint(Game.active_match.state.players[p].faction_id)
        for s in rules.pieces_per_player:
            var pc := lay.pen_position(p, s)
            var rect := _sq_rect(pc)
            _draw_tile(rect, ViewPalette.PEN_FILL, s)
            draw_rect(rect, Color(pt, 0.5), false, 1.0)
