extends HCTestCase
## Simulated bot matches: every match must terminate, respect the turn cap and
## produce a consistent winner/ranking. Match count is env-overridable
## (HCTESTS_SIM_MATCHES) so the fast suite stays quick while the M5 benchmark
## scenario can run the full 1000.

func suite_name() -> String:
    return "bot_sim"

func _match_count() -> int:
    var env := OS.get_environment("HCTESTS_SIM_MATCHES")
    if env != "" and env.is_valid_int():
        return clampi(int(env), 1, 100000)
    return 100

func run() -> void:
    var total := _match_count()
    var diffs := ["easy", "normal", "hard"]
    var t0 := Time.get_ticks_msec()
    var failures := 0
    for i in total:
        if not _run_one(i, diffs):
            failures += 1
        if failures > 10:
            check(false, "too many sim failures; aborting batch")
            return
        if i % 50 == 0 and i > 0:
            print("  bot_sim %d/%d (%.0f ms)" % [i, total, float(Time.get_ticks_msec() - t0)])
    var dt := Time.get_ticks_msec() - t0
    check_eq(failures, 0, "no failed simulations")
    print("  bot_sim %d matches in %d ms (%.2f ms/match)" % [total, dt, float(dt) / float(maxi(1, total))])

func _run_one(i: int, diffs: Array) -> bool:
    var ok := true
    var count := 2 + (i % 3)
    var ids := ["gato_negro", "fantasma_bruja", "rey_calabaza", "conejo_espectral"]
    var setup := []
    for p in count:
        setup.append({
            "faction_id": ids[p],
            "display_name": "P%d" % (p + 1),
            "is_bot": true,
            "bot_difficulty": diffs[(i + p) % 3],
        })
    var rules := MatchRules.create_default() if i % 2 == 0 else MatchRules.create_classic()
    var gm := GameMatch.new(rules, setup, 6000 + i)
    var bots: Array[BotPlayer] = []
    for p in count:
        bots.append(BotPlayer.new(setup[p]["bot_difficulty"], 7000 + i * 17 + p))
    var turns := 0
    while not gm.state.over:
        turns += 1
        if turns > GameMatch.TURN_CAP + 5:
            check(false, "match %d exceeded turn cap" % i)
            return false
        var rr: Dictionary = gm.roll_dice()
        if not bool(rr.get("ok", false)):
            check(false, "match %d roll failed (%s)" % [i, str(rr.get("error", "?"))])
            return false
        if bool(rr.get("auto_pass", false)):
            continue
        var cur := gm.state.current
        var legal := gm.legal_moves()
        if legal.is_empty():
            check(false, "match %d: roll ok but no legal moves" % i)
            return false
        var mv: Variant = bots[cur].choose_move(gm, legal)
        if mv == null:
            check(false, "match %d: bot returned null with legal moves" % i)
            return false
        var ar: Dictionary = gm.apply_move(mv)
        if not bool(ar.get("ok", false)):
            check(false, "match %d: bot move rejected (%s)" % [i, str(ar.get("error", "?"))])
            return false
        if not gm.state.pending_bonus.is_empty():
            var choices := gm.bonus_choices()
            var choice: Variant = bots[cur].choose_bonus(gm, choices)
            if choice == null:
                choice = &"advance"
            var br: Dictionary = gm.resolve_bonus(choice)
            if not bool(br.get("ok", false)):
                check(false, "match %d: bonus rejected" % i)
                return false
    check(gm.state.over, "match %d finished" % i)
    check(gm.state.winner >= 0, "match %d has a winner" % i)
    if gm.state.winner >= 0:
        var w: PlayerState = gm.state.players[gm.state.winner]
        check(w.finished(), "match %d winner has 4 pieces in goal" % i)
    var ranking: Array = gm.state.ranking
    check_eq(ranking.size(), count, "match %d ranking size" % i)
    for r in range(ranking.size() - 1):
        var pa: PlayerState = gm.state.players[ranking[r]]
        var pb: PlayerState = gm.state.players[ranking[r + 1]]
        check(pa.pieces_in_goal() > pb.pieces_in_goal() or
              (pa.pieces_in_goal() == pb.pieces_in_goal() and pa.total_progress() >= pb.total_progress()),
              "match %d ranking order at %d" % [i, r])
    return ok and gm.state.over
