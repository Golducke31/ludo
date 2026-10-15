class_name MatchFactory
extends RefCounted
## Test helpers: deterministic match construction and manual placement.

const FACTION_IDS: Array[StringName] = [&"gato_negro", &"fantasma_bruja", &"rey_calabaza", &"conejo_espectral"]

static func setup(count := 2, bots := true) -> Array:
    var s := []
    for i in count:
        s.append({
            "faction_id": String(FACTION_IDS[i % FACTION_IDS.size()]),
            "display_name": "P%d" % (i + 1),
            "is_bot": bots,
            "bot_difficulty": "normal",
        })
    return s

static func make(rules: MatchRules, count := 2, seed := 1, rolls: Array = []) -> GameMatch:
    return GameMatch.new(rules, setup(count), seed, rolls)

static func place(gm: GameMatch, player: int, slot: int, progress: int) -> void:
    gm.state.players[player].pieces[slot].progress = progress

static func set_dice(gm: GameMatch, value: int) -> void:
    gm.state.dice_value = value

static func move_for(gm: GameMatch, piece_id: int) -> Move:
    for m in gm.legal_moves():
        if m.piece_id == piece_id:
            return m
    return null

static func random_rolls(count: int, seed: int) -> Array:
    var rng := RngStream.new(seed)
    var out: Array = []
    for _i in count:
        out.append(rng.roll_d6())
    return out
