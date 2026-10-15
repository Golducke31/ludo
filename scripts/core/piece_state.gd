class_name PieceState
extends RefCounted
## A single piece. `progress` is the ONLY source of truth:
##   -1  = pen (guarida)
##   0..home_steps-1  = on the ring, ring_index = (start + progress) % ring_size
##   home_steps..home_steps+column_length-1 = in the home column
##   home_steps + column_length = goal (refuge)
## loc()/ring_index()/column_index() are derived views of progress.

var id := -1
var owner := 0
var slot := 0
var progress := -1

var _rules: MatchRules

func _init(p_rules: MatchRules, p_id: int, p_owner: int, p_slot: int) -> void:
    _rules = p_rules
    id = p_id
    owner = p_owner
    slot = p_slot
    progress = -1

func in_pen() -> bool:
    return progress < 0

func in_goal() -> bool:
    return progress >= _rules.total_route_steps()

func on_ring() -> bool:
    return progress >= 0 and progress < _rules.home_steps

func in_column() -> bool:
    return progress >= _rules.home_steps and progress < _rules.total_route_steps()

func loc() -> int:
    if in_pen():
        return Move.LOC_PEN
    if in_goal():
        return Move.LOC_GOAL
    if in_column():
        return Move.LOC_COLUMN
    return Move.LOC_RING

func ring_index() -> int:
    return (_rules.start_index(owner) + progress) % _rules.ring_size

func column_index() -> int:
    return progress - _rules.home_steps

func distance_to_goal() -> int:
    return _rules.total_route_steps() - progress

func to_dict() -> Dictionary:
    return {"id": id, "owner": owner, "slot": slot, "progress": progress}

static func from_dict(d: Dictionary, p_rules: MatchRules) -> PieceState:
    var p := PieceState.new(p_rules, int(d["id"]), int(d["owner"]), int(d["slot"]))
    p.progress = int(d["progress"])
    return p
