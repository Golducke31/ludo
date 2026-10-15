extends Node
## Persistent user settings (ConfigFile at user://settings.cfg).
## Central defaults live here so accessibility/persistence code has no magic values.

const PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS := {
    "reduce_motion": false,
    "colorblind_mode": false,
    "high_contrast": false,
    "text_scale": 1.0,
    "locale": "es",
    "volume_master": 0.8,
    "volume_sfx": 1.0,
    "volume_music": 0.5,
    "tutorial_seen": false,
}

var _cfg := ConfigFile.new()

func _ready() -> void:
    load_settings()

func load_settings() -> void:
    var err := _cfg.load(PATH)
    if err != OK:
        _cfg = ConfigFile.new()
    for key in DEFAULTS:
        if not _cfg.has_section_key(SECTION, key):
            _cfg.set_value(SECTION, key, DEFAULTS[key])

func get_setting(key: String) -> Variant:
    if _cfg.has_section_key(SECTION, key):
        return _cfg.get_value(SECTION, key)
    return DEFAULTS.get(key)

func set_setting(key: String, value: Variant) -> void:
    _cfg.set_value(SECTION, key, value)
    save_settings()
    EventBus.settings_changed.emit()

func save_settings() -> Error:
    var err := _cfg.save(PATH)
    if err != OK:
        push_warning("Settings: could not save (%d)" % err)
    return err

func reset_defaults() -> void:
    _cfg = ConfigFile.new()
    for key in DEFAULTS:
        _cfg.set_value(SECTION, key, DEFAULTS[key])
    save_settings()
    EventBus.settings_changed.emit()
