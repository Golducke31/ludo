extends Node
## Aggregate run statistics persisted at user://stats.cfg (ConfigFile).

const PATH := "user://stats.cfg"
const SECTION := "stats"

const DEFAULTS := {
    "matches_started": 0,
    "matches_finished": 0,
    "matches_abandoned": 0,
    "total_turns": 0,
    "wins_gato_negro": 0,
    "wins_fantasma_bruja": 0,
    "wins_rey_calabaza": 0,
    "wins_conejo_espectral": 0,
    "bot_wins": 0,
    "human_wins": 0,
}

var _cfg := ConfigFile.new()

func _ready() -> void:
    var err := _cfg.load(PATH)
    if err != OK:
        _cfg = ConfigFile.new()
    for key in DEFAULTS:
        if not _cfg.has_section_key(SECTION, key):
            _cfg.set_value(SECTION, key, DEFAULTS[key])

func get_stat(key: String) -> Variant:
    if _cfg.has_section_key(SECTION, key):
        return _cfg.get_value(SECTION, key)
    return DEFAULTS.get(key)

func add_stat(key: String, by := 1) -> void:
    _cfg.set_value(SECTION, key, int(get_stat(key)) + int(by))
    save()

func record_finish(winner_faction: String, winner_is_bot: bool, turns: int) -> void:
    add_stat("matches_finished", 1)
    add_stat("total_turns", turns)
    var win_key := "wins_" + winner_faction
    if DEFAULTS.has(win_key):
        add_stat(win_key, 1)
    add_stat("bot_wins" if winner_is_bot else "human_wins", 1)
    save()

func save() -> void:
    var err := _cfg.save(PATH)
    if err != OK:
        push_warning("Stats: could not save (%d)" % err)
