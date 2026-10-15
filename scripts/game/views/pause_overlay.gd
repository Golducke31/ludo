extends Control
## Pause overlay. Resume returns through the TurnMachine (resume restores the
## exact previous state, never a fresh turn). M4: localized + text-scaled.

@onready var _btn_resume: Button = %BtnResume
@onready var _btn_save: Button = %BtnSave
@onready var _btn_load: Button = %BtnLoad
@onready var _btn_quit: Button = %BtnQuit
@onready var _status: Label = %PauseStatus

func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    _btn_resume.pressed.connect(func(): Game.request_resume())
    _btn_save.pressed.connect(_on_save)
    _btn_load.pressed.connect(_on_load)
    _btn_quit.pressed.connect(_on_quit)
    Game.state_changed.connect(func(_s): _refresh())
    EventBus.settings_changed.connect(func(): _on_settings_changed())
    L10n.localize_scene(self, "pause")
    UiScaler.apply(self)
    _refresh()

func _on_settings_changed() -> void:
    L10n.localize_scene(self, "pause")
    UiScaler.apply(self)
    _refresh()

func _refresh() -> void:
    visible = Game.machine != null and Game.machine.current == TurnMachine.PAUSED
    if visible:
        _btn_load.visible = Game.has_save()
        _btn_load.disabled = not Game.has_save()
        _status.text = ""

func _on_save() -> void:
    var err: Error = Game.save_current()
    _status.text = L10n.t("pause.saved") if err == OK else L10n.t("pause.save_failed", {"err": err})

func _on_load() -> void:
    _status.text = L10n.t("pause.loaded") if Game.load_current() else L10n.t("pause.no_save")

func _on_quit() -> void:
    Game.request_to_menu()
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
