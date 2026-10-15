extends Control
## Results overlay: final ranking, Rematch reuses the setup, Menu returns to
## the main menu. M4: localized + text-scaled.

@onready var _ranking_label: Label = %RankingLabel
@onready var _btn_rematch: Button = %BtnRematch
@onready var _btn_menu: Button = %BtnMenu

func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    _btn_rematch.pressed.connect(func(): Game.request_rematch())
    _btn_menu.pressed.connect(_on_menu)
    EventBus.match_finished.connect(func(ranking): _show(ranking))
    Game.state_changed.connect(func(_s): _refresh())
    EventBus.settings_changed.connect(func(): _on_settings_changed())
    L10n.localize_scene(self, "results")
    UiScaler.apply(self)
    _refresh()

func _on_settings_changed() -> void:
    L10n.localize_scene(self, "results")
    UiScaler.apply(self)

func _refresh() -> void:
    visible = Game.machine != null and Game.machine.current == TurnMachine.MATCH_FINISHED
    if visible:
        _ranking_label.text = _ranking_text(Game.active_match.state.ranking if Game.active_match != null else [])

func _show(ranking: Array) -> void:
    _ranking_label.text = _ranking_text(ranking)
    visible = true

func _ranking_text(ranking: Array) -> String:
    var lines: PackedStringArray = []
    for i in ranking.size():
        var idx := int(ranking[i])
        var name := "P%d" % (idx + 1)
        if Game.active_match != null and idx >= 0 and idx < Game.active_match.state.players.size():
            name = Game.active_match.state.players[idx].display_name
        lines.append("%d. %s" % [i + 1, name])
    return L10n.t("results.ranking") + "\n" + "\n".join(lines)

func _on_menu() -> void:
    Game.request_to_menu()
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
