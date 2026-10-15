class_name Move
extends RefCounted
## A single validated action. Pure data: GameMatch produces these from
## legal_moves() and executes them via apply_move().

const LOC_PEN := -1
const LOC_RING := 0
const LOC_COLUMN := 1
const LOC_GOAL := 2

var action := &"step"          # &"exit" | &"step"
var piece_id := -1
var player_index := -1
var from_progress := -1
var to_progress := -1
var steps := 0
var captures: Array[int] = []  # piece ids captured by this move
var triggered: Array[StringName] = []  # &"portal" | &"lantern"

func to_dict() -> Dictionary:
    return {
        "action": String(action),
        "piece_id": piece_id,
        "player_index": player_index,
        "from_progress": from_progress,
        "to_progress": to_progress,
        "steps": steps,
        "captures": captures.duplicate(),
        "triggered": triggered.duplicate(),
    }

func describe() -> String:
    return "%s piece=%d %d->%d" % [String(action), piece_id, from_progress, to_progress]

static func from_dict(d: Dictionary) -> Move:
    var m := Move.new()
    m.action = StringName(str(d.get("action", "step")))
    m.piece_id = int(d.get("piece_id", -1))
    m.player_index = int(d.get("player_index", -1))
    m.from_progress = int(d.get("from_progress", -1))
    m.to_progress = int(d.get("to_progress", -1))
    m.steps = int(d.get("steps", 0))
    m.captures.assign((d.get("captures", []) as Array).map(func(v): return int(v)))
    for t in (d.get("triggered", []) as Array):
        m.triggered.append(StringName(str(t)))
    return m
