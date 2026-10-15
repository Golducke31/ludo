extends HCTestCase

func suite_name() -> String:
    return "desync"

func run() -> void:
    var rules := MatchRules.create_default()
    var rolls := MatchFactory.random_rolls(2000, 31337)
    var setup := MatchFactory.setup(3)
    var a := GameMatch.new(rules, setup, 24601, rolls)
    var b := GameMatch.new(rules, setup, 24601, rolls)
    var chooser := func(m: GameMatch, legal: Array) -> Variant:
        return legal[0] if not legal.is_empty() else null
    var guard := 0
    while not a.state.over and guard < 2000:
        guard += 1
        var ra := a.roll_dice()
        var rb := b.roll_dice()
        check_eq(int(ra["roll"]), int(rb["roll"]), "same roll at guard %d" % guard)
        if bool(ra.get("auto_pass", false)):
            # the "sloppy view" on b re-reads everything even on auto-pass
            var _hp := b.state_hash()
            var _lp := b.legal_moves()
            continue
        # B is the match whose view never listens: it re-derives state at odd
        # moments, round-trips snapshots, and drops every notification.
        var hash_before: int = b.state_hash()
        var snap := b.to_dict()
        var restored := GameMatch.from_dict(snap)
        check_eq(restored.state_hash(), hash_before, "snapshot roundtrip stable at guard %d" % guard)
        var _legal_b := b.legal_moves()
        var mv: Variant = chooser.call(b, b.legal_moves())
        check(mv != null, "b has legal moves at guard %d" % guard)
        var mv_a: Variant = chooser.call(a, a.legal_moves())
        a.apply_move(mv_a)
        b.apply_move(mv)
        if not b.state.pending_bonus.is_empty():
            b.resolve_bonus(b.bonus_choices()[0] if not b.bonus_choices().is_empty() else &"advance")
        if not a.state.pending_bonus.is_empty():
            a.resolve_bonus(a.bonus_choices()[0] if not a.bonus_choices().is_empty() else &"advance")
        # notifications intentionally never cross the bus in core; views
        # derive everything from state, so nothing can drift.
    check(a.state.over, "match finished")
    check_eq(a.state_hash(), b.state_hash(), "desync-proof: identical final hashes")
    check_eq(a.state.turn_number, b.state.turn_number, "same turn counts")
    check_eq(a.state.winner, b.state.winner, "same winner")
    check_eq(JSON.stringify(a.state.ranking), JSON.stringify(b.state.ranking), "same ranking")
    # even the event log lengths agree (determinism, not cosmetics)
    check_eq(a.log.count(), b.log.count(), "same event counts")
