extends Node
## Helper: run the headless editor pass so .godot/global_script_class_cache.cfg
## is written. Required after adding/renaming class_name scripts, because pure
## headless runs never rebuild the global class cache on their own.

func _ready() -> void:
    pass
