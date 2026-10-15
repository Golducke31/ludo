extends Node
## Headless test entry point. Runs every suite in-process and prints tokens:
##   HCTESTS:START
##   HCTESTS:SUITE <name> checks=<n> failures=<n> ms=<n>
##   HCTESTS:TOTAL checks=<n> suites=<n> failed_suites=<n>
##   HCTESTS:PASS | HCTESTS:FAIL

func _ready() -> void:
    var suites: Array = [
        preload("res://scripts/test/suites/suite_smoke.gd").new(),
        preload("res://scripts/test/suites/suite_accessibility.gd").new(),
        preload("res://scripts/test/suites/suite_rules.gd").new(),
        preload("res://scripts/test/suites/suite_geometry.gd").new(),
        preload("res://scripts/test/suites/suite_rng.gd").new(),
        preload("res://scripts/test/suites/suite_capture.gd").new(),
        preload("res://scripts/test/suites/suite_home.gd").new(),
        preload("res://scripts/test/suites/suite_turns.gd").new(),
        preload("res://scripts/test/suites/suite_turn_machine.gd").new(),
        preload("res://scripts/test/suites/suite_serialize.gd").new(),
        preload("res://scripts/test/suites/suite_save_recovery.gd").new(),
        preload("res://scripts/test/suites/suite_replay.gd").new(),
        preload("res://scripts/test/suites/suite_desync.gd").new(),
        preload("res://scripts/test/suites/suite_bot_sim.gd").new(),
        preload("res://scripts/test/suites/suite_input_spam.gd").new(),
    ]
    var total_checks := 0
    var total_failures := 0
    var failed_suites := 0
    print("HCTESTS:START")
    for s in suites:
        s.failures.clear()
        var t0 := Time.get_ticks_msec()
        s.run()
        var dt := Time.get_ticks_msec() - t0
        total_checks += s.checks_run
        total_failures += s.failures.size()
        if s.failures.size() > 0:
            failed_suites += 1
        print("HCTESTS:SUITE %s checks=%d failures=%d ms=%d" % [s.suite_name(), s.checks_run, s.failures.size(), dt])
        for msg in s.failures:
            printerr("  FAIL %s: %s" % [s.suite_name(), msg])
    print("HCTESTS:TOTAL checks=%d suites=%d failed_suites=%d" % [total_checks, suites.size(), failed_suites])
    print("HCTESTS:%s" % ("FAIL" if total_failures > 0 else "PASS"))
