extends HCTestCase

func suite_name() -> String:
    return "serialize"

func run() -> void:
    var r := MatchRules.create_default()
    var roundtrips := 0
    for k in 50:
        var rules := r if k % 2 == 0 else MatchRules.create_classic()
        var m := MatchFactory.make(rules, 2 + (k % 3), 1000 + k)
        var snap_step := 2 + (k % 6)
        var steps := 5 + (k * 7) % 40
        for _s in steps:
            if m.state.over:
                break
            var rr := m.roll_dice()
            if not bool(rr.get("ok", false)):
                break
            if bool(rr.get("auto_pass", false)):
                continue
            var legal := m.legal_moves()
            if legal.is_empty():
                break
            m.apply_move(legal[k % legal.size()])
            if not m.state.pending_bonus.is_empty():
                m.resolve_bonus(&"advance" if m.bonus_choices().has(&"advance") else &"send_back")
            if _s + 1 == snap_step:
                _snapshot_and_compare(m, k)
                roundtrips += 1
        _snapshot_and_compare(m, k)
        roundtrips += 1
    check(roundtrips >= 50, "at least 50 snapshots round-tripped (%d)" % roundtrips)
    _test_garbage_rejected()

func _snapshot_and_compare(m: GameMatch, k: int) -> void:
    var d := m.to_dict()
    var text := JSON.stringify(d)
    var parsed: Variant = JSON.parse_string(text)
    check(typeof(parsed) == TYPE_DICTIONARY, "json roundtrip %d" % k)
    var m2 := GameMatch.from_dict(d)
    check_eq(m2.state_hash(), m.state_hash(), "state hash after restore %d" % k)
    check_eq(m2.state.turn_number, m.state.turn_number, "turn number restored %d" % k)
    check_eq(m2.state.current, m.state.current, "current restored %d" % k)
    check_eq(m2.state.players.size(), m.state.players.size(), "player count restored %d" % k)
    for i in m.state.players.size():
        var a: PlayerState = m.state.players[i]
        var b: PlayerState = m2.state.players[i]
        check_eq(b.pieces.size(), a.pieces.size(), "piece count %d p%d" % [k, i])
        for j in a.pieces.size():
            check_eq(b.pieces[j].progress, a.pieces[j].progress, "piece progress %d p%d %d" % [k, i, j])

func _test_garbage_rejected() -> void:
    var r := MatchRules.new()
    check_eq(r.from_dict({}), ERR_INVALID_PARAMETER, "empty rules dict rejected")
    var junk := MatchRules.new()
    junk.ring_size = 51
    check_eq(junk.from_dict(junk.to_dict()), ERR_INVALID_PARAMETER, "bad ring rejected")
    var s := MatchState.new()
    s.rules = MatchRules.create_default()
    var d := s.to_dict()
    check(d.has("rules") and d.has("players"), "state dict has sections")
    # JSON round trip keeps everything restorable (ints may come back as floats)
    var text := JSON.stringify(d)
    var parsed: Variant = JSON.parse_string(text)
    check(typeof(parsed) == TYPE_DICTIONARY, "state json roundtrip")
    var s2 := MatchState.from_dict(parsed)
    check_eq(s2.rules.ring_size, 52, "rules restored from json")
