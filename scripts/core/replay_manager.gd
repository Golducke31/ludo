class_name ReplayManager
extends RefCounted
## Deterministic replay: records (roll, move) steps with per-step state hashes
## and verifies them by re-playing the match and comparing hashes. A mismatch
## pinpoints the exact step where replay diverged (desync detection).

static func play_and_record(rules: MatchRules, setup: Array, seed_value: int, \
        rolls: Array, chooser: Callable, bonus_chooser: Callable, max_steps := 4000) -> Dictionary:
    var gm := GameMatch.new(rules, setup, seed_value, rolls)
    var record := {
        "rules": rules.to_dict(),
        "setup": setup,
        "seed": seed_value,
        "rolls": rolls.duplicate(),
        "steps": [],
    }
    var steps: Array = record["steps"]
    var guard := 0
    while not gm.state.over and guard < max_steps:
        guard += 1
        var roll_result: Dictionary = gm.roll_dice()
        if not bool(roll_result.get("ok", false)):
            break
        if bool(roll_result.get("auto_pass", false)):
            steps.append({"roll": int(roll_result["roll"]), "move": null, "hash": gm.state_hash()})
            continue
        var legal: Array = gm.legal_moves()
        var chosen: Variant = chooser.call(gm, legal)
        if chosen == null:
            steps.append({"roll": int(roll_result["roll"]), "move": null, "hash": gm.state_hash()})
            continue
        var mv: Move = chosen
        var apply_result: Dictionary = gm.apply_move(mv)
        if not bool(apply_result.get("ok", false)):
            break
        var step := {"roll": int(roll_result["roll"]), "move": mv.to_dict(), "hash": gm.state_hash()}
        if not gm.state.pending_bonus.is_empty():
            var choices: Array = gm.bonus_choices()
            var choice: Variant = bonus_chooser.call(gm, choices)
            if choice == null:
                choice = &"advance"
            var br: Dictionary = gm.resolve_bonus(choice)
            if not bool(br.get("ok", false)):
                break
            step["bonus"] = String(choice)
            step["hash"] = gm.state_hash()
        steps.append(step)
    record["final_hash"] = gm.state_hash()
    record["turns"] = gm.state.turn_number
    record["winner"] = gm.state.winner
    record["over"] = gm.state.over
    return record

static func verify(record: Dictionary, max_steps := 4000) -> Dictionary:
    ## Re-plays the recording. Returns {ok, step, detail}.
    var rules := MatchRules.new()
    var err := rules.from_dict(record["rules"])
    if err != OK:
        return {"ok": false, "step": -1, "detail": "bad rules: %d" % err}
    var gm := GameMatch.new(rules, record["setup"], int(record["seed"]), record["rolls"])
    var steps: Array = record["steps"]
    var guard := 0
    for i in steps.size():
        guard += 1
        if guard > max_steps:
            return {"ok": false, "step": i, "detail": "step cap exceeded"}
        var step: Dictionary = steps[i]
        if gm.state.over:
            return {"ok": false, "step": i, "detail": "replay ended early at step %d" % i}
        var roll_result: Dictionary = gm.roll_dice()
        if not bool(roll_result.get("ok", false)):
            return {"ok": false, "step": i, "detail": "roll failed: %s" % str(roll_result.get("error", "?"))}
        if int(roll_result["roll"]) != int(step.get("roll", -1)):
            return {"ok": false, "step": i, "detail": "roll mismatch: %d vs %d" % [int(roll_result["roll"]), int(step.get("roll", -1))]}
        if bool(roll_result.get("auto_pass", false)):
            if step.get("move", null) != null:
                return {"ok": false, "step": i, "detail": "expected pass, found move"}
            if int(step.get("hash", 0)) != gm.state_hash():
                return {"ok": false, "step": i, "detail": "hash mismatch after pass"}
            continue
        var move_data: Variant = step.get("move", null)
        if move_data == null:
            return {"ok": false, "step": i, "detail": "missing move at %d" % i}
        var mv := Move.from_dict(move_data)
        var apply_result: Dictionary = gm.apply_move(mv)
        if not bool(apply_result.get("ok", false)):
            return {"ok": false, "step": i, "detail": "move rejected: %s" % str(apply_result.get("error", "?"))}
        if not gm.state.pending_bonus.is_empty():
            var choice := StringName(str(step.get("bonus", "advance")))
            var br: Dictionary = gm.resolve_bonus(choice)
            if not bool(br.get("ok", false)):
                return {"ok": false, "step": i, "detail": "bonus rejected"}
        if int(step.get("hash", 0)) != gm.state_hash():
            return {"ok": false, "step": i, "detail": "hash mismatch at step %d" % i}
    if not gm.state.over:
        return {"ok": false, "step": steps.size(), "detail": "replay did not finish"}
    if int(record.get("final_hash", 0)) != gm.state_hash():
        return {"ok": false, "step": steps.size(), "detail": "final hash mismatch"}
    return {"ok": true, "step": steps.size(), "detail": "replay verified"}
