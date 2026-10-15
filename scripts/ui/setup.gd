extends Control
## Setup screen: pick player count, per-seat faction + human/bot + difficulty,
## rules mode and seed. On Start it configures the Game autoload and loads the
## match scene. M4: localized (ES/EN) + text-scaled.

const FACTION_IDS: Array[StringName] = [&"gato_negro", &"fantasma_bruja", &"rey_calabaza", &"conejo_espectral"]
const FACTION_LABELS := {
    &"gato_negro": "Gato Negro",
    &"fantasma_bruja": "Fantasma Bruja",
    &"rey_calabaza": "Rey Calabaza",
    &"conejo_espectral": "Conejo Espectral",
}
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard"]

@onready var _count_slider: HSlider = %CountSlider
@onready var _count_value: Label = %CountValue
@onready var _rows: VBoxContainer = %SeatRows
@onready var _mode_halloween: CheckBox = %ModeHalloween
@onready var _seed_edit: LineEdit = %SeedEdit
@onready var _btn_start: Button = %BtnStart
@onready var _btn_back: Button = %BtnBack
@onready var _error: Label = %ErrorLabel

var _seat_faction: Array[OptionButton] = []
var _seat_type: Array[OptionButton] = []
var _seat_difficulty: Array[OptionButton] = []

func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    _btn_start.pressed.connect(_on_start)
    _btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
    _count_slider.value_changed.connect(func(_v): _rebuild())
    EventBus.settings_changed.connect(func(): _on_settings_changed())
    L10n.localize_scene(self, "setup")
    UiScaler.apply(self)
    _rebuild()
    _btn_start.grab_focus()

func _on_settings_changed() -> void:
    L10n.localize_scene(self, "setup")
    UiScaler.apply(self)
    _rebuild()

func _rebuild() -> void:
    var count := int(_count_slider.value)
    _count_value.text = str(count)
    for child in _rows.get_children():
        child.queue_free()
    _seat_faction.clear()
    _seat_type.clear()
    _seat_difficulty.clear()
    for i in 4:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        var label := Label.new()
        label.text = "%s %d" % [L10n.t("setup.seat"), i + 1]
        label.custom_minimum_size.x = 96
        row.add_child(label)
        var faction := OptionButton.new()
        for f in FACTION_IDS:
            faction.add_item(L10n.t("faction." + String(f)))
            faction.set_item_metadata(faction.item_count - 1, String(f))
        faction.selected = FACTION_IDS.find(MatchFactory.FACTION_IDS[i % MatchFactory.FACTION_IDS.size()])
        faction.custom_minimum_size.x = 220
        row.add_child(faction)
        var type := OptionButton.new()
        type.add_item(L10n.t("setup.bot"))
        type.add_item(L10n.t("setup.human"))
        type.selected = 1 if i == 0 else 0
        row.add_child(type)
        var diff := OptionButton.new()
        for d in DIFFICULTIES:
            diff.add_item(L10n.t("diff." + String(d)))
            diff.set_item_metadata(diff.item_count - 1, String(d))
        diff.selected = 1   # Normal
        row.add_child(diff)
        var is_bot := type.selected == 0
        diff.visible = is_bot
        type.item_selected.connect(func(idx): diff.visible = idx == 0)
        row.visible = i < count
        _rows.add_child(row)
        _seat_faction.append(faction)
        _seat_type.append(type)
        _seat_difficulty.append(diff)

func _collect_setup() -> Array:
    var count := int(_count_slider.value)
    var out := []
    for i in count:
        var faction_id: String = _seat_faction[i].get_item_metadata(_seat_faction[i].selected)
        var is_bot := _seat_type[i].selected == 0
        var diff: String = _seat_difficulty[i].get_item_metadata(_seat_difficulty[i].selected) if is_bot else "normal"
        out.append({
            "faction_id": faction_id,
            "display_name": L10n.t("faction." + faction_id),
            "is_bot": is_bot,
            "bot_difficulty": diff,
        })
    return out

func _on_start() -> void:
    var count := int(_count_slider.value)
    if count < 2 or count > 4:
        _error.text = L10n.t("setup.error_players")
        return
    _error.text = ""
    var seed_text := _seed_edit.text.strip_edges()
    var seed := randi() if seed_text.is_empty() else int(seed_text)
    var cfg := {
        "players": _collect_setup(),
        "rules_mode": "classic" if not _mode_halloween.button_pressed else "halloween",
        "seed": seed,
    }
    Game.configure(cfg)
    Game.machine.apply(&"start_match")
    get_tree().change_scene_to_file("res://scenes/game/match_root.tscn")
