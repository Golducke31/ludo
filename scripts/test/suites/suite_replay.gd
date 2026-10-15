extends HCTestCase

func suite_name() -> String:
    return "replay"

func run() -> void:
    var chooser := func(m: GameMatch, legal: Array) -> Variant:
        return legal[0] if not legal.is_empty() else null
    var bonus_chooser := func(m: GameMatch, choices: Array) -> StringName:
        if choices.is_empty():
            return &"advance"
        return choices[0]
    var verified := 0
    for k in 10:
        var rules := MatchRules.create_default() if k % 2 == 0 else MatchRules.create_classic()
        var setup := MatchFactory.setup(2 + (k % 3))
        var rolls := MatchFactory.random_rolls(3000, 500 + k)
        var record := ReplayManager.play_and_record(rules, setup, 2000 + k, rolls, chooser, bonus_chooser)
        check(bool(record["over"]), "recorded match %d finished" % k)
        check(int(record["winner"]) >= 0, "recorded match %d has winner" % k)
        var result := ReplayManager.verify(record)
        check(bool(result["ok"]), "replay %d verified (%s)" % [k, str(result.get("detail", ""))])
        if bool(result["ok"]):
            verified += 1
    check_eq(verified, 10, "all 10 replays verified")
    _test_tamper_detection(chooser, bonus_chooser)

func _test_tamper_detection(chooser: Callable, bonus_chooser: Callable) -> void:
    var rules := MatchRules.create_classic()
    var rolls := MatchFactory.random_rolls(500, 99)
    var record := ReplayManager.play_and_record(rules, MatchFactory.setup(2), 4242, rolls, chooser, bonus_chooser)
    var steps: Array = record["steps"]
    var tampered := false
    for i in steps.size():
        var step: Dictionary = steps[i]
        if step.get("move", null) != null:
            var mv: Dictionary = step["move"]
            mv["to_progress"] = int(mv.get("to_progress", 0)) + 1   # illegal destination
            step["move"] = mv
            var result := ReplayManager.verify(record)
            check(not bool(result["ok"]), "tampered move %d rejected" % i)
            check_le(int(result.get("step", 1 << 20)), i, "tamper detected at or before step %d" % i)
            tampered = true
            break
    check(tampered, "found a step to tamper with")
    # hash tampering: change a recorded hash
    var record2 := ReplayManager.play_and_record(rules, MatchFactory.setup(2), 777, rolls, chooser, bonus_chooser)
    var steps2: Array = record2["steps"]
    if steps2.size() > 3:
        var step2: Dictionary = steps2[3]
        step2["hash"] = int(step2.get("hash", 0)) + 12345
        var result2 := ReplayManager.verify(record2)
        check(not bool(result2["ok"]), "hash tamper detected")
        check_le(int(result2.get("step", 1 << 20)), 3, "hash tamper located at step <= 3")
