extends Node
## All human input for a match. Keyboard: Space/Enter roll, 1-4 pick a piece,
## Esc pause/resume, C toggles the camera (isometric <-> first person).
## Mouse: click a piece to move it (resolved by the 3D arena:
## screen-space projection pick, see Arena.pick_piece_at). Positions come from
## Viewport.get_mouse_position() so the canvas_items stretch is already applied.
## Everything goes through the guarded Game API; illegal input is swallowed,
## never throws, so input spam is safe (see suite_input_spam).

var _arena: Node3D = null

func _ready() -> void:
	_arena = get_parent().get_node_or_null("Arena")

func _unhandled_input(event: InputEvent) -> void:
	if Game.active_match == null or Game.active_match.state.over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event as InputEventKey)
	elif event is InputEventMouseButton and event.pressed:
		_handle_click(event as InputEventMouseButton)

func _handle_key(ev: InputEventKey) -> void:
	match ev.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			Game.request_roll()
		KEY_1, KEY_2, KEY_3, KEY_4:
			_select_slot(ev.keycode - KEY_1)
		KEY_C:
			_toggle_camera()
		KEY_ESCAPE:
			_toggle_pause()

func _toggle_camera() -> void:
	if _arena != null and _arena.has_method("toggle_camera_mode"):
		_arena.toggle_camera_mode()

func _select_slot(slot: int) -> void:
	if not Game.is_human_turn():
		return
	if Game.active_match.state.current < 0 or Game.active_match.state.current >= Game.active_match.state.players.size():
		return
	var piece_id: int = Game.active_match.state.current * 10 + slot
	Game.request_move(piece_id)

func _toggle_pause() -> void:
	if Game.machine.current == TurnMachine.PAUSED:
		Game.request_resume()
	elif Game.machine.is_in_match():
		Game.request_pause()

func _handle_click(ev: InputEventMouseButton) -> void:
	if ev.button != MOUSE_BUTTON_LEFT:
		return
	if _arena == null or not _arena.has_method("pick_piece_at"):
		return
	if not Game.is_human_turn():
		return
	if Game.machine.current != TurnMachine.WAITING_FOR_PIECE_SELECTION:
		return
	var pos: Vector2 = get_viewport().get_mouse_position()
	var best_id: int = _arena.pick_piece_at(pos)
	if best_id >= 0:
		Game.request_move(best_id)
