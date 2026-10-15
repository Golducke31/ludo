class_name MatchState
extends RefCounted
## Full serializable state of one match. GameMatch is the only mutator.
## to_dict()/from_dict() are JSON-safe (save, replay, net prep).

var rules: MatchRules
var players: Array[PlayerState] = []
var current := 0
var turn_number := 0
var dice_value := 0             # 0 = awaiting roll this turn
var pending_bonus: Dictionary = {}   # {"type": &"lantern", "piece_id": id} or {}
var winner := -1
var ranking: Array[int] = []    # player indices in finishing order
var over := false
var seed_value := 0
var started_unix := 0

func player(index: int) -> PlayerState:
    return players[index]

func piece_by_id(piece_id: int) -> PieceState:
    for p in players:
        for pc in p.pieces:
            if pc.id == piece_id:
                return pc
    return null

func awaiting_roll() -> bool:
    return not over and dice_value <= 0 and pending_bonus.is_empty()

func to_dict() -> Dictionary:
    return {
        "rules": rules.to_dict(),
        "players": players.map(func(p): return p.to_dict()),
        "current": current,
        "turn_number": turn_number,
        "dice_value": dice_value,
        "pending_bonus": pending_bonus.duplicate(),
        "winner": winner,
        "ranking": ranking.duplicate(),
        "over": over,
        "seed_value": seed_value,
        "started_unix": started_unix,
    }

static func from_dict(d: Dictionary) -> MatchState:
    var r := MatchRules.new()
    var err := r.from_dict(d["rules"])
    if err != OK:
        push_error("MatchState.from_dict: bad rules (%d)" % err)
    var s := MatchState.new()
    s.rules = r
    for pd in (d.get("players", []) as Array):
        s.players.append(PlayerState.from_dict(pd, r))
    s.current = int(d.get("current", 0))
    s.turn_number = int(d.get("turn_number", 0))
    s.dice_value = int(d.get("dice_value", 0))
    s.pending_bonus = (d.get("pending_bonus", {}) as Dictionary).duplicate()
    s.winner = int(d.get("winner", -1))
    s.ranking.assign((d.get("ranking", []) as Array).map(func(v): return int(v)))
    s.over = bool(d.get("over", false))
    s.seed_value = int(d.get("seed_value", 0))
    s.started_unix = int(d.get("started_unix", 0))
    return s
