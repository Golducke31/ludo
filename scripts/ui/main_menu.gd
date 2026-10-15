extends Control
## M4 main menu: Play / Settings / Credits / Tutorial / Quit.
## Localized + text-scaled; all buttons keyboard reachable.

func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    %BtnPlay.pressed.connect(_on_play)
    %BtnSettings.pressed.connect(_on_settings)
    %BtnCredits.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/credits.tscn"))
    %BtnTutorial.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/tutorial.tscn"))
    %BtnQuit.pressed.connect(_on_quit)
    EventBus.settings_changed.connect(func(): _on_settings_changed())
    L10n.localize_scene(self, "menu")
    UiScaler.apply(self)
    %BtnPlay.grab_focus()

func _on_settings_changed() -> void:
    L10n.localize_scene(self, "menu")
    UiScaler.apply(self)

func _on_play() -> void:
    if Game.machine.can(&"open_setup"):
        Game.machine.apply(&"open_setup")
    EventBus.open_setup_requested.emit()
    get_tree().change_scene_to_file("res://scenes/ui/setup.tscn")

func _on_settings() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")

func _on_quit() -> void:
    get_tree().quit()
