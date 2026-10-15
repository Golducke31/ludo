extends Node
## Atomic, versioned save/load of match state.
## - writes go to user://saves/<slot>.tmp then rename (atomic-ish)
## - a corrupt or unknown-version file is quarantined as
##   user://saves/<slot>.corrupt-<unix>.json and defaults (empty) are returned

const DIR := "user://saves"
const SLOT := "slot0"
const VERSION := 1

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(DIR)

func slot_path(name := SLOT) -> String:
    return DIR.path_join(name + ".json")

func has_save(name := SLOT) -> bool:
    return FileAccess.file_exists(slot_path(name))

func save_match(state: Dictionary, name := SLOT) -> Error:
    DirAccess.make_dir_recursive_absolute(DIR)
    var wrapper := {
        "version": VERSION,
        "saved_at": int(Time.get_unix_time_from_system()),
        "state": state,
    }
    var tmp_path := slot_path(name) + ".tmp"
    var f := FileAccess.open(tmp_path, FileAccess.WRITE)
    if f == null:
        return FileAccess.get_open_error()
    f.store_string(JSON.stringify(wrapper))
    f.close()
    return DirAccess.rename_absolute(tmp_path, slot_path(name))

func load_match(name := SLOT) -> Dictionary:
    var path := slot_path(name)
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        _quarantine(path)
        return {}
    var text := f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        _quarantine(path)
        return {}
    var wrapper: Dictionary = parsed
    if int(wrapper.get("version", -1)) != VERSION or not wrapper.has("state"):
        _quarantine(path)
        return {}
    return wrapper["state"]

func delete_save(name := SLOT) -> void:
    if FileAccess.file_exists(slot_path(name)):
        DirAccess.remove_absolute(slot_path(name))

func _quarantine(path: String) -> void:
    var stamp := int(Time.get_unix_time_from_system())
    DirAccess.rename_absolute(path, "%s.corrupt-%d.json" % [path, stamp])
