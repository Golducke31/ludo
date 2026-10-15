class_name MatchRules
extends RefCounted
## All tunable rule numbers live here. Nothing else in the codebase may contain
## a magic gameplay number. Serializes to a JSON-safe dictionary (save/load,
## replay, tests).

const RULES_VERSION := 1

# --- board ---------------------------------------------------------------
var ring_size := 52          # squares on the shared ring
var arm_length := 13         # squares per player arm (ring_size / 4)
var pieces_per_player := 4

# --- entry / safety ------------------------------------------------------
var exit_dice_value := 6     # exact dice value that releases a piece from the pen
var safe_offsets: Array[int] = [0, 7]   # per-arm safe offsets (start + arm center)

# --- home path -----------------------------------------------------------
var home_steps := 50         # ring steps from start to home-column entry
var column_length := 6       # home column squares before the refuge

# --- turns ---------------------------------------------------------------
var extra_turn_cap := 3      # max consecutive extra turns earned by rolling exit value
var third_six_penalty := true

# --- captures ------------------------------------------------------------
var hard_blocks := false     # v1: no hard blocking

# --- Halloween specials (v1 defaults) ------------------------------------
var halloween_enabled := true
var candy_heap_enabled := false      # Candy Heap exists but is OFF by default
var portal_index := 4                # Fog Portal: teleport +portal_bonus on the ring
var portal_bonus := 6
var lantern_index := 30              # Pumpkin Lantern: +lantern_bonus or send rival back
var lantern_bonus := 2
var lantern_send_back := 6
var candy_heap_index := 47           # extra turn, max 1 per player (off by default)

func total_route_steps() -> int:
    return home_steps + column_length

func start_index(player_index: int) -> int:
    return player_index * arm_length

func home_entry_index(player_index: int) -> int:
    return (start_index(player_index) + home_steps) % ring_size

func is_safe_index(idx: int) -> bool:
    var offset := idx % arm_length
    for s in safe_offsets:
        if offset == s:
            return true
    return false

func safe_squares() -> Array[int]:
    var out: Array[int] = []
    for arm in 4:
        for s in safe_offsets:
            out.append(arm * arm_length + s)
    out.sort()
    return out

func to_dict() -> Dictionary:
    return {
        "rules_version": RULES_VERSION,
        "ring_size": ring_size,
        "arm_length": arm_length,
        "pieces_per_player": pieces_per_player,
        "exit_dice_value": exit_dice_value,
        "safe_offsets": safe_offsets.duplicate(),
        "home_steps": home_steps,
        "column_length": column_length,
        "extra_turn_cap": extra_turn_cap,
        "third_six_penalty": third_six_penalty,
        "hard_blocks": hard_blocks,
        "halloween_enabled": halloween_enabled,
        "candy_heap_enabled": candy_heap_enabled,
        "portal_index": portal_index,
        "portal_bonus": portal_bonus,
        "lantern_index": lantern_index,
        "lantern_bonus": lantern_bonus,
        "lantern_send_back": lantern_send_back,
        "candy_heap_index": candy_heap_index,
    }

func from_dict(d: Dictionary) -> Error:
    var required := [
        "ring_size", "arm_length", "pieces_per_player", "exit_dice_value",
        "home_steps", "column_length", "extra_turn_cap",
    ]
    for k in required:
        if not d.has(k):
            return ERR_INVALID_PARAMETER
    ring_size = int(d["ring_size"])
    arm_length = int(d["arm_length"])
    pieces_per_player = int(d["pieces_per_player"])
    exit_dice_value = int(d["exit_dice_value"])
    home_steps = int(d["home_steps"])
    column_length = int(d["column_length"])
    extra_turn_cap = int(d["extra_turn_cap"])
    if d.has("safe_offsets"):
        safe_offsets.assign((d["safe_offsets"] as Array).map(func(v): return int(v)))
    third_six_penalty = bool(d.get("third_six_penalty", third_six_penalty))
    hard_blocks = bool(d.get("hard_blocks", hard_blocks))
    halloween_enabled = bool(d.get("halloween_enabled", halloween_enabled))
    candy_heap_enabled = bool(d.get("candy_heap_enabled", candy_heap_enabled))
    portal_index = int(d.get("portal_index", portal_index))
    portal_bonus = int(d.get("portal_bonus", portal_bonus))
    lantern_index = int(d.get("lantern_index", lantern_index))
    lantern_bonus = int(d.get("lantern_bonus", lantern_bonus))
    lantern_send_back = int(d.get("lantern_send_back", lantern_send_back))
    candy_heap_index = int(d.get("candy_heap_index", candy_heap_index))
    if ring_size != arm_length * 4:
        return ERR_INVALID_PARAMETER
    return OK

func signature() -> String:
    ## Stable identity of the rule set (used by state_hash so replays and saves
    ## can never silently mix rule variants).
    var parts := PackedStringArray()
    for k in to_dict().keys():
        parts.append("%s=%s" % [k, str(to_dict()[k])])
    return ",".join(parts)

static func create_default() -> MatchRules:
    ## Funny default: Halloween specials on, Candy Heap off.
    var r := MatchRules.new()
    return r

static func create_classic() -> MatchRules:
    var r := MatchRules.new()
    r.halloween_enabled = false
    return r
