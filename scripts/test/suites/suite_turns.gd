extends HCTestCase

func suite_name() -> String:
    return "turns"

func run() -> void:
    _test_extra_turn_chain_and_penalty()
    _test_chain_resets_on_non_six()
    _test_no_legal_moves_passes()

func _test_extra_turn_chain_and_penalty() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1, [6, 6, 6, 2, 2, 2, 2])
    var rr := m.roll_dice()
    check_eq(int(rr["roll"]), 6, "first forced roll")
    check(not bool(rr.get("penalty", false)), "no penalty on first 6")
    m.apply_move(m.legal_moves()[0])
    check(bool(m.state.players[0].extra_chain), "chain advanced")
    check_eq(m.state.players[0].extra_chain, 1, "chain = 1")
    check_eq(m.state.current, 0, "extra turn keeps current player")
    rr = m.roll_dice()
    check_eq(int(rr["roll"]), 6, "second forced 6")
    m.apply_move(m.legal_moves()[0])
    check_eq(m.state.players[0].extra_chain, 2, "chain = 2")
    check_eq(m.state.current, 0, "still same player")
    rr = m.roll_dice()
    check_eq(int(rr["roll"]), 6, "third forced 6")
    check(bool(rr.get("penalty", false)), "third 6 triggers penalty")
    check(bool(rr.get("auto_pass", false)), "third 6 passes the turn")
    check_eq(m.state.current, 1, "turn moved to p1")
    check_eq(m.state.players[0].extra_chain, 0, "chain reset after penalty")

func _test_chain_resets_on_non_six() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1, [6, 3, 6, 2])
    m.roll_dice()
    m.apply_move(m.legal_moves()[0])   # exit, extra turn, chain 1
    check_eq(m.state.players[0].extra_chain, 1, "chain 1")
    var rr := m.roll_dice()
    check_eq(int(rr["roll"]), 3, "non-six roll")
    var legal := m.legal_moves()
    check(not legal.is_empty(), "piece on board can step with 3")
    var res := m.apply_move(legal[0])
    check(not bool(res["extra_turn"]), "non-six grants no extra turn")
    check_eq(m.state.current, 1, "turn passed")
    check_eq(m.state.players[0].extra_chain, 0, "chain reset on pass")

func _test_no_legal_moves_passes() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1, [2, 3, 4, 5])
    var rr := m.roll_dice()
    check_eq(int(rr["roll"]), 2, "roll 2 with empty pen")
    check(bool(rr.get("auto_pass", false)), "no legal moves -> auto pass")
    check(m.legal_moves().is_empty(), "indeed no legal moves")
    check_eq(m.state.current, 1, "passed to p1")
    rr = m.roll_dice()
    check(bool(rr.get("auto_pass", false)), "p1 also passes")
    check_eq(m.state.current, 0, "back to p0")
    check_eq(m.state.turn_number, 2, "turn counter advanced")
