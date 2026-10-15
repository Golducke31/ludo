extends HCTestCase

func suite_name() -> String:
    return "capture"

func run() -> void:
    _test_landing_capture()
    _test_safe_protects()
    _test_stack_capture()
    _test_pass_over_does_not_capture()
    _test_portal()
    _test_portal_then_capture()
    _test_lantern_advance()
    _test_lantern_send_back()
    _test_send_back_to_pen()
    _test_candy()
    _test_classic_has_no_specials()

func _test_landing_capture() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 1, 0, 45)   # ring index 6 (vulnerable)
    MatchFactory.place(m, 0, 0, 5)
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    check(mv != null, "step move exists")
    var res := m.apply_move(mv)
    check(bool(res["ok"]), "move applied")
    check_eq(m.state.players[0].pieces[0].progress, 6, "mover advanced")
    check_eq(m.state.players[1].pieces[0].progress, -1, "rival captured to pen")

func _test_safe_protects() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 1, 0, 46)   # ring index 7 = safe
    MatchFactory.place(m, 0, 0, 6)
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    check_eq(m.state.players[1].pieces[0].progress, 46, "rival untouched on safe square")
    check_eq(m.state.players[0].pieces[0].progress, 7, "mover on safe square")

func _test_stack_capture() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 1, 0, 45)
    MatchFactory.place(m, 1, 1, 45)   # stacked rivals
    MatchFactory.place(m, 0, 0, 5)
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    check_eq(m.state.players[1].pieces[0].progress, -1, "first stacked rival captured")
    check_eq(m.state.players[1].pieces[1].progress, -1, "second stacked rival captured")

func _test_pass_over_does_not_capture() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 1, 0, 45)   # ring 6
    MatchFactory.place(m, 0, 0, 4)
    MatchFactory.set_dice(m, 3)       # 4 -> 7 passes over ring 6
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    check_eq(m.state.players[1].pieces[0].progress, 45, "passing over does not capture")
    check_eq(m.state.players[0].pieces[0].progress, 7, "mover landed past rival")

func _test_portal() -> void:
    var r := MatchRules.create_default()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 3)
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    check_eq(m.state.players[0].pieces[0].progress, 10, "portal teleports +6 steps")
    check_eq(m.state.players[0].pieces[0].ring_index(), 10, "portal ring index")

func _test_portal_then_capture() -> void:
    var r := MatchRules.create_default()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 1, 0, 49)   # ring index 10
    MatchFactory.place(m, 0, 0, 3)
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    check_eq(m.state.players[0].pieces[0].progress, 10, "portal destination")
    check_eq(m.state.players[1].pieces[0].progress, -1, "capture resolves at portal exit")

func _test_lantern_advance() -> void:
    var r := MatchRules.create_default()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 29)   # ring 29; +1 -> ring 30 lantern
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    check(not m.state.pending_bonus.is_empty(), "lantern bonus pending")
    check_eq(m.bonus_choices(), [&"advance"], "only advance offered without rivals out")
    m.resolve_bonus(&"advance")
    check(m.state.pending_bonus.is_empty(), "bonus resolved")
    check_eq(m.state.players[0].pieces[0].progress, 32, "lantern +2")

func _test_lantern_send_back() -> void:
    var r := MatchRules.create_default()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 29)
    MatchFactory.place(m, 1, 0, 20)   # rival out at progress 20
    MatchFactory.set_dice(m, 1)
    var mv := MatchFactory.move_for(m, m.state.players[0].pieces[0].id)
    m.apply_move(mv)
    var choices := m.bonus_choices()
    check(choices.has(&"advance") and choices.has(&"send_back"), "both lantern choices offered")
    m.resolve_bonus(&"send_back")
    check_eq(m.state.players[1].pieces[0].progress, 14, "rival sent back 6 squares")
    check_eq(m.state.players[0].pieces[0].progress, 30, "lantern piece unchanged")

func _test_send_back_to_pen() -> void:
    var r := MatchRules.create_default()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 29)
    MatchFactory.place(m, 1, 0, 3)    # only 3 steps out
    MatchFactory.set_dice(m, 1)
    m.apply_move(MatchFactory.move_for(m, m.state.players[0].pieces[0].id))
    m.resolve_bonus(&"send_back")
    check_eq(m.state.players[1].pieces[0].progress, -1, "rival with <6 progress returns to pen")

func _test_candy() -> void:
    var r := MatchRules.create_default()
    r.candy_heap_enabled = true
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 46)   # ring 46; +1 -> ring 47 candy
    MatchFactory.set_dice(m, 1)
    var res := m.apply_move(MatchFactory.move_for(m, m.state.players[0].pieces[0].id))
    check(bool(res["ok"]), "candy move applied")
    check(m.state.players[0].candy_used, "candy marked used")
    check(bool(res["extra_turn"]), "candy grants extra turn")
    # second candy is inert
    MatchFactory.place(m, 0, 1, 46)   # another piece ready at the candy square
    MatchFactory.set_dice(m, 1)
    var res2 := m.apply_move(MatchFactory.move_for(m, m.state.players[0].pieces[1].id))
    check(m.state.players[0].candy_used, "candy flag sticky")
    check(not bool(res2["extra_turn"]), "second candy grants nothing")

func _test_classic_has_no_specials() -> void:
    var r := MatchRules.create_classic()
    var m := MatchFactory.make(r, 2, 1)
    MatchFactory.place(m, 0, 0, 46)
    MatchFactory.set_dice(m, 1)
    var res := m.apply_move(MatchFactory.move_for(m, m.state.players[0].pieces[0].id))
    check(m.state.pending_bonus.is_empty(), "classic never offers bonuses")
    check_eq(m.state.players[0].pieces[0].progress, 47, "classic movement is plain")
