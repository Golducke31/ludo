class_name BoardLayout
extends RefCounted
## Pure numeric layout of the board in design space (1920x1080). No nodes,
## no resources: headless tests assert every invariant.
##
## Geometry: 52 ring squares evenly spaced along the perimeter of a square,
## split into 4 arms of 13 (one edge each). Player p starts at the corner
## where edge p begins; the home-column entry sits two squares before that
## corner; home columns run perpendicular to their edge toward the center.

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const BOARD_CENTER := Vector2(960.0, 560.0)
const RING_HALF := 340.0        # half edge length of the square ring
const SQUARE_SIZE := 48.0       # visual square edge
const PEN_OUT := 70.0           # pen cluster offset outward from own corner
const PEN_SPACING := 52.0
const COLUMN_STEP := 52.0       # spacing between home column squares
const GOAL_SHIFT := 36.0        # perpendicular offset so the 4 goals don't overlap

var rules: MatchRules
var _ring: PackedVector2Array     # 52 positions
var _columns: Dictionary          # player_index -> PackedVector2Array (6)
var _goals: Dictionary            # player_index -> Vector2
var _pens: Dictionary             # player_index -> PackedVector2Array (4)
var _edge_of: PackedInt32Array    # ring index -> edge id (0 bottom, 1 left, 2 top, 3 right)

func _init(p_rules: MatchRules) -> void:
    rules = p_rules
    _build_ring()
    _build_paths()

func _perimeter() -> float:
    return RING_HALF * 8.0

func _step() -> float:
    return _perimeter() / rules.ring_size

func _point_at(s: float) -> Vector2:
    ## Perimeter parametrization. s=0 is the bottom-RIGHT corner; walk the
    ## bottom edge left, up the left edge, right across the top, down the
    ## right edge. Squares are half-step inset so adjacent arms never
    ## overlap at a corner.
    var R := RING_HALF
    var cx := BOARD_CENTER.x
    var cy := BOARD_CENTER.y
    s = wrapf(s, 0.0, _perimeter())
    if s < 2.0 * R:        # bottom edge, right -> left
        return Vector2(cx + R - s, cy + R)
    s -= 2.0 * R
    if s < 2.0 * R:        # left edge, bottom -> top
        return Vector2(cx - R, cy + R - s)
    s -= 2.0 * R
    if s < 2.0 * R:        # top edge, left -> right
        return Vector2(cx - R + s, cy - R)
    s -= 2.0 * R
    return Vector2(cx + R, cy - R + s)   # right edge, top -> bottom

func _build_ring() -> void:
    var step := _step()
    _ring.resize(rules.ring_size)
    _edge_of.resize(rules.ring_size)
    for i in rules.ring_size:
        var s := (float(i) + 0.5) * step
        _ring[i] = _point_at(s)
        var R2 := RING_HALF * 2.0
        var e := 0
        if s < R2:
            e = 0
        elif s < R2 * 2.0:
            e = 1
        elif s < R2 * 3.0:
            e = 2
        else:
            e = 3
        _edge_of[i] = e

func _inward_dir(idx: int) -> Vector2:
    ## Unit vector perpendicular to the ring edge, pointing at the center.
    match _edge_of[idx % rules.ring_size]:
        0: return Vector2(0, -1)
        1: return Vector2(1, 0)
        2: return Vector2(0, 1)
        _: return Vector2(-1, 0)

func _corner_dir(p: int) -> Vector2:
    ## Outward diagonal of the corner where player p's arm starts.
    match p:
        0: return Vector2(1, 1)
        1: return Vector2(-1, 1)
        2: return Vector2(-1, -1)
        _: return Vector2(1, -1)

func _build_paths() -> void:
    for p in 4:
        var entry := rules.home_entry_index(p)
        var inward := _inward_dir(entry)
        var corner_dir := _corner_dir(p)
        var perp := Vector2(-inward.y, inward.x)
        if perp.dot(corner_dir) < 0.0:
            perp = -perp
        var col := PackedVector2Array()
        col.resize(rules.column_length)
        for i in rules.column_length:
            col[i] = _ring[entry] + inward * (float(i) + 1.0) * COLUMN_STEP
        _columns[p] = col
        _goals[p] = col[rules.column_length - 1] + perp * GOAL_SHIFT
        _pens[p] = _build_pen(p)

func _build_pen(p: int) -> PackedVector2Array:
    var start_idx := rules.start_index(p)
    var cd := _corner_dir(p)
    var base := _ring[start_idx] + cd * PEN_OUT
    var ex := Vector2(signf(cd.x), 0.0)
    var ey := Vector2(0.0, signf(cd.y))
    var slots := PackedVector2Array()
    slots.resize(rules.pieces_per_player)
    for i in rules.pieces_per_player:
        slots[i] = base + ex * (float(i % 2) * PEN_SPACING) + ey * (float(i / 2) * PEN_SPACING)
    return slots

# ------------------------------------------------------------------ API ----

func ring_position(idx: int) -> Vector2:
    return _ring[idx % rules.ring_size]

func column_position(player_index: int, column_index: int) -> Vector2:
    return _columns[player_index][clampi(column_index, 0, rules.column_length - 1)]

func goal_position(player_index: int) -> Vector2:
    return _goals[player_index]

func pen_position(player_index: int, slot: int) -> Vector2:
    return _pens[player_index][clampi(slot, 0, rules.pieces_per_player - 1)]

func position_for(piece: PieceState) -> Vector2:
    if piece.in_pen():
        return pen_position(piece.owner, piece.slot)
    if piece.on_ring():
        return ring_position(piece.ring_index())
    if piece.in_column():
        return column_position(piece.owner, piece.column_index())
    return goal_position(piece.owner)

func all_ring() -> PackedVector2Array:
    return _ring

func ring_step_distance() -> float:
    return _step()

func in_design_bounds(p: Vector2, margin := 0.0) -> bool:
    return p.x >= margin and p.y >= margin and p.x <= DESIGN_SIZE.x - margin and p.y <= DESIGN_SIZE.y - margin
