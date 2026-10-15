extends Node
## Boot scene: explicit BOOTING state before MAIN_MENU.
## Autoloads (EventBus/Settings/Save/Stats/Audio) are already initialized here.

func _ready() -> void:
    # One idle frame so the boot state is real (and headless smoke has a frame to run).
    await get_tree().process_frame
    Game.machine.apply(&"boot_finished")
    EventBus.boot_finished.emit()
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
