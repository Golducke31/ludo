extends HCTestCase
## Input spam against the guarded manager API (Game autoload).
## One match is played cleanly (legal decisions only, human seat driven by the
## harness); a second run hammers the SAME API with 5000 random requests:
## illegal piece moves, bonus choices at the wrong time, pause/resume flips,
## rolls when it is not your turn. Every illegal request must be swallowed by
## the guards, so the final state_hash must equal the clean run exactly.
## This is the anti-double-action / desync guard at manager level.

const SPAM_ITERATIONS := 5000

func suite_name() -> String:
    return "input_spam"

func _setup_players() -> Array:
    return [
        {"faction_id": "gato_negro", "display_name": "P1", "is_bot": false, "bot_difficulty": "normal"},
        {"faction_id": "fantasma_bruja", "display_name": "P2", "is_bot": true, "bot_difficulty": "easy"},
    ]

func _begin(seed: int) -> void:
    Game.configure({"players": _setup_players(), "rules_mode": "halloween", "seed": seed})
    Game.begin_match()

func _run(seed: int, spam: bool) -> int:
    _begin(seed)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed + 90000
    var spam_count := 0
    var i := 0
    while i < SPAM_ITERATIONS:
        i += 1
        var m: GameMatch = Game.active_match
        if m == null:
            check(false, "match disappeared mid-run")
            return -1
        if m.state.over:
            break
        var st: StringName = Game.machine.current
        # PAUSED can only happen from our own spam; always resume immediately.
        if st == TurnMachine.PAUSED:
            Game.request_resume()
            continue
        if not Game.is_human_turn():
            # Bots resolve synchronously in fast_mode; reaching here means the
            # harness lost its place -> that is a real failure.
            check(false, "bot turn leaked into the input loop")
            return -1
        # ---- the clean decision (identical in both runs) ----
        if st == TurnMachine.WAITING_FOR_ROLL:
            check(Game.request_roll(), "roll accepted on human turn")
        elif st == TurnMachine.WAITING_FOR_PIECE_SELECTION:
            var legal: Array = Game.active_match.legal_moves()
            if legal.is_empty():
                check(false, "selection state with no legal moves")
                return -2
            check(Game.request_move(legal[0].piece_id), "clean move accepted")
        elif st == TurnMachine.RESOLVING_BONUS:
            check(Game.request_bonus(&"advance"), "clean bonus accepted")
        else:
            check(false, "unexpected machine state in loop: %s" % String(st))
            return -2
        # Never spam past the end: a legal rematch would start a NEW match.
        if Game.active_match == null or Game.active_match.state.over:
            break
        # ---- spam: requests that must all be rejected or be transient ----
        if spam:
            spam_count += _spam_once(rng)
    if not spam:
        check(Game.active_match != null and Game.active_match.state.over, "clean run reaches match end")
    else:
        check(Game.active_match != null and Game.active_match.state.over, "spam run reaches match end")
    return Game.active_match.state_hash() if Game.active_match != null else -2

func _spam_once(rng: RandomNumberGenerator) -> int:
    ## Requests that must all be rejected (or be transient like pause/resume).
    ## Guards: bonus requests only fire outside a bonus state (a legal one would
    ## mutate and rightly diverge), move spam uses the BOT seat's piece ids
    ## (never legal while a human is current).
    var n := 0
    if Game.is_human_turn():
        if not Game.request_roll():
            n += 1
        if not Game.request_move(10 + rng.randi_range(0, 3)):
            n += 1
        if Game.machine.current != TurnMachine.RESOLVING_BONUS:
            if not Game.request_bonus(&"send_back"):
                n += 1
        if rng.randf() < 0.35 and Game.request_pause():
            Game.request_resume()   # transient: machine returns to where it was
            n += 1
    if not Game.request_rematch():   # only legal after the match ended
        n += 1
    return n

func run() -> void:
    Game.fast_mode = true
    var seed := 4242
    var t0 := Time.get_ticks_msec()
    var spam_hash := _run(seed, true)
    var dt := Time.get_ticks_msec() - t0
    var clean_hash := _run(seed, false)
    check_eq(spam_hash, clean_hash, "spam hash equals clean hash")
    print("  input_spam %d iterations in %d ms; hash=%d clean=%d" % [SPAM_ITERATIONS, dt, spam_hash, clean_hash])
    Game.fast_mode = false
