extends HCTestCase

func suite_name() -> String:
    return "rng"

func run() -> void:
    var a := RngStream.new(1234)
    var b := RngStream.new(1234)
    var same := true
    for _i in 1000:
        if a.roll_d6() != b.roll_d6():
            same = false
    check(same, "same seed produces same 1000 rolls")
    var c := RngStream.new(9999)
    c.force_next([6, 6, 6, 1])
    check_eq(c.roll_d6(), 6, "forced 1")
    check_eq(c.roll_d6(), 6, "forced 2")
    check_eq(c.roll_d6(), 6, "forced 3")
    check_eq(c.roll_d6(), 1, "forced 4")
    check_eq(c.forced_remaining(), 0, "forced queue drained")
    c.clear_forced()
    var d := RngStream.new(9999)
    check_eq(d.roll_d6(), c.roll_d6(), "stream continues identically after forced")
    var e := RngStream.new(42)
    var counts := [0, 0, 0, 0, 0, 0]
    for _i in 120000:
        counts[e.roll_d6() - 1] += 1
    var expected := 120000.0 / 6.0
    for f in 6:
        var dev := absf(float(counts[f]) - expected) / expected
        check(dev <= 0.03, "face %d within 3%% (dev %.4f)" % [f + 1, dev])
    var f1 := RngStream.new(7).fork("bot")
    var f2 := RngStream.new(7).fork("bot")
    var f3 := RngStream.new(7).fork("other")
    var fork_same := true
    for _i in 50:
        if f1.roll_d6() != f2.roll_d6():
            fork_same = false
    check(fork_same, "forks are deterministic")
    check(f1.seed_value != f3.seed_value or f1.roll_d6() != f3.roll_d6(), "fork labels differ")
