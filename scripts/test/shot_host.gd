extends Node
## Dev screenshot harness (not part of the shipped game): configures a
## halloween match with 1 human + 3 bots, plays a couple of frames, and
## writes screenshot_m3.png. Usage:
##   godot --path . res://scenes/tools/shot_host.tscn --quit-after 99999

const MATCH_SCENE := "res://scenes/game/match_root.tscn"

func _ready() -> void:
    var seats: Array = [
        {"faction_id": "gato_negro", "display_name": "Gato Negro", "is_bot": false, "bot_difficulty": "normal"},
        {"faction_id": "fantasma_bruja", "display_name": "Fantasma Bruja", "is_bot": true, "bot_difficulty": "normal"},
        {"faction_id": "rey_calabaza", "display_name": "Rey Calabaza", "is_bot": true, "bot_difficulty": "normal"},
        {"faction_id": "conejo_espectral", "display_name": "Conejo Espectral", "is_bot": true, "bot_difficulty": "normal"},
    ]
    Game.configure({"players": seats, "rules_mode": "halloween", "seed": 20261014})
    Game.machine.apply(&"start_match")
    var scene: PackedScene = load(MATCH_SCENE)
    add_child(scene.instantiate())
    _run()

func _run() -> void:
    await get_tree().create_timer(1.2).timeout
    # human rolls when it is their turn
    if Game.is_human_turn() and Game.machine.current == TurnMachine.WAITING_FOR_ROLL:
        Game.request_roll()
        await get_tree().create_timer(0.8).timeout
        # take the first legal move so pieces leave the pens
        if Game.machine.current == TurnMachine.WAITING_FOR_PIECE_SELECTION:
            var moves: Array = Game.active_match.legal_moves()
            if not moves.is_empty():
                Game.request_move(int((moves[0] as Dictionary).get("piece_id", 0)))
            await get_tree().create_timer(0.8).timeout
    # let a bot capture happen if the seed wants it
    await get_tree().create_timer(2.0).timeout
    var img: Image = get_viewport().get_texture().get_image()
    img.save_png("res://screenshot_m3.png")
    print("SHOT saved res://screenshot_m3.png ", img.get_width(), "x", img.get_height())
    get_tree().quit()
