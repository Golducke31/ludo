extends Node
## L10n: ES/EN localization. Loads assets/i18n/ui.csv (columns key,es,en)
## at startup - a runtime loader, so there is no import pipeline to break and
## headless tests get the exact same strings. Placeholders use {name} syntax:
##   L10n.t("hud.turn", {"n": 4})
## Missing keys return the key itself so the scan tool can catch them.

const CSV_PATH := "res://assets/i18n/ui.csv"
const FALLBACK := "es"

var _table: Dictionary = {}        # key -> Dictionary {locale: text}
var _locales: Array[String] = []
var _locale: String = FALLBACK

func _ready() -> void:
    _load_csv()
    var saved := String(Settings.get_setting("locale"))
    if _locales.has(saved):
        _locale = saved
    else:
        _locale = FALLBACK
    EventBus.settings_changed.connect(_on_settings_changed)

func locale() -> String:
    return _locale

func available_locales() -> Array[String]:
    return _locales.duplicate()

func set_locale(loc: String) -> void:
    if not _locales.has(loc) or loc == _locale:
        return
    _locale = loc
    Settings.set_setting("locale", loc)   # persists + emits settings_changed

func t(key: String, args := {}) -> String:
    var entry: Dictionary = _table.get(key, {})
    if entry.is_empty():
        return key
    var text := String(entry.get(_locale, entry.get(FALLBACK, key)))
    for k in args:
        text = text.replace("{%s}" % String(k), str(args[k]))
    return text

func _on_settings_changed() -> void:
    var saved := String(Settings.get_setting("locale"))
    if _locales.has(saved) and saved != _locale:
        _locale = saved

## Localize a scene subtree: for every Label/Button/CheckBox/LineEdit whose
## name matches "<prefix>.<node_name>" in the table, set its text (existing
## .tscn text stays as fallback when the key is missing).
func localize_scene(root: Node, prefix: String) -> void:
    _walk_scene(root, prefix)

func _walk_scene(node: Node, prefix: String) -> void:
    var key := "%s.%s" % [prefix, node.name]
    if node is Label and _table.has(key):
        (node as Label).text = t(key)
    elif node is Button and _table.has(key):
        (node as Button).text = t(key)
    elif node is CheckBox and _table.has(key):
        (node as CheckBox).text = t(key)
    elif node is LineEdit and _table.has(key):
        (node as LineEdit).placeholder_text = t(key)
    for child in node.get_children():
        _walk_scene(child, prefix)

# --- minimal CSV (handles quotes and embedded newlines) ---------------------

func _load_csv() -> void:
    var f := FileAccess.open(CSV_PATH, FileAccess.READ)
    if f == null:
        push_warning("L10n: cannot open %s" % CSV_PATH)
        return
    var text := f.get_as_text()
    f.close()
    var rows := _parse_csv(text)
    if rows.size() < 2:
        push_warning("L10n: csv has no data rows")
        return
    var header: Array = rows[0]
    if String(header[0]).strip_edges() != "key":
        push_warning("L10n: csv header must start with 'key'")
        return
    _locales.clear()
    for i in range(1, header.size()):
        _locales.append(String(header[i]).strip_edges())
    for r in range(1, rows.size()):
        var row: Array = rows[r]
        if row.is_empty():
            continue
        var key := String(row[0]).strip_edges()
        if key.is_empty():
            continue
        var entry := {}
        for i in range(1, mini(header.size(), row.size())):
            entry[String(header[i]).strip_edges()] = String(row[i])
        _table[key] = entry

func _parse_csv(text: String) -> Array:
    var rows: Array = []
    var row: Array = []
    var field := ""
    var in_quotes := false
    var i := 0
    while i < text.length():
        var ch := text[i]
        if in_quotes:
            if ch == '"':
                if i + 1 < text.length() and text[i + 1] == '"':
                    field += '"'
                    i += 1
                else:
                    in_quotes = false
            else:
                field += ch
        else:
            if ch == '"':
                in_quotes = true
            elif ch == ",":
                row.append(field)
                field = ""
            elif ch == "\n":
                row.append(field)
                field = ""
                rows.append(row)
                row = []
            elif ch == "\r":
                pass
            else:
                field += ch
        i += 1
    if not field.is_empty() or not row.is_empty():
        row.append(field)
        rows.append(row)
    return rows
