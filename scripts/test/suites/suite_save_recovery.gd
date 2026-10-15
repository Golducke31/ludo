extends HCTestCase

const SLOT := "it_slot_a"
const CORRUPT_SLOT := "it_slot_b"

func suite_name() -> String:
    return "save_recovery"

func run() -> void:
    _cleanup()
    var r := MatchRules.create_default()
    var m := MatchFactory.make(r, 2, 7)
    m.roll_dice()
    m.apply_move(m.legal_moves()[0])
    var state := m.to_dict()
    var err := Save.save_match(state, SLOT)
    check_eq(err, OK, "atomic save ok")
    check(Save.has_save(SLOT), "save exists after write")
    check(not FileAccess.file_exists(Save.slot_path(SLOT) + ".tmp"), "tmp file renamed away")
    var loaded := Save.load_match(SLOT)
    check_eq(loaded.size(), state.size(), "loaded state same shape")
    # Godot JSON returns floats for all numbers; compare via restored match.
    var restored := GameMatch.from_dict(loaded)
    check_eq(restored.state_hash(), m.state_hash(), "restored match hash identical")
    check_eq(restored.state.turn_number, m.state.turn_number, "turn number restored")
    check_eq(restored.state.dice_value, m.state.dice_value, "dice restored")
    check_eq(restored.state.players[0].pieces[0].progress, m.state.players[0].pieces[0].progress, "piece progress restored")

    # corrupt JSON -> quarantine + default
    var f := FileAccess.open(Save.slot_path(CORRUPT_SLOT), FileAccess.WRITE)
    f.store_string("{ this is not json ")
    f.close()
    var bad := Save.load_match(CORRUPT_SLOT)
    check(bad.is_empty(), "corrupt save returns default (empty)")
    check(_has_quarantine(CORRUPT_SLOT), "corrupt file quarantined")

    # unknown version -> quarantine + default
    var f2 := FileAccess.open(Save.slot_path(CORRUPT_SLOT), FileAccess.WRITE)
    f2.store_string(JSON.stringify({"version": 999, "state": {"x": 1}}))
    f2.close()
    var bad2 := Save.load_match(CORRUPT_SLOT)
    check(bad2.is_empty(), "unknown version returns default")
    check(_has_quarantine(CORRUPT_SLOT), "unknown version quarantined")

    # missing state key -> quarantine
    var f3 := FileAccess.open(Save.slot_path(CORRUPT_SLOT), FileAccess.WRITE)
    f3.store_string(JSON.stringify({"version": 1}))
    f3.close()
    var bad3 := Save.load_match(CORRUPT_SLOT)
    check(bad3.is_empty(), "missing state returns default")

    # delete + has_save
    Save.delete_save(SLOT)
    check(not Save.has_save(SLOT), "delete removes save")
    _cleanup()

func _has_quarantine(slot: String) -> bool:
    var dir := DirAccess.open("user://saves")
    if dir == null:
        return false
    for name in dir.get_files():
        if name.begins_with(slot + ".json.corrupt-"):
            return true
    return false

func _cleanup() -> void:
    var dir := DirAccess.open("user://saves")
    if dir == null:
        return
    for name in dir.get_files():
        if name.begins_with("it_slot_"):
            dir.remove(name)
