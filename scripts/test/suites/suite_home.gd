extends HCTestCase

func suite_name() -> String:
    return "home"

func run() -> void:
    _test_exit_requires_six()
    _test_no_overshoot()
    _test_exact_goal()
    _test_column_entry()
    _test_win_ends_match()
    _test_distance_to_goal()

func _test_exit_requires_six() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.set_dice(m, 3)
    check(m.legal_moves().is_empty(), "no exit with 3")
    MatchFactory.set_dice(m, 5)
    check(m.legal_moves().is_empty(), "no exit with 5")
    MatchFactory.set_dice(m, 6)
    check_eq(m.legal_moves().size(), 4, "four exit moves with 6")

func _test_no_overshoot() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 55)   # column index 5
    MatchFactory.set_dice(m, 2)
    check(m.legal_moves().is_empty(), "cannot overshoot the goal with 2 (no exits)")
    MatchFactory.set_dice(m, 6)
    check(MatchFactory.move_for(m, m.state.players[0].pieces[0].id) == null, "column-5 piece cannot overshoot even with 6")
    MatchFactory.set_dice(m, 1)
    check(MatchFactory.move_for(m, m.state.players[0].pieces[0].id) != null, "exact step is fine")
    # column index 4 (progress 54): distance 2, so 2 lands exactly and 3 overshoots
    MatchFactory.place(m, 0, 1, 54)
    MatchFactory.set_dice(m, 3)
    check(MatchFactory.move_for(m, m.state.players[0].pieces[1].id) == null, "3 overshoots from column 4")
    MatchFactory.set_dice(m, 2)
    var exact := MatchFactory.move_for(m, m.state.players[0].pieces[1].id)
    check(exact != null and exact.to_progress == 56, "2 reaches goal exactly")

func _test_exact_goal() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 55)
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    check(mv != null and mv.to_progress == 56, "exact goal move legal")
    m.apply_move(mv)
    check(m.state.players[0].pieces[0].in_goal(), "piece reached goal")
    check_eq(m.state.players[0].pieces[0].progress, 56, "goal progress value")

func _test_column_entry() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 49)   # last ring square
    MatchFactory.set_dice(m, 1)
    m.apply_move(MatchFactory.move_for(m, m.state.players[0].pieces[0].id))
    check(m.state.players[0].pieces[0].in_column(), "entered home column")
    check_eq(m.state.players[0].pieces[0].column_index(), 0, "column index 0")
    # column_index by progress
    MatchFactory.place(m, 0, 1, 54)
    check_eq(m.state.players[0].pieces[1].column_index(), 4, "column index 4")

func _test_win_ends_match() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 56)
    MatchFactory.place(m, 0, 1, 56)
    MatchFactory.place(m, 0, 2, 56)
    MatchFactory.place(m, 0, 3, 55)
    MatchFactory.set_dice(m, 1)
    var res := m.apply_move(MatchFactory.move_for(m, m.state.players[0].pieces[3].id))
    check(bool(res["ok"]), "winning move applied")
    check(m.state.over, "match over on first winner")
    check_eq(m.state.winner, 0, "p0 wins")
    check_eq(m.state.ranking.size(), 2, "ranking for everyone")
    check_eq(m.state.ranking[0], 0, "winner ranked first")
    check_eq(m.state.players[0].rank, 1, "winner rank 1")
    check_eq(m.state.players[1].rank, 2, "loser rank 2")

func _test_distance_to_goal() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    check_eq(m.state.players[0].pieces[0].distance_to_goal(), 57, "pen piece distance")
    MatchFactory.place(m, 0, 0, 0)
    check_eq(m.state.players[0].pieces[0].distance_to_goal(), 56, "start piece distance")
    MatchFactory.place(m, 0, 0, 55)
    check_eq(m.state.players[0].pieces[0].distance_to_goal(), 1, "column piece distance")
