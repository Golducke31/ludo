extends HCTestCase

const RULES_PATH := "res://data/rules/halloween_default.tres"
const CLASSIC_PATH := "res://data/rules/classic.tres"
const FACTION_DIR := "res://data/factions/"

func suite_name() -> String:
    return "rules"

func run() -> void:
    var r := MatchRules.create_default()
    check_eq(r.ring_size, 52, "ring size")
    check_eq(r.arm_length, 13, "arm length")
    check_eq(r.pieces_per_player, 4, "pieces per player")
    check_eq(r.exit_dice_value, 6, "exit dice value")
    check_eq(r.safe_offsets, [0, 7], "safe offsets")
    check_eq(r.home_steps, 50, "home steps")
    check_eq(r.column_length, 6, "column length")
    check_eq(r.total_route_steps(), 56, "total route steps")
    check_eq(r.extra_turn_cap, 3, "extra turn cap")
    check(r.third_six_penalty, "third-six penalty on by default")
    check(not r.hard_blocks, "no hard blocks in v1")
    check(r.halloween_enabled, "halloween on by default")
    check(not r.candy_heap_enabled, "candy heap off by default")
    var starts := [0, 13, 26, 39]
    var entries := [50, 11, 24, 37]
    for p in 4:
        check_eq(r.start_index(p), starts[p], "start index p%d" % p)
        check_eq(r.home_entry_index(p), entries[p], "home entry p%d" % p)
    var safe := r.safe_squares()
    check_eq(safe.size(), 8, "8 safe squares")
    check_eq(safe, [0, 7, 13, 20, 26, 33, 39, 46], "safe square set")
    var classic := MatchRules.create_classic()
    check(not classic.halloween_enabled, "classic disables halloween")
    check_eq(classic.ring_size, 52, "classic keeps board size")
    var r2 := MatchRules.new()
    check_eq(r2.from_dict(r.to_dict()), OK, "from_dict ok")
    check_eq(r2.signature(), r.signature(), "signature roundtrip")
    var bad := MatchRules.new()
    bad.ring_size = 50
    check_eq(bad.from_dict(bad.to_dict()), ERR_INVALID_PARAMETER, "ring must be 4 arms")
    var res := load(RULES_PATH) as MatchRulesResource
    check(res != null, "halloween_default.tres loads")
    if res != null:
        var hr := res.to_rules()
        check(hr.halloween_enabled, "tres halloween on")
        check_eq(hr.ring_size, 52, "tres ring size")
        check_eq(hr.arm_length, 13, "tres arm length")
        check_eq(hr.safe_offsets, [0, 7], "tres safe offsets")
    var cres := load(CLASSIC_PATH) as MatchRulesResource
    check(cres != null, "classic.tres loads")
    if cres != null:
        check(not cres.to_rules().halloween_enabled, "classic.tres disables halloween")
    for id in ["gato_negro", "fantasma_bruja", "rey_calabaza", "conejo_espectral"]:
        var fres := load(FACTION_DIR + id + ".tres") as FactionDataResource
        check(fres != null, "%s.tres loads" % id)
        if fres == null:
            continue
        var f := fres.to_faction()
        check_eq(String(f.id), id, "faction id %s" % id)
        check(f.name_es != "" and f.name_en != "", "faction names %s" % id)
        check(f.desc_es != "" and f.desc_en != "", "faction descs %s" % id)
        check(f.color_hex.begins_with("#"), "faction color hex %s" % id)
        check(f.sprite_dir.begins_with("res://"), "faction sprite dir %s" % id)
        check(is_muted(f.color()), "faction color not neon/cyan %s (%s)" % [id, f.color_hex])
        check(is_muted(f.accent()), "faction accent not neon/cyan %s (%s)" % [id, f.accent_hex])

func is_muted(c: Color) -> bool:
    ## Reject neon/cyan: cyan hues with strong saturation+value.
    var h := c.h
    var s := c.s
    var v := c.v
    var hue_deg := rad_to_deg(h)
    if hue_deg < 0.0:
        hue_deg += 360.0
    if hue_deg >= 150.0 and hue_deg <= 210.0 and s > 0.35 and v > 0.45:
        return false
    if s > 0.95 and v > 0.9:
        return false
    return true
