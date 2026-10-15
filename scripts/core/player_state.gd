class_name PlayerState
extends RefCounted
## One seat: identity, bot config and its pieces. No gameplay decisions here.

var player_index := 0
var faction_id := &"gato_negro"
var display_name := ""
var is_bot := true
var bot_difficulty := &"normal"
var pieces: Array[PieceState] = []
var extra_chain := 0          # consecutive extra turns earned by rolling exit value
var candy_used := false       # Candy Heap consumed (only if enabled)
var candy_extra_pending := false
var rank := 0                 # 1-based finishing rank, 0 = unfinished

func pieces_in_goal() -> int:
    var n := 0
    for p in pieces:
        if p.in_goal():
            n += 1
    return n

func pieces_in_pen() -> int:
    var n := 0
    for p in pieces:
        if p.in_pen():
            n += 1
    return n

func total_progress() -> int:
    var t := 0
    for p in pieces:
        t += maxi(0, p.progress)
    return t

func finished() -> bool:
    return pieces_in_goal() >= pieces.size()

func to_dict() -> Dictionary:
    return {
        "player_index": player_index,
        "faction_id": String(faction_id),
        "display_name": display_name,
        "is_bot": is_bot,
        "bot_difficulty": String(bot_difficulty),
        "extra_chain": extra_chain,
        "candy_used": candy_used,
        "candy_extra_pending": candy_extra_pending,
        "rank": rank,
        "pieces": pieces.map(func(p): return p.to_dict()),
    }

static func from_dict(d: Dictionary, p_rules: MatchRules) -> PlayerState:
    var p := PlayerState.new()
    p.player_index = int(d["player_index"])
    p.faction_id = StringName(str(d.get("faction_id", "gato_negro")))
    p.display_name = str(d.get("display_name", ""))
    p.is_bot = bool(d.get("is_bot", true))
    p.bot_difficulty = StringName(str(d.get("bot_difficulty", "normal")))
    p.extra_chain = int(d.get("extra_chain", 0))
    p.candy_used = bool(d.get("candy_used", false))
    p.candy_extra_pending = bool(d.get("candy_extra_pending", false))
    p.rank = int(d.get("rank", 0))
    for pd in (d.get("pieces", []) as Array):
        p.pieces.append(PieceState.from_dict(pd, p_rules))
    return p
