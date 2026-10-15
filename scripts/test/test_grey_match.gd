extends Node
## M2 grey match test: plays REAL bot-vs-bot matches on the real scene graph
## (scenes/game/match_root.tscn: board_view, piece_view, dice_view, hud,
## overlays, input_controller) in fast_mode, headless. Views never touch the
## logic; this proves the full scene graph runs, terminates and is
## deterministic: every seed is played twice and both hashes must match.
##
## Protocol: prints HCTESTS tokens so tools/run_tests.sh can gate on it.

const MATCHES_PER_SEED := 2      # same seed twice -> determinism proof
const SEEDS := [7000, 7001, 7002, 7003, 7004, 7005, 7006, 7007, 7008, 7009]

var _failures := 0
var _checks := 0

func _ready() -> void:
    await _run_all()
    print("HCTESTS:TOTAL checks=%d suites=%d failed_suites=%d" % [_checks, 1, 1 if _failures > 0 else 0])
    print("HCTESTS:%s" % ("FAIL" if _failures > 0 else "PASS"))

func _fail(msg: String) -> void:
    _failures += 1
    printerr("  FAIL grey_match: %s" % msg)

func _check(condition: bool, msg: String) -> void:
    _checks += 1
    if not condition:
        _fail(msg)

func _run_all() -> void:
    var t0 := Time.get_ticks_msec()
    Game.fast_mode = true
    var by_seed := {}
    var total := 0
    for seed in SEEDS:
        for rep in MATCHES_PER_SEED:
            var h := await _play_match(seed)
            total += 1
            if h < 0:
                _fail("match seed=%d rep=%d did not complete" % [seed, rep])
                continue
            if by_seed.has(seed):
                _check(by_seed[seed] == h, "seed=%d deterministic (first=%d now=%d)" % [seed, by_seed[seed], h])
            else:
                by_seed[seed] = h
    var dt := Time.get_ticks_msec() - t0
    _check(total == SEEDS.size() * MATCHES_PER_SEED, "all %d matches played" % total)
    print("HCTESTS:SUITE grey_match checks=%d failures=%d ms=%d" % [_checks, _failures, dt])
    print("  grey_match %d matches in %d ms (%.1f ms/match)" % [total, dt, float(dt) / float(maxi(1, total))])
    Game.fast_mode = false

func _play_match(seed: int) -> int:
    Game.configure({
        "players": _bot_setup(4),
        "rules_mode": "halloween" if seed % 2 == 0 else "classic",
        "seed": seed,
    })
    var root: Node = load("res://scenes/game/match_root.tscn").instantiate()
    add_child(root)
    # fast_mode resolves every bot turn synchronously inside begin_match()
    # (called from match_root._ready); one frame lets views queue their redraws.
    await get_tree().process_frame
    if Game.active_match == null:
        root.queue_free()
        return -1
    var over: bool = Game.active_match.state.over
    var hash: int = Game.active_match.state_hash()
    var turns: int = Game.active_match.state.turn_number
    var winner: int = Game.active_match.state.winner
    root.queue_free()
    await get_tree().process_frame
    _check(over, "seed=%d match reached the end (%d turns)" % [seed, turns])
    _check(winner >= 0, "seed=%d match has a winner" % seed)
    _check(turns <= GameMatch.TURN_CAP, "seed=%d respects the turn cap" % seed)
    return hash if over else -1

func _bot_setup(count: int) -> Array:
    var ids := ["gato_negro", "fantasma_bruja", "rey_calabaza", "conejo_espectral"]
    var diffs := ["normal", "easy", "hard", "normal"]
    var out := []
    for i in count:
        out.append({
            "faction_id": ids[i % ids.size()],
            "display_name": "Bot %d" % (i + 1),
            "is_bot": true,
            "bot_difficulty": diffs[i % diffs.size()],
        })
    return out
