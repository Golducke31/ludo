extends Control
## Tutorial screen (M4): rules digest. Text comes from the localized ui.csv
## ('|' separates lines).

@onready var _body: Label = %Body
@onready var _btn_back: Button = %BtnBack

func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    _btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
    EventBus.settings_changed.connect(func(): _on_settings_changed())
    L10n.localize_scene(self, "tutorial")
    _refresh_body()
    UiScaler.apply(self)
    _btn_back.grab_focus()

func _on_settings_changed() -> void:
    L10n.localize_scene(self, "tutorial")
    _refresh_body()
    UiScaler.apply(self)

func _refresh_body() -> void:
    _body.text = L10n.t("tutorial.body").replace("|", "\n")
